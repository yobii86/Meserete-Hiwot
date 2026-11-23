<?php

namespace App\Mz\Support;

/** Program, attendance, reminder and permission validators (port of validators/programs.js). */
final class ProgramSchemas
{
    public static function isoDate(): ZString
    {
        return Z::string()->regex('/^\d{4}-\d{2}-\d{2}$/', 'INVALID_DATE');
    }

    public static function programCreate(): ZObject
    {
        return Z::object([
            'title' => V::text(1, 255),
            'description' => V::optionalText(20000),
            'location' => V::optionalText(255),
            'starts_at' => V::dateTime(),
            // Optional: a program without an end time runs until the end of its day.
            'ends_at' => V::dateTime()->nullable()->optional(),
            // Retired (no late window any more): still accepted from older app versions, ignored.
            'on_time_minutes' => Z::any()->optional(),
            'late_minutes' => Z::any()->optional(),
            // Reminders before each occurrence: 2 days, 1 day, 6 hours and/or 1 hour (minutes).
            'reminder_offsets' => self::reminderOffsets()->optional(),
            'requires_registration' => Z::boolean()->optional(),
            'requires_attendance' => Z::boolean()->optional(),
            'capacity' => Z::number()->int()->positive()->max(1000000)->nullable()->optional(),
            'audience' => Z::enum(['all', 'participants'])->optional(),
            'event_type' => Z::enum(['wedding', 'holiday', 'memorial', 'celebration', 'other'])->nullable()->optional(),
            'status' => Z::enum(['draft', 'published', 'cancelled', 'completed'])->optional(),
            'reminder_enabled' => Z::boolean()->optional(),
            'reminder_days_before' => Z::number()->int()->min(0)->max(30)->optional(),
            'reminder_title' => V::optionalText(255),
            'reminder_body' => V::optionalText(1000),
            'category_id' => Z::number()->int()->positive()->nullable()->optional(),
            'recurrence' => Z::enum(['once', 'weekly', 'monthly', 'twice_monthly', 'ethiopian_days'])->optional(),
            'ethiopian_days' => Z::array(Z::number()->int()->min(1)->max(30))->min(1)->max(30)->nullable()->optional(),
            'is_additional' => Z::boolean()->optional(),
            'counts_for_selection' => Z::boolean()->optional(),
            'monthly_rule' => Z::enum(['day_of_month', 'nth_weekday'])->nullable()->optional(),
            'ordinal_weeks' => Z::any()->optional(),
            'recurring_weekdays' => Z::any()->optional(),
            'recurrence_until' => self::isoDate()->nullable()->optional(),
            'member_groups' => V::memberGroups()->optional(),
            'is_mandatory_reminder' => Z::boolean()->optional(),
            'reminders_enforce' => Z::boolean()->optional(),
            // Remind the audience every N calendar days (15 by policy) from reminder_interval_start
            // while the program runs; null switches it off. Unset on create = the program type's default.
            'reminder_interval_days' => Z::number()->int()->min(1)->max(365)->nullable()->optional(),
            'reminder_interval_start' => self::isoDate()->nullable()->optional(),
            // Education program links (F3 / F4)
            'class_ids' => Z::array(V::id())->max(100)->optional(),
            'course_ids' => Z::array(V::id())->max(100)->optional(),
            'schedule_id' => V::id()->nullable()->optional(),
            'academic_year_id' => V::id()->nullable()->optional(),
        ]);
    }

    public static function checkOverlap(): ZObject
    {
        return Z::object([
            'starts_at' => V::dateTime(),
            'ends_at' => V::dateTime()->nullable()->optional(),
            'recurrence' => Z::enum(['once', 'weekly', 'monthly', 'twice_monthly', 'ethiopian_days'])->optional(),
            'monthly_rule' => Z::enum(['day_of_month', 'nth_weekday'])->nullable()->optional(),
            'ordinal_weeks' => Z::any()->optional(),
            'recurring_weekdays' => Z::any()->optional(),
            'recurrence_until' => self::isoDate()->nullable()->optional(),
            'ethiopian_days' => Z::array(Z::number()->int()->min(1)->max(30))->min(1)->max(30)->nullable()->optional(),
            'location' => V::optionalText(255),
            'exclude_program_id' => V::id()->optional(),
            'category_id' => V::id()->optional(),
        ]);
    }

    public const REMINDER_OFFSETS = [2880, 1440, 360, 60];

    public static function reminderOffsets(): ZType
    {
        return Z::array(Z::number()->int()->refine(fn ($v) => in_array($v, self::REMINDER_OFFSETS, true), 'INVALID_REMINDER_OFFSET'))->max(4);
    }

    public static function programUpdate(): ZObject
    {
        return self::programCreate()->partial()->strict();
    }

    public static function programListQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'scope' => Z::enum(['upcoming', 'past', 'all'])->optional(),
            'status' => Z::enum(['draft', 'published', 'cancelled', 'completed'])->optional(),
            'from' => Z::coerceDate()->optional(),
            'to' => Z::coerceDate()->optional(),
            'mine' => V::bool()->optional(),
            'category_id' => Z::coerceNumber()->int()->positive()->optional(),
            'recurrence' => Z::enum(['once', 'weekly', 'monthly', 'twice_monthly', 'ethiopian_days'])->optional(),
        ]);
    }

    public static function participantsBulk(): ZObject
    {
        return Z::object([
            'target' => V::bulkTarget(),
            'status' => Z::enum(['invited', 'registered'])->default('invited'),
            'notify' => Z::boolean()->default(true),
        ]);
    }

    public static function attendanceStatus(): ZEnum
    {
        // What a taker records: present (signed) or excused (reason). Absent is automatic; there is no late.
        return Z::enum(['present', 'excused']);
    }

    /** A member's signature on the attendance screen (PNG data URL). */
    public static function signature(): ZType
    {
        return Z::string()->max(600000)->regex('#^data:image/png;base64,#', 'INVALID_SIGNATURE');
    }

    public static function attendanceSet(): ZObject
    {
        return Z::object([
            'status' => self::attendanceStatus(),
            'notes' => V::optionalText(500),
            'via' => Z::enum(['qr', 'manual'])->optional(),
            'signature' => self::signature()->nullable()->optional(),
            'date' => self::isoDate()->optional(),
        ]);
    }

    public static function attendanceBulk(): ZObject
    {
        return Z::object([
            'target' => V::bulkTarget(),
            'status' => self::attendanceStatus(),
            'notes' => V::optionalText(500),
            'date' => self::isoDate()->optional(),
        ]);
    }

    public static function occurrenceQuery(): ZObject
    {
        return Z::object(['date' => self::isoDate()->optional()]);
    }

    public static function calendarQuery(): ZObject
    {
        return Z::object([
            'from' => self::isoDate(),
            'to' => self::isoDate(),
            'category_id' => Z::coerceNumber()->int()->positive()->optional(),
        ]);
    }

    public static function statsQuery(): ZObject
    {
        return Z::object([
            'from' => self::isoDate()->optional(),
            'to' => self::isoDate()->optional(),
            'category_id' => Z::coerceNumber()->int()->positive()->optional(),
        ]);
    }

    public static function categoryCreate(): ZObject
    {
        return Z::object([
            'name' => V::text(1, 120),
            'name_en' => V::optionalText(120),
            'color' => Z::string()->regex('/^#[0-9A-Fa-f]{6}$/', 'INVALID_COLOR')->optional(),
            'display_order' => Z::number()->int()->min(0)->max(10000)->optional(),
            'is_active' => Z::boolean()->optional(),
            // Reminder rules of this program type: what new programs of the type start with.
            'reminder_offsets' => self::reminderOffsets()->nullable()->optional(),
            'reminder_interval_days' => Z::number()->int()->min(1)->max(365)->nullable()->optional(),
        ]);
    }

    public static function categoryUpdate(): ZObject
    {
        return self::categoryCreate()->partial()->strict();
    }

    public static function rosterQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'source' => Z::enum(['participants', 'all'])->optional(),
            'status' => Z::enum(['present', 'absent', 'excused', 'unmarked'])->optional(),
            'date' => self::isoDate()->optional(),
        ]);
    }

    public static function reminderCreate(): ZObject
    {
        return Z::object([
            'client_uuid' => Z::string()->uuid('INVALID_ID'),
            'program_id' => Z::number()->int()->positive()->nullable()->optional(),
            'borrowing_id' => Z::number()->int()->positive()->nullable()->optional(),
            'title' => V::text(1, 255),
            'note' => V::optionalText(500),
            'remind_at' => V::dateTime(),
            'repeat' => Z::enum(['none', 'daily', 'weekly'])->optional(),
            'is_enabled' => Z::boolean()->optional(),
        ]);
    }

    public static function reminderUpdate(): ZObject
    {
        return Z::object([
            'title' => V::text(1, 255)->optional(),
            'note' => V::optionalText(500),
            'remind_at' => V::dateTime()->optional(),
            'repeat' => Z::enum(['none', 'daily', 'weekly'])->optional(),
            'is_enabled' => Z::boolean()->optional(),
            'base_updated_at' => Z::coerceDate()->optional(),
        ])->strict();
    }

    public static function permissionRequest(): ZObject
    {
        return Z::object(['reason' => V::optionalText(500), 'date' => self::isoDate()->optional()])->strict();
    }

    public static function permissionCancel(): ZObject
    {
        return Z::object(['date' => self::isoDate()->optional()]);
    }

    public static function permissionListQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'status' => Z::enum(['pending', 'approved', 'rejected', 'cancelled'])->optional(),
            'program_id' => Z::coerceNumber()->int()->positive()->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
        ]);
    }

    public static function permissionReview(): ZObject
    {
        return Z::object(['status' => Z::enum(['approved', 'rejected']), 'note' => V::optionalText(500)])->strict();
    }

    /** An administrator cancelling an approval given by mistake. */
    public static function permissionCancelApproved(): ZObject
    {
        return Z::object(['reason' => V::text(3, 500)])->strict();
    }

    public static function correctionRequest(): ZObject
    {
        return Z::object([
            'date' => self::isoDate()->optional(),
            'requested_status' => Z::enum(['present', 'excused', 'absent'])->nullable()->optional(),
            // When the member actually arrived (a correction to present), within the occurrence.
            'attended_at' => V::dateTime()->nullable()->optional(),
            'reason' => V::text(3, 1000),
        ])->strict();
    }

    public static function correctionReview(): ZObject
    {
        return Z::object(['decision' => Z::enum(['approve', 'reject']), 'note' => V::optionalText(1000)])->strict();
    }

    public static function correctionListQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'status' => Z::enum(['pending', 'approved', 'rejected'])->optional(),
            'program_id' => Z::coerceNumber()->int()->positive()->optional(),
        ]);
    }

    public static function occurrenceChange(): ZObject
    {
        return Z::object([
            'action' => Z::enum(['cancelled', 'rescheduled', 'suspended', 'restore', 'unsuspend']),
            'starts_at' => Z::coerceDate()->optional(),
            'ends_at' => Z::coerceDate()->optional(),
            'reason' => V::optionalText(500),
        ])->strict();
    }
}
