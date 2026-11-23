<?php

namespace App\Mz\Support;

use DateTimeImmutable;
use DateTimeInterface;

/**
 * Ethiopian Orthodox Calendar conversion utilities (Amete Mihret).
 * Uses Julian Day Number (JDN) algorithm, mirroring the Flutter app's EthiopianDate.
 */
final class EthiopianCalendar
{
    public const MONTHS_AM = [
        1 => 'መስከረም',
        2 => 'ጥቅምት',
        3 => 'ኅዳር',
        4 => 'ታኅሣሥ',
        5 => 'ጥር',
        6 => 'የካቲት',
        7 => 'መጋቢት',
        8 => 'ሚያዝያ',
        9 => 'ግንቦት',
        10 => 'ሰኔ',
        11 => 'ሐምሌ',
        12 => 'ነሐሴ',
        13 => 'ጳጉሜ',
    ];

    public const MONTHS_EN = [
        1 => 'Meskerem',
        2 => 'Tikimt',
        3 => 'Hidar',
        4 => 'Tahsas',
        5 => 'Tir',
        6 => 'Yekatit',
        7 => 'Megabit',
        8 => 'Miyazya',
        9 => 'Ginbot',
        10 => 'Sene',
        11 => 'Hamle',
        12 => 'Nehase',
        13 => 'Pagume',
    ];

    public const WEEKDAYS_AM = [
        0 => 'እሑድ',
        1 => 'ሰኞ',
        2 => 'ማክሰኞ',
        3 => 'ረቡዕ',
        4 => 'ሐሙስ',
        5 => 'ዓርብ',
        6 => 'ቅዳሜ',
    ];

    public const WEEKDAYS_EN = [
        0 => 'Sunday',
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
    ];

    public const MONTHLY_FEASTS = [
        1 => 'ልደታ ለማርያም፣ ኤልያስ ነቢይ',
        2 => 'ታዴዎስ ሐዋርያ',
        3 => 'በዓለ ዜና ማርቆስ',
        4 => 'ዮሐንስ ወልደ ነጎድጓድ',
        5 => 'አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)',
        6 => 'ደብረ ቁስቋም (ማርያም በስደት)',
        7 => 'በዓለ ሥላሴ (አብ፣ ወልድ፣ መንፈስ ቅዱስ)',
        8 => 'አባ ኪሮስ',
        9 => 'ቶማስ ሐዋርያ',
        10 => 'መስቀለ ክርስቶስ',
        11 => 'ሐና ወኢያቄም',
        12 => 'ቅዱስ ሚካኤል ሊቀ መላእክት',
        13 => 'እግዚአብሔር አብ፣ ሩፋኤል ሊቀ መላእክት',
        14 => 'አቡነ አረጋዊ፣ ገብረ ክርስቶስ',
        15 => 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ',
        16 => 'ኪዳነ ምሕረት',
        17 => 'እስጢፋኖስ ቀዳሜ ሰማዕት',
        18 => 'ኤዎስጣቴዎስ',
        19 => 'ቅዱስ ገብርኤል ሊቀ መላእክት',
        20 => 'ሕንጸተ ቤተ ክርስቲያን (ጽንጸታ ለማርያም)',
        21 => 'እግዝእትነ ማርያም (በዓለ እግዝእትነ)',
        22 => 'ኡራኤል ሊቀ መላእክት፣ ደቅስዮስ',
        23 => 'ቅዱስ ጊዮርጊስ ሰማዕት',
        24 => 'አቡነ ተክለ ሃይማኖት',
        25 => 'መርቆሬዎስ ሰማዕት',
        26 => 'ቶማስ ዘደብረ ማውፃ',
        27 => 'መድኃኔ ዓለም',
        28 => 'አማኑኤል',
        29 => 'በዓለ ወልድ (እግዚእነ ኢየሱስ ክርስቶስ)',
        30 => 'ዮሐንስ መጥምቅ',
    ];

    public static function jdnFromGregorian(int $year, int $month, int $day): int
    {
        $a = intdiv(14 - $month, 12);
        $yy = $year + 4800 - $a;
        $mm = $month + 12 * $a - 3;
        return $day + intdiv(153 * $mm + 2, 5) + 365 * $yy + intdiv($yy, 4) - intdiv($yy, 100) + intdiv($yy, 400) - 32045;
    }

    public static function isLeapYear(int $ethiopianYear): bool
    {
        return $ethiopianYear % 4 === 3;
    }

    public static function daysInMonth(int $ethiopianYear, int $ethiopianMonth): int
    {
        if ($ethiopianMonth < 13) {
            return 30;
        }
        return self::isLeapYear($ethiopianYear) ? 6 : 5;
    }

    /**
     * Convert Gregorian date to Ethiopian date array.
     * @return array{year:int, month:int, day:int, month_am:string, date:string, formatted:string}
     */
    public static function fromGregorian(int $y, int $m, int $d): array
    {
        $jdn = self::jdnFromGregorian($y, $m, $d);
        $epoch = 1723856;
        $r = ($jdn - $epoch) % 1461;
        $n = $r % 365 + 365 * intdiv($r, 1460);
        $year = 4 * intdiv($jdn - $epoch, 1461) + intdiv($r, 365) - intdiv($r, 1460);
        $month = intdiv($n, 30) + 1;
        $day = $n % 30 + 1;

        $dateStr = sprintf('%04d-%02d-%02d', $year, $month, $day);
        $monthAm = self::MONTHS_AM[$month] ?? '';
        $formatted = "{$monthAm} {$day} ቀን {$year} ዓ.ም";

        return [
            'year' => (int) $year,
            'month' => (int) $month,
            'day' => (int) $day,
            'month_am' => $monthAm,
            'date' => $dateStr,
            'formatted' => $formatted,
        ];
    }

    /**
     * Helper to convert Gregorian date string or DateTime to Ethiopian date details.
     * Compatible with gregorianToEthiopianDate() callers across Attendance & Reports.
     */
    public static function gregorianToEthiopianDate(string|\DateTimeInterface|null $date): array
    {
        if (empty($date)) {
            $today = self::todayInAddis();
            return [
                'ethiopian_year' => (int) $today['ethiopian_year'],
                'ethiopian_month' => (int) $today['ethiopian_month'],
                'ethiopian_day' => (int) $today['ethiopian_day'],
                'month_name_am' => (string) ($today['month_name_am'] ?? ''),
                'month_name_en' => (string) ($today['month_name_en'] ?? ''),
                'ethiopian_date' => (string) ($today['ethiopian_date'] ?? ''),
                'formatted' => "{$today['month_name_am']} {$today['ethiopian_day']} ቀን {$today['ethiopian_year']} ዓ.ም",
            ];
        }

        if ($date instanceof \DateTimeInterface) {
            $gy = (int) $date->format('Y');
            $gm = (int) $date->format('n');
            $gd = (int) $date->format('j');
        } else {
            $parts = explode('-', substr((string) $date, 0, 10));
            $gy = (int) ($parts[0] ?? 2026);
            $gm = (int) ($parts[1] ?? 1);
            $gd = (int) ($parts[2] ?? 1);
        }

        $eth = self::fromGregorian($gy, $gm, $gd);
        return [
            'ethiopian_year' => $eth['year'],
            'ethiopian_month' => $eth['month'],
            'ethiopian_day' => $eth['day'],
            'month_name_am' => $eth['month_am'],
            'month_name_en' => self::MONTHS_EN[$eth['month']] ?? '',
            'ethiopian_date' => $eth['date'],
            'formatted' => $eth['formatted'],
        ];
    }

    /**
     * Convert Ethiopian date to Gregorian DateTimeImmutable.
     */
    public static function toGregorian(int $year, int $month, int $day): DateTimeImmutable
    {
        $epoch = 1723856;
        $jdn = $epoch + 1461 * intdiv($year, 4) + 365 * ($year % 4) + 30 * ($month - 1) + $day - 1;

        $l = $jdn + 68569;
        $n = intdiv(4 * $l, 146097);
        $l = $l - intdiv(146097 * $n + 3, 4);
        $i = intdiv(4000 * ($l + 1), 1461001);
        $l = $l - intdiv(1461 * $i, 4) + 31;
        $j = intdiv(80 * $l, 2447);
        $d = $l - intdiv(2447 * $j, 80);
        $l = intdiv($j, 11);
        $m = $j + 2 - 12 * $l;
        $y = 100 * ($n - 49) + $i + $l;

        return new DateTimeImmutable(sprintf('%04d-%02d-%02d', $y, $m, $d));
    }

    /**
     * Resolve date info for a given date in Africa/Addis_Ababa timezone.
     */
    public static function todayInAddis(): array
    {
        $dt = new DateTimeImmutable('now', Dates::tz());
        $y = (int) $dt->format('Y');
        $m = (int) $dt->format('m');
        $d = (int) $dt->format('d');
        $weekdayIdx = (int) $dt->format('w'); // 0 = Sunday

        $eth = self::fromGregorian($y, $m, $d);

        return [
            'gregorian_date' => $dt->format('Y-m-d'),
            'ethiopian_date' => $eth['date'],
            'ethiopian_year' => $eth['year'],
            'ethiopian_month' => $eth['month'],
            'ethiopian_day' => $eth['day'],
            'month_name_am' => $eth['month_am'],
            'weekday_am' => self::WEEKDAYS_AM[$weekdayIdx] ?? '',
            'weekday_en' => self::WEEKDAYS_EN[$weekdayIdx] ?? '',
            'formatted' => "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም · " . (self::WEEKDAYS_AM[$weekdayIdx] ?? ''),
        ];
    }
}
