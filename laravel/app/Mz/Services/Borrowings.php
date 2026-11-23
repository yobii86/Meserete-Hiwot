<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Borrowing / returns / signatures / fines (port of borrowingService.js). Every borrowing is an
 * individual record per user; bulk issues create N rows linked by an optional batch id. Direct
 * borrowing follows the borrowing.direct policy and each item's settings.
 */
final class Borrowings
{
    private const OPEN = ['active', 'partially_returned'];

    private static function policies(): array
    {
        return [
            'fines' => Settings::get('fines.policy') ?? ['enabled' => false, 'amount' => 0, 'period' => 'day', 'grace_days' => 0, 'max_amount' => null, 'currency' => 'ETB'],
            'reminders' => Settings::get('borrowing.reminders') ?? ['days_before' => 3, 'overdue_repeat_days' => 7, 'default_loan_days' => 14],
        ];
    }

    private static function base(): Builder
    {
        return DB::table('borrowings as b')->join('items as i', 'i.id', '=', 'b.item_id')->join('users as u', 'u.id', '=', 'b.user_id')
            ->where(function ($w) {
                $w->whereNull('i.category')->orWhereNotIn('i.category', ['books', 'book', 'መጻሕፍት']);
            })
            ->whereNull('i.library_category_id')
            ->leftJoin('borrowing_signatures as s', 's.borrowing_id', '=', 'b.id')
            ->leftJoin('users as iss', 'iss.id', '=', 'b.issued_by')->leftJoin('roles as issr', 'issr.id', '=', 'iss.role_id')
            ->leftJoin('users as rt', 'rt.id', '=', 'b.returned_to')->leftJoin('roles as rtr', 'rtr.id', '=', 'rt.role_id')
            ->select('b.*', 'i.name as item_name', 'i.domain as item_domain', 'i.code as item_code', 'i.image as item_image', 'u.full_name as user_name', 'u.phone as user_phone', 's.signed_at',
                Actor::hiddenName('iss', 'issr', 'issued_by_name'), Actor::hiddenName('rt', 'rtr', 'returned_to_name'));
    }

    public static function serialize(object $b, array $pol, bool $admin = false, ?string $today = null): array
    {
        $today ??= Dates::todayLocal();
        $open = in_array($b->status, self::OPEN, true);
        $due = Dates::toDateOnly($b->due_on);
        $deadline = $open ? Fines::deadlineState($due, $today, (int) $pol['reminders']['days_before']) : ['state' => $b->status, 'days_remaining' => null, 'days_overdue' => null];
        $fine = $open && ! $b->fine_overridden ? Fines::compute($due, $today, $pol['fines']) : Num::n($b->fine_amount);
        $out = [
            'id' => $b->id,
            'item' => ['id' => $b->item_id, 'name' => $b->item_name, 'code' => $b->item_code, 'image_url' => Storage::url($b->item_image), 'domain' => $b->item_domain ?? 'mezmur'],
            'quantity' => $b->quantity,
            'borrowed_on' => Dates::toDateOnly($b->borrowed_on),
            'due_on' => $due,
            'status' => $b->status,
            'deadline_state' => $deadline['state'],
            'days_remaining' => $deadline['days_remaining'],
            'days_overdue' => $deadline['days_overdue'],
            'issue_condition' => $b->issue_condition ?? null,
            'returned_on' => Dates::toDateOnly($b->returned_on),
            'returned_quantity' => $b->returned_quantity,
            'return_condition' => $b->return_condition,
            'fine' => ['amount' => $fine, 'currency' => ($pol['fines']['currency'] ?? null) ?: 'ETB', 'status' => $b->fine_status, 'overridden' => (bool) $b->fine_overridden],
            'signed' => (bool) $b->signed_at,
            'signed_at' => $b->signed_at ?? null,
            'notes' => $b->notes,
            'renewals' => $b->renewals ?? 0,
            'approved_at' => $b->approved_at ?? null,
            'rejection_reason' => $b->rejection_reason ?? null,
            'created_at' => $b->created_at,
        ];
        if ($admin) {
            $out['user'] = ['id' => $b->user_id, 'full_name' => $b->user_name, 'phone' => $b->user_phone];
            $out['batch_id'] = $b->batch_id;
            $out['issued_by_name'] = $b->issued_by_name;
            $out['returned_to_name'] = $b->returned_to_name;
            $out['return_notes'] = $b->return_notes;
            $out['fine']['override_reason'] = $b->fine_override_reason;
        }
        return $out;
    }

    private static function applyFilter(Builder $qb, array $f, string $today): Builder
    {
        if (! empty($f['user_id'])) $qb->where('b.user_id', $f['user_id']);
        if (! empty($f['item_id'])) $qb->where('b.item_id', $f['item_id']);
        if (! empty($f['batch_id'])) $qb->where('b.batch_id', $f['batch_id']);
        $status = $f['status'] ?? null;
        if ($status === 'open') $qb->whereIn('b.status', self::OPEN);
        elseif ($status === 'pending') $qb->where('b.status', 'pending_approval');
        elseif ($status === 'overdue') $qb->whereIn('b.status', self::OPEN)->where('b.due_on', '<', $today);
        elseif ($status) $qb->where('b.status', $status);
        if (! empty($f['due_from'])) $qb->where('b.due_on', '>=', $f['due_from']);
        if (! empty($f['due_to'])) $qb->where('b.due_on', '<=', $f['due_to']);
        if (! empty($f['fine_status'])) $qb->where('b.fine_status', $f['fine_status']);
        if (! empty($f['domain'])) $qb->where('i.domain', $f['domain']);
        if (! empty($f['department_id'])) $qb->where('i.department_id', $f['department_id']);
        if (! empty($f['category'])) $qb->where('i.category', $f['category']);
        if (! empty($f['q'])) {
            $q = $f['q'];
            $qb->where(fn ($w) => $w->where('u.full_name', 'like', "%$q%")->orWhere('u.phone', 'like', "%$q%")->orWhere('i.name', 'like', "%$q%")->orWhere('i.code', 'like', "$q%"));
        }
        return $qb;
    }

    public static function listForUser(int $userId, array $f, array $page): array
    {
        $pol = self::policies();
        $today = Dates::todayLocal();
        $qb = self::applyFilter(self::base()->where('b.user_id', $userId), ['status' => $f['status'] ?? null, 'domain' => $f['domain'] ?? null], $today)->orderBy('b.status')->orderBy('b.due_on');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($b) => self::serialize($b, $pol, false, $today), $res['items']), 'meta' => $res['meta']];
    }

    public static function getForUser(int $userId, int $id): array
    {
        $b = self::base()->where(['b.id' => $id, 'b.user_id' => $userId])->first();
        if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
        return self::serialize($b, self::policies());
    }

    public static function adminList(array $f, array $page): array
    {
        $pol = self::policies();
        $today = Dates::todayLocal();
        $qb = self::applyFilter(self::base(), $f, $today)->orderBy('b.due_on')->orderByDesc('b.id');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($b) => self::serialize($b, $pol, true, $today), $res['items']), 'meta' => $res['meta']];
    }

    public static function adminGet(int $id): array
    {
        $b = self::base()->where('b.id', $id)->first();
        if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
        return self::serialize($b, self::policies(), true);
    }

    // ------------------------------------------------------------------ issue
    private static function resolveDates(array $input, array $pol): array
    {
        $borrowedOn = ($input['borrowed_on'] ?? null) ?: Dates::todayLocal();
        $dueOn = ($input['due_on'] ?? null) ?: Dates::addDays($borrowedOn, (int) ($input['loan_days'] ?? $pol['reminders']['default_loan_days']));
        if ($dueOn < $borrowedOn) throw ApiError::field('due_on', 'DEADLINE_BEFORE_BORROW');
        return [$borrowedOn, $dueOn];
    }

    /** @param array<int,int> $needs item_id => quantity */
    private static function lockItems(array $needs): array
    {
        $items = DB::table('items')->whereIn('id', array_keys($needs))->whereNull('deleted_at')->lockForUpdate()->select('id', 'name', 'status', 'available_quantity', 'condition', 'kind', 'category', 'library_category_id')->get();
        $byId = [];
        foreach ($items as $i) $byId[$i->id] = $i;
        foreach ($needs as $itemId => $qty) {
            $it = $byId[$itemId] ?? null;
            if (! $it) throw ApiError::field('item_id', 'ITEM_NOT_FOUND');
            if (in_array($it->category ?? '', ['books', 'book', 'መጻሕፍት'], true) || ! empty($it->library_category_id)) {
                throw ApiError::conflict('ITEM_IS_BOOK', 'Physical books must be borrowed through the Library Circulation system.');
            }
            if (($it->kind ?? 'physical') === 'digital') throw ApiError::conflict('ITEM_IS_DIGITAL', 'Digital items cannot be borrowed');
            if ($it->status !== 'active') throw ApiError::conflict('ITEM_UNAVAILABLE', 'Item is not available', [['field' => 'item_id', 'code' => 'ITEM_UNAVAILABLE', 'message' => (string) $itemId]]);
            if ($it->available_quantity < $qty) throw ApiError::conflict('INSUFFICIENT_QUANTITY', 'Not enough items available', [['field' => 'quantity', 'code' => 'INSUFFICIENT_QUANTITY', 'message' => "$itemId:{$it->available_quantity}"]]);
        }
        return $byId;
    }

    private static function storeSignature(?string $dataUrl): ?array
    {
        if (! $dataUrl) return null;
        return Storage::save('signature', Storage::FOLDERS['SIGNATURES'], Storage::decodeDataUrl($dataUrl));
    }

    /** Direct-borrowing rules; returns whether approval is still needed. */
    private static function checkDirectRules(array $actx, array $userIds, array $lines, string $borrowedOn, string $dueOn): bool
    {
        $pol = Settings::directBorrowingPolicy();
        $items = DB::table('items')->whereIn('id', array_column($lines, 'item_id'))->whereNull('deleted_at')->select('id', 'name', 'direct_borrowable', 'max_quantity', 'max_days')->get();
        $byId = [];
        foreach ($items as $i) $byId[$i->id] = $i;
        $days = Dates::calendarDaysBetween($borrowedOn, $dueOn);
        foreach ($lines as $l) {
            $it = $byId[$l['item_id']] ?? null;
            if (! $it) throw ApiError::field('item_id', 'ITEM_NOT_FOUND');
            if (! $it->direct_borrowable) throw ApiError::conflict('ITEM_NOT_DIRECT_BORROWABLE', 'This item cannot be lent directly; use a department request', [['field' => 'item_id', 'code' => 'ITEM_NOT_DIRECT_BORROWABLE', 'message' => (string) $it->id]]);
            $maxQty = $it->max_quantity ?? $pol['max_quantity'];
            if ($maxQty && $l['quantity'] > $maxQty) throw ApiError::validation([['field' => 'quantity', 'code' => 'ABOVE_MAX_QUANTITY', 'message' => "ABOVE_MAX_QUANTITY:$maxQty"]]);
            $maxDays = $it->max_days ?? $pol['max_days'];
            if ($maxDays && $days > $maxDays) throw ApiError::validation([['field' => 'due_on', 'code' => 'ABOVE_MAX_DAYS', 'message' => "ABOVE_MAX_DAYS:$maxDays"]]);
        }
        $groups = DB::table('users')->whereIn('id', $userIds)->distinct()->pluck('member_group')->all();
        $notAllowed = array_values(array_filter($groups, fn ($g) => ! in_array($g, $pol['member_groups'], true)));
        if ($notAllowed) throw ApiError::conflict('MEMBER_NOT_ELIGIBLE', 'These members cannot borrow directly', [['field' => 'user_id', 'code' => 'MEMBER_NOT_ELIGIBLE', 'message' => implode(',', $notAllowed)]]);
        return $pol['approval_required'] && ! $actx['auth']->can('borrowing.approve');
    }

    /** Create borrowings for users × items in one transaction (all or nothing). */
    private static function issue(array $actx, array $userIds, array $lines, string $borrowedOn, string $dueOn, ?string $notes, array $signatures = [], ?string $batchNotes = null, bool $directRules = true): array
    {
        $savedSigs = [];
        try {
            foreach ($signatures as $uid => $dataUrl) {
                if ($dataUrl) $savedSigs[(int) $uid] = self::storeSignature($dataUrl);
            }
        } catch (\Throwable $e) {
            foreach ($savedSigs as $s) Storage::remove($s['path']);
            throw $e;
        }
        try {
            $result = DB::transaction(function () use ($actx, $userIds, $lines, $borrowedOn, $dueOn, $notes, $batchNotes, $savedSigs, $directRules) {
                $validUsers = MemberIds::membersAndAdmins(DB::table('users'))->whereIn('id', $userIds)->where('status', 'active')->whereNull('deleted_at')->pluck('id')->all();
                if (count($validUsers) !== count(array_unique($userIds))) throw ApiError::field('user_ids', 'USER_NOT_FOUND');
                $needs = [];
                foreach ($lines as $l) $needs[$l['item_id']] = ($needs[$l['item_id']] ?? 0) + $l['quantity'] * count($validUsers);
                // A library request that was approved is already the approval: no direct-borrowing rules.
                $pending = $directRules ? self::checkDirectRules($actx, $validUsers, $lines, $borrowedOn, $dueOn) : false;
                $items = self::lockItems($needs);
                $batchId = null;
                if (count($validUsers) * count($lines) > 1) {
                    $batchId = DB::table('borrowing_batches')->insertGetId(['created_by' => $actx['auth']->id, 'record_count' => count($validUsers) * count($lines), 'notes' => $batchNotes]);
                }
                $created = [];
                foreach ($validUsers as $uid) {
                    foreach ($lines as $l) {
                        // Prevent duplicate active borrowing for the same user and item
                        $activeLoan = DB::table('borrowings')
                            ->where(['user_id' => $uid, 'item_id' => $l['item_id']])
                            ->whereIn('status', ['pending_approval', 'active', 'partially_returned'])
                            ->lockForUpdate()
                            ->first();
                        if ($activeLoan) {
                            throw ApiError::conflict('ALREADY_BORROWED', "User $uid already has an active borrowing for item {$l['item_id']}");
                        }

                        $id = DB::table('borrowings')->insertGetId([
                            'user_id' => $uid, 'item_id' => $l['item_id'], 'batch_id' => $batchId, 'quantity' => $l['quantity'], 'borrowed_on' => $borrowedOn, 'due_on' => $dueOn,
                            'issue_condition' => ($l['issue_condition'] ?? null) ?: ($items[$l['item_id']]->condition ?? null),
                            'notes' => $notes, 'issued_by' => $actx['auth']->id, 'status' => $pending ? 'pending_approval' : 'active',
                            'approved_by' => $pending ? null : $actx['auth']->id, 'approved_at' => $pending ? null : DB::raw('NOW()'),
                        ]);
                        if (isset($savedSigs[$uid])) {
                            $sig = $savedSigs[$uid];
                            DB::table('borrowing_signatures')->insert(['borrowing_id' => $id, 'user_id' => $uid, 'signature_path' => $sig['path'], 'sha256' => $sig['sha256'], 'signed_at' => DB::raw('NOW()'), 'captured_by' => $actx['auth']->id]);
                        }
                        Activity::track($uid, Activity::BORROW, 'borrowing', $id, inTrx: true);
                        $created[] = ['id' => $id, 'user_id' => $uid, 'item_id' => $l['item_id'], 'quantity' => $l['quantity']];
                    }
                }
                if (! $pending) {
                    foreach ($needs as $itemId => $qty) DB::table('items')->where('id', $itemId)->decrement('available_quantity', $qty);
                }
                foreach ($created as $c) {
                    $name = $items[$c['item_id']]->name;
                    Notifications::createForUsers([$c['user_id']], [
                        'type' => 'borrowing',
                        'title' => T::t($pending ? 'borrowing.pending.title' : 'borrowing.created.title'),
                        'body' => $pending ? T::t('borrowing.pending.body', ['item' => $name]) : T::t('borrowing.created.body', ['item' => $name, 'quantity' => $c['quantity'], 'due' => $dueOn]),
                        'entityType' => 'borrowing',
                        'entityId' => $c['id'],
                        'email' => true,
                        'dedupeKey' => fn () => "borrow:{$c['id']}:created",
                    ]);
                }
                Audit::log($actx, $batchId ? Audit::BORROW_BULK : Audit::BORROW_CREATE, $batchId ? 'borrowing_batch' : 'borrowing', $batchId ?? ($created[0]['id'] ?? null), [
                    'records' => count($created), 'users' => count($validUsers), 'items' => $lines, 'due_on' => $dueOn, 'signed' => count($savedSigs), 'pending_approval' => $pending,
                ], inTrx: true);
                return ['batch_id' => $batchId, 'borrowings' => $created, 'pending_approval' => $pending];
            });
            Notifications::kick();
            return $result;
        } catch (\Throwable $e) {
            foreach ($savedSigs as $s) Storage::remove($s['path']);
            throw $e;
        }
    }

    public static function create(array $actx, array $input): array
    {
        [$borrowedOn, $dueOn] = self::resolveDates($input, self::policies());
        $res = self::issue($actx, [$input['user_id']], [['item_id' => $input['item_id'], 'quantity' => $input['quantity'] ?? 1, 'issue_condition' => $input['issue_condition'] ?? null]], $borrowedOn, $dueOn, $input['notes'] ?? null, ! empty($input['signature']) ? [$input['user_id'] => $input['signature']] : []);
        return self::adminGet($res['borrowings'][0]['id']);
    }

    /**
     * Hand over a requested library book: the borrowing starts now, signed by the member (the
     * signature is required), inside the caller's transaction-free flow. Returns the borrowing id.
     */
    public static function issueForRequest(array $actx, int $userId, int $itemId, int $quantity, array $input): int
    {
        [$borrowedOn, $dueOn] = self::resolveDates($input, self::policies());
        $res = self::issue($actx, [$userId], [['item_id' => $itemId, 'quantity' => $quantity]], $borrowedOn, $dueOn, $input['notes'] ?? null, [$userId => $input['signature']], null, false);
        return (int) $res['borrowings'][0]['id'];
    }

    public static function bulkCreate(array $actx, array $input): array
    {
        [$borrowedOn, $dueOn] = self::resolveDates($input, self::policies());
        $userIds = Targeting::resolve($input['target'], false);
        if (! $userIds) throw ApiError::field('target', 'NO_RECIPIENTS');
        if (count($userIds) > 500) throw ApiError::field('target', 'TOO_MANY');
        return self::issue($actx, $userIds, $input['items'], $borrowedOn, $dueOn, $input['notes'] ?? null, $input['signatures'] ?? [], $input['batch_notes'] ?? null);
    }

    public static function approve(array $actx, int $id): array
    {
        DB::transaction(function () use ($actx, $id) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            if ($b->status !== 'pending_approval') throw ApiError::conflict('NOT_PENDING', 'This borrowing is not waiting for approval');
            self::lockItems([$b->item_id => $b->quantity]);
            DB::table('items')->where('id', $b->item_id)->decrement('available_quantity', $b->quantity);
            DB::table('borrowings')->where('id', $id)->update(['status' => 'active', 'approved_by' => $actx['auth']->id, 'approved_at' => DB::raw('NOW()')]);
            $item = DB::table('items')->where('id', $b->item_id)->first(['name']);
            Notifications::createForUsers([$b->user_id], [
                'type' => 'borrowing',
                'title' => T::t('borrowing.created.title'),
                'body' => T::t('borrowing.created.body', ['item' => $item->name, 'quantity' => $b->quantity, 'due' => Dates::toDateOnly($b->due_on)]),
                'entityType' => 'borrowing',
                'entityId' => $id,
                'email' => true,
                'dedupeKey' => fn () => "borrow:$id:approved",
            ]);
            Audit::log($actx, Audit::BORROW_APPROVE, 'borrowing', $id, ['item_id' => $b->item_id, 'quantity' => $b->quantity], inTrx: true);
        });
        Notifications::kick();
        return self::adminGet($id);
    }

    public static function reject(array $actx, int $id, string $reason): array
    {
        DB::transaction(function () use ($actx, $id, $reason) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            if ($b->status !== 'pending_approval') throw ApiError::conflict('NOT_PENDING', 'This borrowing is not waiting for approval');
            DB::table('borrowings')->where('id', $id)->update(['status' => 'rejected', 'rejection_reason' => $reason, 'approved_by' => $actx['auth']->id, 'approved_at' => DB::raw('NOW()')]);
            $item = DB::table('items')->where('id', $b->item_id)->first(['name']);
            Notifications::createForUsers([$b->user_id], [
                'type' => 'borrowing',
                'title' => T::t('borrowing.rejected.title'),
                'body' => T::t('borrowing.rejected.body', ['item' => $item->name]),
                'entityType' => 'borrowing',
                'entityId' => $id,
                'email' => true,
                'dedupeKey' => fn () => "borrow:$id:rejected",
            ]);
            Audit::log($actx, Audit::BORROW_REJECT, 'borrowing', $id, ['reason' => $reason], inTrx: true);
        });
        Notifications::kick();
        return self::adminGet($id);
    }

    public static function renew(array $actx, int $id, string $dueOn, ?string $reason): array
    {
        DB::transaction(function () use ($actx, $id, $dueOn, $reason) {
            $b = DB::table('borrowings as b')->join('items as i', 'i.id', '=', 'b.item_id')->where('b.id', $id)->lockForUpdate()->first(['b.*', 'i.renewable', 'i.max_days']);
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            if (! in_array($b->status, self::OPEN, true)) throw ApiError::conflict('ALREADY_RETURNED', 'This borrowing is already closed');
            if (! $b->renewable) throw ApiError::conflict('NOT_RENEWABLE', 'This item cannot be renewed');
            $current = Dates::toDateOnly($b->due_on);
            if ($dueOn <= $current) throw ApiError::field('due_on', 'DUE_NOT_LATER');
            $maxDays = $b->max_days ?? Settings::directBorrowingPolicy()['max_days'];
            if ($maxDays && Dates::calendarDaysBetween($current, $dueOn) > $maxDays) throw ApiError::validation([['field' => 'due_on', 'code' => 'ABOVE_MAX_DAYS', 'message' => "ABOVE_MAX_DAYS:$maxDays"]]);
            DB::table('borrowings')->where('id', $id)->update(['due_on' => $dueOn, 'renewals' => $b->renewals + 1]);
            Audit::log($actx, Audit::BORROW_RENEW, 'borrowing', $id, ['from' => $current, 'to' => $dueOn, 'reason' => $reason], inTrx: true);
        });
        return self::adminGet($id);
    }

    public static function addSignature(array $actx, int $id, string $dataUrl): array
    {
        $b = DB::table('borrowings')->where('id', $id)->first(['id', 'user_id']);
        if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
        if (DB::table('borrowing_signatures')->where('borrowing_id', $id)->exists()) throw ApiError::conflict('SIGNATURE_EXISTS', 'This borrowing is already signed');
        $sig = self::storeSignature($dataUrl);
        try {
            DB::transaction(function () use ($actx, $id, $b, $sig) {
                DB::table('borrowing_signatures')->insert(['borrowing_id' => $id, 'user_id' => $b->user_id, 'signature_path' => $sig['path'], 'sha256' => $sig['sha256'], 'signed_at' => DB::raw('NOW()'), 'captured_by' => $actx['auth']->id]);
                Audit::log($actx, Audit::BORROW_SIGNATURE, 'borrowing', $id, ['sha256' => $sig['sha256']], inTrx: true);
            });
        } catch (\Throwable $e) {
            Storage::remove($sig['path']);
            throw $e;
        }
        return self::adminGet($id);
    }

    /** Signature image: the borrower and admins with borrowing.manage. */
    public static function signatureFile(AuthContext $auth, int $id): string
    {
        $s = DB::table('borrowing_signatures')->where('borrowing_id', $id)->first();
        if (! $s) throw ApiError::notFound();
        $allowed = (int) $s->user_id === $auth->id || ($auth->isAdmin && $auth->can('borrowing.manage'));
        if (! $allowed) throw ApiError::notFound();
        $abs = Storage::privatePath($s->signature_path);
        if (! is_file($abs)) throw ApiError::notFound();
        return $abs;
    }

    // ------------------------------------------------------------------ return
    public static function returnItem(array $actx, int $id, array $input): array
    {
        $pol = self::policies();
        $notify = 0;
        DB::transaction(function () use ($actx, $id, $input, $pol, &$notify) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            if (! in_array($b->status, self::OPEN, true)) throw ApiError::conflict('ALREADY_RETURNED', 'This borrowing is already closed');
            $returnedOn = ($input['returned_on'] ?? null) ?: Dates::todayLocal();
            if ($returnedOn < Dates::toDateOnly($b->borrowed_on)) throw ApiError::field('returned_on', 'RETURN_BEFORE_BORROW');
            $outstanding = $b->quantity - $b->returned_quantity;
            $qty = $input['returned_quantity'] ?? $outstanding;
            if ($qty < 1 || $qty > $outstanding) throw ApiError::field('returned_quantity', 'INVALID_RETURN_QUANTITY');
            $condition = DB::table('return_conditions')->where(['label' => $input['return_condition'], 'is_active' => true])->first();
            if (! $condition) throw ApiError::field('return_condition', 'INVALID_CONDITION');
            $totalReturned = $b->returned_quantity + $qty;
            $closed = $totalReturned === (int) $b->quantity;
            $status = $condition->marks_lost && $closed ? 'lost' : ($closed ? 'returned' : 'partially_returned');
            $patch = ['status' => $status, 'returned_quantity' => $totalReturned, 'returned_on' => $returnedOn, 'return_condition' => $condition->label, 'return_notes' => $input['return_notes'] ?? null, 'returned_to' => $actx['auth']->id];
            $due = Dates::toDateOnly($b->due_on);
            if (isset($input['fine_amount']) && $input['fine_amount'] !== null) {
                if (! $actx['auth']->can('fines.manage')) throw ApiError::forbidden();
                $computed = Fines::compute($due, $returnedOn, $pol['fines']);
                $overridden = (float) $input['fine_amount'] !== (float) $computed;
                $patch += ['fine_amount' => $input['fine_amount'], 'fine_overridden' => $overridden, 'fine_override_reason' => $input['fine_override_reason'] ?? null, 'fine_overridden_by' => $overridden ? $actx['auth']->id : null];
                if ($overridden) {
                    Audit::log($actx, Audit::FINE_OVERRIDE, 'borrowing', $id, ['from' => $computed, 'to' => $input['fine_amount'], 'reason' => $input['fine_override_reason'] ?? null], inTrx: true);
                }
            } elseif (! $b->fine_overridden) {
                $patch['fine_amount'] = Fines::compute($due, $returnedOn, $pol['fines']);
            }
            $fineAmount = Num::n($patch['fine_amount'] ?? $b->fine_amount);
            $patch['fine_status'] = $input['fine_status'] ?? ($fineAmount > 0 ? ($b->fine_status === 'paid' ? 'paid' : 'pending') : 'none');
            if (in_array($input['fine_status'] ?? null, ['paid', 'waived'], true) && ! $actx['auth']->can('fines.manage')) throw ApiError::forbidden();
            DB::table('borrowings')->where('id', $id)->update($patch);
            if ($condition->restock && ! $condition->marks_lost) {
                DB::table('items')->where('id', $b->item_id)->increment('available_quantity', $qty);
            } else {
                DB::table('items')->where('id', $b->item_id)->decrement('quantity', $qty);
            }
            Activity::track($b->user_id, Activity::RETURN, 'borrowing', $id, ['quantity' => $qty, 'condition' => $condition->label], inTrx: true);
            Audit::log($actx, Audit::BORROW_RETURN, 'borrowing', $id, ['quantity' => $qty, 'condition' => $condition->label, 'status' => $status, 'fine' => $fineAmount], inTrx: true);
            $item = DB::table('items')->where('id', $b->item_id)->first(['name']);
            $notify = Notifications::createForUsers([$b->user_id], [
                'type' => 'borrowing',
                'title' => T::t('borrowing.returned.title'),
                'body' => T::t('borrowing.returned.body', ['item' => $item->name]),
                'entityType' => 'borrowing',
                'entityId' => $id,
                'email' => true,
                'dedupeKey' => fn () => "borrow:$id:returned:$totalReturned",
            ]);
        });
        if ($notify) Notifications::kick();
        return self::adminGet($id);
    }

    // ------------------------------------------------------------------ fines
    public static function overrideFine(array $actx, int $id, float|int $amount, string $reason): array
    {
        DB::transaction(function () use ($actx, $id, $amount, $reason) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            DB::table('borrowings')->where('id', $id)->update(['fine_amount' => $amount, 'fine_overridden' => true, 'fine_override_reason' => $reason, 'fine_overridden_by' => $actx['auth']->id, 'fine_status' => $amount > 0 ? ($b->fine_status === 'none' ? 'pending' : $b->fine_status) : 'none']);
            Audit::log($actx, Audit::FINE_OVERRIDE, 'borrowing', $id, ['from' => Num::n($b->fine_amount), 'to' => $amount, 'reason' => $reason], inTrx: true);
        });
        return self::adminGet($id);
    }

    public static function clearFineOverride(array $actx, int $id): array
    {
        DB::transaction(function () use ($actx, $id) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            $pol = self::policies();
            $asOf = in_array($b->status, self::OPEN, true) ? Dates::todayLocal() : Dates::toDateOnly($b->returned_on);
            $amount = Fines::compute(Dates::toDateOnly($b->due_on), $asOf, $pol['fines']);
            DB::table('borrowings')->where('id', $id)->update(['fine_amount' => $amount, 'fine_overridden' => false, 'fine_override_reason' => null, 'fine_overridden_by' => null, 'fine_status' => $amount > 0 ? 'pending' : 'none']);
            Audit::log($actx, Audit::FINE_OVERRIDE, 'borrowing', $id, ['from' => Num::n($b->fine_amount), 'to' => $amount, 'cleared' => true], inTrx: true);
        });
        return self::adminGet($id);
    }

    public static function setFineStatus(array $actx, int $id, string $status): array
    {
        DB::transaction(function () use ($actx, $id, $status) {
            $b = DB::table('borrowings')->where('id', $id)->lockForUpdate()->first();
            if (! $b) throw ApiError::notFound('BORROWING_NOT_FOUND', 'Borrowing not found');
            DB::table('borrowings')->where('id', $id)->update(['fine_status' => $status]);
            Audit::log($actx, Audit::FINE_STATUS, 'borrowing', $id, ['from' => $b->fine_status, 'to' => $status, 'amount' => Num::n($b->fine_amount)], inTrx: true);
        });
        return self::adminGet($id);
    }

    /** Scheduled: persist today's computed fine on open overdue borrowings. */
    public static function recalculateOpenFines(?string $today = null): array
    {
        $today ??= Dates::todayLocal();
        $pol = self::policies();
        $rows = DB::table('borrowings')->whereIn('status', self::OPEN)->where('fine_overridden', false)->where('due_on', '<', $today)->select('id', 'due_on', 'fine_amount', 'fine_status')->get();
        $changed = 0;
        foreach ($rows as $b) {
            $amount = Fines::compute(Dates::toDateOnly($b->due_on), $today, $pol['fines']);
            if ((float) $amount !== (float) $b->fine_amount) {
                DB::table('borrowings')->where('id', $b->id)->update(['fine_amount' => $amount, 'fine_status' => $amount > 0 ? ($b->fine_status === 'none' ? 'pending' : $b->fine_status) : 'none']);
                $changed++;
            }
        }
        return ['checked' => $rows->count(), 'changed' => $changed];
    }

    public static function fineSummary(): object
    {
        $out = [];
        foreach (DB::table('borrowings')->where('fine_amount', '>', 0)->groupBy('fine_status')->selectRaw('fine_status, SUM(fine_amount) as total, COUNT(*) as n')->get() as $r) {
            $out[$r->fine_status] = ['count' => (int) $r->n, 'total' => Num::n($r->total)];
        }
        return (object) $out;
    }

    // ------------------------------------------------------------------ return conditions
    public static function listConditions(bool $includeInactive = false): array
    {
        $q = DB::table('return_conditions')->orderBy('display_order');
        if (! $includeInactive) $q->where('is_active', true);
        return $q->get()->all();
    }

    public static function upsertCondition(array $actx, ?int $id, array $input): ?object
    {
        $row = array_intersect_key($input, array_flip(['label', 'marks_lost', 'restock', 'display_order', 'is_active']));
        $outId = $id;
        DB::transaction(function () use ($actx, $id, $row, &$outId) {
            if ($id) {
                if (! DB::table('return_conditions')->where('id', $id)->exists()) throw ApiError::notFound();
                if ($row) DB::table('return_conditions')->where('id', $id)->update($row);
            } else {
                $outId = DB::table('return_conditions')->insertGetId($row);
            }
            Audit::log($actx, Audit::RETURN_CONDITIONS, 'return_condition', $outId, (object) $row, inTrx: true);
        });
        return DB::table('return_conditions')->where('id', $outId)->first();
    }
}
