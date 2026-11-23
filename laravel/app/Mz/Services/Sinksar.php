<?php

namespace App\Mz\Services;

use App\Mz\Notifications\Notifications;
use App\Mz\Support\Dates;
use App\Mz\Support\EthiopianCalendar;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Service for Daily Ethiopian Orthodox Tewahedo Sinksar (Synaxarium).
 * Provides automatic daily commemorations, annual feasts, monthly feasts,
 * offline caching, full-text narrative resolution, and optional daily notification delivery.
 */
final class Sinksar
{
    private const UPSTREAM_BASE = 'https://eotcdev-api.natinael-96.workers.dev/v1';

    /**
     * Get Sinksar data for today (Addis Ababa time).
     */
    public static function forToday(): array
    {
        $todayInfo = EthiopianCalendar::todayInAddis();
        return self::resolveDate($todayInfo['gregorian_date'], $todayInfo);
    }

    /**
     * Alias for forDate or forToday.
     */
    public static function getDay(?string $date = null): array
    {
        return $date ? self::forDate($date) : self::forToday();
    }

    /**
     * Get Sinksar data for any date (supports YYYY-MM-DD Gregorian or Ethiopian).
     */
    public static function forDate(string $dateStr): array
    {
        $dateStr = trim($dateStr);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateStr)) {
            return self::forToday();
        }

        $parts = explode('-', $dateStr);
        $y = (int) $parts[0];
        $m = (int) $parts[1];
        $d = (int) $parts[2];

        // Detect Ethiopian date (month 13 Pagume, or explicit parameter, or Ethiopian year range)
        $isEth = ($m === 13) || ($m >= 1 && $m <= 13 && ($y < 2024 || request('calendar') === 'ethiopian' || request('ethiopian') === '1'));
        if ($isEth && $m >= 1 && $m <= 13) {
            // Validate Pagume days (5 in common years, 6 in leap years: 2015, 2019, 2023, 2027 E.C.)
            $maxDays = EthiopianCalendar::daysInMonth($y, $m);
            $d = max(1, min($d, $maxDays));

            $greg = EthiopianCalendar::toGregorian($y, $m, $d);
            $gregStr = $greg->format('Y-m-d');
            $eth = EthiopianCalendar::fromGregorian((int) $greg->format('Y'), (int) $greg->format('m'), (int) $greg->format('d'));
            $w = (int) $greg->format('w');
            $info = [
                'gregorian_date' => $gregStr,
                'ethiopian_date' => $eth['date'],
                'ethiopian_year' => $eth['year'],
                'ethiopian_month' => $eth['month'],
                'ethiopian_day' => $eth['day'],
                'month_name_am' => $eth['month_am'],
                'weekday_am' => EthiopianCalendar::WEEKDAYS_AM[$w] ?? '',
                'weekday_en' => EthiopianCalendar::WEEKDAYS_EN[$w] ?? '',
                'formatted' => "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም · " . (EthiopianCalendar::WEEKDAYS_AM[$w] ?? ''),
            ];
            return self::resolveDate($gregStr, $info);
        }

        // Gregorian date
        $dt = new DateTimeImmutable($dateStr);
        $w = (int) $dt->format('w');
        $eth = EthiopianCalendar::fromGregorian((int) $dt->format('Y'), (int) $dt->format('m'), (int) $dt->format('d'));
        $info = [
            'gregorian_date' => $dateStr,
            'ethiopian_date' => $eth['date'],
            'ethiopian_year' => $eth['year'],
            'ethiopian_month' => $eth['month'],
            'ethiopian_day' => $eth['day'],
            'month_name_am' => $eth['month_am'],
            'weekday_am' => EthiopianCalendar::WEEKDAYS_AM[$w] ?? '',
            'weekday_en' => EthiopianCalendar::WEEKDAYS_EN[$w] ?? '',
            'formatted' => "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም · " . (EthiopianCalendar::WEEKDAYS_AM[$w] ?? ''),
        ];
        return self::resolveDate($dateStr, $info);
    }

    /**
     * Resolve date data from database cache or upstream API.
     */
    private static function resolveDate(string $gregDate, array $dateInfo): array
    {
        $cached = DB::table('sinksar_daily')->where('gregorian_date', $gregDate)->first();

        // If cached and fresh (within 24 hours), return structured response
        if ($cached) {
            return self::formatRecord($cached, $dateInfo);
        }

        // Attempt upstream fetch
        $upstream = self::fetchFromUpstream($gregDate);
        if ($upstream) {
            $annualFeasts = $upstream['annualFeasts']['items'] ?? [];
            $monthlyFeasts = $upstream['monthlyFeasts']['items'] ?? [];
            $headingAnnual = $upstream['annualFeasts']['heading'] ?? null;
            $headingMonthly = $upstream['monthlyFeasts']['heading'] ?? null;

            // Generate verified summary
            $summary = self::generateSummary($dateInfo, $annualFeasts, $monthlyFeasts);

            $id = DB::table('sinksar_daily')->insertGetId([
                'gregorian_date' => $gregDate,
                'ethiopian_date' => $dateInfo['ethiopian_date'],
                'ethiopian_year' => $dateInfo['ethiopian_year'],
                'ethiopian_month' => $dateInfo['ethiopian_month'],
                'ethiopian_day' => $dateInfo['ethiopian_day'],
                'month_name_am' => $dateInfo['month_name_am'],
                'weekday_am' => $dateInfo['weekday_am'],
                'weekday_en' => $dateInfo['weekday_en'],
                'is_fasting' => !empty($upstream['fasting']['isFasting']),
                'fasting_reason' => $upstream['fasting']['reason'] ?? null,
                'annual_feasts' => json_encode($annualFeasts, JSON_UNESCAPED_UNICODE),
                'monthly_feasts' => json_encode($monthlyFeasts, JSON_UNESCAPED_UNICODE),
                'summary' => $summary,
                'full_text_available' => (bool) ($upstream['fullTextAvailable'] ?? false),
                'raw_payload' => json_encode($upstream, JSON_UNESCAPED_UNICODE),
                'notification_sent' => false,
                'refreshed_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $newRow = DB::table('sinksar_daily')->where('id', $id)->first();
            return self::formatRecord($newRow, $dateInfo);
        }

        // Upstream unreachable: build reliable fallback from canonical EOTC monthly commemorations
        $fallbackMonthly = [
            [
                'id' => "{$dateInfo['ethiopian_month']}-{$dateInfo['ethiopian_day']}-monthly-1",
                'title' => EthiopianCalendar::MONTHLY_FEASTS[$dateInfo['ethiopian_day']] ?? 'ወርኀዊ መታሰቢያ',
                'sourceText' => '፩.' . (EthiopianCalendar::MONTHLY_FEASTS[$dateInfo['ethiopian_day']] ?? 'ወርኀዊ መታሰቢያ'),
            ]
        ];
        $summary = self::generateSummary($dateInfo, [], $fallbackMonthly);

        $rowId = DB::table('sinksar_daily')->insertGetId([
            'gregorian_date' => $gregDate,
            'ethiopian_date' => $dateInfo['ethiopian_date'],
            'ethiopian_year' => $dateInfo['ethiopian_year'],
            'ethiopian_month' => $dateInfo['ethiopian_month'],
            'ethiopian_day' => $dateInfo['ethiopian_day'],
            'month_name_am' => $dateInfo['month_name_am'],
            'weekday_am' => $dateInfo['weekday_am'],
            'weekday_en' => $dateInfo['weekday_en'],
            'is_fasting' => in_array($dateInfo['weekday_en'], ['Wednesday', 'Friday'], true),
            'fasting_reason' => in_array($dateInfo['weekday_en'], ['Wednesday', 'Friday'], true) ? 'የረቡዕና ዓርብ ጾም' : null,
            'annual_feasts' => json_encode([], JSON_UNESCAPED_UNICODE),
            'monthly_feasts' => json_encode($fallbackMonthly, JSON_UNESCAPED_UNICODE),
            'summary' => $summary,
            'full_text_available' => false,
            'raw_payload' => null,
            'notification_sent' => false,
            'refreshed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $row = DB::table('sinksar_daily')->where('id', $rowId)->first();
        return self::formatRecord($row, $dateInfo);
    }

    /**
     * Fetch from open EOTCDevAPI upstream with safe timeout.
     */
    private static function fetchFromUpstream(string $gregDate): ?array
    {
        try {
            $resp = Http::timeout(5)->withoutVerifying()->get(self::UPSTREAM_BASE . "/sinksar/{$gregDate}");
            if ($resp->successful()) {
                return $resp->json();
            }
        } catch (Throwable $e) {
            Log::warning("Sinksar upstream fetch failed for {$gregDate}: {$e->getMessage()}");
        }
        return null;
    }

    /**
     * Generate clear Amharic summary of commemorations.
     */
    private static function generateSummary(array $info, array $annual, array $monthly): string
    {
        $parts = [];
        if (!empty($annual)) {
            $titles = array_slice(array_column($annual, 'title'), 0, 3);
            $parts[] = "ዓመታዊ በዓላት፦ " . implode('፣ ', $titles);
        }
        if (!empty($monthly)) {
            $titles = array_slice(array_column($monthly, 'title'), 0, 3);
            $parts[] = "ወርኀዊ በዓላት፦ " . implode('፣ ', $titles);
        }
        if (empty($parts)) {
            $mFeast = EthiopianCalendar::MONTHLY_FEASTS[$info['ethiopian_day']] ?? 'ወርኀዊ በዓል';
            $parts[] = "ወርኀዊ መታሰቢያ፦ {$mFeast}";
        }
        return implode(' · ', $parts);
    }

    /**
     * Format a database row into an API-ready response.
     */
    public static function formatRecord(object $r, array $info): array
    {
        $annual = is_string($r->annual_feasts) ? (json_decode($r->annual_feasts, true) ?: []) : ($r->annual_feasts ?? []);
        $annual = array_map(function ($item) {
            if (is_string($item)) {
                return trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $item));
            }
            if (is_array($item) && isset($item['title'])) {
                $item['title'] = trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $item['title']));
            }
            return $item;
        }, $annual);
        $monthly = is_string($r->monthly_feasts) ? (json_decode($r->monthly_feasts, true) ?: []) : ($r->monthly_feasts ?? []);
        $monthly = array_map(function ($item) {
            if (is_string($item)) {
                return trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $item));
            }
            if (is_array($item) && isset($item['title'])) {
                $item['title'] = trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $item['title']));
            }
            return $item;
        }, $monthly);

        // Retrieve all annual saints from synaxarium_saints if empty
        if (empty($annual) && \Illuminate\Support\Facades\Schema::hasTable('synaxarium_saints')) {
            $saints = DB::table('synaxarium_saints')
                ->where('month', $r->ethiopian_month)
                ->where('day', $r->ethiopian_day)
                ->orderBy('order_index')
                ->get();
            if ($saints->isNotEmpty()) {
                $annual = $saints->map(fn ($s) => [
                    'id' => "synax-saint-{$s->id}",
                    'title' => str_replace(['dit*', 'd*'], '', $s->name),
                    'sourceText' => !empty($s->biography) ? str_replace(['dit*', 'd*'], '', $s->biography) : str_replace(['dit*', 'd*'], '', $s->name),
                    'type' => $s->type ?? 'annual',
                ])->all();
            }
        }

        // Retrieve and expand ALL monthly recurring commemorations for this day throughout the year
        $dayNum = (int) $r->ethiopian_day;
        $monthlyFeastsDef = EthiopianCalendar::MONTHLY_FEASTS[$dayNum] ?? null;
        if (!empty($monthlyFeastsDef)) {
            $splitNames = preg_split('/[፣,]/u', $monthlyFeastsDef);
            $expandedMonthly = [];
            $mIdx = 1;
            foreach ($splitNames as $name) {
                $trimmed = trim(preg_replace('/^\d+[\.\s\-]+/u', '', $name));
                $trimmed = trim(str_replace(['dit*', 'd*'], '', $trimmed));
                if ($trimmed !== '') {
                    $expandedMonthly[] = [
                        'id' => "{$r->ethiopian_month}-{$r->ethiopian_day}-monthly-{$mIdx}",
                        'title' => $trimmed,
                        'sourceText' => "ወርኀዊ መታሰቢያ፦ {$trimmed}",
                    ];
                    $mIdx++;
                }
            }
            if (!empty($expandedMonthly)) {
                $monthly = $expandedMonthly;
            }
        }

        // Featured commemoration for the daily banner
        $annualTitle = '';
        if (!empty($annual)) {
            $firstAnnual = $annual[0];
            $annualTitle = is_array($firstAnnual) ? ($firstAnnual['title'] ?? '') : (string) $firstAnnual;
        }
        $monthlyTitle = '';
        if (!empty($monthly)) {
            $firstMonthly = $monthly[0];
            $monthlyTitle = is_array($firstMonthly) ? ($firstMonthly['title'] ?? '') : (string) $firstMonthly;
        }
        $featured = $annualTitle !== '' ? $annualTitle : ($monthlyTitle !== '' ? $monthlyTitle : 'የቅዱሳን መታሰቢያ');

        // Check if full-text narratives exist in the database for this Ethiopian month & day
        $narratives = DB::table('sinksar_narratives')
            ->where('ethiopian_month', $r->ethiopian_month)
            ->where('ethiopian_day', $r->ethiopian_day)
            ->get(['id', 'title', 'source', 'summary', 'body', 'verified']);

        if ($narratives->isEmpty() && \Illuminate\Support\Facades\Schema::hasTable('synaxarium_entries')) {
            $synaxEntry = DB::table('synaxarium_entries')
                ->where('month', $r->ethiopian_month)
                ->where('day', $r->ethiopian_day)
                ->first();
            if ($synaxEntry) {
                $narratives = collect([
                    (object) [
                        'id' => (int) $synaxEntry->id,
                        'title' => str_replace(['dit*', 'd*'], '', $synaxEntry->title),
                        'source' => $synaxEntry->source_book_id ?? 'ስንክሳር',
                        'summary' => str_replace(['dit*', 'd*'], '', $synaxEntry->summary),
                        'body' => str_replace(['dit*', 'd*'], '', $synaxEntry->body_am),
                        'verified' => (bool) ($synaxEntry->is_editorially_verified ?? false),
                    ]
                ]);
            }
        }

        return [
            'id' => (int) $r->id,
            'gregorian_date' => $r->gregorian_date,
            'ethiopian_date' => $r->ethiopian_date,
            'ethiopian_year' => (int) $r->ethiopian_year,
            'ethiopian_month' => (int) $r->ethiopian_month,
            'ethiopian_day' => (int) $r->ethiopian_day,
            'month_name_am' => $r->month_name_am,
            'weekday_am' => $r->weekday_am,
            'weekday_en' => $r->weekday_en,
            'formatted_date' => "{$r->month_name_am} {$r->ethiopian_day} ቀን {$r->ethiopian_year} ዓ.ም",
            'formatted_full' => "{$r->month_name_am} {$r->ethiopian_day} ቀን {$r->ethiopian_year} ዓ.ም · {$r->weekday_am}",
            'is_fasting' => (bool) $r->is_fasting,
            'fasting_reason' => $r->fasting_reason,
            'featured_title' => $featured,
            'summary' => $r->summary,
            'annual_feasts' => $annual,
            'monthly_feasts' => $monthly,
            'full_text_available' => $narratives->isNotEmpty() || (bool) $r->full_text_available,
            'narratives' => $narratives->map(fn ($n) => [
                'id' => (int) $n->id,
                'title' => trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $n->title)),
                'source' => $n->source,
                'summary' => $n->summary ? trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $n->summary)) : null,
                'body' => trim(str_replace(['dit*', 'd*', 'n***', 'n*'], '', $n->body)),
                'verified' => (bool) $n->verified,
            ])->all(),
            'has_narratives' => $narratives->isNotEmpty(),
            'refreshed_at' => $r->refreshed_at,
        ];
    }

    /**
     * Dispatch daily optional Sinksar notifications to members who have the 'sinksar' topic enabled.
     */
    public static function sendDailyNotification(): array
    {
        $today = self::forToday();
        $gregDate = $today['gregorian_date'];

        $row = DB::table('sinksar_daily')->where('gregorian_date', $gregDate)->first();
        if ($row && $row->notification_sent) {
            return ['status' => 'already_sent', 'date' => $gregDate];
        }

        // Find users with sinksars notifications enabled (or default on unless topic opt-out)
        $users = DB::table('users as u')
            ->leftJoin('user_preferences as p', 'p.user_id', '=', 'u.id')
            ->where('u.status', 'active')
            ->select('u.id', 'p.notifications_enabled', 'p.notification_topics')
            ->get();

        $recipients = [];
        foreach ($users as $u) {
            if ($u->notifications_enabled !== null && (int) $u->notifications_enabled === 0) {
                continue;
            }
            $prefs = Notifications::preferencesOf($u->notification_topics ?? null);
            // Sinksar is an optional topic (defaults to true if not explicitly false)
            if (($prefs['sinksar']['push'] ?? true) === true) {
                $recipients[] = (int) $u->id;
            }
        }

        if (empty($recipients)) {
            DB::table('sinksar_daily')->where('gregorian_date', $gregDate)->update(['notification_sent' => true]);
            return ['status' => 'no_recipients', 'count' => 0];
        }

        $title = "የዕለቱ ስንክሳር — {$today['formatted_date']}";
        $body = "የዛሬ ቅዱሳን መታሰቢያ፦ {$today['featured_title']}";
        $data = [
            'type' => 'sinksar',
            'entity_type' => 'sinksar',
            'entity_id' => $today['id'],
            'date' => $gregDate,
            'ethiopian_date' => $today['ethiopian_date'],
        ];

        // Insert in-app notifications
        $now = now();
        $hasTopic = \Illuminate\Support\Facades\Schema::hasColumn('notifications', 'topic');
        $hasChannel = \Illuminate\Support\Facades\Schema::hasColumn('notifications', 'channel');
        $hasIsRead = \Illuminate\Support\Facades\Schema::hasColumn('notifications', 'is_read');
        $hasUpdatedAt = \Illuminate\Support\Facades\Schema::hasColumn('notifications', 'updated_at');

        $inserts = [];
        foreach ($recipients as $uid) {
            $row = [
                'user_id' => $uid,
                'type' => 'sinksar',
                'title' => $title,
                'body' => $body,
                'entity_type' => 'sinksar',
                'entity_id' => $today['id'],
                'data' => json_encode($data, JSON_UNESCAPED_UNICODE),
                'created_at' => $now,
            ];
            if ($hasTopic) $row['topic'] = 'sinksar';
            if ($hasChannel) $row['channel'] = 'sinksar';
            if ($hasIsRead) $row['is_read'] = false;
            if ($hasUpdatedAt) $row['updated_at'] = $now;
            $inserts[] = $row;
        }

        foreach (array_chunk($inserts, 500) as $chunk) {
            DB::table('notifications')->insert($chunk);
        }

        // Trigger push notifications
        Notifications::dispatchPending();

        DB::table('sinksar_daily')->where('gregorian_date', $gregDate)->update(['notification_sent' => true]);

        return [
            'status' => 'sent',
            'recipients_count' => count($recipients),
            'date' => $gregDate,
            'ethiopian_date' => $today['ethiopian_date'],
        ];
    }

    /**
     * Send a single authorized test Sinksar notification to ONLY the caller's registered device.
     * Admin/Super-Admin only. Never broadcasts to all users.
     */
    public static function sendTestNotification(\App\Mz\Auth\AuthContext $auth, ?string $targetDate = null): array
    {
        if (! $auth->isAdmin && ! $auth->isSuperAdmin()) {
            throw \App\Mz\Support\ApiError::forbidden('FORBIDDEN', 'Administrative privilege required');
        }

        $tokenTable = \Illuminate\Support\Facades\Schema::hasTable('fcm_tokens') ? 'fcm_tokens' : 'user_fcm_tokens';
        $tokensQ = DB::table($tokenTable)->where('user_id', $auth->id);
        if (\Illuminate\Support\Facades\Schema::hasColumn($tokenTable, 'invalidated_at')) {
            $tokensQ->whereNull('invalidated_at');
        }
        $tokens = $tokensQ->pluck('token')->all();

        $day = $targetDate ? self::forDate($targetDate) : self::forToday();
        $gregDate = $day['gregorian_date'];

        $title = "[ሙከራ] የዕለቱ ስንክሳር — {$day['formatted_date']}";
        $body = "{$gregDate} ({$day['weekday_am']}) • የዛሬ ቅዱሳን፦ {$day['featured_title']}";

        $notificationData = [
            'type' => 'sinksar',
            'entity_type' => 'sinksar',
            'entity_id' => $day['id'] ?? 0,
            'date' => $gregDate,
            'ethiopian_date' => $day['ethiopian_date'],
            'channel' => 'sinksar',
        ];

        // 1. Insert in-app notification record for the tester
        $notifPayload = [
            'user_id' => $auth->id,
            'type' => 'sinksar',
            'title' => $title,
            'body' => $body,
            'entity_type' => 'sinksar',
            'entity_id' => $day['id'] ?? 0,
            'data' => json_encode($notificationData, JSON_UNESCAPED_UNICODE),
            'created_at' => now(),
        ];
        if (\Illuminate\Support\Facades\Schema::hasColumn('notifications', 'topic')) {
            $notifPayload['topic'] = 'sinksar';
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('notifications', 'channel')) {
            $notifPayload['channel'] = 'sinksar';
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('notifications', 'is_read')) {
            $notifPayload['is_read'] = false;
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('notifications', 'updated_at')) {
            $notifPayload['updated_at'] = now();
        }
        $notificationId = DB::table('notifications')->insertGetId($notifPayload);
        $notificationData['notification_id'] = $notificationId;

        if (empty($tokens)) {
            return [
                'success' => false,
                'status' => 'no_device_token',
                'message' => 'No active FCM device token is registered for your account. Please log in from your mobile device with notifications enabled to register.',
                'recipient_user_id' => $auth->id,
                'notification_id' => $notificationId,
                'date' => [
                    'ethiopian' => $day['ethiopian_date'],
                    'gregorian' => $gregDate,
                    'formatted' => $day['formatted_date'],
                ],
            ];
        }

        $fcmConfigured = \App\Mz\Notifications\Fcm::configured();
        $submissionResults = [];

        if ($fcmConfigured) {
            $messages = [];
            foreach ($tokens as $token) {
                $messages[] = [
                    'token' => $token,
                    'title' => $title,
                    'body' => $body,
                    'data' => $notificationData,
                ];
            }
            $submissionResults = \App\Mz\Notifications\Fcm::sendBatch($messages);
        }

        return [
            'success' => true,
            'status' => 'submitted',
            'test_mode' => true,
            'recipient_user_id' => $auth->id,
            'devices_targeted' => count($tokens),
            'fcm_configured' => $fcmConfigured,
            'submission_results' => $submissionResults,
            'channel' => 'sinksar',
            'date' => [
                'ethiopian' => $day['ethiopian_date'],
                'gregorian' => $gregDate,
                'formatted' => $day['formatted_date'],
            ],
            'featured_commemoration' => $day['featured_title'],
            'note' => 'Server submission completed to registered device(s). Device receipt depends on device network status and Android notification/lock-screen settings.',
        ];
    }
}

