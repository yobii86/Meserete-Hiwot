<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\Passwords;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Student registration and class assignment by an administrator:
 * - education.register: enroll or assign students into active classes;
 * - education.manage: transfer and promote students between classes.
 * Enforces academic year exclusivity (F2): active students in exclusive classes
 * cannot be in another exclusive class for the same academic year.
 */
final class EduRegistration
{
    /** Active classes with their courses (what the registrar picks from). */
    public static function classes(?int $academicYearId = null): array
    {
        $qb = DB::table('edu_classes as c')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
            ->leftJoin('edu_terms as tm', 'tm.id', '=', 'c.term_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->where('c.status', 'active');

        if ($academicYearId !== null) {
            $qb->where('c.academic_year_id', $academicYearId);
        }

        $classes = $qb->orderByRaw('COALESCE(lvl.sort_order, 999) ASC')
            ->orderBy('c.name')
            ->select(
                'c.*',
                'y.eth_year as ay_eth_year',
                'y.name as ay_name',
                'y.is_current as ay_is_current',
                'tm.name as tm_name',
                'lvl.code as lvl_code',
                'lvl.name as lvl_name',
                'lvl.name_en as lvl_name_en',
                'lvl.kind as lvl_kind',
                'lvl.sort_order as lvl_sort_order',
                DB::raw("(SELECT COUNT(*) FROM edu_enrollments e WHERE e.class_id = c.id AND e.status = 'active') as student_count")
            )->get();

        $courses = DB::table('edu_courses as co')
            ->leftJoin('users as t', 't.id', '=', 'co.teacher_user_id')
            ->whereIn('co.class_id', $classes->pluck('id')->all() ?: [0])
            ->orderBy('co.name')
            ->get(['co.id', 'co.class_id', 'co.subject_id', 'co.name', 'co.code', 'co.mode', 'co.status', 'co.pass_mark', 'co.teacher_user_id', 't.full_name as teacher_name']);

        $courseIds = $courses->pluck('id')->map(fn ($x) => (int) $x)->all();
        $teachersByCourse = [];
        if (! empty($courseIds)) {
            $tRows = DB::table('edu_course_teachers as ct')
                ->join('users as u', 'u.id', '=', 'ct.user_id')
                ->whereIn('ct.course_id', $courseIds)
                ->where('ct.status', 'active')
                ->select('ct.course_id', 'u.id', 'u.full_name', 'u.phone')
                ->get();
            foreach ($tRows as $tr) {
                $teachersByCourse[$tr->course_id][] = [
                    'id' => (int) $tr->id,
                    'full_name' => $tr->full_name,
                    'phone' => $tr->phone,
                ];
            }
        }

        return $classes->map(fn ($c) => [
            'id' => (int) $c->id,
            'name' => $c->name,
            'name_en' => $c->name_en ?? null,
            'description' => $c->description ?? null,
            'description_en' => $c->description_en ?? null,
            'term' => $c->term,
            'capacity' => $c->capacity !== null ? (int) $c->capacity : null,
            'student_count' => (int) $c->student_count,
            'allow_regular' => (bool) $c->allow_regular,
            'allow_distance' => (bool) $c->allow_distance,
            'allow_multiple' => (bool) ($c->allow_multiple ?? 0),
            'allow_self_registration' => (bool) ($c->allow_self_registration ?? false),
            'academic_year_id' => $c->academic_year_id ? (int) $c->academic_year_id : null,
            'academic_year' => $c->academic_year_id ? [
                'id' => (int) $c->academic_year_id,
                'eth_year' => (int) $c->ay_eth_year,
                'name' => $c->ay_name,
                'is_current' => (bool) $c->ay_is_current,
            ] : null,
            'term_obj' => $c->term_id ? [
                'id' => (int) $c->term_id,
                'name' => $c->tm_name,
            ] : null,
            'level' => $c->level_id ? [
                'id' => (int) $c->level_id,
                'code' => $c->lvl_code,
                'name' => $c->lvl_name,
                'name_en' => $c->lvl_name_en,
                'kind' => $c->lvl_kind,
                'sort_order' => $c->lvl_sort_order !== null ? (int) $c->lvl_sort_order : null,
            ] : null,
            'courses' => $courses->where('class_id', $c->id)->values()->map(function ($co) use ($teachersByCourse) {
                $assignedTeachers = $teachersByCourse[(int) $co->id] ?? [];
                $teacherName = $co->teacher_name;
                if (! $teacherName && ! empty($assignedTeachers)) {
                    $teacherName = implode(', ', array_column($assignedTeachers, 'full_name'));
                }
                return [
                    'id' => (int) $co->id,
                    'class_id' => (int) $co->class_id,
                    'subject_id' => $co->subject_id ? (int) $co->subject_id : null,
                    'name' => $co->name,
                    'code' => $co->code ?? null,
                    'mode' => $co->mode ?? 'physical',
                    'status' => $co->status ?? 'active',
                    'pass_mark' => $co->pass_mark !== null ? (float) $co->pass_mark : 50.0,
                    'teacher_user_id' => $co->teacher_user_id ? (int) $co->teacher_user_id : null,
                    'teacher_name' => $teacherName,
                    'teachers' => $assignedTeachers,
                ];
            })->all(),
        ])->all();
    }

    public static function students(int $classId): array
    {
        if (! DB::table('edu_classes')->where('id', $classId)->exists()) {
            throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');
        }

        return DB::table('edu_enrollments as e')
            ->join('users as u', 'u.id', '=', 'e.user_id')
            ->where(['e.class_id' => $classId, 'e.status' => 'active'])
            ->whereNull('u.deleted_at')
            ->orderBy('u.full_name')
            ->get(['u.id', 'u.full_name', 'u.phone', 'u.member_no', 'u.member_group', 'e.id as enrollment_id', 'e.program', 'e.created_at'])
            ->map(fn ($u) => [
                'id' => (int) $u->id,
                'enrollment_id' => (int) $u->enrollment_id,
                'full_name' => $u->full_name,
                'phone' => $u->phone,
                'member_id' => MemberIds::format($u->member_no, $u->member_group),
                'member_group' => $u->member_group,
                'program' => $u->program,
                'enrolled_at' => $u->created_at,
            ])->all();
    }

    private static function newPin(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    /**
     * in: class_id, program, user_ids? (existing members), new_user? {full_name, phone, member_group, member_type}
     * Returns the enrolled people and temporary 6-digit PIN for new account.
     */
    public static function register(array $actx, array $in): array
    {
        $classId = (int) $in['class_id'];
        $program = $in['program'] ?? 'regular';
        $userIds = array_values(array_unique(array_map('intval', $in['user_ids'] ?? [])));
        $new = $in['new_user'] ?? null;
        if (! $userIds && ! $new) {
            throw ApiError::field('user_ids', 'REQUIRED');
        }

        $pin = null;
        $newId = null;
        if ($new) {
            $taken = Users::phoneOrEmailTaken($new['phone'], null);
            if ($taken) {
                throw ApiError::conflict('ACCOUNT_EXISTS', 'Account already exists', $taken);
            }
        }

        $result = DB::transaction(function () use ($actx, $classId, $program, $userIds, $new, &$pin, &$newId) {
            $c = DB::table('edu_classes')->where('id', $classId)->lockForUpdate()->first();
            if (! $c || $c->status !== 'active') {
                throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');
            }
            if (($program === 'regular' && ! $c->allow_regular) || ($program === 'distance' && ! $c->allow_distance)) {
                throw ApiError::field('program', 'PROGRAM_NOT_OFFERED');
            }

            if ($new) {
                $pin = self::newPin();
                $newId = DB::table('users')->insertGetId([
                    'full_name' => $new['full_name'],
                    'phone' => $new['phone'],
                    'password_hash' => Passwords::hash($pin),
                    'account_type' => 'user',
                    'status' => 'active',
                    'member_group' => $new['member_group'] ?? 'youth_adult',
                    'member_type' => $new['member_type'] ?? null,
                    'created_by' => $actx['auth']->id,
                    'must_change_password' => true,
                    'password_changed_at' => DB::raw('NOW()'),
                ]);
                DB::table('user_preferences')->insert(['user_id' => $newId]);
                MemberIds::assign($newId);
                Audit::log($actx, Audit::USER_CREATE, 'user', $newId, ['via' => 'education_registration'], inTrx: true);
                $userIds[] = $newId;
            }

            $valid = MemberIds::membersAndAdmins(DB::table('users'))
                ->whereIn('id', $userIds)
                ->where('status', 'active')
                ->whereNull('deleted_at')
                ->pluck('id')
                ->map(fn ($x) => (int) $x)
                ->all();

            if (count($valid) !== count($userIds)) {
                throw ApiError::field('user_ids', 'USER_NOT_FOUND');
            }

            $already = DB::table('edu_enrollments')
                ->where(['class_id' => $classId, 'status' => 'active'])
                ->whereIn('user_id', $valid)
                ->pluck('user_id')
                ->map(fn ($x) => (int) $x)
                ->all();

            $toAdd = array_values(array_diff($valid, $already));
            if ($c->capacity) {
                $n = DB::table('edu_enrollments')->where(['class_id' => $classId, 'status' => 'active'])->count();
                if ($n + count($toAdd) > $c->capacity) {
                    throw ApiError::conflict('CLASS_FULL', 'Class is full');
                }
            }

            $isExclusive = ($c->allow_multiple ?? 0) ? 0 : 1;
            foreach ($toAdd as $uid) {
                // If exclusive, check if already in another exclusive class for the same year
                if ($isExclusive && $c->academic_year_id) {
                    $other = DB::table('edu_enrollments as e')
                        ->join('edu_classes as cl', 'cl.id', '=', 'e.class_id')
                        ->where('e.user_id', $uid)
                        ->where('e.academic_year_id', $c->academic_year_id)
                        ->where('e.exclusive', 1)
                        ->where('e.status', 'active')
                        ->where('e.class_id', '!=', $classId)
                        ->first(['cl.name as class_name']);
                    if ($other) {
                        throw ApiError::conflict('ALREADY_ENROLLED', "User is already active in exclusive class {$other->class_name} for this academic year");
                    }
                }

                $existingRow = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $uid])->first();
                if ($existingRow) {
                    DB::table('edu_enrollments')->where('id', $existingRow->id)->update([
                        'program' => $program,
                        'academic_year_id' => $c->academic_year_id,
                        'exclusive' => $isExclusive,
                        'status' => 'active',
                        'updated_at' => now(),
                    ]);
                } else {
                    DB::table('edu_enrollments')->insert([
                        'class_id' => $classId,
                        'user_id' => $uid,
                        'academic_year_id' => $c->academic_year_id,
                        'exclusive' => $isExclusive,
                        'program' => $program,
                        'status' => 'active',
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                EduJourney::record((int) $uid, 'enrolled', ['class_id' => $classId, 'new' => $program], $actx['auth']->id);
            }

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, [
                'registered' => $toAdd,
                'already' => $already,
                'program' => $program,
                'new_user' => $newId,
            ], inTrx: true);

            return ['class' => $c, 'added' => $toAdd, 'already' => $already];
        });

        $courses = DB::table('edu_courses')->where('class_id', $classId)->orderBy('name')->pluck('name')->all();
        if ($result['added']) {
            Notifications::createForUsers($result['added'], [
                'type' => 'education',
                'title' => T::t('edu.registered.title'),
                'body' => T::t('edu.registered.body', ['class' => $result['class']->name, 'courses' => $courses ? implode(', ', $courses) : '-']),
                'entityType' => 'edu_class',
                'entityId' => $classId,
                'dedupeKey' => fn ($uid) => "edu:$classId:registered:$uid:" . time(),
            ]);
            Notifications::kick();
        }

        return [
            'registered' => count($result['added']),
            'already_enrolled' => count($result['already']),
            'new_user' => $newId ? ['id' => $newId, 'full_name' => $new['full_name'], 'phone' => DB::table('users')->where('id', $newId)->value('phone')] : null,
            'temporary_pin' => $pin,
            'courses' => $courses,
            'students' => self::students($classId),
        ];
    }

    public static function unregister(array $actx, int $classId, int $userId): array
    {
        $n = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId, 'status' => 'active'])->update(['status' => 'withdrawn']);
        if ($n) {
            EduJourney::record($userId, 'withdrawn', ['class_id' => $classId, 'old' => 'active', 'new' => 'withdrawn'], $actx['auth']->id);
        }
        if (! $n) {
            throw ApiError::notFound('ENROLLMENT_NOT_FOUND', 'Enrollment not found');
        }
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, ['unregistered' => $userId]);

        return self::students($classId);
    }

    // =========================================================================
    // F2: Class Assignment (assignable, assign, transfer, promote)
    // =========================================================================

    /**
     * Lists active members eligible to be assigned to this class.
     * Excludes members already active in this class, and for exclusive classes,
     * excludes members active in another exclusive class of the same academic year.
     */
    public static function assignable(int $classId, ?string $q, ?string $group, array $pageParams): array
    {
        $class = DB::table('edu_classes')->where('id', $classId)->first();
        if (! $class) {
            throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found');
        }

        $qb = MemberIds::membersAndAdmins(DB::table('users as u'), 'u')
            ->where('u.status', 'active')
            ->whereNull('u.deleted_at');

        // Exclude anyone already active in this class
        $qb->whereNotExists(function ($sub) use ($classId) {
            $sub->select(DB::raw(1))
                ->from('edu_enrollments as e')
                ->whereColumn('e.user_id', 'u.id')
                ->where('e.class_id', $classId)
                ->where('e.status', 'active');
        });

        // If this class is exclusive, exclude anyone active in another exclusive class for the same year
        $isExclusive = ($class->allow_multiple ?? 0) ? 0 : 1;
        if ($isExclusive && $class->academic_year_id) {
            $qb->whereNotExists(function ($sub) use ($class) {
                $sub->select(DB::raw(1))
                    ->from('edu_enrollments as e')
                    ->whereColumn('e.user_id', 'u.id')
                    ->where('e.academic_year_id', $class->academic_year_id)
                    ->where('e.exclusive', 1)
                    ->where('e.status', 'active')
                    ->where('e.class_id', '!=', $class->id);
            });
        }

        if ($group) {
            $qb->where('u.member_group', $group);
        }

        if ($q && trim($q) !== '') {
            $term = '%' . trim($q) . '%';
            $qb->where(function ($w) use ($term) {
                $w->where('u.full_name', 'LIKE', $term)
                  ->orWhere('u.phone', 'LIKE', $term)
                  ->orWhere('u.member_no', 'LIKE', $term);
            });
        }

        $qb->select('u.id', 'u.full_name', 'u.phone', 'u.member_no', 'u.member_group')
           ->orderBy('u.full_name');

        $paginated = Page::paginate($qb, $pageParams);
        $paginated['items'] = array_map(fn ($u) => [
            'id' => (int) $u->id,
            'full_name' => $u->full_name,
            'phone' => $u->phone,
            'member_id' => MemberIds::format($u->member_no, $u->member_group),
            'member_group' => $u->member_group,
        ], $paginated['items']);

        return $paginated;
    }

    /**
     * Assigns a list of users to the class atomically.
     * Returns per-user results: assigned, already_in_class, in_other_class, not_eligible.
     */
    public static function assign(array $actx, int $classId, array $in): array
    {
        $program = $in['program'] ?? 'regular';
        $userIds = array_values(array_unique(array_map('intval', $in['user_ids'] ?? [])));
        if (empty($userIds)) {
            throw ApiError::field('user_ids', 'REQUIRED');
        }

        $results = DB::transaction(function () use ($actx, $classId, $program, $userIds) {
            $c = DB::table('edu_classes')->where('id', $classId)->lockForUpdate()->first();
            if (! $c || $c->status !== 'active') {
                throw ApiError::notFound('CLASS_NOT_FOUND', 'Class not found or not active');
            }
            if (($program === 'regular' && ! $c->allow_regular) || ($program === 'distance' && ! $c->allow_distance)) {
                throw ApiError::field('program', 'PROGRAM_NOT_OFFERED');
            }

            $users = DB::table('users')
                ->whereIn('id', $userIds)
                ->where('status', 'active')
                ->whereNull('deleted_at')
                ->get()
                ->keyBy('id');

            $isExclusive = ($c->allow_multiple ?? 0) ? 0 : 1;
            $userResults = [];
            $assignedIds = [];

            foreach ($userIds as $uid) {
                if (! isset($users[$uid])) {
                    $userResults[] = ['user_id' => $uid, 'status' => 'not_eligible'];
                    continue;
                }

                // Check if already active in this class
                $inThisClass = DB::table('edu_enrollments')
                    ->where(['class_id' => $classId, 'user_id' => $uid, 'status' => 'active'])
                    ->exists();
                if ($inThisClass) {
                    $userResults[] = ['user_id' => $uid, 'status' => 'already_in_class'];
                    continue;
                }

                // Check exclusivity against other classes in the same academic year
                if ($isExclusive && $c->academic_year_id) {
                    $other = DB::table('edu_enrollments as e')
                        ->join('edu_classes as cl', 'cl.id', '=', 'e.class_id')
                        ->where('e.user_id', $uid)
                        ->where('e.academic_year_id', $c->academic_year_id)
                        ->where('e.exclusive', 1)
                        ->where('e.status', 'active')
                        ->where('e.class_id', '!=', $classId)
                        ->first(['cl.name as class_name']);

                    if ($other) {
                        $userResults[] = [
                            'user_id' => $uid,
                            'status' => 'in_other_class',
                            'class_name' => $other->class_name,
                        ];
                        continue;
                    }
                }

                // Capacity check
                if ($c->capacity) {
                    $currentCount = DB::table('edu_enrollments')->where(['class_id' => $classId, 'status' => 'active'])->count();
                    if ($currentCount >= $c->capacity) {
                        $userResults[] = ['user_id' => $uid, 'status' => 'class_full'];
                        continue;
                    }
                }

                try {
                    $existingRow = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $uid])->first();
                    if ($existingRow) {
                        DB::table('edu_enrollments')->where('id', $existingRow->id)->update([
                            'program' => $program,
                            'academic_year_id' => $c->academic_year_id,
                            'exclusive' => $isExclusive,
                            'status' => 'active',
                            'updated_at' => now(),
                        ]);
                    } else {
                        DB::table('edu_enrollments')->insert([
                            'class_id' => $classId,
                            'user_id' => $uid,
                            'academic_year_id' => $c->academic_year_id,
                            'exclusive' => $isExclusive,
                            'program' => $program,
                            'status' => 'active',
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                    }

                    EduJourney::record($uid, 'assigned', ['class_id' => $classId, 'new' => $program], $actx['auth']->id);
                    Notifications::notifyEduClassAssigned($uid, $classId);
                    $assignedIds[] = $uid;
                    $userResults[] = ['user_id' => $uid, 'status' => 'assigned'];
                } catch (\Throwable $e) {
                    // Unique constraint violation on exclusive_key
                    $userResults[] = ['user_id' => $uid, 'status' => 'in_other_class'];
                }
            }

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_class', $classId, [
                'action' => 'assign',
                'assigned' => $assignedIds,
                'results' => $userResults,
            ], inTrx: true);

            return ['results' => $userResults, 'assigned_ids' => $assignedIds, 'class' => $c];
        });

        if (! empty($results['assigned_ids'])) {
            $courses = DB::table('edu_courses')->where('class_id', $classId)->orderBy('name')->pluck('name')->all();
            Notifications::createForUsers($results['assigned_ids'], [
                'type' => 'education',
                'title' => T::t('edu.registered.title'),
                'body' => T::t('edu.registered.body', ['class' => $results['class']->name, 'courses' => $courses ? implode(', ', $courses) : '-']),
                'entityType' => 'edu_class',
                'entityId' => $classId,
                'dedupeKey' => fn ($uid) => "edu:$classId:assigned:$uid:" . time(),
            ]);
            Notifications::kick();
        }

        return [
            'results' => $results['results'],
            'assigned_count' => count($results['assigned_ids']),
            'students' => self::students($classId),
        ];
    }

    /**
     * Transfers an enrolled student to another class atomically.
     * Marks old enrollment 'withdrawn' with reason, creates new active enrollment.
     */
    public static function transfer(array $actx, int $enrollmentId, int $targetClassId, string $reason): array
    {
        return DB::transaction(function () use ($actx, $enrollmentId, $targetClassId, $reason) {
            $old = DB::table('edu_enrollments')->where('id', $enrollmentId)->lockForUpdate()->first();
            if (! $old || $old->status !== 'active') {
                throw ApiError::notFound('ENROLLMENT_NOT_FOUND', 'Active enrollment not found');
            }

            if ((int) $old->class_id === $targetClassId) {
                throw ApiError::conflict('SAME_CLASS', 'Target class is the same as current class');
            }

            $target = DB::table('edu_classes')->where('id', $targetClassId)->lockForUpdate()->first();
            if (! $target || $target->status !== 'active') {
                throw ApiError::notFound('CLASS_NOT_FOUND', 'Target class not found or not active');
            }

            $isExclusive = ($target->allow_multiple ?? 0) ? 0 : 1;
            if ($isExclusive && $target->academic_year_id) {
                $conflict = DB::table('edu_enrollments')
                    ->where('user_id', $old->user_id)
                    ->where('academic_year_id', $target->academic_year_id)
                    ->where('exclusive', 1)
                    ->where('status', 'active')
                    ->where('id', '!=', $enrollmentId)
                    ->exists();

                if ($conflict) {
                    throw ApiError::conflict('ALREADY_ENROLLED', 'Student is already enrolled in another exclusive class for that year');
                }
            }

            // Mark old enrollment withdrawn
            DB::table('edu_enrollments')->where('id', $enrollmentId)->update([
                'status' => 'withdrawn',
                'updated_at' => now(),
            ]);

            // Create or update new enrollment
            $newEnrollmentId = DB::table('edu_enrollments')->insertGetId([
                'class_id' => $targetClassId,
                'user_id' => $old->user_id,
                'academic_year_id' => $target->academic_year_id,
                'exclusive' => $isExclusive,
                'program' => $old->program,
                'stream' => $old->stream,
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            EduJourney::record($old->user_id, 'withdrawn', ['class_id' => $old->class_id, 'reason' => $reason], $actx['auth']->id);
            EduJourney::record($old->user_id, 'class_changed', ['class_id' => $targetClassId, 'old' => $old->class_id, 'reason' => $reason], $actx['auth']->id);
            Notifications::notifyEduPromotion((int) $old->user_id, $target->name ?? 'ክፍል');

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_enrollment', $enrollmentId, [
                'action' => 'transfer',
                'old_class_id' => $old->class_id,
                'target_class_id' => $targetClassId,
                'new_enrollment_id' => $newEnrollmentId,
                'reason' => $reason,
            ], inTrx: true);

            return [
                'old_enrollment_id' => (int) $enrollmentId,
                'new_enrollment_id' => (int) $newEnrollmentId,
                'user_id' => (int) $old->user_id,
                'target_class_id' => (int) $targetClassId,
                'status' => 'transferred',
            ];
        });
    }

    /**
     * Promotes a student into a class of the next academic year.
     */
    public static function promote(array $actx, int $enrollmentId, int $targetClassId, string $reason): array
    {
        return self::transfer($actx, $enrollmentId, $targetClassId, $reason);
    }
}
