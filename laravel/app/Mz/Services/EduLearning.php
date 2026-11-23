<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\T;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The ትምህርት learning catalog: categories → subjects (curriculum kept across classes and years) →
 * units → lessons → materials, with each member's progress and the featured banner.
 *
 * Who sees what (enforced here, the app only hides):
 *  - the catalog (categories, published subjects and lesson titles) — anyone with Education on;
 *  - a lesson's content — a "members" subject: anyone; an "enrolled" subject: students taking a
 *    class subject linked to it, its active teachers and content editors;
 *  - drafts, teacher notes, editing — content editors (education.content / education.manage) for
 *    everything, active teachers of a linked class subject for that subject's units / lessons.
 */
final class EduLearning
{
    public const STATUSES = ['draft', 'published', 'archived'];

    // ------------------------------------------------------------------ who may do what
    public static function isEditor(AuthContext $auth): bool
    {
        return $auth->can('education.content') || $auth->can('education.manage');
    }

    /** Catalog subjects the member actively teaches (through a linked class subject). */
    public static function teachingSubjectIds(int $userId): array
    {
        return array_map('intval', DB::table('edu_courses as co')->join('edu_course_teachers as ct', 'ct.course_id', '=', 'co.id')
            ->where(['ct.user_id' => $userId, 'ct.status' => 'active'])->whereNotNull('co.subject_id')->distinct()->pluck('co.subject_id')->all());
    }

    /** Catalog subjects the member studies (a class subject they take is linked to it). */
    public static function studyingSubjectIds(int $userId): array
    {
        $ids = Edu::myCourseIds($userId);
        if (! $ids) return [];
        return array_map('intval', DB::table('edu_courses')->whereIn('id', $ids)->whereNotNull('subject_id')->distinct()->pluck('subject_id')->all());
    }

    public static function isEnrolledInSubject(int $userId, int $subjectId): bool
    {
        $courses = DB::table('edu_courses')->where('subject_id', $subjectId)->get();
        if ($courses->isEmpty()) {
            return in_array($subjectId, self::studyingSubjectIds($userId), true);
        }
        foreach ($courses as $c) {
            $hasActiveEnrollment = DB::table('edu_enrollments')
                ->where(['class_id' => $c->class_id, 'user_id' => $userId, 'status' => 'active'])
                ->exists();
            $ce = DB::table('edu_course_enrollments')
                ->where(['course_id' => $c->id, 'user_id' => $userId])
                ->first();
            $hasCourseEnrollment = $ce && in_array($ce->status, ['added', 'retake', 'distance', 'enrolled'], true);
            $dropped = $ce && $ce->status === 'dropped';

            if (($hasActiveEnrollment && ! $dropped) || $hasCourseEnrollment) {
                return true;
            }
        }
        return false;
    }

    public static function canEditSubject(AuthContext $auth, int $subjectId): bool
    {
        return self::isEditor($auth) || in_array($subjectId, self::teachingSubjectIds($auth->id), true);
    }

    private static function assertEditor(AuthContext $auth): void
    {
        if (! self::isEditor($auth)) throw ApiError::forbidden('NOT_CONTENT_EDITOR', 'Only education content editors can do this');
    }

    private static function assertEditSubject(AuthContext $auth, int $subjectId): void
    {
        if (! self::canEditSubject($auth, $subjectId)) throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You do not teach or edit this subject');
    }

    public static function hasHistoricalSubjectAccess(int $userId, int $subjectId): bool
    {
        $courses = DB::table('edu_courses')->where('subject_id', $subjectId)->get();
        if ($courses->isEmpty()) return false;
        foreach ($courses as $c) {
            $hadPast = DB::table('edu_enrollments')
                ->where('class_id', $c->class_id)
                ->where('user_id', $userId)
                ->whereIn('status', ['active', 'completed', 'passed', 'promoted'])
                ->exists();
            if ($hadPast) return true;
        }
        return false;
    }

    /** May open the content of [subject] (published, or being edited by the member). */
    public static function canOpen(AuthContext $auth, object $s): bool
    {
        // 1. Authorized content editors and assigned teachers
        if (self::canEditSubject($auth, (int) $s->id)) return true;

        // 2. Subject must be published
        if ($s->status !== 'published') return false;

        // 3. Explicitly public content (no grade restrictions) or members visibility when not a grade curriculum
        if (($s->visibility ?? null) === 'public' || (! empty($s->is_public) && empty($s->grade_level))) {
            return true;
        }

        if (($s->visibility ?? null) === 'members' && empty($s->grade) && empty($s->grade_level)) {
            return true;
        }

        // 4. Strict curriculum authorization: active student enrollment
        if (self::isEnrolledInSubject($auth->id, (int) $s->id)) {
            return true;
        }

        // 5. Historical access for completed past academic year subjects
        if (self::hasHistoricalSubjectAccess($auth->id, (int) $s->id)) {
            return true;
        }

        // Security requirement: Never allow unconditional 'members' visibility or any feature flag
        // to restore unauthorized student access across grade curricula. Preserves security even during recovery.
        return false;
    }

    // ------------------------------------------------------------------ lookups
    private static function category(int $id): object
    {
        $c = DB::table('edu_categories')->where('id', $id)->first();
        if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        return $c;
    }

    private static function subject(int $id): object
    {
        $s = DB::table('edu_subjects')->where('id', $id)->first();
        if (! $s) throw ApiError::notFound('SUBJECT_NOT_FOUND', 'Subject not found');
        return $s;
    }

    private static function unit(int $id): object
    {
        $u = DB::table('edu_units')->where('id', $id)->first();
        if (! $u) throw ApiError::notFound('UNIT_NOT_FOUND', 'Unit not found');
        return $u;
    }

    private static function lesson(int $id): object
    {
        $l = DB::table('edu_lessons')->where('id', $id)->first();
        if (! $l) throw ApiError::notFound('LESSON_NOT_FOUND', 'Lesson not found');
        return $l;
    }

    private static function material(int $id): object
    {
        $m = DB::table('edu_lesson_materials')->where('id', $id)->first();
        if (! $m) throw ApiError::notFound('MATERIAL_NOT_FOUND', 'Material not found');
        return $m;
    }

    // ------------------------------------------------------------------ serializers
    private static function serializeCategory(object $c): array
    {
        return [
            'id' => (int) $c->id, 'name' => $c->name, 'name_en' => $c->name_en, 'description' => $c->description,
            'description_en' => $c->description_en ?? null,
            'image_url' => Storage::url($c->image), 'icon_key' => $c->icon_key, 'sort_order' => (int) $c->sort_order, 'status' => $c->status,
            'subject_count' => (int) ($c->subject_count ?? 0), 'lesson_count' => (int) ($c->lesson_count ?? 0),
        ];
    }

    private static function serializeSubject(object $s): array
    {
        return [
            'id' => (int) $s->id, 'category_id' => $s->category_id ? (int) $s->category_id : null, 'category_name' => $s->category_name ?? null,
            'name' => $s->name, 'name_en' => $s->name_en, 'code' => $s->code, 'description' => $s->description,
            'description_en' => $s->description_en ?? null,
            'objectives' => $s->objectives, 'objectives_en' => $s->objectives_en ?? null,
            'cover_url' => Storage::url($s->cover_image), 'visibility' => $s->visibility, 'sequential' => (bool) $s->sequential,
            'status' => $s->status, 'sort_order' => (int) $s->sort_order,
            'lesson_count' => (int) ($s->lesson_count ?? 0),
        ];
    }

    public static function serializeUnit(object $u): array
    {
        return [
            'id' => (int) $u->id,
            'subject_id' => (int) $u->subject_id,
            'title' => $u->title,
            'title_en' => $u->title_en ?? null,
            'description' => $u->description,
            'description_en' => $u->description_en ?? null,
            'sort_order' => (int) $u->sort_order,
            'status' => $u->status,
        ];
    }

    private static function serializeMaterial(object $m): array
    {
        return [
            'id' => (int) $m->id,
            'lesson_id' => $m->lesson_id !== null ? (int) $m->lesson_id : null,
            'category_id' => ! empty($m->category_id) ? (int) $m->category_id : null,
            'subject_id' => ! empty($m->subject_id) ? (int) $m->subject_id : null,
            'grade' => ! empty($m->grade) ? (int) $m->grade : null,
            'status' => $m->status ?? 'published',
            'is_direct' => $m->lesson_id === null,
            'kind' => $m->kind,
            'title' => $m->title,
            'title_en' => $m->title_en ?? null,
            'description' => $m->description ?? null,
            'description_en' => $m->description_en ?? null,
            'mime' => $m->mime,
            'size' => $m->size !== null ? (int) $m->size : null,
            'name' => $m->original_name,
            'url' => $m->kind === 'file' ? null : $m->url,
            'download_path' => $m->kind === 'file' ? "/edu/materials/{$m->id}/file" : null,
            'sort_order' => (int) $m->sort_order,
        ];
    }

    /** A lesson learners see: published, and not inside a unit that is still a draft / archived. */
    private const VISIBLE_LESSON = "l.status = 'published' AND (l.unit_id IS NULL OR EXISTS (SELECT 1 FROM edu_units vu WHERE vu.id = l.unit_id AND vu.status = 'published'))";

    /** Published lesson / subject counts per category or subject (catalog numbers, never invented). */
    private static function lessonCountSql(string $subjectCol): string
    {
        return "(SELECT COUNT(*) FROM edu_lessons l WHERE l.subject_id = $subjectCol AND " . self::VISIBLE_LESSON . ')';
    }

    // ------------------------------------------------------------------ catalog (members)
    public static function categories(AuthContext $auth, bool $all = false): array
    {
        $q = DB::table('edu_categories as c')
            ->select('c.*',
                DB::raw("(SELECT COUNT(*) FROM edu_subjects s WHERE s.category_id = c.id AND s.status = 'published') as subject_count"),
                DB::raw("(SELECT COUNT(*) FROM edu_lessons l JOIN edu_subjects s ON s.id = l.subject_id WHERE s.category_id = c.id AND s.status = 'published' AND " . self::VISIBLE_LESSON . ') as lesson_count'))
            ->orderBy('c.sort_order')->orderBy('c.id');
        if (! ($all && self::isEditor($auth))) $q->where('c.status', 'active');
        return $q->get()->map(fn ($c) => self::serializeCategory($c))->all();
    }

    /** Subjects of a category (null = every subject); editors also see drafts / archived with [all]. */
    public static function subjects(AuthContext $auth, ?int $categoryId = null, bool $all = false): array
    {
        if ($categoryId) {
            $c = self::category($categoryId);
            if ($c->status !== 'active' && ! self::isEditor($auth)) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        }
        $editor = self::isEditor($auth);
        $teaching = self::teachingSubjectIds($auth->id);
        $studying = self::studyingSubjectIds($auth->id);
        $q = DB::table('edu_subjects as s')->leftJoin('edu_categories as c', 'c.id', '=', 's.category_id')
            ->select('s.*', 'c.name as category_name', DB::raw(self::lessonCountSql('s.id') . ' as lesson_count'))
            ->orderBy('s.sort_order')->orderBy('s.id');
        if ($categoryId) {
            $q->where('s.category_id', $categoryId);
        } elseif (! ($all && $editor)) {
            // When listing subjects on the Education entry, return strictly the 7 canonical subjects
            $q->whereBetween('s.sort_order', [1, 7]);
        }
        if (! ($all && $editor)) {
            $q->where(fn ($w) => $w->where('s.status', 'published')->orWhereIn('s.id', $teaching ?: [0]));
            if (! $all) $q->where('s.status', '<>', 'archived');
        }
        $rows = $q->get();
        $progress = self::subjectProgress($auth->id, $rows->pluck('id')->map(fn ($x) => (int) $x)->all());
        return $rows->map(fn ($s) => self::serializeSubject($s) + [
            'can_open' => self::canOpenWith($s, $editor, $teaching, $studying),
            'can_edit' => $editor || in_array((int) $s->id, $teaching, true),
            'enrolled' => in_array((int) $s->id, $studying, true),
            'my_progress' => $progress[(int) $s->id] ?? ['completed' => 0, 'total' => (int) $s->lesson_count, 'percent' => 0],
        ])->all();
    }

    /** Grades (1..12) the student is actively enrolled in. */
    public static function studentAssignedGrades(int $userId): array
    {
        $grades = [];
        try {
            // 1. Direct active class enrollments
            if (Schema::hasTable('edu_enrollments') && Schema::hasTable('edu_classes')) {
                $hasLevels = Schema::hasTable('edu_levels');
                $q = DB::table('edu_enrollments as e')
                    ->join('edu_classes as c', 'c.id', '=', 'e.class_id');

                if ($hasLevels) {
                    $q->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
                      ->select('c.level_id', 'c.name as class_name', 'lvl.code as level_code', 'lvl.sort_order as level_order');
                } else {
                    $q->select('c.level_id', 'c.name as class_name');
                }

                $classRows = $q->where('e.user_id', $userId)
                    ->where('e.status', 'active')
                    ->get();

                foreach ($classRows as $r) {
                    $g = self::extractGradeNumber($r);
                    if ($g !== null && $g >= 1 && $g <= 12) {
                        $grades[$g] = true;
                    }
                }
            }

            // 2. Course-level enrollments
            if (Schema::hasTable('edu_course_enrollments') && Schema::hasTable('edu_courses') && Schema::hasTable('edu_classes')) {
                $hasLevels = Schema::hasTable('edu_levels');
                $q = DB::table('edu_course_enrollments as ce')
                    ->join('edu_courses as co', 'co.id', '=', 'ce.course_id')
                    ->join('edu_classes as c', 'c.id', '=', 'co.class_id');

                if ($hasLevels) {
                    $q->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
                      ->select('c.level_id', 'c.name as class_name', 'lvl.code as level_code', 'lvl.sort_order as level_order');
                } else {
                    $q->select('c.level_id', 'c.name as class_name');
                }

                $courseRows = $q->where('ce.user_id', $userId)
                    ->whereIn('ce.status', ['enrolled', 'added', 'retake', 'distance'])
                    ->get();

                foreach ($courseRows as $r) {
                    $g = self::extractGradeNumber($r);
                    if ($g !== null && $g >= 1 && $g <= 12) {
                        $grades[$g] = true;
                    }
                }
            }
        } catch (\Throwable $e) {
            // Fallback gracefully on schema issues
        }

        return array_keys($grades);
    }

    /** Subjects assigned to the student's active class curriculum. */
    public static function studentAssignedClassSubjects(int $userId): array
    {
        $subjectIds = self::studyingSubjectIds($userId);
        if (empty($subjectIds)) {
            return [];
        }
        $assignedGrades = self::studentAssignedGrades($userId);
        $primaryGrade = ! empty($assignedGrades) ? $assignedGrades[0] : null;

        $rows = DB::table('edu_subjects as s')
            ->leftJoin('edu_categories as c', 'c.id', '=', 's.category_id')
            ->whereIn('s.id', $subjectIds)
            ->where('s.status', 'published')
            ->select('s.*', 'c.name as category_name', DB::raw(self::lessonCountSql('s.id') . ' as lesson_count'))
            ->orderBy('s.sort_order')
            ->orderBy('s.id')
            ->get();

        $progress = self::subjectProgress($userId, $subjectIds);

        return $rows->map(fn ($s) => self::serializeSubject($s) + [
            'can_open' => true,
            'can_edit' => false,
            'enrolled' => true,
            'assigned_grade' => $primaryGrade,
            'grade' => $primaryGrade,
            'my_progress' => $progress[(int) $s->id] ?? ['completed' => 0, 'total' => (int) $s->lesson_count, 'percent' => 0],
        ])->all();
    }

    private static function extractGradeNumber(object $row): ?int
    {
        if (isset($row->level_order) && $row->level_order >= 1 && $row->level_order <= 12) {
            return (int) $row->level_order;
        }
        if (! empty($row->level_code) && preg_match('/^G(\d+)$/i', $row->level_code, $m)) {
            return (int) $m[1];
        }
        if (isset($row->level_id) && $row->level_id >= 1 && $row->level_id <= 12) {
            return (int) $row->level_id;
        }
        if (! empty($row->class_name)) {
            if (preg_match('/(?:ክፍል\s*|Grade\s*|G)(\d{1,2})/iu', $row->class_name, $m)) {
                return (int) $m[1];
            }
            if (preg_match('/(\d{1,2})ኛ(?:\s*ክፍል)?/u', $row->class_name, $m)) {
                return (int) $m[1];
            }
        }
        return null;
    }

    /** The 12 grades for a subject with content availability. */
    public static function subjectGrades(AuthContext $auth, int $subjectId): array
    {
        $s = self::subject($subjectId);
        $editor = self::isEditor($auth);
        $teaching = self::teachingSubjectIds($auth->id);
        $studying = self::studyingSubjectIds($auth->id);
        $assignedGrades = self::studentAssignedGrades($auth->id);
        $teachesThisSubject = in_array((int) $s->id, $teaching, true);

        $courses = DB::table('edu_courses as co')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->where('co.subject_id', $subjectId)
            ->where('co.status', 'active')
            ->select('co.id as course_id', 'co.class_id', 'c.level_id', 'c.name as class_name')
            ->get();

        $grades = [];
        for ($i = 1; $i <= 12; $i++) {
            $matchingCourses = $courses->filter(function ($co) use ($i) {
                if ($co->level_id && (int) $co->level_id === $i) return true;
                if ($co->class_name && (preg_match("/(^|[^0-9])$i(ኛ|[^0-9]|$)/u", $co->class_name))) return true;
                return false;
            });

            $courseIds = $matchingCourses->pluck('course_id')->all();
            $quizCount = ! empty($courseIds) ? DB::table('edu_quizzes')->whereIn('course_id', $courseIds)->where('status', 'published')->count() : 0;
            $hasContent = $matchingCourses->isNotEmpty();
            $isAssigned = in_array($i, $assignedGrades, true);
            $canOpen = $isAssigned || ($teachesThisSubject && $hasContent);

            $grades[] = [
                'number' => $i,
                'grade_number' => $i,
                'name' => "{$i}ኛ ክፍል",
                'grade_name' => "{$i}ኛ ክፍል",
                'code' => "G{$i}",
                'level_id' => $i,
                'has_content' => $hasContent,
                'course_count' => $matchingCourses->count(),
                'quiz_count' => $quizCount,
                'is_assigned' => $isAssigned,
                'can_open' => $canOpen,
            ];
        }

        return [
            'subject' => self::serializeSubject($s) + [
                'can_open' => self::canOpenWith($s, $editor, $teaching, $studying),
                'can_edit' => $editor || $teachesThisSubject,
            ],
            'has_assigned_grade' => ! empty($assignedGrades),
            'grades' => $grades,
        ];
    }

    /** Content for a specific combination of Subject + Grade (lessons, materials, quizzes). */
    public static function subjectGradeContent(AuthContext $auth, int $subjectId, int $gradeNumber): array
    {
        $s = self::subject($subjectId);
        $editor = self::isEditor($auth);
        $teaching = self::teachingSubjectIds($auth->id);
        $studying = self::studyingSubjectIds($auth->id);

        if ($gradeNumber < 1 || $gradeNumber > 12) {
            throw ApiError::badRequest('INVALID_GRADE', 'Grade must be between 1 and 12');
        }

        // Feature C: In normal Education mode, users must have this grade assigned.
        // Active teachers of this subject bypass grade restriction for their assigned subject.
        // Editors with no student enrollments maintain full administrative access to all grades.
        $teachesThisSubject = in_array((int) $s->id, $teaching, true);
        if (! $teachesThisSubject) {
            $assignedGrades = self::studentAssignedGrades($auth->id);
            if (! in_array($gradeNumber, $assignedGrades, true)) {
                throw ApiError::forbidden('GRADE_ACCESS_DENIED', 'You are not assigned to Grade ' . $gradeNumber);
            }
        }

        $coursesQ = DB::table('edu_courses as co')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->leftJoin('users as t', 't.id', '=', 'co.teacher_user_id')
            ->where('co.subject_id', $subjectId)
            ->where(function ($w) use ($gradeNumber) {
                $w->where('c.level_id', $gradeNumber)
                  ->orWhere('c.name', 'like', "%{$gradeNumber}ኛ%")
                  ->orWhere('c.name', 'like', "%ክፍል {$gradeNumber}%");
            });

        if (! $editor) {
            $coursesQ->where('co.status', 'active');
        }

        $courses = $coursesQ->select(
            'co.*',
            'c.name as class_name',
            'c.level_id',
            't.full_name as teacher_name'
        )->get();

        $courseIds = $courses->pluck('id')->map(fn ($x) => (int) $x)->all();

        // Only return published lessons / units for members
        $unitsQ = DB::table('edu_units as u')->where('u.subject_id', $subjectId)->orderBy('u.sort_order');
        if (! $editor) $unitsQ->where('u.status', 'published');
        $units = $unitsQ->get();

        $lessonsQ = DB::table('edu_lessons as l')->where('l.subject_id', $subjectId)->orderBy('l.sort_order');
        if (! $editor) $lessonsQ->where('l.status', 'published');
        $allLessons = $lessonsQ->get();

        // Grade-specific: only return lessons if this grade has courses or content configured
        $hasGradeCourses = $courses->isNotEmpty();
        $lessons = $hasGradeCourses ? $allLessons : collect([]);

        $lessonIds = $lessons->pluck('id')->all();
        $lessonMaterials = ! empty($lessonIds)
            ? DB::table('edu_lesson_materials')
                ->whereIn('lesson_id', $lessonIds)
                ->orderBy('sort_order')
                ->get()
                ->map(fn ($m) => self::serializeMaterial($m))
                ->all()
            : [];

        // Direct materials for this grade and subject (or category)
        $directMaterials = DB::table('edu_lesson_materials')
            ->whereNull('lesson_id')
            ->where('grade', $gradeNumber)
            ->where(function ($w) use ($s, $subjectId) {
                if ($s->category_id) {
                    $w->where('category_id', $s->category_id);
                }
                $w->orWhere('subject_id', $subjectId);
            })
            ->when(! $editor, fn ($q) => $q->where('status', 'published'))
            ->orderBy('sort_order')
            ->get()
            ->map(fn ($m) => self::serializeMaterial($m))
            ->all();

        $materials = array_merge($lessonMaterials, $directMaterials);

        $quizzes = ! empty($courseIds)
            ? DB::table('edu_quizzes as q')
                ->whereIn('q.course_id', $courseIds)
                ->when(! $editor, fn ($q) => $q->where('status', 'published'))
                ->orderBy('q.id')
                ->get()
                ->map(fn ($q) => [
                    'id' => (int) $q->id,
                    'course_id' => (int) $q->course_id,
                    'title' => $q->title,
                    'title_en' => $q->title_en,
                    'kind' => $q->kind,
                    'time_limit_minutes' => $q->time_limit_minutes ? (int) $q->time_limit_minutes : null,
                    'status' => $q->status,
                ])->all()
            : [];

        return [
            'subject' => self::serializeSubject($s) + [
                'can_open' => self::canOpenWith($s, $editor, $teaching, $studying),
                'can_edit' => $editor || in_array((int) $s->id, $teaching, true),
            ],
            'grade' => [
                'number' => $gradeNumber,
                'name' => "{$gradeNumber}ኛ ክፍል",
                'code' => "G{$gradeNumber}",
            ],
            'courses' => $courses->map(fn ($c) => [
                'id' => (int) $c->id,
                'name' => $c->name,
                'class_name' => $c->class_name,
                'status' => $c->status,
                'teacher_name' => $c->teacher_name,
            ])->all(),
            'lessons' => $lessons->map(fn ($l) => [
                'id' => (int) $l->id,
                'unit_id' => $l->unit_id ? (int) $l->unit_id : null,
                'title' => $l->title,
                'title_en' => $l->title_en,
                'summary' => $l->summary,
                'est_minutes' => $l->est_minutes ? (int) $l->est_minutes : null,
                'status' => $l->status,
                'sort_order' => (int) $l->sort_order,
            ])->all(),
            'units' => $units->map(fn ($u) => [
                'id' => (int) $u->id,
                'title' => $u->title,
                'title_en' => $u->title_en,
                'sort_order' => (int) $u->sort_order,
                'status' => $u->status,
            ])->all(),
            'materials' => $materials,
            'quizzes' => $quizzes,
        ];
    }

    private static function canOpenWith(object $s, bool $editor, array $teaching, array $studying): bool
    {
        if ($editor || in_array((int) $s->id, $teaching, true)) return true;
        if ($s->status !== 'published') return false;
        if (($s->visibility ?? null) === 'public' || (! empty($s->is_public) && empty($s->grade_level))) {
            return true;
        }
        if (in_array((int) $s->id, $studying, true)) {
            return true;
        }
        // Security requirement: Never allow unconditional 'members' visibility or any feature flag
        // to restore unauthorized student access across grade curricula. Preserves security even during recovery.
        return false;
    }

    /** Completed / published lessons per subject for one member. */
    private static function subjectProgress(int $userId, array $subjectIds): array
    {
        if (! $subjectIds) return [];
        $totals = DB::table('edu_lessons as l')->whereIn('l.subject_id', $subjectIds)->whereRaw(self::VISIBLE_LESSON)->groupBy('l.subject_id')->selectRaw('l.subject_id, COUNT(*) as n')->pluck('n', 'subject_id')->all();
        $done = DB::table('edu_lesson_progress as p')->join('edu_lessons as l', 'l.id', '=', 'p.lesson_id')->where('p.user_id', $userId)->whereNotNull('p.completed_at')
            ->whereIn('l.subject_id', $subjectIds)->whereRaw(self::VISIBLE_LESSON)->groupBy('l.subject_id')->selectRaw('l.subject_id, COUNT(*) as n')->pluck('n', 'subject_id')->all();
        $out = [];
        foreach ($subjectIds as $id) {
            $t = (int) ($totals[$id] ?? 0);
            $d = (int) ($done[$id] ?? 0);
            $out[$id] = ['completed' => $d, 'total' => $t, 'percent' => $t ? (int) floor($d / $t * 100) : 0];
        }
        return $out;
    }

    /** One subject: units with their lessons (titles always; content only when allowed), progress. */
    public static function subjectDetail(AuthContext $auth, int $id): array
    {
        $s = DB::table('edu_subjects as s')->leftJoin('edu_categories as c', 'c.id', '=', 's.category_id')->where('s.id', $id)
            ->select('s.*', 'c.name as category_name', DB::raw(self::lessonCountSql('s.id') . ' as lesson_count'))->first();
        if (! $s) throw ApiError::notFound('SUBJECT_NOT_FOUND', 'Subject not found');
        $edit = self::canEditSubject($auth, $id);
        if ($s->status !== 'published' && ! $edit) throw ApiError::notFound('SUBJECT_NOT_FOUND', 'Subject not found');
        $open = self::canOpen($auth, $s);
        $lessons = self::lessonRows($auth->id, $id, $edit);
        $locked = self::lockedIds($s, $lessons, $edit, $auth->id);
        $units = DB::table('edu_units')->where('subject_id', $id)->when(! $edit, fn ($q) => $q->where('status', 'published'))->orderBy('sort_order')->orderBy('id')->get();
        $lessonOut = fn ($l) => self::serializeLessonRow($l) + ['locked' => isset($locked[(int) $l->id])];
        $out = self::serializeSubject($s) + [
            'can_open' => $open,
            'can_edit' => $edit,
            'enrolled' => in_array($id, self::studyingSubjectIds($auth->id), true),
            'my_progress' => self::subjectProgress($auth->id, [$id])[$id],
            'units' => $units->map(fn ($u) => self::serializeUnit($u) + [
                'lessons' => array_values(array_map($lessonOut, array_filter($lessons, fn ($l) => (int) $l->unit_id === (int) $u->id))),
            ])->all(),
            // Lessons outside any unit.
            'lessons' => array_values(array_map($lessonOut, array_filter($lessons, fn ($l) => $l->unit_id === null || ! $units->contains('id', $l->unit_id)))),
        ];
        // Where the subject is taught (class subjects linked to it) — for editors.
        if ($edit) {
            $classes = DB::table('edu_courses as co')->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')->where('co.subject_id', $id)
                ->select('co.id as course_id', 'co.name as course_name', 'c.id as class_id', 'c.name as class_name', 'c.status')->orderBy('c.name')->get()->all();
            $out['classes'] = $classes;
            $courseIds = array_map(fn ($c) => (int) $c->course_id, $classes);
            if (! empty($courseIds)) {
                $out['quizzes'] = DB::table('edu_quizzes as q')
                    ->join('edu_courses as co', 'co.id', '=', 'q.course_id')
                    ->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')
                    ->whereIn('q.course_id', $courseIds)
                    ->select('q.id', 'q.title', 'q.title_en', 'q.status', 'q.course_id', 'q.lesson_id', 'co.name as course_name', 'c.name as class_name',
                        DB::raw('(SELECT COUNT(*) FROM edu_quiz_questions qq WHERE qq.quiz_id = q.id) as question_count'))
                    ->orderByDesc('q.id')
                    ->get()
                    ->all();
            } else {
                $out['quizzes'] = [];
            }
        }
        return $out;
    }

    /** Lessons of a subject in reading order, with the member's progress. */
    private static function lessonRows(int $userId, int $subjectId, bool $drafts): array
    {
        $hasMaterials = Schema::hasTable('edu_lesson_materials');
        $materialCountSql = $hasMaterials
            ? '(SELECT COUNT(*) FROM edu_lesson_materials m WHERE m.lesson_id = l.id) as material_count'
            : '0 as material_count';

        $hasTitleEn = Schema::hasColumn('edu_lessons', 'title_en');
        $hasSummaryEn = Schema::hasColumn('edu_lessons', 'summary_en');
        $hasRequiresQuiz = Schema::hasColumn('edu_lessons', 'requires_quiz');
        $hasBookmarked = Schema::hasColumn('edu_lesson_progress', 'bookmarked');
        $titleEnSql = $hasTitleEn ? 'l.title_en' : 'NULL as title_en';
        $summaryEnSql = $hasSummaryEn ? 'l.summary_en' : 'NULL as summary_en';
        $requiresQuizSql = $hasRequiresQuiz ? 'l.requires_quiz' : '0 as requires_quiz';
        $bookmarkedSql = $hasBookmarked ? 'p.bookmarked' : '0 as bookmarked';

        return DB::table('edu_lessons as l')->leftJoin('edu_units as u', 'u.id', '=', 'l.unit_id')
            ->leftJoin('edu_lesson_progress as p', fn ($j) => $j->on('p.lesson_id', '=', 'l.id')->where('p.user_id', '=', $userId))
            ->where('l.subject_id', $subjectId)->when(! $drafts, fn ($q) => $q->whereRaw(self::VISIBLE_LESSON))
            ->select('l.id', 'l.subject_id', 'l.unit_id', 'l.title', DB::raw($titleEnSql), 'l.summary', DB::raw($summaryEnSql), 'l.est_minutes', 'l.sort_order', 'l.status', 'l.published_at',
                'l.is_mandatory', DB::raw($requiresQuizSql), 'p.last_opened_at', 'p.completed_at', DB::raw($bookmarkedSql),
                DB::raw($materialCountSql))
            // Units first in their order (lessons without a unit last), then the lessons' own order.
            ->orderByRaw('u.id IS NULL')->orderBy('u.sort_order')->orderBy('u.id')->orderBy('l.sort_order')->orderBy('l.id')
            ->get()->all();
    }

    private static function serializeLessonRow(object $l): array
    {
        return [
            'id' => (int) $l->id, 'subject_id' => (int) $l->subject_id, 'unit_id' => $l->unit_id ? (int) $l->unit_id : null,
            'title' => $l->title, 'title_en' => $l->title_en ?? null,
            'summary' => $l->summary, 'summary_en' => $l->summary_en ?? null,
            'est_minutes' => $l->est_minutes !== null ? (int) $l->est_minutes : null,
            'sort_order' => (int) $l->sort_order, 'status' => $l->status,
            'is_mandatory' => (bool) ($l->is_mandatory ?? true),
            'requires_quiz' => (bool) ($l->requires_quiz ?? false),
            'material_count' => (int) ($l->material_count ?? 0),
            'opened' => ($l->last_opened_at ?? null) !== null, 'completed' => ($l->completed_at ?? null) !== null, 'bookmarked' => (bool) ($l->bookmarked ?? false),
        ];
    }

    /**
     * Sequential progression: lessons unlock one after another in order.
     * Accessible by default (first lesson always unlocked); subsequent mandatory lessons
     * require previous lesson completion (and any required quiz passed if configured).
     * Content editors and active teachers are never locked.
     */
    private static function lockedIds(object $s, array $lessons, bool $edit, ?int $userId = null): array
    {
        if ($edit) return [];
        // Sequential unlocking is active by default (unless explicitly disabled as 0)
        if (isset($s->sequential) && ! (bool) $s->sequential) return [];
        $locked = [];
        $prevDone = true;
        foreach ($lessons as $l) {
            if ($l->status !== 'published') continue;
            if (! $prevDone) $locked[(int) $l->id] = true;
            $isMandatory = ! isset($l->is_mandatory) || (bool) $l->is_mandatory;
            if ($isMandatory) {
                $contentDone = ($l->completed_at !== null);
                $quizDone = true;
                if (! empty($l->requires_quiz) && $userId) {
                    $quizIds = DB::table('edu_quizzes')
                        ->where('lesson_id', $l->id)
                        ->where('status', 'published')
                        ->pluck('id')
                        ->all();
                    if (! empty($quizIds)) {
                        $quizDone = DB::table('edu_quiz_attempts')
                            ->whereIn('quiz_id', $quizIds)
                            ->where('user_id', $userId)
                            ->where('status', 'submitted')
                            ->exists();
                    }
                }
                $prevDone = $prevDone && ($contentDone && $quizDone);
            }
        }
        return $locked;
    }

    /** Course completion percentage for mandatory published lessons. */
    public static function courseCompletion(int $userId, int $courseId): array
    {
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course || ! $course->subject_id) {
            return ['completed' => 0, 'total' => 0, 'percent' => 0.0, 'is_enrolled' => false];
        }

        $isEnrolled = false;
        if ($course->class_id) {
            $isEnrolled = DB::table('edu_enrollments')
                ->where('class_id', $course->class_id)
                ->where('user_id', $userId)
                ->where('status', 'active')
                ->exists();
        }
        if (! $isEnrolled && Schema::hasTable('edu_course_enrollments')) {
            $ce = DB::table('edu_course_enrollments')
                ->where('course_id', $courseId)
                ->where('user_id', $userId)
                ->first();
            if ($ce && in_array($ce->status, ['added', 'retake', 'distance', 'enrolled', 'active'], true)) {
                $isEnrolled = true;
            }
        }
        if (! $isEnrolled) {
            return ['completed' => 0, 'total' => 0, 'percent' => 0.0, 'is_enrolled' => false];
        }

        $lessons = DB::table('edu_lessons')
            ->where('subject_id', $course->subject_id)
            ->where('status', 'published')
            ->where('is_mandatory', 1)
            ->pluck('id')
            ->all();

        if (empty($lessons)) {
            $lessons = DB::table('edu_lessons')
                ->where('subject_id', $course->subject_id)
                ->where('status', 'published')
                ->pluck('id')
                ->all();
        }

        $total = count($lessons);
        if ($total === 0) {
            return ['completed' => 0, 'total' => 0, 'percent' => 0.0, 'is_enrolled' => true];
        }

        $completed = DB::table('edu_lesson_progress')
            ->where('user_id', $userId)
            ->whereIn('lesson_id', $lessons)
            ->whereNotNull('completed_at')
            ->count();

        $percent = round(($completed / $total) * 100, 2);
        return [
            'completed' => (int) $completed,
            'total' => $total,
            'percent' => (float) $percent,
            'is_enrolled' => true,
        ];
    }

    /** One lesson to read (records that the member opened it). */
    public static function lessonDetail(AuthContext $auth, int $id): array
    {
        $l = self::lesson($id);
        $s = self::subject((int) $l->subject_id);
        $edit = self::canEditSubject($auth, (int) $s->id);
        if (! $edit && ($l->status !== 'published' || $s->status !== 'published')) throw ApiError::notFound('LESSON_NOT_FOUND', 'Lesson not found');
        if (! self::canOpen($auth, $s)) throw ApiError::forbidden('NOT_ENROLLED', 'This lesson is for the students of this subject');
        $order = self::lessonRows($auth->id, (int) $s->id, $edit);
        $ids = array_map(fn ($x) => (int) $x->id, $order);
        $pos = array_search($id, $ids, true);
        if ($pos === false && ! $edit) throw ApiError::notFound('LESSON_NOT_FOUND', 'Lesson not found');
        $locked = self::lockedIds($s, $order, $edit, $auth->id);
        if (isset($locked[$id])) throw ApiError::conflict('LESSON_LOCKED', 'Complete the previous lesson first');
        if ($pos !== false && $l->status === 'published') {
            DB::table('edu_lesson_progress')->upsert([['user_id' => $auth->id, 'lesson_id' => $id, 'last_opened_at' => Dates::sql(Dates::now())]], ['user_id', 'lesson_id'], ['last_opened_at']);
        }
        $p = DB::table('edu_lesson_progress')->where(['user_id' => $auth->id, 'lesson_id' => $id])->first();
        $unit = $l->unit_id ? DB::table('edu_units')->where('id', $l->unit_id)->first(['id', 'title', 'title_en']) : null;
        $materials = DB::table('edu_lesson_materials')->where('lesson_id', $id)->orderBy('sort_order')->orderBy('id')->get();
        // Published quizzes of this lesson for a class subject the member takes (or teaches / edits).
        $courseIds = $edit ? null : (function () use ($auth, $s) {
            $my = Edu::myCourseIds($auth->id);
            $subjectCourses = DB::table('edu_courses')->where('subject_id', (int) $s->id)->pluck('id')->all();
            $matched = array_values(array_intersect($subjectCourses, $my));
            return ! empty($matched) ? $matched : $subjectCourses;
        })();
        $quizzes = DB::table('edu_quizzes')->where('lesson_id', $id)
            ->when(! $edit, fn ($q) => $q->where('status', '<>', 'draft'))
            ->when($courseIds !== null, fn ($q) => $q->whereIn('course_id', $courseIds ?: [0]))->orderBy('id')->get(['id', 'title', 'title_en', 'course_id', 'closes_at', 'status'])->all();
        return [
            'id' => (int) $l->id, 'title' => $l->title, 'title_en' => $l->title_en ?? null,
            'summary' => $l->summary, 'summary_en' => $l->summary_en ?? null,
            'body' => $l->body, 'body_en' => $l->body_en ?? null,
            'scripture_refs' => $l->scripture_refs,
            'objectives' => $l->objectives, 'objectives_en' => $l->objectives_en ?? null,
            'est_minutes' => $l->est_minutes !== null ? (int) $l->est_minutes : null, 'status' => $l->status,
            'is_mandatory' => (bool) ($l->is_mandatory ?? true),
            'requires_quiz' => (bool) ($l->requires_quiz ?? false),
            'teacher_notes' => $edit ? $l->teacher_notes : null,
            'unit' => $unit ? ['id' => (int) $unit->id, 'title' => $unit->title, 'title_en' => $unit->title_en ?? null] : null,
            'subject' => ['id' => (int) $s->id, 'name' => $s->name, 'name_en' => $s->name_en, 'sequential' => (bool) $s->sequential],
            'position' => $pos === false ? null : $pos + 1, 'total' => count($ids),
            'prev_id' => $pos !== false && $pos > 0 ? $ids[$pos - 1] : null,
            'next_id' => $pos !== false && $pos < count($ids) - 1 ? $ids[$pos + 1] : null,
            'materials' => $materials->map(fn ($m) => self::serializeMaterial($m))->all(),
            'quizzes' => $quizzes,
            'completed' => $p?->completed_at !== null, 'bookmarked' => (bool) ($p?->bookmarked ?? false),
            'can_edit' => $edit, 'author_id' => $l->author_id ? (int) $l->author_id : null, 'unit_id' => $l->unit_id ? (int) $l->unit_id : null,
            'sort_order' => (int) $l->sort_order,
        ];
    }

    /** Mark a lesson completed / not completed, or (un)bookmark it. */
    public static function setProgress(AuthContext $auth, int $id, string $action): array
    {
        $l = self::lesson($id);
        $s = self::subject((int) $l->subject_id);
        if ($l->status !== 'published' || $s->status !== 'published') throw ApiError::notFound('LESSON_NOT_FOUND', 'Lesson not found');
        if (! self::canOpen($auth, $s)) throw ApiError::forbidden('NOT_ENROLLED', 'This lesson is for the students of this subject');
        $order = self::lessonRows($auth->id, (int) $s->id, false);
        if (! in_array($id, array_map(fn ($x) => (int) $x->id, $order), true)) throw ApiError::notFound('LESSON_NOT_FOUND', 'Lesson not found');
        $locked = self::lockedIds($s, $order, self::canEditSubject($auth, (int) $s->id), $auth->id);
        if (isset($locked[$id])) throw ApiError::conflict('LESSON_LOCKED', 'Complete the previous lesson first');
        $now = Dates::sql(Dates::now());
        $patch = match ($action) {
            'complete' => ['completed_at' => $now],
            'uncomplete' => ['completed_at' => null],
            'bookmark' => ['bookmarked' => 1],
            'unbookmark' => ['bookmarked' => 0],
        };
        DB::table('edu_lesson_progress')->upsert([['user_id' => $auth->id, 'lesson_id' => $id, 'last_opened_at' => $now] + $patch], ['user_id', 'lesson_id'], array_keys($patch));
        EduDashboard::invalidateUserDashboard($auth->id);
        $p = DB::table('edu_lesson_progress')->where(['user_id' => $auth->id, 'lesson_id' => $id])->first();
        return ['lesson_id' => $id, 'completed' => $p->completed_at !== null, 'bookmarked' => (bool) $p->bookmarked, 'subject_progress' => self::subjectProgress($auth->id, [(int) $s->id])[(int) $s->id]];
    }

    /**
     * The lesson to resume: the last one opened and not completed, else the next unread lesson of the
     * subject last worked in. Null when the member never opened a lesson (no invented progress).
     */
    public static function continueLearning(AuthContext $auth): ?array
    {
        $recent = DB::table('edu_lesson_progress as p')->join('edu_lessons as l', 'l.id', '=', 'p.lesson_id')->join('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->where('p.user_id', $auth->id)->where('l.status', 'published')->where('s.status', 'published')
            ->orderByDesc('p.last_opened_at')->limit(10)->get(['l.id', 'l.subject_id', 'p.completed_at']);
        foreach ($recent as $r) {
            $s = self::subject((int) $r->subject_id);
            if (! self::canOpen($auth, $s)) continue;
            $target = (int) $r->id;
            if ($r->completed_at !== null) {
                $next = null;
                foreach (self::lessonRows($auth->id, (int) $s->id, false) as $l) {
                    if ($l->completed_at === null) { $next = (int) $l->id; break; }
                }
                if ($next === null) continue; // the whole subject is done
                $target = $next;
            }
            $l = self::lesson($target);
            $progress = self::subjectProgress($auth->id, [(int) $s->id])[(int) $s->id];
            $order = array_map(fn ($x) => (int) $x->id, self::lessonRows($auth->id, (int) $s->id, false));
            $pos = array_search($target, $order, true);
            return [
                'lesson_id' => $target, 'lesson_title' => $l->title, 'subject_id' => (int) $s->id, 'subject_name' => $s->name, 'subject_name_en' => $s->name_en,
                'cover_url' => Storage::url($s->cover_image), 'position' => $pos === false ? null : $pos + 1, 'total' => count($order), 'progress' => $progress,
            ];
        }

        // If member hasn't opened any lesson yet, recommend the first lesson of their assigned class curriculum
        $assignedSubjectIds = self::studyingSubjectIds($auth->id);
        if (empty($assignedSubjectIds) && (self::isEditor($auth) || $auth->isAdmin)) {
            $assignedSubjectIds = DB::table('edu_subjects')->where('status', 'published')->pluck('id')->map(fn ($x) => (int) $x)->all();
        }
        if (! empty($assignedSubjectIds)) {
            $firstSub = DB::table('edu_subjects')
                ->whereIn('id', $assignedSubjectIds)
                ->where('status', 'published')
                ->orderBy('sort_order')
                ->first();
            if ($firstSub) {
                $firstLesson = DB::table('edu_lessons')
                    ->where('subject_id', $firstSub->id)
                    ->where('status', 'published')
                    ->orderBy('sort_order')
                    ->first();
                if ($firstLesson) {
                    $progress = self::subjectProgress($auth->id, [(int) $firstSub->id])[(int) $firstSub->id] ?? ['completed' => 0, 'total' => 1, 'percent' => 0];
                    $order = array_map(fn ($x) => (int) $x->id, self::lessonRows($auth->id, (int) $firstSub->id, false));
                    return [
                        'lesson_id' => (int) $firstLesson->id,
                        'lesson_title' => $firstLesson->title,
                        'subject_id' => (int) $firstSub->id,
                        'subject_name' => $firstSub->name,
                        'subject_name_en' => $firstSub->name_en,
                        'cover_url' => Storage::url($firstSub->cover_image),
                        'position' => 1,
                        'total' => count($order),
                        'progress' => $progress,
                    ];
                }
            }
        }

        return null;
    }

    /** The member's bookmarked lessons they can still open. */
    public static function bookmarks(AuthContext $auth): array
    {
        $rows = DB::table('edu_lesson_progress as p')->join('edu_lessons as l', 'l.id', '=', 'p.lesson_id')->join('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->where(['p.user_id' => $auth->id, 'p.bookmarked' => 1])->where('l.status', 'published')->where('s.status', 'published')
            ->orderByDesc('p.last_opened_at')->limit(50)->get(['l.id', 'l.title', 's.id as subject_id', 's.name as subject_name', 's.visibility', 's.status', 'p.completed_at']);
        $studying = self::studyingSubjectIds($auth->id);
        return $rows->filter(fn ($r) => $r->visibility === 'members' || in_array((int) $r->subject_id, $studying, true) || self::canEditSubject($auth, (int) $r->subject_id))
            ->map(fn ($r) => ['lesson_id' => (int) $r->id, 'title' => $r->title, 'subject_id' => (int) $r->subject_id, 'subject_name' => $r->subject_name, 'completed' => $r->completed_at !== null])->values()->all();
    }

    // ------------------------------------------------------------------ featured banner
    public static function featured(AuthContext $auth, bool $all = false): array
    {
        $now = Dates::sql(Dates::now());
        $q = DB::table('edu_featured')->orderBy('sort_order')->orderByDesc('id');
        if (! ($all && self::isEditor($auth))) {
            $q->where('is_active', 1)->where(fn ($w) => $w->whereNull('starts_at')->orWhere('starts_at', '<=', $now))->where(fn ($w) => $w->whereNull('ends_at')->orWhere('ends_at', '>', $now));
        }
        $out = [];
        foreach ($q->limit($all ? 100 : 10)->get() as $f) {
            $t = self::featuredTarget($auth, $f);
            if (! $t && ! $all) continue; // a removed / unpublished target is not advertised
            $out[] = [
                'id' => (int) $f->id, 'target_type' => $f->target_type, 'target_id' => (int) $f->target_id,
                'title' => $f->title ?: ($t['title'] ?? null), 'subtitle' => $f->subtitle ?: ($t['subtitle'] ?? null),
                'image_url' => Storage::url($f->image) ?? ($t['image_url'] ?? null),
                'starts_at' => $f->starts_at, 'ends_at' => $f->ends_at, 'sort_order' => (int) $f->sort_order, 'is_active' => (bool) $f->is_active,
                'target' => $t,
            ];
        }
        return $out;
    }

    private static function featuredTarget(AuthContext $auth, object $f): ?array
    {
        switch ($f->target_type) {
            case 'subject':
                $s = DB::table('edu_subjects')->where(['id' => $f->target_id, 'status' => 'published'])->first();
                if (! $s) return null;
                $p = self::subjectProgress($auth->id, [(int) $s->id])[(int) $s->id];
                return ['title' => $s->name, 'subtitle' => $s->name_en, 'image_url' => Storage::url($s->cover_image), 'route' => "/edu/learn/subject/{$s->id}", 'progress' => $p];
            case 'lesson':
                $l = DB::table('edu_lessons as l')->join('edu_subjects as s', 's.id', '=', 'l.subject_id')->where('l.id', $f->target_id)
                    ->where('l.status', 'published')->where('s.status', 'published')->first(['l.id', 'l.title', 's.id as subject_id', 's.name as subject_name', 's.cover_image']);
                if (! $l) return null;
                $order = array_map(fn ($x) => (int) $x->id, self::lessonRows($auth->id, (int) $l->subject_id, false));
                $pos = array_search((int) $l->id, $order, true);
                return ['title' => $l->title, 'subtitle' => $l->subject_name, 'image_url' => Storage::url($l->cover_image), 'route' => "/edu/learn/lesson/{$l->id}", 'position' => $pos === false ? null : $pos + 1, 'total' => count($order)];
            case 'class':
                $c = DB::table('edu_classes')->where(['id' => $f->target_id, 'status' => 'active'])->first();
                if (! $c) return null;
                return ['title' => $c->name, 'subtitle' => $c->description, 'image_url' => null, 'route' => '/edu/register'];
        }
        return null;
    }

    // ------------------------------------------------------------------ search (Requirement 8)
    public static function search(AuthContext $auth, string $q): array
    {
        $q = trim($q);
        if (mb_strlen($q) < 2) {
            return [
                'categories' => [],
                'subjects' => [],
                'courses' => [],
                'units' => [],
                'lessons' => [],
                'materials' => [],
                'magazines' => [],
                'books' => [],
                'classes' => [],
                'assignments' => [],
                'quizzes' => [],
            ];
        }
        $like = '%' . addcslashes($q, '%_\\') . '%';
        $studying = self::studyingSubjectIds($auth->id);
        $isEditor = self::isEditor($auth);

        // 1. Categories
        $cats = DB::table('edu_categories')->where('status', 'active')
            ->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('name_en', 'like', $like)->orWhere('description', 'like', $like))
            ->orderBy('sort_order')->limit(10)
            ->get(['id', 'name', 'name_en', 'description'])->all();

        // 2. Subjects
        $subQ = DB::table('edu_subjects');
        if (! $isEditor) $subQ->where('status', 'published');
        $subjects = $subQ->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('name_en', 'like', $like)->orWhere('code', 'like', $like)->orWhere('description', 'like', $like))
            ->orderBy('sort_order')->limit(20)
            ->get(['id', 'name', 'name_en', 'code', 'description', 'category_id', 'visibility'])->filter(function ($s) use ($auth, $studying, $isEditor) {
                if ($isEditor) return true;
                return $s->visibility === 'members' || in_array((int) $s->id, $studying, true) || self::canEditSubject($auth, (int) $s->id);
            })->values()->all();

        // 3. Courses
        $cNameCol = Schema::hasColumn('edu_courses', 'name') ? 'c.name' : 'c.title';
        $courses = DB::table('edu_courses as c')
            ->leftJoin('edu_classes as cl', 'cl.id', '=', 'c.class_id')
            ->where(fn ($w) => $w->where(DB::raw($cNameCol), 'like', $like)->orWhere('c.code', 'like', $like)->orWhere('c.description', 'like', $like))
            ->limit(15)
            ->get(['c.id', DB::raw("{$cNameCol} as title"), 'c.code', 'c.description', 'c.class_id', 'cl.name as class_name'])->all();

        // 4. Units
        $units = DB::table('edu_units as u')
            ->join('edu_subjects as s', 's.id', '=', 'u.subject_id')
            ->where(fn ($w) => $w->where('u.title', 'like', $like)->orWhere('u.title_en', 'like', $like)->orWhere('u.description', 'like', $like))
            ->limit(20)
            ->get(['u.id', 'u.title', 'u.title_en', 'u.subject_id', 's.name as subject_name'])->filter(function ($u) use ($auth, $studying, $isEditor) {
                if ($isEditor) return true;
                return in_array((int) $u->subject_id, $studying, true) || self::canEditSubject($auth, (int) $u->subject_id);
            })->values()->all();

        // 5. Lessons (Title, Summary, Body Content, Learning Objectives, Scripture refs)
        $lessonQ = DB::table('edu_lessons as l')
            ->join('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->leftJoin('edu_units as u', 'u.id', '=', 'l.unit_id');
        if (! $isEditor) {
            $lessonQ->where('l.status', 'published')->where('s.status', 'published');
        }
        $lessonCols = Schema::getColumnListing('edu_lessons');
        $hasBody = in_array('body', $lessonCols);
        $hasContent = in_array('content', $lessonCols);
        $lessons = $lessonQ->where(function ($w) use ($like, $hasBody, $hasContent) {
            $w->where('l.title', 'like', $like)
              ->orWhere('l.summary', 'like', $like);
            if ($hasBody) $w->orWhere('l.body', 'like', $like);
            if ($hasContent) $w->orWhere('l.content', 'like', $like);
            $w->orWhere('l.objectives', 'like', $like)
              ->orWhere('l.scripture_refs', 'like', $like);
        })
        ->orderBy('s.sort_order')->orderBy('l.sort_order')->limit(30)
        ->get(['l.id', 'l.title', 'l.summary', 's.id as subject_id', 's.name as subject_name', 's.visibility', 'u.title as unit_title'])
        ->filter(function ($l) use ($auth, $studying, $isEditor) {
            if ($isEditor) return true;
            return $l->visibility === 'members' || in_array((int) $l->subject_id, $studying, true) || self::canEditSubject($auth, (int) $l->subject_id);
        })->values()->all();

        // 6. Learning Materials (Document and media names)
        $materials = DB::table('edu_lesson_materials as m')
            ->join('edu_lessons as l', 'l.id', '=', 'm.lesson_id')
            ->join('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->where(fn ($w) => $w->where('m.title', 'like', $like)->orWhere('m.original_name', 'like', $like))
            ->limit(20)
            ->get(['m.id', 'm.title', 'm.kind', 'm.mime', 'l.id as lesson_id', 'l.title as lesson_title', 's.id as subject_id', 's.name as subject_name'])
            ->filter(function ($m) use ($auth, $studying, $isEditor) {
                if ($isEditor) return true;
                return in_array((int) $m->subject_id, $studying, true) || self::canEditSubject($auth, (int) $m->subject_id);
            })->values()->all();

        // 7. Published Seleda Magazines
        $magazines = [];
        if (Schema::hasTable('edu_magazines')) {
            $magQ = DB::table('edu_magazines');
            if (! $isEditor) $magQ->where('status', 'published');
            $issueCol = Schema::hasColumn('edu_magazines', 'issue_number') ? 'issue_number' : (Schema::hasColumn('edu_magazines', 'issue_no') ? 'issue_no' : null);
            $magQ->where(function ($w) use ($like, $issueCol) {
                $w->where('title', 'like', $like)->orWhere('description', 'like', $like);
                if ($issueCol) $w->orWhere($issueCol, 'like', $like);
            });
            $selectMag = ['id', 'title', 'description', 'cover_image', 'pdf_path'];
            if ($issueCol) $selectMag[] = DB::raw("{$issueCol} as issue_no");
            $magazines = $magQ->orderByDesc('id')->limit(10)->get($selectMag)->all();
        }

        // 8. Books / Items
        $books = [];
        if (Schema::hasTable('books')) {
            $booksQ = DB::table('books')->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('author', 'like', $like)->orWhere('code', 'like', $like));
            $books = $booksQ->limit(15)->get(['id', 'title', 'author', 'code'])->all();
        }
        if (empty($books) && Schema::hasTable('items')) {
            $itemsQ = DB::table('items')->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('author', 'like', $like)->orWhere('code', 'like', $like));
            $books = $itemsQ->limit(15)->get(['id', DB::raw('name as title'), 'author', 'code'])->all();
        }

        // 9. Classes
        $classes = [];
        if (Schema::hasTable('edu_classes')) {
            $classes = DB::table('edu_classes')
                ->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('term', 'like', $like))
                ->limit(15)->get(['id', 'name', 'term', 'status'])->all();
        }

        // 10. Assignments
        $assignments = [];
        if (Schema::hasTable('edu_assignments')) {
            $assignQ = DB::table('edu_assignments');
            if (! $isEditor) $assignQ->where('status', 'published');
            $assignments = $assignQ->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('instructions', 'like', $like))
                ->limit(15)->get(['id', 'title', 'instructions', 'status'])->all();
        }

        // 11. Quizzes
        $quizzes = [];
        if (Schema::hasTable('edu_quizzes')) {
            $quizQ = DB::table('edu_quizzes');
            if (! $isEditor) $quizQ->where('status', 'published');
            $quizzes = $quizQ->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('instructions', 'like', $like))
                ->limit(15)->get(['id', 'title', 'instructions', 'status'])->all();
        }

        return [
            'categories' => $cats,
            'subjects' => $subjects,
            'courses' => $courses,
            'units' => $units,
            'lessons' => $lessons,
            'materials' => $materials,
            'magazines' => $magazines,
            'books' => $books,
            'classes' => $classes,
            'assignments' => $assignments,
            'quizzes' => $quizzes,
        ];
    }

    // ------------------------------------------------------------------ materials (download)
    /** A lesson file or direct course material file, only for authorized members. */
    public static function materialFile(AuthContext $auth, int $id): array
    {
        $m = self::material($id);
        if ($m->kind !== 'file' || ! $m->path) throw ApiError::notFound('MATERIAL_NOT_FOUND', 'Material not found');
        if ($m->lesson_id) {
            $l = self::lesson((int) $m->lesson_id);
            $s = self::subject((int) $l->subject_id);
            $edit = self::canEditSubject($auth, (int) $s->id);
            if (! $edit && ($l->status !== 'published' || $s->status !== 'published')) throw ApiError::notFound('MATERIAL_NOT_FOUND', 'Material not found');
            if (! self::canOpen($auth, $s)) throw ApiError::forbidden('NOT_ENROLLED', 'This lesson is for the students of this subject');
        } else {
            $edit = self::isEditor($auth);
            if (! empty($m->subject_id)) {
                $s = self::subject((int) $m->subject_id);
                $edit = $edit || self::canEditSubject($auth, (int) $s->id);
            }
            if (! $edit && ($m->status ?? 'published') !== 'published') throw ApiError::notFound('MATERIAL_NOT_FOUND', 'Material not found');
            if (! $edit) {
                if (! empty($m->grade)) {
                    $assignedGrades = self::studentAssignedGrades($auth->id);
                    if (! empty($assignedGrades) && ! in_array((int) $m->grade, $assignedGrades, true)) {
                        throw ApiError::forbidden('GRADE_ACCESS_DENIED', 'You are not enrolled in Grade ' . $m->grade);
                    }
                }
                if (! empty($m->subject_id) && ! self::canOpen($auth, self::subject((int) $m->subject_id))) {
                    throw ApiError::forbidden('NOT_ENROLLED', 'This material is for the students of this subject');
                }
            }
        }
        $abs = Storage::privatePath($m->path);
        if (! is_file($abs)) throw ApiError::notFound('MATERIAL_NOT_FOUND', 'Material not found');
        $ext = pathinfo($m->path, PATHINFO_EXTENSION);
        $name = preg_replace('/[^\p{L}\p{N}._ -]/u', '', $m->original_name ?: $m->title) ?: "material-$id";
        if ($ext && ! str_ends_with(mb_strtolower($name), '.' . $ext)) $name .= ".$ext";
        return ['abs' => $abs, 'mime' => $m->mime ?: 'application/octet-stream', 'name' => mb_substr($name, 0, 150)];
    }

    // ================================================================== editing
    // ---- categories (content editors) ----
    public static function createCategory(array $actx, array $in): array
    {
        self::assertEditor($actx['auth']);
        $order = $in['sort_order'] ?? ((int) DB::table('edu_categories')->max('sort_order') + 1);
        $id = DB::table('edu_categories')->insertGetId(self::only($in, ['name', 'name_en', 'description', 'icon_key', 'status']) + ['sort_order' => $order, 'created_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_category', $id, ['created' => $in['name']]);
        return self::categoryOut($id);
    }

    public static function updateCategory(array $actx, int $id, array $in): array
    {
        self::assertEditor($actx['auth']);
        self::category($id);
        $patch = self::only($in, ['name', 'name_en', 'description', 'icon_key', 'status', 'sort_order']);
        if ($patch) DB::table('edu_categories')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_category', $id, ['fields' => array_keys($patch)]);
        return self::categoryOut($id);
    }

    public static function setCategoryImage(array $actx, int $id, ?UploadedFile $file): array
    {
        self::assertEditor($actx['auth']);
        $c = self::category($id);
        $saved = $file ? Storage::save('image', Storage::FOLDERS['EDU_IMAGES'], $file) : null;
        DB::table('edu_categories')->where('id', $id)->update(['image' => $saved['path'] ?? null, 'updated_by' => $actx['auth']->id]);
        if ($c->image) Storage::remove($c->image);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_category', $id, ['image' => $saved ? 'set' : 'removed']);
        return self::categoryOut($id);
    }

    /** A category is deleted only while empty; otherwise it is archived. */
    public static function deleteCategory(array $actx, int $id): void
    {
        self::assertEditor($actx['auth']);
        $c = self::category($id);
        if (DB::table('edu_subjects')->where('category_id', $id)->exists()) throw ApiError::conflict('HAS_RECORDS', 'This category has subjects; archive it instead');
        DB::table('edu_categories')->where('id', $id)->delete();
        if ($c->image) Storage::remove($c->image);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_category', $id, ['deleted' => $c->name]);
    }

    public static function reorder(array $actx, string $table, array $ids, ?array $scope = null): void
    {
        $tables = ['edu_categories', 'edu_subjects', 'edu_units', 'edu_lessons', 'edu_lesson_materials', 'edu_featured'];
        if (! in_array($table, $tables, true)) throw new \RuntimeException("cannot reorder $table");
        $known = DB::table($table)->whereIn('id', $ids)->when($scope, fn ($q) => $q->where($scope))->count();
        if ($known !== count(array_unique($ids))) throw ApiError::field('ids', 'INVALID_ORDER');
        DB::transaction(function () use ($table, $ids) {
            foreach (array_values($ids) as $i => $id) DB::table($table)->where('id', $id)->update(['sort_order' => $i + 1]);
        });
        Audit::log($actx, Audit::EDU_UPDATE, $table, null, ['reordered' => count($ids)]);
    }

    public static function reorderCategories(array $actx, array $ids): array
    {
        self::assertEditor($actx['auth']);
        self::reorder($actx, 'edu_categories', $ids);
        return self::categories($actx['auth'], true);
    }

    private static function categoryOut(int $id): array
    {
        foreach (self::categories(\App\Mz\Http\Ctx::auth(), true) as $c) if ($c['id'] === $id) return $c;
        throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
    }

    // ---- subjects (content editors) ----
    private const SUBJECT_FIELDS = ['category_id', 'name', 'name_en', 'code', 'description', 'description_en', 'objectives', 'objectives_en', 'visibility', 'sequential', 'status', 'sort_order'];

    public static function createSubject(array $actx, array $in): array
    {
        self::assertEditor($actx['auth']);
        if (! empty($in['category_id'])) self::category((int) $in['category_id']);
        $in['sort_order'] ??= (int) DB::table('edu_subjects')->where('category_id', $in['category_id'] ?? null)->max('sort_order') + 1;
        $id = DB::table('edu_subjects')->insertGetId(self::only($in, self::SUBJECT_FIELDS) + ['created_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_subject', $id, ['created' => $in['name']]);
        return self::subjectDetail($actx['auth'], $id);
    }

    public static function updateSubject(array $actx, int $id, array $in): array
    {
        self::assertEditor($actx['auth']);
        self::subject($id);
        if (! empty($in['category_id'])) self::category((int) $in['category_id']);
        $patch = self::only($in, self::SUBJECT_FIELDS);
        if ($patch) DB::table('edu_subjects')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_subject', $id, ['fields' => array_keys($patch)]);
        return self::subjectDetail($actx['auth'], $id);
    }

    public static function setSubjectCover(array $actx, int $id, ?UploadedFile $file): array
    {
        self::assertEditor($actx['auth']);
        $s = self::subject($id);
        $saved = $file ? Storage::save('image', Storage::FOLDERS['EDU_IMAGES'], $file) : null;
        DB::table('edu_subjects')->where('id', $id)->update(['cover_image' => $saved['path'] ?? null, 'updated_by' => $actx['auth']->id]);
        if ($s->cover_image) Storage::remove($s->cover_image);
        return self::subjectDetail($actx['auth'], $id);
    }

    /** Deleted only while it has no lessons, no linked class subject and nobody's progress. */
    public static function deleteSubject(array $actx, int $id): void
    {
        self::assertEditor($actx['auth']);
        $s = self::subject($id);
        if (DB::table('edu_lessons')->where('subject_id', $id)->exists() || DB::table('edu_courses')->where('subject_id', $id)->exists()) {
            throw ApiError::conflict('HAS_RECORDS', 'This subject has lessons or classes; archive it instead');
        }
        DB::table('edu_subjects')->where('id', $id)->delete();
        if ($s->cover_image) Storage::remove($s->cover_image);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_subject', $id, ['deleted' => $s->name]);
    }

    // ---- units and lessons (content editors, or the subject's active teachers) ----
    private const UNIT_FIELDS = ['title', 'title_en', 'description', 'description_en', 'status', 'sort_order'];

    public static function unitDetail(AuthContext $auth, int $id): array
    {
        $u = self::unit($id);
        $s = self::subject((int) $u->subject_id);
        $edit = self::canEditSubject($auth, (int) $s->id);
        if (! $edit && ($u->status !== 'published' || $s->status !== 'published')) throw ApiError::notFound('UNIT_NOT_FOUND', 'Unit not found');
        $lessons = self::lessonRows($auth->id, (int) $s->id, $edit);
        $locked = self::lockedIds($s, $lessons, $edit, $auth->id);
        $lessonOut = fn ($l) => self::serializeLessonRow($l) + ['locked' => isset($locked[(int) $l->id])];
        return self::serializeUnit($u) + [
            'subject' => ['id' => (int) $s->id, 'name' => $s->name, 'name_en' => $s->name_en],
            'lessons' => array_values(array_map($lessonOut, array_filter($lessons, fn ($l) => (int) $l->unit_id === (int) $u->id))),
            'can_edit' => $edit,
        ];
    }

    public static function createUnit(array $actx, int $subjectId, array $in): array
    {
        self::subject($subjectId);
        self::assertEditSubject($actx['auth'], $subjectId);
        $order = $in['sort_order'] ?? ((int) DB::table('edu_units')->where('subject_id', $subjectId)->max('sort_order') + 1);
        $fields = self::only($in, self::UNIT_FIELDS);
        $id = DB::table('edu_units')->insertGetId(['subject_id' => $subjectId, 'sort_order' => $order] + $fields);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_unit', $id, ['created' => $in['title'], 'subject' => $subjectId]);
        $u = DB::table('edu_units')->where('id', $id)->first();
        $detail = self::subjectDetail($actx['auth'], $subjectId);
        return [
            'id' => (int) $id,
            'unit' => self::serializeUnit($u),
        ] + $detail;
    }

    public static function updateUnit(array $actx, int $id, array $in): array
    {
        $u = self::unit($id);
        self::assertEditSubject($actx['auth'], (int) $u->subject_id);
        $patch = self::only($in, self::UNIT_FIELDS);
        if ($patch) DB::table('edu_units')->where('id', $id)->update($patch);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_unit', $id, ['fields' => array_keys($patch)]);
        $detail = self::subjectDetail($actx['auth'], (int) $u->subject_id);
        $updated = DB::table('edu_units')->where('id', $id)->first();
        return [
            'id' => (int) $id,
            'unit' => self::serializeUnit($updated),
        ] + $detail;
    }

    /** Removing a unit keeps its lessons (they move out of any unit). */
    public static function deleteUnit(array $actx, int $id): array
    {
        $u = self::unit($id);
        self::assertEditSubject($actx['auth'], (int) $u->subject_id);
        DB::table('edu_units')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_unit', $id, ['deleted' => $u->title]);
        return self::subjectDetail($actx['auth'], (int) $u->subject_id);
    }

    public static function reorderUnits(array $actx, int $subjectId, array $ids): array
    {
        self::assertEditSubject($actx['auth'], $subjectId);
        self::reorder($actx, 'edu_units', $ids, ['subject_id' => $subjectId]);
        return self::subjectDetail($actx['auth'], $subjectId);
    }

    private const LESSON_FIELDS = ['unit_id', 'title', 'title_en', 'summary', 'summary_en', 'body', 'body_en', 'scripture_refs', 'objectives', 'objectives_en', 'teacher_notes', 'est_minutes', 'status', 'sort_order', 'is_mandatory', 'requires_quiz'];

    private static function assertUnitOf(?int $unitId, int $subjectId): void
    {
        if ($unitId && (int) self::unit($unitId)->subject_id !== $subjectId) throw ApiError::field('unit_id', 'UNIT_NOT_FOUND');
    }

    public static function createLesson(array $actx, int $subjectId, array $in): array
    {
        $s = self::subject($subjectId);
        self::assertEditSubject($actx['auth'], $subjectId);
        self::assertUnitOf($in['unit_id'] ?? null, $subjectId);
        $in['sort_order'] ??= (int) DB::table('edu_lessons')->where('subject_id', $subjectId)->max('sort_order') + 1;
        $row = self::only($in, self::LESSON_FIELDS) + ['subject_id' => $subjectId, 'author_id' => $actx['auth']->id, 'updated_by' => $actx['auth']->id];
        if (($row['status'] ?? 'draft') === 'published') $row['published_at'] = Dates::sql(Dates::now());
        $id = DB::table('edu_lessons')->insertGetId($row);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson', $id, ['created' => $in['title'], 'subject' => $subjectId, 'status' => $row['status'] ?? 'draft']);
        if (($row['status'] ?? 'draft') === 'published') self::notifyLesson($s, $id, $in['title'], $actx['auth']->id);
        return self::lessonDetail($actx['auth'], $id);
    }

    public static function updateLesson(array $actx, int $id, array $in): array
    {
        $l = self::lesson($id);
        self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        if (array_key_exists('unit_id', $in)) self::assertUnitOf($in['unit_id'], (int) $l->subject_id);
        $patch = self::only($in, self::LESSON_FIELDS);
        $publishing = ($patch['status'] ?? null) === 'published' && $l->status !== 'published';
        if ($publishing && ! $l->published_at) $patch['published_at'] = Dates::sql(Dates::now());
        if ($patch) DB::table('edu_lessons')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson', $id, ['fields' => array_keys($patch), 'status' => $patch['status'] ?? $l->status]);
        // Told once: the first time a lesson is published.
        if ($publishing && ! $l->published_at) self::notifyLesson(self::subject((int) $l->subject_id), $id, $patch['title'] ?? $l->title, $actx['auth']->id);
        return self::lessonDetail($actx['auth'], $id);
    }

    /** A lesson somebody already studied is archived, never deleted (their progress stays). */
    public static function deleteLesson(array $actx, int $id): void
    {
        $l = self::lesson($id);
        self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        if (DB::table('edu_lesson_progress')->where('lesson_id', $id)->exists() || DB::table('edu_quizzes')->where('lesson_id', $id)->exists()) {
            throw ApiError::conflict('HAS_RECORDS', 'Students have opened this lesson; archive it instead');
        }
        $files = DB::table('edu_lesson_materials')->where('lesson_id', $id)->whereNotNull('path')->pluck('path')->all();
        DB::table('edu_lessons')->where('id', $id)->delete();
        foreach ($files as $f) Storage::remove($f);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson', $id, ['deleted' => $l->title]);
    }

    public static function reorderLessons(array $actx, int $subjectId, array $ids): array
    {
        self::assertEditSubject($actx['auth'], $subjectId);
        self::reorder($actx, 'edu_lessons', $ids, ['subject_id' => $subjectId]);
        return self::subjectDetail($actx['auth'], $subjectId);
    }

    private static function notifyLesson(object $s, int $lessonId, string $title, int $actorId): void
    {
        if ($s->status !== 'published') return;
        $ids = [];
        foreach (DB::table('edu_courses')->where('subject_id', $s->id)->get() as $course) {
            $ids = array_merge($ids, Edu::rosterQuery($course)->pluck('u.id')->all());
        }
        $ids = array_values(array_diff(array_unique(array_map('intval', $ids)), [$actorId]));
        if (! $ids) return;
        $n = Notifications::createForUsers($ids, [
            'type' => 'education',
            'title' => T::t('edu.lesson.title'),
            'body' => T::t('edu.lesson.body', ['title' => $title, 'subject' => $s->name]),
            'entityType' => 'edu_lesson',
            'entityId' => $lessonId,
            'dedupeKey' => fn ($uid) => "edu:lesson:$lessonId:$uid",
        ]);
        if ($n) Notifications::kick();
    }

    // ---- materials ----
    private static function nextMaterialOrder(int $lessonId): int
    {
        return (int) DB::table('edu_lesson_materials')->where('lesson_id', $lessonId)->max('sort_order') + 1;
    }

    public static function addMaterialFile(array $actx, int $lessonId, UploadedFile $file, ?string $title): array
    {
        $l = self::lesson($lessonId);
        self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        $saved = Storage::save('lesson', Storage::FOLDERS['EDU_LESSONS'], $file);
        $name = mb_substr((string) $file->getClientOriginalName(), 0, 255) ?: null;
        $id = DB::table('edu_lesson_materials')->insertGetId([
            'lesson_id' => $lessonId, 'kind' => 'file', 'title' => $title ?: ($name ? pathinfo($name, PATHINFO_FILENAME) : 'File'),
            'path' => $saved['path'], 'original_name' => $name, 'mime' => $saved['mime'], 'size' => $saved['size'], 'sha256' => $saved['sha256'],
            'sort_order' => self::nextMaterialOrder($lessonId), 'uploaded_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson_material', $id, ['lesson' => $lessonId, 'file' => $saved['mime']]);
        return self::serializeMaterial(self::material($id));
    }

    public static function addMaterialLink(array $actx, int $lessonId, array $in): array
    {
        $l = self::lesson($lessonId);
        self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        $id = DB::table('edu_lesson_materials')->insertGetId([
            'lesson_id' => $lessonId, 'kind' => $in['kind'], 'title' => $in['title'], 'url' => $in['url'],
            'sort_order' => self::nextMaterialOrder($lessonId), 'uploaded_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson_material', $id, ['lesson' => $lessonId, 'link' => $in['kind']]);
        return self::serializeMaterial(self::material($id));
    }

    public static function updateMaterial(array $actx, int $id, array $in): array
    {
        $m = self::material($id);
        if ($m->lesson_id) {
            $l = self::lesson((int) $m->lesson_id);
            self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        } else {
            self::assertEditor($actx['auth']);
        }
        $patch = self::only($in, ['title', 'title_en', 'description', 'description_en', 'sort_order', 'status']);
        if ($m->kind !== 'file' && isset($in['url'])) $patch['url'] = $in['url'];
        if ($patch) DB::table('edu_lesson_materials')->where('id', $id)->update($patch);
        return self::serializeMaterial(self::material($id));
    }

    public static function deleteMaterial(array $actx, int $id): void
    {
        $m = self::material($id);
        if ($m->lesson_id) {
            $l = self::lesson((int) $m->lesson_id);
            self::assertEditSubject($actx['auth'], (int) $l->subject_id);
        } else {
            self::assertEditor($actx['auth']);
        }
        DB::table('edu_lesson_materials')->where('id', $id)->delete();
        if ($m->path) Storage::remove($m->path);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson_material', $id, ['deleted' => $m->title]);
    }

    // ---- direct course materials (Feature B) ----
    public static function addDirectMaterialFile(array $actx, array $meta, UploadedFile $file): array
    {
        self::assertEditor($actx['auth']);
        $categoryId = ! empty($meta['category_id']) ? (int) $meta['category_id'] : null;
        if ($categoryId && ! DB::table('edu_categories')->where('id', $categoryId)->exists()) {
            throw ApiError::field('category_id', 'CATEGORY_NOT_FOUND');
        }
        $subjectId = ! empty($meta['subject_id']) ? (int) $meta['subject_id'] : null;
        if ($subjectId && ! DB::table('edu_subjects')->where('id', $subjectId)->exists()) {
            throw ApiError::field('subject_id', 'SUBJECT_NOT_FOUND');
        }
        $grade = ! empty($meta['grade']) ? (int) $meta['grade'] : null;
        if ($grade !== null && ($grade < 1 || $grade > 12)) {
            throw ApiError::field('grade', 'INVALID_GRADE');
        }
        $title = ! empty($meta['title']) ? mb_substr(trim($meta['title']), 0, 200) : null;
        $saved = Storage::save('lesson', Storage::FOLDERS['EDU_LESSONS'], $file);
        $name = mb_substr((string) $file->getClientOriginalName(), 0, 255) ?: null;
        $order = (int) DB::table('edu_lesson_materials')
            ->whereNull('lesson_id')
            ->when($categoryId, fn ($q) => $q->where('category_id', $categoryId))
            ->when($grade, fn ($q) => $q->where('grade', $grade))
            ->max('sort_order') + 1;

        $id = DB::table('edu_lesson_materials')->insertGetId([
            'lesson_id' => null,
            'category_id' => $categoryId,
            'subject_id' => $subjectId,
            'grade' => $grade,
            'kind' => 'file',
            'title' => $title ?: ($name ? pathinfo($name, PATHINFO_FILENAME) : 'File'),
            'title_en' => ! empty($meta['title_en']) ? mb_substr(trim($meta['title_en']), 0, 200) : null,
            'description' => ! empty($meta['description']) ? mb_substr(trim($meta['description']), 0, 2000) : null,
            'description_en' => ! empty($meta['description_en']) ? mb_substr(trim($meta['description_en']), 0, 2000) : null,
            'path' => $saved['path'],
            'original_name' => $name,
            'mime' => $saved['mime'],
            'size' => $saved['size'],
            'sha256' => $saved['sha256'],
            'sort_order' => $order,
            'status' => in_array($meta['status'] ?? '', ['draft', 'published', 'archived'], true) ? $meta['status'] : 'published',
            'uploaded_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson_material', $id, ['direct' => true, 'category_id' => $categoryId, 'grade' => $grade]);
        return self::serializeMaterial(self::material($id));
    }

    public static function addDirectMaterialLink(array $actx, array $meta): array
    {
        self::assertEditor($actx['auth']);
        $categoryId = ! empty($meta['category_id']) ? (int) $meta['category_id'] : null;
        if ($categoryId && ! DB::table('edu_categories')->where('id', $categoryId)->exists()) {
            throw ApiError::field('category_id', 'CATEGORY_NOT_FOUND');
        }
        $subjectId = ! empty($meta['subject_id']) ? (int) $meta['subject_id'] : null;
        if ($subjectId && ! DB::table('edu_subjects')->where('id', $subjectId)->exists()) {
            throw ApiError::field('subject_id', 'SUBJECT_NOT_FOUND');
        }
        $grade = ! empty($meta['grade']) ? (int) $meta['grade'] : null;
        if ($grade !== null && ($grade < 1 || $grade > 12)) {
            throw ApiError::field('grade', 'INVALID_GRADE');
        }
        $order = (int) DB::table('edu_lesson_materials')
            ->whereNull('lesson_id')
            ->when($categoryId, fn ($q) => $q->where('category_id', $categoryId))
            ->when($grade, fn ($q) => $q->where('grade', $grade))
            ->max('sort_order') + 1;

        $id = DB::table('edu_lesson_materials')->insertGetId([
            'lesson_id' => null,
            'category_id' => $categoryId,
            'subject_id' => $subjectId,
            'grade' => $grade,
            'kind' => in_array($meta['kind'] ?? '', ['link', 'video_link'], true) ? $meta['kind'] : 'link',
            'title' => mb_substr(trim($meta['title'] ?? 'Link'), 0, 200),
            'title_en' => ! empty($meta['title_en']) ? mb_substr(trim($meta['title_en']), 0, 200) : null,
            'description' => ! empty($meta['description']) ? mb_substr(trim($meta['description']), 0, 2000) : null,
            'description_en' => ! empty($meta['description_en']) ? mb_substr(trim($meta['description_en']), 0, 2000) : null,
            'url' => trim($meta['url']),
            'sort_order' => $order,
            'status' => in_array($meta['status'] ?? '', ['draft', 'published', 'archived'], true) ? $meta['status'] : 'published',
            'uploaded_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_lesson_material', $id, ['direct' => true, 'category_id' => $categoryId, 'grade' => $grade]);
        return self::serializeMaterial(self::material($id));
    }

    public static function directMaterials(AuthContext $auth, int $categoryId, int $gradeNumber): array
    {
        $editor = self::isEditor($auth);
        if (! $editor) {
            $assignedGrades = self::studentAssignedGrades($auth->id);
            if (! empty($assignedGrades) && ! in_array($gradeNumber, $assignedGrades, true)) {
                throw ApiError::forbidden('GRADE_ACCESS_DENIED', 'You are not enrolled in Grade ' . $gradeNumber);
            }
        }
        $q = DB::table('edu_lesson_materials')
            ->whereNull('lesson_id')
            ->where('category_id', $categoryId)
            ->where('grade', $gradeNumber);

        if (! $editor) {
            $q->where('status', 'published');
        }

        return $q->orderBy('sort_order')->orderBy('id')->get()->map(fn ($m) => self::serializeMaterial($m))->all();
    }

    public static function allMaterials(AuthContext $auth, array $params = []): array
    {
        $q = DB::table('edu_lesson_materials as m')
            ->leftJoin('edu_lessons as l', 'l.id', '=', 'm.lesson_id')
            ->leftJoin('edu_subjects as s', 's.id', '=', 'l.subject_id')
            ->select('m.*', 'l.title as lesson_title', 's.id as subject_id', 's.name as subject_name');

        if (! empty($params['subject_id'])) {
            $q->where(function ($w) use ($params) {
                $w->where('m.subject_id', (int) $params['subject_id'])
                  ->orWhere('s.id', (int) $params['subject_id']);
            });
        }

        if (! empty($params['kind'])) {
            $q->where('m.kind', $params['kind']);
        }

        if (! empty($params['search'])) {
            $search = '%' . $params['search'] . '%';
            $q->where(function ($w) use ($search) {
                $w->where('m.title', 'like', $search)
                  ->orWhere('l.title', 'like', $search);
            });
        }

        // Authorization check: if not editor, only show materials from subjects the user can open
        if (! self::isEditor($auth)) {
            $studying = self::studyingSubjectIds($auth->id);
            $teaching = self::teachingSubjectIds($auth->id);
            $allowed = array_unique(array_merge($studying, $teaching));
            $q->where(function ($w) use ($allowed) {
                $w->whereIn('s.id', $allowed ?: [0])
                  ->orWhereIn('m.subject_id', $allowed ?: [0]);
            });
        }

        return $q->orderByDesc('m.id')->limit(200)->get()->map(fn ($row) => [
            'id' => (int) $row->id,
            'lesson_id' => $row->lesson_id ? (int) $row->lesson_id : null,
            'lesson_title' => $row->lesson_title ?? null,
            'subject_id' => $row->subject_id ? (int) $row->subject_id : null,
            'subject_name' => $row->subject_name ?? null,
            'title' => $row->title,
            'kind' => $row->kind,
            'mime' => $row->mime ?? null,
            'size' => $row->size !== null ? (int) $row->size : null,
            'url' => $row->url ?? null,
            'sort_order' => (int) ($row->sort_order ?? 0),
        ])->all();
    }

    // ---- featured banner (content editors) ----
    private const FEATURED_FIELDS = ['target_type', 'target_id', 'title', 'subtitle', 'starts_at', 'ends_at', 'sort_order', 'is_active'];

    private static function assertFeaturedTarget(string $type, int $id): void
    {
        $table = ['subject' => 'edu_subjects', 'lesson' => 'edu_lessons', 'class' => 'edu_classes'][$type];
        if (! DB::table($table)->where('id', $id)->exists()) throw ApiError::field('target_id', 'TARGET_NOT_FOUND');
    }

    public static function createFeatured(array $actx, array $in): array
    {
        self::assertEditor($actx['auth']);
        self::assertFeaturedTarget($in['target_type'], (int) $in['target_id']);
        $in['sort_order'] ??= (int) DB::table('edu_featured')->max('sort_order') + 1;
        $id = DB::table('edu_featured')->insertGetId(self::only($in, self::FEATURED_FIELDS) + ['created_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_featured', $id, ['target' => "{$in['target_type']}:{$in['target_id']}"]);
        
        $bannerTitle = $in['title'] ?? 'አዲስ የትምህርት ማስታወቂያ';
        Notifications::sendToAll([
            'type' => 'education',
            'title' => "የትምህርት ማስታወቂያ: {$bannerTitle}",
            'body' => $in['subtitle'] ?? 'አዲስ የትምህርት ማስታወቂያ ወጥቷል። ዝርዝሩን በትምህርት መነሻ ገጽ መመልከት ይችላሉ።',
            'entityType' => 'edu_featured',
            'entityId' => $id,
            'dedupeKey' => fn (int $uid) => "edu_featured:{$id}:{$uid}",
        ]);
        return self::featured($actx['auth'], true);
    }

    public static function updateFeatured(array $actx, int $id, array $in): array
    {
        self::assertEditor($actx['auth']);
        $f = DB::table('edu_featured')->where('id', $id)->first();
        if (! $f) throw ApiError::notFound('FEATURED_NOT_FOUND', 'Not found');
        if (isset($in['target_type']) || isset($in['target_id'])) self::assertFeaturedTarget($in['target_type'] ?? $f->target_type, (int) ($in['target_id'] ?? $f->target_id));
        $patch = self::only($in, self::FEATURED_FIELDS);
        if ($patch) DB::table('edu_featured')->where('id', $id)->update($patch);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_featured', $id, ['fields' => array_keys($patch)]);
        return self::featured($actx['auth'], true);
    }

    public static function setFeaturedImage(array $actx, int $id, ?UploadedFile $file): array
    {
        self::assertEditor($actx['auth']);
        $f = DB::table('edu_featured')->where('id', $id)->first();
        if (! $f) throw ApiError::notFound('FEATURED_NOT_FOUND', 'Not found');
        $saved = $file ? Storage::save('image', Storage::FOLDERS['EDU_IMAGES'], $file) : null;
        DB::table('edu_featured')->where('id', $id)->update(['image' => $saved['path'] ?? null]);
        if ($f->image) Storage::remove($f->image);
        return self::featured($actx['auth'], true);
    }

    public static function deleteFeatured(array $actx, int $id): array
    {
        self::assertEditor($actx['auth']);
        $f = DB::table('edu_featured')->where('id', $id)->first();
        if (! $f) throw ApiError::notFound('FEATURED_NOT_FOUND', 'Not found');
        DB::table('edu_featured')->where('id', $id)->delete();
        if ($f->image) Storage::remove($f->image);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_featured', $id, ['deleted' => true]);
        return self::featured($actx['auth'], true);
    }

    /** Subjects a teacher (or editor) may write lessons for — the authoring list. */
    public static function editableSubjects(AuthContext $auth): array
    {
        return array_values(array_filter(self::subjects($auth, null, true), fn ($s) => $s['can_edit']));
    }

    private static function only(array $in, array $keys): array
    {
        $out = array_intersect_key($in, array_flip($keys));
        foreach (['sequential', 'is_active'] as $b) if (array_key_exists($b, $out)) $out[$b] = $out[$b] ? 1 : 0;
        return $out;
    }
}
