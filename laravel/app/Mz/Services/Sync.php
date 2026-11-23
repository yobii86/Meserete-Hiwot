<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\BorrowSchemas;
use App\Mz\Support\Dates;
use App\Mz\Support\ProgramSchemas;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Offline synchronisation (port of syncService.js). Each queued op carries a client UUID; it is
 * applied at most once (sync_receipts), results are reported per op, and newer server data is
 * never silently overwritten (optimistic concurrency → "conflict").
 */
final class Sync
{
    private static ?array $ops = null;

    private static function posId()
    {
        return Z::number()->int()->positive();
    }

    private static function isoDate()
    {
        return Z::string()->regex('/^\d{4}-\d{2}-\d{2}$/');
    }

    private static function mezmurRef()
    {
        return Z::object(['mezmur_id' => self::posId()]);
    }

    /** "Already gone" is the goal of a delete — treat not-found as done. */
    private static function ignoreNotFound(callable $fn): array
    {
        try {
            $fn();
            return ['changed' => true];
        } catch (ApiError $e) {
            if ($e->status === 404) return ['changed' => false];
            throw $e;
        }
    }

    /** type => [schema, run(userId, payload, op, ctx), permission?] */
    public static function ops(): array
    {
        return self::$ops ??= [
            'favorite.add' => [self::mezmurRef(), fn ($uid, $p) => ['changed' => Mezmurs::addFavorite($uid, $p['mezmur_id'])]],
            'favorite.remove' => [self::mezmurRef(), function ($uid, $p, $op) {
                // A favorite (re)created on the server after this offline removal wins.
                $fav = DB::table('favorites')->where(['user_id' => $uid, 'mezmur_id' => $p['mezmur_id']])->first(['created_at']);
                if ($fav && ! empty($op['client_ts']) && Dates::of($fav->created_at) > Dates::of($op['client_ts'])) {
                    return ['conflict' => true, 'server' => ['is_favorite' => true]];
                }
                return ['changed' => Mezmurs::removeFavorite($uid, $p['mezmur_id'])];
            }],
            'download.add' => [self::mezmurRef()->extend(['with_audio' => Z::boolean()->default(false)]), function ($uid, $p) {
                Mezmurs::recordDownload($uid, $p['mezmur_id'], $p['with_audio']);
                return ['changed' => true];
            }],
            'download.remove' => [self::mezmurRef(), fn ($uid, $p) => ['changed' => Mezmurs::removeDownload($uid, $p['mezmur_id'])]],
            'reminder.create' => [ProgramSchemas::reminderCreate(), function ($uid, $p) {
                $out = Reminders::create($uid, $p);
                return ['changed' => $out['created'], 'server' => $out['reminder']];
            }],
            'reminder.update' => [ProgramSchemas::reminderUpdate()->extend(['client_uuid' => Z::string()->uuid()]), function ($uid, $p) {
                $uuid = $p['client_uuid'];
                unset($p['client_uuid']);
                return ['changed' => true, 'server' => Reminders::update($uid, $uuid, $p)];
            }],
            'reminder.delete' => [Z::object(['client_uuid' => Z::string()->uuid()]), fn ($uid, $p) => ['changed' => Reminders::remove($uid, $p['client_uuid'])]],
            'activity' => [Z::object([
                'action' => Z::string()->refine(fn ($a) => in_array($a, Activity::CLIENT_REPORTABLE, true)),
                'entity_type' => Z::enum(['mezmur', 'program', 'notification', 'page', 'category'])->optional(),
                'entity_id' => self::posId()->optional(),
                'metadata' => Z::record(Z::union([Z::string()->max(200), Z::number(), Z::boolean()]))->optional(),
                'occurred_at' => Z::coerceDate()->optional(),
            ]), function ($uid, $p, $op) {
                Activity::track($uid, $p['action'], $p['entity_type'] ?? null, $p['entity_id'] ?? null, $p['metadata'] ?? null, $op['op_id'], $p['occurred_at'] ?? null);
                return ['changed' => true];
            }],
            // ---- Staff work that must keep going offline ----
            // Attendance (the session's assigned taker — checked in the services, as online). Times
            // captured on the phone are corrected by the phone's clock skew (ctx offset). Offline work
            // the server cannot apply as sent is kept in the HR conflict queue, never dropped.
            'attendance.session.start' => [Z::object(['program_id' => self::posId(), 'date' => self::isoDate(), 'session_uuid' => Z::string()->uuid()->optional()]),
                fn ($uid, $p, $op, $ctx) => self::sessionOp($ctx, $op, $p, 'session_start', fn ($at, $raw) => AttendanceSessions::start($ctx['actx'], $p['program_id'], $p['date'], $at, $raw, $p['session_uuid'] ?? null))],
            'attendance.session.end' => [Z::object(['program_id' => self::posId(), 'date' => self::isoDate()]),
                fn ($uid, $p, $op, $ctx) => self::sessionOp($ctx, $op, $p, 'session_end', fn ($at) => AttendanceSessions::end($ctx['actx'], $p['program_id'], $p['date'], $at))],
            'attendance.record' => [Z::object([
                'program_id' => self::posId(), 'user_id' => self::posId(), 'date' => self::isoDate(),
                'status' => ProgramSchemas::attendanceStatus(), 'notes' => Z::string()->max(500)->nullish(), 'via' => Z::enum(['qr', 'manual'])->optional(),
                'signature' => ProgramSchemas::signature()->nullish(), 'captured_offline' => Z::boolean()->optional(), 'session_uuid' => Z::string()->uuid()->nullish(),
            ]), fn ($uid, $p, $op, $ctx) => self::recordOp($ctx, $op, $p)],
            // Older app versions (no session, no signature): the same rules apply — what cannot be
            // recorded (e.g. unsigned) goes to the HR queue with the member and time.
            'attendance.set' => [Z::object([
                'program_id' => self::posId(), 'user_id' => self::posId(), 'status' => Z::enum(['present', 'late', 'absent', 'excused']), 'date' => self::isoDate(),
                'notes' => Z::string()->max(500)->nullish(), 'via' => Z::enum(['qr', 'manual'])->optional(),
            ]), fn ($uid, $p, $op, $ctx) => self::recordOp($ctx, $op, ['status' => $p['status'] === 'late' ? 'present' : $p['status'], 'captured_offline' => true] + $p)],
            'attendance.clear' => [Z::object(['program_id' => self::posId(), 'user_id' => self::posId(), 'date' => self::isoDate(), 'reason' => Z::string()->max(500)->nullish()]),
                fn ($uid, $p, $op, $ctx) => self::ignoreNotFound(fn () => Attendance::remove($ctx['actx'], $p['program_id'], $p['user_id'], $p['date'], $p['reason'] ?? 'Cleared on the phone'))],
            'attendance.bulk' => [Z::object([
                'program_id' => self::posId(), 'user_ids' => Z::array(self::posId())->min(1)->max(1000), 'status' => Z::enum(['present', 'late', 'absent', 'excused']), 'date' => self::isoDate(),
                'notes' => Z::string()->max(500)->nullish(),
            ]), function ($uid, $p, $op, $ctx) {
                if ($p['status'] === 'present' || $p['status'] === 'late') {
                    // Older apps marked "present" for many at once; each member now needs their own
                    // signed record, so each one is tried alone and what cannot be applied goes to HR.
                    $out = [];
                    $members = array_values(array_unique($p['user_ids']));
                    $batchTotal = count($members);
                    foreach ($members as $memberId) {
                        $h = md5($op['op_id'] . ':' . $memberId);
                        $one = ['op_id' => substr($h, 0, 8) . '-' . substr($h, 8, 4) . '-4' . substr($h, 13, 3) . '-a' . substr($h, 17, 3) . '-' . substr($h, 20, 12)] + $op;
                        $out[$memberId] = self::recordOp($ctx, $one, [
                            'user_id' => $memberId,
                            'status' => 'present',
                            'captured_offline' => true,
                            'batch_id' => $op['op_id'],
                            'batch_type' => 'attendance.bulk',
                            'batch_total' => $batchTotal,
                        ] + $p);
                    }
                    $conflicts = array_filter($out, fn ($r) => ! empty($r['conflict']));
                    return ['changed' => count($conflicts) < count($out), 'server' => ['batch_id' => $op['op_id'], 'members' => $out, 'sent_to_hr' => count($conflicts)]];
                }
                $in = ['target' => ['user_ids' => $p['user_ids']], 'status' => $p['status'], 'date' => $p['date']];
                if (isset($p['notes'])) $in['notes'] = $p['notes'];
                Attendance::bulkSet($ctx['actx'], $p['program_id'], $in, false);
                return ['changed' => true];
            }],
            // 'late' from older apps' queues is recorded as present (there is no late status any more).
            'edu_attendance.set' => [Z::object(['class_id' => self::posId(), 'user_id' => self::posId(), 'date' => self::isoDate(), 'status' => Z::enum(['present', 'late', 'absent', 'excused'])]),
                function ($uid, $p, $op, $ctx) {
                    $cutover = Settings::eduAttendanceCutover();
                    if ($p['date'] >= $cutover) {
                        [$at, $raw] = self::times($ctx, $op);
                        $cid = AttendanceSessions::recordConflict([
                            'kind' => 'legacy_class',
                            'code' => 'EDU_ATTENDANCE_MOVED',
                            'class_id' => $p['class_id'],
                            'program_id' => null,
                            'date' => $p['date'],
                            'user_id' => $p['user_id'],
                            'submitted_by' => $ctx['auth']->id,
                            'client_event_id' => $op['op_id'],
                            'client_captured_at' => $raw,
                            'captured_at' => $at,
                            'payload' => $p,
                        ]);
                        return ['conflict' => true, 'code' => 'EDU_ATTENDANCE_MOVED', 'server' => ['conflict_id' => $cid, 'code' => 'EDU_ATTENDANCE_MOVED', 'sent_to_hr' => true]];
                    }
                    Edu::mark($ctx['auth'], $p['class_id'], ['date' => $p['date'], 'user_id' => $p['user_id'], 'status' => $p['status'] === 'late' ? 'present' : $p['status']]);
                    return ['changed' => true];
                }],
            'edu_attendance.scan' => [Z::object(['class_id' => self::posId(), 'uuid' => Z::string()->uuid(), 'date' => self::isoDate(), 'status' => Z::enum(['present'])->default('present')]),
                function ($uid, $p, $op, $ctx) {
                    $cutover = Settings::eduAttendanceCutover();
                    if ($p['date'] >= $cutover) {
                        [$at, $raw] = self::times($ctx, $op);
                        $userId = null;
                        try {
                            $userId = Members::idByUuid($p['uuid']);
                        } catch (\Throwable) {}
                        $cid = AttendanceSessions::recordConflict([
                            'kind' => 'legacy_class',
                            'code' => 'EDU_ATTENDANCE_MOVED',
                            'class_id' => $p['class_id'],
                            'program_id' => null,
                            'date' => $p['date'],
                            'user_id' => $userId,
                            'submitted_by' => $ctx['auth']->id,
                            'client_event_id' => $op['op_id'],
                            'client_captured_at' => $raw,
                            'captured_at' => $at,
                            'payload' => $p,
                        ]);
                        return ['conflict' => true, 'code' => 'EDU_ATTENDANCE_MOVED', 'server' => ['conflict_id' => $cid, 'code' => 'EDU_ATTENDANCE_MOVED', 'sent_to_hr' => true]];
                    }
                    return ['changed' => true, 'server' => Edu::markByQr($ctx['auth'], $p['class_id'], ['date' => $p['date'], 'uuid' => $p['uuid'], 'status' => $p['status']])];
                }],
            'borrowing.create' => [BorrowSchemas::create(), fn ($uid, $p, $op, $ctx) => ['changed' => true, 'server' => Borrowings::create($ctx['actx'], $p)], 'borrowing.manage'],
            'borrowing.return' => [Z::object(BorrowSchemas::returnShape() + ['borrowing_id' => self::posId()]), function ($uid, $p, $op, $ctx) {
                $id = $p['borrowing_id'];
                unset($p['borrowing_id']);
                return ['changed' => true, 'server' => Borrowings::returnItem($ctx['actx'], $id, $p)];
            }, 'borrowing.manage'],
            // Project Management: a task moved / updated while offline. base_version = the task's
            // version the phone last saw; if it changed on the server meanwhile, nothing is applied
            // and the server copy comes back as a conflict (the server stays the source of truth).
            // Permissions are checked exactly as online (TaskService::changeStatus).
            'project.task.update' => [Z::object([
                'task_id' => self::posId(),
                'status' => Z::enum(\App\Mz\Projects\Pm::TASK_STATUSES)->optional(),
                'reason' => Z::string()->max(500)->nullish(),
                'pending_reason' => Z::enum(\App\Mz\Projects\Pm::PENDING_REASONS)->nullish(),
                'progress' => Z::number()->int()->min(0)->max(100)->nullish(),
                'note' => Z::string()->max(1000)->nullish(),
                'base_version' => self::posId()->optional(),
            ]), function ($uid, $p, $op, $ctx) {
                $id = $p['task_id'];
                unset($p['task_id']);
                $p = array_filter($p, fn ($v) => $v !== null);
                $out = \App\Mz\Projects\TaskService::changeStatus(array_merge($ctx['actx'], ['source' => 'offline_sync']), $id, $p);
                if (! empty($out['conflict'])) {
                    \App\Mz\Projects\Pm::log(array_merge($ctx['actx'], ['source' => 'offline_sync']), 'project.task.sync_conflict', $out['task']['project']['id'], ['task_id' => $id, 'base_version' => $p['base_version'] ?? null, 'server_version' => $out['task']['version'], 'attempted' => $p]);
                    return ['conflict' => true, 'server' => $out['task']];
                }
                return ['changed' => true, 'server' => $out['task']];
            }],
            'preferences.update' => [Z::object(['values' => Z::record(Z::any()), 'base_updated_at' => Z::coerceDate()->optional()]), function ($uid, $p) {
                $current = Account::getPreferences($uid);
                if (! empty($p['base_updated_at']) && ! empty($current['updated_at']) && Dates::of($current['updated_at']) > $p['base_updated_at']) {
                    return ['conflict' => true, 'server' => $current];
                }
                return ['changed' => true, 'server' => Account::updatePreferences($uid, $p['values'])];
            }],
            'edu.lesson.complete' => [Z::object(['lesson_id' => self::posId()]), function ($uid, $p, $op, $ctx) {
                return ['changed' => true, 'server' => EduLearning::setProgress($ctx['auth'], $p['lesson_id'], 'complete')];
            }],
            'library.progress' => [Z::object([
                'item_id' => self::posId(),
                'page' => Z::number()->int()->min(1),
                'page_count' => Z::number()->int()->min(1)->optional(),
                'audio_position_ms' => Z::number()->int()->min(0)->default(0),
            ]), function ($uid, $p) {
                return ['changed' => true, 'server' => Library::saveProgress($uid, $p['item_id'], $p)];
            }],
            'library.favorite.add' => [Z::object(['item_id' => self::posId()]), function ($uid, $p) {
                return ['changed' => true, 'server' => Library::favorite($uid, $p['item_id'], true)];
            }],
            'library.favorite.remove' => [Z::object(['item_id' => self::posId()]), function ($uid, $p, $op) {
                $fav = DB::table('library_favorites')->where(['user_id' => $uid, 'item_id' => $p['item_id']])->first(['created_at']);
                if ($fav && ! empty($op['client_ts']) && Dates::of($fav->created_at) > Dates::of($op['client_ts'])) {
                    return ['conflict' => true, 'server' => ['is_favorite' => true]];
                }
                return ['changed' => true, 'server' => Library::favorite($uid, $p['item_id'], false)];
            }],
            'library.checkout' => [Z::object([
                'copy_code' => Z::string(),
                'user_id' => self::posId(),
                'due_on' => self::isoDate(),
                'signature' => BorrowSchemas::signature(),
                'condition_out' => Z::enum(LibraryCirculation::CONDITIONS)->optional(),
                'notes' => Z::string()->max(500)->nullish(),
            ]), function ($uid, $p, $op, $ctx) {
                try {
                    $loan = LibraryCirculation::checkout($ctx['actx'], [
                        'copy_code' => $p['copy_code'],
                        'user_id' => $p['user_id'],
                        'due_on' => $p['due_on'],
                        'signature' => $p['signature'],
                        'condition_out' => $p['condition_out'] ?? 'good',
                        'notes' => $p['notes'] ?? null,
                    ]);
                    return ['changed' => true, 'server' => $loan];
                } catch (ApiError $e) {
                    if ($e->errorCode === 'COPY_ON_LOAN' || $e->errorCode === 'COPY_NOT_FOUND') {
                        $conflictId = LibraryCirculation::recordConflict([
                            'kind' => 'checkout',
                            'code' => $e->errorCode,
                            'copy_code' => $p['copy_code'],
                            'user_id' => $p['user_id'],
                            'submitted_by' => $ctx['auth']->id,
                            'client_event_id' => $op['op_id'] ?? null,
                            'payload' => $p,
                        ]);
                        return ['conflict' => true, 'code' => $e->errorCode, 'server' => ['conflict_id' => $conflictId, 'code' => $e->errorCode, 'sent_to_review' => true]];
                    }
                    throw $e;
                }
            }, 'library.circulate'],
            'library.return' => [Z::object([
                'copy_code' => Z::string(),
                'condition_in' => Z::enum(LibraryCirculation::CONDITIONS)->optional(),
                'notes' => Z::string()->max(500)->nullish(),
            ]), function ($uid, $p, $op, $ctx) {
                try {
                    $loan = LibraryCirculation::returnCopy($ctx['actx'], [
                        'copy_code' => $p['copy_code'],
                        'condition_in' => $p['condition_in'] ?? 'good',
                        'notes' => $p['notes'] ?? null,
                    ]);
                    return ['changed' => true, 'server' => $loan];
                } catch (ApiError $e) {
                    if ($e->errorCode === 'LOAN_NOT_FOUND' || $e->errorCode === 'ALREADY_RETURNED') {
                        $conflictId = LibraryCirculation::recordConflict([
                            'kind' => 'return',
                            'code' => $e->errorCode,
                            'copy_code' => $p['copy_code'],
                            'submitted_by' => $ctx['auth']->id,
                            'client_event_id' => $op['op_id'] ?? null,
                            'payload' => $p,
                        ]);
                        return ['conflict' => true, 'code' => $e->errorCode, 'server' => ['conflict_id' => $conflictId, 'code' => $e->errorCode, 'sent_to_review' => true]];
                    }
                    throw $e;
                }
            }, 'library.circulate'],
        ];
    }

    public static function requestSchema()
    {
        return Z::object([
            'operations' => Z::array(Z::object([
                'op_id' => Z::string()->uuid(),
                'type' => Z::enum(array_keys(self::ops())),
                'payload' => Z::record(Z::any()),
                'client_ts' => Z::coerceDate()->optional(),
            ]))->max(200),
            'client_now' => Z::coerceDate()->optional(),
        ]);
    }

    /** Offline captures older than this (server − capture) are "offline" work: kept for HR if refused. */
    private const OFFLINE_LAG_SECONDS = 120;

    /** [phone time adjusted to the server clock, the phone's own time] of an op (null = now / online). */
    private static function times(array $ctx, array $op): array
    {
        if (empty($op['client_ts'])) return [null, null];
        $raw = Dates::of($op['client_ts']);
        $at = $raw->modify(($ctx['offset'] >= 0 ? '+' : '') . (int) $ctx['offset'] . ' seconds');
        $now = Dates::now();
        if ($at > $now) $at = $now;
        // Older than 3 days: not believable as a capture time for a live session.
        if ($now->getTimestamp() - $at->getTimestamp() > 3 * 86400) throw ApiError::conflict('CAPTURE_TOO_OLD', 'This offline capture is older than 3 days');
        return [$at, $raw];
    }

    private static function isOffline(?\DateTimeInterface $at, array $p): bool
    {
        if (! empty($p['captured_offline'])) return true;
        return $at !== null && Dates::now()->getTimestamp() - $at->getTimestamp() > self::OFFLINE_LAG_SECONDS;
    }

    private static function errorCode(ApiError $e): string
    {
        if ($e->errorCode === 'VALIDATION_ERROR' && ! empty($e->errors[0]['code'])) return (string) $e->errors[0]['code'];
        return $e->errorCode;
    }

    /** A recorded mark (QR / manual, with its signature) from the phone's queue. */
    private static function recordOp(array $ctx, array $op, array $p): array
    {
        [$at, $raw] = [null, null];
        try {
            [$at, $raw] = self::times($ctx, $op);
            $offline = self::isOffline($at, $p);
            $in = ['status' => $p['status'], 'date' => $p['date'], 'via' => $p['via'] ?? 'manual', 'notes' => $p['notes'] ?? null, 'signature' => $p['signature'] ?? null];
            $r = Attendance::set($ctx['actx'], $p['program_id'], $p['user_id'], $in, ['at' => $offline ? $at : null, 'client_raw' => $raw, 'offline' => $offline, 'event_id' => $op['op_id']]);
            return ['changed' => ! $r['duplicate'], 'server' => ['status' => $r['status'] ?? null, 'duplicate' => $r['duplicate'], 'already_recorded' => $r['already_recorded'] ?? null, 'attended_at' => $r['attended_at'] ?? null, 'elapsed_seconds' => $r['elapsed_seconds'] ?? null]];
        } catch (ApiError $e) {
            if ($e->status >= 500 || ! self::isOffline($at, $p)) throw $e;
            $cid = AttendanceSessions::recordConflict([
                'kind' => 'record', 'code' => self::errorCode($e), 'program_id' => $p['program_id'], 'date' => $p['date'], 'user_id' => $p['user_id'],
                'submitted_by' => $ctx['auth']->id, 'client_event_id' => $op['op_id'], 'client_captured_at' => $raw, 'captured_at' => $at,
                'batch_id' => $p['batch_id'] ?? null,
                'payload' => array_intersect_key($p, array_flip(['status', 'notes', 'via', 'session_uuid', 'batch_id', 'batch_type', 'batch_total'])), 'signature' => $p['signature'] ?? null,
            ]);
            return ['conflict' => true, 'server' => ['conflict_id' => $cid, 'code' => self::errorCode($e), 'batch_id' => $p['batch_id'] ?? null, 'sent_to_hr' => true]];
        }
    }

    /** Session start / end pressed on the phone (offline): applied at its time, or kept for HR. */
    private static function sessionOp(array $ctx, array $op, array $p, string $kind, callable $run): array
    {
        [$at, $raw] = [null, null];
        try {
            [$at, $raw] = self::times($ctx, $op);
            $offline = self::isOffline($at, $p);
            $s = $run($offline ? $at : null, $raw);
            return ['changed' => empty($s['already_started']) && empty($s['already_ended']), 'server' => $s];
        } catch (ApiError $e) {
            if ($e->status >= 500 || ! self::isOffline($at, $p)) throw $e;
            $cid = AttendanceSessions::recordConflict([
                'kind' => $kind, 'code' => self::errorCode($e), 'program_id' => $p['program_id'], 'date' => $p['date'],
                'submitted_by' => $ctx['auth']->id, 'client_event_id' => $op['op_id'], 'client_captured_at' => $raw, 'captured_at' => $at,
                'payload' => array_intersect_key($p, array_flip(['session_uuid'])),
            ]);
            return ['conflict' => true, 'server' => ['conflict_id' => $cid, 'code' => self::errorCode($e), 'sent_to_hr' => true]];
        }
    }

    private static function receipt(int $userId, string $opId, string $status, ?array $result): void
    {
        DB::table('sync_receipts')->insertOrIgnore(['user_id' => $userId, 'op_id' => $opId, 'status' => $status, 'result' => $result ? json_encode($result, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null]);
    }

    /** Operations are applied in the device's queue order. */
    public static function apply(AuthContext $auth, array $operations, array $actx, ?\DateTimeInterface $clientNow = null): array
    {
        // The phone's clock skew (seconds): server now − phone now when the batch was sent.
        $offset = $clientNow ? Dates::now()->getTimestamp() - $clientNow->getTimestamp() : 0;
        $results = [];
        $opIds = array_column($operations, 'op_id');
        $done = [];
        if ($opIds) {
            foreach (DB::table('sync_receipts')->where('user_id', $auth->id)->whereIn('op_id', $opIds)->select('op_id', 'status', 'result')->get() as $r) $done[$r->op_id] = $r;
        }
        $ops = self::ops();
        foreach ($operations as $op) {
            $prior = $done[$op['op_id']] ?? null;
            if ($prior) {
                // Replayed op (the response to a previous attempt was lost) — return the original outcome.
                $results[] = ['op_id' => $op['op_id'], 'status' => 'duplicate', 'original_status' => $prior->status, 'result' => is_string($prior->result) ? json_decode($prior->result, true) : $prior->result];
                continue;
            }
            $handler = $ops[$op['type']];
            $permission = $handler[2] ?? null;
            if ($permission && ! ($auth->isAdmin && $auth->can($permission))) {
                $r = ['op_id' => $op['op_id'], 'status' => 'rejected', 'code' => 'FORBIDDEN'];
                self::receipt($auth->id, $op['op_id'], 'rejected', $r);
                $results[] = $r;
                continue;
            }
            [$valid, $payload] = Z::safeParse($handler[0], $op['payload']);
            if (! $valid) {
                $r = ['op_id' => $op['op_id'], 'status' => 'rejected', 'code' => 'VALIDATION_ERROR'];
                self::receipt($auth->id, $op['op_id'], 'rejected', $r);
                $results[] = $r;
                continue;
            }
            try {
                $out = ($handler[1])($auth->id, $payload, $op, ['auth' => $auth, 'actx' => $actx, 'offset' => $offset]);
                $status = ! empty($out['conflict']) ? 'conflict' : 'applied';
                $r = ['op_id' => $op['op_id'], 'status' => $status, 'server' => $out['server'] ?? null];
                self::receipt($auth->id, $op['op_id'], $status, $r);
                $results[] = $r;
            } catch (ApiError $e) {
                if ($e->status >= 500) {
                    Log::error('sync op failed', ['type' => $op['type'], 'err' => $e->getMessage()]);
                    $results[] = ['op_id' => $op['op_id'], 'status' => 'retry'];
                    continue;
                }
                $status = $e->errorCode === 'SYNC_CONFLICT' ? 'conflict' : 'rejected';
                $server = null;
                if ($status === 'conflict') $server = json_decode((string) ($e->errors[0]['message'] ?? 'null'), true);
                $r = ['op_id' => $op['op_id'], 'status' => $status, 'code' => $e->errorCode, 'server' => $server];
                self::receipt($auth->id, $op['op_id'], $status, $r);
                $results[] = $r;
            } catch (\Throwable $e) {
                // Transient failure: no receipt, so the client retries this op later.
                Log::error('sync op failed', ['type' => $op['type'], 'err' => $e->getMessage()]);
                $results[] = ['op_id' => $op['op_id'], 'status' => 'retry'];
            }
        }
        return ['results' => $results, 'server_time' => Dates::now()];
    }
}
