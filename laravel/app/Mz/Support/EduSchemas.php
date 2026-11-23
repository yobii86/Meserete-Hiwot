<?php

namespace App\Mz\Support;

/**
 * Request schemas of the ትምህርት API (routes/api/edu.php). Kept here, not in the route file: route
 * files can be loaded more than once (route / config caching), and a class declared there would be
 * declared twice.
 */
final class EduSchemas
{
    public static function time()
    {
        return Z::string()->regex('/^([01]\d|2[0-3]):[0-5]\d$/', 'INVALID_TIME');
    }

    public static function score()
    {
        return Z::number()->min(0)->max(100000);
    }

    public static function status()
    {
        return Z::enum(['present', 'absent', 'excused']); // no late status (attendance is scored by elapsed time)
    }

    public static function klass()
    {
        return Z::object([
            'name' => V::text(1, 150),
            'name_en' => V::optionalText(150),
            'description' => V::optionalText(2000),
            'description_en' => V::optionalText(2000),
            'term' => V::optionalText(80),
            'registration_opens_at' => V::dateTime()->nullable()->optional(),
            'registration_closes_at' => V::dateTime()->nullable()->optional(),
            'allow_regular' => Z::boolean()->optional(),
            'allow_distance' => Z::boolean()->optional(),
            'allow_self_registration' => Z::boolean()->optional(),
            'capacity' => Z::number()->int()->min(1)->max(100000)->nullable()->optional(),
            'status' => Z::enum(['active', 'inactive', 'archived'])->optional(),
            // Academic period and organisation of the class (course offering).
            'academic_year' => V::optionalText(20),
            'semester' => V::optionalText(40),
            'department_id' => V::id()->nullable()->optional(),
            'academic_year_id' => V::id()->nullable()->optional(),
            'term_id' => V::id()->nullable()->optional(),
            'level_id' => V::id()->nullable()->optional(),
            'allow_multiple' => Z::boolean()->optional(),
            // Streams students may choose in this class (empty = no streams).
            'streams' => Z::array(V::text(1, 80))->max(20)->nullable()->optional(),
        ]);
    }

    public static function course()
    {
        return Z::object([
            'name' => V::text(1, 150),
            'code' => V::optionalText(30),
            'description' => V::optionalText(2000),
            'teacher_user_id' => V::id()->nullable()->optional(),
            'status' => Z::enum(['active', 'inactive', 'archived'])->optional(),
            // Completion (sent by the subject form; was refused before, so editing a subject — its
            // teacher included — always failed).
            'progress' => Z::number()->int()->min(0)->max(100)->optional(),
            'completed_at' => V::dateOnly()->nullable()->optional(),
            // The catalog subject (curriculum) this class subject teaches.
            'subject_id' => V::id()->nullable()->optional(),
            // F3 offerings
            'term_id' => V::id()->nullable()->optional(),
            'member_groups' => Z::string()->max(500)->nullable()->optional(),
            'mode' => Z::enum(['physical', 'online', 'hybrid'])->optional(),
            'pass_mark' => Z::number()->min(0)->max(100)->optional(),
            'program_ids' => Z::array(V::id())->max(100)->nullable()->optional(),
        ]);
    }

    public static function academicYear()
    {
        return Z::object([
            'eth_year' => Z::number()->int()->min(1900)->max(2200),
            'name' => V::optionalText(100),
            'starts_on' => V::dateOnly()->nullable()->optional(),
            'ends_on' => V::dateOnly()->nullable()->optional(),
            'status' => Z::enum(['planned', 'active', 'closed'])->optional(),
            'is_current' => Z::boolean()->optional(),
        ]);
    }

    public static function term()
    {
        return Z::object([
            'name' => V::text(1, 100),
            'sort_order' => Z::number()->int()->min(0)->max(1000)->optional(),
            'starts_on' => V::dateOnly()->nullable()->optional(),
            'ends_on' => V::dateOnly()->nullable()->optional(),
            'status' => Z::enum(['planned', 'active', 'closed'])->optional(),
        ]);
    }

    public static function level()
    {
        return Z::object([
            'code' => V::text(1, 30),
            'name' => V::text(1, 100),
            'name_en' => V::optionalText(100),
            'kind' => Z::enum(['grade', 'extra'])->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(1000)->optional(),
            'is_active' => V::bool()->optional(),
        ]);
    }

    public static function assign()
    {
        return Z::object([
            'user_ids' => Z::array(V::id())->min(1)->max(500),
            'program' => Z::enum(['regular', 'distance'])->default('regular'),
        ]);
    }

    public static function transfer()
    {
        return Z::object([
            'target_class_id' => V::id(),
            'reason' => V::text(1, 500),
        ]);
    }

    /** A student's academic request. */
    public static function request()
    {
        return Z::object([
            'type' => Z::enum(\App\Mz\Services\EduRequests::TYPES),
            'class_id' => V::id()->nullable()->optional(),
            'target_class_id' => V::id()->nullable()->optional(),
            'course_id' => V::id()->nullable()->optional(),
            'requested_value' => V::optionalText(120),
            'reason' => V::text(3, 2000),
        ])->strict();
    }

    /** A student's complaint (JSON or multipart with an optional `file`). */
    public static function complaint()
    {
        return Z::object([
            'category' => Z::enum(\App\Mz\Services\EduComplaints::CATEGORIES),
            'class_id' => Z::coerceNumber()->int()->positive()->nullable()->optional(),
            'course_id' => Z::coerceNumber()->int()->positive()->nullable()->optional(),
            'assessment_id' => Z::coerceNumber()->int()->positive()->nullable()->optional(),
            'teacher_user_id' => Z::coerceNumber()->int()->positive()->nullable()->optional(),
            'subject' => V::text(3, 200),
            'description' => V::text(10, 8000),
        ]);
    }

    public static function assignment()
    {
        return Z::object([
            'title' => V::text(1, 255),
            'title_en' => V::optionalText(255),
            'instructions' => V::optionalText(20000),
            'instructions_en' => V::optionalText(10000),
            'course_id' => V::id()->nullable()->optional(),
            'class_id' => V::id()->nullable()->optional(),
            'subject_id' => V::id()->nullable()->optional(),
            'grade' => Z::number()->int()->min(1)->max(12)->nullable()->optional(),
            'max_score' => Z::number()->min(1)->max(1000)->optional(),
            'due_at' => V::dateTime()->nullable()->optional(),
            'publish_at' => V::dateTime()->nullable()->optional(),
            'late_policy' => Z::enum(['refuse', 'accept_marked'])->optional(),
            'late_until' => V::dateTime()->nullable()->optional(),
            'allow_late' => Z::boolean()->optional(),
            'allow_resubmit' => Z::boolean()->optional(),
            'target_user_ids' => Z::array(V::id())->max(1000)->nullable()->optional(),
            'status' => Z::enum(['draft', 'published', 'archived'])->optional(),
            'is_group' => Z::boolean()->optional(),
            'attachments' => Z::array(Z::any())->optional(),
        ]);
    }

    public static function courseAssignment()
    {
        return self::assignment();
    }

    // ---- learning catalog ----
    public static function category()
    {
        return Z::object([
            'name' => V::text(1, 150),
            'name_en' => V::optionalText(150),
            'description' => V::optionalText(2000),
            'description_en' => V::optionalText(2000),
            'icon_key' => Z::string()->regex('/^[a-z_]{1,40}$/', 'INVALID_ICON')->nullable()->optional(),
            'status' => Z::enum(['active', 'archived'])->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(),
        ])->strict();
    }

    public static function subject()
    {
        return Z::object([
            'category_id' => V::id()->nullable()->optional(),
            'name' => V::text(1, 150),
            'name_en' => V::optionalText(150),
            'code' => V::optionalText(30),
            'description' => V::optionalText(4000),
            'description_en' => V::optionalText(4000),
            'objectives' => V::optionalText(8000),
            'objectives_en' => V::optionalText(8000),
            'visibility' => Z::enum(['enrolled', 'members'])->optional(),
            'sequential' => Z::boolean()->optional(),
            'status' => Z::enum(\App\Mz\Services\EduLearning::STATUSES)->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(),
        ])->strict();
    }

    public static function unit()
    {
        return Z::object([
            'subject_id' => V::id()->nullable()->optional(),
            'title' => V::text(1, 200),
            'title_en' => V::optionalText(200),
            'description' => V::optionalText(2000),
            'description_en' => V::optionalText(2000),
            'status' => Z::enum(\App\Mz\Services\EduLearning::STATUSES)->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(),
        ])->strict();
    }

    public static function lesson()
    {
        return Z::object([
            'unit_id' => V::id()->nullable()->optional(),
            'title' => V::text(1, 200),
            'title_en' => V::optionalText(200),
            'summary' => V::optionalText(1000),
            'summary_en' => V::optionalText(1000),
            // Simple formatting: "# heading", "> quote", "- item", blank line = new paragraph.
            'body' => V::optionalText(100000),
            'body_en' => V::optionalText(100000),
            'scripture_refs' => V::optionalText(1000),
            'objectives' => V::optionalText(8000),
            'objectives_en' => V::optionalText(8000),
            'teacher_notes' => V::optionalText(8000),
            'est_minutes' => Z::number()->int()->min(1)->max(1000)->nullable()->optional(),
            'status' => Z::enum(\App\Mz\Services\EduLearning::STATUSES)->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(),
            'is_mandatory' => Z::boolean()->optional(),
            'requires_quiz' => Z::boolean()->optional(),
        ])->strict();
    }


    public static function materialLink()
    {
        return Z::object([
            'kind' => Z::enum(['link', 'video_link']),
            'title' => V::text(1, 200),
            'title_en' => V::optionalText(200),
            'description' => V::optionalText(2000),
            'description_en' => V::optionalText(2000),
            'url' => Z::string()->trim()->max(1000)->regex('#^https?://\S+$#i', 'INVALID_URL'),
        ])->strict();
    }

    public static function featured()
    {
        return Z::object([
            'target_type' => Z::enum(['subject', 'lesson', 'class']),
            'target_id' => V::id(),
            'title' => V::optionalText(200),
            'subtitle' => V::optionalText(300),
            'starts_at' => V::dateTime()->nullable()->optional(),
            'ends_at' => V::dateTime()->nullable()->optional(),
            'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(),
            'is_active' => Z::boolean()->optional(),
        ])->strict();
    }

    public static function ids()
    {
        return Z::object(['ids' => Z::array(V::id())->min(1)->max(500)])->strict();
    }

    // ---- quizzes ----
    public static function quiz()
    {
        return Z::object([
            'title' => V::text(1, 200),
            'title_en' => V::optionalText(200),
            'course_id' => V::id()->nullable()->optional(),
            'instructions' => V::optionalText(4000),
            'instructions_en' => V::optionalText(4000),
            'lesson_id' => V::id()->nullable()->optional(),
            'assessment_id' => V::id()->nullable()->optional(),
            'opens_at' => V::dateTime()->nullable()->optional(),
            'closes_at' => V::dateTime()->nullable()->optional(),
            'results_release_at' => V::dateTime()->nullable()->optional(),
            'kind' => Z::enum(['quiz', 'exam'])->optional(),
            'time_limit_minutes' => Z::number()->int()->min(1)->max(600)->nullable()->optional(),
            'max_attempts' => Z::number()->int()->min(1)->max(20)->optional(),
            'scoring' => Z::enum(['best', 'last'])->optional(),
            'shuffle' => Z::boolean()->optional(),
            'review_policy' => Z::enum(\App\Mz\Services\EduQuizzes::POLICIES)->optional(),
            'status' => Z::enum(['draft', 'published', 'closed'])->optional(),
        ])->strict();
    }

    public static function questionBank()
    {
        return Z::object([
            'title' => V::text(1, 200)->optional(),
            'name' => V::text(1, 200)->optional(),
            'category' => V::optionalText(100),
            'difficulty' => Z::enum(['easy', 'medium', 'hard', 'mixed'])->optional(),
            'description' => V::optionalText(2000),
        ]);
    }

    public static function draws()
    {
        return Z::object([
            'draws' => Z::array(Z::object([
                'bank_id' => V::id(),
                'count' => Z::number()->int()->min(1)->max(500),
                'points_each' => Z::number()->min(0.01)->max(1000)->optional(),
            ]))->max(50),
        ])->strict();
    }

    public static function questions()
    {
        return Z::object(['questions' => Z::array(Z::object([
            'type' => Z::enum(\App\Mz\Services\EduQuizzes::TYPES),
            'prompt' => V::text(1, 4000),
            'prompt_en' => V::optionalText(4000),
            'options' => Z::array(Z::any())->max(10)->optional(),
            'answer' => Z::any()->optional(),
            'explanation' => V::optionalText(4000),
            'explanation_en' => V::optionalText(4000),
            'points' => Z::number()->min(0)->max(1000)->optional(),
        ]))->max(200)])->strict();
    }

    public static function answers()
    {
        return Z::array(Z::object(['question_id' => V::id(), 'response' => Z::any()->optional()]))->max(200);
    }

    public static function assessment()
    {
        return Z::object(['title' => V::text(1, 150), 'max_score' => self::score()->optional(), 'weight' => Z::number()->min(0)->max(100)->optional(), 'held_on' => V::dateOnly()->nullable()->optional()]);
    }

    public static function magazine()
    {
        return Z::object([
            'title' => V::text(1, 200),
            'title_en' => V::optionalText(200),
            'issue_number' => V::optionalText(50),
            'period_info' => V::optionalText(100),
            'description' => V::optionalText(2000),
            'cover_image' => V::optionalText(255),
            'pdf_path' => V::optionalText(255),
            'pdf_mime' => V::optionalText(100),
            'pdf_size' => Z::number()->int()->min(0)->optional(),
            'status' => Z::enum(['draft', 'published', 'scheduled', 'archived'])->optional(),
            'issue_date' => V::dateOnly(),
            'published_at' => V::dateTime()->nullable()->optional(),
        ])->strict();
    }

    public static function magazineUpdate()
    {
        return Z::object([
            'title' => V::optionalText(200),
            'title_en' => V::optionalText(200),
            'issue_number' => V::optionalText(50),
            'period_info' => V::optionalText(100),
            'description' => V::optionalText(2000),
            'cover_image' => V::optionalText(255),
            'pdf_path' => V::optionalText(255),
            'pdf_mime' => V::optionalText(100),
            'pdf_size' => Z::number()->int()->min(0)->optional(),
            'status' => Z::enum(['draft', 'published', 'scheduled', 'archived'])->optional(),
            'issue_date' => V::dateOnly()->optional(),
            'published_at' => V::dateTime()->nullable()->optional(),
        ])->strict();
    }

    // ---- assignments & announcements (Features D & E) ----

    public static function assignmentSubmission()
    {
        return Z::object([
            'text_response' => V::optionalText(10000),
            'attachments' => Z::array(Z::any())->optional(),
        ])->strict();
    }

    public static function assignmentGrade()
    {
        return Z::object([
            'score' => Z::number()->min(0)->max(1000),
            'feedback' => V::optionalText(5000),
            'release' => Z::boolean()->optional(),
        ])->strict();
    }

    public static function announcement()
    {
        return Z::object([
            'title' => V::optionalText(255),
            'title_en' => V::optionalText(255),
            'body' => V::text(1, 10000),
            'body_en' => V::optionalText(10000),
            'course_id' => V::id()->nullable()->optional(),
            'class_id' => V::id()->nullable()->optional(),
            'subject_id' => V::id()->nullable()->optional(),
            'grade' => Z::number()->int()->min(1)->max(12)->nullable()->optional(),
            'status' => Z::enum(['draft', 'published', 'archived'])->optional(),
            'attachments' => Z::array(Z::any())->optional(),
        ])->strict();
    }

    public static function directMaterial()
    {
        return Z::object([
            'category_id' => V::id()->nullable()->optional(),
            'subject_id' => V::id()->nullable()->optional(),
            'grade' => Z::number()->int()->min(1)->max(12)->nullable()->optional(),
            'title' => V::text(1, 200)->optional(),
            'title_en' => V::optionalText(200),
            'description' => V::optionalText(2000),
            'description_en' => V::optionalText(2000),
            'url' => Z::string()->trim()->max(1000)->regex('#^https?://\S+$#i', 'INVALID_URL')->optional(),
            'kind' => Z::enum(['file', 'link', 'video_link'])->optional(),
            'status' => Z::enum(['draft', 'published', 'archived'])->optional(),
        ])->strict();
    }
}
