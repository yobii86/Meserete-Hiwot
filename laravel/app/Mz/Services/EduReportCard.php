<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class EduReportCard
{
    /**
     * Gather report card data for a student.
     */
    public static function generateData(AuthContext $auth, int $studentId): array
    {
        $isSelf = (int) $auth->id === $studentId;
        if (! $isSelf && ! $auth->can('education.reports') && ! $auth->can('education.manage') && ! $auth->isAdmin) {
            $enrolledClasses = DB::table('edu_enrollments')->where('user_id', $studentId)->pluck('class_id')->all();
            $teachesStudent = false;
            if ($enrolledClasses) {
                $teachesStudent = DB::table('edu_courses as c')
                    ->leftJoin('edu_course_teachers as ct', 'ct.course_id', '=', 'c.id')
                    ->whereIn('c.class_id', $enrolledClasses)
                    ->where(fn ($q) => $q->where('c.teacher_user_id', $auth->id)
                        ->orWhere(fn ($q2) => $q2->where('ct.user_id', $auth->id)->where('ct.status', 'active')))
                    ->exists();

                if (! $teachesStudent && Schema::hasTable('edu_class_staff')) {
                    $teachesStudent = DB::table('edu_class_staff')
                        ->whereIn('class_id', $enrolledClasses)
                        ->where('user_id', $auth->id)
                        ->exists();
                }
            }
            if (! $teachesStudent) {
                throw ApiError::forbidden('FORBIDDEN', 'You cannot view this student\'s report card');
            }
        }

        $user = DB::table('users')->where('id', $studentId)->whereNull('deleted_at')->first(['id', 'full_name', 'member_no', 'member_group', 'phone']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'Student not found');

        // Current enrollment and class
        $selectCols = ['e.*', 'c.name as class_name', 'y.name as year_name', 't.name as term_name'];
        if (Schema::hasColumn('edu_classes', 'grade')) {
            $selectCols[] = 'c.grade';
        }
        if (Schema::hasColumn('edu_classes', 'level_id')) {
            $selectCols[] = 'c.level_id';
        }

        $enrollment = DB::table('edu_enrollments as e')
            ->join('edu_classes as c', 'c.id', '=', 'e.class_id')
            ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
            ->leftJoin('edu_terms as t', 't.id', '=', 'c.term_id')
            ->where('e.user_id', $studentId)
            ->where('e.status', 'active')
            ->select($selectCols)
            ->orderByDesc('e.id')
            ->first();

        // Published subject course outcomes
        $courseNameCol = Schema::hasColumn('edu_courses', 'name') ? 'c.name' : 'c.title';
        $outcomeCol = Schema::hasColumn('edu_course_outcomes', 'percent') ? 'percent' : 'score_percent';
        $outcomes = DB::table('edu_course_outcomes as co')
            ->join('edu_courses as c', 'c.id', '=', 'co.course_id')
            ->where('co.user_id', $studentId)
            ->where('co.status', 'finalized')
            ->select('co.*', DB::raw("{$courseNameCol} as course_title"), 'co.' . $outcomeCol . ' as final_percent')
            ->orderBy(DB::raw($courseNameCol))
            ->get();

        // If no finalized outcomes, also check published assessment marks
        $subjects = [];
        $totalScore = 0;
        $subjectCount = 0;

        if ($outcomes->isNotEmpty()) {
            foreach ($outcomes as $o) {
                $score = (float) ($o->final_percent ?? 0);
                $totalScore += $score;
                $subjectCount++;
                $subjects[] = [
                    'name' => $o->course_title,
                    'score' => $score,
                    'max_score' => 100,
                    'result' => $o->result ?? ($score >= 50 ? 'passed' : 'failed'),
                    'remarks' => $score >= 85 ? 'እጅግ በጣም ጥሩ' : ($score >= 70 ? 'በጣም ጥሩ' : ($score >= 50 ? 'ጥሩ' : 'የሚያስፈልግ ድጋፍ')),
                ];
            }
        } elseif ($enrollment) {
            // Find courses in class
            $courses = DB::table('edu_courses')
                ->where('class_id', $enrollment->class_id)
                ->get();
            foreach ($courses as $c) {
                $cName = $c->name ?? $c->title ?? 'ትምህርት';
                // Find published assessments for course
                $avgMark = null;
                $scoreTable = Schema::hasTable('edu_scores') ? 'edu_scores' : (Schema::hasTable('edu_marks') ? 'edu_marks' : null);
                if ($scoreTable && Schema::hasTable('edu_assessments')) {
                    $q = DB::table($scoreTable . ' as s')
                        ->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')
                        ->where('a.course_id', $c->id)
                        ->where('s.user_id', $studentId);
                    if (Schema::hasColumn($scoreTable, 'status')) {
                        $q->where('s.status', 'published');
                    } elseif (Schema::hasColumn('edu_assessments', 'status')) {
                        $q->where('a.status', 'published');
                    }
                    $avgMark = $q->avg('s.score');
                }

                $score = $avgMark !== null ? (float) Num::round1($avgMark) : 0.0;
                if ($avgMark !== null) {
                    $totalScore += $score;
                    $subjectCount++;
                }
                $subjects[] = [
                    'name' => $cName,
                    'score' => $score,
                    'max_score' => 100,
                    'result' => $score >= 50 ? 'passed' : 'provisional',
                    'remarks' => $score >= 85 ? 'እጅግ በጣም ጥሩ' : ($score >= 70 ? 'በጣም ጥሩ' : ($score >= 50 ? 'ጥሩ' : 'በሂደት ላይ')),
                ];
            }
        }

        $average = $subjectCount > 0 ? Num::round1($totalScore / $subjectCount) : 0.0;
        $passed = $average >= 50.0 && $subjectCount > 0;

        // Attendance synthesis
        $attendanceRate = 100.0;
        if ($enrollment) {
            $totalSessions = DB::table('attendance_edu_classes')
                ->where('class_id', $enrollment->class_id)
                ->count();
            if ($totalSessions > 0) {
                $attended = DB::table('attendance as a')
                    ->join('attendance_edu_classes as ac', 'ac.session_id', '=', 'a.session_id')
                    ->where('ac.class_id', $enrollment->class_id)
                    ->where('a.user_id', $studentId)
                    ->whereIn('a.status', ['present', 'late', 'excused'])
                    ->count();
                $attendanceRate = Num::round1(($attended / $totalSessions) * 100);
            }
        }

        $extractedGrade = null;
        if ($enrollment) {
            if (isset($enrollment->grade) && $enrollment->grade !== null) {
                $extractedGrade = (int) $enrollment->grade;
            } elseif (isset($enrollment->level_id) && $enrollment->level_id !== null && (int)$enrollment->level_id >= 1 && (int)$enrollment->level_id <= 12) {
                $extractedGrade = (int) $enrollment->level_id;
            } elseif (! empty($enrollment->class_name)) {
                if (preg_match('/(\d{1,2})ኛ/u', $enrollment->class_name, $m)) {
                    $extractedGrade = (int) $m[1];
                } elseif (preg_match('/(?:Grade|G)\s*(\d{1,2})/iu', $enrollment->class_name, $m)) {
                    $extractedGrade = (int) $m[1];
                }
            }
        }

        return [
            'student_id' => $user->id,
            'full_name' => $user->full_name,
            'member_no' => $user->member_no ?? ('SS-' . str_pad((string) $user->id, 5, '0', STR_PAD_LEFT)),
            'class_name' => $enrollment?->class_name ?? 'ያልተመደበ',
            'grade' => $extractedGrade ?? 7,
            'year_name' => $enrollment?->year_name ?? (date('Y') - 8 . ' ዓ.ም.'),
            'term_name' => $enrollment?->term_name ?? 'የዓመቱ ማጠቃለያ',
            'subjects' => $subjects,
            'total_score' => $totalScore,
            'average' => $average,
            'subject_count' => $subjectCount,
            'passed' => $passed,
            'attendance_rate' => $attendanceRate,
            'generated_at' => Dates::todayLocal(),
        ];
    }

    /**
     * Render the report card as HTML.
     */
    public static function renderHtml(array $d): string
    {
        $e = fn ($v) => htmlspecialchars((string) ($v ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        $rowsHtml = '';
        foreach ($d['subjects'] as $i => $s) {
            $num = $i + 1;
            $passClass = $s['result'] === 'passed' ? 'passed' : 'failed';
            $rowsHtml .= '<tr>
                <td style="text-align:center;">' . $num . '</td>
                <td><strong>' . $e($s['name']) . '</strong></td>
                <td style="text-align:center;">' . $e($s['score']) . ' / 100</td>
                <td style="text-align:center;"><span class="' . $passClass . '">' . ($s['result'] === 'passed' ? 'አልፏል' : 'አላለፈም') . '</span></td>
                <td>' . $e($s['remarks']) . '</td>
            </tr>';
        }

        if (empty($d['subjects'])) {
            $rowsHtml = '<tr><td colspan="5" style="text-align:center; color:#888; padding:20px;">ምንም የተመዘገበ ውጤት የለም / No published marks recorded</td></tr>';
        }

        $decisionText = $d['passed'] ? 'ወደ ቀጣዩ ክፍል ተዛውሯል (PROMOTED)' : 'ድጋፍ ያስፈልገዋል (REQUIRES SUPPORT)';
        $decisionClass = $d['passed'] ? 'decision-promoted' : 'decision-support';
        $font = str_replace('\\', '/', resource_path('fonts'));

        return '<!DOCTYPE html>
<html lang="am">
<head>
    <meta charset="UTF-8">
    <title>የተማሪ ውጤት መግለጫ - ' . $e($d['full_name']) . '</title>
    <style>
        @font-face { font-family: "Noto Ethiopic"; font-weight: normal; src: url("' . $font . '/NotoSansEthiopic-400.ttf") format("truetype"); }
        @font-face { font-family: "Noto Ethiopic"; font-weight: bold; src: url("' . $font . '/NotoSansEthiopic-700.ttf") format("truetype"); }
        @page { size: A4 portrait; margin: 15mm; }
        body {
            font-family: "Noto Ethiopic", "DejaVu Sans", "Nyala", "Abyssinica SIL", sans-serif;
            color: #2b1115;
            background: #fff;
            margin: 0;
            padding: 0;
            font-size: 11pt;
            line-height: 1.4;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #8B1E2D;
            padding-bottom: 12px;
            margin-bottom: 16px;
        }
        .faith-motto {
            font-size: 10pt;
            color: #8B1E2D;
            font-weight: bold;
            letter-spacing: 0.5px;
            margin-bottom: 4px;
        }
        .church-title {
            font-size: 16pt;
            font-weight: bold;
            color: #4A0E17;
            margin: 4px 0;
        }
        .report-subtitle {
            font-size: 12.5pt;
            font-weight: bold;
            color: #8B1E2D;
            background: #FFF8E7;
            display: inline-block;
            padding: 4px 18px;
            border-radius: 4px;
            border: 1px solid #D4AF37;
            margin-top: 6px;
        }
        .info-grid {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 16px;
            background: #faf7f2;
            border: 1px solid #e0d5c1;
        }
        .info-grid td {
            padding: 7px 10px;
            font-size: 10pt;
            border: 1px solid #e0d5c1;
        }
        .info-label {
            color: #6c584c;
            font-weight: bold;
            width: 18%;
        }
        .info-val {
            font-weight: bold;
            color: #1a080a;
            width: 32%;
        }
        table.marks-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 16px;
        }
        table.marks-table th {
            background-color: #650D20;
            color: #ffffff;
            font-weight: bold;
            padding: 8px 6px;
            font-size: 9.5pt;
            border: 1px solid #4a0917;
        }
        table.marks-table td {
            padding: 7px 8px;
            font-size: 9.5pt;
            border: 1px solid #d4c8b8;
        }
        table.marks-table tr:nth-child(even) {
            background-color: #faf6f0;
        }
        .passed { color: #1e7e34; font-weight: bold; }
        .failed { color: #b21f2d; font-weight: bold; }
        .summary-box {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        .summary-box td {
            padding: 8px 12px;
            border: 1px solid #8B1E2D;
            background: #FFF8E7;
            font-size: 10.5pt;
        }
        .decision-badge {
            font-size: 11pt;
            font-weight: bold;
            text-align: center;
            padding: 8px;
            border-radius: 4px;
        }
        .decision-promoted { background: #e8f5e9; color: #1b5e20; border: 1px solid #81c784; }
        .decision-support { background: #ffebee; color: #b71c1c; border: 1px solid #e57373; }
        .signatures {
            width: 100%;
            margin-top: 35px;
            border-collapse: collapse;
        }
        .signatures td {
            width: 33%;
            text-align: center;
            vertical-align: bottom;
            font-size: 9.5pt;
            padding: 0 10px;
        }
        .sig-line {
            border-top: 1px solid #2b1115;
            margin-top: 40px;
            padding-top: 4px;
            font-weight: bold;
        }
        .footer-note {
            font-size: 8pt;
            color: #777;
            text-align: center;
            margin-top: 25px;
            border-top: 1px dashed #ccc;
            padding-top: 8px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="faith-motto">በስመ አብ ወወልድ ወመንፈስ ቅዱስ አሐዱ አምላክ አሜን</div>
        <div class="church-title">የመሠረተ ሕይወት ሰንበት ትምህርት ቤት</div>
        <div class="report-subtitle">የተማሪ የውጤት መግለጫ · Term Report Card</div>
    </div>

    <table class="info-grid">
        <tr>
            <td class="info-label">የተማሪ ስም፡</td>
            <td class="info-val">' . $e($d['full_name']) . '</td>
            <td class="info-label">መለያ ቁጥር፡</td>
            <td class="info-val">' . $e($d['member_no']) . '</td>
        </tr>
        <tr>
            <td class="info-label">የክፍል ደረጃ፡</td>
            <td class="info-val">' . $e($d['class_name']) . ' (' . $e($d['grade']) . 'ኛ ክፍል)</td>
            <td class="info-label">የትምህርት ዘመን፡</td>
            <td class="info-val">' . $e($d['year_name']) . ' · ' . $e($d['term_name']) . '</td>
        </tr>
    </table>

    <table class="marks-table">
        <thead>
            <tr>
                <th style="width:7%;">ተ.ቁ</th>
                <th style="width:38%;">የትምህርቱ ርእስ</th>
                <th style="width:18%;">የተገኘ ውጤት</th>
                <th style="width:15%;">ውሳኔ</th>
                <th style="width:22%;">አስተያየት</th>
            </tr>
        </thead>
        <tbody>
            ' . $rowsHtml . '
        </tbody>
    </table>

    <table class="summary-box">
        <tr>
            <td><strong>ጠቅላላ ድምር፦</strong> ' . $e($d['total_score']) . ' / ' . ($d['subject_count'] * 100) . '</td>
            <td><strong>አማካይ ውጤት፦</strong> ' . $e($d['average']) . '%</td>
            <td><strong>የመገኘት ምጣኔ፦</strong> ' . $e($d['attendance_rate']) . '%</td>
        </tr>
    </table>

    <div class="decision-badge ' . $decisionClass . '">
        የትምህርት ውጤት ውሳኔ፦ ' . $decisionText . '
    </div>

    <table class="signatures">
        <tr>
            <td>
                <div class="sig-line">የክፍሉ አስተማሪ</div>
            </td>
            <td>
                <div class="sig-line">የትምህርት ክፍል ኃላፊ</div>
            </td>
            <td>
                <div class="sig-line">የሰንበት ት/ቤቱ ማኅተም / ቀን</div>
            </td>
        </tr>
    </table>

    <div class="footer-note">
        ሰነዱ የተዘጋጀው በመሠረተ ሕይወት የትምህርት መተግበሪያ ሥርዓት ነው · ቀን፡ ' . $e($d['generated_at']) . ' · ይህ ሰነድ ያለ ማኅተም ተቀባይነት የለውም።
    </div>
</body>
</html>';
    }

    /**
     * Generate the complete binary PDF string.
     */
    public static function generatePdf(AuthContext $auth, int $studentId): string
    {
        $data = self::generateData($auth, $studentId);
        $html = self::renderHtml($data);

        $o = new Options();
        $o->set('isRemoteEnabled', false);
        $o->set('isFontSubsettingEnabled', true);
        $o->set('chroot', array_map(fn ($p) => str_replace('\\', '/', $p), [base_path(), resource_path(), storage_path()]));
        $fontCacheDir = str_replace('\\', '/', storage_path('app/dompdf'));
        if (! is_dir($fontCacheDir)) @mkdir($fontCacheDir, 0775, true);
        $o->set('fontDir', $fontCacheDir);
        $o->set('fontCache', $fontCacheDir);
        $o->set('tempDir', sys_get_temp_dir());

        $pdf = new Dompdf($o);
        $pdf->loadHtml($html, 'UTF-8');
        $pdf->setPaper('A4', 'portrait');
        $pdf->render();

        return (string) $pdf->output();
    }
}
