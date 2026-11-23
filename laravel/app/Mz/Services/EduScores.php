<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Services\MemberIds;
use App\Mz\Support\Num;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class EduScores
{
    private static function checkPermission(AuthContext $auth): void
    {
        if (! $auth->can('education.reports') && ! $auth->can('education.manage') && ! $auth->isAdmin) {
            throw ApiError::forbidden('FORBIDDEN', 'Permission education.reports required');
        }
    }

    /**
     * Compute academic score and engagement score for students in a period.
     * Formula per Decision D8:
     * - Academic score = average percentage of the published course outcomes in the period.
     * - Engagement score = (completed accessible mandatory lessons ÷ accessible mandatory lessons) × 50%
     *                    + (submitted assignments ÷ assignments due) × 30%
     *                    + (quiz and exam attempts ÷ open quizzes and exams) × 20%.
     * Inaccessible activities don't lower anyone's score.
     */
    public static function forPeriod(
        AuthContext $auth,
        ?int $yearId = null,
        ?int $termId = null,
        ?int $classId = null,
        ?int $courseId = null,
        ?string $group = null
    ): array {
        self::checkPermission($auth);

        // Find relevant classes
        $classesQ = DB::table('edu_classes as c');
        if ($classId) $classesQ->where('c.id', $classId);
        if ($yearId) $classesQ->where('c.academic_year_id', $yearId);
        if ($termId) $classesQ->where('c.term_id', $termId);
        $classes = $classesQ->select('c.id', 'c.name', 'c.academic_year_id', 'c.term_id')->get()->keyBy('id');
        $classIds = $classes->keys()->all();
        if (empty($classIds) && ! $courseId) return [];

        // Find enrollments
        $enrQ = DB::table('edu_enrollments as e')
            ->join('users as u', 'u.id', '=', 'e.user_id')
            ->whereNull('u.deleted_at')
            ->whereIn('e.status', ['enrolled', 'active', 'retake']);

        if (! empty($classIds)) {
            $enrQ->whereIn('e.class_id', $classIds);
        }
        if ($group) {
            $enrQ->where('u.member_group', $group);
        }

        $students = $enrQ->select(
            'u.id as user_id',
            'u.full_name',
            'u.member_no',
            'u.member_group',
            'e.class_id'
        )->distinct()->get();

        // Get courses for classes
        $coursesQ = DB::table('edu_courses as co');
        if ($courseId) {
            $coursesQ->where('co.id', $courseId);
        } elseif (! empty($classIds)) {
            $coursesQ->whereIn('co.class_id', $classIds);
        }
        $courses = $coursesQ->get(['co.id', 'co.class_id', 'co.subject_id'])->groupBy('class_id');
        $allCourseIds = $coursesQ->pluck('co.id')->all();

        $now = Dates::sql(Dates::now());

        $scores = [];
        foreach ($students as $st) {
            $uid = (int) $st->user_id;
            $cid = (int) $st->class_id;
            $userCourses = ($courses[$cid] ?? collect())->pluck('id')->all();
            if ($courseId && ! in_array($courseId, $userCourses, true)) {
                $userCourses = in_array($courseId, $allCourseIds, true) ? [$courseId] : [];
            }
            if (empty($userCourses)) continue;

            // 1. Academic score: published outcomes in these courses
            $outcomeCol = Schema::hasColumn('edu_course_outcomes', 'percent') ? 'percent' : 'score_percent';
            $outcomes = DB::table('edu_course_outcomes')
                ->where('user_id', $uid)
                ->whereIn('course_id', $userCourses)
                ->whereNotNull($outcomeCol)
                ->get([$outcomeCol . ' as score_percent', 'result', 'status']);

            $outcomesCount = $outcomes->count();
            $academicScore = $outcomesCount > 0 ? Num::round1($outcomes->avg('score_percent')) : null;

            // 2. Engagement score:
            // a) Mandatory published lessons in student's subject curriculum
            $subjectIds = ($courses[$cid] ?? collect())->pluck('subject_id')->filter()->all();
            $mandLessonsQ = DB::table('edu_lessons as l')
                ->join('edu_units as un', 'un.id', '=', 'l.unit_id')
                ->whereIn('un.subject_id', $subjectIds ?: [0])
                ->where('l.status', 'published')
                ->where('l.is_mandatory', 1);
            $totalMandLessons = $mandLessonsQ->count();

            $completedMandLessons = 0;
            if ($totalMandLessons > 0) {
                $completedMandLessons = DB::table('edu_lesson_progress as lp')
                    ->join('edu_lessons as l', 'l.id', '=', 'lp.lesson_id')
                    ->join('edu_units as un', 'un.id', '=', 'l.unit_id')
                    ->where('lp.user_id', $uid)
                    ->where(function ($w) {
                        if (Schema::hasColumn('edu_lesson_progress', 'completed_at')) {
                            $w->whereNotNull('lp.completed_at');
                        } else {
                            $w->where('lp.completed', 1);
                        }
                    })
                    ->where('l.status', 'published')
                    ->where('l.is_mandatory', 1)
                    ->whereIn('un.subject_id', $subjectIds ?: [0])
                    ->count();
            }
            $lessonRatio = $totalMandLessons > 0 ? min(1.0, $completedMandLessons / $totalMandLessons) : 1.0;

            // b) Assignments: published assignments due
            $assignmentsDueQ = DB::table('edu_assignments')
                ->whereIn('course_id', $userCourses)
                ->where('status', 'published')
                ->where(function ($w) use ($now) {
                    if (Schema::hasColumn('edu_assignments', 'publish_at')) {
                        $w->whereNull('publish_at')->orWhere('publish_at', '<=', $now);
                    }
                })
                ->where(fn ($w) => $w->whereNull('due_at')->orWhere('due_at', '<=', $now));
            $totalAssignmentsDue = $assignmentsDueQ->count();

            $submittedAssignments = 0;
            if ($totalAssignmentsDue > 0) {
                $legacySubmittedIds = Schema::hasTable('edu_submissions')
                    ? DB::table('edu_submissions as s')
                        ->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')
                        ->where('s.user_id', $uid)
                        ->whereIn('a.course_id', $userCourses)
                        ->pluck('s.assignment_id')
                        ->all()
                    : [];

                $modernSubmittedIds = Schema::hasTable('edu_assignment_submissions')
                    ? DB::table('edu_assignment_submissions as eas')
                        ->join('edu_assignments as a', 'a.id', '=', 'eas.assignment_id')
                        ->where('eas.user_id', $uid)
                        ->whereIn('a.course_id', $userCourses)
                        ->pluck('eas.assignment_id')
                        ->all()
                    : [];

                $allSubmittedIds = array_unique(array_merge($legacySubmittedIds, $modernSubmittedIds));
                $submittedAssignments = count($allSubmittedIds);
            }
            $assignmentRatio = $totalAssignmentsDue > 0 ? min(1.0, $submittedAssignments / $totalAssignmentsDue) : 1.0;

            // c) Quizzes / exams: open quizzes in courses
            $quizzesOpenQ = DB::table('edu_quizzes')
                ->whereIn('course_id', $userCourses)
                ->where(function ($w) {
                    if (Schema::hasColumn('edu_quizzes', 'status')) {
                        $w->where('status', 'published');
                    }
                })
                ->where(function ($w) use ($now) {
                    if (Schema::hasColumn('edu_quizzes', 'opens_at')) {
                        $w->whereNull('opens_at')->orWhere('opens_at', '<=', $now);
                    } elseif (Schema::hasColumn('edu_quizzes', 'publish_at')) {
                        $w->whereNull('publish_at')->orWhere('publish_at', '<=', $now);
                    }
                })
                ->where(function ($w) use ($now) {
                    if (Schema::hasColumn('edu_quizzes', 'closes_at')) {
                        $w->whereNull('closes_at')->orWhere('closes_at', '>=', $now);
                    }
                });
            $totalQuizzesOpen = $quizzesOpenQ->count();

            $attemptedQuizzes = 0;
            if ($totalQuizzesOpen > 0) {
                $attemptedQuizzes = DB::table('edu_quiz_attempts as qa')
                    ->join('edu_quizzes as q', 'q.id', '=', 'qa.quiz_id')
                    ->where('qa.user_id', $uid)
                    ->whereIn('q.course_id', $userCourses)
                    ->distinct()
                    ->count('qa.quiz_id');
            }
            $quizRatio = $totalQuizzesOpen > 0 ? min(1.0, $attemptedQuizzes / $totalQuizzesOpen) : 1.0;

            $engagementScore = Num::round1(($lessonRatio * 50.0) + ($assignmentRatio * 30.0) + ($quizRatio * 20.0));

            $className = $classes[$cid]->name ?? '—';

            $scores[] = [
                'user_id' => $uid,
                'full_name' => $st->full_name,
                'member_id' => $st->member_no ? MemberIds::format($st->member_no, $st->member_group) : null,
                'class_id' => $cid,
                'class_name' => $className,
                'academic_score' => $academicScore,
                'outcomes_count' => $outcomesCount,
                'engagement_score' => $engagementScore,
                'mandatory_lessons_completed' => $completedMandLessons,
                'mandatory_lessons_total' => $totalMandLessons,
                'assignments_submitted' => $submittedAssignments,
                'assignments_due' => $totalAssignmentsDue,
                'quiz_attempts' => $attemptedQuizzes,
                'quizzes_open' => $totalQuizzesOpen,
                'breakdown' => [
                    'lessons' => [
                        'completed' => $completedMandLessons,
                        'accessible' => $totalMandLessons,
                        'rate' => Num::round1($lessonRatio * 100.0),
                    ],
                    'assignments' => [
                        'submitted' => $submittedAssignments,
                        'accessible' => $totalAssignmentsDue,
                        'rate' => Num::round1($assignmentRatio * 100.0),
                    ],
                    'quizzes' => [
                        'passed' => $attemptedQuizzes,
                        'accessible' => $totalQuizzesOpen,
                        'rate' => Num::round1($quizRatio * 100.0),
                    ],
                ],
            ];
        }

        return $scores;
    }

    /**
     * Aggregated education activity metrics for administrators.
     */
    public static function activityReport(AuthContext $auth, ?int $yearId = null, ?int $classId = null): array
    {
        self::checkPermission($auth);

        $classesQ = DB::table('edu_classes as c');
        if ($classId) $classesQ->where('c.id', $classId);
        if ($yearId) $classesQ->where('c.academic_year_id', $yearId);
        $classes = $classesQ->get(['c.id', 'c.name'])->keyBy('id');
        $classIds = $classes->keys()->all();

        $courses = DB::table('edu_courses as co')
            ->when(! empty($classIds), fn ($q) => $q->whereIn('co.class_id', $classIds))
            ->get(['co.id', 'co.class_id', 'co.subject_id']);
        $coursesByClass = $courses->groupBy('class_id');

        $activityList = [];
        $totalLessonOpens = 0;
        $totalLessonCompletions = 0;
        $totalSubmissions = 0;
        $totalQuizAttempts = 0;
        $totalCerts = 0;

        foreach ($classes as $cid => $classObj) {
            $classCourses = $coursesByClass->get($cid, collect());
            $cCourseIds = $classCourses->pluck('id')->all();
            $cSubjectIds = $classCourses->pluck('subject_id')->filter()->all();

            $lessonOpens = 0;
            $lessonCompletions = 0;
            if (!empty($cSubjectIds)) {
                $lessonOpens = DB::table('edu_lesson_progress as lp')
                    ->join('edu_lessons as l', 'l.id', '=', 'lp.lesson_id')
                    ->join('edu_units as un', 'un.id', '=', 'l.unit_id')
                    ->whereIn('un.subject_id', $cSubjectIds)
                    ->count();

                $lessonCompletions = DB::table('edu_lesson_progress as lp')
                    ->join('edu_lessons as l', 'l.id', '=', 'lp.lesson_id')
                    ->join('edu_units as un', 'un.id', '=', 'l.unit_id')
                    ->whereIn('un.subject_id', $cSubjectIds)
                    ->where(function ($w) {
                        if (Schema::hasColumn('edu_lesson_progress', 'completed_at')) {
                            $w->whereNotNull('lp.completed_at');
                        } else {
                            $w->where('lp.completed', 1);
                        }
                    })
                    ->count();
            }

            $submissions = 0;
            $quizAttempts = 0;
            $certs = 0;
            if (!empty($cCourseIds)) {
                $submissions = DB::table('edu_submissions as s')
                    ->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')
                    ->whereIn('a.course_id', $cCourseIds)
                    ->count();

                $quizAttempts = DB::table('edu_quiz_attempts as qa')
                    ->join('edu_quizzes as q', 'q.id', '=', 'qa.quiz_id')
                    ->whereIn('q.course_id', $cCourseIds)
                    ->count();

                $certs = DB::table('edu_certificates')
                    ->whereIn('course_id', $cCourseIds)
                    ->where('status', 'valid')
                    ->count();
            }

            $activityList[] = [
                'class_id' => $cid,
                'class_name' => $classObj->name,
                'lesson_opens' => $lessonOpens,
                'lesson_completions' => $lessonCompletions,
                'assignment_submissions' => $submissions,
                'quiz_attempts' => $quizAttempts,
                'certificates_issued' => $certs,
            ];

            $totalLessonOpens += $lessonOpens;
            $totalLessonCompletions += $lessonCompletions;
            $totalSubmissions += $submissions;
            $totalQuizAttempts += $quizAttempts;
            $totalCerts += $certs;
        }

        return [
            'summary' => [
                'classes_count' => count($classes),
                'courses_count' => count($courses),
                'lesson_opens' => $totalLessonOpens,
                'lesson_completions' => $totalLessonCompletions,
                'assignment_submissions' => $totalSubmissions,
                'quiz_attempts' => $totalQuizAttempts,
                'certificates_issued' => $totalCerts,
            ],
            'activity' => $activityList,
        ];
    }

    /**
     * Complete score sheet and educational activity for a single student (Requirement 2).
     * Accessible by the student themselves, or authorized educators/admins.
     */
    public static function forStudent(AuthContext $auth, int $studentId): array
    {
        $isSelf = (int) $auth->id === $studentId;
        if (! $isSelf && ! $auth->can('education.reports') && ! $auth->can('education.manage') && ! $auth->isAdmin) {
            $enrolledClasses = DB::table('edu_enrollments')->where('user_id', $studentId)->pluck('class_id')->all();
            $teachesStudent = false;
            if ($enrolledClasses) {
                $hasTeacherCol = Schema::hasColumn('edu_courses', 'teacher_user_id');
                if (Schema::hasTable('edu_course_teachers')) {
                    $teachesStudent = DB::table('edu_courses as c')
                        ->leftJoin('edu_course_teachers as ct', 'ct.course_id', '=', 'c.id')
                        ->whereIn('c.class_id', $enrolledClasses)
                        ->where(fn ($q) => ($hasTeacherCol ? $q->where('c.teacher_user_id', $auth->id) : $q)
                            ->orWhere(fn ($q2) => $q2->where('ct.user_id', $auth->id)->where('ct.status', 'active')))
                        ->exists();
                } elseif ($hasTeacherCol) {
                    $teachesStudent = DB::table('edu_courses as c')
                        ->whereIn('c.class_id', $enrolledClasses)
                        ->where('c.teacher_user_id', $auth->id)
                        ->exists();
                }

                if (! $teachesStudent && Schema::hasTable('edu_class_staff')) {
                    $teachesStudent = DB::table('edu_class_staff')
                        ->whereIn('class_id', $enrolledClasses)
                        ->where('user_id', $auth->id)
                        ->exists();
                }
            }
            if (! $teachesStudent) {
                throw ApiError::forbidden('FORBIDDEN', 'You cannot view this student\'s scores');
            }
        }

        $user = DB::table('users')->where('id', $studentId)->whereNull('deleted_at')->first(['id', 'full_name', 'member_no', 'member_group', 'phone']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'Student not found');

        // 1. Enrolled classes
        $enrollments = DB::table('edu_enrollments as e')
            ->join('edu_classes as c', 'c.id', '=', 'e.class_id')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
            ->leftJoin('edu_terms as t', 't.id', '=', 'c.term_id')
            ->where('e.user_id', $studentId)
            ->select('e.*', 'c.name as class_name', 'y.name as academic_year_name', 't.name as term_name')
            ->orderByDesc('e.id')
            ->get();

        // 2. Finalized subject / course marks
        $courseNameCol = Schema::hasColumn('edu_courses', 'name') ? 'c.name' : 'c.title';
        $outcomeCol = Schema::hasColumn('edu_course_outcomes', 'percent') ? 'percent' : 'score_percent';
        $courseOutcomes = DB::table('edu_course_outcomes as co')
            ->join('edu_courses as c', 'c.id', '=', 'co.course_id')
            ->where('co.user_id', $studentId)
            ->select('co.*', DB::raw("{$courseNameCol} as course_title"), 'co.' . $outcomeCol . ' as final_percent')
            ->orderBy(DB::raw($courseNameCol))
            ->get();

        // 3. Quiz & Exam attempts with strict pending manual grading masking
        $now = Dates::sql(Dates::now());
        $attempts = DB::table('edu_quiz_attempts as a')
            ->join('edu_quizzes as q', 'q.id', '=', 'a.quiz_id')
            ->leftJoin('edu_courses as c', 'c.id', '=', 'q.course_id')
            ->where('a.user_id', $studentId)
            ->select(
                'a.id as attempt_id',
                'a.quiz_id',
                'a.attempt_no',
                'a.status',
                'a.auto_score',
                'a.manual_score',
                'a.max_score as attempt_max_score',
                'a.question_ids',
                'a.needs_grading',
                'a.started_at',
                'a.submitted_at',
                'a.expires_at',
                'q.title as quiz_title',
                'q.title_en as quiz_title_en',
                DB::raw((Schema::hasColumn('edu_quizzes', 'total_points') ? 'q.total_points' : 'NULL') . ' as quiz_max_score'),
                'q.results_release_at',
                'q.review_policy',
                DB::raw("{$courseNameCol} as course_title")
            )
            ->orderByDesc('a.id')
            ->get();

        $processedAttempts = [];
        foreach ($attempts as $att) {
            $isPendingGrading = (bool) $att->needs_grading || $att->status === 'pending_grading';
            $isResultsReleased = empty($att->results_release_at) || Dates::sql($att->results_release_at) <= $now;

            $shouldWithhold = $isPendingGrading || ! $isResultsReleased;

            $qids = ! empty($att->question_ids) ? (is_array($att->question_ids) ? $att->question_ids : json_decode($att->question_ids, true)) : [];
            $totalQuestions = is_array($qids) && ! empty($qids) ? count($qids) : (int) DB::table('edu_quiz_questions')->where('quiz_id', $att->quiz_id)->count();

            // Maximum score: if attempt or quiz specifies a max_score, use it; otherwise use the total questions count
            $maxScore = (float) ($att->quiz_max_score ?: ($att->attempt_max_score ?: ($totalQuestions > 0 ? $totalQuestions : 100)));
            $rawTotal = (float) ($att->auto_score ?? 0) + (float) ($att->manual_score ?? 0);
            $calculatedPercent = $maxScore > 0 ? round(($rawTotal / $maxScore) * 100, 2) : 0.0;

            // Correct answers count from edu_quiz_answers
            $correctCount = (int) DB::table('edu_quiz_answers')
                ->where('attempt_id', $att->attempt_id)
                ->where('is_correct', 1)
                ->count();

            $scoreDisplay = null;
            $percentDisplay = null;
            if (! $shouldWithhold && $att->status !== 'in_progress') {
                $scoreDisplay = Num::n($rawTotal);
                $percentDisplay = Num::n($calculatedPercent);
            }

            $feedbacks = DB::table('edu_quiz_answers')
                ->where('attempt_id', $att->attempt_id)
                ->whereNotNull('feedback')
                ->where('feedback', '<>', '')
                ->pluck('feedback')
                ->all();

            $processedAttempts[] = [
                'id' => (int) $att->attempt_id,
                'quiz_id' => (int) $att->quiz_id,
                'attempt_no' => (int) $att->attempt_no,
                'quiz_title' => $att->quiz_title,
                'quiz_title_en' => $att->quiz_title_en,
                'course_title' => $att->course_title,
                'status' => $att->status,
                'started_at' => $att->started_at,
                'submitted_at' => $att->submitted_at,
                'pending_grading' => $isPendingGrading,
                'results_released' => $isResultsReleased,
                'results_release_at' => $att->results_release_at,
                'score' => $scoreDisplay,
                'score_percent' => $percentDisplay,
                'max_score' => Num::n($maxScore),
                'correct_answers' => $correctCount,
                'total_questions' => $totalQuestions,
                'notice' => $isPendingGrading
                    ? 'Short-answer questions awaiting grading by teacher'
                    : (! $isResultsReleased ? 'Results will be released at ' . $att->results_release_at : null),
                'feedbacks' => $shouldWithhold ? [] : $feedbacks,
            ];
        }

        // 4. Learning progress (lessons completed)
        $completionsCount = DB::table('edu_lesson_progress')->where('user_id', $studentId)->whereNotNull('completed_at')->count();
        $recentCompletions = DB::table('edu_lesson_progress as lc')
            ->join('edu_lessons as l', 'l.id', '=', 'lc.lesson_id')
            ->leftJoin('edu_units as u', 'u.id', '=', 'l.unit_id')
            ->leftJoin('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->where('lc.user_id', $studentId)
            ->whereNotNull('lc.completed_at')
            ->select('lc.completed_at', 'l.title as lesson_title', 'u.title as unit_title', 's.name as subject_name')
            ->orderByDesc('lc.completed_at')
            ->limit(10)
            ->get();

        // 5. Activity history
        $timeline = [];
        foreach ($processedAttempts as $pa) {
            if ($pa['submitted_at']) {
                $timeline[] = [
                    'type' => 'quiz_submission',
                    'title' => "ፈተና ተጠናቆ ተልኳል: {$pa['quiz_title']}",
                    'description' => $pa['pending_grading'] ? 'እርምት በመጠበቅ ላይ ያለ' : "ውጤት: {$pa['score']} / {$pa['max_score']}",
                    'timestamp' => $pa['submitted_at'],
                ];
            }
        }
        foreach ($recentCompletions as $rc) {
            $timeline[] = [
                'type' => 'lesson_completion',
                'title' => "ትምህርት ተጠናቋል: {$rc->lesson_title}",
                'description' => "{$rc->subject_name} • {$rc->unit_title}",
                'timestamp' => $rc->completed_at,
            ];
        }
        foreach ($enrollments as $enr) {
            $timeline[] = [
                'type' => 'enrollment',
                'title' => "ክፍል ምደባ: {$enr->class_name}",
                'description' => "{$enr->academic_year_name} ({$enr->status})",
                'timestamp' => $enr->created_at ?? Dates::sql(Dates::now()),
            ];
        }
        usort($timeline, fn ($a, $b) => strcmp($b['timestamp'], $a['timestamp']));

        return [
            'student' => [
                'id' => (int) $user->id,
                'full_name' => $user->full_name,
                'member_id' => MemberIds::format($user->member_no, $user->member_group),
                'phone' => $user->phone,
            ],
            'enrollments' => $enrollments->all(),
            'course_outcomes' => $courseOutcomes->all(),
            'quiz_attempts' => $processedAttempts,
            'learning_progress' => [
                'completed_lessons_count' => $completionsCount,
                'recent_completions' => $recentCompletions->all(),
            ],
            'activity_history' => array_slice($timeline, 0, 30),
        ];
    }
}
