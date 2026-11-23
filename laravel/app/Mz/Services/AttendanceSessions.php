<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The attendance session of one program occurrence (HR-controlled):
 *  - exactly one session per occurrence (UNIQUE program + date) and ONE taker — the occurrence's own
 *    assignment by HR (attendance.assign), else the program's default taker;
 *  - available from 15 minutes before the scheduled start; attendance time starts only when the
 *    assigned taker presses Start (the server's time; a start made offline keeps the phone's time,
 *    adjusted to the server clock, and says so);
 *  - ends when the taker presses End (or HR closes it), or at the scheduled end — whichever comes
 *    first, no grace period; after that only the correction workflow changes attendance.
 * No scheduled job: the scheduled end is applied whenever the session is read.
 */
final class AttendanceSessions
{
    public const AVAILABLE_BEFORE_MINUTES = 15;

    public static function availableFrom(array $o): \DateTimeImmutable
    {
        return Dates::of($o['starts_at'])->modify('-' . self::AVAILABLE_BEFORE_MINUTES . ' minutes');
    }

    /** The program's default taker (null = none assigned yet). */
    public static function defaultTaker(int $programId): ?int
    {
        $id = DB::table('program_attendance_takers')->where('program_id', $programId)->orderBy('created_at')->value('user_id');
        return $id ? (int) $id : null;
    }

    /**
     * The session row of an occurrence (created on first use). A scheduled session without an HR
     * assignment follows the program's current default taker. An active session past the scheduled
     * end is ended here (end_reason scheduled_end, at the scheduled end time).
     */
    public static function of(object $p, array $o, bool $lock = false): object
    {
        $key = ['program_id' => $p->id, 'occurrence_date' => $o['date']];
        if (! DB::table('attendance_sessions')->where($key)->exists()) {
            DB::table('attendance_sessions')->insertOrIgnore($key + ['taker_id' => self::defaultTaker((int) $p->id), 'status' => ! empty($o['suspended']) ? 'suspended' : (! empty($o['cancelled']) ? 'cancelled' : 'scheduled')]);
        }
        $q = DB::table('attendance_sessions')->where($key);
        if ($lock) $q->lockForUpdate();
        $s = $q->first();
        if ($s->status === 'scheduled' && $s->assigned_by === null) {
            $default = self::defaultTaker((int) $p->id);
            if ($default !== ($s->taker_id ? (int) $s->taker_id : null)) {
                DB::table('attendance_sessions')->where('id', $s->id)->update(['taker_id' => $default]);
                $s->taker_id = $default;
            }
        }
        if ($s->status === 'active' && Dates::now() >= Dates::of($o['ends_at'])) {
            $end = Dates::sql($o['ends_at']);
            DB::table('attendance_sessions')->where('id', $s->id)->where('status', 'active')->update(['status' => 'ended', 'ended_at' => $end, 'end_reason' => 'scheduled_end']);
            $s->status = 'ended';
            $s->ended_at = Dates::of($end);
            $s->end_reason = 'scheduled_end';
        }
        return $s;
    }

    /** Batch closes all active sessions whose scheduled end time has passed. */
    public static function closeExpiredSessions(): int
    {
        $now = Dates::now();
        $nowIso = Dates::sql($now);
        $activeSessions = DB::table('attendance_sessions as s')
            ->join('programs as p', 'p.id', '=', 's.program_id')
            ->where('s.status', 'active')
            ->select('s.id', 's.program_id', 's.occurrence_date')
            ->get();

        $closed = 0;
        foreach ($activeSessions as $as) {
            $p = DB::table('programs')->where('id', $as->program_id)->first();
            if (! $p) continue;
            $o = Attendance::resolveOccurrence($p, $as->occurrence_date);
            if (! $o) continue;
            if ($now >= Dates::of($o['ends_at'])) {
                $end = Dates::sql($o['ends_at']);
                $updated = DB::table('attendance_sessions')
                    ->where('id', $as->id)
                    ->where('status', 'active')
                    ->update([
                        'status' => 'ended',
                        'ended_at' => $end,
                        'end_reason' => 'scheduled_end',
                        'updated_at' => $nowIso,
                    ]);
                if ($updated) {
                    $closed++;
                    DB::table('attendance_closures')->insertOrIgnore([
                        'program_id' => $as->program_id,
                        'occurrence_date' => $as->occurrence_date,
                        'closed_by' => null,
                        'closed_at' => $end,
                    ]);
                }
            }
        }
        return $closed;
    }

    /** The moment the session stops accepting attendance (End pressed, or the scheduled end). */
    public static function closesAt(object $s, array $o): \DateTimeImmutable
    {
        $end = Dates::of($o['ends_at']);
        return $s->ended_at && Dates::of($s->ended_at) < $end ? Dates::of($s->ended_at) : $end;
    }

    /** Started, not ended, and [at] inside [started_at, end). */
    public static function acceptsAt(object $s, array $o, \DateTimeInterface $at): bool
    {
        if (! $s->started_at || $s->status === 'cancelled') return false;
        return $at >= Dates::of($s->started_at) && $at < self::closesAt($s, $o);
    }

    public static function serialize(object $s, object $p, array $o, ?AuthContext $auth = null): array
    {
        $now = Dates::now();
        $taker = $s->taker_id ? DB::table('users')->where('id', $s->taker_id)->first(['id', 'full_name']) : null;
        $available = self::availableFrom($o);
        $isTaker = $auth && $s->taker_id && (int) $s->taker_id === $auth->id;
        $ended = in_array($s->status, ['ended', 'cancelled'], true);
        return [
            'id' => (int) $s->id, 'program_id' => (int) $p->id, 'date' => $o['date'],
            'scheduled_start' => $o['starts_at'], 'scheduled_end' => $o['ends_at'], 'available_from' => $available,
            'status' => $s->status,
            'taker' => $taker ? ['id' => (int) $taker->id, 'full_name' => $taker->full_name] : null,
            'assigned_by_hr' => $s->assigned_by !== null,
            'started_at' => $s->started_at, 'start_source' => $s->start_source, 'client_started_at' => $s->client_started_at,
            'ended_at' => $s->ended_at, 'end_reason' => $s->end_reason,
            'elapsed_seconds' => $s->status === 'active' && $s->started_at ? max(0, $now->getTimestamp() - Dates::of($s->started_at)->getTimestamp()) : null,
            'is_taker' => (bool) $isTaker,
            'can_start' => $isTaker && $s->status === 'scheduled' && $now >= $available && $now < Dates::of($o['ends_at']),
            'can_end' => $s->status === 'active' && ($isTaker || ($auth && $auth->can('attendance.close'))),
            'can_assign' => ! $ended && $auth && $auth->can('attendance.assign'),
            'server_time' => $now,
        ];
    }

    public static function get(AuthContext $auth, int $programId, ?string $date): array
    {
        self::closeExpiredSessions();
        $p = Attendance::getProgram($programId);
        $o = Attendance::resolveOccurrence($p, $date);
        if (! $o) throw ApiError::notFound('OCCURRENCE_NOT_FOUND', 'No occurrence');
        $s = self::of($p, $o);
        self::assertMayView($auth, $s);
        return self::serialize($s, $p, $o, $auth);
    }

    private static function assertMayView(AuthContext $auth, object $s): void
    {
        if ($s->taker_id && (int) $s->taker_id === $auth->id) return;
        foreach (['attendance.view', 'attendance.manage', 'attendance.assign', 'attendance.close', 'attendance.override', 'attendance.reports'] as $k) {
            if ($auth->can($k)) return;
        }
        throw ApiError::forbidden('NOT_SESSION_TAKER', 'Only the assigned attendance taker or HR can see this session');
    }

    /**
     * Start the session (the assigned taker only). [clientAt] = when the phone pressed Start while
     * offline (already adjusted to the server clock); null = now.
     */
    public static function start(array $actx, int $programId, ?string $date, ?\DateTimeInterface $clientAt = null, ?\DateTimeInterface $clientRaw = null, ?string $clientUuid = null): array
    {
        $auth = $actx['auth'];
        return DB::transaction(function () use ($actx, $auth, $programId, $date, $clientAt, $clientRaw, $clientUuid) {
            $p = Attendance::getProgram($programId);
            if (! $p->requires_attendance) throw ApiError::conflict('ATTENDANCE_NOT_REQUIRED', 'This program does not take attendance');
            $o = Attendance::resolveOccurrence($p, $date);
            if (! $o || ! empty($o['cancelled']) || ! empty($o['suspended'])) throw ApiError::conflict('PROGRAM_SUSPENDED', 'This occurrence is suspended');
            $s = self::of($p, $o, true);
            if (! $s->taker_id) throw ApiError::forbidden('NO_ATTENDANCE_TAKERS_ASSIGNED', 'HR has not assigned an attendance taker for this occurrence');
            if ((int) $s->taker_id !== $auth->id) throw ApiError::forbidden('NOT_SESSION_TAKER', 'Only the assigned attendance taker can start this session');
            if ($s->status === 'active') {
                // Same taker, already started (a second phone, or the offline start of the same phone).
                return self::serialize($s, $p, $o, $auth) + ['already_started' => true];
            }
            if ($s->status !== 'scheduled') throw ApiError::conflict('ATTENDANCE_CLOSED', 'This session has ended');
            $now = Dates::now();
            $at = $clientAt ?? $now;
            if ($at > $now) $at = $now;
            if ($at < self::availableFrom($o)) {
                if (! $clientAt) throw ApiError::conflict('SESSION_NOT_AVAILABLE', 'Attendance can be started 15 minutes before the program');
                throw ApiError::conflict('SESSION_NOT_AVAILABLE', 'The offline start is earlier than the session was available');
            }
            if ($at >= Dates::of($o['ends_at'])) throw ApiError::conflict('ATTENDANCE_CLOSED', 'The program has already ended');
            DB::table('attendance_sessions')->where('id', $s->id)->update([
                'status' => 'active', 'started_at' => Dates::sql($at), 'started_by' => $auth->id,
                'start_source' => $clientAt ? 'offline' : 'server', 'client_started_at' => $clientRaw ? Dates::sql($clientRaw) : null, 'client_uuid' => $clientUuid,
            ]);
            Audit::log($actx, 'attendance.session_start', 'attendance_session', (int) $s->id, ['program_id' => $programId, 'date' => $o['date'], 'started_at' => Dates::sql($at), 'source' => $clientAt ? 'offline' : 'server'], inTrx: true);
            return self::serialize(self::of($p, $o), $p, $o, $auth);
        });
    }

    /** End the session: the taker, or HR (attendance.close). Also records the closure (history). */
    public static function end(array $actx, int $programId, ?string $date, ?\DateTimeInterface $clientAt = null): array
    {
        $auth = $actx['auth'];
        return DB::transaction(function () use ($actx, $auth, $programId, $date, $clientAt) {
            $p = Attendance::getProgram($programId);
            $o = Attendance::resolveOccurrence($p, $date);
            $s = self::of($p, $o, true);
            $isTaker = $s->taker_id && (int) $s->taker_id === $auth->id;
            if (! $isTaker && ! $auth->can('attendance.close')) throw ApiError::forbidden('NOT_SESSION_TAKER', 'Only the taker or HR can end this session');
            if ($s->status === 'ended') return self::serialize($s, $p, $o, $auth) + ['already_ended' => true];
            if ($s->status !== 'active') throw ApiError::conflict('SESSION_NOT_STARTED', 'The session has not been started');
            $now = Dates::now();
            $at = $clientAt && $clientAt < $now ? $clientAt : $now;
            if ($at < Dates::of($s->started_at)) $at = $now;
            DB::table('attendance_sessions')->where('id', $s->id)->update(['status' => 'ended', 'ended_at' => Dates::sql($at), 'ended_by' => $auth->id, 'end_reason' => $isTaker ? 'taker' : 'hr']);
            DB::table('attendance_closures')->insertOrIgnore(['program_id' => $programId, 'occurrence_date' => $o['date'], 'closed_by' => $auth->id, 'closed_at' => Dates::sql($at)]);
            Audit::log($actx, Audit::ATTENDANCE_CLOSE, 'attendance_session', (int) $s->id, ['program_id' => $programId, 'date' => $o['date'], 'ended_at' => Dates::sql($at), 'by' => $isTaker ? 'taker' : 'hr'], inTrx: true);
            return self::serialize(self::of($p, $o), $p, $o, $auth);
        });
    }

    /** HR assigns (or replaces — a recorded substitute) the one taker of an occurrence. */
    public static function assign(array $actx, int $programId, ?string $date, int $takerId, ?string $reason): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('attendance.assign')) throw ApiError::forbidden('NOT_ALLOWED', 'Only HR assigns attendance takers');
        return DB::transaction(function () use ($actx, $auth, $programId, $date, $takerId, $reason) {
            $p = Attendance::getProgram($programId);
            $o = Attendance::resolveOccurrence($p, $date);
            $s = self::of($p, $o, true);
            if (in_array($s->status, ['ended', 'cancelled'], true)) throw ApiError::conflict('ATTENDANCE_CLOSED', 'This session has ended');
            self::assertTakerAccount($takerId);
            if ($s->status === 'active' && ! trim((string) $reason)) throw ApiError::field('reason', 'REASON_REQUIRED');
            $before = $s->taker_id ? (int) $s->taker_id : null;
            DB::table('attendance_sessions')->where('id', $s->id)->update(['taker_id' => $takerId, 'assigned_by' => $auth->id, 'assigned_at' => Dates::sql(Dates::now())]);
            Audit::log($actx, 'attendance.session_assign', 'attendance_session', (int) $s->id, ['program_id' => $programId, 'date' => $o['date'], 'from' => $before, 'to' => $takerId, 'reason' => $reason, 'while_active' => $s->status === 'active'], inTrx: true);
            return self::serialize(self::of($p, $o), $p, $o, $auth);
        });
    }

    public static function assertTakerAccount(int $userId): void
    {
        $ok = DB::table('users')->where(['id' => $userId, 'status' => 'active'])->whereNull('deleted_at')->exists();
        if (! $ok) throw ApiError::field('user_id', 'USER_NOT_FOUND');
    }

    // ------------------------------------------------------------------ offline conflicts
    /** Keep offline work the server could not apply as sent (with its signature) for HR. */
    public static function recordConflict(array $c): int
    {
        if (! empty($c['client_event_id'])) {
            $existing = DB::table('attendance_sync_conflicts')->where('client_event_id', $c['client_event_id'])->value('id');
            if ($existing) return (int) $existing;
        }
        $sig = null;
        if (! empty($c['signature'])) {
            try {
                $sig = Storage::save('signature', Storage::FOLDERS['SIGNATURES'], Storage::decodeDataUrl($c['signature']));
            } catch (ApiError) {
                $sig = null; // an unreadable signature is noted in the payload, the rest is kept
            }
        }
        $payload = $c['payload'] ?? [];
        unset($payload['signature']);
        if (! empty($c['signature']) && ! $sig) $payload['signature_unreadable'] = true;
        if (! empty($c['batch_id']) && ! isset($payload['batch_id'])) {
            $payload['batch_id'] = $c['batch_id'];
        }
        $insert = [
            'kind' => $c['kind'], 'code' => $c['code'], 'program_id' => $c['program_id'] ?? null, 'class_id' => $c['class_id'] ?? null, 'occurrence_date' => $c['date'],
            'user_id' => $c['user_id'] ?? null, 'submitted_by' => $c['submitted_by'], 'client_event_id' => $c['client_event_id'] ?? null,
            'client_captured_at' => isset($c['client_captured_at']) ? Dates::sql($c['client_captured_at']) : null,
            'captured_at' => isset($c['captured_at']) ? Dates::sql($c['captured_at']) : null,
            'payload' => json_encode($payload, JSON_UNESCAPED_UNICODE), 'signature_path' => $sig['path'] ?? null, 'signature_sha256' => $sig['sha256'] ?? null,
        ];
        if (! empty($c['batch_id']) && Schema::hasColumn('attendance_sync_conflicts', 'batch_id')) {
            $insert['batch_id'] = $c['batch_id'];
        }
        return (int) DB::table('attendance_sync_conflicts')->insertGetId($insert);
    }

    public static function conflicts(array $f, array $page): array
    {
        $hasBatch = Schema::hasColumn('attendance_sync_conflicts', 'batch_id');
        $qb = DB::table('attendance_sync_conflicts as c')->leftJoin('programs as p', 'p.id', '=', 'c.program_id')
            ->leftJoin('edu_classes as ec', 'ec.id', '=', 'c.class_id')
            ->leftJoin('users as u', 'u.id', '=', 'c.user_id')->join('users as s', 's.id', '=', 'c.submitted_by')->leftJoin('users as r', 'r.id', '=', 'c.resolved_by')
            ->select('c.id', 'c.kind', 'c.code', $hasBatch ? 'c.batch_id' : DB::raw('NULL as batch_id'), 'c.program_id', 'p.title as program_title', 'c.class_id', 'ec.name as class_name', 'c.occurrence_date', 'c.user_id', 'u.full_name', 'c.submitted_by', 's.full_name as submitted_by_name',
                'c.client_captured_at', 'c.captured_at', 'c.status', 'c.resolved_by', 'r.full_name as resolved_by_name', 'c.resolved_at', 'c.resolution_note', 'c.created_at',
                DB::raw('c.signature_path IS NOT NULL as has_signature'), 'c.payload')
            ->orderByRaw("c.status = 'open' DESC")->orderByDesc('c.id');
        if (! empty($f['status'])) $qb->where('c.status', $f['status']);
        if (! empty($f['program_id'])) $qb->where('c.program_id', $f['program_id']);
        if (! empty($f['class_id'])) $qb->where('c.class_id', $f['class_id']);
        if (! empty($f['batch_id']) && $hasBatch) $qb->where('c.batch_id', $f['batch_id']);
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(function ($r) {
            $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
            $r->payload = json_decode((string) $r->payload, true);
            $r->has_signature = (bool) $r->has_signature;
            if (empty($r->batch_id) && ! empty($r->payload['batch_id'])) {
                $r->batch_id = $r->payload['batch_id'];
            }
            return $r;
        }, $res['items']);
        return $res;
    }

    /**
     * Group related offline attendance conflicts by their original sync batch (F-04).
     * Shows affected members count, occurrence date, program, submitter, error codes, and review progress.
     */
    public static function conflictBatches(array $f, array $page): array
    {
        $hasBatch = Schema::hasColumn('attendance_sync_conflicts', 'batch_id');
        if (! $hasBatch) {
            return ['items' => [], 'meta' => ['page' => 1, 'limit' => 20, 'total' => 0, 'pages' => 0]];
        }

        $qb = DB::table('attendance_sync_conflicts as c')
            ->join('programs as p', 'p.id', '=', 'c.program_id')
            ->join('users as s', 's.id', '=', 'c.submitted_by')
            ->whereNotNull('c.batch_id')
            ->groupBy('c.batch_id', 'c.program_id', 'p.title', 'c.occurrence_date', 'c.submitted_by', 's.full_name')
            ->select(
                'c.batch_id',
                'c.program_id',
                'p.title as program_title',
                'c.occurrence_date',
                'c.submitted_by',
                's.full_name as submitted_by_name',
                DB::raw('COUNT(*) as total_conflicts'),
                DB::raw("SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) as open_count"),
                DB::raw("SUM(CASE WHEN c.status = 'accepted' THEN 1 ELSE 0 END) as accepted_count"),
                DB::raw("SUM(CASE WHEN c.status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
                DB::raw('MIN(c.code) as primary_code'),
                DB::raw('MIN(c.created_at) as created_at')
            )
            ->orderByRaw("SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) > 0 DESC")
            ->orderByDesc(DB::raw('MIN(c.created_at)'));

        if (! empty($f['status'])) {
            if ($f['status'] === 'open') {
                $qb->havingRaw("SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) > 0");
            } elseif ($f['status'] === 'resolved') {
                $qb->havingRaw("SUM(CASE WHEN c.status = 'open' THEN 1 ELSE 0 END) = 0");
            }
        }
        if (! empty($f['program_id'])) {
            $qb->where('c.program_id', $f['program_id']);
        }

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(function ($r) {
            $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
            $r->total_conflicts = (int) $r->total_conflicts;
            $r->open_count = (int) $r->open_count;
            $r->accepted_count = (int) $r->accepted_count;
            $r->rejected_count = (int) $r->rejected_count;
            $r->status = $r->open_count > 0 ? 'open' : ($r->rejected_count === 0 ? 'accepted' : ($r->accepted_count === 0 ? 'rejected' : 'resolved'));
            return $r;
        }, $res['items']);

        return $res;
    }

    /**
     * HR resolves multiple conflicts in a batch or list (F-04).
     * Enforces attendance.override, self-approval prohibitions, transactional safety,
     * independent record validation, and choir eligibility recomputation.
     */
    public static function bulkResolveConflicts(array $actx, array $input): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('attendance.override') && ! $auth->isSystem) {
            throw ApiError::forbidden('FORBIDDEN', 'Permission attendance.override required');
        }

        $batchId = ! empty($input['batch_id']) ? (string) $input['batch_id'] : null;
        $conflictIds = ! empty($input['conflict_ids']) ? array_values(array_unique(array_filter($input['conflict_ids']))) : [];
        $decision = $input['decision'];
        $note = $input['note'];

        if (empty($batchId) && empty($conflictIds)) {
            throw ApiError::validation('BATCH_OR_IDS_REQUIRED', 'Either batch_id or conflict_ids must be provided');
        }

        $affectedUserIds = [];
        $resolvedIds = [];
        $skippedIds = [];

        DB::transaction(function () use ($actx, $auth, $batchId, $conflictIds, $decision, $note, &$affectedUserIds, &$resolvedIds, &$skippedIds) {
            $qb = DB::table('attendance_sync_conflicts')->lockForUpdate();
            if (! empty($batchId) && ! empty($conflictIds)) {
                $qb->where(function ($q) use ($batchId, $conflictIds) {
                    $q->where('batch_id', $batchId)->orWhereIn('id', $conflictIds);
                });
            } elseif (! empty($batchId)) {
                $qb->where('batch_id', $batchId);
            } else {
                $qb->whereIn('id', $conflictIds);
            }

            $rows = $qb->get();
            if ($rows->isEmpty()) {
                throw ApiError::notFound('CONFLICTS_NOT_FOUND', 'No matching conflicts found');
            }

            // Self-approval prohibition: none of the conflicts may be submitted by current resolver
            foreach ($rows as $r) {
                if ((int) $r->submitted_by === $auth->id && ! $auth->isSystem) {
                    throw ApiError::forbidden('SELF_APPROVAL_FORBIDDEN', 'Another HR member must decide this');
                }
            }

            $nowSql = Dates::sql(Dates::now());

            foreach ($rows as $c) {
                if ($c->status !== 'open') {
                    $skippedIds[] = (int) $c->id;
                    continue;
                }

                $attendanceId = null;
                $resultNote = $note;

                if ($decision === 'accept' && $c->kind === 'record' && $c->user_id) {
                    $payload = json_decode((string) $c->payload, true) ?: [];
                    $attendanceId = Attendance::applyAcceptedConflict($actx, $c, $payload);
                    if ($attendanceId === null) {
                        $resultNote = trim($note . ' (already recorded — nothing changed)');
                    }
                    $affectedUserIds[] = (int) $c->user_id;
                }

                DB::table('attendance_sync_conflicts')->where('id', $c->id)->update([
                    'status' => $decision === 'accept' ? 'accepted' : 'rejected',
                    'resolved_by' => $auth->id,
                    'resolved_at' => $nowSql,
                    'resolution_note' => mb_substr($resultNote, 0, 1000),
                    'attendance_id' => $attendanceId,
                ]);

                Audit::log($actx, 'attendance.conflict_' . ($decision === 'accept' ? 'accept' : 'reject'), 'attendance_sync_conflict', (int) $c->id, [
                    'program_id' => $c->program_id ? (int) $c->program_id : null,
                    'class_id' => $c->class_id ? (int) $c->class_id : null,
                    'date' => Dates::toDateOnly($c->occurrence_date),
                    'user_id' => $c->user_id,
                    'code' => $c->code,
                    'batch_id' => $c->batch_id ?? null,
                    'attendance_id' => $attendanceId,
                    'note' => $note,
                ], inTrx: true);

                $resolvedIds[] = (int) $c->id;
            }

            if (! empty($batchId) && ! empty($resolvedIds)) {
                Audit::log($actx, 'attendance.conflict_bulk_resolve', 'attendance_sync_conflict_batch', null, [
                    'batch_id' => $batchId,
                    'decision' => $decision,
                    'resolved_count' => count($resolvedIds),
                    'skipped_count' => count($skippedIds),
                    'note' => $note,
                ], inTrx: true);
            }
        });

        if (! empty($affectedUserIds)) {
            Choir::scheduleEligibility(array_values(array_unique($affectedUserIds)));
        }

        return [
            'success' => true,
            'decision' => $decision,
            'total' => count($resolvedIds) + count($skippedIds),
            'resolved' => count($resolvedIds),
            'accepted' => $decision === 'accept' ? count($resolvedIds) : 0,
            'rejected' => $decision === 'reject' ? count($resolvedIds) : 0,
            'skipped' => count($skippedIds),
            'batch_id' => $batchId,
            'resolved_ids' => $resolvedIds,
            'skipped_ids' => $skippedIds,
        ];
    }

    /**
     * HR decides an offline conflict (attendance.override). Accepting a record writes the attendance
     * as captured (its own time and signature) unless the member is already recorded; the decision,
     * the resolver and the note are kept. Nobody resolves their own submission.
     */
    public static function resolveConflict(array $actx, int $id, string $decision, string $note): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('attendance.override') && ! $auth->isSystem) {
            throw ApiError::forbidden('FORBIDDEN', 'Permission attendance.override required');
        }

        $userId = null;
        DB::transaction(function () use ($actx, $auth, $id, $decision, $note, &$userId) {
            $c = DB::table('attendance_sync_conflicts')->where('id', $id)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CONFLICT_NOT_FOUND', 'Not found');
            if ($c->status !== 'open') throw ApiError::conflict('CONFLICT_RESOLVED', 'Already decided');
            if ((int) $c->submitted_by === $auth->id && ! $auth->isSystem) throw ApiError::forbidden('SELF_APPROVAL_FORBIDDEN', 'Another HR member must decide this');
            $attendanceId = null;
            $resultNote = $note;
            if ($decision === 'accept' && $c->kind === 'record' && $c->user_id) {
                $payload = json_decode((string) $c->payload, true) ?: [];
                $attendanceId = Attendance::applyAcceptedConflict($actx, $c, $payload);
                if ($attendanceId === null) $resultNote = trim($note . ' (already recorded — nothing changed)');
                $userId = (int) $c->user_id;
            }
            DB::table('attendance_sync_conflicts')->where('id', $id)->update([
                'status' => $decision === 'accept' ? 'accepted' : 'rejected', 'resolved_by' => $auth->id, 'resolved_at' => Dates::sql(Dates::now()),
                'resolution_note' => mb_substr($resultNote, 0, 1000), 'attendance_id' => $attendanceId,
            ]);
            Audit::log($actx, 'attendance.conflict_' . ($decision === 'accept' ? 'accept' : 'reject'), 'attendance_sync_conflict', $id, [
                'program_id' => $c->program_id ? (int) $c->program_id : null, 'class_id' => $c->class_id ? (int) $c->class_id : null, 'date' => Dates::toDateOnly($c->occurrence_date), 'user_id' => $c->user_id, 'code' => $c->code, 'attendance_id' => $attendanceId, 'note' => $note,
            ], inTrx: true);
        });
        if ($userId) Choir::scheduleEligibility([$userId]);
        $row = DB::table('attendance_sync_conflicts')->where('id', $id)->first();
        $row->occurrence_date = Dates::toDateOnly($row->occurrence_date);
        return (array) $row;
    }

    public static function conflictSignature(int $id): array
    {
        $c = DB::table('attendance_sync_conflicts')->where('id', $id)->first(['signature_path']);
        if (! $c || ! $c->signature_path) throw ApiError::notFound('SIGNATURE_NOT_FOUND', 'No signature');
        return ['abs' => Storage::privatePath($c->signature_path), 'mime' => 'image/png'];
    }
}
