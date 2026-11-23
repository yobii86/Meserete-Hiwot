<?php

namespace App\Mz\Services;

use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/** Tracked user actions (port of activityService.js). Only identifiers and minimal context. */
final class Activity
{
    public const REGISTER = 'register';
    public const LOGIN = 'login';
    public const LOGIN_FAILED = 'login_failed';
    public const LOGOUT = 'logout';
    public const PASSWORD_CHANGE = 'password_change';
    public const PASSWORD_RESET = 'password_reset';
    public const PROFILE_UPDATE = 'profile_update';
    public const DEVICE_CHANGE = 'device_change';
    public const MEZMUR_VIEW = 'mezmur_view';
    public const MEZMUR_SEARCH = 'mezmur_search';
    public const AUDIO_PLAY = 'audio_play';
    public const AUDIO_COMPLETE = 'audio_complete';
    public const FAVORITE_ADD = 'favorite_add';
    public const FAVORITE_REMOVE = 'favorite_remove';
    public const DOWNLOAD = 'download';
    public const DOWNLOAD_REMOVE = 'download_remove';
    public const OFFLINE_ACCESS = 'offline_access';
    public const PROGRAM_VIEW = 'program_view';
    public const PROGRAM_REGISTER = 'program_register';
    public const PROGRAM_UNREGISTER = 'program_unregister';
    public const REMINDER_CREATE = 'reminder_create';
    public const REMINDER_UPDATE = 'reminder_update';
    public const REMINDER_DELETE = 'reminder_delete';
    public const NOTIFICATION_OPEN = 'notification_open';
    public const ATTENDANCE = 'attendance';
    public const BORROW = 'borrow';
    public const RETURN = 'return';
    public const PAGE_VIEW = 'page_view';
    public const BOOK_READ = 'book_read';
    public const BOOK_DOWNLOAD = 'book_download';
    public const LESSON_VIEW = 'lesson_view';
    public const MATERIAL_OPEN = 'material_open';
    public const QUIZ_ATTEMPT = 'quiz_attempt';
    public const MAGAZINE_VIEW = 'magazine_view';

    /** Actions a client may report itself (via /activity or offline sync). */
    public const CLIENT_REPORTABLE = [
        self::AUDIO_PLAY,
        self::AUDIO_COMPLETE,
        self::OFFLINE_ACCESS,
        self::MEZMUR_VIEW,
        self::MEZMUR_SEARCH,
        self::NOTIFICATION_OPEN,
        self::PAGE_VIEW,
        self::BOOK_READ,
        self::BOOK_DOWNLOAD,
        self::LESSON_VIEW,
        self::MATERIAL_OPEN,
        self::QUIZ_ATTEMPT,
        self::MAGAZINE_VIEW,
    ];

    public static function track(?int $userId, string $action, ?string $entityType = null, int|string|null $entityId = null, mixed $metadata = null, ?string $clientEventId = null, mixed $occurredAt = null, bool $inTrx = false): void
    {
        $row = [
            'user_id' => $userId,
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'metadata' => $metadata ? json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
            'client_event_id' => $clientEventId,
            'occurred_at' => Dates::sql($occurredAt ?? Dates::now()),
        ];
        try {
            // A replayed offline event (same client_event_id) is silently skipped.
            DB::table('activity_logs')->insertOrIgnore($row);
        } catch (\Throwable $e) {
            if ($inTrx || DB::transactionLevel() > 0) {
                throw $e;
            }
            Log::error('failed to track activity', ['action' => $action, 'error' => $e->getMessage()]);
        }
    }
}
