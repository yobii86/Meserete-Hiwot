<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Who teaches a subject (edu_courses = the subjects of a class). Any active member can be made a
 * teacher of one subject without changing their role anywhere else — a student of one class can
 * teach in another. Assignments are kept with who assigned them and when; suspending or removing
 * one keeps the row (history). Only an ACTIVE assignment lets a teacher see the roster and enter or
 * submit marks. edu_courses.teacher_user_id stays the subject's main teacher for older screens.
 */
final class EduTeachers
{
    public const STATUSES = ['active', 'suspended', 'removed'];

    /** Does $userId currently teach $courseId? */
    public static function isActive(int $courseId, int $userId): bool
    {
        return DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $userId, 'status' => 'active'])->exists();
    }

    public static function list(int $courseId): array
    {
        return DB::table('edu_course_teachers as t')->join('users as u', 'u.id', '=', 't.user_id')
            ->leftJoin('users as a', 'a.id', '=', 't.assigned_by')->leftJoin('users as ch', 'ch.id', '=', 't.changed_by')
            ->where('t.course_id', $courseId)
            ->select('t.id', 't.course_id', 't.user_id', 'u.full_name', 't.status', 't.assigned_at', 'a.full_name as assigned_by_name', 't.changed_at', 'ch.full_name as changed_by_name', 't.note')
            ->orderByRaw("FIELD(t.status, 'active', 'suspended', 'removed')")->orderByDesc('t.assigned_at')->get()->all();
    }

    /** The subjects the signed-in member teaches (active assignments), with their class. Moderators see all active courses. */
    public static function teaching(AuthContext $auth): array
    {
        $q = DB::table('edu_courses as co')->join('edu_classes as c', 'c.id', '=', 'co.class_id');

        // If not a moderator/admin, restrict strictly to active teacher assignments
        if (! Edu::isModerator($auth)) {
            $q->join('edu_course_teachers as t', 'co.id', '=', 't.course_id')
              ->where(['t.user_id' => $auth->id, 't.status' => 'active']);
        }

        return $q->select('co.id', 'co.name', 'co.code', 'co.status', 'c.id as class_id', 'c.name as class_name', 'c.academic_year', 'c.semester',
                DB::raw("(SELECT COUNT(*) FROM edu_assessments a JOIN edu_scores s ON s.assessment_id = a.id WHERE a.course_id = co.id AND s.status = 'rejected') as rejected_marks"),
                DB::raw("(SELECT COUNT(*) FROM edu_assessments a JOIN edu_scores s ON s.assessment_id = a.id WHERE a.course_id = co.id AND s.status = 'submitted') as submitted_marks"))
            ->orderBy('c.name')->orderBy('co.name')->get()->all();
    }

    private static function assertMember(int $userId): void
    {
        if (! DB::table('users')->where(['id' => $userId, 'status' => 'active'])->whereNull('deleted_at')->exists()) {
            throw ApiError::validation([['field' => 'user_id', 'code' => 'USER_NOT_FOUND', 'message' => 'USER_NOT_FOUND']]);
        }
    }

    public static function assign(array $actx, int $courseId, int $userId, ?string $note = null, bool $notify = true): array
    {
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        self::assertMember($userId);
        $by = $actx['auth']->id;
        DB::transaction(function () use ($actx, $course, $courseId, $userId, $note, $by) {
            $open = DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $userId])->where('status', '<>', 'removed')->lockForUpdate()->first();
            if ($open) throw ApiError::conflict('ALREADY_ASSIGNED', 'This member is already assigned to this subject');
            $id = DB::table('edu_course_teachers')->insertGetId(['course_id' => $courseId, 'user_id' => $userId, 'status' => 'active', 'assigned_by' => $by, 'assigned_at' => Dates::sql(Dates::now()), 'note' => $note]);
            if (! $course->teacher_user_id) DB::table('edu_courses')->where('id', $courseId)->update(['teacher_user_id' => $userId]);
            EduJourney::record($userId, 'teacher_assigned', ['class_id' => $course->class_id, 'course_id' => $courseId, 'ref_type' => 'edu_course_teacher', 'ref_id' => $id, 'reason' => $note], $by);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $courseId, ['teacher_assigned' => $userId, 'note' => $note], inTrx: true);
        });
        if ($notify) self::notify($userId, $course);
        return self::list($courseId);
    }

    /** Suspend, reactivate or remove an assignment (the row is kept as history). */
    public static function setStatus(array $actx, int $assignmentId, string $status, ?string $note): array
    {
        $row = DB::table('edu_course_teachers')->where('id', $assignmentId)->first();
        if (! $row) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Teacher assignment not found');
        if ($row->status === 'removed') throw ApiError::conflict('ASSIGNMENT_REMOVED', 'A removed assignment cannot be changed; assign the member again');
        if ($row->status === $status) return self::list((int) $row->course_id);
        $by = $actx['auth']->id;
        DB::transaction(function () use ($actx, $row, $status, $note, $by) {
            DB::table('edu_course_teachers')->where('id', $row->id)->update(['status' => $status, 'changed_by' => $by, 'changed_at' => Dates::sql(Dates::now()), 'note' => $note ?? $row->note]);
            $course = DB::table('edu_courses')->where('id', $row->course_id)->lockForUpdate()->first();
            // The main teacher leaves: another active teacher (if any) takes the place.
            if ($status !== 'active' && (int) $course->teacher_user_id === (int) $row->user_id) {
                $next = DB::table('edu_course_teachers')->where(['course_id' => $row->course_id, 'status' => 'active'])->where('id', '<>', $row->id)->orderBy('assigned_at')->value('user_id');
                DB::table('edu_courses')->where('id', $row->course_id)->update(['teacher_user_id' => $next]);
            }
            if ($status === 'active' && ! $course->teacher_user_id) DB::table('edu_courses')->where('id', $row->course_id)->update(['teacher_user_id' => $row->user_id]);
            $event = ['active' => 'teacher_reactivated', 'suspended' => 'teacher_suspended', 'removed' => 'teacher_removed'][$status];
            EduJourney::record((int) $row->user_id, $event, ['class_id' => $course->class_id, 'course_id' => $row->course_id, 'ref_type' => 'edu_course_teacher', 'ref_id' => $row->id, 'old' => $row->status, 'new' => $status, 'reason' => $note], $by);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $row->course_id, ['teacher' => $row->user_id, 'from' => $row->status, 'to' => $status, 'note' => $note], inTrx: true);
        });
        return self::list((int) $row->course_id);
    }

    /**
     * Keep the assignments in step when the main teacher is set through the subject form: the new
     * main teacher gets an active assignment, the former one is removed (kept as history).
     */
    public static function syncMain(array $actx, int $courseId, ?int $newUserId, ?int $oldUserId): void
    {
        if ($newUserId === $oldUserId && (! $newUserId || self::isActive($courseId, $newUserId))) return;
        $by = $actx['auth']->id;
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if ($oldUserId) {
            $old = DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $oldUserId])->where('status', '<>', 'removed')->first();
            if ($old) {
                DB::table('edu_course_teachers')->where('id', $old->id)->update(['status' => 'removed', 'changed_by' => $by, 'changed_at' => Dates::sql(Dates::now()), 'note' => 'replaced as main teacher']);
                EduJourney::record($oldUserId, 'teacher_removed', ['class_id' => $course->class_id, 'course_id' => $courseId, 'ref_type' => 'edu_course_teacher', 'ref_id' => $old->id, 'old' => $old->status, 'new' => 'removed'], $by);
            }
        }
        // Chosen again while suspended: the assignment becomes active again.
        $suspended = $newUserId ? DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $newUserId, 'status' => 'suspended'])->first() : null;
        if ($suspended) {
            DB::table('edu_course_teachers')->where('id', $suspended->id)->update(['status' => 'active', 'changed_by' => $by, 'changed_at' => Dates::sql(Dates::now())]);
            EduJourney::record($newUserId, 'teacher_reactivated', ['class_id' => $course->class_id, 'course_id' => $courseId, 'ref_type' => 'edu_course_teacher', 'ref_id' => $suspended->id, 'old' => 'suspended', 'new' => 'active'], $by);
        }
        if ($newUserId && ! DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $newUserId])->where('status', '<>', 'removed')->exists()) {
            $id = DB::table('edu_course_teachers')->insertGetId(['course_id' => $courseId, 'user_id' => $newUserId, 'status' => 'active', 'assigned_by' => $by, 'assigned_at' => Dates::sql(Dates::now())]);
            EduJourney::record($newUserId, 'teacher_assigned', ['class_id' => $course->class_id, 'course_id' => $courseId, 'ref_type' => 'edu_course_teacher', 'ref_id' => $id], $by);
        }
    }

    private static function notify(int $userId, object $course): void
    {
        $class = DB::table('edu_classes')->where('id', $course->class_id)->value('name');
        $stamp = (int) floor(microtime(true) * 1000);
        $n = Notifications::createForUsers([$userId], [
            'type' => 'education',
            'title' => T::t('edu.teacher.title'),
            'body' => T::t('edu.teacher.body', ['course' => $course->name, 'class' => $class]),
            'entityType' => 'edu_course',
            'entityId' => $course->id,
            'dedupeKey' => fn ($uid) => "edu:teacher:{$course->id}:$uid:$stamp",
        ]);
        if ($n) Notifications::kick();
    }
}
