<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Member-submitted monthly contribution receipts.
 * Members can submit a receipt covering 1–12 consecutive months.
 * The system computes the expected amount on the server.
 * Submissions do NOT mark months as paid until approved by an authorized financial reviewer.
 */
final class ContributionReceipts
{
    public const STATUS_SUBMITTED = 'submitted';
    public const STATUS_UNDER_REVIEW = 'under_review';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_CORRECTION_NEEDED = 'correction_needed';

    public static function serialize(?object $r, bool $withReviewer = true): ?array
    {
        if (! $r) return null;
        $out = [
            'id' => (int) $r->id,
            'user_id' => (int) $r->user_id,
            'period' => $r->period,
            'months' => (int) ($r->months ?? 1),
            'coverage_end' => $r->coverage_end ?? $r->period,
            'expected_amount' => Num::n($r->expected_amount),
            'submitted_amount' => Num::n($r->submitted_amount),
            'currency' => $r->currency,
            'method' => $r->method,
            'reference' => $r->reference,
            'paid_on' => Dates::toDateOnly($r->paid_on),
            'receipt_path' => $r->receipt_path,
            'has_receipt' => ! empty($r->receipt_path),
            'receipt_download_url' => url('/api/v1/me/contribution-receipts/' . $r->id . '/file'),
            'member_note' => $r->member_note,
            'status' => $r->status,
            'review_note' => $r->review_note,
            'reviewed_at' => $r->reviewed_at,
            'payment_id' => $r->payment_id ? (int) $r->payment_id : null,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
        ];
        if (isset($r->full_name)) $out['member_name'] = $r->full_name;
        if (isset($r->member_no)) $out['member_id'] = MemberIds::format($r->member_no, $r->member_group ?? null);
        if (isset($r->phone)) $out['phone'] = $r->phone;
        if ($withReviewer && isset($r->reviewer_name)) $out['reviewer_name'] = $r->reviewer_name;
        return $out;
    }

    /**
     * Calculate expected contribution amount for a member across consecutive months.
     * Handled strictly on server: never trusts client amount as authoritative.
     */
    public static function calculateExpected(int $userId, string $startPeriod, int $months): array
    {
        if ($months < 1 || $months > Payments::MAX_MONTHS) {
            throw ApiError::field('months', 'INVALID_MONTHS_COUNT');
        }
        $user = DB::table('users')->where('id', $userId)->first(['id', 'member_type', 'member_group', 'status', 'membership_status']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        if ($user->member_group === 'children') throw ApiError::conflict('CHILDREN_EXEMPT', 'Children are exempt from contributions');
        $memberType = $user->member_type ?: ($user->member_group === 'student' ? 'student' : 'worker');

        $endPeriod = Ethiopian::addMonths($startPeriod, $months - 1);
        $periodList = Ethiopian::monthsBetween($startPeriod, $endPeriod);

        if ($startPeriod === '2019-01' || in_array('2019-01', $periodList, true)) {
            throw ApiError::badRequest('MESKEREM_2019_NOT_PAYABLE', 'Meskerem 2019 is not payable');
        }

        $breakdown = [];
        $totalExpected = 0.0;
        $currency = Payments::settings()['currency'] ?? 'ETB';

        foreach ($periodList as $p) {
            $rate = Payments::rateForPeriod($memberType, $p) 
                ?? Payments::rateOn($memberType, Dates::todayLocal()) 
                ?? ['monthly_amount' => ($memberType === 'student' ? 20.0 : 40.0), 'currency' => $currency];
            $amt = (float) $rate['monthly_amount'];
            $totalExpected += $amt;
            $currency = $rate['currency'] ?: $currency;
            $breakdown[] = [
                'period' => $p,
                'rate' => Num::n($amt),
                'currency' => $currency,
            ];
        }

        return [
            'user_id' => $userId,
            'period' => $startPeriod,
            'months' => $months,
            'coverage_end' => $endPeriod,
            'expected_amount' => Num::n($totalExpected),
            'currency' => $currency,
            'breakdown' => $breakdown,
        ];
    }

    /**
     * Member submits a contribution receipt.
     */
    public static function submit(array $actx, array $input, UploadedFile $file): array
    {
        $userId = $actx['auth']->id;
        $months = (int) ($input['months'] ?? 1);
        $period = $input['period'];
        if ($period === '2019-01') {
            throw ApiError::badRequest('MESKEREM_2019_NOT_PAYABLE', 'Meskerem 2019 is not payable');
        }
        if ($months < 1 || $months > Payments::MAX_MONTHS) {
            throw ApiError::field('months', 'INVALID_MONTHS_COUNT');
        }

        $calc = self::calculateExpected($userId, $period, $months);
        $start = $calc['period'];
        $end = $calc['coverage_end'];

        // 1. Prevent overlap with already verified payments
        $paymentOverlap = DB::table('payments')
            ->where('user_id', $userId)
            ->where('period', '<=', $end)
            ->where('coverage_end', '>=', $start)
            ->first(['id', 'period', 'coverage_end']);
        if ($paymentOverlap) {
            throw ApiError::conflict('PAYMENT_OVERLAP', "Months {$paymentOverlap->period} to {$paymentOverlap->coverage_end} are already recorded as paid");
        }

        // 2. Prevent duplicate pending submissions for the same months
        $pendingOverlap = DB::table('contribution_receipts')
            ->where('user_id', $userId)
            ->whereIn('status', [self::STATUS_SUBMITTED, self::STATUS_UNDER_REVIEW])
            ->where('period', '<=', $end)
            ->where('coverage_end', '>=', $start)
            ->first(['id', 'period', 'coverage_end']);
        if ($pendingOverlap) {
            throw ApiError::conflict('SUBMISSION_OVERLAP', "A receipt submission for months {$pendingOverlap->period} to {$pendingOverlap->coverage_end} is already under review");
        }

        // 3. Store the receipt privately
        $saved = Storage::save('contribution_receipt', Storage::FOLDERS['CONTRIBUTION_RECEIPTS'], $file);

        $submittedAmount = isset($input['submitted_amount']) ? (float) $input['submitted_amount'] : (float) $calc['expected_amount'];

        $row = [
            'user_id' => $userId,
            'period' => $start,
            'months' => $months,
            'coverage_end' => $end,
            'expected_amount' => $calc['expected_amount'],
            'submitted_amount' => $submittedAmount,
            'currency' => $calc['currency'],
            'method' => $input['method'] ?? 'bank',
            'reference' => $input['reference'] ?? null,
            'paid_on' => $input['paid_on'] ?? Dates::todayLocal(),
            'receipt_path' => $saved['path'],
            'member_note' => $input['member_note'] ?? null,
            'status' => self::STATUS_SUBMITTED,
        ];

        $id = DB::table('contribution_receipts')->insertGetId($row);

        Audit::log($actx, 'contribution.submit', 'contribution_receipt', $id, [
            'user_id' => $userId,
            'period' => $start,
            'months' => $months,
            'expected_amount' => $calc['expected_amount'],
            'submitted_amount' => $submittedAmount,
        ]);

        // Notify payment managers
        $managerIds = DB::table('role_permissions as rp')
            ->join('permissions as p', 'p.id', '=', 'rp.permission_id')
            ->join('users as u', 'u.role_id', '=', 'rp.role_id')
            ->whereIn('p.key', ['payments.manage', 'contributions.review'])
            ->whereNull('u.deleted_at')
            ->pluck('u.id')
            ->all();

        if ($managerIds) {
            Notifications::createForUsers(array_slice($managerIds, 0, 20), [
                'type' => 'finance',
                'title' => 'አዲስ የመዋጮ ደረሰኝ ገብቷል',
                'body' => "አባል ለ{$months} ወራት የ{$calc['expected_amount']} {$calc['currency']} ደረሰኝ አስገብተዋል።",
                'entityType' => 'contribution_receipt',
                'entityId' => $id,
                'url' => "/admin/receipt-review?id={$id}",
                'route' => "/admin/receipt-review?id={$id}",
                'data' => ['admin_review' => true, 'receipt_id' => $id, 'url' => "/admin/receipt-review?id={$id}"],
                'dedupeKey' => fn ($uid) => "cr:sub:$id:$uid",
            ]);
        }

        return self::get($id);
    }

    public static function get(int $id): array
    {
        $r = DB::table('contribution_receipts as cr')
            ->join('users as u', 'u.id', '=', 'cr.user_id')
            ->leftJoin('users as rv', 'rv.id', '=', 'cr.reviewed_by')
            ->where('cr.id', $id)
            ->select('cr.*', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'rv.full_name as reviewer_name')
            ->first();
        if (! $r) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Contribution receipt not found');
        return self::serialize($r);
    }

    public static function forMember(int $userId): array
    {
        $rows = DB::table('contribution_receipts as cr')
            ->leftJoin('users as rv', 'rv.id', '=', 'cr.reviewed_by')
            ->where('cr.user_id', $userId)
            ->orderByDesc('cr.id')
            ->select('cr.*', 'rv.full_name as reviewer_name')
            ->get();
        return array_map(fn ($r) => self::serialize($r), $rows->all());
    }

    public static function adminList(array $f, array $page): array
    {
        $qb = DB::table('contribution_receipts as cr')
            ->join('users as u', 'u.id', '=', 'cr.user_id')
            ->leftJoin('users as rv', 'rv.id', '=', 'cr.reviewed_by')
            ->select('cr.*', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'rv.full_name as reviewer_name')
            ->orderByDesc('cr.id');

        if (! empty($f['id'])) {
            $qb->where('cr.id', (int) $f['id']);
        }
        if (! empty($f['status'])) {
            $qb->where('cr.status', $f['status']);
        }
        if (! empty($f['period'])) {
            $qb->where('cr.period', '<=', $f['period'])->where('cr.coverage_end', '>=', $f['period']);
        }
        if (! empty($f['user_id'])) {
            $qb->where('cr.user_id', $f['user_id']);
        }
        if (! empty($f['q'])) {
            MemberIds::search($qb, $f['q']);
        }

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => self::serialize($r), $res['items']);
        return $res;
    }

    /**
     * Authorized review of a contribution receipt.
     * When approved: transactionally creates verified payment, binds it to receipt, audits, and notifies member.
     */
    public static function review(array $actx, int $id, array $input): array
    {
        $decision = $input['status']; // 'approved' | 'rejected' | 'under_review' | 'correction_needed'
        if (! in_array($decision, [self::STATUS_APPROVED, self::STATUS_REJECTED, self::STATUS_UNDER_REVIEW, self::STATUS_CORRECTION_NEEDED], true)) {
            throw ApiError::field('status', 'INVALID_STATUS');
        }

        $reviewerId = $actx['auth']->id;
        $note = $input['review_note'] ?? null;

        $out = DB::transaction(function () use ($actx, $id, $decision, $reviewerId, $note, $input) {
            $sub = DB::table('contribution_receipts')->where('id', $id)->lockForUpdate()->first();
            if (! $sub) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Contribution receipt not found');

            if ($sub->status === self::STATUS_APPROVED) {
                throw ApiError::conflict('ALREADY_APPROVED', 'This contribution receipt has already been approved');
            }

            if ($decision === self::STATUS_APPROVED) {
                // Ensure no overlapping payment was made while under review
                $overlap = DB::table('payments')
                    ->where('user_id', $sub->user_id)
                    ->where('period', '<=', $sub->coverage_end)
                    ->where('coverage_end', '>=', $sub->period)
                    ->first();
                if ($overlap) {
                    throw ApiError::conflict('PAYMENT_OVERLAP', "Already covered by payment {$overlap->period} – {$overlap->coverage_end}");
                }

                $user = DB::table('users')->where('id', $sub->user_id)->first(['id', 'member_type']);
                $approvedAmount = isset($input['approved_amount']) ? (float) $input['approved_amount'] : (float) $sub->submitted_amount;
                $monthlyRate = $sub->months > 0 ? ($approvedAmount / $sub->months) : $approvedAmount;

                // Create official verified payment record
                $paymentId = DB::table('payments')->insertGetId([
                    'user_id' => $sub->user_id,
                    'period' => $sub->period,
                    'months' => $sub->months,
                    'coverage_end' => $sub->coverage_end,
                    'member_type' => $user->member_type ?? 'worker',
                    'monthly_rate' => $monthlyRate,
                    'amount' => $approvedAmount,
                    'currency' => $sub->currency,
                    'method' => $sub->method,
                    'reference' => $sub->reference,
                    'paid_on' => $sub->paid_on,
                    'receipt' => $sub->receipt_path,
                    'note' => $note ?: "Verified contribution submission #{$sub->id}",
                    'status' => 'verified',
                    'recorded_by' => $reviewerId,
                    'verified_by' => $reviewerId,
                ]);

                DB::table('contribution_receipts')->where('id', $id)->update([
                    'status' => self::STATUS_APPROVED,
                    'reviewed_by' => $reviewerId,
                    'reviewed_at' => Dates::now(),
                    'review_note' => $note,
                    'payment_id' => $paymentId,
                ]);

                Audit::log($actx, 'contribution.approve', 'contribution_receipt', $id, [
                    'payment_id' => $paymentId,
                    'user_id' => $sub->user_id,
                    'months' => $sub->months,
                    'amount' => $approvedAmount,
                ], inTrx: true);

                return ['sub' => self::get($id), 'notify' => 'approved', 'userId' => $sub->user_id, 'months' => $sub->months, 'period' => $sub->period, 'note' => $note];
            } else {
                DB::table('contribution_receipts')->where('id', $id)->update([
                    'status' => $decision,
                    'reviewed_by' => $reviewerId,
                    'reviewed_at' => Dates::now(),
                    'review_note' => $note,
                ]);

                Audit::log($actx, 'contribution.' . $decision, 'contribution_receipt', $id, [
                    'user_id' => $sub->user_id,
                    'status' => $decision,
                    'note' => $note,
                ], inTrx: true);

                return ['sub' => self::get($id), 'notify' => $decision, 'userId' => $sub->user_id, 'months' => $sub->months, 'period' => $sub->period, 'note' => $note];
            }
        });

        // Member notifications
        $title = match ($out['notify']) {
            'approved' => 'የመዋጮ ክፍያዎ ጸድቋል',
            'rejected' => 'የመዋጮ ደረሰኝዎ ውድቅ ተደርጓል',
            'correction_needed' => 'የመዋጮ ደረሰኝ ማስተካከያ ያስፈልገዋል',
            default => 'የመዋጮ ደረሰኝ ሁኔታ ተቀይሯል',
        };

        $body = match ($out['notify']) {
            'approved' => "የ{$out['period']} መዋጮ ክፍያ ደረሰኝ በገንዘብ ያዥ ጸድቆ ክፍያው ተመዝግቧል።",
            'rejected' => "የመዋጮ ክፍያ ደረሰኝዎ ውድቅ ተደርጓል። ምክንያት፦ " . ($out['note'] ?: 'የተሳሳተ መረጃ'),
            'correction_needed' => "እባክዎ ደረሰኝዎን አስተካክለው በድጋሚ ይላኩ። ማስታወሻ፦ " . ($out['note'] ?: 'ማብራሪያ ያስፈልጋል'),
            default => "የመዋጮ ደረሰኝዎ ሁኔታ ወደ {$out['notify']} ተቀይሯል።",
        };

        Notifications::createForUsers([$out['userId']], [
            'type' => 'finance',
            'title' => $title,
            'body' => $body,
            'entityType' => 'contribution_receipt',
            'entityId' => $id,
            'data' => ['admin_review' => false, 'target' => 'member', 'receipt_id' => $id],
            'dedupeKey' => fn ($uid) => "cr:rev:$id:" . time(),
        ]);

        if ($out['notify'] === 'approved') {
            Choir::scheduleEligibility([$out['userId']]);
        }

        return $out['sub'];
    }

    /**
     * Secure file access: only the submitter or authorized reviewers can view the receipt.
     */
    public static function fileResponse(AuthContext $auth, int $id)
    {
        $r = DB::table('contribution_receipts')->where('id', $id)->first(['id', 'user_id', 'receipt_path']);
        if (! $r || ! $r->receipt_path) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Receipt not found');

        $canView = $r->user_id === $auth->id || $auth->canAny(['payments.manage', 'payments.view', 'contributions.review']);
        if (! $canView) throw ApiError::forbidden('RECEIPT_FORBIDDEN', 'Access to this receipt is restricted');

        $abs = Storage::privatePath($r->receipt_path);
        if (! is_file($abs)) throw ApiError::notFound('FILE_NOT_FOUND', 'File not found on storage');

        $det = Storage::detect($abs);
        $mime = $det ? $det[1] : 'application/octet-stream';
        $filename = 'receipt_' . $r->id . '.' . ($det ? $det[0] : 'jpg');

        return response()->file($abs, [
            'Cache-Control' => 'private, max-age=3600',
            'Content-Type' => $mime,
            'Content-Disposition' => "inline; filename=\"$filename\"",
        ]);
    }
}
