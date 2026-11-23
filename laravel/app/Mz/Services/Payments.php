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
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Monthly contributions by Ethiopian month (port of paymentService.js). One payment covers 1–12
 * consecutive months; the amount is the member's rate (student / worker) × months, kept on the
 * payment. Children do not pay. On time = paid by the end of the month + grace_days.
 */
final class Payments
{
    public const POLICY_DEFAULT = ['currency' => 'ETB', 'start_period' => null, 'grace_days' => 0];
    public const MEMBER_TYPES = ['student', 'worker'];
    public const MAX_MONTHS = 12;

    public static function settings(): array
    {
        return array_merge(self::POLICY_DEFAULT, Settings::get('payments.policy') ?? []);
    }

    public static function policy(): array
    {
        return self::settings() + ['max_months' => self::MAX_MONTHS, 'current_period' => Ethiopian::currentPeriod(), 'rates' => self::currentRates()];
    }

    public static function saveSettings(array $actx, array $input): array
    {
        $saved = Settings::set('payments.policy', array_merge(self::settings(), $input), $actx['auth']->id);
        Audit::log($actx, Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'payments.policy', 'value' => $saved]);
        return self::policy();
    }

    public static function serialize(?object $p): ?array
    {
        if (! $p) return null;
        $out = [
            'id' => $p->id,
            'user_id' => $p->user_id,
            'period' => $p->period,
            'months' => $p->months ?? 1,
            'coverage_start' => $p->period,
            'coverage_end' => $p->coverage_end ?? $p->period,
            'member_type' => $p->member_type ?? null,
            'monthly_rate' => isset($p->monthly_rate) ? Num::n($p->monthly_rate) : null,
            'amount' => Num::n($p->amount),
            'currency' => $p->currency,
            'method' => $p->method,
            'reference' => $p->reference,
            'paid_on' => Dates::toDateOnly($p->paid_on),
            'receipt_url' => Storage::url($p->receipt ?? null),
            'note' => $p->note,
            'status' => $p->status ?? 'recorded',
        ];
        if (isset($p->verified_by_name)) $out['verified_by_name'] = $p->verified_by_name;
        if (isset($p->recorded_by_name)) $out['recorded_by_name'] = $p->recorded_by_name;
        $out['created_at'] = $p->created_at;
        return $out;
    }

    // ------------------------------------------------------------------ rates
    public static function rateOn(?string $memberType, string $date): ?array
    {
        if (! $memberType) return null;
        $r = DB::table('payment_rates')->where('member_type', $memberType)->where('effective_from', '<=', $date)->orderByDesc('effective_from')->orderByDesc('id')->first();
        return $r ? ['monthly_amount' => Num::n($r->monthly_amount), 'currency' => $r->currency, 'effective_from' => Dates::toDateOnly($r->effective_from)] : null;
    }

    /** The rate in effect on the month's first day, or one that first took effect during the month. */
    public static function rateForPeriod(?string $memberType, string $period): ?array
    {
        $r = Ethiopian::periodRange($period);
        return self::rateOn($memberType, $r['start']) ?? self::rateOn($memberType, $r['end']);
    }

    public static function currentRates(): array
    {
        $today = Dates::todayLocal();
        $out = [];
        foreach (self::MEMBER_TYPES as $t) $out[$t] = self::rateOn($t, $today);
        return $out;
    }

    public static function rateHistory(): array
    {
        return DB::table('payment_rates as r')->leftJoin('users as u', 'u.id', '=', 'r.created_by')->orderByDesc('r.effective_from')->orderByDesc('r.id')->select('r.*', 'u.full_name as created_by_name')->get()
            ->map(fn ($r) => ['id' => $r->id, 'member_type' => $r->member_type, 'monthly_amount' => Num::n($r->monthly_amount), 'currency' => $r->currency, 'effective_from' => Dates::toDateOnly($r->effective_from), 'created_by_name' => $r->created_by_name, 'created_at' => $r->created_at])->all();
    }

    public static function addRate(array $actx, array $in): array
    {
        $cur = $in['currency'] ?? self::settings()['currency'];
        $from = $in['effective_from'] ?? Dates::todayLocal();
        $id = DB::table('payment_rates')->insertGetId(['member_type' => $in['member_type'], 'monthly_amount' => $in['monthly_amount'], 'currency' => $cur, 'effective_from' => $from, 'created_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::PAYMENT_RATE, 'payment_rate', $id, ['member_type' => $in['member_type'], 'monthly_amount' => $in['monthly_amount'], 'effective_from' => $from]);
        return self::rateHistory();
    }

    public static function updateRate(array $actx, int $id, array $input): array
    {
        $patch = array_intersect_key($input, array_flip(['monthly_amount', 'effective_from', 'member_type']));
        if (! DB::table('payment_rates')->where('id', $id)->exists()) throw ApiError::notFound('RATE_NOT_FOUND', 'Rate not found');
        if ($patch) DB::table('payment_rates')->where('id', $id)->update($patch);
        Audit::log($actx, Audit::PAYMENT_RATE, 'payment_rate', $id, ['updated' => (object) $patch]);
        return self::rateHistory();
    }

    public static function removeRate(array $actx, int $id): array
    {
        $n = DB::table('payment_rates')->where('id', $id)->delete();
        if (! $n) throw ApiError::notFound('RATE_NOT_FOUND', 'Rate not found');
        Audit::log($actx, Audit::PAYMENT_RATE, 'payment_rate', $id, ['deleted' => true]);
        return self::rateHistory();
    }

    // ------------------------------------------------------------------ months of a member
    private static function firstPeriodOf(object $user, array $pol): string
    {
        $joined = Ethiopian::periodOfDate(Dates::localDateOf($user->created_at));
        return $pol['start_period'] && strcmp($pol['start_period'], $joined) > 0 ? $pol['start_period'] : $joined;
    }

    private static function deadlineOf(string $period, int $graceDays): string
    {
        return Dates::addDays(Ethiopian::periodRange($period)['end'], $graceDays);
    }

    /** Month by month: required, paid, status paid | late | unpaid | due | exempt, on time. */
    public static function monthsOf(int $userId, ?string $from = null, ?string $to = null): array
    {
        $pol = self::settings();
        $user = DB::table('users')->where('id', $userId)->first(['id', 'created_at', 'member_type', 'member_group']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        $exempt = $user->member_group === 'children';
        $first = self::firstPeriodOf($user, $pol);
        $start = $from && strcmp($from, $first) > 0 ? $from : $first;
        $end = $to ?? Ethiopian::currentPeriod();
        $rows = DB::table('payments as p')->leftJoin('users as v', 'v.id', '=', 'p.verified_by')->where('p.user_id', $userId)->orderByDesc('p.period')->select('p.*', 'v.full_name as verified_by_name')->get()->all();
        $byPeriod = [];
        foreach ($rows as $r) {
            foreach (Ethiopian::monthsBetween($r->period, $r->coverage_end ?? $r->period) as $m) $byPeriod[$m] = $r;
        }
        $today = Dates::todayLocal();
        $months = [];
        foreach (strcmp($start, $end) <= 0 ? Ethiopian::monthsBetween($start, $end) : [] as $period) {
            $pay = $byPeriod[$period] ?? null;
            $rate = $pay ? Num::n($pay->monthly_rate ?? ((float) $pay->amount / ($pay->months ?: 1))) : (self::rateForPeriod($user->member_type, $period)['monthly_amount'] ?? null);
            $paidOn = $pay ? Dates::toDateOnly($pay->paid_on) : null;
            $deadline = self::deadlineOf($period, (int) $pol['grace_days']);
            $onTime = (bool) ($pay && $paidOn <= $deadline);
            $months[] = [
                'period' => $period,
                'required' => $exempt ? 0 : $rate,
                'paid' => $pay ? $rate : 0,
                'paid_on' => $paidOn,
                'status' => $exempt ? 'exempt' : ($pay ? ($onTime ? 'paid' : 'late') : ($today <= $deadline ? 'due' : 'unpaid')),
                'on_time' => $exempt || $onTime,
                'payment' => self::serialize($pay),
            ];
        }
        return ['user' => $user, 'pol' => $pol, 'exempt' => $exempt, 'months' => $months, 'payments' => $rows];
    }

    /** A member's months (newest first) with payments and totals. */
    public static function forMember(int $userId): array
    {
        $m = self::monthsOf($userId);
        $current = Ethiopian::currentPeriod();
        $ahead = [];
        foreach ($m['payments'] as $p) {
            foreach (Ethiopian::monthsBetween($p->period, $p->coverage_end) as $mm) {
                if (strcmp($mm, $current) > 0) $ahead[] = ['period' => $mm, 'required' => Num::n($p->monthly_rate), 'paid' => Num::n($p->monthly_rate), 'paid_on' => Dates::toDateOnly($p->paid_on), 'status' => 'paid', 'on_time' => true, 'payment' => self::serialize($p)];
            }
        }
        $list = array_merge($m['months'], $ahead);
        usort($list, fn ($a, $b) => strcmp($b['period'], $a['period']));
        $past = $m['months'];
        $ends = array_map(fn ($r) => $r->coverage_end ?? $r->period, $m['payments']);
        sort($ends);
        return [
            'policy' => self::policy(),
            'member_type' => $m['user']->member_type ?? null,
            'exempt' => $m['exempt'],
            'months' => $list,
            'payments' => array_map([self::class, 'serialize'], $m['payments']),
            'paid_count' => count(array_filter($past, fn ($x) => $x['status'] === 'paid' || $x['status'] === 'late')),
            'unpaid_count' => $m['exempt'] ? 0 : count(array_filter($past, fn ($x) => $x['status'] === 'unpaid')),
            'late_count' => count(array_filter($past, fn ($x) => $x['status'] === 'late')),
            'paid_until' => $ends ? end($ends) : null,
            'year' => self::yearSummary($m, $current),
            'total_paid' => Num::clean(array_sum(array_map(fn ($r) => (float) $r->amount, $m['payments']))),
        ];
    }

    /**
     * The current Ethiopian year, month by month: which of its 12 months are covered by a payment
     * (also months paid ahead). "All paid" only when the 12 months are all covered.
     */
    private static function yearSummary(array $m, string $current): array
    {
        $year = Ethiopian::parsePeriod($current)['year'];
        $covered = [];
        foreach ($m['payments'] as $p) {
            foreach (Ethiopian::monthsBetween($p->period, $p->coverage_end ?? $p->period) as $mm) $covered[$mm] = true;
        }
        $ethMonthNames = ['', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'];
        $ethMonthNamesEn = ['', 'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit', 'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'];

        $paid = [];
        $unpaid = [];
        $paidDetails = [];
        $unpaidDetails = [];

        for ($i = 1; $i <= 12; $i++) {
            $period = Ethiopian::period($year, $i);
            $isPaid = $m['exempt'] || isset($covered[$period]);
            $item = [
                'month' => $i,
                'period' => $period,
                'name' => $ethMonthNames[$i] ?? '',
                'name_en' => $ethMonthNamesEn[$i] ?? '',
            ];
            if ($isPaid) {
                $paid[] = $i;
                $paidDetails[] = $item;
            } else {
                $unpaid[] = $i;
                $unpaidDetails[] = $item;
            }
        }
        return [
            'year' => $year,
            'months_total' => 12,
            'months_paid' => count($paid),
            'paid_months' => $paid,
            'unpaid_months' => $unpaid,
            'paid_month_details' => $paidDetails,
            'unpaid_month_details' => $unpaidDetails,
            'full' => count($paid) === 12,
            'exempt' => $m['exempt'],
        ];
    }

    /** Share of months paid on time over [from, to] (late months earn lateCredit). Children: exempt. */
    public static function paymentPercent(int $userId, string $from, string $to, float|int $lateCredit = 0.5): array
    {
        $m = self::monthsOf($userId, $from, $to);
        if ($m['exempt']) return ['percent' => 100, 'exempt' => true, 'months' => []];
        $counted = array_values(array_filter($m['months'], fn ($x) => $x['status'] !== 'due'));
        if (! $counted) return ['percent' => null, 'exempt' => false, 'months' => $m['months']];
        $score = 0;
        foreach ($counted as $x) $score += $x['status'] === 'paid' ? 1 : ($x['status'] === 'late' ? $lateCredit : 0);
        return ['percent' => Num::clean(floor(($score / count($counted)) * 1000 + 0.5) / 10), 'exempt' => false, 'months' => $m['months']];
    }

    /** Admin: members (children excluded) for one month with the covering payment. */
    public static function adminList(array $f, array $page): array
    {
        $period = $f['period'] ?? Ethiopian::currentPeriod();
        $qb = DB::table('users as u')
            ->leftJoin('payments as p', fn ($j) => $j->on('p.user_id', '=', 'u.id')->where('p.period', '<=', $period)->where('p.coverage_end', '>=', $period))
            ->whereIn('u.account_type', ['user', 'admin'])
            ->where(['u.status' => 'active', 'u.membership_status' => 'active'])
            ->where('u.member_group', '<>', 'children')->whereNull('u.deleted_at')
            ->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.member_type as user_member_type', 'p.*', 'u.id as uid')
            ->orderBy('u.full_name');
        $status = $f['status'] ?? null;
        if ($status === 'paid') $qb->whereNotNull('p.id');
        if ($status === 'unpaid') $qb->whereNull('p.id');
        if (! empty($f['member_type'])) $qb->where('u.member_type', $f['member_type']);
        MemberIds::search($qb, $f['q'] ?? null);
        $res = Page::paginate($qb, $page);
        $covering = fn () => DB::table('payments')->where('period', '<=', $period)->where('coverage_end', '>=', $period);
        $paid = $covering()->count();
        $total = $covering()->sum(DB::raw('COALESCE(monthly_rate, amount / months)'));
        $rates = ['student' => self::rateForPeriod('student', $period), 'worker' => self::rateForPeriod('worker', $period)];
        return [
            'items' => array_map(function ($r) use ($rates) {
                $t = $r->user_member_type ?? null;
                $pay = null;
                if ($r->id) {
                    $p = clone $r;
                    $p->user_id = $r->uid;
                    $pay = self::serialize($p);
                }
                return [
                    'user_id' => $r->uid,
                    'full_name' => $r->full_name,
                    'member_id' => MemberIds::format($r->member_no, $r->member_group),
                    'phone' => $r->phone,
                    'member_type' => $t,
                    'required' => $t ? ($rates[$t]['monthly_amount'] ?? null) : null,
                    'payment' => $pay,
                ];
            }, $res['items']),
            'meta' => $res['meta'] + ['period' => $period, 'paid_count' => $paid, 'total_amount' => Num::n($total ?? 0)],
        ];
    }

    /**
     * Financial summary for monthly contributions for the selected Ethiopian year and month.
     */
    public static function contributionSummary(array $f): array
    {
        $period = $f['period'] ?? Ethiopian::currentPeriod();
        $pInfo = Ethiopian::parsePeriod($period);
        $year = (int) ($f['year'] ?? $pInfo['year']);
        $month = (int) ($f['month'] ?? $pInfo['month']);
        if ($month < 1) $month = 1;
        if ($month > 13) $month = 13;
        $period = Ethiopian::period($year, $month);

        $targetMonths = [];
        for ($m = 1; $m <= $month; $m++) {
            $targetMonths[] = Ethiopian::period($year, $m);
        }

        $qb = DB::table('users as u')
            ->whereIn('u.account_type', ['user', 'admin'])
            ->when(Schema::hasTable('roles'), fn ($q) => $q->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr')->whereColumn('hr.id', 'u.role_id')->where('hr.is_hidden', true)))
            ->where(['u.status' => 'active', 'u.membership_status' => 'active'])
            ->where('u.member_group', '<>', 'children')
            ->whereNull('u.deleted_at');

        if (! empty($f['member_group'])) $qb->where('u.member_group', $f['member_group']);
        if (! empty($f['member_type'])) $qb->where('u.member_type', $f['member_type']);

        $totalRegistered = DB::table('users')->whereNull('deleted_at')->where('member_group', '<>', 'children')->count();
        $users = $qb->get(['u.id', 'u.member_type']);
        $expectedCount = count($users);
        $userIds = $users->pluck('id')->all();

        $rates = [
            'student' => (float) (self::rateForPeriod('student', $period)['monthly_amount'] ?? 0),
            'worker' => (float) (self::rateForPeriod('worker', $period)['monthly_amount'] ?? 0),
        ];

        $coveredByUser = [];
        $amountPaidByUser = [];
        if (! empty($userIds)) {
            $payments = DB::table('payments')
                ->whereIn('user_id', $userIds)
                ->where('period', '<=', $period)
                ->where('coverage_end', '>=', Ethiopian::period($year, 1))
                ->get(['user_id', 'period', 'coverage_end', 'amount', 'monthly_rate', 'months']);

            foreach ($payments as $p) {
                $pMonths = Ethiopian::monthsBetween($p->period, $p->coverage_end ?? $p->period);
                $rate = $p->monthly_rate ? (float) $p->monthly_rate : ((float) $p->amount / max(1, (int) $p->months));
                foreach ($pMonths as $mStr) {
                    if (in_array($mStr, $targetMonths, true) && ! isset($coveredByUser[$p->user_id][$mStr])) {
                        $coveredByUser[$p->user_id][$mStr] = true;
                        $amountPaidByUser[$p->user_id] = ($amountPaidByUser[$p->user_id] ?? 0) + $rate;
                    }
                }
            }
        }

        $pendingReceipts = ! empty($userIds) ? DB::table('contribution_receipts')
            ->whereIn('user_id', $userIds)
            ->whereIn('status', ['submitted', 'pending', 'under_review'])
            ->where('period', '<=', $period)
            ->where('coverage_end', '>=', Ethiopian::period($year, 1))
            ->pluck('user_id')
            ->flip()
            ->all() : [];

        $paidUsers = 0;
        $partialUsers = 0;
        $unpaidUsers = 0;
        $pendingUsers = 0;
        $totalExpectedAmount = 0;
        $totalCollectedAmount = 0;

        foreach ($users as $u) {
            $reqRate = $rates[$u->member_type] ?? 0;
            $userExpected = $reqRate * count($targetMonths);
            $totalExpectedAmount += $userExpected;

            $paidMonthsCount = isset($coveredByUser[$u->id]) ? count($coveredByUser[$u->id]) : 0;
            $amtPaid = $amountPaidByUser[$u->id] ?? 0;
            $totalCollectedAmount += min($amtPaid, $userExpected);

            if ($paidMonthsCount >= count($targetMonths)) {
                $paidUsers++;
            } elseif ($paidMonthsCount > 0) {
                $partialUsers++;
            } elseif (isset($pendingReceipts[$u->id])) {
                $pendingUsers++;
                $unpaidUsers++;
            } else {
                $unpaidUsers++;
            }
        }

        $outstandingAmount = max(0, $totalExpectedAmount - $totalCollectedAmount);
        $collectionPercent = $totalExpectedAmount > 0
            ? round(($totalCollectedAmount / $totalExpectedAmount) * 100, 1)
            : 0;

        return [
            'period' => $period,
            'year' => $year,
            'month' => $month,
            'months_count' => count($targetMonths),
            'total_registered_users' => $totalRegistered,
            'total_expected_users' => $expectedCount,
            'paid_users' => $paidUsers,
            'partially_paid_users' => $partialUsers,
            'unpaid_users' => $unpaidUsers,
            'pending_users' => $pendingUsers,
            'total_expected_amount' => Num::n($totalExpectedAmount),
            'total_collected_amount' => Num::n($totalCollectedAmount),
            'outstanding_amount' => Num::n($outstandingAmount),
            'collection_percentage' => $collectionPercent,
            'currency' => 'ETB',
        ];
    }

    /**
     * Year-wide month-by-month analytics summary for Ethiopian calendar (13 months).
     */
    public static function yearlyContributionSummary(array $f): array
    {
        $currentYear = (int) Ethiopian::parsePeriod(Ethiopian::currentPeriod())['year'];
        $year = (int) ($f['year'] ?? $currentYear);
        if ($year < 1900 || $year > 2200) {
            $year = $currentYear;
        }

        $qb = DB::table('users as u')
            ->whereIn('u.account_type', ['user', 'admin'])
            ->when(Schema::hasTable('roles'), fn ($q) => $q->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr')->whereColumn('hr.id', 'u.role_id')->where('hr.is_hidden', true)))
            ->where(['u.status' => 'active', 'u.membership_status' => 'active'])
            ->where('u.member_group', '<>', 'children')
            ->whereNull('u.deleted_at');

        if (! empty($f['member_group'])) $qb->where('u.member_group', $f['member_group']);
        if (! empty($f['member_type'])) $qb->where('u.member_type', $f['member_type']);

        $totalRegistered = DB::table('users')->whereNull('deleted_at')->where('member_group', '<>', 'children')->count();
        $users = $qb->get(['u.id', 'u.member_type']);
        $expectedCount = count($users);
        $userIds = $users->pluck('id')->all();

        $startPeriod = Ethiopian::period($year, 1);
        $endPeriod = Ethiopian::period($year, 13);

        $coveredByUser = [];
        $amountPaidByUserMonth = [];

        if (! empty($userIds)) {
            $payments = DB::table('payments')
                ->whereIn('user_id', $userIds)
                ->where('period', '<=', $endPeriod)
                ->where('coverage_end', '>=', $startPeriod)
                ->get(['user_id', 'period', 'coverage_end', 'amount', 'monthly_rate', 'months']);

            foreach ($payments as $p) {
                $pMonths = Ethiopian::monthsBetween($p->period, $p->coverage_end ?? $p->period);
                $rate = $p->monthly_rate ? (float) $p->monthly_rate : ((float) $p->amount / max(1, (int) $p->months));
                foreach ($pMonths as $mStr) {
                    $parts = explode('-', $mStr);
                    if (count($parts) === 2 && (int) $parts[0] === $year) {
                        $coveredByUser[$p->user_id][$mStr] = true;
                        $amountPaidByUserMonth[$p->user_id][$mStr] = ($amountPaidByUserMonth[$p->user_id][$mStr] ?? 0) + $rate;
                    }
                }
            }
        }

        $ethMonthNamesAm = [
            1 => 'መስከረም', 2 => 'ጥቅምት', 3 => 'ሕዳር', 4 => 'ታኅሣሥ',
            5 => 'ጥር', 6 => 'የካቲት', 7 => 'መጋቢት', 8 => 'ሚያዝያ',
            9 => 'ግንቦት', 10 => 'ሰኔ', 11 => 'ሐምሌ', 12 => 'ነሐሴ', 13 => 'ጳጉሜን'
        ];

        $ethMonthNamesEn = [
            1 => 'Meskerem', 2 => 'Tikimt', 3 => 'Hidar', 4 => 'Tahsas',
            5 => 'Tir', 6 => 'Yakatit', 7 => 'Megabit', 8 => 'Miyazya',
            9 => 'Ginbot', 10 => 'Sene', 11 => 'Hamle', 12 => 'Nehase', 13 => 'Puagme'
        ];

        $monthlyStats = [];
        $grandExpected = 0;
        $grandCollected = 0;

        for ($m = 1; $m <= 13; $m++) {
            $mPeriod = Ethiopian::period($year, $m);
            $rates = [
                'student' => (float) (self::rateForPeriod('student', $mPeriod)['monthly_amount'] ?? 0),
                'worker' => (float) (self::rateForPeriod('worker', $mPeriod)['monthly_amount'] ?? 0),
            ];

            $mExpected = 0;
            $mCollected = 0;
            $mPaid = 0;
            $mPartial = 0;
            $mUnpaid = 0;

            foreach ($users as $u) {
                $reqRate = $rates[$u->member_type] ?? 0;
                $mExpected += $reqRate;

                $amt = $amountPaidByUserMonth[$u->id][$mPeriod] ?? 0;
                $hasCover = isset($coveredByUser[$u->id][$mPeriod]);

                if ($hasCover || $amt >= $reqRate) {
                    $mPaid++;
                    $mCollected += $reqRate;
                } elseif ($amt > 0) {
                    $mPartial++;
                    $mCollected += $amt;
                } else {
                    $mUnpaid++;
                }
            }

            $grandExpected += $mExpected;
            $grandCollected += $mCollected;

            $monthlyStats[] = [
                'month' => $m,
                'period' => $mPeriod,
                'month_name_am' => $ethMonthNamesAm[$m] ?? "$m",
                'month_name_en' => $ethMonthNamesEn[$m] ?? "$m",
                'total_expected_users' => $expectedCount,
                'paid_users' => $mPaid,
                'partially_paid_users' => $mPartial,
                'unpaid_users' => $mUnpaid,
                'total_expected_amount' => Num::n($mExpected),
                'total_collected_amount' => Num::n($mCollected),
                'outstanding_amount' => Num::n(max(0, $mExpected - $mCollected)),
                'collection_percentage' => $mExpected > 0 ? round(($mCollected / $mExpected) * 100, 1) : 0,
            ];
        }

        return [
            'year' => $year,
            'total_registered_users' => $totalRegistered,
            'total_expected_users' => $expectedCount,
            'total_expected_amount' => Num::n($grandExpected),
            'total_collected_amount' => Num::n($grandCollected),
            'outstanding_amount' => Num::n(max(0, $grandExpected - $grandCollected)),
            'collection_percentage' => $grandExpected > 0 ? round(($grandCollected / $grandExpected) * 100, 1) : 0,
            'months' => $monthlyStats,
            'currency' => 'ETB',
        ];
    }

    /**
     * Detailed user contribution list with month-based payment ordering and comprehensive filters.
     */
    public static function detailedContributions(array $f, array $page): array
    {
        $period = $f['period'] ?? Ethiopian::currentPeriod();
        $pInfo = Ethiopian::parsePeriod($period);
        $year = (int) ($f['year'] ?? $pInfo['year']);
        $month = (int) ($f['month'] ?? $pInfo['month']);
        if ($month < 1) $month = 1;
        if ($month > 13) $month = 13;
        $period = Ethiopian::period($year, $month);

        $targetMonths = [];
        for ($m = 1; $m <= $month; $m++) {
            $targetMonths[] = Ethiopian::period($year, $m);
        }

        $qb = DB::table('users as u')
            ->whereIn('u.account_type', ['user', 'admin'])
            ->when(Schema::hasTable('roles'), fn ($q) => $q->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr')->whereColumn('hr.id', 'u.role_id')->where('hr.is_hidden', true)))
            ->where(['u.status' => 'active', 'u.membership_status' => 'active'])
            ->where('u.member_group', '<>', 'children')
            ->whereNull('u.deleted_at')
            ->select('u.id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.member_type');

        if (! empty($f['member_group'])) $qb->where('u.member_group', $f['member_group']);
        if (! empty($f['member_type'])) $qb->where('u.member_type', $f['member_type']);
        MemberIds::search($qb, $f['q'] ?? null);

        $users = $qb->orderBy('u.full_name')->get();
        $userIds = $users->pluck('id')->all();

        $rates = [
            'student' => (float) (self::rateForPeriod('student', $period)['monthly_amount'] ?? 0),
            'worker' => (float) (self::rateForPeriod('worker', $period)['monthly_amount'] ?? 0),
        ];

        $coveredByUser = [];
        $amountPaidByUser = [];
        $latestPaymentByUser = [];
        $allPaymentsByUser = [];
        if (! empty($userIds)) {
            $payments = DB::table('payments')
                ->whereIn('user_id', $userIds)
                ->orderBy('paid_on', 'desc')
                ->get();

            foreach ($payments as $p) {
                $allPaymentsByUser[$p->user_id][] = self::serialize($p);
                if (! isset($latestPaymentByUser[$p->user_id])) {
                    $latestPaymentByUser[$p->user_id] = $p;
                }
                $pMonths = Ethiopian::monthsBetween($p->period, $p->coverage_end ?? $p->period);
                $rate = $p->monthly_rate ? (float) $p->monthly_rate : ((float) $p->amount / max(1, (int) $p->months));
                foreach ($pMonths as $mStr) {
                    if (in_array($mStr, $targetMonths, true) && ! isset($coveredByUser[$p->user_id][$mStr])) {
                        $coveredByUser[$p->user_id][$mStr] = true;
                        $amountPaidByUser[$p->user_id] = ($amountPaidByUser[$p->user_id] ?? 0) + $rate;
                    }
                }
            }
        }

        $pendingReceiptsByUser = [];
        if (! empty($userIds)) {
            $receipts = DB::table('contribution_receipts')
                ->whereIn('user_id', $userIds)
                ->whereIn('status', ['submitted', 'pending', 'under_review'])
                ->orderBy('id', 'desc')
                ->get();
            foreach ($receipts as $r) {
                if (! isset($pendingReceiptsByUser[$r->user_id])) {
                    $pendingReceiptsByUser[$r->user_id] = [
                        'id' => (int) $r->id,
                        'period' => $r->period,
                        'months' => (int) $r->months,
                        'submitted_amount' => (float) ($r->submitted_amount ?? $r->expected_amount ?? 0),
                        'method' => $r->method ?? 'bank',
                        'reference' => $r->reference ?? null,
                        'receipt_path' => $r->receipt_path ?? null,
                        'status' => $r->status,
                        'paid_on' => $r->paid_on ?? null,
                    ];
                }
            }
        }

        $allRows = [];
        $statusFilter = $f['status'] ?? null;
        $paidMonthsFilter = isset($f['paid_months']) ? (int) $f['paid_months'] : null;
        $unpaidMonthsFilter = isset($f['unpaid_months']) ? (int) $f['unpaid_months'] : null;

        foreach ($users as $u) {
            $reqRate = $rates[$u->member_type] ?? 0;
            $userExpected = $reqRate * count($targetMonths);
            $covered = $coveredByUser[$u->id] ?? [];
            $paidCount = count($covered);
            $unpaidCount = count($targetMonths) - $paidCount;
            $amtPaid = $amountPaidByUser[$u->id] ?? 0;
            $outstanding = max(0, $userExpected - $amtPaid);
            $hasPending = isset($pendingReceiptsByUser[$u->id]);

            if ($paidCount >= count($targetMonths)) {
                $status = 'paid';
                $priority = 1;
            } elseif ($paidCount > 0) {
                $status = 'partial';
                $priority = 2;
            } elseif ($hasPending) {
                $status = 'pending';
                $priority = 3;
            } else {
                $status = 'unpaid';
                $priority = 4;
            }

            if ($statusFilter && $statusFilter !== 'all') {
                if ($statusFilter === 'paid' && $status !== 'paid') continue;
                if ($statusFilter === 'partial' && $status !== 'partial') continue;
                if ($statusFilter === 'unpaid' && $status !== 'unpaid' && $status !== 'pending') continue;
                if ($statusFilter === 'pending' && ! $hasPending && $status !== 'pending') continue;
            }
            if ($paidMonthsFilter !== null && $paidCount < $paidMonthsFilter) continue;
            if ($unpaidMonthsFilter !== null && $unpaidCount < $unpaidMonthsFilter) continue;

            $paidMonthNums = [];
            $unpaidMonthNums = [];
            for ($mi = 1; $mi <= $month; $mi++) {
                $mP = Ethiopian::period($year, $mi);
                if (isset($covered[$mP])) {
                    $paidMonthNums[] = $mi;
                } else {
                    $unpaidMonthNums[] = $mi;
                }
            }

            $latestPay = $latestPaymentByUser[$u->id] ?? null;

            $allRows[] = [
                'priority' => $priority,
                'user_id' => $u->id,
                'full_name' => $u->full_name,
                'member_id' => MemberIds::format($u->member_no, $u->member_group),
                'member_no' => $u->member_no,
                'phone' => $u->phone,
                'member_group' => $u->member_group,
                'member_type' => $u->member_type,
                'monthly_required' => Num::n($reqRate),
                'months_in_scope' => count($targetMonths),
                'months_paid' => $paidCount,
                'months_unpaid' => $unpaidCount,
                'paid_months_list' => $paidMonthNums,
                'unpaid_months_list' => $unpaidMonthNums,
                'total_expected' => Num::n($userExpected),
                'total_paid' => Num::n($amtPaid),
                'outstanding' => Num::n($outstanding),
                'status' => $status,
                'has_pending_receipt' => $hasPending,
                'pending_receipt' => $pendingReceiptsByUser[$u->id] ?? null,
                'latest_payment_date' => $latestPay ? Dates::toDateOnly($latestPay->paid_on) : null,
                'latest_payment_method' => $latestPay->method ?? null,
                'latest_reference' => $latestPay->reference ?? null,
                'latest_receipt_path' => $latestPay->receipt_path ?? null,
                'payment_history' => array_slice($allPaymentsByUser[$u->id] ?? [], 0, 10),
            ];
        }

        usort($allRows, function ($a, $b) {
            if ($a['priority'] !== $b['priority']) {
                return $a['priority'] <=> $b['priority'];
            }
            if ($a['outstanding'] != $b['outstanding']) {
                return $b['outstanding'] <=> $a['outstanding'];
            }
            return strcmp($a['full_name'], $b['full_name']);
        });

        $totalItems = count($allRows);
        $perPage = max(1, (int) ($page['limit'] ?? 50));
        $currentPage = max(1, (int) ($page['page'] ?? 1));
        $offset = ($currentPage - 1) * $perPage;
        $items = array_slice($allRows, $offset, $perPage);

        return [
            'items' => $items,
            'meta' => [
                'page' => $currentPage,
                'limit' => $perPage,
                'total' => $totalItems,
                'pages' => (int) ceil($totalItems / $perPage),
                'period' => $period,
                'year' => $year,
                'month' => $month,
            ],
        ];
    }

    // ------------------------------------------------------------------ recording
    private static function assertNoOverlap(int $userId, string $start, string $end, ?int $exceptId = null): void
    {
        $q = DB::table('payments')->where('user_id', $userId)->where('period', '<=', $end)->where('coverage_end', '>=', $start);
        if ($exceptId) $q->where('id', '<>', $exceptId);
        $clash = $q->first(['id', 'period', 'coverage_end']);
        if ($clash) throw ApiError::conflict('PAYMENT_OVERLAP', "Already paid {$clash->period} – {$clash->coverage_end}");
    }

    private static function rateFor(object $user, string $period): array
    {
        if ($user->member_group === 'children') throw ApiError::conflict('CHILDREN_EXEMPT', 'Children do not pay');
        if (! $user->member_type) throw ApiError::field('member_type', 'MEMBER_TYPE_REQUIRED');
        $rate = self::rateForPeriod($user->member_type, $period);
        if (! $rate) throw ApiError::conflict('RATE_NOT_SET', 'No monthly rate is set for this member type');
        return $rate;
    }

    public static function record(array $actx, array $input): array
    {
        $pol = self::settings();
        $out = DB::transaction(function () use ($actx, $input, $pol) {
            $user = DB::table('users')->where('id', $input['user_id'])->whereNull('deleted_at')->lockForUpdate()->first(['id', 'member_type', 'member_group']);
            if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
            $months = $input['months'] ?? 1;
            $start = $input['period'];
            $end = Ethiopian::addMonths($start, $months - 1);
            $periodList = Ethiopian::monthsBetween($start, $end);
            if ($start === '2019-01' || in_array('2019-01', $periodList, true)) {
                throw ApiError::badRequest('MESKEREM_2019_NOT_PAYABLE', 'Meskerem 2019 is not payable');
            }
            self::assertNoOverlap($user->id, $start, $end);
            $rate = self::rateFor($user, $start);
            $row = [
                'user_id' => $user->id,
                'period' => $start,
                'months' => $months,
                'coverage_end' => $end,
                'member_type' => $user->member_type,
                'monthly_rate' => $rate['monthly_amount'],
                'amount' => $rate['monthly_amount'] * $months,
                'currency' => $rate['currency'] ?: $pol['currency'],
                'method' => $input['method'] ?? 'cash',
                'reference' => $input['reference'] ?? null,
                'paid_on' => $input['paid_on'] ?? Dates::todayLocal(),
                'note' => $input['note'] ?? null,
                'status' => 'recorded',
                'recorded_by' => $actx['auth']->id,
            ];
            $id = DB::table('payments')->insertGetId($row);
            Audit::log($actx, Audit::PAYMENT_RECORD, 'payment', $id, ['user_id' => $row['user_id'], 'period' => $start, 'months' => $months, 'coverage_end' => $end, 'amount' => Num::clean($row['amount']), 'monthly_rate' => $row['monthly_rate'], 'member_type' => $row['member_type']], inTrx: true);
            return self::get($id);
        });
        Choir::scheduleEligibility([$input['user_id']]);
        return $out;
    }

    public static function get(int $id): array
    {
        $p = DB::table('payments as p')->leftJoin('users as r', 'r.id', '=', 'p.recorded_by')->leftJoin('users as v', 'v.id', '=', 'p.verified_by')
            ->where('p.id', $id)->first(['p.*', 'r.full_name as recorded_by_name', 'v.full_name as verified_by_name']);
        if (! $p) throw ApiError::notFound('PAYMENT_NOT_FOUND', 'Payment not found');
        return self::serialize($p);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $out = DB::transaction(function () use ($actx, $id, $input) {
            $p = DB::table('payments')->where('id', $id)->lockForUpdate()->first();
            if (! $p) throw ApiError::notFound('PAYMENT_NOT_FOUND', 'Payment not found');
            $patch = array_intersect_key($input, array_flip(['method', 'reference', 'paid_on', 'note']));
            if (isset($input['months']) && $input['months'] !== (int) $p->months) {
                $end = Ethiopian::addMonths($p->period, $input['months'] - 1);
                self::assertNoOverlap($p->user_id, $p->period, $end, $id);
                $patch['months'] = $input['months'];
                $patch['coverage_end'] = $end;
                $patch['amount'] = (float) ($p->monthly_rate ?? $p->amount) * $input['months'];
            }
            if ($patch) DB::table('payments')->where('id', $id)->update($patch);
            Audit::log($actx, Audit::PAYMENT_RECORD, 'payment', $id, ['updated' => array_keys($patch)], inTrx: true);
            return ['payment' => self::get($id), 'userId' => $p->user_id];
        });
        Choir::scheduleEligibility([$out['userId']]);
        return $out['payment'];
    }

    public static function verify(array $actx, int $id): array
    {
        $p = DB::table('payments')->where('id', $id)->first(['id', 'status', 'user_id']);
        if (! $p) throw ApiError::notFound('PAYMENT_NOT_FOUND', 'Payment not found');
        DB::table('payments')->where('id', $id)->update(['status' => 'verified', 'verified_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::PAYMENT_VERIFY, 'payment', $id, ['user_id' => $p->user_id, 'previous' => $p->status]);
        return self::get($id);
    }

    public static function remove(array $actx, int $id): void
    {
        $p = DB::table('payments')->where('id', $id)->first();
        if (! $p) throw ApiError::notFound('PAYMENT_NOT_FOUND', 'Payment not found');
        DB::table('payments')->where('id', $id)->delete();
        if ($p->receipt) Storage::remove($p->receipt);
        Audit::log($actx, Audit::PAYMENT_RECORD, 'payment', $id, ['deleted' => true, 'user_id' => $p->user_id, 'period' => $p->period, 'coverage_end' => $p->coverage_end]);
        Choir::scheduleEligibility([$p->user_id]);
    }

    public static function setReceipt(array $actx, int $id, UploadedFile $file): array
    {
        $p = DB::table('payments')->where('id', $id)->first(['id', 'receipt']);
        if (! $p) throw ApiError::notFound('PAYMENT_NOT_FOUND', 'Payment not found');
        $saved = Storage::save('image', Storage::FOLDERS['PAYMENT_RECEIPTS'], $file);
        DB::table('payments')->where('id', $id)->update(['receipt' => $saved['path']]);
        if ($p->receipt) Storage::remove($p->receipt);
        Audit::log($actx, Audit::PAYMENT_RECORD, 'payment', $id, ['receipt' => 'replaced']);
        return self::get($id);
    }

    // ------------------------------------------------------------------ contribution receipts (Requirement 1)
    public static function serializeReceipt(?object $r): ?array
    {
        if (! $r) return null;
        $start = $r->period ?? $r->start_period ?? null;
        $end = $r->coverage_end ?? $r->end_period ?? null;
        $amount = isset($r->submitted_amount) ? Num::n($r->submitted_amount) : (isset($r->amount) ? Num::n($r->amount) : (isset($r->expected_amount) ? Num::n($r->expected_amount) : null));
        $filePath = $r->receipt_path ?? $r->file_path ?? null;
        $note = $r->member_note ?? $r->note ?? null;
        $status = ($r->status === 'submitted') ? 'pending' : $r->status;
        $reason = $r->review_note ?? $r->rejection_reason ?? null;
        $reviewer = $r->reviewed_by ?? $r->verified_by ?? null;
        $reviewedAt = $r->reviewed_at ?? $r->verified_at ?? null;

        $out = [
            'id' => (int) $r->id,
            'user_id' => (int) $r->user_id,
            'months' => (int) ($r->months ?? 1),
            'start_period' => $start,
            'period' => $start,
            'end_period' => $end,
            'coverage_end' => $end,
            'amount' => $amount,
            'submitted_amount' => $amount,
            'expected_amount' => isset($r->expected_amount) ? Num::n($r->expected_amount) : null,
            'currency' => $r->currency ?? 'ETB',
            'file_name' => $r->file_name ?? basename($filePath ?? 'receipt.jpg'),
            'mime_type' => $r->mime_type ?? 'image/jpeg',
            'file_size' => (int) ($r->file_size ?? 0),
            'note' => $note,
            'member_note' => $note,
            'status' => $status,
            'rejection_reason' => $reason,
            'review_note' => $reason,
            'receipt_url' => Storage::url($filePath),
            'file_path' => $filePath,
            'receipt_path' => $filePath,
            'verified_by' => $reviewer ? (int) $reviewer : null,
            'reviewed_by' => $reviewer ? (int) $reviewer : null,
            'verified_at' => $reviewedAt,
            'reviewed_at' => $reviewedAt,
            'payment_id' => $r->payment_id ? (int) $r->payment_id : null,
            'created_at' => $r->created_at,
        ];
        if (isset($r->full_name)) $out['user_name'] = $r->full_name;
        if (isset($r->member_no)) $out['member_id'] = MemberIds::format($r->member_no, $r->member_group ?? null);
        if (isset($r->phone)) $out['phone'] = $r->phone;
        if (isset($r->verified_by_name)) $out['verified_by_name'] = $r->verified_by_name;
        if (isset($r->reviewer_name)) $out['reviewer_name'] = $r->reviewer_name;
        return $out;
    }

    public static function submitReceipt(array $actx, array $input, UploadedFile $file): array
    {
        $userId = $actx['auth']->id;
        $user = DB::table('users')->where('id', $userId)->whereNull('deleted_at')->first(['id', 'member_type', 'member_group']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        if ($user->member_group === 'children') throw ApiError::conflict('CHILDREN_EXEMPT', 'Children do not pay');

        $months = max(1, min((int) ($input['months'] ?? 1), self::MAX_MONTHS));

        $start = $input['period'] ?? null;
        if (! $start) {
            $latestEnd = DB::table('payments')->where('user_id', $userId)->max('coverage_end');
            $start = $latestEnd ? Ethiopian::addMonths($latestEnd, 1) : Ethiopian::currentPeriod();
        }
        $end = Ethiopian::addMonths($start, $months - 1);

        self::assertNoOverlap($userId, $start, $end);

        $pendingClash = DB::table('contribution_receipts')
            ->where('user_id', $userId)
            ->whereIn('status', ['pending', 'submitted', 'under_review'])
            ->where(function ($w) use ($start, $end) {
                $w->where(function ($q) use ($start, $end) {
                    $q->where('period', '<=', $end)->where('coverage_end', '>=', $start);
                })->orWhere(function ($q) use ($start, $end) {
                    $q->where('start_period', '<=', $end)->where('end_period', '>=', $start);
                });
            })
            ->first();
        if ($pendingClash) {
            $pStart = $pendingClash->period ?? $pendingClash->start_period ?? $start;
            $pEnd = $pendingClash->coverage_end ?? $pendingClash->end_period ?? $end;
            throw ApiError::conflict('RECEIPT_ALREADY_PENDING', "A receipt submission for {$pStart} – {$pEnd} is already pending verification.");
        }

        $saved = Storage::save('receipt', Storage::FOLDERS['RECEIPTS'], $file);

        $rate = self::rateForPeriod($user->member_type, $start);
        $amount = isset($input['amount']) && is_numeric($input['amount'])
            ? (float) $input['amount']
            : ($rate ? $rate['monthly_amount'] * $months : null);
        $currency = $rate['currency'] ?? self::settings()['currency'];

        $cols = Schema::getColumnListing('contribution_receipts');
        $row = [
            'user_id' => $userId,
            'months' => $months,
            'period' => $start,
            'start_period' => $start,
            'coverage_end' => $end,
            'end_period' => $end,
            'submitted_amount' => $amount,
            'expected_amount' => $amount ?? 0,
            'amount' => $amount,
            'currency' => $currency,
            'receipt_path' => $saved['path'],
            'file_path' => $saved['path'],
            'file_name' => $file->getClientOriginalName() ?: 'receipt',
            'mime_type' => $saved['mime'],
            'file_size' => $saved['size'],
            'member_note' => isset($input['note']) ? mb_substr(trim($input['note']), 0, 1000) : null,
            'note' => isset($input['note']) ? mb_substr(trim($input['note']), 0, 1000) : null,
            'status' => in_array('submitted', ['submitted']) ? 'submitted' : 'pending',
            'paid_on' => Dates::todayLocal(),
            'method' => 'bank',
            'created_at' => Dates::sql(Dates::now()),
            'updated_at' => Dates::sql(Dates::now()),
        ];
        // Filter row to only columns actually present in table
        $filteredRow = array_intersect_key($row, array_flip($cols));

        $id = DB::table('contribution_receipts')->insertGetId($filteredRow);

        Audit::log($actx, Audit::CONTRIBUTION_RECEIPT_SUBMIT, 'contribution_receipt', $id, [
            'user_id' => $userId,
            'months' => $months,
            'start_period' => $start,
            'end_period' => $end,
            'amount' => $amount,
        ]);

        Notifications::notifyReceiptSubmitted($id, $userId);

        $row = DB::table('contribution_receipts')->where('id', $id)->first();
        return self::serializeReceipt($row);
    }

    public static function myReceipts(int $userId): array
    {
        $cols = Schema::getColumnListing('contribution_receipts');
        $revCol = in_array('reviewed_by', $cols) ? 'reviewed_by' : 'verified_by';

        $rows = DB::table('contribution_receipts as r')
            ->leftJoin('users as v', 'v.id', '=', "r.{$revCol}")
            ->where('r.user_id', $userId)
            ->select('r.*', 'v.full_name as verified_by_name', 'v.full_name as reviewer_name')
            ->orderByDesc('r.id')
            ->get();

        return array_map(fn ($r) => self::serializeReceipt($r), $rows->all());
    }

    public static function receiptList(array $f, array $page): array
    {
        $cols = Schema::getColumnListing('contribution_receipts');
        $revCol = in_array('reviewed_by', $cols) ? 'reviewed_by' : 'verified_by';

        $qb = DB::table('contribution_receipts as r')
            ->join('users as u', 'u.id', '=', 'r.user_id')
            ->leftJoin('users as v', 'v.id', '=', "r.{$revCol}")
            ->select('r.*', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'v.full_name as verified_by_name', 'v.full_name as reviewer_name')
            ->orderByDesc('r.id');

        if (! empty($f['status'])) {
            $st = $f['status'];
            if ($st === 'pending') {
                $qb->whereIn('r.status', ['pending', 'submitted', 'under_review']);
            } else {
                $qb->where('r.status', $st);
            }
        }
        if (! empty($f['user_id'])) $qb->where('r.user_id', $f['user_id']);
        if (! empty($f['from'])) $qb->where('r.created_at', '>=', Dates::sql($f['from']));
        if (! empty($f['to'])) $qb->where('r.created_at', '<=', Dates::sql($f['to']));
        if (! empty($f['q'])) {
            $needle = "%{$f['q']}%";
            $qb->where(function ($w) use ($needle) {
                $w->where('u.full_name', 'like', $needle)
                  ->orWhere('u.phone', 'like', $needle)
                  ->orWhere('u.member_no', 'like', $needle);
            });
        }

        $res = Page::paginate($qb, $page);
        return [
            'items' => array_map(fn ($r) => self::serializeReceipt($r), $res['items']),
            'meta' => $res['meta'],
        ];
    }

    public static function approveReceipt(array $actx, int $receiptId): array
    {
        $r = DB::table('contribution_receipts')->where('id', $receiptId)->first();
        if (! $r) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Receipt not found');
        if (! in_array($r->status, ['pending', 'submitted', 'under_review'])) {
            throw ApiError::conflict('RECEIPT_NOT_PENDING', "Receipt is already {$r->status}");
        }

        $start = $r->period ?? $r->start_period;
        $end = $r->coverage_end ?? $r->end_period;
        $amountSubmitted = $r->submitted_amount ?? $r->amount ?? null;
        $filePath = $r->receipt_path ?? $r->file_path ?? null;
        $note = $r->member_note ?? $r->note ?? null;

        $pol = self::settings();
        $paymentId = DB::transaction(function () use ($actx, $r, $start, $end, $amountSubmitted, $filePath, $note, $pol) {
            $user = DB::table('users')->where('id', $r->user_id)->lockForUpdate()->first(['id', 'member_type', 'member_group']);
            if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');

            self::assertNoOverlap($r->user_id, $start, $end);

            $rate = self::rateForPeriod($user->member_type, $start);
            $monthlyRate = $rate ? $rate['monthly_amount'] : ($amountSubmitted ? $amountSubmitted / $r->months : 0);
            $amount = $amountSubmitted ?? ($monthlyRate * $r->months);

            $payRow = [
                'user_id' => $r->user_id,
                'period' => $start,
                'months' => $r->months,
                'coverage_end' => $end,
                'member_type' => $user->member_type,
                'monthly_rate' => $monthlyRate,
                'amount' => $amount,
                'currency' => $r->currency ?: ($rate['currency'] ?? $pol['currency']),
                'method' => 'bank_transfer',
                'reference' => "Receipt #{$r->id}",
                'paid_on' => Dates::toDateOnly($r->created_at),
                'receipt' => $filePath,
                'note' => $note,
                'status' => 'verified',
                'recorded_by' => $actx['auth']->id,
                'verified_by' => $actx['auth']->id,
            ];

            $pId = DB::table('payments')->insertGetId($payRow);

            $cols = Schema::getColumnListing('contribution_receipts');
            $upd = [
                'status' => 'approved',
                'payment_id' => $pId,
                'updated_at' => Dates::sql(Dates::now()),
            ];
            if (in_array('verified_by', $cols)) $upd['verified_by'] = $actx['auth']->id;
            if (in_array('reviewed_by', $cols)) $upd['reviewed_by'] = $actx['auth']->id;
            if (in_array('verified_at', $cols)) $upd['verified_at'] = Dates::sql(Dates::now());
            if (in_array('reviewed_at', $cols)) $upd['reviewed_at'] = Dates::sql(Dates::now());

            DB::table('contribution_receipts')->where('id', $r->id)->update($upd);

            Audit::log($actx, Audit::CONTRIBUTION_RECEIPT_VERIFY, 'contribution_receipt', $r->id, [
                'status' => 'approved',
                'payment_id' => $pId,
                'user_id' => $r->user_id,
                'amount' => $amount,
            ], inTrx: true);

            return $pId;
        });

        Choir::scheduleEligibility([$r->user_id]);

        Notifications::notifyReceiptReviewed($r->user_id, $receiptId, true);

        $cols = Schema::getColumnListing('contribution_receipts');
        $revCol = in_array('reviewed_by', $cols) ? 'reviewed_by' : 'verified_by';

        $row = DB::table('contribution_receipts as r')
            ->leftJoin('users as v', 'v.id', '=', "r.{$revCol}")
            ->where('r.id', $receiptId)
            ->select('r.*', 'v.full_name as verified_by_name', 'v.full_name as reviewer_name')
            ->first();

        return self::serializeReceipt($row);
    }

    public static function rejectReceipt(array $actx, int $receiptId, string $reason): array
    {
        $cleanReason = trim($reason);
        if ($cleanReason === '') {
            throw ApiError::badRequest('REASON_REQUIRED', 'Rejection reason is required');
        }
        $r = DB::table('contribution_receipts')->where('id', $receiptId)->first();
        if (! $r) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Receipt not found');
        if (! in_array($r->status, ['pending', 'submitted', 'under_review'])) {
            throw ApiError::conflict('RECEIPT_NOT_PENDING', "Receipt is already {$r->status}");
        }

        $cols = Schema::getColumnListing('contribution_receipts');
        $upd = [
            'status' => 'rejected',
            'updated_at' => Dates::sql(Dates::now()),
        ];
        if (in_array('rejection_reason', $cols)) $upd['rejection_reason'] = mb_substr($cleanReason, 0, 1000);
        if (in_array('review_note', $cols)) $upd['review_note'] = mb_substr($cleanReason, 0, 1000);
        if (in_array('verified_by', $cols)) $upd['verified_by'] = $actx['auth']->id;
        if (in_array('reviewed_by', $cols)) $upd['reviewed_by'] = $actx['auth']->id;
        if (in_array('verified_at', $cols)) $upd['verified_at'] = Dates::sql(Dates::now());
        if (in_array('reviewed_at', $cols)) $upd['reviewed_at'] = Dates::sql(Dates::now());

        DB::table('contribution_receipts')->where('id', $receiptId)->update($upd);

        Audit::log($actx, Audit::CONTRIBUTION_RECEIPT_REJECT, 'contribution_receipt', $receiptId, [
            'status' => 'rejected',
            'reason' => $reason,
            'user_id' => $r->user_id,
        ]);

        Notifications::notifyReceiptReviewed($r->user_id, $receiptId, false, $reason);

        $revCol = in_array('reviewed_by', $cols) ? 'reviewed_by' : 'verified_by';
        $row = DB::table('contribution_receipts as r')
            ->leftJoin('users as v', 'v.id', '=', "r.{$revCol}")
            ->where('r.id', $receiptId)
            ->select('r.*', 'v.full_name as verified_by_name', 'v.full_name as reviewer_name')
            ->first();

        return self::serializeReceipt($row);
    }

    public static function downloadReceiptFile(AuthContext $auth, int $receiptId)
    {
        $r = DB::table('contribution_receipts')->where('id', $receiptId)->first();
        if (! $r) throw ApiError::notFound('RECEIPT_NOT_FOUND', 'Receipt not found');

        $isOwner = (int) $r->user_id === (int) $auth->id;
        $canManage = $auth->can('payments.view') || $auth->can('payments.manage') || $auth->isAdmin;
        if (! $isOwner && ! $canManage) {
            throw ApiError::forbidden('RECEIPT_ACCESS_DENIED', 'You cannot view this receipt');
        }

        $path = $r->receipt_path ?? $r->file_path;
        $fileName = $r->file_name ?? basename($path);
        return Storage::download($path, $fileName);
    }
}

