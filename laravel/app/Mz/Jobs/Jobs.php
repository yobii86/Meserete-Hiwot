<?php

namespace App\Mz\Jobs;

use App\Mz\Db\Locks;
use App\Mz\Notifications\Notifications;
use App\Mz\Notifications\Telegram;
use App\Mz\Services\AttendanceSessions;
use App\Mz\Services\Borrowings;
use App\Mz\Services\Choir;
use App\Mz\Services\Settings;
use App\Mz\Support\Dates;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Background work WITHOUT cron. Instead of a crontab (node-cron in the Node backend), due jobs run
 * after an HTTP response has been sent (Laravel "terminating" — PHP-FPM / LiteSpeed flush the
 * response first, so the client never waits). A tick is cheap: one cached timestamp read most of
 * the time; at most once per TICK_SECONDS one request takes a MySQL named lock and runs whatever
 * is due. There is exactly one worker at a time (the named lock), never a process per reminder.
 *
 * Each job remembers its last run in the `job_runs` TABLE (not the cache: a cache store that is
 * missing or cleared must never stop reminders). Reminders are idempotent (unique dedupe keys), so
 * a late or repeated run is harmless. `php artisan mz:jobs` runs them by hand.
 */
final class Jobs
{
    private const TICK_SECONDS = 60;

    /** name => [interval seconds | daily local "HH:MM", runner] */
    public static function all(): array
    {
        return [
            'attendance:auto-close' => [60, fn () => ['closed_sessions' => AttendanceSessions::closeExpiredSessions()]],
            'notifications:dispatch' => [60, fn () => Notifications::dispatchPending()],
            // Time-based notifications stored in advance (task deadlines…): one central dispatcher.
            'scheduled:dispatch' => [60, function () {
                $out = ScheduledNotifications::releaseDue();
                if ($out['released'] ?? 0) Notifications::dispatchPending();
                return $out;
            }],
            'programs:reminders' => [300, function () {
                $out = ReminderJobs::programReminders();
                Notifications::dispatchPending();
                return $out;
            }],
            'borrowings:reminders' => [1800, function () {
                $out = ReminderJobs::borrowingReminders();
                Notifications::dispatchPending();
                return $out;
            }],
            'fines:recalculate' => ['00:30', fn () => Locks::named('mz:job:fines', fn () => Borrowings::recalculateOpenFines())],
            'choir:eligibility' => ['02:15', function () {
                $out = Locks::named('mz:job:choir-eligibility', fn () => Choir::refresh());
                Notifications::dispatchPending();
                return $out;
            }],
            'sinksar:refresh' => ['00:05', function () {
                $out = Locks::named('mz:job:sinksar-refresh', function () {
                    \App\Mz\Services\Sinksar::forToday();
                    $tomorrowDt = (new \DateTimeImmutable('now', \App\Mz\Support\Dates::tz()))->modify('+1 day');
                    \App\Mz\Services\Sinksar::forDate($tomorrowDt->format('Y-m-d'));
                    return \App\Mz\Services\Sinksar::sendDailyNotification();
                });
                Notifications::dispatchPending();
                return $out;
            }],
            'cleanup' => ['03:00', fn () => self::cleanup()],
            // Telegram: webhook when TELEGRAM_WEBHOOK_SECRET is set (re-registered daily), otherwise
            // pending updates are fetched here once a minute (no long-running poller needed).
            'telegram:webhook' => [86400, fn () => self::telegramWebhook()],
            'telegram:updates' => [60, fn () => self::telegramUpdates()],
        ];
    }

    public static function telegramWebhook(): array
    {
        if (! Telegram::enabled() || ! config('mz.telegram.webhook_secret')) return ['skipped' => true];
        Telegram::api('setWebhook', [
            'url' => config('mz.public_base_url') . '/api/v1/telegram/webhook',
            'secret_token' => config('mz.telegram.webhook_secret'),
            'allowed_updates' => ['message'],
        ]);
        return ['registered' => true];
    }

    public static function telegramUpdates(): array
    {
        if (! Telegram::enabled() || config('mz.telegram.webhook_secret')) return ['skipped' => true];
        return Locks::named('mz:job:telegram-updates', function () {
            // getUpdates refuses to work while a webhook is set.
            if (! cache()->get('mz:telegram:webhook_deleted')) {
                try {
                    Telegram::api('deleteWebhook', []);
                } catch (\Throwable) {
                    // ignore
                }
                cache()->put('mz:telegram:webhook_deleted', true, 86400);
            }
            $offset = (int) (DB::table('telegram_state')->where('key', 'offset')->value('value') ?? 0);
            $updates = Telegram::api('getUpdates', ['offset' => $offset, 'timeout' => 0, 'allowed_updates' => ['message']], 20) ?: [];
            foreach ($updates as $u) {
                $offset = $u['update_id'] + 1;
                try {
                    Telegram::handleUpdate($u);
                } catch (\Throwable $e) {
                    Log::error('telegram update failed', ['error' => $e->getMessage()]);
                }
            }
            if ($updates) DB::table('telegram_state')->upsert([['key' => 'offset', 'value' => $offset]], ['key'], ['value']);
            return ['updates' => count($updates)];
        });
    }

    /** Called after every HTTP response; does nothing unless a job is due. */
    public static function tick(): void
    {
        if (! config('mz.jobs_enabled')) return;
        $now = time();
        // Fast path: a timestamp file (no database query on most requests). Any failure here only
        // means we fall through to the database lock, which is the real guard.
        $stamp = storage_path('framework/mz-next-tick');
        $next = @file_get_contents($stamp);
        if ($next !== false && $now < (int) $next) return;
        @file_put_contents($stamp, (string) ($now + self::TICK_SECONDS), LOCK_EX);
        @set_time_limit(300);
        @ignore_user_abort(true);
        // One process wins the tick (MySQL named lock); the others return immediately.
        Locks::named('mz:jobs:tick', fn () => self::runDue());
    }

    /** Run every due job (or the named ones regardless of schedule). */
    public static function runDue(?array $only = null, bool $force = false): array
    {
        $results = [];
        $local = (new DateTimeImmutable('now'))->setTimezone(Dates::tz());
        $state = self::state();
        foreach (self::all() as $name => [$when, $fn]) {
            if ($only && ! in_array($name, $only, true)) continue;
            $last = $state[$name] ?? null;
            if (! $force && ! self::isDue($when, $last, $local)) continue;
            self::remember($name, $when, $local, null);
            try {
                $results[$name] = $fn();
            } catch (\Throwable $e) {
                Log::error('job failed', ['job' => $name, 'error' => $e->getMessage()]);
                $results[$name] = ['error' => $e->getMessage()];
            }
            self::remember($name, $when, $local, $results[$name]);
        }
        return $results;
    }

    /** name => ['at' => unix seconds|null, 'day' => 'Y-m-d'|null] */
    private static function state(): array
    {
        try {
            $out = [];
            foreach (DB::table('job_runs')->get() as $r) {
                $out[$r->name] = ['at' => $r->last_run_at ? Dates::of($r->last_run_at)?->getTimestamp() : null, 'day' => Dates::toDateOnly($r->last_day)];
            }
            return $out;
        } catch (\Throwable) {
            return []; // table not migrated yet: everything is due (jobs are idempotent)
        }
    }

    private static function remember(string $name, int|string $when, DateTimeImmutable $local, mixed $result): void
    {
        try {
            $row = ['name' => $name, 'last_run_at' => gmdate('Y-m-d H:i:s'), 'last_day' => is_int($when) ? null : $local->format('Y-m-d'), 'last_result' => $result === null ? null : mb_substr((string) json_encode($result), 0, 2000)];
            DB::table('job_runs')->upsert([$row], ['name'], ['last_run_at', 'last_day', 'last_result']);
        } catch (\Throwable) {
            // ignore — see state()
        }
    }

    private static function isDue(int|string $when, ?array $last, DateTimeImmutable $local): bool
    {
        if (is_int($when)) return ! $last || ! $last['at'] || time() - (int) $last['at'] >= $when;
        // Daily: once per local day, at or after the given local time.
        return $local->format('H:i') >= $when && ($last['day'] ?? null) !== $local->format('Y-m-d');
    }

    /** Last run of every job (for the admin dashboard / `mz:jobs --list`). */
    public static function status(): array
    {
        try {
            return DB::table('job_runs')->orderBy('name')->get()->map(fn ($r) => ['name' => $r->name, 'last_run_at' => $r->last_run_at, 'last_day' => Dates::toDateOnly($r->last_day), 'last_result' => $r->last_result ? json_decode($r->last_result, true) : null])->all();
        } catch (\Throwable) {
            return [];
        }
    }

    /** Purges expired tokens / receipts / old read notifications, completes finished programs. */
    public static function cleanup(): array
    {
        return Locks::named('mz:job:cleanup', function () {
            $d = fn (int $n) => Dates::sql(Dates::now()->modify("-$n days"));
            $retention = (int) ((Settings::get('notifications.retention_days')['days'] ?? null) ?? 365);
            return [
                // Live sessions are never deleted (they do not expire); only long-replaced tokens are.
                'tokens' => DB::table('refresh_tokens')->whereNotNull('revoked_at')->where('revoked_at', '<', $d(180))->delete(),
                'revoked_access' => DB::table('revoked_access_tokens')->where('expires_at', '<', Dates::sql(Dates::now()))->delete(),
                'resets' => DB::table('password_resets')->where('expires_at', '<', $d(1))->delete(),
                'receipts' => DB::table('sync_receipts')->where('created_at', '<', $d(30))->delete(),
                'notifications' => DB::table('notifications')->where('created_at', '<', $d($retention))->whereNotNull('read_at')->delete(),
                'fcm' => DB::table('fcm_tokens')->where('invalidated_at', '<', $d(30))->orWhere('last_seen_at', '<', $d(120))->delete(),
                // Programs that have ended are marked completed.
                'completed' => DB::table('programs')->where('status', 'published')->where('recurrence', 'once')->where('ends_at', '<', Dates::sql(Dates::now()))->update(['status' => 'completed']),
                'scheduled' => DB::table('scheduled_notifications')->where('status', '!=', 'pending')->where('created_at', '<', $d(60))->delete(),
            ];
        });
    }
}
