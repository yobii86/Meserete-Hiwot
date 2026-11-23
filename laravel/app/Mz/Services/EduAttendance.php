<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Education Attendance Service for the dedicated Education Attendance Dashboard.
 * Integrates directly with the unified attendance engine and Education models (classes, courses, levels, academic years).
 */
final class EduAttendance
{
    /**
     * Dashboard overview and performance analytics for Education administrators.
     */
    public static function dashboard(AuthContext $auth, array $f): array
    {
        $currentEth = EthiopianCalendar::todayInAddis();
        $year = (int) ($f['year'] ?? $currentEth['ethiopian_year']);
        if ($year < 1900 || $year > 2200) {
            $year = (int) $currentEth['ethiopian_year'];
        }

        $month = ! empty($f['month']) ? max(1, min(13, (int) $f['month'])) : null;

        if ($month !== null) {
            $days = EthiopianCalendar::daysInMonth($year, $month);
            $fromDate = EthiopianCalendar::toGregorian($year, $month, 1)->format('Y-m-d');
            $toDate = EthiopianCalendar::toGregorian($year, $month, $days)->format('Y-m-d');
        } elseif (! empty($f['from']) && ! empty($f['to'])) {
            $fromDate = Dates::toDateOnly($f['from']);
            $toDate = Dates::toDateOnly($f['to']);
        } else {
            $fromDate = EthiopianCalendar::toGregorian($year, 1, 1)->format('Y-m-d');
            $pagumeDays = EthiopianCalendar::daysInMonth($year, 13);
            $toDate = EthiopianCalendar::toGregorian($year, 13, $pagumeDays)->format('Y-m-d');
        }

        // Base query for attendance in Education scope
        $qb = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->leftJoin('attendance_edu_classes as aec', 'aec.attendance_id', '=', 'a.id')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'aec.class_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->whereBetween('a.occurrence_date', [$fromDate, $toDate]);

        // Ensure Education scope
        $qb->where(function ($w) {
            $w->where('pc.is_education', true)
              ->orWhereNotNull('aec.class_id');
            if (Schema::hasTable('program_edu_classes')) {
                $w->orWhereExists(function ($sq) {
                    $sq->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id');
                });
            }
        });

        // Apply filters
        if (! empty($f['academic_year_id'])) {
            $qb->where('c.academic_year_id', (int) $f['academic_year_id']);
        }
        if (! empty($f['level_id'])) {
            $qb->where('c.level_id', (int) $f['level_id']);
        }
        if (! empty($f['class_id'])) {
            $classId = (int) $f['class_id'];
            $qb->where(function ($w) use ($classId) {
                $w->where('aec.class_id', $classId);
                if (Schema::hasTable('edu_enrollments')) {
                    $w->orWhereExists(function ($sq) use ($classId) {
                        $sq->select(DB::raw(1))->from('edu_enrollments as enr')->whereColumn('enr.user_id', 'a.user_id')->where('enr.class_id', $classId);
                    });
                }
            });
        }
        if (! empty($f['course_id'])) {
            $courseId = (int) $f['course_id'];
            if (Schema::hasTable('program_edu_courses')) {
                $qb->whereExists(function ($sq) use ($courseId) {
                    $sq->select(DB::raw(1))->from('program_edu_courses as pec_c')
                        ->whereColumn('pec_c.program_id', 'p.id')
                        ->where('pec_c.course_id', $courseId);
                });
            }
        }
        if (! empty($f['program_id'])) {
            $qb->where('a.program_id', (int) $f['program_id']);
        }
        if (! empty($f['category_id'])) {
            $qb->where('p.category_id', (int) $f['category_id']);
        }
        if (! empty($f['status'])) {
            $st = $f['status'];
            if ($st === 'present') {
                $qb->whereIn('a.status', ['present', 'late']);
            } else {
                $qb->where('a.status', $st);
            }
        }
        if (! empty($f['user_id'])) {
            $qb->where('a.user_id', (int) $f['user_id']);
        }
        if (! empty($f['q'])) {
            $term = trim((string) $f['q']);
            $qb->where(function ($w) use ($term) {
                $w->where('u.full_name', 'like', "%{$term}%")
                  ->orWhere('u.phone', 'like', "%{$term}%")
                  ->orWhere('u.member_no', 'like', "%{$term}%")
                  ->orWhere('p.title', 'like', "%{$term}%");
            });
        }

        $records = $qb->select([
            'a.id',
            'a.program_id',
            'a.user_id',
            'a.occurrence_date',
            'a.status',
            'p.title as program_title',
            'p.category_id',
            'pc.name as category_name',
            'pc.color as category_color',
            'u.full_name as student_name',
            'u.profile_image',
            'u.phone',
            'u.member_no',
            'c.id as class_id',
            'c.name as class_name',
            'lvl.name as level_name',
        ])->get();

        // 1. KPI Calculations
        $presentCount = 0;
        $absentCount = 0;
        $excusedCount = 0;
        $studentMap = [];
        $sessionsMap = [];
        $programMap = [];
        $classMap = [];

        // Ethiopian month trend buckets (all 13 months)
        $monthBuckets = [];
        for ($m = 1; $m <= 13; $m++) {
            $mDays = EthiopianCalendar::daysInMonth($year, $m);
            $monthBuckets[$m] = [
                'month' => $m,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$m],
                'month_name_en' => EthiopianCalendar::MONTHS_EN[$m],
                'present' => 0,
                'absent' => 0,
                'excused' => 0,
                'expected' => 0,
                'rate' => 0.0,
            ];
        }

        foreach ($records as $r) {
            $dateOnly = Dates::toDateOnly($r->occurrence_date);
            [$gy, $gm, $gd] = array_map('intval', explode('-', substr($dateOnly, 0, 10)));
            $eth = EthiopianCalendar::fromGregorian($gy, $gm, $gd);
            $ethMonth = (int) $eth['month'];

            $isPres = in_array($r->status, ['present', 'late'], true);
            $isAbs = $r->status === 'absent';
            $isExc = $r->status === 'excused';

            if ($isPres) $presentCount++;
            elseif ($isAbs) $absentCount++;
            elseif ($isExc) $excusedCount++;

            // Session tracker
            $sessKey = "{$r->program_id}:{$dateOnly}";
            $sessionsMap[$sessKey] = true;

            // Student performance tracker
            $uid = (int) $r->user_id;
            if (! isset($studentMap[$uid])) {
                $studentMap[$uid] = [
                    'id' => $uid,
                    'full_name' => $r->student_name,
                    'profile_image' => $r->profile_image,
                    'phone' => $r->phone,
                    'member_no' => $r->member_no,
                    'class_name' => $r->class_name ?? '—',
                    'level_name' => $r->level_name ?? '',
                    'present' => 0,
                    'absent' => 0,
                    'excused' => 0,
                    'total' => 0,
                    'rate' => 0.0,
                ];
            }
            if ($isPres) $studentMap[$uid]['present']++;
            elseif ($isAbs) $studentMap[$uid]['absent']++;
            elseif ($isExc) $studentMap[$uid]['excused']++;
            $studentMap[$uid]['total']++;

            // Program breakdown
            $pid = (int) $r->program_id;
            if (! isset($programMap[$pid])) {
                $programMap[$pid] = [
                    'id' => $pid,
                    'title' => $r->program_title,
                    'category_name' => $r->category_name ?? 'Education',
                    'category_color' => $r->category_color,
                    'sessions' => [],
                    'present' => 0,
                    'absent' => 0,
                    'excused' => 0,
                    'total' => 0,
                    'rate' => 0.0,
                ];
            }
            $programMap[$pid]['sessions'][$dateOnly] = true;
            if ($isPres) $programMap[$pid]['present']++;
            elseif ($isAbs) $programMap[$pid]['absent']++;
            elseif ($isExc) $programMap[$pid]['excused']++;
            $programMap[$pid]['total']++;

            // Class breakdown
            $cid = (int) ($r->class_id ?? 0);
            if ($cid > 0) {
                if (! isset($classMap[$cid])) {
                    $classMap[$cid] = [
                        'id' => $cid,
                        'name' => $r->class_name,
                        'level_name' => $r->level_name ?? '',
                        'present' => 0,
                        'absent' => 0,
                        'excused' => 0,
                        'total' => 0,
                        'rate' => 0.0,
                    ];
                }
                if ($isPres) $classMap[$cid]['present']++;
                elseif ($isAbs) $classMap[$cid]['absent']++;
                elseif ($isExc) $classMap[$cid]['excused']++;
                $classMap[$cid]['total']++;
            }

            // Month trends
            if ($ethMonth >= 1 && $ethMonth <= 13) {
                if ($isPres) $monthBuckets[$ethMonth]['present']++;
                elseif ($isAbs) $monthBuckets[$ethMonth]['absent']++;
                elseif ($isExc) $monthBuckets[$ethMonth]['excused']++;
                $monthBuckets[$ethMonth]['expected']++;
            }
        }

        // Finalize student metrics
        $studentList = [];
        foreach ($studentMap as $s) {
            $s['rate'] = $s['total'] > 0 ? round(($s['present'] / $s['total']) * 100, 1) : 0.0;
            $studentList[] = $s;
        }
        usort($studentList, fn ($a, $b) => $b['rate'] <=> $a['rate'] ?: strcmp($a['full_name'], $b['full_name']));

        // Finalize program metrics
        $programList = [];
        foreach ($programMap as $p) {
            $p['session_count'] = count($p['sessions']);
            unset($p['sessions']);
            $p['rate'] = $p['total'] > 0 ? round(($p['present'] / $p['total']) * 100, 1) : 0.0;
            $programList[] = $p;
        }
        usort($programList, fn ($a, $b) => $b['total'] <=> $a['total']);

        // Finalize class metrics
        $classList = [];
        foreach ($classMap as $c) {
            $c['rate'] = $c['total'] > 0 ? round(($c['present'] / $c['total']) * 100, 1) : 0.0;
            $classList[] = $c;
        }
        usort($classList, fn ($a, $b) => strcmp($a['name'], $b['name']));

        // Finalize monthly trends
        $monthlyTrends = [];
        foreach ($monthBuckets as $m => $b) {
            $b['rate'] = $b['expected'] > 0 ? round(($b['present'] / $b['expected']) * 100, 1) : 0.0;
            $monthlyTrends[] = $b;
        }

        // Check suspended sessions
        $progIds = array_keys($programMap);
        $suspendedCount = 0;
        if (! empty($progIds) && Schema::hasTable('program_occurrence_overrides')) {
            $suspendedCount = DB::table('program_occurrence_overrides')
                ->whereIn('program_id', $progIds)
                ->whereBetween('occurrence_date', [$fromDate, $toDate])
                ->where('action', 'suspended')
                ->count();
        }
        if ($suspendedCount === 0 && ! empty($progIds) && Schema::hasTable('program_occurrences')) {
            $suspendedCount = DB::table('program_occurrences')
                ->whereIn('program_id', $progIds)
                ->whereBetween('occurrence_date', [$fromDate, $toDate])
                ->where('is_suspended', true)
                ->count();
        }

        $totalExpected = $presentCount + $absentCount + $excusedCount;
        $overallRate = $totalExpected > 0 ? round(($presentCount / $totalExpected) * 100, 1) : 0.0;

        // Filter metadata
        $metaAcademicYears = DB::table('edu_academic_years')->orderByDesc('eth_year')->get(['id', 'eth_year', 'name', 'is_current'])->map(fn ($r) => (array) $r)->all();
        $metaClasses = DB::table('edu_classes as c')
            ->leftJoin('edu_levels as l', 'l.id', '=', 'c.level_id')
            ->where('c.status', 'active')
            ->select('c.id', 'c.name', 'c.level_id', 'c.academic_year_id', 'l.name as level_name')
            ->orderBy('c.name')
            ->get()->map(fn ($r) => (array) $r)->all();
        $metaLevels = Schema::hasTable('edu_levels') ? DB::table('edu_levels')->orderBy('code')->get(['id', 'code', 'name'])->map(fn ($r) => (array) $r)->all() : [];

        $metaPrograms = DB::table('programs as p')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->where('p.status', 'published')
            ->where(function ($w) {
                $w->where('pc.is_education', true);
                if (Schema::hasTable('program_edu_classes')) {
                    $w->orWhereExists(fn ($sq) => $sq->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id'));
                }
            })
            ->select('p.id', 'p.title', 'p.category_id')
            ->orderBy('p.title')
            ->get()->map(fn ($r) => (array) $r)->all();

        return [
            'period' => [
                'year' => $year,
                'month' => $month,
                'from_date' => $fromDate,
                'to_date' => $toDate,
                'month_name_am' => $month ? (EthiopianCalendar::MONTHS_AM[$month] ?? '') : 'ሁሉም ወራት',
                'month_name_en' => $month ? (EthiopianCalendar::MONTHS_EN[$month] ?? '') : 'All Months',
            ],
            'kpi' => [
                'total_students' => count($studentMap),
                'total_sessions' => count($sessionsMap),
                'present' => $presentCount,
                'absent' => $absentCount,
                'excused' => $excusedCount,
                'total_expected' => $totalExpected,
                'attendance_rate' => $overallRate,
                'suspended_sessions' => $suspendedCount,
            ],
            'analytics' => [
                'monthly_trends' => $monthlyTrends,
                'by_program' => $programList,
                'by_class' => $classList,
                'status_distribution' => [
                    'present' => $presentCount,
                    'absent' => $absentCount,
                    'excused' => $excusedCount,
                ],
                'student_ranking' => array_slice($studentList, 0, 15),
            ],
            'students_performance' => $studentList,
            'filters_meta' => [
                'academic_years' => $metaAcademicYears,
                'levels' => $metaLevels,
                'classes' => $metaClasses,
                'programs' => $metaPrograms,
            ],
        ];
    }

    /**
     * Complete individual student attendance history across all assigned education programs.
     */
    public static function studentProfile(AuthContext $auth, int $userId, array $f): array
    {
        $u = DB::table('users')->where('id', $userId)->first(['id', 'full_name', 'phone', 'member_no', 'member_group', 'member_type', 'profile_image']);
        if (! $u) throw ApiError::notFound('STUDENT_NOT_FOUND', 'Student not found');

        $currentEth = EthiopianCalendar::todayInAddis();
        $year = (int) ($f['year'] ?? $currentEth['ethiopian_year']);
        if ($year < 1900 || $year > 2200) $year = (int) $currentEth['ethiopian_year'];

        $ethFrom = EthiopianCalendar::toGregorian($year, 1, 1)->format('Y-m-d');
        $pagumeDays = EthiopianCalendar::daysInMonth($year, 13);
        $ethTo = EthiopianCalendar::toGregorian($year, 13, $pagumeDays)->format('Y-m-d');

        // Student's active class & grade
        $enrollment = DB::table('edu_enrollments as enr')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'enr.class_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->leftJoin('edu_academic_years as ay', 'ay.id', '=', 'c.academic_year_id')
            ->where('enr.user_id', $userId)
            ->where('enr.status', 'active')
            ->select('c.id as class_id', 'c.name as class_name', 'lvl.name as grade_name', 'ay.name as academic_year_name')
            ->first();

        // Fetch student's attendance records in education programs
        $recordsQ = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->leftJoin('attendance_edu_classes as aec', 'aec.attendance_id', '=', 'a.id')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'aec.class_id')
            ->leftJoin('attendance_signatures as sig', 'sig.attendance_id', '=', 'a.id')
            ->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')
            ->where('a.user_id', $userId)
            ->whereBetween('a.occurrence_date', [$ethFrom, $ethTo])
            ->where(function ($w) {
                $w->where('pc.is_education', true)
                  ->orWhereNotNull('aec.class_id');
                if (Schema::hasTable('program_edu_classes')) {
                    $w->orWhereExists(fn ($sq) => $sq->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id'));
                }
            });

        if (Schema::hasTable('program_edu_courses')) {
            $recordsQ->leftJoin('program_edu_courses as pec_crs', 'pec_crs.program_id', '=', 'p.id')
                     ->leftJoin('edu_courses as crs', 'crs.id', '=', 'pec_crs.course_id');
        }

        $records = $recordsQ->select([
            'a.*',
            'p.title as program_title',
            'pc.name as category_name',
            'pc.color as category_color',
            'c.name as class_name',
            Schema::hasTable('program_edu_courses') ? 'crs.name as course_name' : DB::raw("NULL as course_name"),
            'sig.path as signature_path',
            'rec.full_name as recorder_name',
        ])
        ->orderByDesc('a.occurrence_date')
        ->get();

        $monthStats = [];
        for ($m = 1; $m <= 13; $m++) {
            $monthStats[$m] = [
                'month' => $m,
                'month_name_am' => EthiopianCalendar::MONTHS_AM[$m],
                'month_name_en' => EthiopianCalendar::MONTHS_EN[$m],
                'present' => 0,
                'absent' => 0,
                'excused' => 0,
                'expected' => 0,
                'attendance_rate' => 0.0,
            ];
        }

        $presTotal = 0;
        $absTotal = 0;
        $excTotal = 0;
        $detailedRecords = [];
        $uniquePrograms = [];

        foreach ($records as $r) {
            $dateOnly = Dates::toDateOnly($r->occurrence_date);
            [$gy, $gm, $gd] = array_map('intval', explode('-', substr($dateOnly, 0, 10)));
            $eth = EthiopianCalendar::fromGregorian($gy, $gm, $gd);
            $m = (int) $eth['month'];

            $isPres = in_array($r->status, ['present', 'late'], true);
            $isAbs = $r->status === 'absent';
            $isExc = $r->status === 'excused';

            if ($m >= 1 && $m <= 13) {
                if ($isPres) {
                    $presTotal++;
                    $monthStats[$m]['present']++;
                } elseif ($isAbs) {
                    $absTotal++;
                    $monthStats[$m]['absent']++;
                } elseif ($isExc) {
                    $excTotal++;
                    $monthStats[$m]['excused']++;
                }
            }

            $uniquePrograms[(int) $r->program_id] = true;

            $hasSig = ! empty($r->signature_id) || ! empty($r->signature_path);
            $calendarDate = "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም";

            $detailedRecords[] = [
                'id' => (int) $r->id,
                'program_id' => (int) $r->program_id,
                'program_title' => $r->program_title,
                'category_name' => $r->category_name ?? 'ትምህርት',
                'category_color' => $r->category_color,
                'occurrence_date' => $dateOnly,
                'calendar_date' => $calendarDate,
                'ethiopian_date' => $eth['date'],
                'starts_at' => $r->occurrence_date,
                'attended_at' => $r->attended_at,
                'status' => $r->status,
                'via' => $r->via ?? 'manual',
                'notes' => $r->notes,
                'has_signature' => $hasSig,
                'signature_status' => $hasSig ? 'signed' : ($r->status === 'present' ? 'missing' : 'exempt'),
                'signature_url' => $hasSig ? "/api/v1/programs/attendance/signatures/{$r->id}" : null,
                'recorder_id' => $r->recorded_by ? (int) $r->recorded_by : null,
                'recorder_name' => $r->recorder_name ?? '—',
                'class_name' => $r->class_name ?? ($enrollment->class_name ?? '—'),
                'course_name' => $r->course_name ?? '—',
            ];
        }

        foreach ($monthStats as $m => &$b) {
            $exp = $b['present'] + $b['absent'] + $b['excused'];
            $b['expected'] = $exp;
            $b['attendance_rate'] = $exp > 0 ? round(($b['present'] / $exp) * 100, 1) : 0.0;
        }
        unset($b);

        // Check suspended occurrences in these programs
        $suspendedCount = 0;
        if (! empty($uniquePrograms) && Schema::hasTable('program_occurrence_overrides')) {
            $suspendedCount = DB::table('program_occurrence_overrides')
                ->whereIn('program_id', array_keys($uniquePrograms))
                ->whereBetween('occurrence_date', [$ethFrom, $ethTo])
                ->where('action', 'suspended')
                ->count();
        }
        if ($suspendedCount === 0 && ! empty($uniquePrograms) && Schema::hasTable('program_occurrences')) {
            $suspendedCount = DB::table('program_occurrences')
                ->whereIn('program_id', array_keys($uniquePrograms))
                ->whereBetween('occurrence_date', [$ethFrom, $ethTo])
                ->where('is_suspended', true)
                ->count();
        }

        $grandExpected = $presTotal + $absTotal + $excTotal;
        $grandRate = $grandExpected > 0 ? round(($presTotal / $grandExpected) * 100, 1) : 0.0;

        return [
            'student' => [
                'id' => $u->id,
                'full_name' => $u->full_name,
                'phone' => $u->phone,
                'member_no' => $u->member_no,
                'member_group' => $u->member_group,
                'member_type' => $u->member_type,
                'profile_image' => $u->profile_image,
                'class_id' => $enrollment->class_id ?? null,
                'class_name' => $enrollment->class_name ?? '—',
                'grade_name' => $enrollment->grade_name ?? '—',
                'academic_year_name' => $enrollment->academic_year_name ?? '—',
            ],
            'summary' => [
                'year' => $year,
                'total_scheduled_programs' => count($uniquePrograms),
                'present_sessions' => $presTotal,
                'absent_sessions' => $absTotal,
                'excused_sessions' => $excTotal,
                'suspended_sessions' => $suspendedCount,
                'total_expected' => $grandExpected,
                'attendance_rate' => $grandRate,
            ],
            'monthly_stats' => array_values($monthStats),
            'records' => $detailedRecords,
        ];
    }

    /**
     * Detailed individual attendance record view.
     */
    public static function recordDetail(AuthContext $auth, int $attendanceId): array
    {
        $rQ = DB::table('attendance as a')
            ->join('programs as p', 'p.id', '=', 'a.program_id')
            ->join('users as u', 'u.id', '=', 'a.user_id')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->leftJoin('attendance_edu_classes as aec', 'aec.attendance_id', '=', 'a.id')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'aec.class_id')
            ->leftJoin('edu_levels as lvl', 'lvl.id', '=', 'c.level_id')
            ->leftJoin('attendance_signatures as sig', 'sig.attendance_id', '=', 'a.id')
            ->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')
            ->where('a.id', $attendanceId);

        if (Schema::hasTable('program_edu_courses')) {
            $rQ->leftJoin('program_edu_courses as pec_crs', 'pec_crs.program_id', '=', 'p.id')
               ->leftJoin('edu_courses as crs', 'crs.id', '=', 'pec_crs.course_id');
        }

        $r = $rQ->select([
            'a.*',
            'p.title as program_title',
            'p.starts_at as program_starts_at',
            'p.ends_at as program_ends_at',
            'p.location as program_location',
            'pc.name as category_name',
            'pc.color as category_color',
            'u.id as student_id',
            'u.full_name as student_name',
            'u.phone as student_phone',
            'u.member_no as student_member_no',
            'u.profile_image as student_profile_image',
            'c.name as class_name',
            'lvl.name as grade_name',
            Schema::hasTable('program_edu_courses') ? 'crs.name as course_name' : DB::raw("NULL as course_name"),
            'sig.path as signature_path',
            'rec.id as recorder_id',
            'rec.full_name as recorder_name',
        ])
        ->first();

        if (! $r) throw ApiError::notFound('RECORD_NOT_FOUND', 'Attendance record not found');

        $dateOnly = Dates::toDateOnly($r->occurrence_date);
        [$gy, $gm, $gd] = array_map('intval', explode('-', substr($dateOnly, 0, 10)));
        $eth = EthiopianCalendar::fromGregorian($gy, $gm, $gd);

        $hasSig = ! empty($r->signature_id) || ! empty($r->signature_path);
        $calendarDate = "{$eth['month_am']} {$eth['day']} ቀን {$eth['year']} ዓ.ም";

        return [
            'id' => (int) $r->id,
            'occurrence_date' => $dateOnly,
            'calendar_date' => $calendarDate,
            'ethiopian_date' => $eth['date'],
            'status' => $r->status,
            'attended_at' => $r->attended_at,
            'punctuality' => $r->punctuality ?? 'on_time',
            'via' => $r->via ?? 'manual',
            'notes' => $r->notes,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
            'student' => [
                'id' => (int) $r->student_id,
                'full_name' => $r->student_name,
                'phone' => $r->student_phone,
                'member_no' => $r->student_member_no,
                'profile_image' => $r->student_profile_image,
                'class_name' => $r->class_name ?? '—',
                'grade_name' => $r->grade_name ?? '—',
            ],
            'program' => [
                'id' => (int) $r->program_id,
                'title' => $r->program_title,
                'category_name' => $r->category_name ?? 'ትምህርት',
                'category_color' => $r->category_color,
                'scheduled_start' => $r->program_starts_at,
                'scheduled_end' => $r->program_ends_at,
                'location' => $r->program_location ?? '—',
            ],
            'education' => [
                'class_name' => $r->class_name ?? '—',
                'course_name' => $r->course_name ?? '—',
            ],
            'recorder' => [
                'id' => $r->recorder_id ? (int) $r->recorder_id : null,
                'name' => $r->recorder_name ?? '—',
            ],
            'signature' => [
                'has_signature' => $hasSig,
                'status' => $hasSig ? 'signed' : ($r->status === 'present' ? 'missing' : 'exempt'),
                'signature_url' => $hasSig ? "/api/v1/programs/attendance/signatures/{$r->id}" : null,
            ],
        ];
    }
}

