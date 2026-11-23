<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The ትምህርት home in one request: the blocks of every responsibility the member really has
 * (student, teacher, attendance taker, registrar, content editor, education administrator), each
 * computed from the records — no sample or invented numbers. A block the member has no part in is
 * null / empty, so the app shows a helpful empty state instead.
 */
final class EduDashboard
{
    public static function forUser(AuthContext $auth): array
    {
        $cacheEnabled = config('edu.cache_dashboard', env('CACHE_EDU_DASHBOARD', true));
        if (! $cacheEnabled) {
            return self::computeForUser($auth);
        }

        $userId = $auth->id;
        $userVer = Cache::get("edu:dashboard:user:{$userId}:ver", 1);
        $permHash = md5(json_encode($auth->permissions) . '_' . ($auth->tokenVersion ?? 1) . '_' . ($auth->isAdmin ? 1 : 0));
        $cacheKey = "edu:dashboard:user:{$userId}:v{$userVer}:{$permHash}";

        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $lock = Cache::lock("lock:{$cacheKey}", 10);
            return $lock->block(5, function () use ($cacheKey, $auth) {
                $cached = Cache::get($cacheKey);
                if ($cached !== null) {
                    return $cached;
                }
                $data = self::computeForUser($auth);
                Cache::put($cacheKey, $data, 600); // 10 minutes TTL
                return $data;
            });
        } catch (\Throwable $e) {
            // Fallback gracefully without atomic lock if store does not support locking or contention times out
            $data = self::computeForUser($auth);
            try {
                Cache::put($cacheKey, $data, 600);
            } catch (\Throwable) {}
            return $data;
        }
    }

    public static function invalidateUserDashboard(int $userId): void
    {
        try {
            $ver = (int) Cache::get("edu:dashboard:user:{$userId}:ver", 1);
            Cache::put("edu:dashboard:user:{$userId}:ver", $ver + 1, 86400 * 30);
        } catch (\Throwable) {
            Cache::put("edu:dashboard:user:{$userId}:ver", time(), 86400 * 30);
        }
    }

    public static function computeForUser(AuthContext $auth): array
    {
        $overview = Edu::overview($auth);
        $courseIds = Edu::myCourseIds($auth->id);
        $teachingIds = Edu::myTeachingCourseIds($auth->id);
        $isAdmin = $auth->can('education.manage');
        $isEditor = EduLearning::isEditor($auth);
        $assignedGrades = EduLearning::studentAssignedGrades($auth->id);
        $mySubjects = EduLearning::studentAssignedClassSubjects($auth->id);

        if (empty($mySubjects) && ($isAdmin || $auth->isAdmin || $isEditor)) {
            $adminSubjects = EduLearning::subjects($auth, null);
            $mySubjects = array_map(function ($s) {
                return $s + [
                    'assigned_grade' => 7,
                    'grade' => 7,
                    'enrolled' => true,
                    'can_open' => true,
                ];
            }, $adminSubjects);
            if (empty($assignedGrades)) {
                $assignedGrades = [7];
            }
        }

        return [
            'featured' => EduLearning::featured($auth),
            'categories' => EduLearning::categories($auth),
            'subjects' => EduLearning::subjects($auth, null),
            'my_subjects' => $mySubjects,
            'assigned_grades' => $assignedGrades,
            'continue' => EduLearning::continueLearning($auth),
            'books' => Schema::hasTable('items') ? (Library::books($auth, ['domain' => 'timhirt'], ['page' => 1, 'limit' => 6])['items'] ?? []) : [],
            'classes' => $overview['classes'],
            'next_sessions' => $overview['next_sessions'],
            'open_registration' => $overview['open_registration'],
            'student' => $courseIds || $overview['classes'] ? self::student($auth, $overview['classes'], $courseIds) : null,
            'teaching' => $teachingIds ? self::teaching($overview['teaching'], $teachingIds) : null,
            'attendance_classes' => $overview['attendance_classes'],
            'admin' => $isAdmin ? self::admin() : null,
            'roles' => [
                'student' => (bool) $courseIds,
                'teacher' => (bool) $teachingIds,
                'attendance_taker' => (bool) $overview['attendance_classes'],
                'registrar' => $auth->can('education.register') || $isAdmin,
                'content_editor' => EduLearning::isEditor($auth),
                'admin' => $isAdmin,
                'author' => EduLearning::isEditor($auth) || (bool) EduLearning::teachingSubjectIds($auth->id),
            ],
        ];
    }

    private static function student(AuthContext $auth, array $classes, array $courseIds): array
    {
        $now = Dates::sql(Dates::now());
        // Assignments of the subjects taken: not yet submitted, newest deadline first (overdue kept a week).
        $weekAgo = Dates::sql(Dates::of($now)->modify('-7 days'));
        $assignments = $courseIds ? DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->whereIn('a.course_id', $courseIds)
            ->where(fn ($w) => $w->whereNull('a.due_at')->orWhere('a.due_at', '>=', $weekAgo))
            ->select('a.id', 'a.title', 'a.due_at', 'a.course_id', 'a.is_group', 'co.name as course_name', 'co.class_id')
            ->orderByRaw('a.due_at IS NULL')->orderBy('a.due_at')->limit(40)->get() : collect();
        $groups = DB::table('edu_group_members as gm')->join('edu_groups as g', 'g.id', '=', 'gm.group_id')->where('gm.user_id', $auth->id)->pluck('g.id', 'g.course_id')->all();
        $due = [];
        foreach ($assignments as $a) {
            $g = $groups[$a->course_id] ?? null;
            $hasSubmission = (Schema::hasTable('edu_assignment_submissions')
                && DB::table('edu_assignment_submissions')->where(['assignment_id' => $a->id, 'user_id' => $auth->id])->exists())
                || (Schema::hasTable('edu_submissions')
                && DB::table('edu_submissions')->where('assignment_id', $a->id)
                    ->where(fn ($w) => $a->is_group && $g ? $w->where('group_id', $g)->orWhere('user_id', $auth->id) : $w->where('user_id', $auth->id))->exists());
            if ($hasSubmission) continue;
            $due[] = ['id' => (int) $a->id, 'title' => $a->title, 'due_at' => $a->due_at, 'course_id' => (int) $a->course_id, 'course_name' => $a->course_name, 'class_id' => (int) $a->class_id,
                'overdue' => $a->due_at !== null && Dates::sql($a->due_at) < $now];
            if (count($due) >= 10) break;
        }
        $quizzes = array_values(array_filter(EduQuizzes::mine($auth), fn ($q) => $q['availability'] !== 'closed' && ($q['attempts_left'] > 0 || $q['in_progress_attempt_id'])));
        $attendance = [];
        foreach ($classes as $c) {
            if (! empty($c['added_subjects_only'])) continue;
            $s = Edu::attendanceSummary((int) $c['id'], $auth->id);
            $attendance[] = ['class_id' => (int) $c['id'], 'class_name' => $c['name'], 'rate' => $s['rate'], 'total' => $s['total'], 'present' => $s['present'], 'late' => $s['late'], 'absent' => $s['absent'], 'excused' => $s['excused']];
        }
        // Only published marks — never drafts or marks under review.
        $results = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->where(['s.user_id' => $auth->id, 's.status' => 'published'])->whereNotNull('s.score')
            ->orderByDesc('s.published_at')->limit(5)
            ->get(['a.id as assessment_id', 'a.title', 'a.max_score', 's.score', 's.published_at', 'co.id as course_id', 'co.name as course_name', 'co.class_id'])
            ->map(fn ($r) => ['assessment_id' => (int) $r->assessment_id, 'title' => $r->title, 'score' => Num::n($r->score), 'max_score' => Num::n($r->max_score),
                'course_id' => (int) $r->course_id, 'course_name' => $r->course_name, 'class_id' => (int) $r->class_id, 'published_at' => $r->published_at])->all();
        // Academic period (F1)
        $primaryClassId = ! empty($classes) ? (int) $classes[0]['id'] : null;
        $classRow = $primaryClassId ? DB::table('edu_classes')->where('id', $primaryClassId)->first() : null;
        $yearRow = $classRow && $classRow->academic_year_id ? DB::table('edu_academic_years')->where('id', $classRow->academic_year_id)->first() : DB::table('edu_academic_years')->where('is_current', 1)->first();
        $termRow = $classRow && $classRow->term_id ? DB::table('edu_terms')->where('id', $classRow->term_id)->first() : null;
        $levelRow = $classRow && $classRow->level_id ? DB::table('edu_levels')->where('id', $classRow->level_id)->first() : null;

        $academicPeriod = null;
        if ($yearRow && (! empty($yearRow->name) || ((int) ($yearRow->eth_year ?? 0) > 1900))) {
            $ethYear = (int) ($yearRow->eth_year ?? 0);
            $yearName = $yearRow->name ?: ($ethYear > 1900 ? "{$ethYear} ዓ.ም" : '');
            $termName = $termRow ? $termRow->name : ($classRow->term ?? null);
            $levelName = $levelRow ? $levelRow->name : ($classRow && $classRow->level_id ? "{$classRow->level_id}ኛ ክፍል" : null);

            $academicPeriod = [
                'year_id' => (int) $yearRow->id,
                'year_name' => $yearName,
                'eth_year' => $ethYear > 1900 ? $ethYear : null,
                'is_current' => (bool) $yearRow->is_current,
                'term_id' => $termRow ? (int) $termRow->id : null,
                'term_name' => $termName,
                'level_id' => $levelRow ? (int) $levelRow->id : ($classRow->level_id ?? null),
                'level_name' => $levelName,
            ];
        }

        // Outcomes (F10), retakes (F11), certificates (F13)
        $outcomes = EduOutcomes::forStudent($auth);
        $retakes = EduRetakes::list($auth, ['user_id' => $auth->id]);
        $certificates = EduCertificates::myCertificates($auth->id);

        // Overall learning progress calculation for student dashboard card
        $subjects = EduLearning::subjects($auth, null);
        $enrolledSubjects = array_values(array_filter($subjects, fn ($s) => !empty($s['enrolled']) || ((int) ($s['my_progress']['completed'] ?? 0)) > 0));
        $totalCourses = count($enrolledSubjects) ?: count($classes);
        $completedCourses = 0;
        $totalLessons = 0;
        $completedLessons = 0;
        foreach ($enrolledSubjects as $s) {
            $comp = (int) ($s['my_progress']['completed'] ?? 0);
            $tot = (int) ($s['my_progress']['total'] ?? 0);
            $totalLessons += $tot;
            $completedLessons += $comp;
            if ($tot > 0 && $comp >= $tot) {
                $completedCourses++;
            }
        }
        $overallPercent = $totalLessons > 0 ? (int) round(($completedLessons / $totalLessons) * 100) : 0;

        return [
            'academic_period' => $academicPeriod,
            'overall_progress' => [
                'percent' => $overallPercent,
                'completed_courses' => $completedCourses,
                'total_courses' => $totalCourses,
                'completed_lessons' => $completedLessons,
                'total_lessons' => $totalLessons,
            ],
            'assignments_due' => $due,
            'quizzes' => array_slice($quizzes, 0, 10),
            'attendance' => $attendance,
            'results' => $results,
            'outcomes' => $outcomes,
            'retakes' => $retakes,
            'certificates' => $certificates,
            'subject_count' => count($courseIds),
        ];
    }

    private static function teaching(array $courses, array $teachingIds): array
    {
        $ungradedLegacy = Schema::hasTable('edu_submissions')
            ? DB::table('edu_submissions as s')->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')->whereIn('a.course_id', $teachingIds)->whereNull('s.graded_at')->count()
            : 0;
        $ungradedModern = Schema::hasTable('edu_assignment_submissions')
            ? DB::table('edu_assignment_submissions as s')->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')->whereIn('a.course_id', $teachingIds)->whereNull('s.released_at')->whereNull('s.score')->count()
            : 0;
        $ungraded = max($ungradedLegacy, $ungradedModern);
        $rejected = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->whereIn('a.course_id', $teachingIds)->where('s.status', 'rejected')->count();
        $drafts = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->whereIn('a.course_id', $teachingIds)->where('s.status', 'draft')->whereNotNull('s.score')->count();
        $quizGrading = DB::table('edu_quiz_attempts as qa')->join('edu_quizzes as q', 'q.id', '=', 'qa.quiz_id')->whereIn('q.course_id', $teachingIds)->where('qa.needs_grading', 1)->count();
        return [
            'courses' => $courses,
            'submissions_to_grade' => $ungraded,
            'marks_rejected' => $rejected,
            'marks_draft' => $drafts,
            'quiz_answers_to_grade' => $quizGrading,
        ];
    }

    private static function admin(): array
    {
        return [
            'marks_submitted' => DB::table('edu_scores')->where('status', 'submitted')->distinct()->count('assessment_id'),
            'marks_approved_unpublished' => DB::table('edu_scores')->where('status', 'approved')->distinct()->count('assessment_id'),
            'requests_pending' => DB::table('edu_requests')->where('status', 'pending')->count(),
            'complaints_open' => DB::table('edu_complaints')->whereIn('status', ['submitted', 'under_review', 'awaiting_information', 'escalated'])->count(),
            'classes_active' => DB::table('edu_classes')->where('status', 'active')->count(),
            'subjects_unlinked' => DB::table('edu_courses as co')->join('edu_classes as c', 'c.id', '=', 'co.class_id')->where('c.status', 'active')->whereNull('co.subject_id')->count(),
        ];
    }

    /** Progress page: comprehensive student progress dashboard data */
    public static function progress(AuthContext $auth): array
    {
        $overview = Edu::overview($auth);
        $classes = [];
        $attRateSum = 0;
        $attCount = 0;

        foreach ($overview['classes'] as $c) {
            $r = Edu::myResults($auth, (int) $c['id']);
            $classes[] = ['class' => $c, 'attendance' => $r['attendance'], 'courses' => $r['courses']];
            if (! empty($r['attendance']['rate'])) {
                $attRateSum += (float) $r['attendance']['rate'];
                $attCount++;
            }
        }
        $subjects = array_values(array_filter(EduLearning::subjects($auth, null), fn ($s) => $s['my_progress']['completed'] > 0 || $s['enrolled']));
        if (empty($subjects) && ($auth->isAdmin || $auth->can('education.manage') || EduLearning::isEditor($auth))) {
            $subjects = EduLearning::subjects($auth, null);
        }

        // Total lessons completed
        $totalLessonsCompleted = (int) DB::table('edu_lesson_progress')
            ->where('user_id', $auth->id)
            ->whereNotNull('completed_at')
            ->count();

        // Active courses
        $activeCourseIds = Edu::myCourseIds($auth->id);
        $activeCoursesCount = count($activeCourseIds);

        // Pending assignments
        $now = Dates::sql(Dates::now());
        $weekAgo = Dates::sql(Dates::of($now)->modify('-7 days'));
        $assignments = $activeCourseIds ? DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->whereIn('a.course_id', $activeCourseIds)
            ->where(fn ($w) => $w->whereNull('a.due_at')->orWhere('a.due_at', '>=', $weekAgo))
            ->select('a.id', 'a.title', 'a.due_at', 'a.course_id', 'a.is_group', 'co.name as course_name', 'co.class_id')
            ->orderByRaw('a.due_at IS NULL')->orderBy('a.due_at')->limit(30)->get() : collect();

        $groups = DB::table('edu_group_members as gm')->join('edu_groups as g', 'g.id', '=', 'gm.group_id')->where('gm.user_id', $auth->id)->pluck('g.id', 'g.course_id')->all();
        $pendingAssignments = [];
        foreach ($assignments as $a) {
            $g = $groups[$a->course_id] ?? null;
            $sub = DB::table('edu_submissions')->where('assignment_id', $a->id)
                ->where(fn ($w) => $a->is_group && $g ? $w->where('group_id', $g)->orWhere('user_id', $auth->id) : $w->where('user_id', $auth->id))->first(['id', 'graded_at']);
            if ($sub) continue;
            $pendingAssignments[] = [
                'id' => (int) $a->id,
                'title' => $a->title,
                'due_at' => $a->due_at,
                'course_id' => (int) $a->course_id,
                'course_name' => $a->course_name,
                'class_id' => (int) $a->class_id,
                'overdue' => $a->due_at !== null && Dates::sql($a->due_at) < $now,
            ];
            if (count($pendingAssignments) >= 10) break;
        }

        // Overall progress percentage
        $totalEligibleLessons = 0;
        $doneLessons = 0;
        $completedCoursesCount = 0;
        $totalCoursesCount = count($subjects);
        $highestScorePct = 0;

        foreach ($subjects as $s) {
            $comp = (int) ($s['my_progress']['completed'] ?? 0);
            $tot = (int) ($s['my_progress']['total'] ?? 0);
            $doneLessons += $comp;
            $totalEligibleLessons += $tot;
            if ($tot > 0 && $comp >= $tot) {
                $completedCoursesCount++;
            }
        }

        // Check published scores and quizzes for highest score
        $quizzes = array_values(array_filter(EduQuizzes::mine($auth), fn ($q) => $q['attempts_used'] > 0));
        foreach ($quizzes as $q) {
            $score = (float) ($q['my_score'] ?? 0);
            $max = (float) ($q['my_max_score'] ?? $q['max_score'] ?? 0);
            if ($max > 0) {
                $pct = ($score / $max) * 100;
                if ($pct > $highestScorePct) $highestScorePct = $pct;
            }
        }
        foreach ($classes as $cl) {
            foreach ($cl['courses'] as $co) {
                if (isset($co['total_percent']) && is_numeric($co['total_percent'])) {
                    $pct = (float) $co['total_percent'];
                    if ($pct > $highestScorePct) $highestScorePct = $pct;
                }
            }
        }

        $overallPct = $totalEligibleLessons > 0 ? (int) round(($doneLessons / $totalEligibleLessons) * 100) : 0;

        // Summary
        $summary = [
            'completed_lessons' => $totalLessonsCompleted,
            'active_courses' => $activeCoursesCount ?: count($subjects),
            'pending_assignments' => count($pendingAssignments),
            'overall_percent' => $overallPct,
            'completed_courses' => $completedCoursesCount,
            'total_courses' => $totalCoursesCount,
            'attendance_rate' => $attCount > 0 ? round($attRateSum / $attCount, 1) : null,
        ];

        // Recent Activity Timeline (real records: lessons completed + quizzes taken)
        $recentActivities = [];
        $recentCompletions = DB::table('edu_lesson_progress as p')
            ->join('edu_lessons as l', 'l.id', '=', 'p.lesson_id')
            ->leftJoin('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->where('p.user_id', $auth->id)
            ->whereNotNull('p.completed_at')
            ->orderByDesc('p.completed_at')
            ->limit(5)
            ->get(['l.id as lesson_id', 'l.title as lesson_title', 's.name as subject_name', 's.name_en as subject_name_en', 'p.completed_at']);

        foreach ($recentCompletions as $rc) {
            $recentActivities[] = [
                'type' => 'lesson_completed',
                'title' => $rc->lesson_title,
                'subtitle' => $rc->subject_name ?: $rc->subject_name_en,
                'id' => (int) $rc->lesson_id,
                'target_route' => "/edu/learn/lesson/{$rc->lesson_id}",
                'timestamp' => $rc->completed_at,
            ];
        }

        // Add recent quiz attempts
        $recentAttempts = DB::table('edu_quiz_attempts as a')
            ->join('edu_quizzes as q', 'q.id', '=', 'a.quiz_id')
            ->leftJoin('edu_courses as co', 'co.id', '=', 'q.course_id')
            ->where('a.user_id', $auth->id)
            ->whereIn('a.status', ['submitted', 'graded', 'pending_grading'])
            ->orderByDesc('a.submitted_at')
            ->limit(3)
            ->get(['a.id as attempt_id', 'q.title as quiz_title', 'co.name as course_name', 'a.auto_score', 'a.manual_score', 'a.max_score', 'a.submitted_at']);

        foreach ($recentAttempts as $ra) {
            $totalScore = (float) ($ra->auto_score ?? 0) + (float) ($ra->manual_score ?? 0);
            $maxScore = (float) ($ra->max_score ?? 0);
            $scoreText = $maxScore > 0 ? Num::n($totalScore) . ' / ' . Num::n($maxScore) : '';
            $recentActivities[] = [
                'type' => 'quiz_completed',
                'title' => $ra->quiz_title,
                'subtitle' => $ra->course_name ? "{$ra->course_name} • {$scoreText}" : $scoreText,
                'id' => (int) $ra->attempt_id,
                'target_route' => "/edu/attempt/{$ra->attempt_id}",
                'timestamp' => $ra->submitted_at,
            ];
        }

        usort($recentActivities, fn ($a, $b) => strcmp($b['timestamp'] ?? '', $a['timestamp'] ?? ''));
        $recentActivities = array_slice($recentActivities, 0, 6);

        // Achievements (deterministic)
        $achievements = [
            [
                'id' => 'first_step',
                'title' => 'የመጀመሪያ ጅምር',
                'title_en' => 'First Step',
                'desc' => 'የመጀመሪያውን የትምህርት ክፍለ ጊዜ አጠናቀቁ',
                'desc_en' => 'Completed your first Sunday school lesson',
                'icon' => 'flag',
                'earned' => $totalLessonsCompleted >= 1,
                'progress' => min(1.0, $totalLessonsCompleted / 1.0),
            ],
            [
                'id' => 'diligent_student',
                'title' => 'ትጉህ ተማሪ',
                'title_en' => 'Diligent Student',
                'desc' => '5 የትምህርት ክፍለ ጊዜያትን በተሳካ ሁኔታ አጠናቀቁ',
                'desc_en' => 'Completed 5 lessons in your curriculum',
                'icon' => 'school',
                'earned' => $totalLessonsCompleted >= 5,
                'progress' => min(1.0, $totalLessonsCompleted / 5.0),
            ],
            [
                'id' => 'course_milestone',
                'title' => 'የምዕራፍ አሸናፊ',
                'title_en' => 'Course Master',
                'desc' => 'አንድ ሙሉ የትምህርት ዘርፍ አጠናቀቁ',
                'desc_en' => 'Completed all lessons in a course',
                'icon' => 'trophy',
                'earned' => $completedCoursesCount >= 1,
                'progress' => $totalCoursesCount > 0 ? min(1.0, $completedCoursesCount / 1.0) : 0.0,
            ],
            [
                'id' => 'academic_excellence',
                'title' => 'የፈተና ብቃት',
                'title_en' => 'Academic Excellence',
                'desc' => 'በአንድ ፈተና 80% እና ከዚያ በላይ ውጤት አስመዘገቡ',
                'desc_en' => 'Scored 80% or higher on an assessment',
                'icon' => 'star',
                'earned' => $highestScorePct >= 80,
                'progress' => min(1.0, $highestScorePct / 80.0),
            ],
        ];

        // Recommended Next Action
        $recommendedNext = null;
        if (! empty($pendingAssignments)) {
            $firstAssign = $pendingAssignments[0];
            $recommendedNext = [
                'type' => 'assignment',
                'title' => $firstAssign['title'],
                'subtitle' => $firstAssign['course_name'] ?: 'የቤት ሥራ',
                'action_label' => 'የቤት ሥራ አስረክብ',
                'action_label_en' => 'View Assignment',
                'target_route' => "/edu/class/{$firstAssign['class_id']}?tab=assignments",
            ];
        } else {
            // Find an unfinished published lesson from the student's assigned class curriculum
            $assignedSubjectIds = EduLearning::studyingSubjectIds($auth->id);

            if (! empty($assignedSubjectIds)) {
                $incompLesson = DB::table('edu_lessons as l')
                    ->join('edu_subjects as s', 's.id', '=', 'l.subject_id')
                    ->leftJoin('edu_lesson_progress as p', fn ($j) => $j->on('p.lesson_id', '=', 'l.id')->where('p.user_id', '=', $auth->id))
                    ->whereIn('s.id', $assignedSubjectIds)
                    ->where('s.status', 'published')
                    ->where('l.status', 'published')
                    ->where(fn ($w) => $w->whereNull('p.completed_at')->orWhere('p.completed_at', ''))
                    ->orderBy('s.sort_order')
                    ->orderBy('l.sort_order')
                    ->first(['l.id as lesson_id', 'l.title as lesson_title', 's.name as subject_name', 's.name_en as subject_name_en']);

                if ($incompLesson) {
                    $recommendedNext = [
                        'type' => 'lesson',
                        'title' => $incompLesson->lesson_title,
                        'subtitle' => $incompLesson->subject_name ?: $incompLesson->subject_name_en,
                        'action_label' => 'ትምህርቱን ቀጥል',
                        'action_label_en' => 'Continue Lesson',
                        'target_route' => "/edu/learn/lesson/{$incompLesson->lesson_id}",
                        'explainability' => 'በክፍልዎ ሥርዓተ-ትምህርት ቅደም-ተከተል መሠረት',
                    ];
                } else {
                    $recommendedNext = [
                        'type' => 'completed',
                        'title' => 'የክፍልዎን ሙሉ ሥርዓተ-ትምህርት አጠናቀዋል!',
                        'subtitle' => 'እንኳን ደስ አለዎት! ማጠቃለያ ፈተናዎችን ይውሰዱ ወይም ክለሳ ያድርጉ።',
                        'action_label' => 'ማጠቃለያ ፈተናዎች',
                        'action_label_en' => 'Closing Exams',
                        'target_route' => '/edu/quizzes',
                    ];
                }
            } else {
                // Unenrolled or no subjects assigned
                $recommendedNext = [
                    'type' => 'orientation',
                    'title' => 'የክፍል ምደባዎን ይጠብቁ',
                    'subtitle' => 'የሰሌዳ መጽሔት እና ሌሎች መንፈሳዊ ይዘቶችን መመልከት ይችላሉ',
                    'action_label' => 'ሰሌዳ መጽሔት',
                    'action_label_en' => 'Read Magazine',
                    'target_route' => '/edu/magazines',
                ];
            }
        }

        return [
            'classes' => $classes,
            'subjects' => array_map(fn ($s) => [
                'id' => $s['id'],
                'name' => $s['name'],
                'name_en' => $s['name_en'],
                'progress' => $s['my_progress'],
                'enrolled' => $s['enrolled'],
                'image_url' => $s['image_url'] ?? null,
            ], $subjects),
            'quizzes' => $quizzes,
            'bookmarks' => EduLearning::bookmarks($auth),
            'summary' => $summary,
            'recent_activities' => $recentActivities,
            'achievements' => $achievements,
            'recommended_next' => $recommendedNext,
        ];
    }
}
