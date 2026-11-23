<?php

namespace App\Mz\Services;

use App\Mz\Db\UtcDateTime;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use DateTimeImmutable;
use DateTimeZone;
use Generator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Program occurrences, calculated, never stored (port of programSchedule.js).
 *   once / weekly / monthly (day_of_month | nth_weekday) / ethiopian_days.
 * Every occurrence keeps the first one's local start time and duration. Overrides (cancelled /
 * rescheduled) are attached with loadOverrides() as $p->_overrides[date].
 */
final class Schedule
{
    private const MAX_OCCURRENCES = 1000;

    /** Attach each program's occurrence overrides. Accepts one program object, a list, or a Collection. */
    public static function loadOverrides(mixed $programs): mixed
    {
        $list = is_array($programs) ? $programs : ($programs instanceof \Illuminate\Support\Collection ? $programs->all() : [$programs]);
        $ids = array_values(array_filter(array_map(fn ($p) => $p?->id, $list)));
        if (! $ids) return $programs;
        if (! Schema::hasTable('program_occurrence_overrides')) {
            foreach ($list as $p) {
                if ($p) $p->_overrides = [];
            }
            return $programs;
        }
        $by = [];
        foreach (DB::table('program_occurrence_overrides')->whereIn('program_id', $ids)->select('program_id', 'occurrence_date', 'action', 'starts_at', 'ends_at', 'reason')->get() as $r) {
            $by[$r->program_id][Dates::toDateOnly($r->occurrence_date)] = $r;
        }
        foreach ($list as $p) {
            if ($p) $p->_overrides = $by[$p->id] ?? [];
        }
        return $programs;
    }

    private static function tz(?string $tz = null): DateTimeZone
    {
        return new DateTimeZone($tz ?? (string) config('mz.timezone'));
    }

    private static function local(mixed $d, ?string $tz = null): DateTimeImmutable
    {
        return DateTimeImmutable::createFromInterface(Dates::of($d))->setTimezone(self::tz($tz));
    }

    public static function localDate(mixed $d, ?string $tz = null): string
    {
        return self::local($d, $tz)->format('Y-m-d');
    }

    private static function atLocal(string $date, string $time, ?string $tz = null): UtcDateTime
    {
        $d = new DateTimeImmutable("$date $time", self::tz($tz));
        return new UtcDateTime('@' . $d->getTimestamp());
    }

    private static function plusMs(UtcDateTime $d, int $ms): UtcDateTime
    {
        return new UtcDateTime('@' . intdiv($d->ms() + $ms, 1000));
    }

    private static function candidateDates(object $p, ?string $tz): Generator
    {
        $first = self::local($p->starts_at, $tz)->setTime(0, 0);
        $rec = $p->recurrence ?? null;
        if (! $rec || $rec === 'once') {
            yield $first;
            return;
        }
        if ($rec === 'weekly') {
            for ($d = $first; ; $d = $d->modify('+7 day')) yield $d;
        }
        if ($rec === 'biweekly' || $rec === 'every_two_weeks') {
            for ($d = $first; ; $d = $d->modify('+14 day')) yield $d;
        }
        if ($rec === 'twice_monthly' || $rec === 'monthly' || $rec === 'nth_weekday') {
            $configuredWeeks = ! empty($p->ordinal_weeks)
                ? array_filter(array_map('intval', is_array($p->ordinal_weeks) ? $p->ordinal_weeks : explode(',', (string) $p->ordinal_weeks)), fn ($x) => $x >= 1 && $x <= 5)
                : null;
            $configuredWeekdays = ! empty($p->recurring_weekdays)
                ? array_filter(array_map('intval', is_array($p->recurring_weekdays) ? $p->recurring_weekdays : explode(',', (string) $p->recurring_weekdays)), fn ($x) => $x >= 0 && $x <= 6)
                : null;

            $defaultWeekday = (int) $first->format('w');
            $weekdays = ! empty($configuredWeekdays) ? array_values(array_unique($configuredWeekdays)) : [$defaultWeekday];

            $dayNum = (int) $first->format('j');
            $secondDay = $dayNum <= 15 ? min(28, $dayNum + 14) : max(1, $dayNum - 14);
            $days = array_values(array_unique([min($dayNum, $secondDay), max($dayNum, $secondDay)]));
            $nth = (int) ceil($dayNum / 7);
            $defaultNths = $rec === 'twice_monthly' ? (($nth % 2 === 1) ? [1, 3] : [2, 4]) : [$nth];
            $nths = ! empty($configuredWeeks) ? array_values(array_unique($configuredWeeks)) : $defaultNths;

            for ($m = $first->modify('first day of this month'); ; $m = $m->modify('first day of next month')) {
                if (($p->monthly_rule ?? null) === 'nth_weekday' || $rec === 'nth_weekday') {
                    $monthDates = [];
                    foreach ($weekdays as $w) {
                        foreach ($nths as $n) {
                            $d = $m;
                            while ((int) $d->format('w') !== $w) $d = $d->modify('+1 day');
                            $target = $d->modify('+' . (7 * ($n - 1)) . ' day');
                            if ($target->format('m') === $m->format('m')) {
                                $monthDates[] = $target;
                            }
                        }
                    }
                    usort($monthDates, fn ($a, $b) => $a <=> $b);
                    foreach ($monthDates as $t) {
                        yield $t;
                    }
                } else {
                    $dim = (int) $m->format('t');
                    if ($rec === 'twice_monthly') {
                        foreach ($days as $dn) {
                            yield $m->setDate((int) $m->format('Y'), (int) $m->format('m'), min($dn, $dim));
                        }
                    } else {
                        yield $m->setDate((int) $m->format('Y'), (int) $m->format('m'), min($dayNum, $dim));
                    }
                }
            }
        }
        if ($rec === 'ethiopian_days') {
            $days = array_flip(array_filter(array_map('intval', explode(',', (string) ($p->ethiopian_days ?? ''))), fn ($x) => $x >= 1 && $x <= 30));
            if (! $days) {
                yield $first;
                return;
            }
            for ($d = $first; ; $d = $d->modify('+1 day')) {
                $e = Ethiopian::ethiopianOfDate($d->format('Y-m-d'));
                if ($e['month'] !== 13 && isset($days[$e['day']])) yield $d; // ጳጉሜ is not a regular month
            }
        }
    }

    /**
     * Occurrences whose local date lies in [from, to] (inclusive).
     * @return array<array{date:string, starts_at:UtcDateTime, ends_at:UtcDateTime, cancelled?:bool, rescheduled?:bool, reason?:?string}>
     */
    public static function between(object $p, string $from, string $to, ?string $tz = null, bool $includeCancelled = false): array
    {
        $out = [];
        $start = self::local($p->starts_at, $tz);
        $durationMs = max(0, ($p->ends_at ? Dates::ms($p->ends_at) : Dates::ms($p->starts_at)) - Dates::ms($p->starts_at));
        $time = $start->format('H:i:s');
        $first = $start->format('Y-m-d');
        $until = ! empty($p->recurrence_until) ? Dates::toDateOnly($p->recurrence_until) : null;
        $scanned = 0;
        $overrides = $p->_overrides ?? [];
        $seen = [];
        foreach (self::candidateDates($p, $tz) as $d) {
            $date = $d->format('Y-m-d');
            if (isset($seen[$date])) continue;
            $seen[$date] = true;
            if ($date < $first) continue;
            if ($date > $to || ($until && $date > $until) || count($out) >= self::MAX_OCCURRENCES || ++$scanned > self::MAX_OCCURRENCES * 31) break;
            if ($date >= $from) {
                $ov = $overrides[$date] ?? null;
                if ($ov && ($ov->action === 'cancelled' || $ov->action === 'suspended')) {
                    if ($includeCancelled) {
                        $s = self::atLocal($date, $time, $tz);
                        $out[] = [
                            'date' => $date,
                            'starts_at' => $s,
                            'ends_at' => self::plusMs($s, $durationMs),
                            'cancelled' => $ov->action === 'cancelled',
                            'suspended' => $ov->action === 'suspended',
                            'reason' => $ov->reason ?? null,
                        ];
                    }
                    continue;
                }
                if ($ov && $ov->action === 'rescheduled' && $ov->starts_at) {
                    $s = Dates::of($ov->starts_at);
                    $out[] = ['date' => $date, 'starts_at' => $s, 'ends_at' => $ov->ends_at ? Dates::of($ov->ends_at) : self::plusMs($s, $durationMs), 'rescheduled' => true, 'reason' => $ov->reason ?? null];
                    continue;
                }
                $s = self::atLocal($date, $time, $tz);
                $out[] = ['date' => $date, 'starts_at' => $s, 'ends_at' => self::plusMs($s, $durationMs)];
            }
        }
        return $out;
    }

    public static function on(object $p, string $date, ?string $tz = null, bool $includeCancelled = false): ?array
    {
        return self::between($p, $date, $date, $tz, $includeCancelled)[0] ?? null;
    }

    public static function next(object $p, ?\DateTimeInterface $now = null, ?string $tz = null): ?array
    {
        $now ??= Dates::now();
        $today = self::localDate($now, $tz);
        foreach (self::between($p, Dates::addDays($today, -1), Dates::addDays($today, 400), $tz) as $o) {
            if ($o['ends_at'] >= $now) return $o;
        }
        return null;
    }

    public static function upcoming(object $p, int $count, ?\DateTimeInterface $now = null, ?string $tz = null): array
    {
        $now ??= Dates::now();
        $today = self::localDate($now, $tz);
        $out = [];
        foreach (self::between($p, Dates::addDays($today, -1), Dates::addDays($today, 400), $tz) as $o) {
            if ($o['ends_at'] >= $now) {
                $out[] = $o;
                if (count($out) >= $count) break;
            }
        }
        return $out;
    }

    public static function activeOn(object $p, string $date, ?string $tz = null): bool
    {
        if (empty($p->recurrence) || $p->recurrence === 'once') return self::localDate($p->ends_at, $tz) >= $date;
        return empty($p->recurrence_until) || Dates::toDateOnly($p->recurrence_until) >= $date;
    }
}
