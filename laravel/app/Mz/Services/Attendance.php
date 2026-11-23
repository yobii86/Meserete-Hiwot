<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Db\UtcDateTime;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\EthiopianCalendar;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Program attendance per occurrence (port of attendanceService.js), taken inside the occurrence's
 * attendance session (AttendanceSessions): only the one assigned taker records, only between the
 * official Start and the end. Each "present" mark keeps its real capture time, the seconds since
 * the official start and the member's signature (unless HR exempts the member's group); "excused"
 * needs a reason; unmarked = absent once the occurrence has closed. There is no late status any
 * more — how early someone came is scored from the elapsed time where it is needed (selection).
 * Rows recorded before sessions existed ("legacy", possibly "late") are kept and read as before.
 */
final class Attendance
{
    public const MARKABLE = ['present', 'excused'];
    private const PROGRAM_COLS = ['id', 'title', 'status', 'starts_at', 'ends_at', 'recurrence', 'monthly_rule', 'recurrence_until', 'ethiopian_days', 'audience', 'category_id', 'requires_attendance', 'member_groups', 'is_additional', 'counts_for_selection'];
    private const DAY_PRIORITY = ['absent', 'late', 'excused', 'present', 'today', 'upcoming'];

    public static function getProgram(int $id): object
    {
        $p = DB::table('programs')->where('id', $id)->first(self::PROGRAM_COLS);
        if (! $p || $p->status === 'draft') throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        return $p;
    }

    /** The given date, else today's, else the most recent past occurrence, else the next. */
    public static function resolveOccurrence(object $p, ?string $date, ?\DateTimeInterface $now = null): ?array
    {
        if ($date) {
            $o = Schedule::on($p, $date, null, true);
            if (! $o) throw ApiError::field('date', 'NOT_AN_OCCURRENCE');
            return $o;
        }
        $now ??= Dates::now();
        $today = Dates::todayLocal($now);
        $past = Schedule::between($p, Dates::addDays($today, -400), $today);
        if ($past) return end($past);
        $next = Schedule::next($p, $now);
        if ($next) return $next;
        $all = Schedule::between($p, '1900-01-01', '2999-12-31');
        return $all ? end($all) : null;
    }

    public static function isActive(array $o, ?\DateTimeInterface $now = null): bool
    {
        return Schedule::localDate($o['starts_at']) <= Dates::todayLocal($now);
    }

    private static function hasEnded(array $o, ?\DateTimeInterface $now = null): bool
    {
        return $o['ends_at'] < ($now ?? Dates::now());
    }

    private static function closureOf(int $programId, string $date): ?object
    {
        return DB::table('attendance_closures')->where(['program_id' => $programId, 'occurrence_date' => $date])->first(['closed_at', 'closed_by']);
    }

    private static function isClosed(object $p, array $o, ?\DateTimeInterface $at = null): bool
    {
        $at ??= Dates::now();
        if (self::hasEnded($o, $at)) return true;
        $c = self::closureOf($p->id, $o['date']);
        return (bool) ($c && Dates::of($c->closed_at) <= $at);
    }

    /** Members of these groups mark attendance without signing (HR setting, audited). */
    public static function signatureExempt(?string $memberGroup): bool
    {
        return $memberGroup !== null && in_array($memberGroup, Settings::signaturePolicy()['exempt_groups'], true);
    }

    public static function groupsOf(object $p): array
    {
        return $p->member_groups ? array_values(array_filter(explode(',', $p->member_groups))) : [];
    }

    private static function inGroups(Builder $qb, object $p): Builder
    {
        $groups = self::groupsOf($p);
        if ($groups) $qb->whereIn('u.member_group', $groups);
        return $qb;
    }

    private static function assertInGroups(object $p, int $userId): void
    {
        if (! self::inGroups(MemberIds::memberAccounts(DB::table('users as u')), $p)->where('u.id', $userId)->exists()) {
            throw ApiError::conflict('MEMBER_NOT_EXPECTED', "This member is not in the program's target group");
        }
    }

    public static function hasLinkedClasses(int $programId): bool
    {
        return Schema::hasTable('program_edu_classes')
            && DB::table('program_edu_classes')->where('program_id', $programId)->exists();
    }

    public static function isEducationProgram(object|int $program): bool
    {
        $id = is_object($program) ? $program->id : $program;
        if (self::hasLinkedClasses($id)) return true;
        $catId = is_object($program) ? ($program->category_id ?? null) : DB::table('programs')->where('id', $id)->value('category_id');
        if (! $catId || ! Schema::hasTable('program_categories') || ! Schema::hasColumn('program_categories', 'is_education')) return false;
        return (bool) DB::table('program_categories')->where('id', $catId)->value('is_education');
    }

    public static function expectedMembers(object $p, string $occurrenceDate = ''): Builder
    {
        $occurrenceDate = $occurrenceDate ?: Dates::todayLocal();
        if (self::hasLinkedClasses($p->id)) {
            $classIds = DB::table('program_edu_classes')->where('program_id', $p->id)->pluck('class_id')->all();
            $q = MemberIds::memberAccounts(DB::table('users as u'))
                ->join('edu_enrollments as e', 'e.user_id', '=', 'u.id')
                ->where('e.status', 'active')
                ->whereIn('e.class_id', $classIds ?: [0])
                ->where(['u.status' => 'active', 'u.membership_status' => 'active']);

            // Filter by occurrence's academic year if defined
            $yearId = null;
            if (Schema::hasTable('edu_academic_years')) {
                $yearId = DB::table('edu_academic_years')
                    ->where('starts_on', '<=', $occurrenceDate)
                    ->where('ends_on', '>=', $occurrenceDate)
                    ->value('id');
                if (! $yearId) {
                    $yearId = DB::table('edu_academic_years')->where('is_current', 1)->value('id');
                }
            }
            if ($yearId) {
                $q->where(fn ($w) => $w->where('e.academic_year_id', $yearId)->orWhereNull('e.academic_year_id'));
            }

            // Filter by course eligible groups where courses are linked
            if (Schema::hasTable('program_edu_courses')) {
                $linkedCourses = DB::table('program_edu_courses as pc')
                    ->join('edu_courses as co', 'co.id', '=', 'pc.course_id')
                    ->where('pc.program_id', $p->id)
                    ->whereNotNull('co.member_groups')
                    ->where('co.member_groups', '!=', '')
                    ->pluck('co.member_groups')
                    ->all();
                if ($linkedCourses) {
                    $allowedGroups = [];
                    foreach ($linkedCourses as $csv) {
                        foreach (explode(',', (string) $csv) as $g) {
                            $g = trim($g);
                            if ($g !== '') $allowedGroups[$g] = true;
                        }
                    }
                    if ($allowedGroups) {
                        $q->whereIn('u.member_group', array_keys($allowedGroups));
                    }
                }
            }

            $q->distinct();
            return $q;
        }

        // Education programs without linked classes should never leak general church members
        if (self::isEducationProgram($p)) {
            return MemberIds::memberAccounts(DB::table('users as u'))->whereRaw('0 = 1');
        }

        $q = MemberIds::memberAccounts(DB::table('users as u'))->where(['u.status' => 'active', 'u.membership_status' => 'active']);
        self::inGroups($q, $p);
        if ($p->audience === 'participants') {
            $q->join('program_participants as pp', 'pp.user_id', '=', 'u.id')->where('pp.program_id', $p->id)->whereIn('pp.status', ['invited', 'registered']);
        } else {
            // joined by the end of that local day
            $q->where('u.created_at', '<', Dates::sql(Dates::fromLocal("$occurrenceDate 23:59:59")));
        }
        return $q;
    }

    private static function assertExpected(object $p, string $date, int $userId): void
    {
        if (! self::expectedMembers($p, $date)->where('u.id', $userId)->exists()) {
            throw ApiError::conflict('MEMBER_NOT_EXPECTED', 'This member is not expected at this program');
        }
    }

    /** Direct record entry by HR or manager for any program (including Education). */
    public static function record(array $actx, array $data): array
    {
        /** @var AuthContext $auth */
        $auth = $actx['auth'];
        if (! $auth->can('attendance.manage') && ! $auth->can('programs.manage') && ! $auth->isAdmin) {
            throw ApiError::forbidden('FORBIDDEN', 'Attendance management permission required');
        }

        $programId = (int) $data['program_id'];
        $userId = (int) $data['user_id'];
        $date = $data['date'] ?? Dates::todayLocal();
        $status = $data['status'] ?? 'present';
        $punctuality = $data['punctuality'] ?? 'on_time';
        $note = $data['note'] ?? null;
        $actorId = $auth->id;

        $p = self::getProgram($programId);
        Schedule::loadOverrides($p);
        $o = self::resolveOccurrence($p, $date);
        if (! empty($o['suspended'])) {
            throw ApiError::conflict('OCCURRENCE_SUSPENDED', 'This program occurrence has been suspended for ' . $date);
        }
        if (! empty($o['cancelled'])) {
            throw ApiError::conflict('OCCURRENCE_CANCELLED', 'This program occurrence has been cancelled for ' . $date);
        }
        self::assertExpected($p, $date, $userId);

        $now = Dates::sql(Dates::now());
        $existing = DB::table('attendance')->where(['program_id' => $programId, 'user_id' => $userId, 'date' => $date])->first();
        if ($existing) {
            DB::table('attendance')->where('id', $existing->id)->update([
                'status' => $status,
                'punctuality' => $punctuality,
                'note' => $note,
                'recorded_by' => $actorId,
                'updated_at' => $now,
            ]);
            $id = $existing->id;
        } else {
            $id = DB::table('attendance')->insertGetId([
                'program_id' => $programId,
                'user_id' => $userId,
                'occurrence_date' => $date,
                'date' => $date,
                'status' => $status,
                'punctuality' => $punctuality,
                'channel' => 'manual',
                'recorded_by' => $actorId,
                'note' => $note,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        if (self::hasLinkedClasses($programId) && Schema::hasTable('attendance_edu_classes')) {
            $classIds = DB::table('program_edu_classes as pc')
                ->join('edu_enrollments as e', 'e.class_id', '=', 'pc.class_id')
                ->where('pc.program_id', $programId)
                ->where('e.user_id', $userId)
                ->where('e.status', 'active')
                ->pluck('pc.class_id')
                ->all();
            foreach ($classIds as $cid) {
                DB::table('attendance_edu_classes')->insertOrIgnore([
                    'attendance_id' => $id,
                    'class_id' => $cid,
                ]);
            }
        }

        return (array) DB::table('attendance')->where('id', $id)->first();
    }

    /** Roster of one occurrence: every expected member (plus anyone marked) with their status. */
    public static function roster(int $programId, array $f, array $page, ?AuthContext $auth = null): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $f['date'] ?? null);
        $session = AttendanceSessions::serialize(AttendanceSessions::of($p, $o), $p, $o, $auth);
        $closed = self::isClosed($p, $o);
        $expected = self::expectedMembers($p, $o['date'])->select('u.id');
        $qb = DB::table('users as u')
            ->leftJoin('attendance as a', fn ($j) => $j->on('a.user_id', '=', 'u.id')->where('a.program_id', '=', $programId)->where('a.occurrence_date', '=', $o['date']))
            ->leftJoin('program_participants as pp', fn ($j) => $j->on('pp.user_id', '=', 'u.id')->where('pp.program_id', '=', $programId))
            ->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')
            ->leftJoin('roles as rr', 'rr.id', '=', 'rec.role_id');
        MemberIds::memberAccounts($qb);
        $qb->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.profile_image', 'pp.status as participation', 'a.id as attendance_id', 'a.status', 'a.attended_at', 'a.notes', 'a.via',
            'a.session_id', 'a.elapsed_seconds', 'a.time_source', 'a.source', 'a.signature_id', 'a.signature_exempt', Actor::hiddenName('rec', 'rr', 'recorded_by_name'))
            ->orderBy('u.full_name');
        if (($f['source'] ?? 'participants') === 'participants') {
            $qb->where(fn ($w) => $w->whereIn('u.id', $expected)->orWhereNotNull('a.id'));
        } else {
            $pool = self::inGroups(MemberIds::memberAccounts(DB::table('users as u'))->where('u.status', 'active'), $p)->select('u.id');
            $qb->where(fn ($w) => $w->whereIn('u.id', $pool)->orWhereNotNull('a.id'));
        }
        MemberIds::search($qb, $f['q'] ?? null);
        $status = $f['status'] ?? null;
        if ($status === 'unmarked' || $status === 'absent') $qb->where(fn ($w) => $w->whereNull('a.id')->orWhere('a.status', 'absent'));
        elseif ($status === 'present') $qb->whereIn('a.status', ['present', 'late']);
        elseif ($status) $qb->where('a.status', $status);
        $res = Page::paginate($qb, $page);
        $items = array_map(function ($r) use ($closed) {
            $r->status = $r->status ?? ($closed ? 'absent' : 'unmarked');
            $r->marked = (bool) $r->attendance_id;
            // Recorded before attendance sessions existed (the old present / late marks).
            $r->legacy = $r->attendance_id && ! $r->session_id;
            // There is no late status any more: an old "late" mark is attendance (kept for history).
            $r->legacy_late = $r->status === 'late';
            if ($r->legacy_late) $r->status = 'present';
            $r->signed = (bool) $r->signature_id;
            $r->signature_url = ($r->signed && $r->attendance_id) ? url("/api/v1/programs/attendance/signatures/{$r->attendance_id}") : null;
            return $r;
        }, MemberIds::decorate($res['items']));

        $uids = array_column($items, 'user_id');
        $userClasses = [];
        if ($uids && Schema::hasTable('edu_enrollments')) {
            $cRows = DB::table('edu_enrollments as e')
                ->join('edu_classes as c', 'c.id', '=', 'e.class_id')
                ->whereIn('e.user_id', $uids)
                ->where('e.status', 'active')
                ->select('e.user_id', 'c.name')
                ->get();
            foreach ($cRows as $cr) {
                $userClasses[$cr->user_id][] = $cr->name;
            }
        }
        foreach ($items as &$it) {
            $it->classes = implode(', ', array_unique($userClasses[$it->user_id] ?? []));
        }

        return [
            'items' => $items,
            'meta' => $res['meta'] + [
                'occurrence' => [
                    'date' => $o['date'],
                    'starts_at' => $o['starts_at'],
                    'ends_at' => $o['ends_at'],
                    'active' => empty($o['suspended']) && empty($o['cancelled']) && self::isActive($o),
                    'ended' => self::hasEnded($o),
                    'closed' => $closed,
                    'rescheduled' => ! empty($o['rescheduled']),
                    'cancelled' => ! empty($o['cancelled']),
                    'suspended' => ! empty($o['suspended']),
                    'status' => ! empty($o['suspended']) ? 'suspended' : (! empty($o['cancelled']) ? 'cancelled' : ($closed ? 'closed' : 'active')),
                ],
                'session' => $session,
                'signature_policy' => Settings::signaturePolicy(),
                'summary' => self::summary($programId, $o['date']),
            ],
        ];
    }

    /** absent = expected but not marked (only once closed). */
    public static function summary(int $programId, ?string $date): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $date);
        $counts = ['present' => 0, 'late' => 0, 'excused' => 0, 'absent' => 0];
        foreach (DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date']])->groupBy('status')->select('status', DB::raw('COUNT(*) as c'))->get() as $r) {
            $counts[$r->status] = (int) $r->c;
        }
        $expected = self::expectedMembers($p, $o['date'])->count();
        $marked = $counts['present'] + $counts['late'] + $counts['excused'];
        $unmarked = max(0, $expected - $marked - $counts['absent']);
        $ended = self::isClosed($p, $o);
        // No late status any more: a legacy "late" row counts as present (kept apart for history).
        $legacyLate = $counts['late'];
        unset($counts['late']);
        $counts['present'] += $legacyLate;
        // array_merge: the closed occurrence's unmarked members are absent (the "+" operator kept the raw count).
        return array_merge(['date' => $o['date'], 'expected' => $expected], $counts, ['legacy_late' => $legacyLate, 'absent' => $counts['absent'] + ($ended ? $unmarked : 0), 'unmarked' => $ended ? 0 : $unmarked, 'participants' => $expected]);
    }

    /**
     * Write one mark of a session. [$m]: status, notes, via, attended_at (the capture time),
     * client_captured_at, received_at, elapsed_seconds, time_source, session_id, signature_exempt,
     * source, client_event_id.
     */
    private static function upsert(array $actx, object $p, string $date, int $userId, array $m): array
    {
        $status = $m['status'];
        $existing = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $date, 'user_id' => $userId])->first(['id', 'status']);
        $row = [
            'status' => $status, 'attended_at' => isset($m['attended_at']) ? Dates::sql($m['attended_at']) : null, 'notes' => $m['notes'] ?? null, 'via' => $m['via'] ?? 'manual',
            'updated_by' => $actx['auth']->id,
            'session_id' => $m['session_id'] ?? null, 'client_captured_at' => isset($m['client_captured_at']) ? Dates::sql($m['client_captured_at']) : null,
            'received_at' => Dates::sql($m['received_at'] ?? Dates::now()), 'elapsed_seconds' => $m['elapsed_seconds'] ?? null, 'time_source' => $m['time_source'] ?? null,
            'signature_exempt' => ! empty($m['signature_exempt']) ? 1 : 0, 'source' => $m['source'] ?? null, 'client_event_id' => $m['client_event_id'] ?? null,
        ];
        if ($existing) {
            DB::table('attendance')->where('id', $existing->id)->update($row);
            $id = (int) $existing->id;
        } else {
            $id = (int) DB::table('attendance')->insertGetId($row + ['program_id' => $p->id, 'occurrence_date' => $date, 'user_id' => $userId, 'recorded_by' => $m['recorded_by'] ?? $actx['auth']->id]);
        }
        if ($status === 'present') {
            Activity::track($userId, Activity::ATTENDANCE, 'program', $p->id, ['status' => $status, 'date' => $date], inTrx: true);
        }
        return ['id' => $id, 'isNew' => ! $existing, 'previous' => $existing?->status];
    }

    private static function attachSignature(int $attendanceId, int $userId, array $sig, int $capturedBy, ?string $eventId, \DateTimeInterface $signedAt): void
    {
        $sid = DB::table('attendance_signatures')->insertGetId([
            'attendance_id' => $attendanceId, 'user_id' => $userId, 'path' => $sig['path'], 'sha256' => $sig['sha256'],
            'signed_at' => Dates::sql($signedAt), 'captured_by' => $capturedBy, 'client_event_id' => $eventId,
        ]);
        DB::table('attendance')->where('id', $attendanceId)->update(['signature_id' => $sid]);
    }

    /** The session's taker is the only one who records (HR assigns; holding a permission is not enough). */
    private static function assertTaker(AuthContext $auth, object $s): void
    {
        if (! $s->taker_id) throw ApiError::forbidden('NO_ATTENDANCE_TAKERS_ASSIGNED', 'HR has not assigned an attendance taker for this occurrence');
        if ((int) $s->taker_id !== $auth->id) throw ApiError::forbidden('NOT_SESSION_TAKER', 'Only the assigned attendance taker can record attendance for this occurrence');
    }

    /** Who recorded an existing mark, and when (for "already recorded"). */
    private static function recordOf(int $programId, string $date, int $userId): ?array
    {
        $r = DB::table('attendance as a')->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')->leftJoin('roles as rr', 'rr.id', '=', 'rec.role_id')
            ->where(['a.program_id' => $programId, 'a.occurrence_date' => $date, 'a.user_id' => $userId])
            ->first(['a.status', 'a.via', 'a.attended_at', 'a.created_at', Actor::hiddenName('rec', 'rr', 'recorded_by_name')]);
        return $r ? ['status' => $r->status === 'late' ? 'present' : $r->status, 'via' => $r->via, 'attended_at' => $r->attended_at, 'recorded_at' => $r->created_at, 'recorded_by_name' => $r->recorded_by_name] : null;
    }

    /**
     * Step 1 of taking attendance (QR scan or manual pick): who is this, may they be recorded now,
     * and must they sign. Nothing is written; the taker checks the photo, the member signs, then
     * the mark is recorded.
     */
    public static function identify(AuthContext $auth, int $programId, array $in): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $in['date'] ?? null);
        $s = AttendanceSessions::of($p, $o);
        $userId = ! empty($in['uuid']) ? Members::idByUuid($in['uuid']) : (int) ($in['user_id'] ?? 0);
        $u = MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)
            ->first(['u.id', 'u.full_name', 'u.profile_image', 'u.member_no', 'u.member_group', 'u.member_type', 'u.status', 'u.membership_status']);
        if (! $u) throw ApiError::notFound('MEMBER_NOT_FOUND', 'Member not found');
        $now = Dates::now();
        $existing = self::recordOf($programId, $o['date'], $userId);
        $groups = self::groupsOf($p);
        $reason = null;
        if (! empty($o['suspended'])) $reason = 'OCCURRENCE_SUSPENDED';
        elseif (! empty($o['cancelled'])) $reason = 'OCCURRENCE_CANCELLED';
        elseif (! $s->taker_id) $reason = 'NO_ATTENDANCE_TAKERS_ASSIGNED';
        elseif ((int) $s->taker_id !== $auth->id) $reason = 'NOT_SESSION_TAKER';
        elseif (! $s->started_at) $reason = 'SESSION_NOT_STARTED';
        elseif (! AttendanceSessions::acceptsAt($s, $o, $now)) $reason = 'ATTENDANCE_CLOSED';
        elseif ($userId === $auth->id) $reason = 'SELF_ATTENDANCE_NOT_ALLOWED';
        elseif (! self::hasLinkedClasses($p->id) && $groups && ! in_array($u->member_group, $groups, true)) $reason = 'MEMBER_NOT_IN_GROUP';
        elseif (! self::expectedMembers($p, $o['date'])->where('u.id', $userId)->exists()) $reason = 'MEMBER_NOT_EXPECTED';
        elseif ($existing && $existing['status'] === 'present') $reason = 'ATTENDANCE_ALREADY_RECORDED';
        return [
            'member' => [
                'id' => $u->id, 'full_name' => $u->full_name, 'avatar_url' => Storage::url($u->profile_image),
                'member_id' => MemberIds::format($u->member_no, $u->member_group), 'member_group' => $u->member_group,
                'member_group_name' => MemberGroups::name($u->member_group), 'member_group_name_en' => MemberGroups::name($u->member_group, 'en'),
                'member_type' => $u->member_type, 'membership_status' => $u->membership_status, 'status' => $u->status,
            ],
            'program' => ['id' => $p->id, 'title' => $p->title, 'member_groups' => $groups],
            'occurrence' => [
                'date' => $o['date'],
                'starts_at' => $o['starts_at'],
                'ends_at' => $o['ends_at'],
                'active' => empty($o['suspended']) && empty($o['cancelled']) && self::isActive($o, $now),
                'closed' => self::isClosed($p, $o, $now),
                'cancelled' => ! empty($o['cancelled']),
                'suspended' => ! empty($o['suspended']),
                'status' => ! empty($o['suspended']) ? 'suspended' : (! empty($o['cancelled']) ? 'cancelled' : 'active'),
            ],
            'session' => AttendanceSessions::serialize($s, $p, $o, $auth),
            'eligible' => $reason === null,
            'reason' => $reason,
            'attendance' => $existing,
            'would_record' => $reason === null ? 'present' : null,
            'signature_required' => ! self::signatureExempt($u->member_group),
        ];
    }

    /**
     * Record one member (the session's taker). [$capture] for offline work: at (capture time,
     * adjusted to the server clock), client_raw (the phone's own time), offline, event_id.
     * present needs the member's signature (PNG data URL) unless their group is exempt; excused needs
     * a reason. Outside the session (not started / ended) nothing is written: corrections instead.
     */
    public static function set(array $actx, int $programId, int $userId, array $input, array $capture = []): array
    {
        $notify = false;
        $date = null;
        $duplicate = false;
        $savedSig = null;
        /** @var AuthContext $auth */
        $auth = $actx['auth'];
        $status = $input['status'] ?? 'present';
        if ($status === 'late') throw ApiError::field('status', 'LATE_REMOVED');
        if ($status === 'absent') throw ApiError::field('status', 'ABSENT_IS_AUTOMATIC');
        if (! in_array($status, self::MARKABLE, true)) throw ApiError::field('status', 'INVALID_STATUS');
        $run = function () use ($actx, $auth, $programId, $userId, $input, $capture, $status, &$notify, &$date, &$duplicate, &$savedSig) {
            $p = self::getProgram($programId);
            $o = self::resolveOccurrence($p, $input['date'] ?? null);
            if (! empty($o['suspended'])) {
                throw ApiError::conflict('OCCURRENCE_SUSPENDED', 'This program occurrence has been suspended for ' . $o['date']);
            }
            if (! empty($o['cancelled'])) {
                throw ApiError::conflict('OCCURRENCE_CANCELLED', 'This program occurrence has been cancelled for ' . $o['date']);
            }
            $date = $o['date'];
            if ($date < Dates::todayLocal() && empty($capture['allow_past'])) {
                throw ApiError::conflict('PAST_PROGRAM_ATTENDANCE_BLOCKED', 'Attendance cannot be recorded for past program dates. Submit an attendance correction request instead.');
            }
            $s = AttendanceSessions::of($p, $o, true);
            self::assertTaker($auth, $s);
            $u = MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)->first(['u.id', 'u.member_group']);
            if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
            // Marks of the same member are serialised on the member's row.
            DB::table('users')->where('id', $userId)->lockForUpdate()->first(['id']);
            $now = Dates::now();
            $at = $capture['at'] ?? $now;
            if ($at > $now) $at = $now;
            if (! $s->started_at) throw ApiError::conflict('SESSION_NOT_STARTED', 'Start the attendance session first');
            if (! AttendanceSessions::acceptsAt($s, $o, $at)) {
                throw $at < Dates::of($s->started_at)
                    ? ApiError::conflict('BEFORE_SESSION_START', 'This was captured before the session started')
                    : ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
            }
            if ($userId === $auth->id) throw ApiError::forbidden('SELF_ATTENDANCE_NOT_ALLOWED', 'Another attendance taker must record your attendance');
            if (! self::hasLinkedClasses($p->id)) self::assertInGroups($p, $userId);
            self::assertExpected($p, $o['date'], $userId);
            $existing = DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId])->lockForUpdate()->first(['id', 'status', 'client_event_id']);
            $eventId = $capture['event_id'] ?? null;
            if ($existing && $eventId && $existing->client_event_id === $eventId) {
                $duplicate = true; // the same event, replayed
                return;
            }
            // A second scan of someone already present changes nothing (no second signature either).
            if ($existing && in_array($existing->status, ['present', 'late'], true)) {
                $duplicate = true;
                return;
            }
            $exempt = false;
            if ($status === 'excused') {
                if (! trim((string) ($input['notes'] ?? ''))) throw ApiError::field('notes', 'REASON_REQUIRED');
            } else {
                $exempt = self::signatureExempt($u->member_group);
                if (! $exempt && empty($input['signature'])) throw ApiError::field('signature', 'SIGNATURE_REQUIRED');
                if (! empty($input['signature'])) $savedSig = Storage::save('signature', Storage::FOLDERS['SIGNATURES'], Storage::decodeDataUrl($input['signature']));
            }
            $offline = ! empty($capture['at']);
            $r = self::upsert($actx, $p, $o['date'], $userId, [
                'status' => $status, 'attended_at' => $status === 'present' ? $at : null, 'notes' => $input['notes'] ?? null, 'via' => $input['via'] ?? 'manual',
                'session_id' => (int) $s->id, 'client_captured_at' => $capture['client_raw'] ?? null, 'received_at' => $now,
                'elapsed_seconds' => $status === 'present' ? max(0, $at->getTimestamp() - Dates::of($s->started_at)->getTimestamp()) : null,
                'time_source' => $offline ? 'device' : 'server', 'signature_exempt' => $exempt && empty($input['signature']),
                'source' => ! empty($capture['offline']) ? 'offline' : 'online', 'client_event_id' => $eventId,
            ]);
            if ($savedSig) self::attachSignature($r['id'], $userId, $savedSig, $auth->id, $eventId, $at);
            if (self::hasLinkedClasses($p->id) && Schema::hasTable('attendance_edu_classes')) {
                $classIds = DB::table('program_edu_classes as pc')
                    ->join('edu_enrollments as e', 'e.class_id', '=', 'pc.class_id')
                    ->where('pc.program_id', $programId)
                    ->where('e.user_id', $userId)
                    ->where('e.status', 'active')
                    ->pluck('pc.class_id')
                    ->all();
                foreach ($classIds as $cid) {
                    DB::table('attendance_edu_classes')->insertOrIgnore([
                        'attendance_id' => $r['id'],
                        'class_id' => $cid,
                    ]);
                }
            }
            Audit::log($actx, Audit::ATTENDANCE_SET, 'attendance', $programId, [
                'user_id' => $userId, 'date' => $o['date'], 'status' => $status, 'previous' => $r['previous'], 'via' => $input['via'] ?? 'manual', 'reason' => $input['notes'] ?? null,
                'session_id' => (int) $s->id, 'captured_at' => Dates::sql($at), 'signed' => (bool) $savedSig, 'source' => ! empty($capture['offline']) ? 'offline' : 'online',
            ], inTrx: true);
            if ($status === 'present') {
                $notify = Notifications::createForUsers([$userId], [
                    'type' => 'attendance',
                    'title' => T::t('attendance.recorded.title'),
                    'body' => T::t('attendance.recorded.body', ['title' => $p->title]),
                    'entityType' => 'program',
                    'entityId' => $programId,
                    'dedupeKey' => fn ($uid) => "attendance:$programId:{$o['date']}:$uid",
                ]) > 0;
            }
        };
        try {
            DB::transaction($run);
        } catch (\Illuminate\Database\QueryException $e) {
            if ($savedSig) Storage::remove($savedSig['path']);
            // The unique key (program, date, member) refused a second row: another request was first.
            if ((int) ($e->errorInfo[1] ?? 0) !== 1062 || $date === null) throw $e;
            $duplicate = true;
            $notify = false;
        } catch (\Throwable $e) {
            if ($savedSig) Storage::remove($savedSig['path']);
            throw $e;
        }
        if ($duplicate && $savedSig) Storage::remove($savedSig['path']);
        if ($notify) Notifications::kick();
        if (! $duplicate) Choir::scheduleEligibility([$userId]);
        $rec = DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $date, 'user_id' => $userId])->first();
        $out = array_merge((array) $rec, ['duplicate' => $duplicate]);
        if ($duplicate) $out['already_recorded'] = self::recordOf($programId, $date, $userId);
        return $out;
    }

    /** Several members excused at once (reason required). "Present" is signed one by one. */
    public static function bulkSet(array $actx, int $programId, array $in, bool $allowAll): array
    {
        $auth = $actx['auth'];
        if (($in['status'] ?? null) !== 'excused') throw ApiError::field('status', 'SIGNATURE_REQUIRED');
        $notes = $in['notes'] ?? null;
        if (! trim((string) $notes)) throw ApiError::field('notes', 'REASON_REQUIRED');
        return DB::transaction(function () use ($actx, $auth, $programId, $in, $allowAll, $notes) {
            $p = self::getProgram($programId);
            $o = self::resolveOccurrence($p, $in['date'] ?? null);
            if ($o['date'] < Dates::todayLocal() && empty($in['allow_past'])) {
                throw ApiError::conflict('PAST_PROGRAM_ATTENDANCE_BLOCKED', 'Attendance cannot be recorded for past program dates. Submit an attendance correction request instead.');
            }
            $s = AttendanceSessions::of($p, $o, true);
            self::assertTaker($auth, $s);
            $now = Dates::now();
            if (! $s->started_at) throw ApiError::conflict('SESSION_NOT_STARTED', 'Start the attendance session first');
            if (! AttendanceSessions::acceptsAt($s, $o, $now)) throw ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
            $expected = array_flip(self::expectedMembers($p, $o['date'])->pluck('u.id')->all());
            $target = $in['target'];
            $picked = ! empty($target['user_ids']) ? array_values(array_filter($target['user_ids'], fn ($u) => ! in_array($u, $target['exclude_ids'] ?? [], true))) : Targeting::resolve($target, $allowAll);
            $present = array_flip(DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date']])->whereIn('status', ['present', 'late'])->pluck('user_id')->all());
            $ids = [];
            foreach (array_values(array_unique($picked)) as $uid) {
                if ($uid !== $auth->id && isset($expected[$uid]) && ! isset($present[$uid])) $ids[] = $uid;
            }
            foreach ($ids as $uid) self::upsert($actx, $p, $o['date'], $uid, ['status' => 'excused', 'notes' => $notes, 'via' => 'manual', 'session_id' => (int) $s->id, 'received_at' => $now, 'time_source' => 'server', 'source' => 'online']);
            Choir::scheduleEligibility($ids);
            Audit::log($actx, Audit::ATTENDANCE_BULK, 'attendance', $programId, ['count' => count($ids), 'status' => 'excused', 'date' => $o['date'], 'reason' => $notes, 'session_id' => (int) $s->id], inTrx: true);
            return ['updated' => count($ids), 'status' => 'excused', 'date' => $o['date']];
        });
    }

    /** The taker removes a mistaken mark while the session runs (reason kept); afterwards: corrections. */
    public static function remove(array $actx, int $programId, int $userId, ?string $date, ?string $reason): void
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $date);
        $s = AttendanceSessions::of($p, $o);
        self::assertTaker($actx['auth'], $s);
        if (! $s->started_at || ! AttendanceSessions::acceptsAt($s, $o, Dates::now())) throw ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
        if (! trim((string) $reason)) throw ApiError::field('reason', 'REASON_REQUIRED');
        $key = ['program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId];
        $prev = DB::table('attendance')->where($key)->first(['id', 'status', 'signature_id']);
        if (! $prev) throw ApiError::notFound('ATTENDANCE_NOT_FOUND', 'Attendance not found');
        DB::table('attendance')->where('id', $prev->id)->delete();
        Choir::scheduleEligibility([$userId]);
        // The signature record stays (attendance_signatures) for the audit trail.
        Audit::log($actx, Audit::ATTENDANCE_SET, 'attendance', $programId, ['user_id' => $userId, 'date' => $o['date'], 'status' => 'removed', 'previous' => $prev->status, 'reason' => $reason, 'session_id' => (int) $s->id, 'signature_id' => $prev->signature_id]);
    }

    /** End the occurrence's session (HR: attendance.close; or the taker). */
    public static function close(array $actx, int $programId, ?string $date): array
    {
        $out = AttendanceSessions::end($actx, $programId, $date);
        return ['date' => $out['date'], 'closed' => true, 'session' => $out];
    }

    /**
     * Apply an offline record HR accepted from the conflict queue: written as captured (its own
     * capture time and signature, recorded by the taker who captured it). Null = already recorded.
     */
    public static function applyAcceptedConflict(array $actx, object $c, array $payload): ?int
    {
        $p = self::getProgram((int) $c->program_id);
        $d = Dates::toDateOnly($c->occurrence_date);
        $o = Schedule::on($p, $d);
        if (! $o) throw ApiError::conflict('NOT_AN_OCCURRENCE', 'This occurrence no longer exists');
        $existing = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $d, 'user_id' => $c->user_id])->first(['id', 'status']);
        $status = in_array($payload['status'] ?? 'present', self::MARKABLE, true) ? $payload['status'] : 'present';
        if ($existing && ($existing->status === 'present' || $existing->status === 'late' || $existing->status === $status)) return null;
        $s = AttendanceSessions::of($p, $o);
        $at = $c->captured_at ? Dates::of($c->captured_at) : null;
        $r = self::upsert($actx, $p, $d, (int) $c->user_id, [
            'status' => $status, 'attended_at' => $status === 'present' ? $at : null, 'notes' => $payload['notes'] ?? null, 'via' => $payload['via'] ?? 'manual',
            'session_id' => (int) $s->id, 'client_captured_at' => $c->client_captured_at, 'received_at' => Dates::now(),
            'elapsed_seconds' => $status === 'present' && $at && $s->started_at ? max(0, $at->getTimestamp() - Dates::of($s->started_at)->getTimestamp()) : null,
            'time_source' => 'device', 'source' => 'offline', 'recorded_by' => (int) $c->submitted_by,
        ]);
        if ($c->signature_path) self::attachSignature($r['id'], (int) $c->user_id, ['path' => $c->signature_path, 'sha256' => $c->signature_sha256], (int) $c->submitted_by, null, $at ?? Dates::now());
        return $r['id'];
    }

    /** The member's signature of a mark (HR / reports). */
    public static function signatureFile(int $attendanceId): array
    {
        $sid = DB::table('attendance')->where('id', $attendanceId)->value('signature_id');
        $sig = $sid ? DB::table('attendance_signatures')->where('id', $sid)->first(['path']) : null;
        if (! $sig) throw ApiError::notFound('SIGNATURE_NOT_FOUND', 'No signature');
        return ['abs' => Storage::privatePath($sig->path), 'mime' => 'image/png'];
    }

    // ------------------------------------------------------------------ comments and correction requests
    private static function currentStatus(object $p, array $o, int $userId): string
    {
        $a = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $o['date'], 'user_id' => $userId])->first(['status']);
        return $a?->status ?? (self::isClosed($p, $o) ? 'absent' : 'unmarked');
    }

    public static function requestCorrection(array $actx, int $programId, int $userId, array $in): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $in['date'] ?? null);
        if (! MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)->exists()) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        self::assertInGroups($p, $userId);

        $reason = trim((string) ($in['reason'] ?? ''));
        if (empty($reason)) {
            throw ApiError::validation([['field' => 'reason', 'code' => 'REASON_REQUIRED', 'message' => 'A valid reason is required for attendance correction requests.']]);
        }

        // Block corrections when no independent HR approver is available
        $approvers = array_values(array_unique(array_merge(
            \App\Mz\Auth\Holders::of('attendance.correction.approve'),
            \App\Mz\Auth\Holders::of('hr.corrections')
        )));
        $eligibleApprovers = array_filter($approvers, fn ($u) => (int) $u !== $actx['auth']->id && (int) $u !== $userId);
        if (empty($eligibleApprovers)) {
            throw ApiError::conflict('NO_ELIGIBLE_HR_APPROVER', 'No authorized HR approver is currently available to review this correction. An independent HR approver must be designated.');
        }

        $original = self::currentStatus($p, $o, $userId);
        $requested = $in['requested_status'] ?? null;
        if ($requested === 'late') throw ApiError::field('requested_status', 'LATE_REMOVED');
        // "Present" may say when the member actually arrived (scored from the session's start).
        $arrived = $requested === 'present' && ! empty($in['attended_at']) ? Dates::of($in['attended_at']) : null;
        if ($arrived && ($arrived < Dates::of($o['starts_at'])->modify('-' . AttendanceSessions::AVAILABLE_BEFORE_MINUTES . ' minutes') || $arrived > Dates::of($o['ends_at']))) throw ApiError::field('attended_at', 'OUTSIDE_OCCURRENCE');
        $id = DB::table('attendance_corrections')->insertGetId([
            'program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId, 'original_status' => $original, 'requested_status' => $requested,
            'requested_attended_at' => $arrived ? Dates::sql($arrived) : null, 'reason' => $reason, 'requested_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::ATTENDANCE_CORRECTION_REQUEST, 'attendance_correction', $id, ['program_id' => $programId, 'date' => $o['date'], 'user_id' => $userId, 'original' => $original, 'requested' => $requested, 'reason' => $reason]);
        $member = DB::table('users')->where('id', $userId)->value('full_name');
        Notifications::createForUsers(array_values(array_filter($eligibleApprovers, fn ($u) => (int) $u !== $actx['auth']->id)), [
            'type' => 'attendance',
            'title' => T::t('attendance.correction.requested.title'),
            'body' => T::t('attendance.correction.requested.body', ['name' => $member, 'title' => $p->title, 'date' => \App\Mz\Services\ReportExport::ethiopianDate($o['date'] . ' 12:00:00'), 'by' => $actx['auth']->fullName]),
            'entityType' => 'program',
            'entityId' => $programId,
            'dedupeKey' => fn ($uid) => "correction:$id:requested:$uid",
        ]);
        return self::correction($id);
    }

    private static function correctionQuery(): Builder
    {
        return DB::table('attendance_corrections as c')->join('programs as p', 'p.id', '=', 'c.program_id')->join('users as u', 'u.id', '=', 'c.user_id')
            ->leftJoin('users as rq', 'rq.id', '=', 'c.requested_by')->leftJoin('users as rv', 'rv.id', '=', 'c.reviewed_by');
    }

    public static function correction(int $id): array
    {
        $r = self::correctionQuery()->where('c.id', $id)->first(['c.*', 'p.title as program_title', 'u.full_name', 'rq.full_name as requested_by_name', 'rv.full_name as reviewed_by_name']);
        if (! $r) throw ApiError::notFound('CORRECTION_NOT_FOUND', 'Correction request not found');
        $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
        return (array) $r;
    }

    public static function listCorrections(AuthContext $auth, array $f, array $page): array
    {
        $qb = self::correctionQuery()->orderByDesc('c.created_at')->select('c.*', 'p.title as program_title', 'u.full_name', 'rq.full_name as requested_by_name', 'rv.full_name as reviewed_by_name');
        if (! $auth->can('attendance.correction.approve')) $qb->where('c.requested_by', $auth->id);
        if (! empty($f['status'])) $qb->where('c.status', $f['status']);
        if (! empty($f['program_id'])) $qb->where('c.program_id', $f['program_id']);
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(function ($r) {
            $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
            return $r;
        }, $res['items']);
        return $res;
    }

    /** Approve (applies the requested status, even after closure) or reject. */
    public static function reviewCorrection(array $actx, int $id, string $decision, ?string $note): array
    {
        $userId = null;
        DB::transaction(function () use ($actx, $id, $decision, $note, &$userId) {
            $c = DB::table('attendance_corrections')->where('id', $id)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CORRECTION_NOT_FOUND', 'Correction request not found');
            if ($c->status !== 'pending') throw ApiError::conflict('CORRECTION_REVIEWED', 'This request was already reviewed');

            $reviewer = $actx['auth'];
            if (! $reviewer->can('attendance.correction.approve') && ! $reviewer->can('hr.corrections')) {
                throw ApiError::forbidden('NOT_AUTHORIZED_HR_APPROVER', 'Only authorized HR approvers can review attendance corrections.');
            }
            if ($reviewer->id === (int) $c->requested_by || $reviewer->id === (int) $c->user_id) {
                throw ApiError::forbidden('SELF_APPROVAL_FORBIDDEN', 'Self-approval is strictly forbidden. Another authorized HR approver must decide this correction request.');
            }

            $userId = $c->user_id;
            $p = self::getProgram($c->program_id);
            $d = Dates::toDateOnly($c->occurrence_date);
            $o = Schedule::on($p, $d) ?? ['date' => $d, 'starts_at' => Dates::now(), 'ends_at' => new UtcDateTime('@0')];
            $before = self::currentStatus($p, $o, $c->user_id);
            $final = $before;
            if ($decision === 'approve' && $c->requested_status) {
                if ($c->requested_status === 'absent') {
                    DB::table('attendance')->where(['program_id' => $c->program_id, 'occurrence_date' => $o['date'], 'user_id' => $c->user_id])->delete();
                } else {
                    // A corrected "present" keeps the stated arrival time (scored from the session's
                    // official start); without one it has no elapsed time (time_source = correction).
                    $sess = isset($o['starts_at']) && Schedule::on($p, $o['date']) ? AttendanceSessions::of($p, $o) : null;
                    $arrived = $c->requested_status === 'present' && $c->requested_attended_at ? Dates::of($c->requested_attended_at) : null;
                    self::upsert($actx, $p, $o['date'], $c->user_id, [
                        'status' => $c->requested_status, 'notes' => mb_substr("correction #{$c->id}: {$c->reason}", 0, 500), 'via' => 'manual',
                        'attended_at' => $arrived, 'session_id' => $sess ? (int) $sess->id : null, 'time_source' => 'correction',
                        'elapsed_seconds' => $arrived && $sess && $sess->started_at ? max(0, $arrived->getTimestamp() - Dates::of($sess->started_at)->getTimestamp()) : null,
                    ]);
                }
                $final = $c->requested_status;
            }
            DB::table('attendance_corrections')->where('id', $id)->update(['status' => $decision === 'approve' ? 'approved' : 'rejected', 'reviewed_by' => $actx['auth']->id, 'review_note' => $note, 'final_status' => $final, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, Audit::ATTENDANCE_CORRECTION_REVIEW, 'attendance_correction', $id, [
                'decision' => $decision, 'original' => $c->original_status, 'requested' => $c->requested_status, 'before' => $before, 'final' => $final, 'note' => $note, 'program_id' => $c->program_id, 'date' => $o['date'], 'user_id' => $c->user_id,
            ], inTrx: true);
        });
        Choir::scheduleEligibility([$userId]);
        $c = self::correction($id);
        $key = $decision === 'approve' ? 'approved' : 'rejected';
        Notifications::createForUsers(array_filter([(int) $c['requested_by'], (int) $c['user_id']], fn ($u) => $u !== $actx['auth']->id), [
            'type' => 'attendance',
            'title' => T::t("attendance.correction.$key.title"),
            'body' => T::t("attendance.correction.$key.body", ['title' => $c['program_title'], 'date' => \App\Mz\Services\ReportExport::ethiopianDate($c['occurrence_date'] . ' 12:00:00'), 'note' => (string) $note]),
            'entityType' => 'program',
            'entityId' => (int) $c['program_id'],
            'email' => true,
            'dedupeKey' => fn ($uid) => "correction:$id:$key:$uid",
        ]);
        return $c;
    }

    // ------------------------------------------------------------------ member view
    private static function relevantPrograms(int $userId, ?array $categoryIds, ?array $programIds, ?string $memberGroup): array
    {
        $q = DB::table('programs as p')->leftJoin('program_categories as c', 'c.id', '=', 'p.category_id')
            ->whereIn('p.status', ['published', 'completed'])->where('p.requires_attendance', true)
            ->where(fn ($w) => $w->where('p.audience', 'all')->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_participants as pp')->whereColumn('pp.program_id', 'p.id')->where('pp.user_id', $userId)->whereIn('pp.status', ['invited', 'registered'])))
            ->select('p.*', 'c.name as category_name', 'c.name_en as category_name_en', 'c.color as category_color');
        if ($memberGroup) $q->where(fn ($w) => $w->whereNull('p.member_groups')->orWhere('p.member_groups', '')->orWhereRaw('FIND_IN_SET(?, p.member_groups)', [$memberGroup]));
        if (Schema::hasTable('program_edu_classes') && Schema::hasTable('edu_enrollments')) {
            $q->where(function ($w) use ($userId) {
                $w->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id'))
                    ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')
                        ->join('edu_enrollments as ee', 'ee.class_id', '=', 'pec.class_id')
                        ->whereColumn('pec.program_id', 'p.id')
                        ->where('ee.user_id', $userId)
                        ->where('ee.status', 'active')
                    );
            });
        }
        if ($categoryIds) $q->whereIn('p.category_id', $categoryIds);
        if ($programIds) $q->whereIn('p.id', $programIds);
        return $q->get()->all();
    }

    /** Every occurrence a member was (or is) expected at: present|excused|absent|today|upcoming. */
    public static function memberOccurrences(int $userId, array $f = [], ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $user = DB::table('users')->where('id', $userId)->first(['id', 'created_at', 'member_group']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        $joined = Schedule::localDate($user->created_at);
        $today = Dates::todayLocal($now);
        $start = max($f['from'] ?? $joined, $joined);
        $end = $f['to'] ?? $today;
        $programs = self::relevantPrograms($userId, $f['categoryIds'] ?? null, $f['programIds'] ?? null, $user->member_group);
        if (! $programs || $start > $end) return [];
        Schedule::loadOverrides($programs);
        $byKey = [];
        $selectCols = ['a.program_id', 'a.occurrence_date', 'a.status', 'a.attended_at', 'a.elapsed_seconds', 'a.recorded_by', 'u.full_name as recorder_name'];
        if (Schema::hasColumn('attendance', 'notes')) {
            $selectCols[] = 'a.notes';
        }
        if (Schema::hasColumn('attendance', 'signature_id')) {
            $selectCols[] = 'a.signature_id';
        }
        if (Schema::hasColumn('attendance', 'signature_exempt')) {
            $selectCols[] = 'a.signature_exempt';
        }
        $records = DB::table('attendance as a')
            ->leftJoin('users as u', 'u.id', '=', 'a.recorded_by')
            ->where('a.user_id', $userId)
            ->whereIn('a.program_id', array_map(fn ($p) => $p->id, $programs))
            ->whereBetween('a.occurrence_date', [$start, $end])
            ->select($selectCols)
            ->get();
        foreach ($records as $m) {
            // No late status any more: an old "late" mark counts (and shows) as attended.
            $byKey[$m->program_id . ':' . Dates::toDateOnly($m->occurrence_date)] = [
                'status' => $m->status === 'late' ? 'present' : $m->status,
                'attended_at' => $m->attended_at,
                'elapsed_seconds' => $m->elapsed_seconds !== null ? (int) $m->elapsed_seconds : null,
                'signature_id' => $m->signature_id ?? null,
                'signature_exempt' => (bool) ($m->signature_exempt ?? false),
                'recorder_name' => $m->recorder_name,
                'notes' => $m->notes ?? null,
            ];
        }
        $out = [];
        foreach ($programs as $p) {
            foreach (Schedule::between($p, $start, $end) as $o) {
                $mark = $byKey["{$p->id}:{$o['date']}"] ?? null;
                $status = $mark ? $mark['status'] : ($o['ends_at'] < $now ? 'absent' : ($o['date'] === $today ? 'today' : 'upcoming'));
                $out[] = [
                    'program_id' => $p->id,
                    'title' => $p->title,
                    'location' => $p->location,
                    'category' => $p->category_id ? ['id' => $p->category_id, 'name' => $p->category_name, 'name_en' => $p->category_name_en, 'color' => $p->category_color] : null,
                    'date' => $o['date'],
                    'starts_at' => $o['starts_at'],
                    'ends_at' => $o['ends_at'],
                    'status' => $status,
                    'attended_at' => $mark['attended_at'] ?? null,
                    'elapsed_seconds' => $mark['elapsed_seconds'] ?? null,
                    'signature_id' => $mark['signature_id'] ?? null,
                    'signature_exempt' => $mark['signature_exempt'] ?? false,
                    'signature_status' => ! empty($mark['signature_id']) ? 'verified' : (! empty($mark['signature_exempt']) ? 'exempt' : null),
                    'recorder_name' => $mark['recorder_name'] ?? null,
                    'notes' => $mark['notes'] ?? null,
                    'is_additional' => (bool) $p->is_additional,
                    'counts_for_selection' => (bool) $p->counts_for_selection,
                ];
            }
        }
        usort($out, fn ($a, $b) => $a['starts_at'] <=> $b['starts_at']);
        return $out;
    }

    public static function stats(int $userId, array $f = [], ?\DateTimeInterface $now = null): array
    {
        return self::statsOf(self::memberOccurrences($userId, $f, $now), Settings::permissionPolicy()['weight']);
    }

    /** The single attendance formula: present + excused×weight over past occurrences ('late' stays 0 for older apps). */
    public static function statsOf(array $occurrences, float|int $excusedWeight): array
    {
        $c = ['present' => 0, 'late' => 0, 'excused' => 0, 'absent' => 0];
        $upcoming = 0;
        foreach ($occurrences as $o) {
            if (isset($c[$o['status']])) $c[$o['status']]++;
            if ($o['status'] === 'upcoming' || $o['status'] === 'today') $upcoming++;
        }
        $total = $c['present'] + $c['late'] + $c['excused'] + $c['absent'];
        $score = $c['present'] + $c['late'] + $c['excused'] * $excusedWeight;
        return [
            'total_programs' => $total,
            'attended' => $c['present'],
            'late' => $c['late'],
            'excused' => $c['excused'],
            'absent' => $c['absent'],
            'excused_weight' => Num::clean($excusedWeight),
            'percentage' => $total ? Num::clean(floor(($score / $total) * 1000 + 0.5) / 10) : null,
            'upcoming' => $upcoming,
        ];
    }

    /** Calendar days in [from, to]: occurrences and the day's state (worst status wins). */
    public static function calendar(int $userId, string $from, string $to, ?array $categoryIds, ?\DateTimeInterface $now = null): array
    {
        $occ = self::memberOccurrences($userId, ['from' => $from, 'to' => $to, 'categoryIds' => $categoryIds], $now);
        $days = [];
        foreach ($occ as $o) $days[$o['date']][] = $o;
        $out = [];
        foreach ($days as $date => $items) {
            $state = null;
            foreach (self::DAY_PRIORITY as $s) {
                foreach ($items as $i) {
                    if ($i['status'] === $s) { $state = $s; break 2; }
                }
            }
            $out[] = ['date' => (string) $date, 'state' => $state, 'occurrences' => $items];
        }
        return ['from' => $from, 'to' => $to, 'days' => $out, 'stats' => self::statsOf($occ, Settings::permissionPolicy()['weight'])];
    }

    public static function forProgram(int $userId, int $programId, ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $occ = self::memberOccurrences($userId, ['programIds' => [$programId], 'to' => Dates::addDays(Dates::todayLocal($now), 60)], $now);
        $past = array_values(array_filter($occ, fn ($o) => $o['status'] !== 'upcoming'));
        return [
            'occurrences' => array_map(fn ($o) => ['date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at'], 'status' => $o['status']], array_reverse($occ)),
            'stats' => self::statsOf($past, Settings::permissionPolicy()['weight']),
        ];
    }

    public static function forUser(int $userId, array $page): array
    {
        $user = DB::table('users')->where('id', $userId)->first(['id', 'full_name', 'member_no', 'member_group']);
        $userName = $user->full_name ?? '';
        $memberId = $user ? MemberIds::format($user->member_no, $user->member_group) : '';

        $allOccurrences = self::memberOccurrences($userId);
        $all = array_reverse(array_values(array_filter($allOccurrences, fn ($o) => in_array($o['status'], ['present', 'late', 'excused', 'absent'], true))));

        // Fetch actual recorded attendance records for this user
        $realRecordsQuery = DB::table('attendance as a')->where('a.user_id', $userId);
        $realCols = ['a.id', 'a.program_id', 'a.occurrence_date', 'a.status', 'a.attended_at', 'a.client_captured_at'];
        if (Schema::hasColumn('attendance', 'signature_id')) {
            $realCols[] = 'a.signature_id';
        }
        if (Schema::hasTable('attendance_signatures')) {
            $realRecordsQuery->leftJoin('attendance_signatures as sig', 'sig.attendance_id', '=', 'a.id');
            $realCols[] = 'sig.path as signature_path';
        }
        $realRecords = $realRecordsQuery->select($realCols)
            ->get()
            ->keyBy(fn ($r) => "{$r->program_id}:" . Dates::toDateOnly($r->occurrence_date));

        $slice = array_slice($all, $page['offset'], $page['limit']);

        $items = array_map(function ($o) use ($realRecords, $userName, $memberId) {
            $key = "{$o['program_id']}:{$o['date']}";
            $real = $realRecords->get($key);

            $hasSig = $real && (! empty($real->signature_id) || ! empty($real->signature_path));
            $attendedAt = $real?->attended_at ?? $real?->client_captured_at;
            $status = $real?->status ?? $o['status'];

            $ethDate = EthiopianCalendar::gregorianToEthiopianDate($o['date']);
            $calendarDate = "{$ethDate['month_name_am']} {$ethDate['ethiopian_day']} ቀን {$ethDate['ethiopian_year']} ዓ.ም";

            $sigIndicator = $hasSig ? 'signed' : ($status === 'present' ? 'missing' : 'exempt');

            return [
                'id' => $real ? (int) $real->id : $key,
                'status' => $status,
                'attended_at' => $attendedAt ? Dates::iso($attendedAt) : null,
                'actual_time' => $attendedAt ? date('H:i:s', strtotime($attendedAt)) : null,
                'program_id' => (int) $o['program_id'],
                'program_name' => $o['title'],
                'program_title' => $o['title'],
                'member_name' => $userName,
                'member_id' => $memberId,
                'calendar_date' => $calendarDate,
                'ethiopian_date' => $ethDate['ethiopian_date'],
                'signature_status' => $sigIndicator,
                'signature_indicator' => $sigIndicator,
                'has_signature' => $hasSig,
                'signature_url' => ($real && $hasSig) ? "/api/v1/programs/attendance/signatures/{$real->id}" : null,
                'starts_at' => $o['starts_at'],
                'location' => $o['location'],
                'date' => $o['date'],
                'occurrence_date' => $o['date'],
                'category' => $o['category'],
            ];
        }, $slice);

        return [
            'items' => $items,
            'meta' => [
                'page' => $page['page'],
                'limit' => $page['limit'],
                'total' => count($all),
                'pages' => max(1, (int) ceil(count($all) / $page['limit'])),
            ],
        ];
    }

    public static function rateSummary(int $userId, array $f = []): array
    {
        $s = self::stats($userId, $f);
        return [
            'present' => $s['attended'],
            'late' => $s['late'],
            'excused' => $s['excused'],
            'absent' => $s['absent'],
            'total' => $s['total_programs'],
            'excused_weight' => $s['excused_weight'],
            'score' => Num::clean($s['attended'] + $s['late'] + $s['excused'] * $s['excused_weight']),
            'rate' => $s['percentage'],
        ];
    }

    // ------------------------------------------------------------------ Admin Attendance Management (History & Overview)
    private static function applyAdminFilters(\Illuminate\Database\Query\Builder $qb, array $f): \Illuminate\Database\Query\Builder
    {
        if (! empty($f['from'])) {
            $qb->where('a.occurrence_date', '>=', Dates::toDateOnly($f['from']));
        }
        if (! empty($f['to'])) {
            $qb->where('a.occurrence_date', '<=', Dates::toDateOnly($f['to']));
        }
        if (! empty($f['date'])) {
            $qb->where('a.occurrence_date', Dates::toDateOnly($f['date']));
        }
        if (! empty($f['program_id'])) {
            $qb->where('a.program_id', (int) $f['program_id']);
        }
        if (! empty($f['category_id'])) {
            $qb->where('p.category_id', (int) $f['category_id']);
        }
        if (! empty($f['status'])) {
            $st = $f['status'];
            if ($st === 'present') {
                $qb->whereIn('a.status', ['present', 'late']);
            } else {
                $qb->where('a.status', $st);
            }
        }
        if (! empty($f['taker_id'])) {
            $qb->where('a.recorded_by', (int) $f['taker_id']);
        }
        if (! empty($f['class_id']) && Schema::hasTable('attendance_edu_classes')) {
            $qb->whereExists(fn ($sq) => $sq->select(DB::raw(1))->from('attendance_edu_classes as aec')->whereColumn('aec.attendance_id', 'a.id')->where('aec.class_id', (int) $f['class_id']));
        }
        if (! empty($f['q'])) {
            $q = trim((string) $f['q']);
            $qb->where(function ($w) use ($q) {
                $w->where('u.full_name', 'like', "%{$q}%")
                  ->orWhere('u.phone', 'like', "%{$q}%")
                  ->orWhere('u.member_no', 'like', "%{$q}%")
                  ->orWhere('p.title', 'like', "%{$q}%");
            });
        }
        return $qb;
    }

    public static function adminOverview(array $f): array
    {
        $base = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id');

        $filtered = self::applyAdminFilters(clone $base, $f);

        $statusCounts = (clone $filtered)
            ->selectRaw("a.status, COUNT(*) as cnt")
            ->groupBy('a.status')
            ->pluck('cnt', 'status')
            ->all();

        $present = (int) (($statusCounts['present'] ?? 0) + ($statusCounts['late'] ?? 0));
        $absent = (int) ($statusCounts['absent'] ?? 0);
        $excused = (int) ($statusCounts['excused'] ?? 0);
        $total = $present + $absent + $excused;
        $rate = $total > 0 ? round(($present / $total) * 100, 1) : 0.0;

        $categories = (clone $filtered)
            ->whereNotNull('p.category_id')
            ->groupBy('p.category_id', 'pc.name', 'pc.color')
            ->selectRaw('p.category_id, COALESCE(pc.name, "Uncategorized") as name, pc.color, COUNT(*) as count')
            ->orderByDesc('count')
            ->limit(10)
            ->get();

        $programs = (clone $filtered)
            ->groupBy('p.id', 'p.title')
            ->selectRaw('p.id, p.title, COUNT(*) as count')
            ->orderByDesc('count')
            ->limit(10)
            ->get();

        $takers = (clone $filtered)
            ->leftJoin('users as t', 't.id', '=', 'a.recorded_by')
            ->whereNotNull('a.recorded_by')
            ->groupBy('a.recorded_by', 't.full_name')
            ->selectRaw('a.recorded_by as id, t.full_name as user_name, COUNT(*) as count')
            ->orderByDesc('count')
            ->limit(10)
            ->get()
            ->map(fn ($r) => [
                'id' => (int) $r->id,
                'name' => ! empty($r->user_name) ? $r->user_name : ('#' . $r->id),
                'count' => (int) $r->count,
            ])
            ->values();

        return [
            'total_records' => $total,
            'unique_attendees' => (clone $filtered)->distinct('a.user_id')->count('a.user_id'),
            'programs_count' => (clone $filtered)->distinct('a.program_id')->count('a.program_id'),
            'present' => $present,
            'absent' => $absent,
            'excused' => $excused,
            'attendance_rate' => $rate,
            'categories' => $categories,
            'programs' => $programs,
            'takers' => $takers,
        ];
    }

    public static function adminRecords(array $f, array $page): array
    {
        $qb = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->leftJoin('users as taker', 'taker.id', '=', 'a.recorded_by');
        $cols = [
            'a.id',
            'a.occurrence_date',
            'a.program_id',
            'p.title as program_title',
            'p.category_id',
            'pc.name as category_name',
            'pc.color as category_color',
            'a.user_id',
            'u.full_name as user_name',
            'u.member_no',
            'u.member_group',
            'u.phone',
            'u.profile_image',
            'a.status',
            'a.attended_at',
            'a.client_captured_at',
            'a.elapsed_seconds',
            'a.recorded_by',
            'taker.full_name as recorder_name',
            'a.via',
        ];
        if (Schema::hasColumn('attendance', 'notes')) {
            $cols[] = 'a.notes';
        }
        if (Schema::hasColumn('attendance', 'signature_id')) {
            $cols[] = 'a.signature_id';
        }
        if (Schema::hasTable('attendance_signatures')) {
            $qb->leftJoin('attendance_signatures as sig', 'sig.attendance_id', '=', 'a.id');
            $cols[] = 'sig.path as signature_path';
        }
        $qb->select($cols)
            ->orderByDesc('a.occurrence_date')
            ->orderByDesc('a.attended_at')
            ->orderByDesc('a.id');

        self::applyAdminFilters($qb, $f);

        $res = Page::paginate($qb, $page);

        $items = array_map(function ($r) {
            $hasSig = ! empty($r->signature_id) || ! empty($r->signature_path);
            $ethDate = EthiopianCalendar::gregorianToEthiopianDate(Dates::toDateOnly($r->occurrence_date));
            $calendarDate = "{$ethDate['month_name_am']} {$ethDate['ethiopian_day']} ቀን {$ethDate['ethiopian_year']} ዓ.ም";
            $sigIndicator = $hasSig ? 'signed' : ($r->status === 'present' ? 'missing' : 'exempt');
            return [
                'id' => (int) $r->id,
                'occurrence_date' => Dates::toDateOnly($r->occurrence_date),
                'date' => Dates::toDateOnly($r->occurrence_date),
                'calendar_date' => $calendarDate,
                'ethiopian_date' => $ethDate['ethiopian_date'],
                'program_id' => (int) $r->program_id,
                'program_name' => $r->program_title,
                'program_title' => $r->program_title,
                'category_id' => $r->category_id ? (int) $r->category_id : null,
                'category_name' => $r->category_name,
                'category_color' => $r->category_color,
                'user_id' => (int) $r->user_id,
                'user_name' => $r->user_name,
                'member_name' => $r->user_name,
                'member_no' => $r->member_no,
                'member_id' => MemberIds::format($r->member_no, $r->member_group),
                'member_group' => $r->member_group,
                'phone' => $r->phone,
                'user_photo' => Storage::url($r->profile_image),
                'status' => $r->status === 'late' ? 'present' : $r->status,
                'attended_at' => $r->attended_at ? Dates::iso($r->attended_at) : null,
                'actual_time' => $r->attended_at ? date('H:i:s', strtotime($r->attended_at)) : null,
                'client_captured_at' => $r->client_captured_at,
                'elapsed_seconds' => $r->elapsed_seconds !== null ? (int) $r->elapsed_seconds : null,
                'recorded_by' => $r->recorded_by ? (int) $r->recorded_by : null,
                'recorder_name' => $r->recorder_name,
                'via' => $r->via ?? 'manual',
                'has_signature' => $hasSig,
                'signature_status' => $sigIndicator,
                'signature_indicator' => $sigIndicator,
                'signature_id' => $r->signature_id ? (int) $r->signature_id : null,
                'signature_url' => $hasSig ? "/api/v1/programs/attendance/signatures/{$r->id}" : null,
                'notes' => $r->notes,
            ];
        }, $res['items']);

        return ['items' => $items, 'meta' => $res['meta']];
    }

    public static function adminExport(array $f): array
    {
        $all = self::adminRecords($f, ['page' => 1, 'limit' => 5000]);
        return [
            'exported_at' => Dates::sql(Dates::now()),
            'filters' => $f,
            'total' => count($all['items']),
            'records' => $all['items'],
        ];
    }

    /**
     * Year-wide month-by-month analytics summary for Ethiopian calendar (all 13 months).
     */
    public static function yearlySummary(array $f): array
    {
        $currentEth = EthiopianCalendar::todayInAddis();
        $year = (int) ($f['year'] ?? $currentEth['ethiopian_year']);
        if ($year < 1900 || $year > 2200) {
            $year = (int) $currentEth['ethiopian_year'];
        }

        $ethFrom = EthiopianCalendar::toGregorian($year, 1, 1)->format('Y-m-d');
        $pagumeDays = EthiopianCalendar::daysInMonth($year, 13);
        $ethTo = EthiopianCalendar::toGregorian($year, 13, $pagumeDays)->format('Y-m-d');

        $base = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->whereBetween('a.occurrence_date', [$ethFrom, $ethTo]);

        if (! empty($f['member_group'])) $base->where('u.member_group', $f['member_group']);
        if (! empty($f['member_type'])) $base->where('u.member_type', $f['member_type']);
        if (! empty($f['category_id'])) $base->where('p.category_id', (int) $f['category_id']);
        if (! empty($f['program_id'])) $base->where('p.id', (int) $f['program_id']);

        $records = $base->select('a.occurrence_date', 'a.status', 'a.program_id', 'a.user_id')->get();

        $totalPresent = 0;
        $totalAbsent = 0;
        $totalExcused = 0;

        $monthBuckets = [];
        for ($m = 1; $m <= 13; $m++) {
            $days = EthiopianCalendar::daysInMonth($year, $m);
            $mFrom = EthiopianCalendar::toGregorian($year, $m, 1)->format('Y-m-d');
            $mTo = EthiopianCalendar::toGregorian($year, $m, $days)->format('Y-m-d');
            $monthBuckets[$m] = [
                'month' => $m,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$m],
                'month_name_en' => EthiopianCalendar::MONTHS_EN[$m],
                'from_date' => $mFrom,
                'to_date' => $mTo,
                'present' => 0,
                'absent' => 0,
                'excused' => 0,
                'expected' => 0,
                'attendance_rate' => 0.0,
                'session_count' => 0,
                'sessions' => [],
            ];
        }

        $sessionsYear = [];

        foreach ($records as $r) {
            $dateOnly = Dates::toDateOnly($r->occurrence_date);
            [$gy, $gm, $gd] = array_map('intval', explode('-', substr($dateOnly, 0, 10)));
            $eth = EthiopianCalendar::fromGregorian($gy, $gm, $gd);
            $m = (int) $eth['month'];
            if ($m < 1 || $m > 13) continue;

            $status = $r->status;
            $isPres = in_array($status, ['present', 'late'], true);
            $isAbs = $status === 'absent';
            $isExc = $status === 'excused';

            if ($isPres) {
                $totalPresent++;
                $monthBuckets[$m]['present']++;
            } elseif ($isAbs) {
                $totalAbsent++;
                $monthBuckets[$m]['absent']++;
            } elseif ($isExc) {
                $totalExcused++;
                $monthBuckets[$m]['excused']++;
            }

            $sessKey = "{$r->program_id}:$dateOnly";
            $sessionsYear[$sessKey] = true;
            $monthBuckets[$m]['sessions'][$sessKey] = true;
        }

        $monthlyList = [];
        foreach ($monthBuckets as $m => $b) {
            $expected = $b['present'] + $b['absent'] + $b['excused'];
            $rate = $expected > 0 ? round(($b['present'] / $expected) * 100, 1) : 0.0;
            $b['expected'] = $expected;
            $b['attendance_rate'] = $rate;
            $b['session_count'] = count($b['sessions']);
            unset($b['sessions']);
            $monthlyList[] = $b;
        }

        $totalExpected = $totalPresent + $totalAbsent + $totalExcused;
        $overallRate = $totalExpected > 0 ? round(($totalPresent / $totalExpected) * 100, 1) : 0.0;

        return [
            'year' => $year,
            'gregorian_from' => $ethFrom,
            'gregorian_to' => $ethTo,
            'total_present' => $totalPresent,
            'total_absent' => $totalAbsent,
            'total_excused' => $totalExcused,
            'total_expected' => $totalExpected,
            'attendance_rate' => $overallRate,
            'total_sessions' => count($sessionsYear),
            'months' => $monthlyList,
        ];
    }

    /**
     * Single Ethiopian month attendance summary.
     */
    public static function monthlySummary(array $f): array
    {
        $currentEth = EthiopianCalendar::todayInAddis();
        $year = (int) ($f['year'] ?? $currentEth['ethiopian_year']);
        $month = (int) ($f['month'] ?? $currentEth['ethiopian_month']);
        $month = max(1, min(13, $month));

        $days = EthiopianCalendar::daysInMonth($year, $month);
        $mFrom = EthiopianCalendar::toGregorian($year, $month, 1)->format('Y-m-d');
        $mTo = EthiopianCalendar::toGregorian($year, $month, $days)->format('Y-m-d');

        $f['from'] = $mFrom;
        $f['to'] = $mTo;

        $ov = self::adminOverview($f);

        $sessions = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->whereBetween('a.occurrence_date', [$mFrom, $mTo])
            ->when(! empty($f['program_id']), fn ($q) => $q->where('a.program_id', (int) $f['program_id']))
            ->select('a.program_id', 'a.occurrence_date')
            ->distinct()
            ->get()
            ->count();

        // Detailed program occurrences in the selected month for Phase 6.1
        $publishedPrograms = DB::table('programs as p')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->where('p.status', 'published')
            ->where('p.requires_attendance', true)
            ->when(! empty($f['program_id']), fn ($q) => $q->where('p.id', (int) $f['program_id']))
            ->select('p.*', 'pc.name as category_name')
            ->when(Schema::hasColumn('program_categories', 'name_en'), fn ($q) => $q->addSelect('pc.name_en as category_name_en'))
            ->when(Schema::hasColumn('program_categories', 'color'), fn ($q) => $q->addSelect('pc.color as category_color'))
            ->get();
        Schedule::loadOverrides($publishedPrograms);

        $monthOccurrences = [];
        $todayLocal = Dates::todayLocal();
        foreach ($publishedPrograms as $p) {
            foreach (Schedule::between($p, $mFrom, $mTo, null, true) as $o) {
                $occDate = $o['date'];
                $attStats = DB::table('attendance')
                    ->where('program_id', $p->id)
                    ->where('occurrence_date', $occDate)
                    ->selectRaw('
                        SUM(CASE WHEN status IN ("present", "late") THEN 1 ELSE 0 END) as present_count,
                        SUM(CASE WHEN status = "absent" THEN 1 ELSE 0 END) as absent_count,
                        SUM(CASE WHEN status = "excused" THEN 1 ELSE 0 END) as excused_count,
                        COUNT(*) as total_marked
                    ')
                    ->first();

                $expectedMembersCount = self::expectedMembers($p, $occDate)->count();
                $presentCount = (int) ($attStats->present_count ?? 0);
                $absentCount = (int) ($attStats->absent_count ?? 0);
                $excusedCount = (int) ($attStats->excused_count ?? 0);
                $totalMarked = (int) ($attStats->total_marked ?? 0);
                $expected = max($expectedMembersCount, $totalMarked);

                $startsTime = Dates::of($o['starts_at'])->format('H:i');
                $endsTime = Dates::of($o['ends_at'])->format('H:i');

                $monthOccurrences[] = [
                    'program_id' => (int) $p->id,
                    'program_title' => $p->title,
                    'category_name' => $p->category_name ?? null,
                    'category_color' => $p->category_color ?? null,
                    'date' => $occDate,
                    'starts_at' => Dates::sql(Dates::of($o['starts_at'])),
                    'ends_at' => Dates::sql(Dates::of($o['ends_at'])),
                    'starts_time' => $startsTime,
                    'ends_time' => $endsTime,
                    'is_past' => $occDate < $todayLocal,
                    'is_today' => $occDate === $todayLocal,
                    'expected' => $expected,
                    'present' => $presentCount,
                    'absent' => $absentCount,
                    'excused' => $excusedCount,
                    'suspended' => ! empty($o['suspended']),
                    'cancelled' => ! empty($o['cancelled']),
                ];
            }
        }

        usort($monthOccurrences, function ($a, $b) {
            $cmp = strcmp($a['date'], $b['date']);
            return $cmp !== 0 ? $cmp : strcmp($a['starts_at'], $b['starts_at']);
        });

        return [
            'year' => $year,
            'month' => $month,
            'month_name_am' => EthiopianCalendar::MONTHS_AM[$month],
            'month_name_en' => EthiopianCalendar::MONTHS_EN[$month],
            'from_date' => $mFrom,
            'to_date' => $mTo,
            'present' => $ov['present'],
            'absent' => $ov['absent'],
            'excused' => $ov['excused'],
            'expected' => $ov['total_records'],
            'attendance_rate' => $ov['attendance_rate'],
            'session_count' => $sessions,
            'categories' => $ov['categories'],
            'programs' => $ov['programs'],
            'occurrences' => $monthOccurrences,
        ];
    }

    /**
     * Program-based attendance overview.
     */
    public static function byProgram(array $f): array
    {
        $currentEth = EthiopianCalendar::todayInAddis();
        $year = (int) ($f['year'] ?? $currentEth['ethiopian_year']);
        $ethFrom = EthiopianCalendar::toGregorian($year, 1, 1)->format('Y-m-d');
        $pagumeDays = EthiopianCalendar::daysInMonth($year, 13);
        $ethTo = EthiopianCalendar::toGregorian($year, 13, $pagumeDays)->format('Y-m-d');

        $programs = DB::table('programs as p')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->where('p.status', 'published')
            ->where('p.requires_attendance', true)
            ->select('p.id', 'p.title', 'p.category_id', 'pc.name as category_name', 'pc.color as category_color')
            ->orderBy('p.title')
            ->get();

        $out = [];
        foreach ($programs as $p) {
            $att = DB::table('attendance')
                ->where('program_id', $p->id)
                ->whereBetween('occurrence_date', [$ethFrom, $ethTo])
                ->selectRaw('
                    COUNT(DISTINCT occurrence_date) as session_count,
                    SUM(CASE WHEN status IN ("present", "late") THEN 1 ELSE 0 END) as present_count,
                    SUM(CASE WHEN status = "absent" THEN 1 ELSE 0 END) as absent_count,
                    SUM(CASE WHEN status = "excused" THEN 1 ELSE 0 END) as excused_count,
                    COUNT(*) as total_records
                ')
                ->first();

            $pres = (int) ($att->present_count ?? 0);
            $total = (int) ($att->total_records ?? 0);
            $rate = $total > 0 ? round(($pres / $total) * 100, 1) : 0.0;

            // Check suspended occurrences safely across overrides table or occurrences
            $suspendedCount = 0;
            if (Schema::hasTable('program_occurrence_overrides')) {
                $suspendedCount += DB::table('program_occurrence_overrides')
                    ->where('program_id', $p->id)
                    ->whereBetween('occurrence_date', [$ethFrom, $ethTo])
                    ->where('action', 'suspended')
                    ->count();
            }
            if ($suspendedCount === 0 && Schema::hasTable('program_occurrences')) {
                $suspendedCount += DB::table('program_occurrences')
                    ->where('program_id', $p->id)
                    ->whereBetween('occurrence_date', [$ethFrom, $ethTo])
                    ->where('is_suspended', true)
                    ->count();
            }

            $out[] = [
                'id' => $p->id,
                'title' => $p->title,
                'category_id' => $p->category_id,
                'category_name' => $p->category_name ?? 'Uncategorized',
                'category_color' => $p->category_color,
                'session_count' => (int) ($att->session_count ?? 0),
                'suspended_count' => $suspendedCount,
                'present_count' => $pres,
                'absent_count' => (int) ($att->absent_count ?? 0),
                'excused_count' => (int) ($att->excused_count ?? 0),
                'total_expected' => $total,
                'attendance_rate' => $rate,
            ];
        }

        return $out;
    }

    /**
     * Search members for Admin Attendance by name, member_no, phone, or id.
     */
    public static function searchMembers(?string $query): array
    {
        if (empty($query)) return [];
        $s = '%' . trim($query) . '%';
        return DB::table('users as u')
            ->whereNull('u.deleted_at')
            ->where(function ($w) use ($s, $query) {
                $w->where('u.full_name', 'like', $s)
                  ->orWhere('u.phone', 'like', $s)
                  ->orWhere('u.member_no', 'like', $s);
                if (is_numeric($query)) {
                    $w->orWhere('u.id', (int) $query);
                }
            })
            ->select('u.id', 'u.full_name', 'u.member_no', 'u.phone', 'u.profile_image', 'u.member_group', 'u.status')
            ->limit(25)
            ->get()
            ->map(function ($u) {
                return [
                    'id' => (int) $u->id,
                    'full_name' => $u->full_name,
                    'member_no' => $u->member_no,
                    'phone' => $u->phone,
                    'avatar_url' => Storage::url($u->profile_image),
                    'member_group' => $u->member_group,
                    'status' => $u->status,
                ];
            })
            ->all();
    }

    /**
     * Admin member attendance profile & history across all 13 Ethiopian months.
     */
    public static function adminMemberProfile(int $userId, int $year = 0): array
    {
        $u = DB::table('users')->where('id', $userId)->first(['id', 'full_name', 'phone', 'member_no', 'member_group', 'member_type', 'profile_image']);
        if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');

        $currentEth = EthiopianCalendar::todayInAddis();
        if ($year < 1900 || $year > 2200) $year = (int) $currentEth['ethiopian_year'];

        $ethFrom = EthiopianCalendar::toGregorian($year, 1, 1)->format('Y-m-d');
        $pagumeDays = EthiopianCalendar::daysInMonth($year, 13);
        $ethTo = EthiopianCalendar::toGregorian($year, 13, $pagumeDays)->format('Y-m-d');

        $qb = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->leftJoin('users as taker', 'taker.id', '=', 'a.recorded_by')
            ->where('a.user_id', $userId)
            ->whereBetween('a.occurrence_date', [$ethFrom, $ethTo]);
        $cols = [
            'a.*',
            'p.title as program_title',
            'pc.name as category_name',
            'pc.color as category_color',
            'taker.full_name as recorder_name',
        ];
        if (Schema::hasTable('attendance_signatures')) {
            $qb->leftJoin('attendance_signatures as sig', 'sig.attendance_id', '=', 'a.id');
            $cols[] = 'sig.path as signature_path';
        }
        $records = $qb->select($cols)
            ->orderByDesc('a.occurrence_date')
            ->get();

        $monthStats = [];
        for ($m = 1; $m <= 13; $m++) {
            $monthStats[$m] = [
                'month' => $m,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$m],
                'month_name_en' => EthiopianCalendar::MONTHS_EN[$m],
                'present' => 0,
                'absent' => 0,
                'excused' => 0,
                'expected' => 0,
                'attendance_rate' => 0.0,
            ];
        }

        $presTotal = 0;
        $absTotal = 0;
        $excTotal = 0;
        $allRecords = [];
        $progStats = [];

        foreach ($records as $r) {
            $dateOnly = Dates::toDateOnly($r->occurrence_date);
            [$gy, $gm, $gd] = array_map('intval', explode('-', substr($dateOnly, 0, 10)));
            $eth = EthiopianCalendar::fromGregorian($gy, $gm, $gd);
            $m = (int) $eth['month'];
            if ($m >= 1 && $m <= 13) {
                if (in_array($r->status, ['present', 'late'], true)) {
                    $presTotal++;
                    $monthStats[$m]['present']++;
                } elseif ($r->status === 'absent') {
                    $absTotal++;
                    $monthStats[$m]['absent']++;
                } elseif ($r->status === 'excused') {
                    $excTotal++;
                    $monthStats[$m]['excused']++;
                }
            }

            // Group by program
            $pid = (int) $r->program_id;
            if (! isset($progStats[$pid])) {
                $progStats[$pid] = [
                    'program_id' => $pid,
                    'program_title' => $r->program_title,
                    'category_name' => $r->category_name,
                    'category_color' => $r->category_color,
                    'present' => 0,
                    'absent' => 0,
                    'excused' => 0,
                    'total' => 0,
                    'rate' => 0.0,
                ];
            }
            if (in_array($r->status, ['present', 'late'], true)) {
                $progStats[$pid]['present']++;
            } elseif ($r->status === 'absent') {
                $progStats[$pid]['absent']++;
            } elseif ($r->status === 'excused') {
                $progStats[$pid]['excused']++;
            }
            $progStats[$pid]['total']++;

            $hasSig = ! empty($r->signature_id) || ! empty($r->signature_path);
            $calendarDate = "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም";
            $allRecords[] = [
                'id' => (int) $r->id,
                'occurrence_date' => $dateOnly,
                'calendar_date' => $calendarDate,
                'ethiopian_date' => $eth['date'],
                'program_id' => (int) $r->program_id,
                'program_title' => $r->program_title,
                'category_name' => $r->category_name,
                'category_color' => $r->category_color,
                'status' => $r->status,
                'attended_at' => $r->attended_at,
                'recorded_by' => $r->recorded_by ? (int) $r->recorded_by : null,
                'recorder_name' => $r->recorder_name,
                'notes' => $r->notes,
                'has_signature' => $hasSig,
                'signature_status' => $hasSig ? 'signed' : ($r->status === 'present' ? 'missing' : 'exempt'),
                'signature_url' => $hasSig ? "/api/v1/programs/attendance/signatures/{$r->id}" : null,
            ];
        }

        foreach ($monthStats as $m => &$b) {
            $exp = $b['present'] + $b['absent'] + $b['excused'];
            $b['expected'] = $exp;
            $b['attendance_rate'] = $exp > 0 ? round(($b['present'] / $exp) * 100, 1) : 0.0;
        }
        unset($b);

        foreach ($progStats as &$ps) {
            $ps['rate'] = $ps['total'] > 0 ? round(($ps['present'] / $ps['total']) * 100, 1) : 0.0;
        }
        unset($ps);

        $grandExpected = $presTotal + $absTotal + $excTotal;
        $grandRate = $grandExpected > 0 ? round(($presTotal / $grandExpected) * 100, 1) : 0.0;

        return [
            'user' => [
                'id' => $u->id,
                'full_name' => $u->full_name,
                'phone' => $u->phone,
                'member_no' => $u->member_no,
                'member_group' => $u->member_group,
                'member_type' => $u->member_type,
                'profile_image' => $u->profile_image,
                'avatar_url' => Storage::url($u->profile_image),
            ],
            'year' => $year,
            'total_present' => $presTotal,
            'total_absent' => $absTotal,
            'total_excused' => $excTotal,
            'total_expected' => $grandExpected,
            'attendance_rate' => $grandRate,
            'months' => array_values($monthStats),
            'programs_breakdown' => array_values($progStats),
            'recent_records' => $allRecords,
            'records' => $allRecords,
        ];
    }

    /**
     * Member's own yearly summary & monthly breakdown (strictly scoped to auth user).
     */
    public static function myYearlySummary(int $userId, int $year = 0): array
    {
        return self::adminMemberProfile($userId, $year);
    }
}
