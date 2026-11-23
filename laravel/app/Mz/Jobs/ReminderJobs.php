<?php

namespace App\Mz\Jobs;

use App\Mz\Db\Locks;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\Edu;
use App\Mz\Services\Fines;
use App\Mz\Services\MemberIds;
use App\Mz\Services\Programs;
use App\Mz\Services\Schedule;
use App\Mz\Services\Settings;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\T;
use DateTimeImmutable;
use DateTimeInterface;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Idempotent reminder generation (port of jobs/reminderJobs.js). Running a job twice (or from two
 * requests at once) never duplicates notifications: each reminder period has a unique dedupe_key.
 */
final class ReminderJobs
{
    private const PROGRAM_COLS = ['id', 'title', 'location', 'starts_at', 'ends_at', 'recurrence', 'monthly_rule', 'recurrence_until', 'ethiopian_days', 'audience', 'member_groups'];

    /** Published programs with an occurrence still ahead, each narrowed to that next occurrence. */
    private static function nextOccurrences(DateTimeInterface $now, array $extraCols = [], ?callable $extra = null): array
    {
        $today = Dates::todayLocal($now);
        $nowSql = Dates::sql($now);
        $q = DB::table('programs')->where('status', 'published')
            ->where(fn ($w) => $w->where(fn ($x) => $x->where('recurrence', 'once')->where('starts_at', '>', $nowSql))
                ->orWhere(fn ($x) => $x->where('recurrence', '!=', 'once')->where(fn ($y) => $y->whereNull('recurrence_until')->orWhere('recurrence_until', '>=', $today))))
            ->select(array_merge(self::PROGRAM_COLS, $extraCols));
        if ($extra) $extra($q);
        $rows = $q->get()->all();
        Schedule::loadOverrides($rows);
        $out = [];
        foreach ($rows as $p) {
            $o = Schedule::next($p, $now);
            if ($o && Dates::of($o['starts_at']) > $now) {
                $p->starts_at = Dates::of($o['starts_at']);
                $p->occurrence_date = $o['date'];
                $out[] = $p;
            }
        }
        return $out;
    }

    /** Users whose preferred reminder time (HH:mm, local) has been reached today. */
    private static function reminderTimeReached(Builder $qb, DateTimeInterface $now): Builder
    {
        $hhmm = DateTimeImmutable::createFromInterface($now)->setTimezone(Dates::tz())->format('H:i');
        return $qb->where(fn ($w) => $w->whereNull('p.reminder_time')->orWhere('p.reminder_time', '<=', $hhmm));
    }

    public static function recipients(object $p): Builder
    {
        // Administrators are members too: they get the same program reminders.
        $q = MemberIds::memberAccounts(DB::table('users as u'))->where('u.status', 'active')->where('u.membership_status', 'active');
        if ($p->member_groups) $q->whereIn('u.member_group', explode(',', $p->member_groups));
        if ($p->audience === 'participants') {
            $q->join('program_participants as pp', 'pp.user_id', '=', 'u.id')->where('pp.program_id', $p->id)->whereIn('pp.status', ['invited', 'registered']);
        }

        // Education scoping: If program has linked classes, only notify enrolled students and course teachers
        if (\Illuminate\Support\Facades\Schema::hasTable('program_edu_classes')) {
            $hasClasses = DB::table('program_edu_classes')->where('program_id', $p->id)->exists();
            if ($hasClasses) {
                $q->where(function ($w) use ($p) {
                    $w->whereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')
                        ->join('edu_enrollments as ee', 'ee.class_id', '=', 'pec.class_id')
                        ->where('pec.program_id', $p->id)
                        ->whereColumn('ee.user_id', 'u.id')
                        ->where('ee.status', 'active')
                    )->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec_t')
                        ->join('edu_courses as eco', 'eco.class_id', '=', 'pec_t.class_id')
                        ->where('pec_t.program_id', $p->id)
                        ->whereColumn('eco.teacher_user_id', 'u.id')
                    );
                });
            }
        }

        $q->distinct();
        return $q;
    }

    /**
     * Reminders before each occurrence at the program's offsets (2 days / 1 day / 6 hours / 1 hour
     * before), or at the member's own choice for that program. Each (occurrence, offset, member) is
     * sent once; when several offsets are already due (late run, program created late) only the
     * closest one is sent.
     */
    public static function programReminders(?DateTimeInterface $now = null): ?array
    {
        $now ??= Dates::now();
        return Locks::named('mz:job:program-reminders', function () use ($now) {
            $programs = self::nextOccurrences($now, ['reminder_offsets', 'reminder_title', 'reminder_body', 'is_mandatory_reminder'], fn ($q) => $q->where(fn ($w) => $w->where('reminder_enabled', true)->orWhere('is_mandatory_reminder', true)));
            $nowMs = Dates::ms($now);
            $created = 0;
            foreach ($programs as $p) {
                $startMs = Dates::ms($p->starts_at);
                $minutesLeft = ($startMs - $nowMs) / 60000;
                if ($minutesLeft > 2880 + 5) continue; // nothing can be due yet
                $default = Programs::offsetsOf($p->reminder_offsets);
                $isMandatory = ! empty($p->is_mandatory_reminder);
                $choices = DB::table('program_reminder_choices')->where('program_id', $p->id)->pluck('offsets', 'user_id')->all();
                $ids = self::recipients($p)->pluck('u.id')->all();
                // user id => offset to send now
                $byOffset = [];
                foreach ($ids as $uid) {
                    $offsets = ($isMandatory || ! array_key_exists($uid, $choices)) ? $default : Programs::offsetsOf($choices[$uid]);
                    if ($isMandatory && empty($offsets)) $offsets = $default ?: [1440, 60];
                    $due = array_values(array_filter($offsets, fn ($o) => $o >= $minutesLeft));
                    if (! $due) continue;
                    $byOffset[min($due)][] = (int) $uid;
                }
                $startKey = $p->starts_at->setTimezone(new \DateTimeZone('UTC'))->format('YmdHi');
                foreach ($byOffset as $offset => $uids) {
                    $left = max(1, (int) round($minutesLeft));
                    $created += Notifications::createForUsers($uids, [
                        'type' => 'program_reminder',
                        'title' => $p->reminder_title ?: T::t('program.reminder.title'),
                        'body' => $p->reminder_body ?: self::reminderBody($p, $left),
                        'entityType' => 'program',
                        'entityId' => $p->id,
                        'data' => ['offset' => $offset, 'starts_at' => Dates::iso($p->starts_at)],
                        'dedupeKey' => fn ($uid) => "program:{$p->id}:$startKey:off$offset:$uid",
                    ]);
                }
            }
            $created += self::startingSoon($now);
            $created += self::intervalReminders($now);
            $created += Edu::runClassReminders($now);
            return ['programs' => count($programs), 'created' => $created];
        });
    }

    /** Local hours in which an every-N-days reminder may go out (no messages at night). */
    private const INTERVAL_HOURS = [8, 21];

    /**
     * Every-N-days reminders (15 by policy). Cycle k of a program falls on start + k·N calendar days
     * (local time). Only the current cycle is ever sent — a cycle missed while no job ran is not
     * replayed later, so there is never a backlog — and each (program, cycle, member) once, keyed in
     * the notification dedupe key, so restarts and repeated runs cannot duplicate it. It stops by
     * itself once the program is cancelled, completed, unpublished or past its last day.
     */
    public static function intervalReminders(?DateTimeInterface $now = null): int
    {
        $now ??= Dates::now();
        $local = DateTimeImmutable::createFromInterface($now)->setTimezone(Dates::tz());
        $hour = (int) $local->format('G');
        if ($hour < self::INTERVAL_HOURS[0] || $hour >= self::INTERVAL_HOURS[1]) return 0;
        $today = $local->format('Y-m-d');
        $rows = DB::table('programs as p')->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->where('p.status', 'published')
            ->where('p.reminder_enabled', true)
            ->where('p.reminder_interval_days', '>', 0)
            ->whereNotNull('p.reminder_interval_start')
            ->where('p.reminder_interval_start', '<=', $today)
            ->select(array_merge(array_map(fn ($c) => "p.$c", self::PROGRAM_COLS), ['p.reminder_interval_days', 'p.reminder_interval_start', 'p.reminder_body', 'pc.name as type_name']))
            ->get()->all();
        Schedule::loadOverrides($rows);
        $created = 0;
        foreach ($rows as $p) {
            $last = $p->recurrence === 'once' ? Dates::of($p->ends_at)->setTimezone(Dates::tz())->format('Y-m-d') : Dates::toDateOnly($p->recurrence_until);
            if ($last !== null && $today > $last) continue;
            $n = (int) $p->reminder_interval_days;
            $start = Dates::toDateOnly($p->reminder_interval_start);
            $cycle = intdiv((int) (new DateTimeImmutable($start))->diff(new DateTimeImmutable($today))->days, $n);
            $next = Schedule::next($p, $now);
            if (! $next && $p->recurrence !== 'once') continue;
            $ids = self::recipients($p)->pluck('u.id')->all();
            if (! $ids) continue;
            $when = $next ? Dates::of($next['starts_at']) : Dates::of($p->starts_at);
            $sent = Notifications::createForUsers($ids, [
                'type' => 'program_reminder',
                'title' => T::t('program.interval.title', ['title' => $p->title]),
                'body' => T::t('program.interval.body', [
                    'title' => $p->title,
                    'type' => $p->type_name ?: '-',
                    'date' => DateTimeImmutable::createFromInterface($when)->setTimezone(Dates::tz())->format('Y-m-d H:i'),
                    'location' => $p->location ?: '-',
                ]) . ($p->reminder_body ? "\n" . $p->reminder_body : ''),
                'entityType' => 'program',
                'entityId' => $p->id,
                'data' => ['interval_days' => $n, 'cycle' => $cycle, 'starts_at' => Dates::iso($when)],
                'dedupeKey' => fn ($uid) => "program:{$p->id}:every$n:$start:c$cycle:$uid",
            ]);
            if ($sent) DB::table('programs')->where('id', $p->id)->update(['reminder_interval_last_at' => Dates::sql($now)]);
            $created += $sent;
        }
        return $created;
    }

    private static function reminderBody(object $p, int $minutesLeft): string
    {
        $loc = $p->location ?: '-';
        if ($minutesLeft >= 1440 - 60) {
            $days = (int) round($minutesLeft / 1440);
            $when = $days <= 1 ? T::t('program.reminder.when.tomorrow') : T::t('program.reminder.when.days', ['days' => $days]);
            return T::t('program.reminder.body', ['title' => $p->title, 'when' => $when, 'location' => $loc]);
        }
        return T::t('program.soon.body', ['title' => $p->title, 'minutes' => $minutesLeft, 'location' => $loc]);
    }

    /** Automatic alarm shortly before a program starts (minutes_before, default 30). */
    private static function startingSoon(DateTimeInterface $now): int
    {
        $cfg = Settings::get('programs.reminder_defaults') ?: [];
        $minutes = $cfg['minutes_before'] ?? 30;
        if (! $minutes) return 0;
        $horizon = DateTimeImmutable::createFromInterface($now)->modify("+$minutes minutes");
        $created = 0;
        foreach (self::nextOccurrences($now) as $p) {
            if ($p->starts_at > $horizon) continue;
            $ids = self::recipients($p)->pluck('u.id')->all();
            if (! $ids) continue;
            $left = max(1, Num::jsRound((Dates::ms($p->starts_at) - Dates::ms($now)) / 60000));
            $startKey = $p->starts_at->setTimezone(new \DateTimeZone('UTC'))->format('YmdHi');
            $created += Notifications::createForUsers($ids, [
                'type' => 'program_reminder',
                'title' => T::t('program.soon.title'),
                'body' => T::t('program.soon.body', ['title' => $p->title, 'minutes' => $left, 'location' => $p->location ?: '-']),
                'entityType' => 'program',
                'entityId' => $p->id,
                'dedupeKey' => fn ($uid) => "program:{$p->id}:$startKey:soon:$uid",
            ]);
        }
        return $created;
    }

    /** Borrowing deadline sequence: N..1 days before, the deadline day, then overdue (day 1 and every N days). */
    public static function borrowingReminders(?DateTimeInterface $now = null): ?array
    {
        $now ??= Dates::now();
        return Locks::named('mz:job:borrowing-reminders', function () use ($now) {
            $today = Dates::todayLocal($now);
            $cfg = Settings::get('borrowing.reminders') ?: ['days_before' => 3, 'overdue_repeat_days' => 7];
            $finePolicy = Settings::get('fines.policy');
            $horizon = Dates::addDays($today, (int) $cfg['days_before']);
            $rows = self::reminderTimeReached(
                DB::table('borrowings as b')->join('items as i', 'i.id', '=', 'b.item_id')->join('users as u', 'u.id', '=', 'b.user_id')
                    ->leftJoin('user_preferences as p', 'p.user_id', '=', 'u.id')
                    ->whereIn('b.status', ['active', 'partially_returned'])->where('b.due_on', '<=', $horizon)->where('u.status', 'active')->whereNull('u.deleted_at'),
                $now,
            )->select('b.id', 'b.user_id', 'b.due_on', 'b.fine_amount', 'b.fine_overridden', 'i.name as item_name')->get();
            $created = 0;
            foreach ($rows as $b) {
                $due = Dates::toDateOnly($b->due_on);
                $stage = Fines::reminderStage($due, $today, $cfg);
                if (! $stage) continue;
                if ($stage['kind'] === 'due') {
                    $type = 'borrowing_due';
                    $title = T::t('borrowing.due.title');
                    $body = $stage['days'] === 0 ? T::t('borrowing.due.body.today', ['item' => $b->item_name]) : T::t('borrowing.due.body.days', ['item' => $b->item_name, 'days' => $stage['days'], 'due' => $due]);
                } else {
                    $type = 'borrowing_overdue';
                    $title = T::t('borrowing.overdue.title');
                    $fine = $b->fine_overridden ? Num::n($b->fine_amount) : Fines::compute($due, $today, $finePolicy ?? []);
                    $body = $fine > 0
                        ? T::t('borrowing.overdue.body.fine', ['item' => $b->item_name, 'days' => $stage['days'], 'fine' => $fine, 'currency' => ($finePolicy['currency'] ?? null) ?: 'ETB'])
                        : T::t('borrowing.overdue.body', ['item' => $b->item_name, 'days' => $stage['days']]);
                }
                $created += Notifications::createForUsers([(int) $b->user_id], [
                    'type' => $type, 'title' => $title, 'body' => $body, 'entityType' => 'borrowing', 'entityId' => $b->id, 'email' => true,
                    'dedupeKey' => fn () => "borrow:{$b->id}:$due:{$stage['key']}",
                ]);
            }
            return ['checked' => $rows->count(), 'created' => $created];
        });
    }
}
