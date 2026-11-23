<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;

/**
 * Service for the Amharic Ethiopian Orthodox Tewahedo Synaxarium (ስንክሳር).
 * Provides access to the 13 monthly books, 366 daily readings, authoritative daily saints,
 * search across texts, and import management from senkisar source files.
 */
final class Synaxarium
{
    /**
     * List all 13 Ethiopian months.
     */
    public static function listMonths(): array
    {
        $months = DB::table('synaxarium_months')
            ->orderBy('order_index')
            ->get();

        if ($months->isEmpty()) {
            return self::defaultMonthsData();
        }

        return $months->map(fn ($m) => [
            'month_number' => (int) $m->month_number,
            'name_am' => $m->name_am,
            'name_en' => $m->name_en,
            'name_geez' => $m->name_geez,
            'days_count' => (int) $m->days_count,
            'season_am' => $m->season_am ?? null,
        ])->all();
    }

    /**
     * Get Synaxarium reading for today (Addis Ababa timezone).
     */
    public static function getToday(): array
    {
        $todayEth = EthiopianCalendar::todayInAddis();
        $m = (int) $todayEth['ethiopian_month'];
        $d = (int) $todayEth['ethiopian_day'];
        $y = (int) $todayEth['ethiopian_year'];

        $entry = self::getEntry($m, $d, $y);
        $entry['today_meta'] = [
            'gregorian_date' => $todayEth['gregorian_date'],
            'ethiopian_date' => $todayEth['ethiopian_date'],
            'ethiopian_year' => $y,
            'weekday_am' => $todayEth['weekday_am'] ?? '',
            'formatted' => $todayEth['formatted'] ?? '',
        ];

        return $entry;
    }

    /**
     * Get Synaxarium reading for a specific month (1..13) and day (1..30, or 1..6 for Pagumen).
     */
    public static function getEntry(int $month, int $day, ?int $year = null): array
    {
        self::validateMonthDay($month, $day);

        // Leap year validation for Pagumen 6
        $isLeapYearDay = ($month === 13 && $day === 6);
        $isValidForYear = true;
        $leapYearNote = null;

        if ($isLeapYearDay) {
            $checkYear = $year ?? (int) EthiopianCalendar::todayInAddis()['ethiopian_year'];
            $isLeap = EthiopianCalendar::isLeapYear($checkYear);
            $isValidForYear = $isLeap;
            $leapYearNote = $isLeap 
                ? "ጳጉሜ ፮ በዘመነ ዮሐንስ ({$checkYear} ዓ.ም) የሚነበብ ነው።"
                : "ጳጉሜ ፮ የሚነበበው በዘመነ ዮሐንስ (በዘመነ ሉቃስ ማብቂያ) ብቻ ሲሆን፣ በ{$checkYear} ዓ.ም የጳጉሜ ወር ፭ ቀናት ብቻ አሉት።";
        }

        $entry = DB::table('synaxarium_entries')
            ->where('month', $month)
            ->where('day', $day)
            ->first();

        if (!$entry) {
            throw ApiError::notFound('ENTRY_NOT_FOUND', "Synaxarium entry for Month {$month}, Day {$day} not found.");
        }

        // Authoritative daily saints section from B028 - B040
        $dailySaint = DB::table('synaxarium_daily_saints')
            ->where('month', $month)
            ->where('day', $day)
            ->first();

        // Extracted commemoration accounts
        $saints = DB::table('synaxarium_saints')
            ->where('month', $month)
            ->where('day', $day)
            ->orderBy('order_index')
            ->get();

        $monthNameAm = EthiopianCalendar::MONTHS_AM[$month] ?? "ወር {$month}";

        return [
            'id' => (int) $entry->id,
            'month' => (int) $entry->month,
            'day' => (int) $entry->day,
            'month_name_am' => $monthNameAm,
            'unique_code' => $entry->unique_code,
            'title' => $entry->title,
            'date_heading' => $entry->date_heading,
            'summary' => $entry->summary,
            'body_am' => $entry->body_am,
            'annual_feasts' => $entry->annual_feasts ? json_decode($entry->annual_feasts, true) : [],
            'monthly_feasts' => $entry->monthly_feasts ? json_decode($entry->monthly_feasts, true) : [],
            'verses' => $entry->verses,
            'source_book_id' => $entry->source_book_id,
            'char_count' => (int) ($entry->char_count ?? 0),
            'word_count' => (int) ($entry->word_count ?? 0),
            'editorial_status' => $entry->editorial_status ?? 'imported',
            'is_editorially_verified' => (bool) ($entry->is_editorially_verified ?? false),
            'leap_year_info' => $isLeapYearDay ? [
                'is_leap_year_day' => true,
                'is_valid_for_year' => $isValidForYear,
                'note' => $leapYearNote,
            ] : null,
            'daily_saints' => $dailySaint ? [
                'id' => (int) $dailySaint->id,
                'title' => $dailySaint->title,
                'section_text_clean' => $dailySaint->section_text_clean,
                'commemoration_lines_count' => (int) $dailySaint->commemoration_lines_count,
                'is_editorially_verified' => (bool) $dailySaint->is_editorially_verified,
            ] : null,
            'saints' => $saints->map(fn ($s) => [
                'id' => (int) $s->id,
                'name' => $s->name,
                'type' => $s->type,
                'feast_type' => $s->feast_type,
                'biography' => $s->biography,
                'source_reference' => $s->source_reference,
                'is_editorially_verified' => (bool) ($s->is_editorially_verified ?? false),
            ])->all(),
        ];
    }

    /**
     * Get all entries for a given month (overview list without full heavy bodies).
     */
    public static function getMonthEntries(int $month): array
    {
        if ($month < 1 || $month > 13) {
            throw ApiError::badRequest('INVALID_MONTH', 'Month must be between 1 and 13.');
        }

        $entries = DB::table('synaxarium_entries')
            ->where('month', $month)
            ->orderBy('day')
            ->get(['id', 'month', 'day', 'unique_code', 'title', 'date_heading', 'summary', 'annual_feasts', 'monthly_feasts', 'source_book_id', 'is_editorially_verified']);

        $monthNameAm = EthiopianCalendar::MONTHS_AM[$month] ?? "ወር {$month}";

        return [
            'month' => $month,
            'month_name_am' => $monthNameAm,
            'total_entries' => $entries->count(),
            'entries' => $entries->map(fn ($e) => [
                'id' => (int) $e->id,
                'month' => (int) $e->month,
                'day' => (int) $e->day,
                'unique_code' => $e->unique_code,
                'title' => $e->title,
                'date_heading' => $e->date_heading,
                'summary' => $e->summary,
                'annual_feasts' => $e->annual_feasts ? json_decode($e->annual_feasts, true) : [],
                'monthly_feasts' => $e->monthly_feasts ? json_decode($e->monthly_feasts, true) : [],
                'source_book_id' => $e->source_book_id,
                'is_editorially_verified' => (bool) ($e->is_editorially_verified ?? false),
            ])->all(),
        ];
    }

    /**
     * Get commemorated saints for a specific day.
     */
    public static function getSaints(int $month, int $day): array
    {
        self::validateMonthDay($month, $day);

        $dailySaint = DB::table('synaxarium_daily_saints')
            ->where('month', $month)
            ->where('day', $day)
            ->first();

        $saints = DB::table('synaxarium_saints')
            ->where('month', $month)
            ->where('day', $day)
            ->orderBy('order_index')
            ->get();

        $monthNameAm = EthiopianCalendar::MONTHS_AM[$month] ?? "ወር {$month}";

        return [
            'month' => $month,
            'day' => $day,
            'month_name_am' => $monthNameAm,
            'daily_saints_text' => $dailySaint?->section_text_clean,
            'commemoration_lines_count' => (int) ($dailySaint?->commemoration_lines_count ?? 0),
            'total_saints' => $saints->count(),
            'saints' => $saints->map(fn ($s) => [
                'id' => (int) $s->id,
                'name' => $s->name,
                'type' => $s->type,
                'feast_type' => $s->feast_type,
                'biography' => $s->biography,
                'source_reference' => $s->source_reference,
                'is_editorially_verified' => (bool) ($s->is_editorially_verified ?? false),
            ])->all(),
        ];
    }

    /**
     * Search Synaxarium entries and saints biographies for an Amharic query string.
     */
    public static function search(string $query, int $limit = 25): array
    {
        $q = trim($query);
        if (mb_strlen($q) < 2) {
            throw ApiError::badRequest('QUERY_TOO_SHORT', 'Search query must be at least 2 characters long.');
        }

        $limit = max(1, min($limit, 100));

        // 1. Search entries (title, summary, body_am)
        $entries = DB::table('synaxarium_entries')
            ->where(function ($qb) use ($q) {
                $qb->where('title', 'LIKE', "%{$q}%")
                   ->orWhere('summary', 'LIKE', "%{$q}%")
                   ->orWhere('body_am', 'LIKE', "%{$q}%");
            })
            ->orderBy('month')
            ->orderBy('day')
            ->limit($limit)
            ->get(['id', 'month', 'day', 'unique_code', 'title', 'date_heading', 'summary', 'source_book_id', 'is_editorially_verified']);

        // 2. Search saints (name, biography)
        $saints = DB::table('synaxarium_saints')
            ->where(function ($qb) use ($q) {
                $qb->where('name', 'LIKE', "%{$q}%")
                   ->orWhere('biography', 'LIKE', "%{$q}%");
            })
            ->orderBy('month')
            ->orderBy('day')
            ->limit($limit)
            ->get(['id', 'month', 'day', 'name', 'type', 'feast_type', 'source_reference', 'is_editorially_verified']);

        return [
            'query' => $q,
            'entries_count' => $entries->count(),
            'saints_count' => $saints->count(),
            'entries' => $entries->map(fn ($e) => [
                'id' => (int) $e->id,
                'month' => (int) $e->month,
                'day' => (int) $e->day,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$e->month] ?? '',
                'unique_code' => $e->unique_code,
                'title' => $e->title,
                'date_heading' => $e->date_heading,
                'summary' => $e->summary,
                'is_editorially_verified' => (bool) ($e->is_editorially_verified ?? false),
            ])->all(),
            'saints' => $saints->map(fn ($s) => [
                'id' => (int) $s->id,
                'month' => (int) $s->month,
                'day' => (int) $s->day,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$s->month] ?? '',
                'name' => $s->name,
                'type' => $s->type,
                'feast_type' => $s->feast_type,
                'is_editorially_verified' => (bool) ($s->is_editorially_verified ?? false),
            ])->all(),
        ];
    }

    /**
     * Validate month and day bounds.
     */
    private static function validateMonthDay(int $month, int $day): void
    {
        if ($month < 1 || $month > 13) {
            throw ApiError::badRequest('INVALID_MONTH', 'Month must be between 1 and 13.');
        }

        $maxDays = ($month === 13) ? 6 : 30;
        if ($day < 1 || $day > $maxDays) {
            throw ApiError::badRequest('INVALID_DAY', "Day must be between 1 and {$maxDays} for month {$month}.");
        }
    }

    /**
     * Default month metadata fallback.
     */
    public static function defaultMonthsData(): array
    {
        return [
            ['month_number' => 1, 'name_am' => 'መስከረም', 'name_en' => 'Meskerem', 'name_geez' => 'መስከረም', 'days_count' => 30, 'order_index' => 1, 'season_am' => 'መጸው'],
            ['month_number' => 2, 'name_am' => 'ጥቅምት', 'name_en' => 'Tikimt', 'name_geez' => 'ጥቅምት', 'days_count' => 30, 'order_index' => 2, 'season_am' => 'መጸው'],
            ['month_number' => 3, 'name_am' => 'ኅዳር', 'name_en' => 'Hidar', 'name_geez' => 'ኅዳር', 'days_count' => 30, 'order_index' => 3, 'season_am' => 'መጸው'],
            ['month_number' => 4, 'name_am' => 'ታኅሣሥ', 'name_en' => 'Tahsas', 'name_geez' => 'ታኅሣሥ', 'days_count' => 30, 'order_index' => 4, 'season_am' => 'በጋ'],
            ['month_number' => 5, 'name_am' => 'ጥር', 'name_en' => 'Tir', 'name_geez' => 'ጥር', 'days_count' => 30, 'order_index' => 5, 'season_am' => 'በጋ'],
            ['month_number' => 6, 'name_am' => 'የካቲት', 'name_en' => 'Yekatit', 'name_geez' => 'የካቲት', 'days_count' => 30, 'order_index' => 6, 'season_am' => 'በጋ'],
            ['month_number' => 7, 'name_am' => 'መጋቢት', 'name_en' => 'Megabit', 'name_geez' => 'መጋቢት', 'days_count' => 30, 'order_index' => 7, 'season_am' => 'ጸደይ (በልግ)'],
            ['month_number' => 8, 'name_am' => 'ሚያዝያ', 'name_en' => 'Miyazya', 'name_geez' => 'ሚያዝያ', 'days_count' => 30, 'order_index' => 8, 'season_am' => 'ጸደይ (በልግ)'],
            ['month_number' => 9, 'name_am' => 'ግንቦት', 'name_en' => 'Ginbot', 'name_geez' => 'ግንቦት', 'days_count' => 30, 'order_index' => 9, 'season_am' => 'ጸደይ (በልግ)'],
            ['month_number' => 10, 'name_am' => 'ሰኔ', 'name_en' => 'Sene', 'name_geez' => 'ሰኔ', 'days_count' => 30, 'order_index' => 10, 'season_am' => 'ክረምት'],
            ['month_number' => 11, 'name_am' => 'ሐምሌ', 'name_en' => 'Hamle', 'name_geez' => 'ሐምሌ', 'days_count' => 30, 'order_index' => 11, 'season_am' => 'ክረምት'],
            ['month_number' => 12, 'name_am' => 'ነሐሴ', 'name_en' => 'Nehase', 'name_geez' => 'ነሐሴ', 'days_count' => 30, 'order_index' => 12, 'season_am' => 'ክረምት'],
            ['month_number' => 13, 'name_am' => 'ጳጉሜ', 'name_en' => 'Pagumen', 'name_geez' => 'ጳጉሜን', 'days_count' => 6, 'order_index' => 13, 'season_am' => 'ክረምት'],
        ];
    }
}
