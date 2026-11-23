<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use App\Mz\Services\MemberIds;
use App\Mz\Support\Num;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

final class EduCertificates
{
    private static function checkManage(AuthContext $auth): void
    {
        if (! $auth->can('education.certify') && ! $auth->can('education.manage') && ! $auth->isAdmin) {
            throw ApiError::forbidden('FORBIDDEN', 'Permission education.certify required');
        }
    }

    /**
     * Check which students in a course are eligible for a certificate.
     * Requires:
     * 1. Finalized outcome with result = 'passed' and counts_for_progression = 1.
     * 2. For online / hybrid courses: 100% course completion (all mandatory published lessons completed).
     */
    public static function eligible(AuthContext $auth, int $courseId, ?int $userId = null): array
    {
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');

        $outcomesQ = DB::table('edu_course_outcomes as o')
            ->join('users as u', 'u.id', '=', 'o.user_id')
            ->where('o.course_id', $courseId)
            ->where('o.result', 'passed')
            ->where('o.status', 'finalized')
            ->where('o.counts_for_progression', 1);

        if ($userId !== null) {
            $outcomesQ->where('o.user_id', $userId);
        }

        $col = Schema::hasColumn('edu_course_outcomes', 'percent') ? 'percent' : 'score_percent';
        $outcomes = $outcomesQ->select(
            'o.id as outcome_id',
            'o.user_id',
            "o.$col as score_percent",
            'o.pass_mark',
            'u.full_name',
            'u.member_no',
            'u.member_group'
        )->get();

        $existing = DB::table('edu_certificates')
            ->where('course_id', $courseId)
            ->where('status', 'valid')
            ->pluck('id', 'user_id')
            ->all();

        $isOnlineOrHybrid = in_array($course->mode ?? 'physical', ['online', 'hybrid'], true);

        $list = [];
        foreach ($outcomes as $o) {
            $uid = (int) $o->user_id;
            $hasCert = isset($existing[$uid]);
            $completion = $isOnlineOrHybrid ? EduLearning::courseCompletion($uid, $courseId) : ['percent' => 100.0, 'total' => 1];
            $completionPct = (float) ($completion['percent'] ?? 100.0);
            $totalLessons = (int) ($completion['total'] ?? ($isOnlineOrHybrid ? 0 : 1));
            // A course with 0 published lessons cannot grant completion certificates in online/hybrid mode
            $hasRequiredLessons = ! $isOnlineOrHybrid || $totalLessons > 0;
            $eligible = $hasRequiredLessons && (! $isOnlineOrHybrid || $completionPct >= 100.0) && ! $hasCert;

            $list[] = [
                'user_id' => $uid,
                'outcome_id' => (int) $o->outcome_id,
                'full_name' => $o->full_name,
                'member_id' => $o->member_no ? MemberIds::format($o->member_no, $o->member_group) : null,
                'score_percent' => Num::n($o->score_percent),
                'pass_mark' => Num::n($o->pass_mark),
                'completion_percent' => Num::n($completionPct),
                'total_lessons' => $totalLessons,
                'has_certificate' => $hasCert,
                'eligible' => $eligible,
            ];
        }

        return $list;
    }

    /**
     * Explicitly issue certificates to eligible users.
     */
    public static function issue(AuthContext $auth, int $courseId, array $userIds): array
    {
        self::checkManage($auth);
        if (empty($userIds)) throw ApiError::field('user_ids', 'EMPTY_USER_IDS');

        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course) throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        $class = $course->class_id ? DB::table('edu_classes')->where('id', $course->class_id)->first() : null;

        $ethYear = null;
        if ($class && ! empty($class->term_id)) {
            $ethYear = DB::table('edu_terms as t')
                ->join('edu_academic_years as y', 'y.id', '=', 't.academic_year_id')
                ->where('t.id', $class->term_id)
                ->value('y.eth_year');
        }
        if (! $ethYear) {
            $dt = Dates::now();
            $ethYear = Ethiopian::toEthiopian((int) $dt->format('Y'), (int) $dt->format('n'), (int) $dt->format('j'))['year'];
        }

        $issued = [];
        foreach ($userIds as $uid) {
            $uid = (int) $uid;

            // Verify eligibility
            $elig = self::eligible($auth, $courseId, $uid);
            $userElig = $elig[0] ?? null;
            if (! $userElig || empty($userElig['eligible'])) {
                if ($userElig && ! empty($userElig['has_certificate'])) {
                    throw ApiError::conflict('CERTIFICATE_EXISTS', "Certificate already issued for user $uid");
                }
                throw ApiError::conflict('NOT_ELIGIBLE', "User $uid is not eligible for certificate");
            }

            // Determine sequence number
            $countThisYear = DB::table('edu_certificates')
                ->where('number', 'like', "MH-$ethYear-%")
                ->count();
            $seq = $countThisYear + 1;
            $number = sprintf('MH-%d-%06d', $ethYear, $seq);

            // Generate unique verify code (10 chars uppercase)
            $code = self::generateVerifyCode();

            $user = DB::table('users')->where('id', $uid)->first();
            $snapshot = [
                'student_name' => $user->full_name ?? "Student #$uid",
                'member_id' => $user && $user->member_no ? MemberIds::format($user->member_no, $user->member_group) : null,
                'course_name' => $course->name,
                'class_name' => $class->name ?? '—',
                'score_percent' => $userElig['score_percent'],
                'pass_mark' => $userElig['pass_mark'],
                'issued_at' => Dates::sql(Dates::now()),
                'signatory' => 'Meserete Hiwot Sunday School Education Department Head',
            ];

            $nowSql = Dates::sql(Dates::now());
            $certId = DB::table('edu_certificates')->insertGetId([
                'number' => $number,
                'verify_code' => $code,
                'user_id' => $uid,
                'course_id' => $courseId,
                'outcome_id' => $userElig['outcome_id'],
                'issued_at' => $nowSql,
                'issued_by' => $auth->id,
                'status' => 'valid',
                'snapshot' => json_encode($snapshot, JSON_UNESCAPED_UNICODE),
                'created_at' => $nowSql,
                'updated_at' => $nowSql,
            ]);

            $cert = DB::table('edu_certificates')->where('id', $certId)->first();
            $issued[] = self::serialize($cert);
        }

        return $issued;
    }

    private static function generateVerifyCode(): string
    {
        for ($i = 0; $i < 20; $i++) {
            $code = strtoupper(Str::random(10));
            if (! DB::table('edu_certificates')->where('verify_code', $code)->exists()) {
                return $code;
            }
        }
        return strtoupper(Str::random(12));
    }

    public static function revoke(AuthContext $auth, int $id, string $reason): array
    {
        self::checkManage($auth);
        $cert = DB::table('edu_certificates')->where('id', $id)->first();
        if (! $cert) throw ApiError::notFound('CERTIFICATE_NOT_FOUND', 'Certificate not found');

        if ($cert->status === 'revoked') {
            throw ApiError::conflict('ALREADY_REVOKED', 'Certificate is already revoked');
        }

        $nowSql = Dates::sql(Dates::now());
        DB::table('edu_certificates')->where('id', $id)->update([
            'status' => 'revoked',
            'revoked_reason' => $reason,
            'updated_at' => $nowSql,
        ]);

        $updated = DB::table('edu_certificates')->where('id', $id)->first();
        return self::serialize($updated);
    }

    public static function reissue(AuthContext $auth, int $id, string $reason): array
    {
        self::checkManage($auth);
        $cert = DB::table('edu_certificates')->where('id', $id)->first();
        if (! $cert) throw ApiError::notFound('CERTIFICATE_NOT_FOUND', 'Certificate not found');

        $dt = Dates::now();
        $ethYear = Ethiopian::toEthiopian((int) $dt->format('Y'), (int) $dt->format('n'), (int) $dt->format('j'))['year'];
        $countThisYear = DB::table('edu_certificates')->where('number', 'like', "MH-$ethYear-%")->count();
        $seq = $countThisYear + 1;
        $number = sprintf('MH-%d-%06d', $ethYear, $seq);
        $code = self::generateVerifyCode();

        $nowSql = Dates::sql(Dates::now());
        $newId = DB::table('edu_certificates')->insertGetId([
            'number' => $number,
            'verify_code' => $code,
            'user_id' => $cert->user_id,
            'course_id' => $cert->course_id,
            'outcome_id' => $cert->outcome_id,
            'issued_at' => $nowSql,
            'issued_by' => $auth->id,
            'status' => 'valid',
            'snapshot' => $cert->snapshot,
            'created_at' => $nowSql,
            'updated_at' => $nowSql,
        ]);

        // Mark old as replaced
        DB::table('edu_certificates')->where('id', $id)->update([
            'status' => 'replaced',
            'replaced_by' => $newId,
            'revoked_reason' => $reason,
            'updated_at' => $nowSql,
        ]);

        $newCert = DB::table('edu_certificates')->where('id', $newId)->first();
        return self::serialize($newCert);
    }

    public static function verify(string $code): array
    {
        $cert = DB::table('edu_certificates')->where('verify_code', $code)->first();
        if (! $cert) throw ApiError::notFound('CERTIFICATE_NOT_FOUND', 'Certificate not found');

        $replacementNumber = null;
        if ($cert->status === 'replaced' && $cert->replaced_by) {
            $replacementNumber = DB::table('edu_certificates')->where('id', $cert->replaced_by)->value('number');
        }

        $snapshot = json_decode((string) $cert->snapshot, true) ?: [];

        return [
            'status' => $cert->status,
            'number' => $cert->number,
            'student_name' => $snapshot['student_name'] ?? '—',
            'course_name' => $snapshot['course_name'] ?? '—',
            'issued_at' => $cert->issued_at,
            'revoked_reason' => $cert->status === 'revoked' ? $cert->revoked_reason : null,
            'replacement_number' => $replacementNumber,
        ];
    }

    public static function myCertificates(int $userId): array
    {
        $certs = DB::table('edu_certificates as c')
            ->join('edu_courses as co', 'co.id', '=', 'c.course_id')
            ->where('c.user_id', $userId)
            ->where('c.status', 'valid')
            ->orderByDesc('c.issued_at')
            ->select('c.*', 'co.name as course_name')
            ->get();

        return $certs->map(fn ($c) => self::serialize($c))->all();
    }

    public static function list(AuthContext $auth, ?int $courseId = null, ?int $userId = null): array
    {
        $q = DB::table('edu_certificates as c')
            ->join('edu_courses as co', 'co.id', '=', 'c.course_id')
            ->join('users as u', 'u.id', '=', 'c.user_id')
            ->orderByDesc('c.issued_at');

        if ($courseId) $q->where('c.course_id', $courseId);
        if ($userId) $q->where('c.user_id', $userId);

        $certs = $q->select('c.*', 'co.name as course_name', 'u.full_name as student_name')->get();
        return $certs->map(fn ($c) => self::serialize($c))->all();
    }

    public static function renderPdf(int $id): string
    {
        $cert = DB::table('edu_certificates')->where('id', $id)->first();
        if (! $cert) throw ApiError::notFound('CERTIFICATE_NOT_FOUND', 'Certificate not found');

        $snapshot = json_decode((string) $cert->snapshot, true) ?: [];
        $font = str_replace('\\', '/', resource_path('fonts'));
        $logo = 'data:image/jpeg;base64,' . base64_encode((string) @file_get_contents(resource_path('static/logo.jpg')));
        $e = fn ($v) => htmlspecialchars((string) ($v ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        $html = '<!doctype html><html><head><meta charset="utf-8"><style>
            @font-face { font-family: "Noto Ethiopic"; font-weight: normal; src: url("' . $font . '/NotoSansEthiopic-400.ttf") format("truetype"); }
            @font-face { font-family: "Noto Ethiopic"; font-weight: bold; src: url("' . $font . '/NotoSansEthiopic-700.ttf") format("truetype"); }
            @page { margin: 10mm; size: A4 landscape; }
            body { font-family: "Noto Ethiopic", "DejaVu Sans", sans-serif; margin: 0; padding: 0; background: #fff; color: #2d1e2f; text-align: center; }
            .border { border: 6pt double #c8961e; padding: 18mm 20mm; height: 160mm; box-sizing: border-box; background: #fffcf7; position: relative; }
            .header img { height: 22mm; margin-bottom: 3mm; border-radius: 50%; }
            .church { font-size: 15pt; font-weight: bold; color: #6e1423; margin: 0; }
            .sub { font-size: 11pt; color: #8a7a7d; margin-top: 1mm; }
            .cert-title { font-size: 24pt; font-weight: bold; color: #c8961e; margin: 6mm 0 4mm; letter-spacing: 2px; }
            .presents { font-size: 11pt; color: #5a4b4e; margin-bottom: 4mm; }
            .student-name { font-size: 22pt; font-weight: bold; color: #6e1423; border-bottom: 1.5pt solid #c8961e; display: inline-block; padding: 0 15mm 2mm; margin-bottom: 4mm; }
            .cert-body { font-size: 12pt; line-height: 1.6; max-width: 200mm; margin: 0 auto 6mm; color: #3d2e31; }
            .highlight { font-weight: bold; color: #6e1423; }
            .footer-row { position: absolute; bottom: 12mm; left: 20mm; right: 20mm; display: table; width: 85%; }
            .footer-cell { display: table-cell; width: 33%; vertical-align: bottom; }
            .sig-line { border-top: 1pt solid #8a7a7d; width: 50mm; margin: 0 auto 2mm; }
            .sig-title { font-size: 9pt; color: #8a7a7d; }
            .cert-meta { font-size: 8.5pt; color: #8a7a7d; text-align: left; }
            .stamp { border: 1.5pt solid #c8961e; border-radius: 6px; padding: 3px 8px; font-size: 8.5pt; color: #8a6d1e; display: inline-block; }
            .status-revoked { color: #d32f2f; font-weight: bold; font-size: 14pt; margin-top: 2mm; }
        </style></head><body>
            <div class="border">
                <div class="header">
                    <img src="' . $logo . '">
                    <div class="church">ደብረ ዕንቁ ልደታ ለማርያም ቤተክርስቲያን መሠረተ ሕይወት ሰንበት ትምህርት ቤት</div>
                    <div class="sub">Debre Enqu St. Lideta Lemariam Church · Meserete Hiwot Sunday School</div>
                </div>
                <div class="cert-title">የምስክር ወረቀት · CERTIFICATE</div>
                <div class="presents">ይህ የምስክር ወረቀት ለተማሪው/ዋ የተሰጠው / This certificate is proudly presented to:</div>
                <div class="student-name">' . $e($snapshot['student_name'] ?? '—') . '</div>
                <div class="cert-body">
                    የትምህርቱን ርእስ <span class="highlight">' . $e($snapshot['course_name'] ?? '—') . '</span> በተሳካ ሁኔታ በማጠናቀቁ/ቋ የተሰጠ የምስክር ወረቀት።<br>
                    For successfully completing the course with a passing grade of <span class="highlight">' . $e($snapshot['score_percent'] ?? '—') . '%</span> (Pass Mark: ' . $e($snapshot['pass_mark'] ?? '—') . '%).
                </div>
                ' . ($cert->status === 'revoked' ? '<div class="status-revoked">[REVOKED / ተሰርዟል - ' . $e($cert->revoked_reason) . ']</div>' : '') . '
                ' . ($cert->status === 'replaced' ? '<div class="status-revoked">[REPLACED / በሌላ ተተክቷል]</div>' : '') . '
                <div class="footer-row">
                    <div class="footer-cell cert-meta">
                        <div>ቁጥር / No: <strong>' . $e($cert->number) . '</strong></div>
                        <div>የማረጋገጫ ኮድ / Code: <strong>' . $e($cert->verify_code) . '</strong></div>
                        <div>ቀን / Date: ' . $e($cert->issued_at) . '</div>
                    </div>
                    <div class="footer-cell">
                        <div class="stamp">ኦፊሴላዊ ሰነድ<br>OFFICIAL</div>
                    </div>
                    <div class="footer-cell">
                        <div class="sig-line"></div>
                        <div class="sig-title">የትምህርት ክፍል ኃላፊ<br>Head of Education Dept.</div>
                    </div>
                </div>
            </div>
        </body></html>';

        $o = new Options();
        $o->set('isRemoteEnabled', false);
        $o->set('isFontSubsettingEnabled', true);
        $fontCacheDir = str_replace('\\', '/', storage_path('app/dompdf'));
        if (! is_dir($fontCacheDir)) @mkdir($fontCacheDir, 0775, true);
        $o->set('fontDir', $fontCacheDir);
        $o->set('fontCache', $fontCacheDir);
        $pdf = new Dompdf($o);
        $pdf->loadHtml($html, 'UTF-8');
        $pdf->setPaper('A4', 'landscape');
        $pdf->render();

        return (string) $pdf->output();
    }

    public static function renderVerifyWebPage(string $code): Response
    {
        try {
            $data = self::verify($code);
        } catch (\Throwable) {
            $data = null;
        }

        $e = fn ($v) => htmlspecialchars((string) ($v ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        $content = '';
        if (! $data) {
            $content = '<div class="card invalid">
                <div class="icon">✗</div>
                <h2>የማረጋገጫ ኮዱ አልተገኘም / Invalid Verification Code</h2>
                <p>ምንም ዓይነት የተሰጠ የምስክር ወረቀት በዚህ ኮድ አልተመዘገበም።</p>
                <p class="muted">No certificate record was found matching code <code>' . $e($code) . '</code>.</p>
            </div>';
        } else {
            $status = $data['status'];
            $isValid = $status === 'valid';
            $isRevoked = $status === 'revoked';
            $isReplaced = $status === 'replaced';

            $badgeClass = $isValid ? 'badge-valid' : 'badge-danger';
            $badgeText = $isValid ? '✓ ትክክለኛ ሰነድ (VALID)' : ($isRevoked ? '✗ የተሰረዘ (REVOKED)' : '⚠ በሌላ የተተካ (REPLACED)');

            $content = '<div class="card ' . ($isValid ? 'valid' : 'revoked') . '">
                <span class="badge ' . $badgeClass . '">' . $badgeText . '</span>
                <h2>የምስክር ወረቀት ማረጋገጫ · Certificate Verification</h2>
                <table class="details">
                    <tr><th>የምስክር ወረቀት ቁጥር / Number:</th><td><strong>' . $e($data['number']) . '</strong></td></tr>
                    <tr><th>የተማሪው ሙሉ ስም / Student Name:</th><td>' . $e($data['student_name']) . '</td></tr>
                    <tr><th>የትምህርቱ ርእስ / Course:</th><td>' . $e($data['course_name']) . '</td></tr>
                    <tr><th>የተሰጠበት ቀን / Issue Date:</th><td>' . $e($data['issued_at']) . '</td></tr>
                    ' . ($isRevoked ? '<tr class="danger-row"><th>የተሰረዘበት ምክንያት / Revocation Reason:</th><td>' . $e($data['revoked_reason']) . '</td></tr>' : '') . '
                    ' . ($isReplaced ? '<tr class="warning-row"><th>አዲስ የተተካው ቁጥር / Replacement Number:</th><td><strong>' . $e($data['replacement_number']) . '</strong></td></tr>' : '') . '
                </table>
            </div>';
        }

        $html = '<!doctype html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>የምስክር ወረቀት ማረጋገጫ - Certificate Verification</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #fdfbf7; color: #2d1e2f; margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 90vh; }
                .container { max-width: 580px; width: 100%; text-align: center; }
                .brand { font-size: 17px; font-weight: bold; color: #6e1423; margin-bottom: 16px; }
                .card { background: #fff; border-radius: 12px; padding: 28px; box-shadow: 0 4px 16px rgba(0,0,0,0.06); border-top: 5px solid #c8961e; text-align: left; }
                .card.valid { border-top-color: #2e7d32; }
                .card.revoked, .card.invalid { border-top-color: #d32f2f; text-align: center; }
                .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 12px; }
                .badge-valid { background: #e8f5e9; color: #2e7d32; }
                .badge-danger { background: #ffebee; color: #d32f2f; }
                h2 { color: #6e1423; font-size: 19px; margin-top: 0; }
                .details { width: 100%; border-collapse: collapse; margin-top: 16px; }
                .details th { text-align: left; color: #666; font-size: 13px; padding: 8px 0; vertical-align: top; width: 45%; }
                .details td { padding: 8px 0; font-size: 14px; }
                .icon { font-size: 48px; color: #d32f2f; margin-bottom: 8px; }
                .muted { color: #888; font-size: 13px; }
                .danger-row th, .danger-row td { color: #d32f2f; font-weight: bold; }
                .warning-row th, .warning-row td { color: #e65100; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="brand">ደብረ ዕንቁ ልደታ ለማርያም መሠረተ ሕይወት ሰንበት ት/ቤት</div>
                ' . $content . '
            </div>
        </body>
        </html>';

        return response($html, 200, ['Content-Type' => 'text/html; charset=utf-8']);
    }

    private static function serialize(object $c): array
    {
        $snapshot = is_string($c->snapshot) ? json_decode($c->snapshot, true) : (array) $c->snapshot;
        return [
            'id' => (int) $c->id,
            'number' => $c->number,
            'verify_code' => $c->verify_code,
            'user_id' => (int) $c->user_id,
            'course_id' => (int) $c->course_id,
            'course_name' => $c->course_name ?? ($snapshot['course_name'] ?? null),
            'student_name' => $c->student_name ?? ($snapshot['student_name'] ?? null),
            'outcome_id' => (int) $c->outcome_id,
            'issued_at' => $c->issued_at,
            'issued_by' => (int) $c->issued_by,
            'status' => $c->status,
            'replaced_by' => $c->replaced_by ? (int) $c->replaced_by : null,
            'revoked_reason' => $c->revoked_reason,
            'pdf_path' => $c->pdf_path,
            'snapshot' => $snapshot,
        ];
    }
}
