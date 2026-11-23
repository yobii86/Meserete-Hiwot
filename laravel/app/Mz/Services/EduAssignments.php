<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Storage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class EduAssignments
{
    public const STATUSES = ['draft', 'published', 'archived'];
    public const SUBMISSION_STATUSES = ['submitted', 'graded', 'returned', 'resubmitted'];

    // ------------------------------------------------------------------ lookups
    public static function assignment(int $id): object
    {
        $a = DB::table('edu_assignments')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Assignment not found');
        return $a;
    }

    public static function bridgeLegacySubmission(object $leg): object
    {
        $att = [];
        if (! empty($leg->file)) {
            $att[] = [
                'kind' => 'file',
                'name' => $leg->file_name ?? 'attachment',
                'path' => $leg->file,
            ];
        }
        return (object) [
            'id' => (int) $leg->id,
            'assignment_id' => (int) $leg->assignment_id,
            'user_id' => (int) $leg->user_id,
            'text_response' => $leg->text ?? null,
            'attachments' => ! empty($att) ? json_encode($att, JSON_UNESCAPED_UNICODE) : null,
            'score' => $leg->score ?? null,
            'feedback' => $leg->feedback ?? null,
            'graded_by' => $leg->graded_by ?? null,
            'graded_at' => $leg->graded_at ?? null,
            'status' => ! empty($leg->graded_at) ? 'returned' : 'submitted',
            'is_late' => (int) ($leg->is_late ?? 0),
            'submitted_at' => $leg->submitted_at ?? null,
            'released_at' => $leg->graded_at ?? null,
            'created_at' => $leg->submitted_at ?? null,
            'updated_at' => $leg->graded_at ?? $leg->submitted_at ?? null,
        ];
    }

    public static function submission(int $id): object
    {
        $s = DB::table('edu_assignment_submissions')->where('id', $id)->first();
        if (! $s && Schema::hasTable('edu_submissions')) {
            $leg = DB::table('edu_submissions')->where('id', $id)->first();
            if ($leg) {
                return self::bridgeLegacySubmission($leg);
            }
        }
        if (! $s) throw ApiError::notFound('SUBMISSION_NOT_FOUND', 'Submission not found');
        return $s;
    }

    public static function canManageAssignment(AuthContext $auth, object $a): bool
    {
        if (EduLearning::isEditor($auth)) return true;
        if ((int) $a->teacher_id === $auth->id) return true;
        if (! empty($a->course_id) && EduTeachers::isActive((int) $a->course_id, $auth->id)) return true;
        if (! empty($a->subject_id) && EduLearning::canEditSubject($auth, (int) $a->subject_id)) return true;
        if (! empty($a->class_id) && Schema::hasTable('edu_class_staff') && DB::table('edu_class_staff')->where(['class_id' => $a->class_id, 'user_id' => $auth->id])->exists()) return true;
        if (! empty($a->course_id) && Schema::hasTable('edu_class_staff')) {
            $course = DB::table('edu_courses')->where('id', $a->course_id)->first();
            if ($course && ! empty($course->class_id) && DB::table('edu_class_staff')->where(['class_id' => $course->class_id, 'user_id' => $auth->id])->exists()) {
                return true;
            }
        }
        return false;
    }

    public static function canViewAssignment(AuthContext $auth, object $a): bool
    {
        if (self::canManageAssignment($auth, $a)) return true;
        if ($a->status !== 'published') return false;

        if (! empty($a->course_id)) {
            $myCourseIds = Edu::myCourseIds($auth->id);
            if (in_array((int) $a->course_id, $myCourseIds, true)) return true;
        }

        if (! empty($a->class_id)) {
            $hasActiveEnrollment = DB::table('edu_enrollments')
                ->where(['class_id' => $a->class_id, 'user_id' => $auth->id, 'status' => 'active'])
                ->exists();
            if ($hasActiveEnrollment) return true;
        }

        if (! empty($a->grade)) {
            $assignedGrades = EduLearning::studentAssignedGrades($auth->id);
            if (in_array((int) $a->grade, $assignedGrades, true)) return true;
        }

        if (! empty($a->subject_id) && EduLearning::isEnrolledInSubject($auth->id, (int) $a->subject_id)) {
            return true;
        }

        return false;
    }

    private static function assertCanManage(AuthContext $auth, object $a): void
    {
        if (! self::canManageAssignment($auth, $a)) {
            throw ApiError::forbidden('NOT_ASSIGNMENT_TEACHER', 'You are not authorized to manage this assignment');
        }
    }

    private static function assertCanView(AuthContext $auth, object $a): void
    {
        if (! self::canViewAssignment($auth, $a)) {
            throw ApiError::forbidden('ASSIGNMENT_ACCESS_DENIED', 'You do not have access to this assignment');
        }
    }

    // ------------------------------------------------------------------ serialization
    public static function serializeAssignment(object $a): array
    {
        $teacherId = $a->teacher_id ?? $a->created_by ?? null;
        $teacher = $teacherId ? DB::table('users')->where('id', $teacherId)->first() : null;
        $course = ! empty($a->course_id) ? DB::table('edu_courses')->where('id', $a->course_id)->first() : null;
        $class = ! empty($a->class_id) ? DB::table('edu_classes')->where('id', $a->class_id)->first() : null;
        $subject = ! empty($a->subject_id) ? DB::table('edu_subjects')->where('id', $a->subject_id)->first() : null;

        $attachments = ! empty($a->attachments) ? (is_array($a->attachments) ? $a->attachments : json_decode($a->attachments, true)) : [];

        return [
            'id' => (int) $a->id,
            'course_id' => ! empty($a->course_id) ? (int) $a->course_id : null,
            'course_name' => $course?->name,
            'class_id' => ! empty($a->class_id) ? (int) $a->class_id : null,
            'class_name' => $class?->name,
            'subject_id' => ! empty($a->subject_id) ? (int) $a->subject_id : null,
            'subject_name' => $subject?->name,
            'grade' => ! empty($a->grade) ? (int) $a->grade : null,
            'teacher_id' => (int) ($teacherId ?? 0),
            'teacher_name' => $teacher?->full_name ?? 'Teacher',
            'title' => $a->title,
            'title_en' => $a->title_en ?? null,
            'instructions' => $a->instructions,
            'instructions_en' => $a->instructions_en ?? null,
            'attachments' => $attachments ?? [],
            'max_score' => (float) Num::n($a->max_score ?? 100),
            'due_at' => $a->due_at,
            'status' => $a->status ?? 'published',
            'allow_late' => (bool) ($a->allow_late ?? true),
            'allow_resubmit' => (bool) ($a->allow_resubmit ?? true),
            'created_at' => $a->created_at ?? null,
            'updated_at' => $a->updated_at ?? null,
        ];
    }

    public static function serializeSubmission(object $s, bool $hideGradeIfNotReleased = false): array
    {
        $student = DB::table('users')->where('id', $s->user_id)->first();
        $grader = ! empty($s->graded_by) ? DB::table('users')->where('id', $s->graded_by)->first() : null;
        $attachments = ! empty($s->attachments) ? (is_array($s->attachments) ? $s->attachments : json_decode($s->attachments, true)) : [];

        $released = ! empty($s->released_at);
        $showGrade = ! $hideGradeIfNotReleased || $released;

        $versions = [];
        if (Schema::hasTable('edu_submissions') && Schema::hasTable('edu_submission_versions')) {
            $baseSub = DB::table('edu_submissions')
                ->where(['assignment_id' => $s->assignment_id, 'user_id' => $s->user_id])
                ->first();
            if ($baseSub) {
                $versions = DB::table('edu_submission_versions')
                    ->where('submission_id', $baseSub->id)
                    ->orderByDesc('id')
                    ->get()
                    ->map(fn ($v) => [
                        'id' => (int) $v->id,
                        'submission_id' => (int) $v->submission_id,
                        'text' => $v->text,
                        'file' => $v->file,
                        'file_name' => $v->file_name,
                        'submitted_at' => $v->submitted_at,
                        'is_late' => (bool) $v->is_late,
                    ])
                    ->all();
            }
        }

        return [
            'id' => (int) $s->id,
            'assignment_id' => (int) $s->assignment_id,
            'user_id' => (int) $s->user_id,
            'student_name' => $student?->full_name,
            'text_response' => $s->text_response,
            'attachments' => $attachments ?? [],
            'submitted_at' => $s->submitted_at,
            'is_late' => (bool) $s->is_late,
            'status' => $s->status,
            'score' => $showGrade && $s->score !== null ? (float) Num::n($s->score) : null,
            'feedback' => $s->feedback, // Formative feedback remains visible so student can read teacher's remarks
            'graded_by' => $showGrade && $grader ? $grader->full_name : null,
            'graded_at' => $showGrade ? $s->graded_at : null,
            'released_at' => $s->released_at,
            'versions' => $versions,
        ];
    }

    // ------------------------------------------------------------------ teacher operations
    public static function create(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        $courseId = ! empty($in['course_id']) ? (int) $in['course_id'] : null;
        $classId = ! empty($in['class_id']) ? (int) $in['class_id'] : null;
        $subjectId = ! empty($in['subject_id']) ? (int) $in['subject_id'] : null;
        $grade = ! empty($in['grade']) ? (int) $in['grade'] : null;

        // Authorization check
        if (! EduLearning::isEditor($auth)) {
            if ($courseId) {
                if (! EduTeachers::isActive($courseId, $auth->id)) {
                    throw ApiError::forbidden('NOT_COURSE_TEACHER', 'You are not assigned to teach this course');
                }
            } elseif ($subjectId) {
                if (! EduLearning::canEditSubject($auth, $subjectId)) {
                    throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You are not authorized to assign work for this subject');
                }
            } elseif ($classId) {
                $teachesClass = DB::table('edu_courses as co')
                    ->join('edu_course_teachers as ct', 'ct.course_id', '=', 'co.id')
                    ->where(['co.class_id' => $classId, 'ct.user_id' => $auth->id, 'ct.status' => 'active'])
                    ->exists();
                if (! $teachesClass) {
                    throw ApiError::forbidden('NOT_CLASS_TEACHER', 'You do not teach any courses in this class');
                }
            } else {
                throw ApiError::forbidden('SCOPE_REQUIRED', 'Course, class, or subject scope is required');
            }
        }

        $maxScore = isset($in['max_score']) ? (float) $in['max_score'] : 100.0;
        if ($maxScore <= 0 || $maxScore > 1000) {
            throw ApiError::field('max_score', 'INVALID_MAX_SCORE');
        }

        $dueAt = ! empty($in['due_at']) ? Dates::sql($in['due_at']) : null;
        $status = in_array($in['status'] ?? '', self::STATUSES, true) ? $in['status'] : 'published';

        $id = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId,
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'grade' => $grade,
            'teacher_id' => $auth->id,
            'title' => trim($in['title']),
            'title_en' => ! empty($in['title_en']) ? trim($in['title_en']) : null,
            'instructions' => ! empty($in['instructions']) ? trim($in['instructions']) : null,
            'instructions_en' => ! empty($in['instructions_en']) ? trim($in['instructions_en']) : null,
            'attachments' => ! empty($in['attachments']) ? json_encode($in['attachments'], JSON_UNESCAPED_UNICODE) : null,
            'max_score' => $maxScore,
            'due_at' => $dueAt,
            'status' => $status,
            'allow_late' => isset($in['allow_late']) ? (bool) $in['allow_late'] : true,
            'allow_resubmit' => isset($in['allow_resubmit']) ? (bool) $in['allow_resubmit'] : true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_assignment', $id, ['created' => $in['title'], 'status' => $status]);

        if ($status === 'published') {
            self::notifyRecipients($id, trim($in['title']), $courseId, $classId, $grade, $subjectId);
        }

        return self::serializeAssignment(self::assignment($id));
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $a = self::assignment($id);
        self::assertCanManage($actx['auth'], $a);

        $updates = [];
        foreach (['title', 'title_en', 'instructions', 'instructions_en', 'status', 'allow_late', 'allow_resubmit'] as $k) {
            if (array_key_exists($k, $in)) {
                $updates[$k] = $in[$k];
            }
        }
        if (isset($in['max_score'])) {
            $maxScore = (float) $in['max_score'];
            if ($maxScore <= 0 || $maxScore > 1000) throw ApiError::field('max_score', 'INVALID_MAX_SCORE');
            $updates['max_score'] = $maxScore;
        }
        if (array_key_exists('due_at', $in)) {
            $updates['due_at'] = ! empty($in['due_at']) ? Dates::sql($in['due_at']) : null;
        }
        if (array_key_exists('attachments', $in)) {
            $updates['attachments'] = ! empty($in['attachments']) ? json_encode($in['attachments'], JSON_UNESCAPED_UNICODE) : null;
        }

        if ($updates) {
            $updates['updated_at'] = now();
            DB::table('edu_assignments')->where('id', $id)->update($updates);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_assignment', $id, ['updates' => array_keys($updates)]);
        }

        if (($updates['status'] ?? null) === 'published' && $a->status !== 'published') {
            self::notifyRecipients($id, $updates['title'] ?? $a->title, (int) $a->course_id, (int) $a->class_id, (int) $a->grade, (int) $a->subject_id);
        }

        return self::serializeAssignment(self::assignment($id));
    }

    public static function delete(array $actx, int $id): void
    {
        $a = self::assignment($id);
        self::assertCanManage($actx['auth'], $a);

        DB::table('edu_assignment_submissions')->where('assignment_id', $id)->delete();
        DB::table('edu_assignments')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_assignment', $id, ['deleted' => $a->title]);
    }

    // ------------------------------------------------------------------ student operations
    public static function studentList(AuthContext $auth, ?int $courseId = null): array
    {
        $myCourseIds = Edu::myCourseIds($auth->id);
        $assignedGrades = EduLearning::studentAssignedGrades($auth->id);
        $studyingSubjectIds = EduLearning::studyingSubjectIds($auth->id);

        if (empty($myCourseIds) && empty($assignedGrades) && empty($studyingSubjectIds)) {
            return [];
        }

        $hasGradeCol = Schema::hasColumn('edu_assignments', 'grade');
        $hasSubjectCol = Schema::hasColumn('edu_assignments', 'subject_id');
        $q = DB::table('edu_assignments as a')
            ->where('a.status', 'published')
            ->where(function ($w) use ($myCourseIds, $assignedGrades, $studyingSubjectIds, $hasGradeCol, $hasSubjectCol) {
                if (! empty($myCourseIds)) $w->orWhereIn('a.course_id', $myCourseIds);
                if ($hasGradeCol && ! empty($assignedGrades)) $w->orWhereIn('a.grade', $assignedGrades);
                if ($hasSubjectCol && ! empty($studyingSubjectIds)) $w->orWhereIn('a.subject_id', $studyingSubjectIds);
            });

        if ($courseId) {
            $q->where('a.course_id', $courseId);
        }

        $assignments = $q->orderByRaw('a.due_at IS NULL')->orderBy('a.due_at')->orderByDesc('a.id')->get();
        if ($assignments->isEmpty()) return [];

        $assignmentIds = $assignments->pluck('id')->all();
        $submissions = DB::table('edu_assignment_submissions')
            ->where('user_id', $auth->id)
            ->whereIn('assignment_id', $assignmentIds)
            ->get()
            ->keyBy('assignment_id');

        $legacySubs = Schema::hasTable('edu_submissions')
            ? DB::table('edu_submissions')
                ->where('user_id', $auth->id)
                ->whereIn('assignment_id', $assignmentIds)
                ->get()
                ->keyBy('assignment_id')
            : collect();

        $now = Dates::sql(Dates::now());

        return $assignments->map(function ($a) use ($submissions, $legacySubs, $now) {
            $sub = $submissions->get($a->id) ?? ($legacySubs->has($a->id) ? self::bridgeLegacySubmission($legacySubs->get($a->id)) : null);
            $ser = self::serializeAssignment($a);

            // Derive presentation state
            $statusGroup = 'assigned';
            $isSubmitted = $sub !== null;
            $isGraded = $sub && ! empty($sub->released_at);

            if ($isSubmitted) {
                $statusGroup = $isGraded ? 'graded' : 'turned_in';
            } else {
                if ($a->due_at) {
                    if (Dates::sql($a->due_at) < $now) {
                        $statusGroup = 'overdue';
                    } elseif (Dates::sql(Dates::of($now)->modify('+2 days')) >= Dates::sql($a->due_at)) {
                        $statusGroup = 'due_soon';
                    } else {
                        $statusGroup = 'upcoming';
                    }
                }
            }

            return $ser + [
                'status_group' => $statusGroup,
                'my_submission' => $sub ? self::serializeSubmission($sub, true) : null,
            ];
        })->all();
    }

    public static function studentDetail(AuthContext $auth, int $id): array
    {
        $a = self::assignment($id);
        self::assertCanView($auth, $a);

        $sub = DB::table('edu_assignment_submissions')
            ->where(['assignment_id' => $id, 'user_id' => $auth->id])
            ->first();

        if (! $sub && Schema::hasTable('edu_submissions')) {
            $leg = DB::table('edu_submissions')
                ->where(['assignment_id' => $id, 'user_id' => $auth->id])
                ->first();
            if ($leg) {
                $sub = self::bridgeLegacySubmission($leg);
            }
        }

        $canManage = self::canManageAssignment($auth, $a);

        return self::serializeAssignment($a) + [
            'can_manage' => $canManage,
            'my_submission' => $sub ? self::serializeSubmission($sub, ! $canManage) : null,
        ];
    }

    public static function submit(AuthContext $auth, int $id, array $in, ?UploadedFile $file = null): array
    {
        $a = self::assignment($id);
        self::assertCanView($auth, $a);
        if ($a->status !== 'published') {
            throw ApiError::forbidden('ASSIGNMENT_NOT_OPEN', 'This assignment is not published');
        }

        $now = Dates::sql(Dates::now());
        $isLate = false;
        if ($a->due_at && Dates::sql($a->due_at) < $now) {
            if (! $a->allow_late) {
                throw ApiError::conflict('ASSIGNMENT_PAST_DUE', 'The deadline for this assignment has passed');
            }
            $isLate = true;
        }

        $existing = DB::table('edu_assignment_submissions')
            ->where(['assignment_id' => $id, 'user_id' => $auth->id])
            ->first();

        if (! $existing && Schema::hasTable('edu_submissions')) {
            $legacyExisting = DB::table('edu_submissions')
                ->where(['assignment_id' => $id, 'user_id' => $auth->id])
                ->first();
            if ($legacyExisting) {
                $existing = self::bridgeLegacySubmission($legacyExisting);
            }
        }

        if ($existing && ! $a->allow_resubmit && $existing->status === 'graded') {
            throw ApiError::conflict('RESUBMISSION_DISALLOWED', 'Resubmission is not permitted for this assignment');
        }

        $textInput = ! empty($in['text_response']) ? $in['text_response'] : ($in['text'] ?? null);
        $textResponse = is_string($textInput) && trim($textInput) !== '' ? trim($textInput) : $existing?->text_response;

        $attachments = ! empty($in['attachments']) ? $in['attachments'] : ($existing?->attachments ? (is_array($existing->attachments) ? $existing->attachments : json_decode($existing->attachments, true)) : []);
        if ($file) {
            $saved = Storage::save('assignment', Storage::FOLDERS['EDU_LESSONS'], $file);
            $attachments[] = [
                'kind' => 'file',
                'name' => $file->getClientOriginalName(),
                'path' => $saved['path'],
                'mime' => $saved['mime'],
                'size' => $saved['size'],
            ];
        }

        if (empty($textResponse) && empty($attachments) && ! $file) {
            throw ApiError::badRequest('EMPTY_SUBMISSION', 'Please enter your written answer or upload a file.');
        }

        $row = [
            'assignment_id' => $id,
            'user_id' => $auth->id,
            'text_response' => $textResponse,
            'attachments' => ! empty($attachments) ? json_encode($attachments, JSON_UNESCAPED_UNICODE) : null,
            'submitted_at' => $now,
            'is_late' => $isLate ? 1 : ($existing?->is_late ?? 0),
            'status' => $existing ? 'resubmitted' : 'submitted',
            'created_at' => $existing?->created_at ?? $now,
            'updated_at' => $now,
        ];

        DB::table('edu_assignment_submissions')->upsert(
            [$row],
            ['assignment_id', 'user_id'],
            ['text_response', 'attachments', 'submitted_at', 'is_late', 'status', 'updated_at']
        );

        EduDashboard::invalidateUserDashboard($auth->id);

        // Maintain immutable version history in edu_submissions and edu_submission_versions
        if (Schema::hasTable('edu_submissions')) {
            $groupId = null;
            if (! empty($a->is_group) && ! empty($a->course_id) && Schema::hasTable('edu_group_members') && Schema::hasTable('edu_groups')) {
                $groupId = DB::table('edu_group_members as gm')
                    ->join('edu_groups as g', 'g.id', '=', 'gm.group_id')
                    ->where('gm.user_id', $auth->id)
                    ->where('g.course_id', $a->course_id)
                    ->value('g.id');
            }

            $primarySub = DB::table('edu_submissions')
                ->where(['assignment_id' => $id, 'user_id' => $auth->id])
                ->first();
            $subData = [
                'assignment_id' => $id,
                'user_id' => $auth->id,
                'group_id' => $groupId,
                'text' => $row['text_response'],
                'file' => $file ? $saved['path'] : ($primarySub->file ?? null),
                'file_name' => $file ? $file->getClientOriginalName() : ($primarySub->file_name ?? null),
                'is_late' => $row['is_late'],
                'submitted_at' => $now,
            ];
            if ($primarySub) {
                DB::table('edu_submissions')->where('id', $primarySub->id)->update($subData);
                $subId = $primarySub->id;
            } else {
                $subId = DB::table('edu_submissions')->insertGetId($subData);
            }

            if (Schema::hasTable('edu_submission_versions')) {
                DB::table('edu_submission_versions')->insert([
                    'submission_id' => $subId,
                    'text' => $row['text_response'],
                    'file' => $file ? $saved['path'] : ($primarySub->file ?? null),
                    'file_name' => $file ? $file->getClientOriginalName() : ($primarySub->file_name ?? null),
                    'submitted_at' => $now,
                    'is_late' => $row['is_late'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        $sub = DB::table('edu_assignment_submissions')
            ->where(['assignment_id' => $id, 'user_id' => $auth->id])
            ->first();

        // Notify teacher of submission
        Notifications::createForUsers([(int) $a->teacher_id], [
            'type' => 'education',
            'title' => "የተማሪ የቤት ሥራ ምላሽ: {$a->title}",
            'body' => "ተማሪ {$auth->user?->full_name} ለ'{$a->title}' ምላሽ አስገብቷል።",
            'entityType' => 'edu_assignment',
            'entityId' => $id,
            'dedupeKey' => fn (int $uid) => "edu_sub:{$id}:{$auth->id}:" . date('YmdH'),
        ]);

        return self::serializeSubmission($sub, true);
    }

    // ------------------------------------------------------------------ teacher grading
    public static function teacherList(AuthContext $auth, ?int $courseId = null): array
    {
        $q = DB::table('edu_assignments as a');
        if (! EduLearning::isEditor($auth)) {
            $q->where(function ($w) use ($auth) {
                $w->where('a.teacher_id', $auth->id);
                $teachingCourses = EduTeachers::myActiveCourses($auth->id);
                if (! empty($teachingCourses)) {
                    $w->orWhereIn('a.course_id', $teachingCourses);
                }
            });
        }

        if ($courseId) {
            $q->where('a.course_id', $courseId);
        }

        $rows = $q->orderByDesc('a.id')->get();
        if ($rows->isEmpty()) return [];

        $assignmentIds = $rows->pluck('id')->all();
        $counts = DB::table('edu_assignment_submissions')
            ->whereIn('assignment_id', $assignmentIds)
            ->select('assignment_id',
                DB::raw('COUNT(*) as total_submitted'),
                DB::raw("SUM(CASE WHEN released_at IS NOT NULL THEN 1 ELSE 0 END) as total_graded"))
            ->groupBy('assignment_id')
            ->get()
            ->keyBy('assignment_id');

        $legacyCounts = Schema::hasTable('edu_submissions')
            ? DB::table('edu_submissions')
                ->whereIn('assignment_id', $assignmentIds)
                ->select('assignment_id',
                    DB::raw('COUNT(*) as total_submitted'),
                    DB::raw("SUM(CASE WHEN graded_at IS NOT NULL THEN 1 ELSE 0 END) as total_graded"))
                ->groupBy('assignment_id')
                ->get()
                ->keyBy('assignment_id')
            : collect();

        return $rows->map(function ($a) use ($counts, $legacyCounts) {
            $c = $counts->get($a->id);
            $leg = $legacyCounts->get($a->id);
            $totalSub = max((int) ($c?->total_submitted ?? 0), (int) ($leg?->total_submitted ?? 0));
            $totalGraded = max((int) ($c?->total_graded ?? 0), (int) ($leg?->total_graded ?? 0));
            return self::serializeAssignment($a) + [
                'submissions_count' => $totalSub,
                'graded_count' => $totalGraded,
            ];
        })->all();
    }

    public static function listSubmissions(AuthContext $auth, int $assignmentId): array
    {
        $a = self::assignment($assignmentId);
        self::assertCanManage($auth, $a);

        $subs = DB::table('edu_assignment_submissions as s')
            ->where('s.assignment_id', $assignmentId)
            ->orderBy('s.submitted_at')
            ->get();

        $seenUserIds = $subs->pluck('user_id')->all();
        if (Schema::hasTable('edu_submissions')) {
            $legacy = DB::table('edu_submissions as s')
                ->where('s.assignment_id', $assignmentId)
                ->whereNotIn('s.user_id', $seenUserIds ?: [0])
                ->get();
            foreach ($legacy as $leg) {
                $subs->push(self::bridgeLegacySubmission($leg));
            }
        }

        return $subs->map(fn ($s) => self::serializeSubmission($s, false))->all();
    }

    public static function gradeSubmission(array $actx, int $submissionId, float $score, ?string $feedback = null, bool $release = true): array
    {
        $s = self::submission($submissionId);
        $a = self::assignment((int) $s->assignment_id);
        self::assertCanManage($actx['auth'], $a);

        if ($score < 0 || $score > (float) Num::n($a->max_score)) {
            throw ApiError::field('score', 'SCORE_OUT_OF_RANGE');
        }

        $now = Dates::sql(Dates::now());
        $updates = [
            'score' => $score,
            'feedback' => $feedback !== null ? trim($feedback) : null,
            'graded_by' => $actx['auth']->id,
            'graded_at' => $now,
            'status' => $release ? 'returned' : 'graded',
            'released_at' => $release ? $now : null,
            'updated_at' => $now,
        ];

        $existsModern = DB::table('edu_assignment_submissions')->where('id', $submissionId)->exists();
        if ($existsModern) {
            DB::table('edu_assignment_submissions')->where('id', $submissionId)->update($updates);
        } else {
            DB::table('edu_assignment_submissions')->upsert([
                [
                    'assignment_id' => $s->assignment_id,
                    'user_id' => $s->user_id,
                    'text_response' => $s->text_response ?? null,
                    'attachments' => is_array($s->attachments) ? json_encode($s->attachments) : $s->attachments,
                    'score' => $updates['score'],
                    'feedback' => $updates['feedback'],
                    'graded_by' => $updates['graded_by'],
                    'graded_at' => $updates['graded_at'],
                    'status' => $updates['status'],
                    'released_at' => $updates['released_at'],
                    'submitted_at' => $s->submitted_at ?? $now,
                    'is_late' => $s->is_late ?? 0,
                    'created_at' => $s->submitted_at ?? $now,
                    'updated_at' => $now,
                ]
            ], ['assignment_id', 'user_id'], ['score', 'feedback', 'graded_by', 'graded_at', 'status', 'released_at', 'updated_at']);
        }

        if (Schema::hasTable('edu_submissions')) {
            DB::table('edu_submissions')
                ->where('assignment_id', $s->assignment_id)
                ->where('user_id', $s->user_id)
                ->update([
                    'score' => $score,
                    'feedback' => $updates['feedback'],
                    'graded_by' => $updates['graded_by'],
                    'graded_at' => $updates['graded_at'],
                ]);
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_assignment_submission', $submissionId, ['score' => $score, 'release' => $release]);

        if ($release) {
            Notifications::createForUsers([(int) $s->user_id], [
                'type' => 'education',
                'title' => "የቤት ሥራ ውጤት: {$a->title}",
                'body' => "ለ'{$a->title}' የተሰጠ ውጤት፦ {$score}/{$a->max_score}",
                'entityType' => 'edu_assignment',
                'entityId' => (int) $a->id,
                'dedupeKey' => fn (int $uid) => "edu_grade:{$submissionId}:{$uid}",
            ]);
        }

        return self::serializeSubmission(self::submission($submissionId), false);
    }

    public static function releaseGrades(array $actx, int $assignmentId): array
    {
        $a = self::assignment($assignmentId);
        self::assertCanManage($actx['auth'], $a);

        $now = Dates::sql(Dates::now());
        $unreleased = DB::table('edu_assignment_submissions')
            ->where('assignment_id', $assignmentId)
            ->whereNotNull('score')
            ->whereNull('released_at')
            ->get();

        if ($unreleased->isEmpty()) {
            return ['released' => 0];
        }

        DB::table('edu_assignment_submissions')
            ->whereIn('id', $unreleased->pluck('id')->all())
            ->update([
                'released_at' => $now,
                'status' => 'returned',
                'updated_at' => $now,
            ]);

        if (Schema::hasTable('edu_submissions')) {
            foreach ($unreleased as $sub) {
                DB::table('edu_submissions')
                    ->where('assignment_id', $sub->assignment_id)
                    ->where('user_id', $sub->user_id)
                    ->update(['graded_at' => $now]);
            }
        }

        foreach ($unreleased as $sub) {
            Notifications::createForUsers([(int) $sub->user_id], [
                'type' => 'education',
                'title' => "የቤት ሥራ ውጤት: {$a->title}",
                'body' => "ለ'{$a->title}' የተሰጠ ውጤት፦ {$sub->score}/{$a->max_score}",
                'entityType' => 'edu_assignment',
                'entityId' => $assignmentId,
                'dedupeKey' => fn (int $uid) => "edu_grade:{$sub->id}:{$uid}",
            ]);
        }

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_assignment', $assignmentId, ['released_count' => $unreleased->count()]);
        return ['released' => $unreleased->count()];
    }

    // ------------------------------------------------------------------ helper notifications
    private static function notifyRecipients(int $assignmentId, string $title, ?int $courseId, ?int $classId, ?int $grade, ?int $subjectId): void
    {
        $studentIds = [];
        if ($courseId) {
            $studentIds = DB::table('edu_course_enrollments')
                ->where('course_id', $courseId)
                ->whereIn('status', ['added', 'enrolled', 'retake', 'distance'])
                ->pluck('user_id')
                ->all();
        } elseif ($classId) {
            $studentIds = DB::table('edu_enrollments')
                ->where('class_id', $classId)
                ->where('status', 'active')
                ->pluck('user_id')
                ->all();
        } elseif ($grade) {
            $hasGradeCol = Schema::hasColumn('edu_classes', 'grade');
            $studentIds = DB::table('edu_enrollments as e')
                ->join('edu_classes as c', 'c.id', '=', 'e.class_id')
                ->when($hasGradeCol, function ($q) use ($grade) {
                    $q->where('c.grade', $grade);
                }, function ($q) use ($grade) {
                    $q->where(function ($sub) use ($grade) {
                        $sub->where('c.level_id', $grade)
                            ->orWhere('c.name', 'like', "{$grade}ኛ%")
                            ->orWhere('c.name', 'like', "Grade {$grade}%");
                    });
                })
                ->where('e.status', 'active')
                ->pluck('e.user_id')
                ->unique()
                ->all();
        } elseif ($subjectId) {
            $studentIds = DB::table('edu_course_enrollments as ce')
                ->join('edu_courses as co', 'co.id', '=', 'ce.course_id')
                ->where('co.subject_id', $subjectId)
                ->whereIn('ce.status', ['added', 'enrolled', 'retake', 'distance'])
                ->pluck('ce.user_id')
                ->unique()
                ->all();
        }

        if (! empty($studentIds)) {
            Notifications::createForUsers($studentIds, [
                'type' => 'education',
                'title' => "አዲስ የቤት ሥራ: {$title}",
                'body' => "አዲስ የተሰጠ የቤት ሥራ አለ። በመተግበሪያው ገብተው ይመልከቱ።",
                'entityType' => 'edu_assignment',
                'entityId' => $assignmentId,
                'dedupeKey' => fn (int $uid) => "edu_assign:{$assignmentId}:{$uid}",
            ]);
        }
    }
}
