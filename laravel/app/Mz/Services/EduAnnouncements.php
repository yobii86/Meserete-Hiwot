<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class EduAnnouncements
{
    public const STATUSES = ['draft', 'published', 'archived'];

    public static function announcement(int $id): object
    {
        $a = DB::table('edu_announcements')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('ANNOUNCEMENT_NOT_FOUND', 'Announcement not found');
        return $a;
    }

    public static function canManage(AuthContext $auth, object $a): bool
    {
        if (EduLearning::isEditor($auth)) return true;
        if ((int) $a->teacher_id === $auth->id) return true;
        if (! empty($a->course_id) && EduTeachers::isActive((int) $a->course_id, $auth->id)) return true;
        if (! empty($a->subject_id) && EduLearning::canEditSubject($auth, (int) $a->subject_id)) return true;
        return false;
    }

    public static function canView(AuthContext $auth, object $a): bool
    {
        if (self::canManage($auth, $a)) return true;
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
        if (! self::canManage($auth, $a)) {
            throw ApiError::forbidden('NOT_ANNOUNCEMENT_TEACHER', 'You are not authorized to manage this announcement');
        }
    }

    private static function assertCanView(AuthContext $auth, object $a): void
    {
        if (! self::canView($auth, $a)) {
            throw ApiError::forbidden('ANNOUNCEMENT_ACCESS_DENIED', 'You do not have access to this announcement');
        }
    }

    public static function serialize(object $a): array
    {
        $teacher = DB::table('users')->where('id', $a->teacher_id)->first();
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
            'teacher_id' => (int) $a->teacher_id,
            'teacher_name' => $teacher?->full_name ?? 'Teacher',
            'title' => $a->title,
            'title_en' => $a->title_en,
            'body' => $a->body,
            'body_en' => $a->body_en,
            'attachments' => $attachments ?? [],
            'status' => $a->status,
            'published_at' => $a->published_at,
            'created_at' => $a->created_at,
            'updated_at' => $a->updated_at,
        ];
    }

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
                    throw ApiError::forbidden('NOT_SUBJECT_EDITOR', 'You are not authorized to post announcements for this subject');
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

        $status = in_array($in['status'] ?? '', self::STATUSES, true) ? $in['status'] : 'published';
        $now = Dates::sql(Dates::now());

        $id = DB::table('edu_announcements')->insertGetId([
            'course_id' => $courseId,
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'grade' => $grade,
            'teacher_id' => $auth->id,
            'title' => ! empty($in['title']) ? trim($in['title']) : null,
            'title_en' => ! empty($in['title_en']) ? trim($in['title_en']) : null,
            'body' => trim($in['body']),
            'body_en' => ! empty($in['body_en']) ? trim($in['body_en']) : null,
            'attachments' => ! empty($in['attachments']) ? json_encode($in['attachments'], JSON_UNESCAPED_UNICODE) : null,
            'status' => $status,
            'published_at' => $status === 'published' ? $now : null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_announcement', $id, ['title' => $in['title'] ?? null, 'status' => $status]);

        if ($status === 'published') {
            self::notifyRecipients($id, $in['title'] ?? 'አዲስ ማስታወቂያ', $courseId, $classId, $grade, $subjectId);
        }

        return self::serialize(self::announcement($id));
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $a = self::announcement($id);
        self::assertCanManage($actx['auth'], $a);

        $updates = [];
        foreach (['title', 'title_en', 'body', 'body_en', 'status'] as $k) {
            if (array_key_exists($k, $in)) {
                $updates[$k] = $in[$k];
            }
        }
        if (array_key_exists('attachments', $in)) {
            $updates['attachments'] = ! empty($in['attachments']) ? json_encode($in['attachments'], JSON_UNESCAPED_UNICODE) : null;
        }

        if ($updates) {
            $updates['updated_at'] = Dates::sql(Dates::now());
            if (($updates['status'] ?? null) === 'published' && ! $a->published_at) {
                $updates['published_at'] = Dates::sql(Dates::now());
            }
            DB::table('edu_announcements')->where('id', $id)->update($updates);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_announcement', $id, ['updates' => array_keys($updates)]);
        }

        if (($updates['status'] ?? null) === 'published' && $a->status !== 'published') {
            self::notifyRecipients($id, $updates['title'] ?? $a->title ?? 'አዲስ ማስታወቂያ', (int) $a->course_id, (int) $a->class_id, (int) $a->grade, (int) $a->subject_id);
        }

        return self::serialize(self::announcement($id));
    }

    public static function delete(array $actx, int $id): void
    {
        $a = self::announcement($id);
        self::assertCanManage($actx['auth'], $a);

        DB::table('edu_announcements')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_announcement', $id, ['deleted' => true]);
    }

    public static function detail(AuthContext $auth, int $id): array
    {
        $a = self::announcement($id);
        self::assertCanView($auth, $a);

        return self::serialize($a);
    }

    public static function feed(AuthContext $auth, ?int $courseId = null, ?int $classId = null): array
    {
        $myCourseIds = Edu::myCourseIds($auth->id);
        $assignedGrades = EduLearning::studentAssignedGrades($auth->id);
        $studyingSubjectIds = EduLearning::studyingSubjectIds($auth->id);

        if (empty($myCourseIds) && empty($assignedGrades) && empty($studyingSubjectIds)) {
            return [];
        }

        $q = DB::table('edu_announcements as a')
            ->where('a.status', 'published')
            ->where(function ($w) use ($myCourseIds, $assignedGrades, $studyingSubjectIds) {
                if (! empty($myCourseIds)) $w->orWhereIn('a.course_id', $myCourseIds);
                if (! empty($assignedGrades)) $w->orWhereIn('a.grade', $assignedGrades);
                if (! empty($studyingSubjectIds)) $w->orWhereIn('a.subject_id', $studyingSubjectIds);
            });

        if ($courseId) {
            $q->where('a.course_id', $courseId);
        }
        if ($classId) {
            $q->where('a.class_id', $classId);
        }

        return $q->orderByDesc('a.published_at')->orderByDesc('a.id')->get()->map(fn ($a) => self::serialize($a))->all();
    }

    public static function teacherList(AuthContext $auth, ?int $courseId = null): array
    {
        $q = DB::table('edu_announcements as a');
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

        return $q->orderByDesc('a.id')->get()->map(fn ($a) => self::serialize($a))->all();
    }

    private static function notifyRecipients(int $announcementId, string $title, ?int $courseId, ?int $classId, ?int $grade, ?int $subjectId): void
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
                'title' => "አዲስ የክፍል ማስታወቂያ: {$title}",
                'body' => "አዲስ ማስታወቂያ ተለጥፏል። በመተግበሪያው ገብተው ይመልከቱ።",
                'entityType' => 'edu_announcement',
                'entityId' => $announcementId,
                'dedupeKey' => fn (int $uid) => "edu_ann:{$announcementId}:{$uid}",
            ]);
        }
    }
}
