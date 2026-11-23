<?php

namespace App\Mz\Support;

use App\Mz\Db\UtcDateTime;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;

/** Date helpers (port of utils/dates.js). DATETIMEs are UTC; business dates are in APP_TIMEZONE. */
final class Dates
{
    public static function tz(): DateTimeZone
    {
        return new DateTimeZone((string) config('mz.timezone', 'Africa/Addis_Ababa'));
    }

    public static function utc(): DateTimeZone
    {
        return new DateTimeZone('UTC');
    }

    public static function now(): UtcDateTime
    {
        return new UtcDateTime('now', self::utc());
    }

    /** Anything date-like → UtcDateTime (null stays null). */
    public static function of(mixed $v): ?UtcDateTime
    {
        if ($v === null || $v === '') {
            return null;
        }
        if ($v instanceof UtcDateTime) {
            return $v;
        }
        return ZDate::toDate($v);
    }

    /** Today's date (YYYY-MM-DD) in the application time zone. */
    public static function todayLocal(?DateTimeInterface $now = null): string
    {
        return (DateTimeImmutable::createFromInterface($now ?? self::now()))->setTimezone(self::tz())->format('Y-m-d');
    }

    /** A DATE / DATETIME / string value → "YYYY-MM-DD" (a DATE column keeps its calendar day). */
    public static function toDateOnly(mixed $v): ?string
    {
        if ($v === null || $v === '') {
            return null;
        }
        if (is_string($v)) {
            return substr($v, 0, 10);
        }
        if ($v instanceof DateTimeInterface) {
            return DateTimeImmutable::createFromInterface($v)->setTimezone(self::utc())->format('Y-m-d');
        }
        return substr((string) $v, 0, 10);
    }

    public static function calendarDaysBetween(mixed $from, mixed $to): int
    {
        $a = new DateTimeImmutable(self::toDateOnly($from) . ' 00:00:00', self::utc());
        $b = new DateTimeImmutable(self::toDateOnly($to) . ' 00:00:00', self::utc());
        return (int) round(($b->getTimestamp() - $a->getTimestamp()) / 86400);
    }

    /** UTC datetime → local calendar date. */
    public static function localDateOf(mixed $dt): string
    {
        return self::of($dt)->setTimezone(self::tz())->format('Y-m-d');
    }

    public static function sql(mixed $d): ?string
    {
        $x = self::of($d);
        return $x ? $x->setTimezone(self::utc())->format('Y-m-d H:i:s') : null;
    }

    /** A local wall-clock time "YYYY-MM-DD HH:mm:ss" in APP_TIMEZONE → UTC instant. */
    public static function fromLocal(string $local): UtcDateTime
    {
        $d = new DateTimeImmutable($local, self::tz());
        return new UtcDateTime('@' . $d->getTimestamp());
    }

    /** ISO string as JavaScript's toISOString(). */
    public static function iso(mixed $d): ?string
    {
        $x = self::of($d);
        return $x?->jsonSerialize();
    }

    public static function toIso(mixed $d): ?string
    {
        return self::iso($d);
    }

    public static function addDays(string $date, int $n): string
    {
        return (new DateTimeImmutable($date . ' 00:00:00', self::utc()))->modify(($n >= 0 ? '+' : '') . $n . ' day')->format('Y-m-d');
    }

    /** Milliseconds since epoch (0 if null). */
    public static function ms(mixed $d): int
    {
        return self::of($d)?->ms() ?? 0;
    }

    public static function fromMs(int|float $ms): UtcDateTime
    {
        return ZDate::toDate((int) $ms);
    }
}
