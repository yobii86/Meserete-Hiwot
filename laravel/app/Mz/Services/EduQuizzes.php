<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Digital quizzes of a class subject (edu_courses). Everything is decided by the server: who may
 * take a quiz (the subject's roster), when (opens_at / closes_at), how often (max_attempts, one
 * attempt in progress at a time), for how long (expires_at fixed when the attempt starts) and when
 * the correct answers are shown (review_policy). Correct answers never leave the server before that.
 *
 * A quiz score is never an official result. A quiz linked to an assessment sends its scores to that
 * assessment's score sheet as DRAFT marks (Edu::saveScores), which then follow the existing review
 * and publication (EduMarks). Students see the score of such a quiz only once that mark is published.
 */
final class EduQuizzes
{
    public const TYPES = ['single', 'multiple', 'true_false', 'short_text'];
    public const POLICIES = ['never', 'after_submit', 'after_close', 'practice'];
    /** Answers saved this long after the time is up still count (network delay). */
    private const GRACE_SECONDS = 30;

    // ------------------------------------------------------------------ lookups
    private static function quiz(int $id, bool $lock = false): object
    {
        $q = DB::table('edu_quizzes')->where('id', $id)->when($lock, fn ($x) => $x->lockForUpdate())->first();
        if (! $q) throw ApiError::notFound('QUIZ_NOT_FOUND', 'Quiz not found');
        return $q;
    }

    private static function attempt(int $id, bool $lock = false): object
    {
        $a = DB::table('edu_quiz_attempts')->where('id', $id)->when($lock, fn ($x) => $x->lockForUpdate())->first();
        if (! $a) throw ApiError::notFound('ATTEMPT_NOT_FOUND', 'Attempt not found');
        return $a;
    }

    private static function course(int $id): object
    {
        $c = DB::table('edu_courses')->where('id', $id)->first();
        if (! $c) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        return $c;
    }

    private static function now(): string
    {
        return Dates::sql(Dates::now());
    }

    private static function isClosed(object $q, ?string $now = null): bool
    {
        $now ??= self::now();
        return $q->status === 'closed' || ($q->closes_at && Dates::sql($q->closes_at) <= $now);
    }

    /** upcoming / open / closed for students. */
    private static function availability(object $q, ?string $now = null): string
    {
        $now ??= self::now();
        if (self::isClosed($q, $now)) return 'closed';
        if ($q->opens_at && Dates::sql($q->opens_at) > $now) return 'upcoming';
        return 'open';
    }

    private static function answersVisible(object $q, ?object $a): bool
    {
        if (! $a || $a->status === 'in_progress') return false;
        if (! empty($a->needs_grading) || $a->status === 'pending_grading') return false;
        if (! empty($q->results_release_at) && Dates::sql($q->results_release_at) > self::now()) {
            return false;
        }
        return match ($q->review_policy) {
            'practice', 'after_submit' => true,
            'after_close' => self::isClosed($q),
            default => false,
        };
    }

    /** The score of a linked quiz is shown only once the official mark of that student is published. */
    private static function scoreVisible(object $q, ?object $a, int $userId): bool
    {
        if (! $a || $a->status === 'in_progress') return false;
        if (! empty($a->needs_grading) || $a->status === 'pending_grading') return false;
        if (! empty($q->results_release_at) && Dates::sql($q->results_release_at) > self::now()) return false;
        if (! $q->assessment_id) return true;
        return DB::table('edu_scores')->where(['assessment_id' => $q->assessment_id, 'user_id' => $userId, 'status' => 'published'])->exists();
    }

    private static function decode(?string $json): mixed
    {
        return $json === null ? null : json_decode($json, true);
    }

    // ------------------------------------------------------------------ teachers
    private static function serializeQuiz(object $q): array
    {
        $drawCount = (int) DB::table('edu_quiz_draws')->where('quiz_id', $q->id)->sum('count');
        $drawPoints = (float) DB::table('edu_quiz_draws')->where('quiz_id', $q->id)->selectRaw('COALESCE(SUM(count * points_each), 0) as tp')->value('tp');
        $directCount = (int) DB::table('edu_quiz_questions')->where('quiz_id', $q->id)->count();
        $directPoints = (float) DB::table('edu_quiz_questions')->where('quiz_id', $q->id)->sum('points');
        return [
            'id' => (int) $q->id, 'course_id' => $q->course_id ? (int) $q->course_id : null, 'magazine_id' => $q->magazine_id ? (int) $q->magazine_id : null,
            'course_name' => $q->course_name ?? null, 'class_name' => $q->class_name ?? null,
            'lesson_id' => $q->lesson_id ? (int) $q->lesson_id : null, 'assessment_id' => $q->assessment_id ? (int) $q->assessment_id : null,
            'title' => $q->title, 'title_en' => $q->title_en ?? null,
            'instructions' => $q->instructions, 'instructions_en' => $q->instructions_en ?? null,
            'opens_at' => $q->opens_at, 'closes_at' => $q->closes_at,
            'results_release_at' => $q->results_release_at ?? null, 'kind' => $q->kind ?? 'quiz',
            'time_limit_minutes' => $q->time_limit_minutes !== null ? (int) $q->time_limit_minutes : null, 'max_attempts' => (int) $q->max_attempts,
            'scoring' => $q->scoring, 'shuffle' => (bool) $q->shuffle, 'review_policy' => $q->review_policy, 'status' => $q->status,
            'availability' => self::availability($q),
            'question_count' => (int) ($q->question_count ?? ($directCount + $drawCount)),
            'total_points' => Num::n($q->total_points ?? ($directPoints + $drawPoints)),
        ];
    }

    private static function quizQuery()
    {
        return DB::table('edu_quizzes as q')->leftJoin('edu_courses as co', 'co.id', '=', 'q.course_id')->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->select('q.*', 'co.name as course_name', 'c.name as class_name',
                DB::raw('(SELECT COUNT(*) FROM edu_quiz_questions qq WHERE qq.quiz_id = q.id) as question_count'),
                DB::raw('(SELECT COALESCE(SUM(points), 0) FROM edu_quiz_questions qq WHERE qq.quiz_id = q.id) as total_points'));
    }

    public static function forCourse(AuthContext $auth, int $courseId): array
    {
        Edu::assertTeachesCourse($auth, $courseId);
        return self::quizQuery()->where('q.course_id', $courseId)->orderByDesc('q.id')->get()->map(fn ($q) => self::serializeQuiz($q) + [
            'attempts' => (int) DB::table('edu_quiz_attempts')->where('quiz_id', $q->id)->where('status', '<>', 'in_progress')->count(),
            'needs_grading' => (int) DB::table('edu_quiz_attempts')->where(['quiz_id' => $q->id, 'needs_grading' => 1])->count(),
        ])->all();
    }

    public static function forSubject(AuthContext $auth, int $subjectId): array
    {
        if (! EduLearning::canEditSubject($auth, $subjectId)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not teach or edit this subject');
        }
        $courseIds = DB::table('edu_courses')->where('subject_id', $subjectId)->pluck('id')->all();
        if (empty($courseIds)) return [];
        return self::quizQuery()->whereIn('q.course_id', $courseIds)->orderByDesc('q.id')->get()->map(fn ($q) => self::serializeQuiz($q) + [
            'attempts' => (int) DB::table('edu_quiz_attempts')->where('quiz_id', $q->id)->where('status', '<>', 'in_progress')->count(),
            'needs_grading' => (int) DB::table('edu_quiz_attempts')->where(['quiz_id' => $q->id, 'needs_grading' => 1])->count(),
        ])->all();
    }

    public static function createForSubject(array $actx, int $subjectId, array $in): array
    {
        $auth = $actx['auth'];
        if (! EduLearning::canEditSubject($auth, $subjectId)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not teach or edit this subject');
        }
        $courseId = ! empty($in['course_id']) ? (int) $in['course_id'] : null;
        if ($courseId) {
            $valid = DB::table('edu_courses')->where(['id' => $courseId, 'subject_id' => $subjectId])->exists();
            if (! $valid) throw ApiError::field('course_id', 'COURSE_NOT_FOUND');
        } else {
            if (! Edu::isModerator($auth)) {
                $courseId = DB::table('edu_courses as co')
                    ->join('edu_course_teachers as ct', 'ct.course_id', '=', 'co.id')
                    ->where('co.subject_id', $subjectId)
                    ->where('ct.user_id', $auth->id)
                    ->where('ct.status', 'active')
                    ->orderByDesc('co.id')
                    ->value('co.id');
                if (! $courseId) {
                    $courseId = DB::table('edu_courses')
                        ->where('subject_id', $subjectId)
                        ->where('teacher_user_id', $auth->id)
                        ->orderByDesc('id')
                        ->value('id');
                }
            }
            if (! $courseId) {
                $courseId = DB::table('edu_courses')->where('subject_id', $subjectId)->orderByDesc('id')->value('id');
            }
            if (! $courseId) {
                $classId = DB::table('edu_classes')->where('status', 'active')->orderByDesc('id')->value('id');
                if (! $classId) {
                    $classId = DB::table('edu_classes')->orderByDesc('id')->value('id');
                }
                $now = Dates::sql(Dates::now());
                if (! $classId) {
                    $classId = (int) DB::table('edu_classes')->insertGetId([
                        'name' => 'General Education',
                        'status' => 'active',
                        'created_by' => $auth->id,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
                $subj = DB::table('edu_subjects')->where('id', $subjectId)->first();
                $courseId = (int) DB::table('edu_courses')->insertGetId([
                    'class_id' => $classId,
                    'subject_id' => $subjectId,
                    'name' => $subj ? ($subj->name ?? $subj->title ?? 'Subject Course') : 'Subject Course',
                    'status' => 'active',
                    'teacher_user_id' => $auth->id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                DB::table('edu_course_teachers')->insert([
                    'course_id' => $courseId,
                    'user_id' => $auth->id,
                    'status' => 'active',
                    'assigned_by' => $auth->id,
                    'assigned_at' => $now,
                    'note' => 'Auto-assigned on quiz creation',
                ]);
            }
        }
        return self::create($actx, (int) $courseId, $in);
    }

    private static function assertLinks(int $courseId, array $in): void
    {
        if (! empty($in['assessment_id']) && ! DB::table('edu_assessments')->where(['id' => $in['assessment_id'], 'course_id' => $courseId])->exists()) {
            throw ApiError::field('assessment_id', 'ASSESSMENT_NOT_FOUND');
        }
        if (! empty($in['lesson_id'])) {
            $subjectId = DB::table('edu_courses')->where('id', $courseId)->value('subject_id');
            if (! $subjectId || ! DB::table('edu_lessons')->where(['id' => $in['lesson_id'], 'subject_id' => $subjectId])->exists()) throw ApiError::field('lesson_id', 'LESSON_NOT_FOUND');
        }
        if (! empty($in['opens_at']) && ! empty($in['closes_at']) && Dates::sql($in['closes_at']) <= Dates::sql($in['opens_at'])) throw ApiError::field('closes_at', 'CLOSES_BEFORE_OPENS');
    }

    private const QUIZ_FIELDS = ['lesson_id', 'assessment_id', 'title', 'title_en', 'instructions', 'instructions_en', 'opens_at', 'closes_at', 'time_limit_minutes', 'max_attempts', 'scoring', 'shuffle', 'review_policy', 'status', 'results_release_at', 'kind'];

    public static function canManageQuiz(AuthContext $auth, object $q): bool
    {
        if (Edu::isModerator($auth)) return true;
        if (! empty($q->magazine_id) && EduMagazines::canManage($auth)) return true;
        if (! empty($q->course_id)) {
            if (EduTeachers::isActive((int) $q->course_id, $auth->id)) return true;
            $course = DB::table('edu_courses')->where('id', (int) $q->course_id)->first();
            if ($course && ! empty($course->subject_id) && EduLearning::canEditSubject($auth, (int) $course->subject_id)) return true;
        }
        return false;
    }

    public static function canTakeQuiz(AuthContext $auth, object $q): bool
    {
        if (self::canManageQuiz($auth, $q)) return true;
        if (! empty($q->magazine_id) || empty($q->course_id)) {
            return \App\Mz\Http\ModuleGate::allows($auth, 'education');
        }
        $course = DB::table('edu_courses')->where('id', (int) $q->course_id)->first();
        if (! $course) return false;
        if (isset($course->status) && $course->status !== 'active') return false;
        $class = DB::table('edu_classes')->where('id', (int) $course->class_id)->first();
        if ($class && isset($class->status) && $class->status !== 'active') return false;
        if (Edu::onRoster($course, $auth->id)) return true;
        if (! empty($course->subject_id)) {
            $subject = DB::table('edu_subjects')->where('id', $course->subject_id)->first();
            if ($subject) {
                if (($subject->visibility ?? 'members') !== 'enrolled') {
                    return true;
                }
                if (EduLearning::isEnrolledInSubject($auth->id, (int) $subject->id)) {
                    return true;
                }
            }
        }
        return false;
    }

    public static function assertCanManageQuiz(AuthContext $auth, object $q): void
    {
        if (! self::canManageQuiz($auth, $q)) {
            if (! empty($q->magazine_id)) {
                EduMagazines::assertCanManage($auth);
            } elseif (! empty($q->course_id)) {
                Edu::assertTeachesCourse($auth, (int) $q->course_id);
            } else {
                throw ApiError::forbidden('FORBIDDEN', 'Permission denied');
            }
        }
    }

    private static function fields(array $in): array
    {
        $out = array_intersect_key($in, array_flip(self::QUIZ_FIELDS));
        foreach (['opens_at', 'closes_at', 'results_release_at'] as $k) if (! empty($out[$k])) $out[$k] = Dates::sql(Dates::of($out[$k]));
        if (array_key_exists('shuffle', $out)) $out['shuffle'] = $out['shuffle'] ? 1 : 0;
        return $out;
    }

    public static function checkPrerequisites(int $id): array
    {
        $q = self::quiz($id);
        $qCount = (int) DB::table('edu_quiz_questions')->where('quiz_id', $id)->count();
        $hasQuestions = $qCount > 0;
        $hasCourse = ! empty($q->course_id);
        $hasAssessment = ! empty($q->assessment_id);
        $hasSchedule = ! empty($q->opens_at) && ! empty($q->closes_at) && Dates::sql($q->closes_at) > Dates::sql($q->opens_at);
        $hasTimeLimit = ($q->time_limit_minutes ?? 0) > 0;

        $items = [
            [
                'key' => 'questions',
                'label' => 'Questions added (ቢያንስ አንድ ጥያቄ)',
                'satisfied' => $hasQuestions,
                'detail' => $hasQuestions ? "{$qCount} questions ready" : 'Add at least one question before publishing',
            ],
            [
                'key' => 'course',
                'label' => 'Class Course assigned (ክፍል እና ኮርስ)',
                'satisfied' => $hasCourse,
                'detail' => $hasCourse ? 'Assigned to course' : 'Must belong to an active class course',
            ],
            [
                'key' => 'assessment',
                'label' => 'Assessment linked (የውጤት መዝገብ/አሰስመንት)',
                'satisfied' => $hasAssessment,
                'detail' => $hasAssessment ? 'Linked to official course assessment' : 'Must link to an assessment so marks flow to report cards',
            ],
            [
                'key' => 'schedule',
                'label' => 'Schedule configured (የፈተና መክፈቻና መዝጊያ ቀን)',
                'satisfied' => $hasSchedule,
                'detail' => $hasSchedule ? "Opens: {$q->opens_at}, Closes: {$q->closes_at}" : 'Set start date and closing date (closing must be after start)',
            ],
            [
                'key' => 'time_limit',
                'label' => 'Time limit set (የፈተናው የጊዜ ገደብ)',
                'satisfied' => $hasTimeLimit,
                'detail' => $hasTimeLimit ? "{$q->time_limit_minutes} minutes" : 'Set duration in minutes (e.g. 60 mins)',
            ],
        ];

        $canPublish = $hasQuestions && $hasCourse && ($q->kind !== 'exam' || ($hasAssessment && $hasSchedule && $hasTimeLimit));

        return [
            'quiz_id' => $id,
            'kind' => $q->kind ?? 'quiz',
            'status' => $q->status,
            'can_publish' => $canPublish,
            'prerequisites' => $items,
        ];
    }

    public static function allAdminQuizzes(AuthContext $auth, array $params = []): array
    {
        $isMod = Edu::isModerator($auth) || \App\Mz\Http\ModuleGate::allows($auth, 'education');
        $subjectId = ! empty($params['subject_id']) ? (int) $params['subject_id'] : null;
        $status = ! empty($params['status']) && $params['status'] !== 'all' ? (string) $params['status'] : null;
        $kind = ! empty($params['kind']) ? (string) $params['kind'] : null;

        $q = self::quizQuery();

        if (! $isMod) {
            $teachingIds = EduTeachers::myCourseIds($auth->id);
            $q->where(function ($w) use ($auth, $teachingIds) {
                $w->whereIn('q.course_id', $teachingIds ?: [0])
                  ->orWhere('q.created_by', $auth->id)
                  ->orWhereExists(function ($sub) use ($auth) {
                      $sub->select(DB::raw(1))
                          ->from('edu_courses as co')
                          ->join('edu_course_teachers as ct', 'ct.course_id', '=', 'co.id')
                          ->whereColumn('co.id', 'q.course_id')
                          ->where('ct.user_id', $auth->id)
                          ->where('ct.status', 'active');
                  });
            });
        }

        if ($subjectId) {
            $q->where('co.subject_id', $subjectId);
        }

        if ($status) {
            $q->where('q.status', $status);
        }

        if ($kind) {
            $q->where('q.kind', $kind);
        }

        $quizzes = $q->orderByDesc('q.id')->limit(200)->get();

        // High performance single batch count query
        $quizIds = $quizzes->pluck('id')->all();
        $attemptsCounts = [];
        $needsGradingCounts = [];

        if (! empty($quizIds)) {
            $attemptsCounts = DB::table('edu_quiz_attempts')
                ->whereIn('quiz_id', $quizIds)
                ->where('status', '<>', 'in_progress')
                ->groupBy('quiz_id')
                ->selectRaw('quiz_id, COUNT(*) as cnt')
                ->pluck('cnt', 'quiz_id')
                ->all();

            $needsGradingCounts = DB::table('edu_quiz_attempts')
                ->whereIn('quiz_id', $quizIds)
                ->where('needs_grading', 1)
                ->groupBy('quiz_id')
                ->selectRaw('quiz_id, COUNT(*) as cnt')
                ->pluck('cnt', 'quiz_id')
                ->all();
        }

        return $quizzes->map(function ($row) use ($attemptsCounts, $needsGradingCounts) {
            $data = self::serializeQuiz($row);
            $data['attempts'] = (int) ($attemptsCounts[$row->id] ?? 0);
            $data['needs_grading'] = (int) ($needsGradingCounts[$row->id] ?? 0);
            return $data;
        })->all();
    }

    public static function create(array $actx, int $courseId, array $in): array
    {
        $auth = $actx['auth'];
        $course = self::course($courseId);
        if (! (Edu::isModerator($auth) || EduTeachers::isActive($courseId, $auth->id) || (! empty($course->subject_id) && EduLearning::canEditSubject($auth, (int) $course->subject_id)))) {
            Edu::assertTeachesCourse($auth, $courseId);
        }
        self::assertLinks($courseId, $in);
        if (($in['kind'] ?? 'quiz') === 'exam') {
            if (empty($in['assessment_id'])) throw ApiError::field('assessment_id', 'ASSESSMENT_REQUIRED');
            $in['max_attempts'] ??= 1;
        }
        $in['status'] = 'draft'; // questions first; published with update()
        $id = DB::table('edu_quizzes')->insertGetId(['course_id' => $courseId, 'created_by' => $auth->id] + self::fields($in));
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz', $id, ['created' => $in['title'], 'course' => $courseId]);
        return self::teacherQuiz($auth, $id);
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        $q = self::quiz($id);
        self::assertCanManageQuiz($auth, $q);
        self::assertLinks((int) $q->course_id, $in + ['opens_at' => $q->opens_at, 'closes_at' => $q->closes_at]);
        $kind = $in['kind'] ?? $q->kind ?? 'quiz';
        if ($kind === 'exam') {
            $assessmentId = $in['assessment_id'] ?? $q->assessment_id;
            if (empty($assessmentId)) throw ApiError::field('assessment_id', 'ASSESSMENT_REQUIRED');
        }
        $taken = DB::table('edu_quiz_attempts')->where('quiz_id', $id)->exists();
        // Once somebody started, the rules that decide a score do not change under them.
        if ($taken) {
            foreach (['scoring', 'max_attempts', 'time_limit_minutes', 'assessment_id'] as $k) {
                if (array_key_exists($k, $in) && (string) $in[$k] !== (string) $q->$k) throw ApiError::conflict('QUIZ_HAS_ATTEMPTS', 'Students already took this quiz');
            }
        }
        $patch = self::fields($in);
        $publishing = ($patch['status'] ?? null) === 'published' && $q->status === 'draft';
        if (($patch['status'] ?? null) === 'draft' && $taken) throw ApiError::conflict('QUIZ_HAS_ATTEMPTS', 'Students already took this quiz');
        if ($patch) DB::table('edu_quizzes')->where('id', $id)->update($patch);
        if ($publishing) {
            if (! DB::table('edu_quiz_questions')->where('quiz_id', $id)->exists()) {
                DB::table('edu_quizzes')->where('id', $id)->update(['status' => 'draft']);
                throw ApiError::conflict('QUIZ_EMPTY', 'Add questions before publishing (ፈተናውን ከማሳተምዎ በፊት ቢያንስ አንድ ጥያቄ ያክሉ)');
            }
            if ($kind === 'exam') {
                $prereqs = self::checkPrerequisites($id);
                if (! $prereqs['can_publish']) {
                    $missing = array_map(fn ($it) => $it['label'], array_filter($prereqs['prerequisites'], fn ($it) => ! $it['satisfied']));
                    DB::table('edu_quizzes')->where('id', $id)->update(['status' => 'draft']);
                    throw ApiError::conflict('EXAM_PREREQUISITE_FAILED', 'Cannot publish closing exam. Missing: ' . implode(', ', $missing));
                }
            }
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz', $id, ['fields' => array_keys($patch)]);
        if ($publishing) self::notifyPublished(self::quiz($id), $auth->id);
        return self::teacherQuiz($auth, $id);
    }

    public static function delete(array $actx, int $id): void
    {
        $q = self::quiz($id);
        self::assertCanManageQuiz($actx['auth'], $q);
        if (DB::table('edu_quiz_attempts')->where('quiz_id', $id)->exists()) throw ApiError::conflict('HAS_RECORDS', 'Students already took this quiz; close it instead');
        DB::table('edu_quizzes')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz', $id, ['deleted' => $q->title]);
    }

    /** The quiz with its questions AND answers — teachers only. */
    public static function teacherQuiz(AuthContext $auth, int $id): array
    {
        $q = self::quiz($id);
        self::assertCanManageQuiz($auth, $q);
        $row = self::quizQuery()->where('q.id', $id)->first();
        return self::serializeQuiz($row) + [
            'has_attempts' => DB::table('edu_quiz_attempts')->where('quiz_id', $id)->exists(),
            'can_edit' => true,
            'prerequisites' => self::checkPrerequisites($id),
            'questions' => DB::table('edu_quiz_questions')->where('quiz_id', $id)->orderBy('sort_order')->orderBy('id')->get()->map(fn ($x) => [
                'id' => (int) $x->id, 'type' => $x->type, 'prompt' => $x->prompt, 'prompt_en' => $x->prompt_en ?? null, 'options' => self::decode($x->options) ?? [],
                'answer' => self::decode($x->answer), 'explanation' => $x->explanation, 'explanation_en' => $x->explanation_en ?? null, 'points' => Num::n($x->points), 'sort_order' => (int) $x->sort_order,
            ])->all(),
        ];
    }

    /** Unified detail endpoint for both students and staff */
    public static function quizDetail(AuthContext $auth, int $id): array
    {
        $q = self::quiz($id);
        $canManage = self::canManageQuiz($auth, $q);
        if (! $canManage && ! self::canTakeQuiz($auth, $q)) {
            throw ApiError::forbidden('NOT_ENROLLED', 'You do not have access to this quiz');
        }

        $row = self::quizQuery()->where('q.id', $id)->first();
        if (! $row) throw ApiError::notFound('QUIZ_NOT_FOUND', 'Quiz not found');

        self::finalizeExpired($id, $auth->id);
        $attempts = DB::table('edu_quiz_attempts')->where(['user_id' => $auth->id, 'quiz_id' => $id])->orderBy('attempt_no')->get();
        $done = array_values(array_filter($attempts->all(), fn ($a) => $a->status !== 'in_progress'));
        $chosen = self::chosen($q, $done);
        $inProgress = $attempts->firstWhere('status', 'in_progress');
        $visible = $chosen && self::scoreVisible($q, $chosen, $auth->id);

        $out = self::serializeQuiz($row) + [
            'can_edit' => $canManage,
            'has_attempts' => DB::table('edu_quiz_attempts')->where('quiz_id', $id)->exists(),
            'attempts_used' => count($attempts),
            'attempts_left' => max(0, (int) $q->max_attempts - count($attempts)),
            'in_progress_attempt_id' => $inProgress ? (int) $inProgress->id : null,
            'last_attempt_id' => $attempts->isNotEmpty() ? (int) $attempts->last()->id : null,
            'my_score' => $visible ? self::total($chosen) : null,
            'my_max_score' => $visible ? Num::n($chosen->max_score) : null,
            'score_hidden' => $chosen !== null && ! $visible,
            'official' => $q->assessment_id !== null,
            'needs_grading' => $chosen ? (bool) $chosen->needs_grading : false,
        ];

        if ($canManage) {
            $out['questions'] = DB::table('edu_quiz_questions')->where('quiz_id', $id)->orderBy('sort_order')->orderBy('id')->get()->map(fn ($x) => [
                'id' => (int) $x->id, 'type' => $x->type, 'prompt' => $x->prompt, 'prompt_en' => $x->prompt_en ?? null,
                'options' => self::decode($x->options) ?? [],
                'answer' => self::decode($x->answer), 'explanation' => $x->explanation, 'explanation_en' => $x->explanation_en ?? null,
                'points' => Num::n($x->points), 'sort_order' => (int) $x->sort_order,
            ])->all();
        }

        return $out;
    }

    /** Replace all questions (only before anybody started the quiz). */
    public static function setQuestions(array $actx, int $id, array $questions): array
    {
        $auth = $actx['auth'];
        $q = self::quiz($id);
        self::assertCanManageQuiz($auth, $q);
        DB::transaction(function () use ($id, $questions) {
            if (DB::table('edu_quiz_attempts')->where('quiz_id', $id)->lockForUpdate()->exists()) throw ApiError::conflict('QUIZ_HAS_ATTEMPTS', 'Students already took this quiz');
            DB::table('edu_quiz_questions')->where('quiz_id', $id)->delete();
            foreach (array_values($questions) as $i => $x) {
                [$options, $answer] = self::validateQuestion($x, $i);
                DB::table('edu_quiz_questions')->insert([
                    'quiz_id' => $id, 'type' => $x['type'], 'prompt' => $x['prompt'], 'prompt_en' => $x['prompt_en'] ?? null,
                    'options' => $options === null ? null : json_encode($options, JSON_UNESCAPED_UNICODE),
                    'answer' => $answer === null ? null : json_encode($answer, JSON_UNESCAPED_UNICODE),
                    'explanation' => $x['explanation'] ?? null, 'explanation_en' => $x['explanation_en'] ?? null,
                    'points' => $x['points'] ?? 1, 'sort_order' => $i + 1,
                ]);
            }
        });
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz', $id, ['questions' => count($questions)]);
        return self::teacherQuiz($auth, $id);
    }

    /** Options get stable ids (a, b, c…); the answer must point at them. */
    private static function validateQuestion(array $x, int $i): array
    {
        $field = "questions.$i";
        switch ($x['type']) {
            case 'true_false':
                if (! is_bool($x['answer'] ?? null)) throw ApiError::field("$field.answer", 'ANSWER_REQUIRED');
                return [null, $x['answer']];
            case 'short_text':
                $model = isset($x['answer']) && is_string($x['answer']) ? mb_substr(trim($x['answer']), 0, 2000) : null;
                return [null, $model ?: null];
            default:
                $texts = array_values(array_filter(array_map(fn ($o) => is_array($o) ? trim((string) ($o['text'] ?? '')) : trim((string) $o), $x['options'] ?? []), fn ($t) => $t !== ''));
                if (count($texts) < 2) throw ApiError::field("$field.options", 'TWO_OPTIONS_REQUIRED');
                $options = [];
                foreach ($texts as $k => $t) $options[] = ['id' => chr(97 + $k), 'text' => mb_substr($t, 0, 1000)];
                $ids = array_column($options, 'id');
                $ans = $x['answer'] ?? null;
                if ($x['type'] === 'single') {
                    if (! is_string($ans) || ! in_array($ans, $ids, true)) throw ApiError::field("$field.answer", 'ANSWER_REQUIRED');
                } else {
                    $ans = is_array($ans) ? array_values(array_unique(array_filter($ans, 'is_string'))) : [];
                    if (! $ans || array_diff($ans, $ids)) throw ApiError::field("$field.answer", 'ANSWER_REQUIRED');
                    sort($ans);
                }
                return [$options, $ans];
        }
    }

    private static function notifyPublished(object $q, int $actorId): void
    {
        $ids = array_values(array_diff(array_map('intval', Edu::rosterQuery(self::course((int) $q->course_id))->pluck('u.id')->all()), [$actorId]));
        if (! $ids) return;
        $n = Notifications::createForUsers($ids, [
            'type' => 'education',
            'title' => T::t('edu.quiz.title'),
            'body' => T::t('edu.quiz.body', ['title' => $q->title, 'course' => DB::table('edu_courses')->where('id', $q->course_id)->value('name')]),
            'entityType' => 'edu_quiz',
            'entityId' => (int) $q->id,
            'dedupeKey' => fn ($uid) => "edu:quiz:{$q->id}:$uid",
        ]);
        if ($n) Notifications::kick();
    }

    /** Each student's attempts (teachers). */
    public static function results(AuthContext $auth, int $id): array
    {
        $q = self::quiz($id);
        Edu::assertTeachesCourse($auth, (int) $q->course_id);
        self::finalizeExpired($id);
        $roster = Edu::rosterQuery(self::course((int) $q->course_id))->select('u.id', 'u.full_name')->orderBy('u.full_name')->get();
        $attempts = DB::table('edu_quiz_attempts')->where('quiz_id', $id)->orderBy('attempt_no')->get()->groupBy('user_id');
        return [
            'quiz' => self::serializeQuiz(self::quizQuery()->where('q.id', $id)->first()),
            'students' => $roster->map(function ($u) use ($attempts, $q) {
                $mine = $attempts->get($u->id, collect());
                $chosen = self::chosen($q, $mine->all());
                return [
                    'user_id' => (int) $u->id, 'full_name' => $u->full_name,
                    'attempts' => $mine->map(fn ($a) => self::attemptSummary($a))->values()->all(),
                    'score' => $chosen ? self::total($chosen) : null, 'max_score' => $chosen ? Num::n($chosen->max_score) : null,
                    'needs_grading' => $mine->contains(fn ($a) => (bool) $a->needs_grading),
                    'transferred_at' => $mine->pluck('transferred_at')->filter()->map(fn ($d) => Dates::sql($d))->max(),
                ];
            })->all(),
        ];
    }

    /** One attempt with answers and the correct ones — teachers. */
    public static function teacherAttempt(AuthContext $auth, int $attemptId): array
    {
        $a = self::attempt($attemptId);
        $q = self::quiz((int) $a->quiz_id);
        self::assertCanManageQuiz($auth, $q);
        return self::attemptOut($q, $a, true, true) + ['full_name' => DB::table('users')->where('id', $a->user_id)->value('full_name')];
    }

    /** Teacher marks a written (short text) answer with points and feedback. */
    public static function gradeAnswer(array $actx, int $attemptId, int $questionId, float $points, ?string $feedback = null): array
    {
        $auth = $actx['auth'];
        $a = self::attempt($attemptId);
        $q = self::quiz((int) $a->quiz_id);
        self::assertCanManageQuiz($auth, $q);
        if ($a->status === 'in_progress') throw ApiError::conflict('ATTEMPT_IN_PROGRESS', 'The student is still answering');
        if ($a->transferred_at) throw ApiError::conflict('ALREADY_TRANSFERRED', 'The score was already sent to the score sheet; amend the mark there');

        $question = null;
        if (! empty($a->question_ids)) {
            $qids = is_array($a->question_ids) ? $a->question_ids : json_decode($a->question_ids, true);
            if (is_array($qids) && in_array($questionId, $qids)) {
                $question = DB::table('edu_quiz_questions')->where('id', $questionId)->first();
            }
        }
        if (! $question) {
            $question = DB::table('edu_quiz_questions')->where(['id' => $questionId, 'quiz_id' => $q->id])->first();
        }
        if (! $question) throw ApiError::notFound('QUESTION_NOT_FOUND', 'Question not found');
        if ($points < 0 || $points > Num::n($question->points)) throw ApiError::field('points', 'SCORE_TOO_HIGH');

        DB::transaction(function () use ($a, $question, $points, $feedback, $auth) {
            $existing = DB::table('edu_quiz_answers')->where(['attempt_id' => $a->id, 'question_id' => $question->id])->first();
            $row = [
                'attempt_id' => $a->id,
                'question_id' => $question->id,
                'response' => $existing?->response,
                'points_awarded' => $points,
                'is_correct' => $points >= Num::n($question->points) ? 1 : 0,
                'feedback' => $feedback !== null ? trim($feedback) : $existing?->feedback,
                'graded_by' => $auth->id,
                'graded_at' => self::now(),
            ];
            DB::table('edu_quiz_answers')->upsert([$row], ['attempt_id', 'question_id'], ['points_awarded', 'is_correct', 'feedback', 'graded_by', 'graded_at']);
            self::rescore($a->id);
        });

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz_attempt', $attemptId, ['question' => $questionId, 'points' => $points, 'feedback' => $feedback]);
        return self::teacherAttempt($auth, $attemptId);
    }

    /**
     * Send the scores of a quiz linked to an assessment to that assessment's score sheet: DRAFT marks
     * through the ordinary entry path (history, audit), scaled to the assessment's maximum. Marks
     * already submitted / approved / published are left alone (changed only by review / amendment).
     */
    public static function transfer(array $actx, int $id): array
    {
        $auth = $actx['auth'];
        $q = self::quiz($id);
        Edu::assertTeachesCourse($auth, (int) $q->course_id);
        if (! $q->assessment_id) throw ApiError::conflict('QUIZ_NOT_LINKED', 'Link the quiz to an assessment first');
        self::finalizeExpired($id);
        $assessment = DB::table('edu_assessments')->where('id', $q->assessment_id)->first();
        $existing = DB::table('edu_scores')->where('assessment_id', $q->assessment_id)->get()->keyBy('user_id');
        // Only students still taking the subject get a mark (the score sheet refuses anyone else).
        $roster = array_flip(array_map('intval', Edu::rosterQuery(self::course((int) $q->course_id))->pluck('u.id')->all()));
        $rows = [];
        $done = [];
        $pending = 0;
        $locked = 0;
        foreach (DB::table('edu_quiz_attempts')->where('quiz_id', $id)->where('status', '<>', 'in_progress')->get()->groupBy('user_id') as $uid => $list) {
            if (! isset($roster[(int) $uid])) continue;
            if ($list->contains(fn ($a) => (bool) $a->needs_grading)) { $pending++; continue; }
            $prev = $existing->get($uid);
            if ($prev && ! in_array($prev->status, EduMarks::EDITABLE, true)) { $locked++; continue; }
            $chosen = self::chosen($q, $list->all());
            if (! $chosen || Num::n($chosen->max_score) <= 0) continue;
            $score = round(self::total($chosen) / Num::n($chosen->max_score) * Num::n($assessment->max_score), 2);
            $rows[] = ['user_id' => (int) $uid, 'score' => $score, 'remark' => mb_substr(T::t('edu.quiz.remark', ['title' => $q->title]), 0, 300), 'reason' => 'quiz'];
            $done[] = (int) $chosen->id;
        }
        if ($rows) {
            Edu::saveScores($auth, (int) $q->assessment_id, $rows);
            DB::table('edu_quiz_attempts')->whereIn('id', $done)->update(['transferred_at' => self::now()]);
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_quiz', $id, ['transferred' => count($rows), 'assessment' => (int) $q->assessment_id, 'pending' => $pending, 'locked' => $locked]);
        return ['transferred' => count($rows), 'pending_grading' => $pending, 'locked' => $locked, 'assessment_id' => (int) $q->assessment_id];
    }

    // ------------------------------------------------------------------ students
    /** Quizzes of the subjects the member takes (drafts never), with their own attempts. */
    public static function mine(AuthContext $auth, ?int $courseId = null): array
    {
        $courseIds = Edu::myCourseIds($auth->id);
        $studyingSubjectIds = EduLearning::studyingSubjectIds($auth->id);
        $subjectCourses = DB::table('edu_courses')->whereIn('subject_id', $studyingSubjectIds ?: [0])->pluck('id')->all();
        $courseIds = array_values(array_unique(array_merge($courseIds, $subjectCourses)));

        if ($courseId) $courseIds = array_values(array_intersect($courseIds, [$courseId]));
        if (! $courseIds) {
            if (Edu::isModerator($auth)) {
                $courseIds = DB::table('edu_courses')->pluck('id')->all();
            } else {
                return [];
            }
        }
        $rows = self::quizQuery()->whereIn('q.course_id', $courseIds)->where('q.status', '<>', 'draft')->orderByRaw('q.closes_at IS NULL')->orderBy('q.closes_at')->orderByDesc('q.id')->get();
        foreach ($rows as $q) self::finalizeExpired((int) $q->id, $auth->id);
        $attempts = DB::table('edu_quiz_attempts')->where('user_id', $auth->id)->whereIn('quiz_id', $rows->pluck('id')->all() ?: [0])->orderBy('attempt_no')->get()->groupBy('quiz_id');
        return $rows->map(function ($q) use ($attempts, $auth) {
            $mine = $attempts->get($q->id, collect())->all();
            $done = array_values(array_filter($mine, fn ($a) => $a->status !== 'in_progress'));
            $chosen = self::chosen($q, $done);
            $inProgress = current(array_filter($mine, fn ($a) => $a->status === 'in_progress')) ?: null;
            $visible = $chosen && self::scoreVisible($q, $chosen, $auth->id);
            $myMaxScore = null;
            if ($visible && $chosen) {
                $qids = ! empty($chosen->question_ids) ? (is_array($chosen->question_ids) ? $chosen->question_ids : json_decode($chosen->question_ids, true)) : [];
                $qCount = is_array($qids) && ! empty($qids) ? count($qids) : (int) DB::table('edu_quiz_questions')->where('quiz_id', $q->id)->count();
                $myMaxScore = Num::n($chosen->max_score ?: ($qCount > 0 ? $qCount : 100));
            }
            return self::serializeQuiz($q) + [
                'attempts_used' => count($mine), 'attempts_left' => max(0, (int) $q->max_attempts - count($mine)),
                'in_progress_attempt_id' => $inProgress ? (int) $inProgress->id : null,
                'last_attempt_id' => $mine ? (int) end($mine)->id : null,
                'my_score' => $visible ? self::total($chosen) : null, 'my_max_score' => $myMaxScore,
                'score_hidden' => $chosen !== null && ! $visible,
                'official' => $q->assessment_id !== null,
                'needs_grading' => $chosen ? (bool) $chosen->needs_grading : false,
            ];
        })->all();
    }

    private static function assertEligible(AuthContext $auth, object $q): void
    {
        $canManage = self::canManageQuiz($auth, $q);
        if (! $canManage && $q->status === 'draft') throw ApiError::notFound('QUIZ_NOT_FOUND', 'Quiz not found');
        if (! self::canTakeQuiz($auth, $q)) throw ApiError::forbidden('NOT_ENROLLED', 'This quiz is for the students of this subject');
    }

    /** Start an attempt (or resume the one in progress). */
    public static function start(AuthContext $auth, int $id): array
    {
        $q = self::quiz($id);
        self::assertEligible($auth, $q);
        self::finalizeExpired($id, $auth->id);
        $attemptId = DB::transaction(function () use ($auth, $id) {
            $q = self::quiz($id, true); // serialises concurrent starts of this quiz
            $now = self::now();
            $canManage = self::canManageQuiz($auth, $q);
            $state = self::availability($q, $now);
            if (! $canManage) {
                if ($state === 'upcoming') throw ApiError::conflict('QUIZ_NOT_OPEN', 'This quiz is not open yet');
                if ($state === 'closed') throw ApiError::conflict('QUIZ_CLOSED', 'This quiz is closed');
            }
            $mine = DB::table('edu_quiz_attempts')->where(['quiz_id' => $id, 'user_id' => $auth->id])->lockForUpdate()->orderBy('attempt_no')->get();
            $open = $mine->firstWhere('status', 'in_progress');
            if ($open) {
                if (self::expired($open, $now) || (! $canManage && self::isClosed($q, $now))) {
                    self::finalize((int) $open->id);
                    $mine = DB::table('edu_quiz_attempts')->where(['quiz_id' => $id, 'user_id' => $auth->id])->lockForUpdate()->orderBy('attempt_no')->get();
                } else {
                    return (int) $open->id;
                }
            }
            if ($mine->count() >= (int) $q->max_attempts || (int) $q->max_attempts <= 0) {
                throw ApiError::conflict('NO_ATTEMPTS_LEFT', 'You have used all your attempts');
            }
            $expires = null;
            if ($q->time_limit_minutes) $expires = Dates::sql(Dates::of($now)->modify('+' . (int) $q->time_limit_minutes . ' minutes'));
            if ($q->closes_at && (! $expires || Dates::sql($q->closes_at) < $expires)) $expires = Dates::sql($q->closes_at);
            $draws = DB::table('edu_quiz_draws')->where('quiz_id', $id)->get();
            $directQIds = DB::table('edu_quiz_questions')->where('quiz_id', $id)->orderBy('sort_order')->orderBy('id')->pluck('id')->all();
            $drawQIds = [];
            foreach ($draws as $d) {
                $bankIds = DB::table('edu_quiz_questions')
                    ->where('bank_id', $d->bank_id)
                    ->inRandomOrder()
                    ->limit((int) $d->count)
                    ->pluck('id')
                    ->all();
                $drawQIds = array_merge($drawQIds, $bankIds);
            }
            $allQIds = array_values(array_unique(array_merge($directQIds, $drawQIds)));
            if (empty($allQIds)) {
                throw ApiError::conflict('QUIZ_EMPTY', 'This quiz has no questions yet');
            }
            $questionIdsJson = json_encode($allQIds);

            $directPoints = (float) DB::table('edu_quiz_questions')->whereIn('id', $directQIds ?: [0])->sum('points');
            $drawPoints = 0.0;
            foreach ($draws as $d) {
                $drawPoints += ((int) $d->count) * Num::n($d->points_each);
            }
            $maxScore = $directPoints + $drawPoints;
            if ($maxScore <= 0 && $allQIds) {
                $maxScore = (float) DB::table('edu_quiz_questions')->whereIn('id', $allQIds)->sum('points');
            }

            return (int) DB::table('edu_quiz_attempts')->insertGetId([
                'quiz_id' => $id, 'user_id' => $auth->id, 'attempt_no' => $mine->count() + 1, 'started_at' => $now, 'expires_at' => $expires,
                'max_score' => $maxScore ?: null,
                'question_ids' => $questionIdsJson,
            ]);
        });
        if ($auth->accountType === 'user') {
            Activity::track($auth->id, Activity::QUIZ_ATTEMPT, 'edu_quiz', $id, ['title' => $q->title, 'attempt_id' => $attemptId]);
        }
        return self::studentAttempt($auth, $attemptId);
    }

    private static function ownAttempt(AuthContext $auth, int $attemptId, bool $lock = false): array
    {
        $a = self::attempt($attemptId, $lock);
        if ((int) $a->user_id !== $auth->id) throw ApiError::notFound('ATTEMPT_NOT_FOUND', 'Attempt not found');
        return [$a, self::quiz((int) $a->quiz_id)];
    }

    private static function expired(object $a, ?string $now = null): bool
    {
        if (! $a->expires_at) return false;
        $limit = Dates::sql(Dates::of($a->expires_at)->modify('+' . self::GRACE_SECONDS . ' seconds'));
        return ($now ?? self::now()) > $limit;
    }

    public static function studentAttempt(AuthContext $auth, int $attemptId): array
    {
        [$a, $q] = self::ownAttempt($auth, $attemptId);
        if ($a->status === 'in_progress' && self::expired($a)) {
            self::finalize($a->id);
            $a = self::attempt($attemptId);
        }
        return self::attemptOut($q, $a, self::answersVisible($q, $a), false, $auth->id);
    }

    /** Save answers while the attempt runs (any number of times). */
    public static function saveAnswers(AuthContext $auth, int $attemptId, array $answers): array
    {
        DB::transaction(function () use ($auth, $attemptId, $answers) {
            [$a, $q] = self::ownAttempt($auth, $attemptId, true);
            if ($a->status !== 'in_progress') throw ApiError::conflict('ATTEMPT_SUBMITTED', 'This attempt was already submitted');
            if (self::expired($a)) throw ApiError::conflict('ATTEMPT_EXPIRED', 'The time for this attempt is over');
            self::store($a, $answers);
        });
        return self::studentAttempt($auth, $attemptId);
    }

    /** Practice quizzes: check one answer at once (saved, then shown right / wrong with the explanation). */
    public static function check(AuthContext $auth, int $attemptId, int $questionId, mixed $response): array
    {
        [$a, $q] = self::ownAttempt($auth, $attemptId);
        if ($q->review_policy !== 'practice') throw ApiError::forbidden('NOT_PRACTICE', 'Answers are shown after the quiz');
        self::saveAnswers($auth, $attemptId, [['question_id' => $questionId, 'response' => $response]]);
        $question = DB::table('edu_quiz_questions')->where(['id' => $questionId, 'quiz_id' => $q->id])->first();
        $correct = self::isCorrect($question, $response);
        return ['question_id' => $questionId, 'correct' => $correct, 'answer' => $question->type === 'short_text' ? null : self::decode($question->answer), 'explanation' => $question->explanation];
    }

    /** Submit (idempotent: a second submit returns the same result, never a second attempt). */
    public static function submit(AuthContext $auth, int $attemptId, ?array $answers): array
    {
        DB::transaction(function () use ($auth, $attemptId, $answers) {
            [$a] = self::ownAttempt($auth, $attemptId, true);
            if ($a->status !== 'in_progress') return;
            if (self::expired($a)) {
                self::finalize((int) $a->id);
                throw ApiError::conflict('ATTEMPT_EXPIRED', 'The time for this attempt is over');
            }
            if ($answers) self::store($a, $answers);
            self::finalize((int) $a->id);
        });

        $att = DB::table('edu_quiz_attempts')->where('id', $attemptId)->first();
        if ($att && ($att->needs_grading || $att->status === 'pending_grading')) {
            Notifications::notifyEduQuizSubmitted((int) $att->quiz_id, $attemptId, $auth->id);
        }

        EduDashboard::invalidateUserDashboard($auth->id);

        return self::studentAttempt($auth, $attemptId);
    }

    private static function store(object $a, array $answers): void
    {
        if (! empty($a->question_ids)) {
            $qids = is_array($a->question_ids) ? $a->question_ids : json_decode($a->question_ids, true);
            $questions = DB::table('edu_quiz_questions')->whereIn('id', $qids ?: [0])->get()->keyBy('id');
        } else {
            $questions = DB::table('edu_quiz_questions')->where('quiz_id', $a->quiz_id)->get()->keyBy('id');
        }
        foreach ($answers as $x) {
            $question = $questions->get((int) ($x['question_id'] ?? 0));
            if (! $question) throw ApiError::field('question_id', 'QUESTION_NOT_FOUND');
            $r = self::normalize($question, $x['response'] ?? null);
            DB::table('edu_quiz_answers')->upsert([['attempt_id' => $a->id, 'question_id' => $question->id, 'response' => $r === null ? null : json_encode($r, JSON_UNESCAPED_UNICODE)]],
                ['attempt_id', 'question_id'], ['response']);
        }
    }

    /** A response in the shape of its question, or null (unanswered); anything else is refused. */
    private static function normalize(object $question, mixed $r): mixed
    {
        if ($r === null || $r === '' || $r === []) return null;
        $ids = array_column(self::decode($question->options) ?? [], 'id');
        return match ($question->type) {
            'true_false' => is_bool($r) ? $r : throw ApiError::field('response', 'INVALID_ANSWER'),
            'single', 'multiple_choice' => is_string($r) && in_array($r, $ids, true) ? $r : throw ApiError::field('response', 'INVALID_ANSWER'),
            'multiple' => is_array($r) && ! array_diff($r, $ids) ? (function () use ($r) { $v = array_values(array_unique($r)); sort($v); return $v; })() : throw ApiError::field('response', 'INVALID_ANSWER'),
            'short_text' => is_string($r) ? mb_substr(trim($r), 0, 5000) : throw ApiError::field('response', 'INVALID_ANSWER'),
            default => throw ApiError::field('response', 'UNSUPPORTED_QUESTION_TYPE'),
        };
    }

    private static function isCorrect(object $question, mixed $response): ?bool
    {
        if ($question->type === 'short_text') return null;
        $r = $response === null ? null : self::normalize($question, $response);
        $expected = self::decode($question->answer);
        if ($expected === null && $question->answer !== null && $question->answer !== 'null') {
            $expected = $question->answer;
        }
        return $r !== null && $r === $expected;
    }

    /** Close an attempt and mark it: choice questions automatically, written ones wait for the teacher. */
    private static function finalize(int $attemptId): void
    {
        $a = self::attempt($attemptId, true);
        if ($a->status !== 'in_progress') return;
        $answers = DB::table('edu_quiz_answers')->where('attempt_id', $attemptId)->get()->keyBy('question_id');
        $attemptQuestions = ! empty($a->question_ids)
            ? (function () use ($a) {
                $qids = is_array($a->question_ids) ? $a->question_ids : json_decode($a->question_ids, true);
                return DB::table('edu_quiz_questions')->whereIn('id', $qids ?: [0])->get();
            })()
            : DB::table('edu_quiz_questions')->where('quiz_id', $a->quiz_id)->get();
        foreach ($attemptQuestions as $question) {
            $ans = $answers->get($question->id);
            $resp = $ans ? self::decode($ans->response) : null;
            if ($question->type === 'short_text') {
                // An empty written answer gets 0 at once; a written one waits for the teacher.
                $row = $resp === null ? ['is_correct' => 0, 'points_awarded' => 0] : ['is_correct' => null, 'points_awarded' => null];
            } else {
                $ok = self::isCorrect($question, $resp);
                $row = ['is_correct' => $ok ? 1 : 0, 'points_awarded' => $ok ? $question->points : 0];
            }
            DB::table('edu_quiz_answers')->upsert([['attempt_id' => $attemptId, 'question_id' => $question->id, 'response' => $ans?->response] + $row], ['attempt_id', 'question_id'], array_keys($row));
        }
        DB::table('edu_quiz_attempts')->where('id', $attemptId)->update(['status' => 'submitted', 'submitted_at' => self::now()]);
        self::rescore($attemptId);
        $att = DB::table('edu_quiz_attempts')->where('id', $attemptId)->first();
        if ($att) {
            $isWaiting = (bool) $att->needs_grading;
            Notifications::notifyEduStudentSubmitted($attemptId, (int) $att->user_id, (int) $att->quiz_id, $isWaiting);
            if ($isWaiting) {
                Notifications::notifyEduQuizSubmitted((int) $att->quiz_id, $attemptId, (int) $att->user_id);
            }
        }
    }

    private static function rescore(int $attemptId): void
    {
        $a = DB::table('edu_quiz_attempts')->where('id', $attemptId)->first();
        if (! $a) return;

        if (! empty($a->question_ids)) {
            $qids = is_array($a->question_ids) ? $a->question_ids : json_decode($a->question_ids, true);
            $questions = DB::table('edu_quiz_questions')->whereIn('id', $qids ?: [0])->get();
        } else {
            $questions = DB::table('edu_quiz_questions')->where('quiz_id', $a->quiz_id)->get();
        }

        $answers = DB::table('edu_quiz_answers')->where('attempt_id', $attemptId)->get()->keyBy('question_id');
        $auto = 0.0;
        $manual = 0.0;
        $waiting = false;

        foreach ($questions as $q) {
            $ans = $answers->get($q->id);
            if ($q->type === 'short_text') {
                if (! $ans || $ans->points_awarded === null) {
                    $waiting = true;
                } else {
                    $manual += Num::n($ans->points_awarded);
                }
            } else {
                if ($ans && $ans->points_awarded !== null) {
                    $auto += Num::n($ans->points_awarded);
                }
            }
        }

        $newStatus = $waiting ? 'pending_grading' : 'graded';
        $totalScore = $auto + $manual;
        $maxScore = (float) ($a->max_score ?? DB::table('edu_quizzes')->where('id', $a->quiz_id)->value('total_points') ?: 100);
        $scorePercent = $maxScore > 0 ? round(($totalScore / $maxScore) * 100, 2) : 0.0;

        $update = [
            'auto_score' => $auto,
            'manual_score' => $manual,
            'needs_grading' => $waiting ? 1 : 0,
            'status' => $newStatus,
        ];
        DB::table('edu_quiz_attempts')->where('id', $attemptId)->update($update);

        if (! $waiting && $a->status === 'pending_grading') {
            $quiz = DB::table('edu_quizzes')->where('id', $a->quiz_id)->first();
            if (! $quiz || ! $quiz->results_release_at || Dates::sql($quiz->results_release_at) <= self::now()) {
                Notifications::notifyEduGradingComplete($attemptId, (int) $a->user_id, (int) $a->quiz_id);
            }
        }
    }

    /** Attempts whose time is over are submitted with what was saved (checked lazily, no cron). */
    private static function finalizeExpired(int $quizId, ?int $userId = null): void
    {
        $now = self::now();
        $q = DB::table('edu_quiz_attempts')->where(['quiz_id' => $quizId, 'status' => 'in_progress'])->whereNotNull('expires_at')->when($userId, fn ($x) => $x->where('user_id', $userId));
        foreach ($q->get() as $a) {
            if (self::expired($a, $now)) DB::transaction(fn () => self::finalize((int) $a->id));
        }
    }

    private static function total(object $a): float
    {
        return (float) Num::n($a->auto_score ?? 0) + (float) Num::n($a->manual_score ?? 0);
    }

    /** The attempt that counts: best or last, among finished ones. */
    private static function chosen(object $q, array $attempts): ?object
    {
        $done = array_values(array_filter($attempts, fn ($a) => $a->status !== 'in_progress'));
        if (! $done) return null;
        if ($q->scoring === 'last') return end($done);
        usort($done, fn ($x, $y) => self::total($y) <=> self::total($x) ?: $x->attempt_no <=> $y->attempt_no);
        return $done[0];
    }

    private static function attemptSummary(object $a): array
    {
        return [
            'id' => (int) $a->id, 'attempt_no' => (int) $a->attempt_no, 'status' => $a->status, 'started_at' => $a->started_at, 'submitted_at' => $a->submitted_at,
            'score' => $a->status === 'in_progress' ? null : self::total($a), 'max_score' => Num::n($a->max_score), 'needs_grading' => (bool) $a->needs_grading,
            'transferred_at' => $a->transferred_at,
        ];
    }

    /**
     * An attempt as the student (or teacher) sees it. Questions in a stable per-attempt order when
     * shuffled; correct answers / explanations only when [reveal]; scores only when allowed.
     */
    private static function attemptOut(object $q, object $a, bool $reveal, bool $teacher, ?int $userId = null): array
    {
        if (! empty($a->question_ids)) {
            $qids = is_array($a->question_ids) ? $a->question_ids : json_decode($a->question_ids, true);
            if (is_array($qids) && ! empty($qids)) {
                $rawQ = DB::table('edu_quiz_questions')->whereIn('id', $qids)->get()->keyBy('id');
                $questions = [];
                foreach ($qids as $qid) {
                    if ($rawQ->has($qid)) $questions[] = $rawQ->get($qid);
                }
            } else {
                $questions = DB::table('edu_quiz_questions')->where('quiz_id', $q->id)->orderBy('sort_order')->orderBy('id')->get()->all();
            }
        } else {
            $questions = DB::table('edu_quiz_questions')->where('quiz_id', $q->id)->orderBy('sort_order')->orderBy('id')->get()->all();
        }
        if ($q->shuffle && ! $teacher) {
            mt_srand((int) $a->id);
            shuffle($questions);
            mt_srand();
        }
        $answers = DB::table('edu_quiz_answers')->where('attempt_id', $a->id)->get()->keyBy('question_id');
        $finished = $a->status !== 'in_progress';
        $showScore = $teacher || self::scoreVisible($q, $a, (int) ($userId ?? $a->user_id));
        $now = self::now();

        $totalQuestions = count($questions);
        $correctCount = 0;
        foreach ($questions as $x) {
            $ans = $answers->get($x->id);
            if ($ans && (int) $ans->is_correct === 1) {
                $correctCount++;
            }
        }
        $scoreVal = $finished && $showScore ? self::total($a) : null;
        $maxScoreVal = Num::n($a->max_score ?: ($totalQuestions > 0 ? $totalQuestions : 100));
        $percentVal = ($scoreVal !== null && $maxScoreVal > 0) ? round(((float)$scoreVal / (float)$maxScoreVal) * 100, 2) : null;

        return [
            'id' => (int) $a->id, 'quiz_id' => (int) $q->id, 'attempt_no' => (int) $a->attempt_no, 'status' => $a->status,
            'started_at' => $a->started_at, 'expires_at' => $a->expires_at, 'submitted_at' => $a->submitted_at,
            'seconds_left' => ! $finished && $a->expires_at ? max(0, Dates::of($a->expires_at)->getTimestamp() - Dates::of($now)->getTimestamp()) : null,
            'server_time' => $now,
            'quiz' => ['id' => (int) $q->id, 'title' => $q->title, 'title_en' => $q->title_en ?? null, 'instructions' => $q->instructions, 'instructions_en' => $q->instructions_en ?? null, 'review_policy' => $q->review_policy, 'official' => $q->assessment_id !== null, 'max_attempts' => (int) $q->max_attempts],
            'score' => $scoreVal,
            'max_score' => $maxScoreVal,
            'score_percent' => $percentVal,
            'correct_answers' => $correctCount,
            'total_questions' => $totalQuestions,
            'score_hidden' => $finished && ! $showScore,
            'needs_grading' => (bool) $a->needs_grading,
            'answers_visible' => $reveal,
            'questions' => array_map(function ($x) use ($answers, $reveal, $teacher, $finished, $showScore) {
                $ans = $answers->get($x->id);
                $out = [
                    'id' => (int) $x->id, 'type' => $x->type, 'prompt' => $x->prompt, 'prompt_en' => $x->prompt_en ?? null, 'options' => self::decode($x->options) ?? [], 'points' => Num::n($x->points),
                    'response' => $ans ? self::decode($ans->response) : null,
                ];
                if ($reveal || $teacher) {
                    $out += ['answer' => self::decode($x->answer), 'explanation' => $x->explanation, 'explanation_en' => $x->explanation_en ?? null];
                }
                if ($finished && ($reveal || $teacher || $showScore)) {
                    $out += [
                        'is_correct' => $ans && $ans->is_correct !== null ? (bool) $ans->is_correct : null,
                        'points_awarded' => $ans && $ans->points_awarded !== null ? Num::n($ans->points_awarded) : null,
                        'feedback' => $ans?->feedback ?? null,
                    ];
                }
                return $out;
            }, $questions),
        ];
    }

    // ------------------------------------------------------------------ Question Banks & Draws (F12)
    public static function createBank(AuthContext $auth, int $subjectId, array $in): array
    {
        if (! EduLearning::canEditSubject($auth, $subjectId)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not edit this subject');
        }
        $title = trim((string) ($in['title'] ?? $in['name'] ?? ''));
        if (empty($title)) {
            throw ApiError::field('title', 'REQUIRED');
        }
        $row = [
            'subject_id' => $subjectId,
            'title' => $title,
            'created_by' => $auth->id,
            'created_at' => Dates::sql(Dates::now()),
            'updated_at' => Dates::sql(Dates::now()),
        ];
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_question_banks', 'category') && isset($in['category'])) {
            $row['category'] = $in['category'];
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_question_banks', 'difficulty') && isset($in['difficulty'])) {
            $row['difficulty'] = $in['difficulty'];
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_question_banks', 'description') && isset($in['description'])) {
            $row['description'] = $in['description'];
        }
        $id = DB::table('edu_question_banks')->insertGetId($row);
        return self::getBank($auth, $id);
    }

    public static function listBanks(AuthContext $auth, int $subjectId): array
    {
        if (! EduLearning::canEditSubject($auth, $subjectId)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not edit this subject');
        }
        return DB::table('edu_question_banks as b')
            ->where('b.subject_id', $subjectId)
            ->select('b.*', DB::raw('(SELECT COUNT(*) FROM edu_quiz_questions q WHERE q.bank_id = b.id) as question_count'))
            ->orderBy('b.title')
            ->get()->map(fn ($b) => [
                'id' => (int) $b->id,
                'subject_id' => (int) $b->subject_id,
                'title' => $b->title,
                'category' => $b->category ?? null,
                'difficulty' => $b->difficulty ?? null,
                'description' => $b->description ?? null,
                'question_count' => (int) $b->question_count,
                'created_at' => $b->created_at,
            ])->all();
    }

    public static function getBank(AuthContext $auth, int $bankId): array
    {
        $b = DB::table('edu_question_banks')->where('id', $bankId)->first();
        if (! $b) throw ApiError::notFound('BANK_NOT_FOUND', 'Question bank not found');
        if (! EduLearning::canEditSubject($auth, (int) $b->subject_id)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not edit this subject');
        }
        $questions = DB::table('edu_quiz_questions')->where('bank_id', $bankId)->orderBy('sort_order')->orderBy('id')->get()->map(fn ($x) => [
            'id' => (int) $x->id, 'type' => $x->type, 'prompt' => $x->prompt, 'options' => self::decode($x->options) ?? [],
            'answer' => self::decode($x->answer), 'explanation' => $x->explanation, 'points' => Num::n($x->points), 'sort_order' => (int) $x->sort_order,
        ])->all();
        return [
            'id' => (int) $b->id,
            'subject_id' => (int) $b->subject_id,
            'title' => $b->title,
            'category' => $b->category ?? null,
            'difficulty' => $b->difficulty ?? null,
            'description' => $b->description ?? null,
            'question_count' => count($questions),
            'questions' => $questions,
            'created_at' => $b->created_at,
        ];
    }

    public static function setBankQuestions(AuthContext $auth, int $bankId, array $questions): array
    {
        $b = DB::table('edu_question_banks')->where('id', $bankId)->first();
        if (! $b) throw ApiError::notFound('BANK_NOT_FOUND', 'Question bank not found');
        if (! EduLearning::canEditSubject($auth, (int) $b->subject_id)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not edit this subject');
        }
        DB::transaction(function () use ($bankId, $questions) {
            DB::table('edu_quiz_questions')->where('bank_id', $bankId)->delete();
            foreach (array_values($questions) as $i => $x) {
                [$options, $answer] = self::validateQuestion($x, $i);
                DB::table('edu_quiz_questions')->insert([
                    'bank_id' => $bankId, 'quiz_id' => null, 'type' => $x['type'], 'prompt' => $x['prompt'],
                    'options' => $options === null ? null : json_encode($options, JSON_UNESCAPED_UNICODE),
                    'answer' => $answer === null ? null : json_encode($answer, JSON_UNESCAPED_UNICODE),
                    'explanation' => $x['explanation'] ?? null,
                    'points' => $x['points'] ?? 1, 'sort_order' => $i + 1,
                ]);
            }
        });
        return self::getBank($auth, $bankId);
    }

    public static function deleteBank(AuthContext $auth, int $bankId): void
    {
        $b = DB::table('edu_question_banks')->where('id', $bankId)->first();
        if (! $b) throw ApiError::notFound('BANK_NOT_FOUND', 'Question bank not found');
        if (! EduLearning::canEditSubject($auth, (int) $b->subject_id)) {
            throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not edit this subject');
        }
        if (DB::table('edu_quiz_draws')->where('bank_id', $bankId)->exists()) {
            throw ApiError::conflict('HAS_RECORDS', 'Quizzes draw from this bank; remove draws first');
        }
        DB::table('edu_quiz_questions')->where('bank_id', $bankId)->delete();
        DB::table('edu_question_banks')->where('id', $bankId)->delete();
    }

    public static function setDraws(AuthContext $auth, int $quizId, array $draws): array
    {
        $q = self::quiz($quizId);
        Edu::assertTeachesCourse($auth, (int) $q->course_id);
        if (DB::table('edu_quiz_attempts')->where('quiz_id', $quizId)->exists()) {
            throw ApiError::conflict('QUIZ_HAS_ATTEMPTS', 'Students already took this quiz');
        }
        DB::transaction(function () use ($quizId, $draws) {
            DB::table('edu_quiz_draws')->where('quiz_id', $quizId)->delete();
            foreach ($draws as $d) {
                DB::table('edu_quiz_draws')->insert([
                    'quiz_id' => $quizId,
                    'bank_id' => (int) $d['bank_id'],
                    'count' => (int) ($d['count'] ?? 1),
                    'points_each' => Num::n($d['points_each'] ?? 1.00),
                    'created_at' => Dates::sql(Dates::now()),
                    'updated_at' => Dates::sql(Dates::now()),
                ]);
            }
        });
        return self::getDraws($auth, $quizId);
    }

    public static function getDraws(AuthContext $auth, int $quizId): array
    {
        $q = self::quiz($quizId);
        Edu::assertTeachesCourse($auth, (int) $q->course_id);
        return DB::table('edu_quiz_draws as d')
            ->join('edu_question_banks as b', 'b.id', '=', 'd.bank_id')
            ->where('d.quiz_id', $quizId)
            ->select('d.*', 'b.title as bank_title')
            ->get()->map(fn ($d) => [
                'id' => (int) $d->id,
                'quiz_id' => (int) $d->quiz_id,
                'bank_id' => (int) $d->bank_id,
                'bank_title' => $d->bank_title,
                'count' => (int) $d->count,
                'points_each' => (float) $d->points_each,
            ])->all();
    }
}
