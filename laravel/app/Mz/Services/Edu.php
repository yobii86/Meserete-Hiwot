<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Http\Ctx;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use DateTimeImmutable;
use DateTimeInterface;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ትምህርት (education): classes with courses, weekly schedules, self-enrollment within a
 * registration window, attendance (manual or by QR), assignments with submissions and groups,
 * and assessments with scores (port of eduService.js). Roles are assignments, not account types.
 */
final class Edu
{
    private const CLASS_FIELDS = ['name', 'name_en', 'description', 'description_en', 'term', 'academic_year', 'semester', 'department_id', 'streams', 'registration_opens_at', 'registration_closes_at', 'allow_regular', 'allow_distance', 'allow_self_registration', 'capacity', 'status', 'academic_year_id', 'term_id', 'level_id', 'allow_multiple'];
    private const COURSE_FIELDS = ['name', 'code', 'description', 'teacher_user_id', 'status', 'subject_id', 'term_id', 'member_groups', 'mode', 'pass_mark'];

    /** A catalog subject given to a class subject must exist (it is never set automatically). */
    private static function assertSubject($subjectId): void
    {
        if ($subjectId && ! DB::table('edu_subjects')->where('id', $subjectId)->exists()) throw ApiError::field('subject_id', 'SUBJECT_NOT_FOUND');
    }

    public static function isModerator(?AuthContext $auth): bool
    {
        return (bool) ($auth?->isSuperAdmin() || $auth?->can('education.manage') || $auth?->can('education.content'));
    }

    private static function num($v): int|float|null
    {
        return $v === null ? null : Num::n($v);
    }

    private static function pick(array $fields, array $input): array
    {
        return array_intersect_key($input, array_flip($fields));
    }

    private static function strip(object $r): array
    {
        $a = (array) $r;
        $a['avatar_url'] = Storage::url($a['profile_image'] ?? null);
        unset($a['profile_image']);
        return $a;
    }

    // ------------------------------------------------------------------ access
    private static function getClass(int $id): object
    {
        $c = DB::table('edu_classes')->where('id', $id)->first();
        if (! $c) throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');
        return $c;
    }

    private static function getCourse(int $id): object
    {
        $c = DB::table('edu_courses')->where('id', $id)->first();
        if (! $c) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        return $c;
    }

    /** A teacher with an ACTIVE assignment to the subject (suspended / removed ones are refused), or an education administrator, or a subject editor. */
    private static function assertTeaches(AuthContext $auth, int $courseId): object
    {
        $c = self::getCourse($courseId);
        $canEditSubject = ! empty($c->subject_id) && EduLearning::canEditSubject($auth, (int) $c->subject_id);
        if (! self::isModerator($auth) && ! EduTeachers::isActive($courseId, $auth->id) && ! $canEditSubject) {
            throw ApiError::forbidden('NOT_TEACHER', 'Only the course teacher can do this');
        }
        return $c;
    }

    public static function assertTeachesCourse(AuthContext $auth, int $courseId): object
    {
        return self::assertTeaches($auth, $courseId);
    }

    /**
     * The students of a subject: the active students of its class who have not dropped it, plus
     * students who added it from elsewhere (edu_course_enrollments). Alias u (users), e (enrollment).
     */
    public static function rosterQuery(object $course)
    {
        $groups = ! empty($course->member_groups) ? array_filter(array_map('trim', explode(',', $course->member_groups))) : [];
        $validAdded = ['added', 'retake', 'distance', 'enrolled'];
        return DB::table('users as u')
            ->leftJoin('edu_enrollments as e', fn ($j) => $j->on('e.user_id', '=', 'u.id')->where('e.class_id', '=', $course->class_id)->where('e.status', '=', 'active'))
            ->leftJoin('edu_course_enrollments as ce', fn ($j) => $j->on('ce.user_id', '=', 'u.id')->where('ce.course_id', '=', $course->id))
            ->whereNull('u.deleted_at')
            ->where(function ($w) use ($groups, $validAdded) {
                $w->where(function ($x) use ($groups, $validAdded) {
                    $x->whereNotNull('e.id')
                      ->where(fn ($y) => $y->whereNull('ce.status')->orWhereIn('ce.status', $validAdded));
                    if (! empty($groups)) {
                        $x->whereIn('u.member_group', $groups);
                    }
                })->orWhereIn('ce.status', $validAdded);
            });
    }

    public static function onRoster(object $course, int $userId): bool
    {
        return self::rosterQuery($course)->where('u.id', $userId)->exists();
    }

    /**
     * Ids of the class subjects (edu_courses) a member takes — the same rule as [rosterQuery]: the
     * subjects of their active classes they have not dropped, plus subjects added from elsewhere.
     */
    public static function myCourseIds(int $userId): array
    {
        $validAdded = ['added', 'retake', 'distance', 'enrolled'];
        $hasCourseStatus = Schema::hasColumn('edu_courses', 'status');
        $fromClasses = DB::table('edu_courses as co')
            ->join('edu_enrollments as e', fn ($j) => $j->on('e.class_id', '=', 'co.class_id')->where('e.user_id', '=', $userId)->where('e.status', '=', 'active'))
            ->join('edu_classes as c', fn ($j) => $j->on('c.id', '=', 'co.class_id')->where('c.status', '=', 'active'))
            ->leftJoin('edu_course_enrollments as ce', fn ($j) => $j->on('ce.course_id', '=', 'co.id')->where('ce.user_id', '=', $userId))
            ->where(fn ($w) => $w->whereNull('ce.status')->orWhereIn('ce.status', $validAdded))
            ->when($hasCourseStatus, fn ($q) => $q->where('co.status', '=', 'active'))
            ->pluck('co.id')->all();
        $added = DB::table('edu_course_enrollments as ce')
            ->join('edu_courses as co', 'co.id', '=', 'ce.course_id')
            ->join('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->where('ce.user_id', $userId)
            ->whereIn('ce.status', $validAdded)
            ->where('c.status', '=', 'active')
            ->when($hasCourseStatus, fn ($q) => $q->where('co.status', '=', 'active'))
            ->pluck('ce.course_id')->all();
        return array_values(array_unique(array_map('intval', array_merge($fromClasses, $added))));
    }

    /** Ids of the class subjects the member actively teaches. */
    public static function myTeachingCourseIds(int $userId): array
    {
        return array_map('intval', DB::table('edu_course_teachers')->where(['user_id' => $userId, 'status' => 'active'])->pluck('course_id')->all());
    }

    private static function assertAttendance(AuthContext $auth, int $classId): void
    {
        $class = self::getClass($classId);
        if ($class->status !== 'active' && ! self::isModerator($auth)) {
            throw ApiError::forbidden('CLASS_CLOSED', 'This class is currently closed');
        }
        if (self::isModerator($auth) || $auth->can('attendance.manage')) return;
        if (DB::table('edu_class_staff')->where(['class_id' => $classId, 'user_id' => $auth->id])->exists()) return;
        if (! DB::table('edu_course_teachers as ct')->join('edu_courses as co', 'co.id', '=', 'ct.course_id')->where(['co.class_id' => $classId, 'ct.user_id' => $auth->id, 'ct.status' => 'active'])->exists()) throw ApiError::forbidden('NOT_ATTENDANCE_TAKER', 'You do not take attendance for this class');
    }

    private static function enrollment(int $classId, int $userId): ?object
    {
        return DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId, 'status' => 'active'])->first();
    }

    /** The student takes a subject of this class without being enrolled in it (added from another class). */
    private static function hasAddedSubject(int $classId, int $userId): bool
    {
        return DB::table('edu_course_enrollments as ce')->join('edu_courses as co', 'co.id', '=', 'ce.course_id')
            ->where(['co.class_id' => $classId, 'ce.user_id' => $userId, 'ce.status' => 'added'])->exists();
    }

    /** Teaches at least one subject of the class (an active assignment). */
    private static function teachesInClass(int $classId, int $userId): bool
    {
        return DB::table('edu_course_teachers as ct')->join('edu_courses as co', 'co.id', '=', 'ct.course_id')->where(['co.class_id' => $classId, 'ct.user_id' => $userId, 'ct.status' => 'active'])->exists();
    }

    private static function assertClassMember(AuthContext $auth, int $classId): void
    {
        $class = self::getClass($classId);
        if (self::isModerator($auth)) return;
        if ($class->status !== 'active') {
            throw ApiError::forbidden('CLASS_CLOSED', 'This class is currently closed');
        }
        if (self::enrollment($classId, $auth->id)) return;
        if (self::hasAddedSubject($classId, $auth->id)) return;
        if (DB::table('edu_course_teachers as ct')->join('edu_courses as co', 'co.id', '=', 'ct.course_id')->where(['co.class_id' => $classId, 'ct.user_id' => $auth->id, 'ct.status' => 'active'])->exists()) return;
        if (DB::table('edu_class_staff')->where(['class_id' => $classId, 'user_id' => $auth->id])->exists()) return;
        throw ApiError::forbidden('NOT_IN_CLASS', 'You are not part of this class');
    }

    // ------------------------------------------------------------------ serializers
    private static function registrationState(object $c, ?DateTimeInterface $now = null): string
    {
        $now ??= Dates::now();
        if ($c->status !== 'active') return 'closed';
        if (empty($c->allow_self_registration)) return 'closed';
        if ($c->registration_opens_at && $now < Dates::of($c->registration_opens_at)) return 'upcoming';
        if ($c->registration_closes_at && $now > Dates::of($c->registration_closes_at)) return 'closed';
        return 'open';
    }

    private static function serializeClass(object $c): array
    {
        $academicYear = null;
        if (! empty($c->academic_year_id)) {
            $ayName = $c->ay_name ?? null;
            $ayEthYear = isset($c->ay_eth_year) ? (int) $c->ay_eth_year : null;
            $ayIsCurrent = ! empty($c->ay_is_current);

            if (empty($ayName) && empty($ayEthYear)) {
                $y = DB::table('edu_academic_years')->where('id', $c->academic_year_id)->first();
                if ($y) {
                    $ayName = $y->name;
                    $ayEthYear = (int) $y->eth_year;
                    $ayIsCurrent = (bool) $y->is_current;
                }
            }

            if (! empty($ayName) || (! empty($ayEthYear) && $ayEthYear > 0)) {
                $academicYear = [
                    'id' => (int) $c->academic_year_id,
                    'eth_year' => $ayEthYear ?: (int) ($c->academic_year ?? 0),
                    'name' => $ayName ?: ($ayEthYear ? "{$ayEthYear} ዓ.ም" : (is_string($c->academic_year ?? null) ? $c->academic_year : '')),
                    'is_current' => $ayIsCurrent,
                ];
            }
        } elseif (! empty($c->academic_year) && is_string($c->academic_year)) {
            $ayStr = trim($c->academic_year);
            if ($ayStr !== '' && ! str_starts_with($ayStr, '{')) {
                $digits = (int) preg_replace('/\D/', '', $ayStr);
                $academicYear = [
                    'id' => null,
                    'eth_year' => $digits > 1900 ? $digits : 0,
                    'name' => $ayStr,
                    'is_current' => false,
                ];
            }
        }

        $termObj = null;
        $termStr = $c->term ?? null;
        if (! empty($c->term_id)) {
            $tmName = $c->tm_name ?? null;
            if (empty($tmName)) {
                $tRow = DB::table('edu_terms')->where('id', $c->term_id)->first();
                $tmName = $tRow?->name;
            }
            $termStr = $tmName ?: $termStr;
            $termObj = [
                'id' => (int) $c->term_id,
                'name' => $termStr ?? '',
            ];
        }

        $levelObj = null;
        $gradeStr = null;
        if (! empty($c->level_id)) {
            $lvlName = $c->lvl_name ?? null;
            if (empty($lvlName)) {
                $lvlRow = DB::table('edu_levels')->where('id', $c->level_id)->first();
                if ($lvlRow) {
                    $lvlName = $lvlRow->name;
                    $c->lvl_code = $lvlRow->code ?? '';
                    $c->lvl_name_en = $lvlRow->name_en ?? null;
                    $c->lvl_kind = $lvlRow->kind ?? 'grade';
                } else {
                    $lvlName = "{$c->level_id}ኛ ክፍል";
                }
            }
            $gradeStr = $lvlName;
            $levelObj = [
                'id' => (int) $c->level_id,
                'code' => $c->lvl_code ?? '',
                'name' => $lvlName,
                'name_en' => $c->lvl_name_en ?? null,
                'kind' => $c->lvl_kind ?? 'grade',
            ];
        }

        $cName = trim((string) ($c->name ?? ''));
        if ($cName === '' || str_starts_with($cName, '{')) {
            $cName = $gradeStr ?: ('ክፍል ' . $c->id);
        }

        $academicYearName = $academicYear ? $academicYear['name'] : (is_string($c->academic_year ?? null) ? $c->academic_year : null);

        $out = [
            'id' => (int) $c->id,
            'name' => $cName,
            'name_en' => $c->name_en ?? null,
            'description' => $c->description,
            'description_en' => $c->description_en ?? null,
            'term' => $termStr,
            'academic_year' => $academicYearName,
            'academic_year_obj' => $academicYear,
            'academic_year_id' => $c->academic_year_id ? (int) $c->academic_year_id : null,
            'term_id' => $c->term_id ? (int) $c->term_id : null,
            'term_obj' => $termObj,
            'level_id' => $c->level_id ? (int) $c->level_id : null,
            'level' => $levelObj,
            'grade' => $gradeStr,
            'allow_multiple' => (bool) ($c->allow_multiple ?? 0),
            'allow_self_registration' => (bool) ($c->allow_self_registration ?? false),
            'semester' => $c->semester ?? null,
            'department_id' => $c->department_id ? (int) $c->department_id : null,
            'streams' => ! empty($c->streams) ? array_values(array_filter(array_map('trim', explode(',', $c->streams)))) : [],
            'registration_opens_at' => $c->registration_opens_at,
            'registration_closes_at' => $c->registration_closes_at,
            'registration' => self::registrationState($c),
            'allow_regular' => (bool) $c->allow_regular,
            'allow_distance' => (bool) $c->allow_distance,
            'capacity' => $c->capacity !== null ? (int) $c->capacity : null,
            'status' => $c->status,
        ];
        if (property_exists($c, 'student_count')) $out['student_count'] = (int) $c->student_count;
        $out['my_program'] = $c->my_program ?? null;
        return $out;
    }

    private static function serializeCourse(object $c): array
    {
        $out = [
            'id' => (int) $c->id, 'class_id' => (int) $c->class_id, 'class_name' => $c->class_name ?? null, 'name' => $c->name, 'code' => $c->code ?? null, 'status' => $c->status ?? 'active', 'description' => $c->description,
            'subject_id' => isset($c->subject_id) && $c->subject_id !== null ? (int) $c->subject_id : null,
            'term_id' => isset($c->term_id) && $c->term_id !== null ? (int) $c->term_id : null,
            'member_groups' => $c->member_groups ?? null,
            'mode' => $c->mode ?? 'physical',
            'pass_mark' => isset($c->pass_mark) ? (float) $c->pass_mark : 50.0,
            'teacher' => $c->teacher_user_id ? ['id' => (int) $c->teacher_user_id, 'full_name' => $c->teacher_name ?? null] : null,
            'progress' => (int) ($c->progress ?? 0),
            'completed_at' => $c->completed_at ?? null,
        ];
        if (property_exists($c, 'student_count')) $out['student_count'] = (int) $c->student_count;
        if (property_exists($c, 'programs')) $out['programs'] = $c->programs;
        return $out;
    }

    private static function serializeSchedule(object $s): array
    {
        return [
            'id' => $s->id, 'class_id' => $s->class_id, 'course_id' => $s->course_id, 'course_name' => $s->course_name ?? null, 'weekday' => $s->weekday,
            'frequency' => $s->frequency ?? 'weekly', 'week_of_month' => $s->week_of_month ?? null, 'program' => $s->program ?? 'all', 'mode' => $s->mode ?? 'in_person',
            'starts' => $s->starts, 'ends' => $s->ends, 'location' => $s->location,
        ];
    }

    // ------------------------------------------------------------------ which days are class days
    /** Week of the (Ethiopian) month a date falls in: 1–4, or 5 when it is the last such weekday. */
    public static function weekOfMonth(string $date): array
    {
        $e = \App\Mz\Support\Ethiopian::ethiopianOfDate($date);
        $days = \App\Mz\Support\Ethiopian::daysInMonth($e['year'], $e['month']);
        return ['week' => intdiv($e['day'] - 1, 7) + 1, 'last' => $e['day'] + 7 > $days];
    }

    /** Does schedule row [s] meet on [date] for a student of [program] (regular / distance; null = anyone)? */
    public static function scheduleApplies(object $s, string $date, ?string $program = null, array $completed = []): bool
    {
        if ((int) $s->weekday !== (int) (new DateTimeImmutable($date))->format('N')) return false;
        $p = $s->program ?? 'all';
        if ($program !== null && $p !== 'all' && $p !== $program) return false;
        if (($s->frequency ?? 'weekly') === 'monthly' && $s->week_of_month) {
            $w = self::weekOfMonth($date);
            if ((int) $s->week_of_month === 5 ? ! $w['last'] : $w['week'] !== (int) $s->week_of_month) return false;
        }
        // A finished course has no more sessions.
        if ($s->course_id && isset($completed[(int) $s->course_id]) && $date > $completed[(int) $s->course_id]) return false;
        return true;
    }

    /**
     * The class sessions a student of [program] was expected at between two dates: sessions actually
     * held (attendance taken) on a scheduled day of theirs, and none after all the class's courses
     * are complete. A class without a schedule keeps the old rule (every session held).
     */
    public static function expectedDates(int $classId, ?string $program, string $from, string $to): array
    {
        $heldLegacy = array_map(fn ($d) => Dates::toDateOnly($d), DB::table('edu_attendance')->where('class_id', $classId)->whereBetween('session_date', [$from, $to])->distinct()->pluck('session_date')->all());
        $heldProgram = array_map(fn ($d) => Dates::toDateOnly($d), DB::table('attendance as a')->join('attendance_edu_classes as ac', 'ac.attendance_id', '=', 'a.id')->where('ac.class_id', $classId)->whereBetween('a.occurrence_date', [$from, $to])->distinct()->pluck('a.occurrence_date')->all());
        $progIds = DB::table('program_edu_classes')->where('class_id', $classId)->pluck('program_id')->all();
        $heldSessions = [];
        if ($progIds) {
            $heldSessions = array_map(fn ($d) => Dates::toDateOnly($d), DB::table('attendance_sessions')->whereIn('program_id', $progIds)->where('status', 'ended')->whereBetween('occurrence_date', [$from, $to])->distinct()->pluck('occurrence_date')->all());
        }
        $held = array_values(array_unique(array_merge($heldLegacy, $heldProgram, $heldSessions)));
        $rows = DB::table('edu_schedule')->where('class_id', $classId)->get()->all();
        $courses = DB::table('edu_courses')->where('class_id', $classId)->get(['id', 'completed_at'])->all();
        $completed = [];
        foreach ($courses as $c) {
            if ($c->completed_at) $completed[(int) $c->id] = Dates::toDateOnly($c->completed_at);
        }
        $allDoneAt = $courses && count($completed) === count($courses) ? max($completed) : null;
        $out = [];
        foreach (array_unique($held) as $d) {
            if ($allDoneAt && $d > $allDoneAt) continue;
            if ($rows) {
                $ok = false;
                foreach ($rows as $r) {
                    if (self::scheduleApplies($r, $d, $program, $completed)) {
                        $ok = true;
                        break;
                    }
                }
                if (! $ok) continue;
            }
            $out[] = $d;
        }
        sort($out);
        return $out;
    }

    private static function classCounts()
    {
        return DB::raw("(SELECT COUNT(*) FROM edu_enrollments e WHERE e.class_id = c.id AND e.status = 'active') as student_count");
    }

    // ------------------------------------------------------------------ moderator
    public static function adminClasses(?string $status = null, ?int $academicYearId = null): array
    {
        $q = DB::table('edu_classes as c')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
            ->leftJoin('edu_terms as tm', 'tm.id', '=', 'c.term_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->select('c.*', 'y.eth_year as ay_eth_year', 'y.name as ay_name', 'y.is_current as ay_is_current',
                     'tm.name as tm_name', 'lvl.code as lvl_code', 'lvl.name as lvl_name', 'lvl.name_en as lvl_name_en', 'lvl.kind as lvl_kind',
                     self::classCounts())
            ->orderBy('c.status')->orderBy('c.name');
        if ($status) $q->where('c.status', $status);
        if ($academicYearId) $q->where('c.academic_year_id', $academicYearId);
        return $q->get()->map(fn ($c) => self::serializeClass($c))->all();
    }

    public static function createClass(array $actx, array $input): array
    {
        $levelId = isset($input['level_id']) ? (int) $input['level_id'] : null;
        $yearId = isset($input['academic_year_id']) ? (int) $input['academic_year_id'] : null;
        $streamVal = isset($input['streams']) ? (is_array($input['streams']) ? implode(',', array_filter(array_map('trim', $input['streams']))) : (string) $input['streams']) : null;

        // Prevent duplicate grade-class records for the same academic year and stream/section
        if ($levelId && $yearId) {
            $dupeQ = DB::table('edu_classes')
                ->where('academic_year_id', $yearId)
                ->where('level_id', $levelId)
                ->where('status', '!=', 'archived');
            if ($streamVal !== null && $streamVal !== '') {
                $dupeQ->where('streams', $streamVal);
            } else {
                $dupeQ->where(fn ($w) => $w->whereNull('streams')->orWhere('streams', ''));
            }
            if ($dupeQ->exists()) {
                throw ApiError::conflict('DUPLICATE_GRADE_CLASS', 'An active class already exists for this grade level and academic year.');
            }
        }

        $id = DB::table('edu_classes')->insertGetId(self::pick(self::CLASS_FIELDS, self::streamsCsv($input)) + ['created_by' => $actx['auth']->id]);

        // Automatically connect official curriculum for this grade
        if ($levelId) {
            self::connectClassToCurriculum($id, $levelId);
        }

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $id, ['created' => $input['name']]);
        return self::classDetail($actx['auth'], $id);
    }

    public static function updateClass(array $actx, int $id, array $input): array
    {
        $before = self::getClass($id);
        $levelId = isset($input['level_id']) ? (int) $input['level_id'] : (int) ($before->level_id ?? 0);
        $yearId = isset($input['academic_year_id']) ? (int) $input['academic_year_id'] : (int) ($before->academic_year_id ?? 0);
        $streamVal = array_key_exists('streams', $input)
            ? (is_array($input['streams']) ? implode(',', array_filter(array_map('trim', $input['streams']))) : (string) $input['streams'])
            : ($before->streams ?? null);

        // Prevent duplicate grade-class conflicts on update
        if ($levelId && $yearId) {
            $dupeQ = DB::table('edu_classes')
                ->where('academic_year_id', $yearId)
                ->where('level_id', $levelId)
                ->where('id', '!=', $id)
                ->where('status', '!=', 'archived');
            if ($streamVal !== null && $streamVal !== '') {
                $dupeQ->where('streams', $streamVal);
            } else {
                $dupeQ->where(fn ($w) => $w->whereNull('streams')->orWhere('streams', ''));
            }
            if ($dupeQ->exists()) {
                throw ApiError::conflict('DUPLICATE_GRADE_CLASS', 'Another active class already exists for this grade level and academic year.');
            }
        }

        $patch = self::pick(self::CLASS_FIELDS, self::streamsCsv($input));
        if ($patch) DB::table('edu_classes')->where('id', $id)->update($patch);

        if ($levelId) {
            self::connectClassToCurriculum($id, $levelId);
        }

        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $id, ['fields' => array_keys($patch)]);
        return self::classDetail($actx['auth'], $id);
    }

    public static function standardizeCourseCode(int $grade, int $sequence): string
    {
        $g = max(1, min(12, $grade));
        $s = max(1, min(99, $sequence));
        return sprintf('G%02d-S%02d', $g, $s);
    }

    /**
     * Resolve canonical grade number (1–12) for a class.
     */
    public static function resolveClassGrade(object|array $class): ?int
    {
        $c = (object) $class;
        if (! empty($c->level_id)) {
            $lvl = DB::table('edu_levels')->where('id', $c->level_id)->first();
            if ($lvl) {
                if (isset($lvl->sort_order) && (int) $lvl->sort_order >= 1 && (int) $lvl->sort_order <= 12) {
                    return (int) $lvl->sort_order;
                }
                if (! empty($lvl->code) && preg_match('/^G(\d{1,2})$/i', $lvl->code, $m)) {
                    return (int) $m[1];
                }
            }
            if ((int) $c->level_id >= 1 && (int) $c->level_id <= 12) {
                return (int) $c->level_id;
            }
        }
        if (! empty($c->name)) {
            if (preg_match('/(\d{1,2})ኛ(?:\s*ክፍል)?/u', $c->name, $m)) {
                return (int) $m[1];
            }
            if (preg_match('/(?:Grade|G|ክፍል)\s*(\d{1,2})/iu', $c->name, $m)) {
                return (int) $m[1];
            }
        }
        if (! empty($c->name_en) && preg_match('/(?:Grade|G)\s*(\d{1,2})/iu', $c->name_en, $m)) {
            return (int) $m[1];
        }
        return null;
    }

    /**
     * Connects a class to its official grade curriculum courses and lessons.
     * Reuses existing courses without generating duplicates, mapping legacy course titles.
     */
    public static function connectClassToCurriculum(int $classId, ?int $levelId = null): array
    {
        $c = self::getClass($classId);
        if ($levelId) {
            $c->level_id = $levelId;
        }
        $gradeNum = self::resolveClassGrade($c);
        if (! $gradeNum || $gradeNum < 1 || $gradeNum > 12) {
            return ['connected' => 0, 'courses' => [], 'grade' => null];
        }

        if (! Schema::hasTable('edu_subjects')) {
            return ['connected' => 0, 'courses' => [], 'grade' => $gradeNum];
        }
        $hasGradeCol = Schema::hasColumn('edu_subjects', 'grade');
        $subjects = DB::table('edu_subjects')
            ->when($hasGradeCol, function ($q) use ($gradeNum) {
                $q->where('grade', $gradeNum)
                  ->orWhere(fn ($q2) => $q2->whereNull('grade')->where('sort_order', $gradeNum));
            }, function ($q) use ($gradeNum) {
                $q->where('sort_order', $gradeNum);
            })
            ->where('status', '!=', 'archived')
            ->orderBy('id')
            ->get();

        if ($subjects->isEmpty()) {
            try {
                EduCurriculumImport::import(false);
                $subjects = DB::table('edu_subjects')
                    ->when($hasGradeCol, function ($q) use ($gradeNum) {
                        $q->where('grade', $gradeNum)
                          ->orWhere(fn ($q2) => $q2->whereNull('grade')->where('sort_order', $gradeNum));
                    }, function ($q) use ($gradeNum) {
                        $q->where('sort_order', $gradeNum);
                    })
                    ->where('status', '!=', 'archived')
                    ->orderBy('id')
                    ->get();
            } catch (\Throwable $e) {}
        }

        $connectedCount = 0;
        $existingCourses = DB::table('edu_courses')->where('class_id', $classId)->get();

        foreach ($subjects as $sub) {
            $course = $existingCourses->firstWhere('subject_id', $sub->id);

            if (! $course) {
                $trimmedSubName = trim($sub->name);
                $course = $existingCourses->first(function ($ec) use ($trimmedSubName, $sub) {
                    return trim($ec->name ?? '') === $trimmedSubName
                        || (! empty($sub->code) && trim($ec->code ?? '') === trim($sub->code))
                        || (str_contains(trim($ec->name ?? ''), $trimmedSubName) || str_contains($trimmedSubName, trim($ec->name ?? '')));
                });

                if ($course) {
                    DB::table('edu_courses')->where('id', $course->id)->update([
                        'subject_id' => $sub->id,
                        'code' => $sub->code ?? $course->code,
                        'status' => 'active',
                        'updated_at' => now(),
                    ]);
                    $connectedCount++;
                    continue;
                }
            }

            if (! $course) {
                DB::table('edu_courses')->insert([
                    'class_id' => $classId,
                    'subject_id' => $sub->id,
                    'name' => $sub->name,
                    'code' => (!empty($sub->code) && preg_match('/^G\d{1,2}-S\d{1,2}$/i', $sub->code))
                        ? strtoupper(trim($sub->code))
                        : self::standardizeCourseCode($gradeNum, $sub->sort_order ?: $sub->id),
                    'status' => 'active',
                    'mode' => 'physical',
                    'pass_mark' => 50.0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
                $connectedCount++;
            } else {
                $connectedCount++;
            }
        }

        return [
            'connected' => $connectedCount,
            'grade' => $gradeNum,
            'total_subjects' => $subjects->count(),
        ];
    }

    /**
     * Preview official curriculum for a grade level prior to class creation/edit.
     */
    public static function curriculumPreview(int $levelId): array
    {
        $level = DB::table('edu_levels')->where('id', $levelId)->first();
        if (! $level) throw ApiError::notFound('LEVEL_NOT_FOUND', 'Grade level not found');

        $gradeNum = (int) ($level->sort_order ?? 0);
        if ($gradeNum < 1 || $gradeNum > 12) {
            if (preg_match('/^G(\d{1,2})$/i', $level->code ?? '', $m)) {
                $gradeNum = (int) $m[1];
            }
        }

        $hasGradeCol = Schema::hasColumn('edu_subjects', 'grade');
        $subjects = DB::table('edu_subjects as s')
            ->leftJoin('edu_categories as c', 'c.id', '=', 's.category_id')
            ->when($hasGradeCol, function ($q) use ($gradeNum) {
                $q->where('s.grade', $gradeNum)
                  ->orWhere(fn ($q2) => $q2->whereNull('s.grade')->where('s.sort_order', $gradeNum));
            }, function ($q) use ($gradeNum) {
                $q->where('s.sort_order', $gradeNum);
            })
            ->where('s.status', '!=', 'archived')
            ->select('s.*', 'c.name as category_name', 'c.name_en as category_name_en', 'c.icon_key as category_icon')
            ->orderBy('s.id')
            ->get();

        $subjectIds = $subjects->pluck('id')->all();
        $unitCounts = ! empty($subjectIds)
            ? DB::table('edu_units')->whereIn('subject_id', $subjectIds)->groupBy('subject_id')->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all()
            : [];
        $lessonCounts = ! empty($subjectIds)
            ? DB::table('edu_lessons')->whereIn('subject_id', $subjectIds)->groupBy('subject_id')->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all()
            : [];
        $publishedLessonCounts = ! empty($subjectIds)
            ? DB::table('edu_lessons')->whereIn('subject_id', $subjectIds)->where('status', 'published')->groupBy('subject_id')->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all()
            : [];

        $previewList = $subjects->map(fn ($s) => [
            'id' => (int) $s->id,
            'name' => $s->name,
            'name_en' => $s->name_en,
            'code' => $s->code,
            'category_name' => $s->category_name,
            'category_name_en' => $s->category_name_en,
            'category_icon' => $s->category_icon,
            'units_count' => (int) ($unitCounts[$s->id] ?? 0),
            'lessons_count' => (int) ($lessonCounts[$s->id] ?? 0),
            'published_lessons_count' => (int) ($publishedLessonCounts[$s->id] ?? 0),
            'status' => $s->status,
        ])->all();

        return [
            'level_id' => (int) $level->id,
            'grade' => $gradeNum,
            'grade_name' => $level->name,
            'grade_name_en' => $level->name_en,
            'has_curriculum' => ! empty($previewList),
            'total_subjects' => count($previewList),
            'subjects' => $previewList,
        ];
    }

    /**
     * Explicitly synchronize / refresh a class's curriculum connections.
     */
    public static function syncClassCurriculum(array $actx, int $classId): array
    {
        $res = self::connectClassToCurriculum($classId);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['sync_curriculum' => $res]);
        $detail = self::classDetail($actx['auth'], $classId);
        $detail['sync_stats'] = [
            'connected' => $res['connected'] ?? 0,
            'total_subjects' => $res['total_subjects'] ?? 0,
            'grade' => $res['grade'] ?? null,
            'success' => true,
        ];
        return $detail;
    }

    /**
     * Synchronize official canonical curriculum across all 12 grades from intermediate canonical JSON.
     */
    public static function syncCurriculum(array $actx, bool $dryRun = false): array
    {
        $res = EduCurriculumImport::import($dryRun);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_curriculum', 0, ['sync_curriculum' => $res]);
        return $res;
    }

    /**
     * Ensure Grade 1–12 classes exist and are connected to official curriculum.
     */
    public static function ensureGradeClasses(?int $academicYearId = null): array
    {
        EduAcademicYears::ensureCanonicalGrades();

        $yearId = $academicYearId;
        if (! $yearId) {
            $year = DB::table('edu_academic_years')->where('is_current', 1)->first()
                 ?? DB::table('edu_academic_years')->orderByDesc('eth_year')->first();
            if (! $year) {
                $nowEth = 2017;
                $yearId = DB::table('edu_academic_years')->insertGetId([
                    'eth_year' => $nowEth,
                    'name' => "{$nowEth} ዓ.ም",
                    'status' => 'active',
                    'is_current' => 1,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            } else {
                $yearId = (int) $year->id;
            }
        }

        $levels = DB::table('edu_levels')->where('kind', 'grade')->orderBy('sort_order')->get()->keyBy('sort_order');
        $results = [];

        for ($g = 1; $g <= 12; $g++) {
            $level = $levels->get($g);
            $levelId = $level ? (int) $level->id : $g;

            $existingClass = DB::table('edu_classes')
                ->where('academic_year_id', $yearId)
                ->where('level_id', $levelId)
                ->where('status', '!=', 'archived')
                ->first();

            if (! $existingClass) {
                $existingClass = DB::table('edu_classes')
                    ->where('academic_year_id', $yearId)
                    ->where('status', '!=', 'archived')
                    ->where(function ($w) use ($g) {
                        $w->where('name', "{$g}ኛ ክፍል")
                          ->orWhere('name', "{$g}ኛ");
                    })
                    ->first();

                if ($existingClass) {
                    DB::table('edu_classes')->where('id', $existingClass->id)->update([
                        'level_id' => $levelId,
                        'name_en' => $existingClass->name_en ?? "Grade {$g}",
                        'updated_at' => now(),
                    ]);
                }
            }

            $classId = null;
            if ($existingClass) {
                $classId = (int) $existingClass->id;
            } else {
                $classId = DB::table('edu_classes')->insertGetId([
                    'name' => "{$g}ኛ ክፍል",
                    'name_en' => "Grade {$g}",
                    'academic_year_id' => $yearId,
                    'level_id' => $levelId,
                    'allow_regular' => 1,
                    'allow_distance' => 1,
                    'allow_self_registration' => 0,
                    'status' => 'active',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            $conn = self::connectClassToCurriculum($classId, $levelId);
            $results[] = [
                'grade' => $g,
                'class_id' => $classId,
                'level_id' => $levelId,
                'connected_courses' => $conn['connected'],
                'action' => $existingClass ? 'reused' : 'created',
            ];
        }

        return [
            'academic_year_id' => $yearId,
            'grades' => $results,
            'total_grades' => count($results),
        ];
    }


    /**
     * Deleting cascades (enrollments, attendance, marks, submissions…), so a class / subject /
     * assessment that already holds academic records is never deleted: it is archived instead.
     */
    private static function assertNoRecords(string $what, array $courseIds, ?int $classId = null, ?int $assessmentId = null): void
    {
        $assessments = $assessmentId ? [$assessmentId] : ($courseIds ? DB::table('edu_assessments')->whereIn('course_id', $courseIds)->pluck('id')->all() : []);
        $has = ($classId && (DB::table('edu_enrollments')->where('class_id', $classId)->exists() || DB::table('edu_attendance')->where('class_id', $classId)->exists()))
            || ($assessments && DB::table('edu_scores')->whereIn('assessment_id', $assessments)->whereNotNull('score')->exists())
            || ($courseIds && DB::table('edu_submissions as s')->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')->whereIn('a.course_id', $courseIds)->exists())
            || ($courseIds && DB::table('edu_course_enrollments')->whereIn('course_id', $courseIds)->exists())
            || ($courseIds && DB::table('edu_quiz_attempts as qa')->join('edu_quizzes as q', 'q.id', '=', 'qa.quiz_id')->whereIn('q.course_id', $courseIds)->exists());
        if ($has) throw ApiError::conflict('HAS_RECORDS', "This $what has academic records; archive it instead of deleting it");
    }

    public static function deleteClass(array $actx, int $id): void
    {
        self::getClass($id);
        self::assertNoRecords('class', array_map('intval', DB::table('edu_courses')->where('class_id', $id)->pluck('id')->all()), $id);
        DB::table('edu_classes')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $id, ['deleted' => true]);
    }

    private static function streamsCsv(array $input): array
    {
        if (array_key_exists('streams', $input)) $input['streams'] = $input['streams'] ? implode(',', array_values(array_unique(array_map('trim', $input['streams'])))) : null;
        return $input;
    }

    private static function assertUser($userId): void
    {
        if (! $userId) return;
        if (! DB::table('users')->where(['id' => $userId, 'status' => 'active'])->whereNull('deleted_at')->exists()) {
            throw ApiError::validation([['field' => 'teacher_user_id', 'code' => 'USER_NOT_FOUND', 'message' => 'USER_NOT_FOUND']]);
        }
    }

    private static function assertMemberGroups(?string $csv): void
    {
        if (! $csv) return;
        $groups = array_filter(array_map('trim', explode(',', $csv)));
        $validKeys = MemberGroups::keys();
        foreach ($groups as $g) {
            if (! in_array($g, $validKeys, true)) {
                throw ApiError::field('member_groups', 'INVALID_MEMBER_GROUP');
            }
        }
    }

    private static function syncCoursePrograms(int $classId, int $courseId, ?array $programIds): void
    {
        if ($programIds === null) return;
        $class = self::getClass($classId);
        if ($class->status === 'archived') {
            throw ApiError::conflict('CLASS_NOT_ACTIVE', 'Cannot link program to course of an archived class');
        }
        if (! empty($programIds)) {
            $valid = DB::table('programs')->whereIn('id', $programIds)->pluck('id')->map(fn ($x) => (int) $x)->all();
            if (count($valid) !== count($programIds)) {
                throw ApiError::field('program_ids', 'PROGRAM_NOT_FOUND');
            }
        }
        DB::table('program_edu_courses')->where('course_id', $courseId)->delete();
        foreach (array_unique($programIds) as $pid) {
            DB::table('program_edu_courses')->insert([
                'program_id' => (int) $pid,
                'course_id' => $courseId,
                'created_at' => now(),
            ]);
        }
    }

    public static function createCourse(array $actx, int $classId, array $input): array
    {
        $class = self::getClass($classId);
        self::assertUser($input['teacher_user_id'] ?? null);
        self::assertSubject($input['subject_id'] ?? null);
        self::assertMemberGroups($input['member_groups'] ?? null);

        // Auto-resolve curriculum subject if not explicitly supplied
        if (empty($input['subject_id'])) {
            $gradeNum = self::resolveClassGrade($class);
            $cName = trim($input['name'] ?? '');
            if ($gradeNum && Schema::hasTable('edu_subjects')) {
                $sub = DB::table('edu_subjects')
                    ->where(function ($q) use ($gradeNum) {
                        $q->where('grade', $gradeNum)
                          ->orWhere(fn ($q2) => $q2->whereNull('grade')->where('sort_order', $gradeNum));
                    })
                    ->where(function ($w) use ($cName, $input) {
                        $w->where('name', $cName)
                          ->orWhere('name_en', $cName);
                        if (! empty($input['code'])) {
                            $w->orWhere('code', trim($input['code']));
                        }
                    })
                    ->first();
                if ($sub) {
                    $input['subject_id'] = $sub->id;
                }
            }
        }

        // Check if course offering already exists for this class and subject to prevent duplicates
        if (! empty($input['subject_id'])) {
            $existing = DB::table('edu_courses')->where('class_id', $classId)->where('subject_id', $input['subject_id'])->first();
            if ($existing) {
                // If existing course already offers this curriculum subject, update and return it
                return self::updateCourse($actx, $existing->id, $input);
            }
        }

        $gradeNum = self::resolveClassGrade(self::getClass($classId)) ?? 1;
        $existingCount = DB::table('edu_courses')->where('class_id', $classId)->count();
        if (empty($input['code']) || !preg_match('/^G\d{1,2}-S\d{1,2}$/i', $input['code'])) {
            $input['code'] = self::standardizeCourseCode($gradeNum, $existingCount + 1);
        } else {
            preg_match('/^G(\d{1,2})-S(\d{1,2})$/i', $input['code'], $cm);
            $input['code'] = self::standardizeCourseCode((int)$cm[1], (int)$cm[2]);
        }

        $id = DB::table('edu_courses')->insertGetId(['class_id' => $classId] + self::pick(self::COURSE_FIELDS, $input));
        EduTeachers::syncMain($actx, $id, isset($input['teacher_user_id']) ? (int) $input['teacher_user_id'] : null, null);
        if (array_key_exists('program_ids', $input)) {
            self::syncCoursePrograms($classId, $id, $input['program_ids']);
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $id, ['created' => $input['name'], 'teacher' => $input['teacher_user_id'] ?? null]);
        if (! empty($input['teacher_user_id'])) self::notifyTeacher($input['teacher_user_id'], $id);
        return self::courseDetail($id);
    }

    public static function updateCourse(array $actx, int $id, array $input): array
    {
        $before = self::getCourse($id);
        self::assertUser($input['teacher_user_id'] ?? null);
        self::assertSubject($input['subject_id'] ?? null);
        self::assertMemberGroups($input['member_groups'] ?? null);
        if (isset($input['code'])) {
            if (preg_match('/^G(\d{1,2})-S(\d{1,2})$/i', $input['code'], $cm)) {
                $input['code'] = self::standardizeCourseCode((int)$cm[1], (int)$cm[2]);
            }
        }
        $patch = self::pick([...self::COURSE_FIELDS, 'progress', 'completed_at'], $input);
        // Reaching 100 % completes the course today (unless a date is given); going below reopens it.
        if (isset($patch['progress'])) {
            if ((int) $patch['progress'] >= 100 && ! array_key_exists('completed_at', $patch) && ! $before->completed_at) $patch['completed_at'] = Dates::todayLocal();
            if ((int) $patch['progress'] < 100 && ! array_key_exists('completed_at', $patch)) $patch['completed_at'] = null;
        }
        if ($patch) DB::table('edu_courses')->where('id', $id)->update($patch);
        if (array_key_exists('teacher_user_id', $patch)) EduTeachers::syncMain($actx, $id, $patch['teacher_user_id'] ? (int) $patch['teacher_user_id'] : null, $before->teacher_user_id ? (int) $before->teacher_user_id : null);
        if (array_key_exists('program_ids', $input)) {
            self::syncCoursePrograms((int) $before->class_id, $id, $input['program_ids']);
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $id, ['fields' => array_keys($input)]);
        if (! empty($input['teacher_user_id']) && (int) $input['teacher_user_id'] !== (int) $before->teacher_user_id) self::notifyTeacher($input['teacher_user_id'], $id);
        return self::courseDetail($id);
    }

    private static function notifyTeacher(int $userId, int $courseId): void
    {
        $c = self::courseDetail($courseId);
        $stamp = (int) floor(microtime(true) * 1000);
        $n = Notifications::createForUsers([$userId], [
            'type' => 'education',
            'title' => T::t('edu.teacher.title'),
            'body' => T::t('edu.teacher.body', ['course' => $c['name'], 'class' => $c['class_name']]),
            'entityType' => 'edu_course',
            'entityId' => $courseId,
            'dedupeKey' => fn ($uid) => "edu:teacher:$courseId:$uid:$stamp",
        ]);
        if ($n) Notifications::kick();
    }

    public static function deleteCourse(array $actx, int $id): void
    {
        self::getCourse($id);
        self::assertNoRecords('subject', [$id]);
        DB::table('edu_courses')->where('id', $id)->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $id, ['deleted' => true]);
    }

    public static function courseDetail(int $id): array
    {
        $c = DB::table('edu_courses as co')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->leftJoin('users as tu', 'tu.id', '=', 'co.teacher_user_id')
            ->where('co.id', $id)
            ->first(['co.*', 'c.name as class_name', 'tu.full_name as teacher_name']);
        if (! $c) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        $c->programs = DB::table('program_edu_courses as pec')
            ->join('programs as p', 'p.id', '=', 'pec.program_id')
            ->where('pec.course_id', $id)
            ->select('p.id', 'p.title', 'p.recurrence')
            ->get()
            ->all();
        return self::serializeCourse($c);
    }

    public static function setSchedule(array $actx, int $classId, array $rows): array
    {
        self::getClass($classId);
        $courseIds = array_map('intval', DB::table('edu_courses')->where('class_id', $classId)->pluck('id')->all());
        foreach ($rows as $r) {
            if (! empty($r['course_id']) && ! in_array((int) $r['course_id'], $courseIds, true)) throw ApiError::validation([['field' => 'course_id', 'code' => 'COURSE_NOT_FOUND', 'message' => 'COURSE_NOT_FOUND']]);
        }
        DB::transaction(function () use ($actx, $classId, $rows) {
            DB::table('edu_schedule')->where('class_id', $classId)->delete();
            if ($rows) {
                DB::table('edu_schedule')->insert(array_map(fn ($r) => [
                    'class_id' => $classId, 'course_id' => $r['course_id'] ?? null, 'weekday' => $r['weekday'],
                    'frequency' => $r['frequency'] ?? 'weekly', 'week_of_month' => ($r['frequency'] ?? 'weekly') === 'monthly' ? ($r['week_of_month'] ?? 1) : null,
                    'program' => $r['program'] ?? 'all', 'mode' => $r['mode'] ?? 'in_person',
                    'starts' => $r['starts'], 'ends' => $r['ends'], 'location' => $r['location'] ?? null,
                ], $rows));
            }
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['schedule' => count($rows)], inTrx: true);
        });
        return self::schedule($classId);
    }

    public static function schedule(int $classId): array
    {
        return DB::table('edu_schedule as s')->leftJoin('edu_courses as co', 'co.id', '=', 's.course_id')->where('s.class_id', $classId)
            ->select('s.*', 'co.name as course_name')->orderBy('s.weekday')->orderBy('s.starts')->get()->map(fn ($s) => self::serializeSchedule($s))->all();
    }

    public static function allSchedules(?int $academicYearId = null, ?int $classId = null): array
    {
        $qb = DB::table('edu_schedule as s')
            ->join('edu_classes as c', 'c.id', '=', 's.class_id')
            ->leftJoin('edu_courses as co', 'co.id', '=', 's.course_id')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id');

        if ($classId) {
            $qb->where('s.class_id', $classId);
        }
        if ($academicYearId) {
            $qb->where('c.academic_year_id', $academicYearId);
        }

        return $qb->select('s.*', 'c.name as class_name', 'co.name as course_name', 'y.eth_year', 'y.name as year_name')
            ->orderBy('c.name')->orderBy('s.weekday')->orderBy('s.starts')
            ->get()->map(function ($s) {
                $out = self::serializeSchedule($s);
                $out['class_name'] = $s->class_name;
                $out['academic_year'] = $s->eth_year ? ['eth_year' => (int) $s->eth_year, 'name' => $s->year_name] : null;
                return $out;
            })->all();
    }

    public static function staff(int $classId): array
    {
        self::getClass($classId);
        return DB::table('edu_class_staff as s')->join('users as u', 'u.id', '=', 's.user_id')->where('s.class_id', $classId)->select('u.id', 'u.full_name', 'u.phone', 's.role')->get()->all();
    }

    public static function addStaff(array $actx, int $classId, int $userId): array
    {
        self::getClass($classId);
        self::assertUser($userId);
        DB::table('edu_class_staff')->insertOrIgnore(['class_id' => $classId, 'user_id' => $userId, 'role' => 'attendance_taker']);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['attendance_taker' => $userId]);
        return self::staff($classId);
    }

    public static function removeStaff(array $actx, int $classId, int $userId): array
    {
        DB::table('edu_class_staff')->where(['class_id' => $classId, 'user_id' => $userId])->delete();
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['attendance_taker_removed' => $userId]);
        return self::staff($classId);
    }

    public static function students(AuthContext $auth, int $classId, ?string $q, array $page): array
    {
        self::assertClassMember($auth, $classId);
        $qb = DB::table('edu_enrollments as e')->join('users as u', 'u.id', '=', 'e.user_id')->where(['e.class_id' => $classId, 'e.status' => 'active'])
            ->select('e.id as enrollment_id', 'u.id as user_id', 'u.full_name', 'u.profile_image', 'e.program', 'e.stream', 'e.created_at as enrolled_at')->orderBy('u.full_name');
        if (self::isModerator($auth)) $qb->addSelect('u.phone');
        if ($q) $qb->where('u.full_name', 'like', "%$q%");
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::strip($r), $res['items']), 'meta' => $res['meta']];
    }

    public static function removeEnrollment(array $actx, int $classId, int $userId): void
    {
        $n = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId, 'status' => 'active'])->update(['status' => 'withdrawn']);
        if (! $n) throw ApiError::notFound('ENROLLMENT_NOT_FOUND', 'Enrollment not found');
        EduJourney::record($userId, 'withdrawn', ['class_id' => $classId, 'old' => 'active', 'new' => 'withdrawn'], $actx['auth']->id);
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['withdrawn' => $userId]);
    }

    /** Administrator: add or drop one subject for a student (same rules as an approved request). */
    public static function setStudentSubject(array $actx, int $userId, int $courseId, bool $add, ?string $reason): array
    {
        $course = self::getCourse($courseId);
        DB::transaction(function () use ($actx, $userId, $course, $courseId, $add, $reason) {
            $on = self::onRoster($course, $userId);
            if ($add && $on) throw ApiError::conflict('ALREADY_ENROLLED', 'Already taking this subject');
            if (! $add && ! $on) throw ApiError::field('course_id', 'NOT_ENROLLED');
            if ($add && ! DB::table('edu_enrollments')->where(['user_id' => $userId, 'status' => 'active'])->exists()) throw ApiError::field('user_id', 'NOT_ENROLLED');
            EduRequests::setSubject($userId, $courseId, $add, $actx['auth']->id);
            EduJourney::record($userId, $add ? 'subject_added' : 'subject_dropped', ['class_id' => $course->class_id, 'course_id' => $courseId, 'reason' => $reason], $actx['auth']->id);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_course', $courseId, ['student' => $userId, 'subject' => $add ? 'added' : 'dropped', 'reason' => $reason], inTrx: true);
        });
        return ['course_id' => $courseId, 'user_id' => $userId, 'on_roster' => self::onRoster($course, $userId)];
    }

    /** Administrator: change a student's study mode (regular / distance) or stream in a class. */
    public static function updateEnrollment(array $actx, int $classId, int $userId, array $in): array
    {
        $c = self::getClass($classId);
        DB::transaction(function () use ($actx, $c, $classId, $userId, $in) {
            $e = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId, 'status' => 'active'])->lockForUpdate()->first();
            if (! $e) throw ApiError::notFound('ENROLLMENT_NOT_FOUND', 'Enrollment not found');
            $by = $actx['auth']->id;
            $reason = $in['reason'] ?? null;
            if (isset($in['program']) && $in['program'] !== $e->program) {
                if (($in['program'] === 'regular' && ! $c->allow_regular) || ($in['program'] === 'distance' && ! $c->allow_distance)) throw ApiError::field('program', 'PROGRAM_NOT_OFFERED');
                DB::table('edu_enrollments')->where('id', $e->id)->update(['program' => $in['program']]);
                EduJourney::record($userId, 'study_mode_changed', ['class_id' => $classId, 'old' => $e->program, 'new' => $in['program'], 'reason' => $reason], $by);
            }
            if (array_key_exists('stream', $in) && $in['stream'] !== $e->stream) {
                $allowed = ! empty($c->streams) ? array_map('trim', explode(',', $c->streams)) : [];
                if ($in['stream'] !== null && ! in_array($in['stream'], $allowed, true)) throw ApiError::field('stream', 'INVALID_STREAM');
                DB::table('edu_enrollments')->where('id', $e->id)->update(['stream' => $in['stream']]);
                EduJourney::record($userId, 'stream_changed', ['class_id' => $classId, 'old' => $e->stream, 'new' => $in['stream'], 'reason' => $reason], $by);
            }
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['enrollment' => $userId, 'changes' => array_keys($in)], inTrx: true);
        });
        return (array) DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId])->first(['class_id', 'user_id', 'program', 'stream', 'status']);
    }

    // ------------------------------------------------------------------ students
    public static function openClasses(AuthContext $auth): array
    {
        $rows = DB::table('edu_classes as c')
            ->leftJoin('edu_enrollments as me', fn ($j) => $j->on('me.class_id', '=', 'c.id')->where('me.user_id', '=', $auth->id)->where('me.status', '=', 'active'))
            ->where('c.status', 'active')->select('c.*', self::classCounts(), 'me.program as my_program')->orderBy('c.name')->get();
        $out = [];
        foreach ($rows as $r) {
            $c = self::serializeClass($r);
            if ($c['my_program'] || (! empty($c['allow_self_registration']) && $c['registration'] !== 'closed')) $out[] = $c;
        }
        return $out;
    }

    public static function enroll(AuthContext $auth, int $classId, string $program): array
    {
        DB::transaction(function () use ($auth, $classId, $program) {
            $c = DB::table('edu_classes')->where('id', $classId)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');
            if (empty($c->allow_self_registration)) {
                throw ApiError::forbidden('SELF_REGISTRATION_DISABLED', 'Self-registration is not allowed for this class. An administrator must assign you.');
            }
            $state = self::registrationState($c);
            if ($state !== 'open') throw ApiError::conflict($state === 'upcoming' ? 'REGISTRATION_NOT_OPEN' : 'REGISTRATION_CLOSED', 'Registration is not open');
            if (($program === 'regular' && ! $c->allow_regular) || ($program === 'distance' && ! $c->allow_distance)) {
                throw ApiError::validation([['field' => 'program', 'code' => 'PROGRAM_NOT_OFFERED', 'message' => 'PROGRAM_NOT_OFFERED']]);
            }
            $existing = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $auth->id])->first();
            if ($existing?->status === 'active') throw ApiError::conflict('ALREADY_ENROLLED', 'Already enrolled');
            if ($c->capacity) {
                $n = DB::table('edu_enrollments')->where(['class_id' => $classId, 'status' => 'active'])->count();
                if ($n >= $c->capacity) throw ApiError::conflict('CLASS_FULL', 'Class is full');
            }
            $isExclusive = ($c->allow_multiple ?? 0) ? 0 : 1;
            if ($isExclusive && $c->academic_year_id) {
                $other = DB::table('edu_enrollments as e')
                    ->join('edu_classes as cl', 'cl.id', '=', 'e.class_id')
                    ->where('e.user_id', $auth->id)
                    ->where('e.academic_year_id', $c->academic_year_id)
                    ->where('e.exclusive', 1)
                    ->where('e.status', 'active')
                    ->where('e.class_id', '!=', $classId)
                    ->first(['cl.name as class_name']);
                if ($other) {
                    throw ApiError::conflict('ALREADY_ENROLLED', "User is already active in exclusive class {$other->class_name} for this academic year");
                }
            }
            DB::table('edu_enrollments')->upsert([['class_id' => $classId, 'user_id' => $auth->id, 'academic_year_id' => $c->academic_year_id, 'exclusive' => $isExclusive, 'program' => $program, 'status' => 'active']], ['class_id', 'user_id'], ['academic_year_id', 'exclusive', 'program', 'status']);
            EduJourney::record($auth->id, 'enrolled', ['class_id' => $classId, 'new' => $program], $auth->id);
        });
        return self::classDetail($auth, $classId);
    }

    public static function withdraw(AuthContext $auth, int $classId): void
    {
        $c = self::getClass($classId);
        if (self::registrationState($c) !== 'open') throw ApiError::conflict('REGISTRATION_CLOSED', 'Registration is closed');
        $n = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $auth->id, 'status' => 'active'])->update(['status' => 'withdrawn']);
        if (! $n) throw ApiError::notFound('ENROLLMENT_NOT_FOUND', 'Enrollment not found');
        EduJourney::record($auth->id, 'withdrawn', ['class_id' => $classId, 'old' => 'active', 'new' => 'withdrawn'], $auth->id);
    }

    public static function overview(AuthContext $auth): array
    {
        $hasAy = Schema::hasTable('edu_academic_years');
        $hasTm = Schema::hasTable('edu_terms');
        $hasLvl = Schema::hasTable('edu_levels');
        $hasLvlCode = $hasLvl && Schema::hasColumn('edu_levels', 'code');
        $hasLvlName = $hasLvl && Schema::hasColumn('edu_levels', 'name');
        $hasLvlNameEn = $hasLvl && Schema::hasColumn('edu_levels', 'name_en');
        $hasLvlKind = $hasLvl && Schema::hasColumn('edu_levels', 'kind');
        $hasProgram = Schema::hasColumn('edu_enrollments', 'program');

        $baseJoin = function ($query) use ($hasAy, $hasTm, $hasLvl) {
            if ($hasAy) {
                $query->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id');
            }
            if ($hasTm) {
                $query->leftJoin('edu_terms as tm', 'tm.id', '=', 'c.term_id');
            }
            if ($hasLvl) {
                $query->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id');
            }
        };

        $baseSelect = [
            'c.*',
            $hasAy ? 'y.eth_year as ay_eth_year' : DB::raw('NULL as ay_eth_year'),
            $hasAy ? 'y.name as ay_name' : DB::raw('NULL as ay_name'),
            $hasAy ? 'y.is_current as ay_is_current' : DB::raw('NULL as ay_is_current'),
            $hasTm ? 'tm.name as tm_name' : DB::raw('NULL as tm_name'),
            $hasLvlCode ? 'lvl.code as lvl_code' : DB::raw('NULL as lvl_code'),
            $hasLvlName ? 'lvl.name as lvl_name' : DB::raw('NULL as lvl_name'),
            $hasLvlNameEn ? 'lvl.name_en as lvl_name_en' : DB::raw('NULL as lvl_name_en'),
            $hasLvlKind ? 'lvl.kind as lvl_kind' : DB::raw('NULL as lvl_kind'),
            self::classCounts(),
        ];

        $enrolledQ = DB::table('edu_enrollments as e')->join('edu_classes as c', 'c.id', '=', 'e.class_id');
        $baseJoin($enrolledQ);
        $enrolled = $enrolledQ->where(['e.user_id' => $auth->id, 'e.status' => 'active', 'c.status' => 'active'])
            ->select(array_merge($baseSelect, [$hasProgram ? 'e.program as my_program' : DB::raw('NULL as my_program')]))->orderBy('c.name')->get();

        // Classes where the student only takes subjects added from elsewhere.
        $addedOnlyQ = DB::table('edu_classes as c');
        $baseJoin($addedOnlyQ);
        $addedOnly = $addedOnlyQ->where('c.status', 'active')->whereNotIn('c.id', $enrolled->pluck('id')->all() ?: [0])
            ->whereExists(fn ($q) => $q->select(DB::raw(1))->from('edu_course_enrollments as ce')->join('edu_courses as co', 'co.id', '=', 'ce.course_id')
                ->whereColumn('co.class_id', 'c.id')->where(['ce.user_id' => $auth->id, 'ce.status' => 'added']))
            ->select($baseSelect)->get();

        // Subjects with an ACTIVE teaching assignment (suspended / removed ones are not listed).
        $teaching = DB::table('edu_courses as co')->join('edu_classes as c', 'c.id', '=', 'co.class_id')->where('c.status', 'active')
            ->whereExists(fn ($q) => $q->select(DB::raw(1))->from('edu_course_teachers as ct')->whereColumn('ct.course_id', 'co.id')->where(['ct.user_id' => $auth->id, 'ct.status' => 'active']))
            ->select('co.*', 'c.name as class_name', DB::raw("(SELECT COUNT(*) FROM edu_enrollments e WHERE e.class_id = co.class_id AND e.status = 'active') as student_count"))->get();

        $attendanceClassesQ = DB::table('edu_class_staff as s')->join('edu_classes as c', 'c.id', '=', 's.class_id');
        $baseJoin($attendanceClassesQ);
        $attendanceClasses = $attendanceClassesQ->where('s.user_id', $auth->id)->where('c.status', 'active')
            ->select($baseSelect)->get();

        $classIds = array_values(array_unique(array_merge($enrolled->pluck('id')->all(), $teaching->pluck('class_id')->all())));
        $open = array_filter(self::openClasses($auth), fn ($c) => ! $c['my_program'] && $c['registration'] === 'open');
        return [
            'classes' => array_merge($enrolled->map(fn ($c) => self::serializeClass($c))->all(), $addedOnly->map(fn ($c) => self::serializeClass($c) + ['added_subjects_only' => true])->all()),
            'teaching' => $teaching->map(fn ($c) => self::serializeCourse($c))->all(),
            'attendance_classes' => $attendanceClasses->map(fn ($c) => self::serializeClass($c))->all(),
            'next_sessions' => self::upcomingSessions($classIds),
            'open_registration' => count($open),
            'is_moderator' => self::isModerator($auth),
        ];
    }

    private static function upcomingSessions(array $classIds, int $days = 7): array
    {
        if (! $classIds) return [];
        $rows = DB::table('edu_schedule as s')->join('edu_classes as c', 'c.id', '=', 's.class_id')->leftJoin('edu_courses as co', 'co.id', '=', 's.course_id')
            ->whereIn('s.class_id', $classIds)->select('s.*', 'c.name as class_name', 'co.name as course_name')->get();
        $completed = [];
        foreach (DB::table('edu_courses')->whereIn('class_id', $classIds)->whereNotNull('completed_at')->get(['id', 'completed_at']) as $c) $completed[(int) $c->id] = Dates::toDateOnly($c->completed_at);
        $out = [];
        $today = Dates::todayLocal();
        for ($i = 0; $i < $days; $i++) {
            $d = Dates::addDays($today, $i);
            foreach ($rows as $r) {
                if (self::scheduleApplies($r, $d, null, $completed)) $out[] = ['date' => $d] + self::serializeSchedule($r) + ['class_name' => $r->class_name];
            }
        }
        usort($out, fn ($a, $b) => strcmp($a['date'] . $a['starts'], $b['date'] . $b['starts']));
        return array_slice($out, 0, 20);
    }

    public static function classDetail(AuthContext $auth, int $classId): array
    {
        self::assertClassMember($auth, $classId);
        $c = DB::table('edu_classes as c')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
            ->leftJoin('edu_terms as tm', 'tm.id', '=', 'c.term_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->where('c.id', $classId)
            ->select('c.*', 'y.eth_year as ay_eth_year', 'y.name as ay_name', 'y.is_current as ay_is_current',
                     'tm.name as tm_name', 'lvl.code as lvl_code', 'lvl.name as lvl_name', 'lvl.name_en as lvl_name_en', 'lvl.kind as lvl_kind',
                     self::classCounts())
            ->first();
        if (! $c) throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');

        $out = self::serializeClass($c);

        // Auto-connect curriculum if class has a grade level but no courses yet
        $courses = DB::table('edu_courses as co')->leftJoin('users as tu', 'tu.id', '=', 'co.teacher_user_id')->where('co.class_id', $classId)
            ->select('co.*', 'tu.full_name as teacher_name')->orderBy('co.name')->get();
        if ($courses->isEmpty() && (! empty($c->level_id) || self::resolveClassGrade($c))) {
            self::connectClassToCurriculum($classId, $c->level_id ? (int) $c->level_id : null);
            $courses = DB::table('edu_courses as co')->leftJoin('users as tu', 'tu.id', '=', 'co.teacher_user_id')->where('co.class_id', $classId)
                ->select('co.*', 'tu.full_name as teacher_name')->orderBy('co.name')->get();
        }

        // Gather curriculum subjects, units, lessons metadata
        $subjectIds = array_values(array_filter(array_map(fn ($co) => ! empty($co->subject_id) ? (int) $co->subject_id : null, $courses->all())));
        $curriculumMap = [];
        if (! empty($subjectIds)) {
            $subs = DB::table('edu_subjects as s')
                ->leftJoin('edu_categories as cat', 'cat.id', '=', 's.category_id')
                ->whereIn('s.id', $subjectIds)
                ->select('s.*', 'cat.name as category_name', 'cat.name_en as category_name_en', 'cat.icon_key as category_icon')
                ->get()->keyBy('id');

            $unitCounts = DB::table('edu_units')->whereIn('subject_id', $subjectIds)->groupBy('subject_id')
                ->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all();
            $lessonCounts = DB::table('edu_lessons')->whereIn('subject_id', $subjectIds)->groupBy('subject_id')
                ->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all();
            $pubLessonCounts = DB::table('edu_lessons')->whereIn('subject_id', $subjectIds)->where('status', 'published')->groupBy('subject_id')
                ->select('subject_id', DB::raw('COUNT(*) as total'))->pluck('total', 'subject_id')->all();

            foreach ($subs as $sId => $sub) {
                $curriculumMap[$sId] = [
                    'subject' => $sub,
                    'units_count' => (int) ($unitCounts[$sId] ?? 0),
                    'lessons_count' => (int) ($lessonCounts[$sId] ?? 0),
                    'published_lessons_count' => (int) ($pubLessonCounts[$sId] ?? 0),
                ];
            }
        }

        // Active teachers per course
        $courseIds = $courses->pluck('id')->map(fn ($x) => (int) $x)->all();
        $teachersByCourse = [];
        if (! empty($courseIds)) {
            $hasIsPrimaryCol = Schema::hasColumn('edu_course_teachers', 'is_primary');
            $tQuery = DB::table('edu_course_teachers as ct')
                ->join('users as u', 'u.id', '=', 'ct.user_id')
                ->whereIn('ct.course_id', $courseIds)
                ->where('ct.status', 'active');
            if ($hasIsPrimaryCol) {
                $tQuery->select('ct.course_id', 'u.id', 'u.full_name', 'u.phone', 'ct.is_primary');
            } else {
                $tQuery->select('ct.course_id', 'u.id', 'u.full_name', 'u.phone');
            }
            $tRows = $tQuery->get();
            $primaryTeacherByCourse = $courses->pluck('teacher_user_id', 'id')->all();
            foreach ($tRows as $tr) {
                $isPrimary = $hasIsPrimaryCol
                    ? (bool) ($tr->is_primary ?? false)
                    : ((int) $tr->id === (int) ($primaryTeacherByCourse[$tr->course_id] ?? 0));
                $teachersByCourse[$tr->course_id][] = [
                    'id' => (int) $tr->id,
                    'full_name' => $tr->full_name,
                    'phone' => $tr->phone,
                    'is_primary' => $isPrimary,
                ];
            }
        }

        $out['courses'] = $courses->map(function ($x) use ($c, $curriculumMap, $teachersByCourse) {
            $x->class_name = $c->name;
            $ser = self::serializeCourse($x);
            $sId = $x->subject_id ? (int) $x->subject_id : null;
            $cMeta = $sId && isset($curriculumMap[$sId]) ? $curriculumMap[$sId] : null;
            $ser['curriculum_subject'] = $cMeta ? [
                'id' => $sId,
                'name' => $cMeta['subject']->name,
                'name_en' => $cMeta['subject']->name_en,
                'code' => $cMeta['subject']->code,
                'category_name' => $cMeta['subject']->category_name,
                'category_name_en' => $cMeta['subject']->category_name_en,
                'category_icon' => $cMeta['subject']->category_icon,
                'units_count' => $cMeta['units_count'],
                'lessons_count' => $cMeta['lessons_count'],
                'published_lessons_count' => $cMeta['published_lessons_count'],
                'status' => $cMeta['subject']->status,
            ] : null;
            $ser['teachers'] = $teachersByCourse[(int) $x->id] ?? [];
            return $ser;
        })->all();

        $gradeNum = self::resolveClassGrade($c);
        $out['curriculum'] = [
            'grade' => $gradeNum,
            'grade_name' => $gradeNum ? "{$gradeNum}ኛ ክፍል" : ($c->name ?? null),
            'grade_name_en' => $gradeNum ? "Grade {$gradeNum}" : ($c->name_en ?? null),
            'is_connected' => ! empty($gradeNum),
            'total_courses' => count($out['courses']),
            'source' => 'Official Sunday School Curriculum',
        ];

        $out['schedule'] = self::schedule($classId);
        $mine = self::enrollment($classId, $auth->id);
        $out['my_program'] = $mine?->program;
        // Any active teaching assignment (not only the subject's main teacher).
        $out['is_teacher'] = self::teachesInClass($classId, $auth->id);
        // Takes some of this class's subjects without being enrolled in the class.
        $out['has_added_subjects'] = ! $mine && self::hasAddedSubject($classId, $auth->id);
        $out['takes_attendance'] = self::isModerator($auth) || DB::table('edu_class_staff')->where(['class_id' => $classId, 'user_id' => $auth->id])->exists() || $out['is_teacher'];
        if ($mine) $out['my_attendance'] = self::attendanceSummary($classId, $auth->id);
        return $out;
    }

    // ------------------------------------------------------------------ attendance
    public static function attendanceSummary(int $classId, int $userId): array
    {
        $cutover = Settings::eduAttendanceCutover();
        $counts = ['present' => 0, 'late' => 0, 'absent' => 0, 'excused' => 0];

        // 1. Legacy marks before cutover
        foreach (DB::table('edu_attendance')
            ->where(['class_id' => $classId, 'user_id' => $userId])
            ->where('session_date', '<', $cutover)
            ->groupBy('status')
            ->selectRaw('status, COUNT(*) as n')
            ->get() as $r) {
            $counts[$r->status] = (int) $r->n;
        }
        // No late status any more: an old "late" class mark counts as present ('late' stays 0 for older apps).
        $counts['present'] += $counts['late'];
        $counts['late'] = 0;

        // 2. Program marks on or after cutover linked to this class
        $programMarks = DB::table('attendance as a')
            ->join('attendance_edu_classes as ac', 'ac.attendance_id', '=', 'a.id')
            ->where('ac.class_id', $classId)
            ->where('a.user_id', $userId)
            ->where('a.occurrence_date', '>=', $cutover)
            ->groupBy('a.status')
            ->selectRaw('a.status, COUNT(*) as n')
            ->get();
        foreach ($programMarks as $pm) {
            $counts[$pm->status] = ($counts[$pm->status] ?? 0) + (int) $pm->n;
        }

        // 3. Unrecorded closed program occurrences for this student count as absent
        $progIds = DB::table('program_edu_classes')->where('class_id', $classId)->pluck('program_id')->all();
        if ($progIds) {
            $closedSessions = DB::table('attendance_sessions')
                ->whereIn('program_id', $progIds)
                ->where('occurrence_date', '>=', $cutover)
                ->where('status', 'ended')
                ->get(['program_id', 'occurrence_date']);
            foreach ($closedSessions as $cs) {
                $hasRecord = DB::table('attendance')
                    ->where('program_id', $cs->program_id)
                    ->where('occurrence_date', $cs->occurrence_date)
                    ->where('user_id', $userId)
                    ->exists();
                if (! $hasRecord) {
                    $counts['absent']++;
                }
            }
        }

        $total = array_sum($counts);
        return $counts + ['total' => $total, 'rate' => $total ? Num::round1($counts['present'] / $total * 100) : null];
    }

    public static function myAttendance(AuthContext $auth, int $classId): array
    {
        self::assertClassMember($auth, $classId);
        $cutover = Settings::eduAttendanceCutover();
        $legacyRows = DB::table('edu_attendance')
            ->where(['class_id' => $classId, 'user_id' => $auth->id])
            ->where('session_date', '<', $cutover)
            ->orderByDesc('session_date')
            ->select('session_date', 'status', 'via')
            ->get()->map(fn ($r) => (array) $r)->all();

        $programRows = DB::table('attendance as a')
            ->join('attendance_edu_classes as ac', 'ac.attendance_id', '=', 'a.id')
            ->where('ac.class_id', $classId)
            ->where('a.user_id', $auth->id)
            ->where('a.occurrence_date', '>=', $cutover)
            ->orderByDesc('a.occurrence_date')
            ->select('a.occurrence_date as session_date', 'a.status', 'a.via')
            ->get()->map(fn ($r) => (array) $r)->all();

        $rows = array_merge($programRows, $legacyRows);
        usort($rows, fn ($a, $b) => strcmp($b['session_date'], $a['session_date']));

        return ['summary' => self::attendanceSummary($classId, $auth->id), 'sessions' => $rows];
    }

    public static function roster(AuthContext $auth, int $classId, string $date): array
    {
        self::assertAttendance($auth, $classId);
        $rows = DB::table('edu_enrollments as e')->join('users as u', 'u.id', '=', 'e.user_id')
            ->leftJoin('edu_attendance as a', fn ($j) => $j->on('a.user_id', '=', 'e.user_id')->on('a.class_id', '=', 'e.class_id')->where('a.session_date', '=', $date))
            ->where(['e.class_id' => $classId, 'e.status' => 'active'])
            ->select('u.id as user_id', 'u.full_name', 'u.profile_image', 'e.program', 'a.status', 'a.via')->orderBy('u.full_name')
            ->get()->map(fn ($r) => self::strip($r))->all();

        // Also bridge unified attendance marks from attendance + attendance_edu_classes
        if (Schema::hasTable('attendance') && Schema::hasTable('attendance_edu_classes')) {
            try {
                $unifiedMarks = DB::table('attendance as att')
                    ->join('attendance_edu_classes as aec', 'aec.attendance_id', '=', 'att.id')
                    ->where('aec.class_id', $classId)
                    ->where('att.occurrence_date', $date)
                    ->pluck('att.status', 'att.user_id')
                    ->all();

                foreach ($rows as $r) {
                    if (empty($r->status) && isset($unifiedMarks[$r->user_id])) {
                        $r->status = $unifiedMarks[$r->user_id];
                        $r->via = 'programs_unified';
                    }
                }
            } catch (\Throwable) {
                // Ignore fallback error on mock/partial tables
            }
        }

        return $rows;
    }

    private static function markOne(AuthContext $auth, int $classId, string $date, int $userId, string $status, string $via): void
    {
        if (! self::enrollment($classId, $userId)) throw ApiError::conflict('NOT_ENROLLED', 'This member is not enrolled in the class');
        DB::table('edu_attendance')->upsert([['class_id' => $classId, 'session_date' => $date, 'user_id' => $userId, 'status' => $status, 'via' => $via, 'recorded_by' => $auth->id]], ['class_id', 'session_date', 'user_id'], ['status', 'via', 'recorded_by']);
        Choir::scheduleEligibility([$userId]);
    }

    public static function mark(AuthContext $auth, int $classId, array $in): array
    {
        if ($in['date'] >= Settings::eduAttendanceCutover()) {
            throw ApiError::gone('EDU_ATTENDANCE_MOVED', 'Class attendance has moved to programs');
        }
        self::assertAttendance($auth, $classId);
        self::markOne($auth, $classId, $in['date'], $in['user_id'], $in['status'], 'manual');
        return ['user_id' => $in['user_id'], 'status' => $in['status']];
    }

    public static function markByQr(AuthContext $auth, int $classId, array $in): array
    {
        if ($in['date'] >= Settings::eduAttendanceCutover()) {
            throw ApiError::gone('EDU_ATTENDANCE_MOVED', 'Class attendance has moved to programs');
        }
        self::assertAttendance($auth, $classId);
        $userId = Members::idByUuid($in['uuid']);
        self::markOne($auth, $classId, $in['date'], $userId, $in['status'], 'qr');
        $u = DB::table('users')->where('id', $userId)->first(['id', 'full_name', 'profile_image']);
        return ['user_id' => $u->id, 'full_name' => $u->full_name, 'avatar_url' => Storage::url($u->profile_image), 'status' => $in['status']];
    }

    // ------------------------------------------------------------------ teachers
    public static function courseForTeacher(AuthContext $auth, int $courseId): array
    {
        $c = self::assertTeaches($auth, $courseId);
        $detail = self::courseDetail($courseId);
        $roster = DB::table('edu_enrollments as e')->join('users as u', 'u.id', '=', 'e.user_id')->where(['e.class_id' => $c->class_id, 'e.status' => 'active'])
            ->select('u.id as user_id', 'u.full_name', 'e.program')->orderBy('u.full_name')->get();
        $groups = self::groupsOf($courseId);
        $groupOf = [];
        foreach ($groups as $g) foreach ($g['members'] as $m) $groupOf[$m['user_id']] = $g['name'];
        return $detail + ['students' => $roster->map(fn ($s) => (array) $s + ['group' => $groupOf[$s->user_id] ?? null])->all(), 'groups' => $groups];
    }

    private static function groupsOf(int $courseId): array
    {
        $groups = DB::table('edu_groups')->where('course_id', $courseId)->orderBy('name')->get();
        $members = DB::table('edu_group_members as gm')->join('users as u', 'u.id', '=', 'gm.user_id')->whereIn('gm.group_id', $groups->pluck('id')->all())
            ->select('gm.group_id', 'u.id as user_id', 'u.full_name')->get();
        return $groups->map(fn ($g) => [
            'id' => $g->id, 'name' => $g->name,
            'members' => $members->filter(fn ($m) => $m->group_id === $g->id)->map(fn ($m) => ['user_id' => $m->user_id, 'full_name' => $m->full_name])->values()->all(),
        ])->all();
    }

    public static function createGroup(AuthContext $auth, int $courseId, string $name, array $userIds): array
    {
        $c = self::assertTeaches($auth, $courseId);
        $id = DB::table('edu_groups')->insertGetId(['course_id' => $courseId, 'name' => $name]);
        self::setGroupMembers($auth, $id, $userIds, $c);
        return self::groupsOf($courseId);
    }

    public static function setGroupMembers(AuthContext $auth, int $groupId, array $userIds, ?object $course = null): array
    {
        $g = DB::table('edu_groups')->where('id', $groupId)->first();
        if (! $g) throw ApiError::notFound('GROUP_NOT_FOUND', 'Group not found');
        $c = $course ?? self::assertTeaches($auth, $g->course_id);
        $enrolled = array_map('intval', DB::table('edu_enrollments')->where(['class_id' => $c->class_id, 'status' => 'active'])->pluck('user_id')->all());
        $valid = array_values(array_filter(array_unique($userIds), fn ($u) => in_array($u, $enrolled, true)));
        DB::transaction(function () use ($g, $groupId, $valid) {
            $siblings = DB::table('edu_groups')->where('course_id', $g->course_id)->pluck('id')->all();
            if ($valid) DB::table('edu_group_members')->whereIn('group_id', $siblings)->whereIn('user_id', $valid)->delete();
            DB::table('edu_group_members')->where('group_id', $groupId)->delete();
            if ($valid) DB::table('edu_group_members')->insert(array_map(fn ($u) => ['group_id' => $groupId, 'user_id' => $u], $valid));
        });
        return self::groupsOf($g->course_id);
    }

    public static function deleteGroup(AuthContext $auth, int $groupId): array
    {
        $g = DB::table('edu_groups')->where('id', $groupId)->first();
        if (! $g) throw ApiError::notFound('GROUP_NOT_FOUND', 'Group not found');
        self::assertTeaches($auth, $g->course_id);
        DB::table('edu_groups')->where('id', $groupId)->delete();
        return self::groupsOf($g->course_id);
    }

    private static function serializeAssignment(object $a): array
    {
        $out = ['id' => $a->id, 'course_id' => $a->course_id];
        if (isset($a->course_name)) $out['course_name'] = $a->course_name;
        $targets = null;
        if (! empty($a->target_user_ids)) {
            $targets = is_array($a->target_user_ids) ? $a->target_user_ids : json_decode($a->target_user_ids, true);
        }
        $out += [
            'title' => $a->title, 'instructions' => $a->instructions, 'due_at' => $a->due_at, 'max_score' => self::num($a->max_score),
            'is_group' => (bool) $a->is_group, 'attachment_url' => Storage::url($a->attachment),
            'publish_at' => $a->publish_at ?? null,
            'late_policy' => $a->late_policy ?? 'refuse',
            'late_until' => $a->late_until ?? null,
            'allow_resubmit' => (bool) ($a->allow_resubmit ?? true),
            'target_user_ids' => $targets,
            'status' => $a->status ?? 'published',
        ];
        if (property_exists($a, 'submission_count')) $out['submission_count'] = (int) $a->submission_count;
        $out['created_at'] = $a->created_at;
        return $out;
    }

    private static function assignment(int $id): object
    {
        $a = DB::table('edu_assignments')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Assignment not found');
        return $a;
    }

    public static function listAssignments(AuthContext $auth, int $courseId): array
    {
        self::assertTeaches($auth, $courseId);
        return DB::table('edu_assignments as a')->where('a.course_id', $courseId)
            ->select('a.*', DB::raw('(SELECT COUNT(*) FROM edu_submissions s WHERE s.assignment_id = a.id) as submission_count'))->orderByDesc('a.created_at')
            ->get()->map(fn ($a) => self::serializeAssignment($a))->all();
    }

    public static function createAssignment(AuthContext $auth, int $courseId, array $input): array
    {
        $c = self::assertTeaches($auth, $courseId);
        $targets = null;
        if (! empty($input['target_user_ids'])) {
            $targets = is_array($input['target_user_ids']) ? json_encode(array_values($input['target_user_ids'])) : $input['target_user_ids'];
        }
        $id = DB::table('edu_assignments')->insertGetId([
            'course_id' => $courseId, 'title' => $input['title'], 'instructions' => $input['instructions'] ?? null, 'due_at' => $input['due_at'] ?? null,
            'publish_at' => $input['publish_at'] ?? null,
            'late_policy' => $input['late_policy'] ?? 'refuse',
            'late_until' => $input['late_until'] ?? null,
            'allow_resubmit' => isset($input['allow_resubmit']) ? ($input['allow_resubmit'] ? 1 : 0) : 1,
            'target_user_ids' => $targets,
            'status' => $input['status'] ?? 'published',
            'max_score' => $input['max_score'] ?? 100, 'is_group' => $input['is_group'] ?? false, 'created_by' => $auth->id,
        ]);
        $course = self::courseDetail($courseId);
        $ids = DB::table('edu_enrollments')->where(['class_id' => $c->class_id, 'status' => 'active'])->pluck('user_id')->all();
        if ($ids) {
            $n = Notifications::createForUsers($ids, [
                'type' => 'education',
                'title' => T::t('edu.assignment.title'),
                'body' => T::t('edu.assignment.body', ['title' => $input['title'], 'course' => $course['name']]),
                'entityType' => 'edu_assignment',
                'entityId' => $id,
                'dedupeKey' => fn ($uid) => "edu:assignment:$id:$uid",
            ]);
            if ($n) Notifications::kick();
        }
        return self::serializeAssignment(self::assignment($id));
    }

    public static function updateAssignment(AuthContext $auth, int $id, array $input): array
    {
        $a = self::assignment($id);
        self::assertTeaches($auth, $a->course_id);
        $patch = self::pick(['title', 'instructions', 'due_at', 'publish_at', 'late_policy', 'late_until', 'allow_resubmit', 'status', 'max_score', 'is_group'], $input);
        if (array_key_exists('target_user_ids', $input)) {
            $patch['target_user_ids'] = ! empty($input['target_user_ids']) ? (is_array($input['target_user_ids']) ? json_encode(array_values($input['target_user_ids'])) : $input['target_user_ids']) : null;
        }
        if (array_key_exists('allow_resubmit', $patch)) {
            $patch['allow_resubmit'] = $patch['allow_resubmit'] ? 1 : 0;
        }
        if ($patch) DB::table('edu_assignments')->where('id', $id)->update($patch);
        return self::serializeAssignment(self::assignment($id));
    }

    public static function deleteAssignment(AuthContext $auth, int $id): void
    {
        $a = self::assignment($id);
        self::assertTeaches($auth, $a->course_id);
        $files = DB::table('edu_submissions')->where('assignment_id', $id)->whereNotNull('file')->pluck('file')->all();
        DB::table('edu_assignments')->where('id', $id)->delete();
        foreach (array_merge([$a->attachment], $files) as $f) if ($f) Storage::remove($f);
    }

    public static function setAssignmentFile(AuthContext $auth, int $id, UploadedFile $file): array
    {
        $a = self::assignment($id);
        self::assertTeaches($auth, $a->course_id);
        $saved = Storage::save('document', Storage::FOLDERS['EDU_FILES'], $file);
        DB::table('edu_assignments')->where('id', $id)->update(['attachment' => $saved['path']]);
        if ($a->attachment) Storage::remove($a->attachment);
        return self::serializeAssignment(self::assignment($id));
    }

    private static function serializeSubmission(object $s): array
    {
        $out = ['id' => $s->id, 'assignment_id' => $s->assignment_id, 'user_id' => $s->user_id];
        if (isset($s->full_name)) $out['full_name'] = $s->full_name;
        return $out + [
            'group_id' => $s->group_id, 'group_name' => $s->group_name ?? null, 'text' => $s->text, 'file_url' => Storage::url($s->file), 'file_name' => $s->file_name,
            'score' => self::num($s->score), 'feedback' => $s->feedback, 'graded_at' => $s->graded_at,
            'is_late' => (bool) ($s->is_late ?? false),
            'submitted_at' => $s->submitted_at ?? $s->updated_at ?? $s->created_at,
        ];
    }

    public static function submissions(AuthContext $auth, int $assignmentId): array
    {
        $a = self::assignment($assignmentId);
        self::assertTeaches($auth, $a->course_id);
        $rows = DB::table('edu_submissions as s')->join('users as u', 'u.id', '=', 's.user_id')->leftJoin('edu_groups as g', 'g.id', '=', 's.group_id')
            ->where('s.assignment_id', $assignmentId)->select('s.*', 'u.full_name', 'g.name as group_name')->orderByDesc('s.updated_at')->get();
        return ['assignment' => self::serializeAssignment($a), 'submissions' => $rows->map(fn ($s) => self::serializeSubmission($s))->all()];
    }

    public static function grade(AuthContext $auth, int $submissionId, array $in): array
    {
        $s = DB::table('edu_submissions')->where('id', $submissionId)->first();
        if (! $s) throw ApiError::notFound('SUBMISSION_NOT_FOUND', 'Submission not found');
        $a = self::assignment($s->assignment_id);
        self::assertTeaches($auth, $a->course_id);
        $score = $in['score'] ?? null;
        if ($score !== null && $score > Num::n($a->max_score)) throw ApiError::validation([['field' => 'score', 'code' => 'SCORE_TOO_HIGH', 'message' => 'SCORE_TOO_HIGH']]);
        DB::table('edu_submissions')->where('id', $submissionId)->update(['score' => $score, 'feedback' => $in['feedback'] ?? null, 'graded_by' => $auth->id, 'graded_at' => Dates::now()]);
        $recipients = $s->group_id ? DB::table('edu_group_members')->where('group_id', $s->group_id)->pluck('user_id')->all() : [$s->user_id];
        $stamp = (int) floor(microtime(true) * 1000);
        $n = Notifications::createForUsers($recipients, [
            'type' => 'education',
            'title' => T::t('edu.graded.title'),
            'body' => T::t('edu.graded.body', ['title' => $a->title]),
            'entityType' => 'edu_assignment',
            'entityId' => $a->id,
            'dedupeKey' => fn ($uid) => "edu:graded:$submissionId:$uid:$stamp",
        ]);
        if ($n) Notifications::kick();
        return self::serializeSubmission(DB::table('edu_submissions')->where('id', $submissionId)->first());
    }

    // ------------------------------------------------------------------ assessments
    private static function serializeAssessment(object $a): array
    {
        return ['id' => $a->id, 'course_id' => $a->course_id, 'title' => $a->title, 'max_score' => self::num($a->max_score), 'weight' => self::num($a->weight), 'held_on' => $a->held_on];
    }

    private static function assessment(int $id): object
    {
        $a = DB::table('edu_assessments')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('ASSESSMENT_NOT_FOUND', 'Assessment not found');
        return $a;
    }

    public static function assessments(AuthContext $auth, int $courseId): array
    {
        self::assertTeaches($auth, $courseId);
        return DB::table('edu_assessments')->where('course_id', $courseId)->orderBy('held_on')->orderBy('id')->get()->map(fn ($a) => self::serializeAssessment($a))->all();
    }

    public static function createAssessment(AuthContext $auth, int $courseId, array $input): array
    {
        self::assertTeaches($auth, $courseId);
        $id = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => $input['title'], 'max_score' => $input['max_score'] ?? 100, 'weight' => $input['weight'] ?? 0, 'held_on' => $input['held_on'] ?? null]);
        return self::serializeAssessment(self::assessment($id));
    }

    public static function updateAssessment(AuthContext $auth, int $id, array $input): array
    {
        $a = self::assessment($id);
        self::assertTeaches($auth, $a->course_id);
        $patch = self::pick(['title', 'max_score', 'weight', 'held_on'], $input);
        if ($patch) DB::table('edu_assessments')->where('id', $id)->update($patch);
        return self::serializeAssessment(self::assessment($id));
    }

    public static function deleteAssessment(AuthContext $auth, int $id): void
    {
        $a = self::assessment($id);
        self::assertTeaches($auth, $a->course_id);
        self::assertNoRecords('assessment', [], null, $id);
        if (DB::table('edu_quizzes')->where('assessment_id', $id)->exists()) throw ApiError::conflict('HAS_RECORDS', 'A quiz sends its scores to this assessment');
        DB::table('edu_assessments')->where('id', $id)->delete();
    }

    public static function scoreSheet(AuthContext $auth, int $assessmentId): array
    {
        $a = self::assessment($assessmentId);
        $c = self::assertTeaches($auth, $a->course_id);
        $rows = self::rosterQuery($c)
            ->leftJoin('edu_scores as s', fn ($j) => $j->on('s.user_id', '=', 'u.id')->where('s.assessment_id', '=', $assessmentId))
            ->leftJoin('users as rec', 'rec.id', '=', 's.recorded_by')
            ->select('u.id as user_id', 'u.full_name', 's.score', 's.remark', 's.status', 's.review_note', 's.recorded_by', 'rec.full_name as recorded_by_name', 's.created_at as recorded_at', 's.updated_at')
            ->orderBy('u.full_name')->get();
        return [
            'assessment' => self::serializeAssessment($a),
            'scores' => $rows->map(fn ($r) => [
                'user_id' => $r->user_id,
                'full_name' => $r->full_name,
                'score' => self::num($r->score),
                'remark' => $r->remark,
                // draft / submitted / approved / rejected / published; null = nothing entered yet
                'status' => $r->status,
                'editable' => $r->status === null || in_array($r->status, EduMarks::EDITABLE, true),
                'review_note' => $r->review_note,
                'recorded_by' => $r->recorded_by,
                'recorded_by_name' => $r->recorded_by ? $r->recorded_by_name : ($r->score !== null ? 'Imported' : null),
                'recorded_at' => $r->recorded_at,
                'updated_at' => $r->updated_at,
            ])->all(),
        ];
    }

    public static function saveScores(AuthContext $auth, int $assessmentId, array $rows): array
    {
        Choir::scheduleEligibility(array_column($rows, 'user_id'));
        $a = self::assessment($assessmentId);
        $c = self::assertTeaches($auth, $a->course_id);
        $enrolled = array_map('intval', self::rosterQuery($c)->pluck('u.id')->all());
        if (count(array_unique(array_column($rows, 'user_id'))) !== count($rows)) throw ApiError::validation([['field' => 'user_id', 'code' => 'DUPLICATE', 'message' => 'DUPLICATE']]);
        foreach ($rows as $r) {
            if (! in_array($r['user_id'], $enrolled, true)) throw ApiError::validation([['field' => 'user_id', 'code' => 'NOT_ENROLLED', 'message' => 'NOT_ENROLLED']]);
            if (($r['score'] ?? null) !== null && $r['score'] > Num::n($a->max_score)) throw ApiError::validation([['field' => 'score', 'code' => 'SCORE_TOO_HIGH', 'message' => 'SCORE_TOO_HIGH']]);
        }
        DB::transaction(function () use ($rows, $assessmentId, $auth, $a) {
            $existing = DB::table('edu_scores')->where('assessment_id', $assessmentId)
                ->whereIn('user_id', array_column($rows, 'user_id'))->lockForUpdate()
                ->get()->keyBy('user_id');
            // Submitted, approved or published marks are no longer edited here (review / amendment).
            foreach ($rows as $r) {
                $prev = $existing->get($r['user_id']);
                if ($prev && ! in_array($prev->status, EduMarks::EDITABLE, true) && ((string) $prev->score !== (string) ($r['score'] ?? null) || ($prev->remark ?? null) !== ($r['remark'] ?? null))) {
                    throw ApiError::conflict('MARK_LOCKED', 'This mark was already submitted; it is changed through review or amendment');
                }
            }
            $now = Dates::sql(Dates::now());
            foreach ($rows as $r) {
                $prev = $existing->get($r['user_id']);
                if ($prev && ! in_array($prev->status, EduMarks::EDITABLE, true)) continue; // unchanged locked row
                $oldScore = $prev ? $prev->score : null;
                $newScore = $r['score'] ?? null;
                DB::table('edu_scores')->upsert([[
                    'assessment_id' => $assessmentId,
                    'user_id' => $r['user_id'],
                    'score' => $newScore,
                    'remark' => $r['remark'] ?? null,
                    'status' => 'draft',
                    'recorded_by' => $auth->id,
                    'updated_at' => $now,
                ]], ['assessment_id', 'user_id'], ['score', 'remark', 'status', 'recorded_by', 'updated_at']);
                if ($prev === null || (string) $oldScore !== (string) $newScore) {
                    EduMarks::history($assessmentId, (int) $r['user_id'], $prev ? 'edited' : 'entered', ['score' => $oldScore, 'status' => $prev?->status], ['score' => $newScore, 'status' => 'draft'], $auth->id, $r['reason'] ?? null);
                }

                if ($prev === null || (string) $oldScore !== (string) $newScore) {
                    Audit::log(
                        Ctx::actx(),
                        Audit::EDU_UPDATE,
                        'edu_score',
                        $assessmentId,
                        [
                            'user_id' => $r['user_id'],
                            'assessment_id' => $assessmentId,
                            'assessment_title' => $a->title,
                            'old_score' => $oldScore !== null ? (float) $oldScore : null,
                            'new_score' => $newScore !== null ? (float) $newScore : null,
                            'recorded_by' => $auth->id,
                            'reason' => $r['reason'] ?? ($prev ? 'correction' : 'initial_entry'),
                        ],
                        inTrx: true
                    );
                }
            }
        });
        return self::scoreSheet($auth, $assessmentId);
    }

    // ------------------------------------------------------------------ students: work and results
    private static function myGroups(int $userId, array $courseIds): array
    {
        if (! $courseIds) return [];
        $out = [];
        foreach (DB::table('edu_group_members as gm')->join('edu_groups as g', 'g.id', '=', 'gm.group_id')->where('gm.user_id', $userId)->whereIn('g.course_id', $courseIds)->select('g.id', 'g.course_id', 'g.name')->get() as $r) {
            $out[$r->course_id] = $r;
        }
        return $out;
    }

    public static function myAssignments(AuthContext $auth, int $classId): array
    {
        self::assertClassMember($auth, $classId);
        // Only the subjects the student takes (a dropped subject's work is not listed, an added one's is).
        $mineIds = array_map(fn ($c) => (int) $c->id, array_values(array_filter(DB::table('edu_courses')->where('class_id', $classId)->get()->all(), fn ($c) => self::onRoster($c, $auth->id))));
        $rows = DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')->where('co.class_id', $classId)->whereIn('co.id', $mineIds ?: [0])
            ->select('a.*', 'co.name as course_name')->orderBy('a.due_at')->orderByDesc('a.id')->get();
        $groups = self::myGroups($auth->id, array_values(array_unique($rows->pluck('course_id')->all())));
        $out = [];
        foreach ($rows as $a) {
            $g = $groups[$a->course_id] ?? null;
            $sub = DB::table('edu_submissions')->where('assignment_id', $a->id)
                ->where(fn ($w) => $a->is_group && $g ? $w->where('group_id', $g->id)->orWhere('user_id', $auth->id) : $w->where('user_id', $auth->id))
                ->orderByDesc('updated_at')->first();
            $out[] = self::serializeAssignment($a) + ['my_group' => $g ? ['id' => $g->id, 'name' => $g->name] : null, 'submission' => $sub ? self::serializeSubmission($sub) : null];
        }
        return $out;
    }

    public static function submit(AuthContext $auth, int $assignmentId, ?string $text, ?UploadedFile $file): ?array
    {
        $a = DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')->where('a.id', $assignmentId)->first(['a.*', 'co.class_id']);
        if (! $a) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Assignment not found');
        self::assertClassMember($auth, (int) $a->class_id);
        if (! self::onRoster(self::getCourse((int) $a->course_id), $auth->id)) throw ApiError::forbidden('NOT_ENROLLED', 'You are not enrolled in this class');
        if (! $text && ! $file) throw ApiError::validation([['field' => 'text', 'code' => 'REQUIRED', 'message' => 'REQUIRED']]);

        $now = Dates::sql(Dates::now());
        if (($a->status ?? 'published') !== 'published' || (! empty($a->publish_at) && Dates::sql($a->publish_at) > $now)) {
            throw ApiError::conflict('ASSIGNMENT_NOT_OPEN', 'Assignment is not open yet');
        }

        if (! empty($a->target_user_ids)) {
            $targets = is_array($a->target_user_ids) ? $a->target_user_ids : json_decode($a->target_user_ids, true);
            if (is_array($targets) && ! in_array($auth->id, array_map('intval', $targets), true)) {
                throw ApiError::forbidden('NOT_TARGETED', 'You are not assigned to this work');
            }
        }

        $g = $a->is_group ? (self::myGroups($auth->id, [$a->course_id])[$a->course_id] ?? null) : null;
        if ($a->is_group && ! $g) throw ApiError::conflict('NO_GROUP', 'You are not in a group for this course yet');

        $existing = DB::table('edu_submissions')->where('assignment_id', $assignmentId)->where(fn ($w) => $g ? $w->where('group_id', $g->id) : $w->where('user_id', $auth->id))->first();
        if ($existing?->graded_at) {
            throw ApiError::conflict('ALREADY_GRADED', 'This work has already been graded');
        }

        if ($existing && ! (bool) ($a->allow_resubmit ?? true)) {
            throw ApiError::conflict('RESUBMIT_NOT_ALLOWED', 'Resubmissions are not allowed for this assignment');
        }

        $isLate = 0;
        if (! empty($a->due_at) && $now > Dates::sql($a->due_at)) {
            $latePolicy = $a->late_policy ?? 'refuse';
            if ($latePolicy === 'refuse') {
                throw ApiError::conflict('DEADLINE_PASSED', 'Submission deadline has passed');
            }
            if (! empty($a->late_until) && $now > Dates::sql($a->late_until)) {
                throw ApiError::conflict('DEADLINE_PASSED', 'Late submission deadline has passed');
            }
            $isLate = 1;
        }

        $saved = $file ? Storage::save('document', Storage::FOLDERS['EDU_FILES'], $file) : null;
        $fileName = $saved ? mb_substr((string) $file->getClientOriginalName(), 0, 255) : ($existing->file_name ?? null);
        $filePath = $saved ? $saved['path'] : ($existing->file ?? null);

        $row = [
            'text' => $text,
            'group_id' => $g?->id,
            'user_id' => $auth->id,
            'is_late' => $isLate,
            'submitted_at' => $now,
            'file' => $filePath,
            'file_name' => $fileName,
        ];

        if ($existing) {
            DB::table('edu_submissions')->where('id', $existing->id)->update($row);
            $subId = $existing->id;
        } else {
            $subId = DB::table('edu_submissions')->insertGetId($row + ['assignment_id' => $assignmentId]);
        }

        DB::table('edu_submission_versions')->insert([
            'submission_id' => $subId,
            'text' => $text,
            'file' => $filePath,
            'file_name' => $fileName,
            'submitted_at' => $now,
            'is_late' => $isLate,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach (self::myAssignments($auth, $a->class_id) as $x) if ($x['id'] === $assignmentId) return $x;
        return null;
    }

    public static function submissionVersions(AuthContext $auth, int $submissionId): array
    {
        $s = DB::table('edu_submissions')->where('id', $submissionId)->first();
        if (! $s) throw ApiError::notFound('SUBMISSION_NOT_FOUND', 'Submission not found');
        $a = self::assignment($s->assignment_id);
        if ($s->user_id !== $auth->id && ! self::isModerator($auth)) {
            self::assertTeaches($auth, $a->course_id);
        }
        return DB::table('edu_submission_versions')->where('submission_id', $submissionId)->orderByDesc('id')->get()->map(fn ($v) => [
            'id' => (int) $v->id,
            'submission_id' => (int) $v->submission_id,
            'text' => $v->text,
            'file_url' => Storage::url($v->file),
            'file_name' => $v->file_name,
            'submitted_at' => $v->submitted_at,
            'is_late' => (bool) $v->is_late,
        ])->all();
    }

    public static function myResults(AuthContext $auth, int $classId): array
    {
        self::assertClassMember($auth, $classId);
        $enrolled = (bool) self::enrollment($classId, $auth->id);
        $out = [];
        // The class's subjects the student has not dropped (subjects added from elsewhere are listed in their own class).
        foreach (DB::table('edu_courses')->where('class_id', $classId)->orderBy('name')->get()->filter(fn ($c) => self::onRoster($c, $auth->id)) as $c) {
            // Only published marks are shown; anything else is "pending" (never shown as 0).
            $rows = DB::table('edu_assessments as a')->leftJoin('edu_scores as s', fn ($j) => $j->on('s.assessment_id', '=', 'a.id')->where('s.user_id', '=', $auth->id)->where('s.status', '=', 'published'))
                ->where('a.course_id', $c->id)->select('a.*', 's.score', 's.remark', 's.published_at')->orderBy('a.held_on')->get();
            $weighted = 0;
            $weightSum = 0;
            foreach ($rows as $r) {
                if ($r->score === null) continue;
                $w = Num::n($r->weight);
                $weighted += (Num::n($r->score) / Num::n($r->max_score)) * $w;
                $weightSum += $w;
            }
            $out[] = [
                'course' => ['id' => $c->id, 'name' => $c->name],
                'assessments' => $rows->map(fn ($r) => self::serializeAssessment($r) + ['score' => self::num($r->score), 'remark' => $r->remark, 'published' => $r->published_at !== null, 'published_at' => $r->published_at])->all(),
                'total_percent' => $weightSum ? Num::round1($weighted / $weightSum * 100) : null,
            ];
        }
        return ['courses' => $out, 'attendance' => $enrolled ? self::attendanceSummary($classId, $auth->id) : null];
    }

    /** "Class tomorrow" reminder, evenings (runs with the program reminder job). */
    public static function runClassReminders(?DateTimeInterface $now = null): int
    {
        $local = DateTimeImmutable::createFromInterface($now ?? Dates::now())->setTimezone(Dates::tz());
        if ((int) $local->format('G') < 18) return 0;
        $tomorrow = $local->modify('+1 day');
        $wd = (int) $tomorrow->format('N');
        $date = $tomorrow->format('Y-m-d');
        $rows = DB::table('edu_schedule as s')->join('edu_classes as c', 'c.id', '=', 's.class_id')->leftJoin('edu_courses as co', 'co.id', '=', 's.course_id')
            ->where('s.weekday', $wd)->where('c.status', 'active')->select('s.*', 'c.name as class_name', 'co.name as course_name', 'co.teacher_user_id', 'co.completed_at as course_completed_at')->orderBy('s.starts')->get()
            // monthly rows only on their week; finished courses no longer remind
            ->filter(fn ($s) => self::scheduleApplies($s, $date, null, $s->course_id && $s->course_completed_at ? [(int) $s->course_id => Dates::toDateOnly($s->course_completed_at)] : []))->values();
        $byClass = [];
        foreach ($rows as $r) $byClass[$r->class_id][] = $r;
        $created = 0;
        foreach ($byClass as $classId => $sessions) {
            $students = DB::table('edu_enrollments')->where(['class_id' => $classId, 'status' => 'active'])->pluck('user_id')->all();
            $teachers = array_filter(array_map(fn ($s) => $s->teacher_user_id, $sessions));
            $ids = array_values(array_unique(array_map('intval', array_merge($students, $teachers))));
            if (! $ids) continue;
            $first = $sessions[0];
            $what = implode('، ', array_filter(array_map(fn ($s) => $s->course_name, $sessions))) ?: $first->class_name;
            $created += Notifications::createForUsers($ids, [
                'type' => 'education',
                'title' => T::t('edu.tomorrow.title'),
                'body' => T::t('edu.tomorrow.body', ['class' => $first->class_name, 'time' => $first->starts, 'what' => $what, 'location' => $first->location ?: '-']),
                'entityType' => 'edu_class',
                'entityId' => $classId,
                'dedupeKey' => fn ($uid) => "edu:tomorrow:$classId:$date:$uid",
            ]);
        }
        return $created;
    }
}
