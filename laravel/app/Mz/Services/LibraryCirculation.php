<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

/**
 * Physical Sunday-school library circulation (F17).
 *
 * Departmental books have stable per-copy IDs (copy_code: LIB-{cat}-{book}-{copy}).
 * Checkout and return are handled by library staff with borrower signatures,
 * completely segregated from property borrowings.
 */
final class LibraryCirculation
{
    public const CONDITIONS = ['good', 'fair', 'poor', 'damaged'];
    public const STATUSES = ['available', 'on_loan', 'lost', 'withdrawn'];
    public const LOAN_STATUSES = ['active', 'returned', 'overdue', 'lost'];

    // ------------------------------------------------------------------ Serializers
    public static function serializeCopy(object|array $c): array
    {
        $c = (object) $c;
        return [
            'id' => (int) $c->id,
            'item_id' => (int) $c->item_id,
            'book_title' => $c->book_title ?? $c->item_name ?? null,
            'book_author' => $c->book_author ?? $c->item_author ?? null,
            'book_code' => $c->book_code ?? $c->item_code ?? null,
            'category_name' => $c->category_name ?? null,
            'copy_no' => (int) $c->copy_no,
            'copy_code' => $c->copy_code,
            'condition' => $c->condition,
            'location' => $c->location,
            'status' => $c->status,
            'current_loan' => ! empty($c->loan_id) ? [
                'id' => (int) $c->loan_id,
                'user_id' => (int) $c->loan_user_id,
                'borrower_name' => $c->loan_user_name,
                'member_id' => MemberIds::format($c->loan_member_no ?? null, $c->loan_member_group ?? null),
                'checked_out_at' => $c->loan_checked_out_at,
                'due_on' => Dates::toDateOnly($c->loan_due_on),
            ] : null,
            'created_at' => $c->created_at,
        ];
    }

    public static function serializeLoan(object|array $l): array
    {
        $l = (object) $l;
        return [
            'id' => (int) $l->id,
            'copy_id' => (int) $l->copy_id,
            'copy_code' => $l->copy_code,
            'book_id' => (int) ($l->item_id ?? 0),
            'book_title' => $l->book_title ?? $l->item_name ?? null,
            'book_author' => $l->book_author ?? null,
            'user_id' => (int) $l->user_id,
            'borrower_name' => $l->user_name,
            'borrower_phone' => $l->user_phone ?? null,
            'member_id' => MemberIds::format($l->member_no ?? null, $l->member_group ?? null),
            'checked_out_at' => $l->checked_out_at,
            'due_on' => Dates::toDateOnly($l->due_on),
            'returned_at' => $l->returned_at,
            'condition_out' => $l->condition_out,
            'condition_in' => $l->condition_in,
            'issued_by' => (int) $l->issued_by,
            'issuer_name' => $l->issuer_name ?? null,
            'received_by' => $l->received_by ? (int) $l->received_by : null,
            'receiver_name' => $l->receiver_name ?? null,
            'signature_url' => ! empty($l->signature_path) ? "/library/circulation/loans/{$l->id}/signature" : null,
            'notes' => $l->notes,
            'status' => $l->status,
            'created_at' => $l->created_at,
        ];
    }

    // ------------------------------------------------------------------ Query builders
    private static function copyQuery()
    {
        $table = \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
        return DB::table('library_copies as c')
            ->join("{$table} as i", 'i.id', '=', 'c.item_id')
            ->leftJoin('library_categories as cat', 'cat.id', '=', 'i.library_category_id')
            ->leftJoin('library_loans as l', fn ($j) => $j->on('l.copy_id', '=', 'c.id')->where('l.status', 'active'))
            ->leftJoin('users as lu', 'lu.id', '=', 'l.user_id')
            ->select(
                'c.*',
                'i.name as book_title',
                'i.author as book_author',
                'i.code as book_code',
                'cat.name as category_name',
                'l.id as loan_id',
                'l.user_id as loan_user_id',
                'l.checked_out_at as loan_checked_out_at',
                'l.due_on as loan_due_on',
                'lu.full_name as loan_user_name',
                'lu.member_no as loan_member_no',
                'lu.member_group as loan_member_group'
            );
    }

    private static function loanQuery()
    {
        $table = \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
        return DB::table('library_loans as l')
            ->join('library_copies as c', 'c.id', '=', 'l.copy_id')
            ->join("{$table} as i", 'i.id', '=', 'c.item_id')
            ->join('users as u', 'u.id', '=', 'l.user_id')
            ->leftJoin('users as iu', 'iu.id', '=', 'l.issued_by')
            ->leftJoin('users as ru', 'ru.id', '=', 'l.received_by')
            ->select(
                'l.*',
                'c.copy_code',
                'c.item_id',
                'i.name as book_title',
                'i.author as book_author',
                'u.full_name as user_name',
                'u.phone as user_phone',
                'u.member_no as member_no',
                'u.member_group as member_group',
                'iu.full_name as issuer_name',
                'ru.full_name as receiver_name'
            );
    }

    // ------------------------------------------------------------------ Inventory & Copies
    public static function copies(array $f, array $page): array
    {
        $qb = self::copyQuery()->orderBy('c.copy_code');
        if (! empty($f['item_id'])) $qb->where('c.item_id', (int) $f['item_id']);
        if (! empty($f['status'])) $qb->where('c.status', $f['status']);
        if (! empty($f['condition'])) $qb->where('c.condition', $f['condition']);
        if (! empty($f['domain'])) $qb->where('i.domain', $f['domain']);
        if (! empty($f['q'])) {
            $q = trim((string) $f['q']);
            $qb->where(fn ($w) => $w->where('c.copy_code', 'like', "{$q}%")
                ->orWhere('i.name', 'like', "%{$q}%")
                ->orWhere('i.author', 'like', "%{$q}%"));
        }
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => self::serializeCopy($r), $res['items']);
        return $res;
    }

    public static function findCopyByCode(string $code): ?array
    {
        $c = self::copyQuery()->where('c.copy_code', trim($code))->first();
        return $c ? self::serializeCopy($c) : null;
    }

    public static function addCopy(array $actx, int $itemId, array $data): array
    {
        $book = DB::table('items')->where(['id' => $itemId, 'status' => 'active', 'kind' => 'physical'])->whereNull('deleted_at')->first();
        if (! $book) throw ApiError::notFound('BOOK_NOT_FOUND', 'Physical book not found');

        $maxCopyNo = (int) DB::table('library_copies')->where('item_id', $itemId)->max('copy_no');
        $copyNo = $maxCopyNo + 1;

        $catCode = 'GEN';
        if ($book->library_category_id) {
            $catCode = DB::table('library_categories')->where('id', $book->library_category_id)->value('code') ?: 'GEN';
        }

        $copyCode = sprintf('LIB-%s-%04d-%02d', $catCode, $book->id, $copyNo);

        $id = DB::table('library_copies')->insertGetId([
            'item_id' => $itemId,
            'copy_no' => $copyNo,
            'copy_code' => $copyCode,
            'condition' => in_array($data['condition'] ?? 'good', self::CONDITIONS, true) ? $data['condition'] : 'good',
            'location' => ! empty($data['location']) ? mb_substr(trim($data['location']), 0, 100) : null,
            'status' => 'available',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('items')->where('id', $itemId)->increment('quantity');
        DB::table('items')->where('id', $itemId)->increment('available_quantity');

        Audit::log($actx, 'library.copy_create', 'library_copy', $id, ['copy_code' => $copyCode, 'item_id' => $itemId]);

        return self::serializeCopy(self::copyQuery()->where('c.id', $id)->first());
    }

    public static function updateCopy(array $actx, int $id, array $data): array
    {
        $copy = DB::table('library_copies')->where('id', $id)->first();
        if (! $copy) throw ApiError::notFound('COPY_NOT_FOUND', 'Copy not found');

        $up = [
            'updated_at' => now(),
        ];
        if (array_key_exists('condition', $data)) {
            if (! in_array($data['condition'], self::CONDITIONS, true)) {
                throw ApiError::field('condition', 'INVALID_CONDITION');
            }
            $up['condition'] = $data['condition'];
        }
        if (array_key_exists('location', $data)) {
            $up['location'] = ! empty($data['location']) ? mb_substr(trim((string) $data['location']), 0, 100) : null;
        }
        if (array_key_exists('status', $data)) {
            if (! in_array($data['status'], self::STATUSES, true)) {
                throw ApiError::field('status', 'INVALID_STATUS');
            }
            $oldStatus = $copy->status;
            $newStatus = $data['status'];
            $up['status'] = $newStatus;
            if ($oldStatus === 'available' && $newStatus !== 'available') {
                DB::table('items')->where('id', $copy->item_id)->where('available_quantity', '>', 0)->decrement('available_quantity');
            } elseif ($oldStatus !== 'available' && $newStatus === 'available') {
                DB::table('items')->where('id', $copy->item_id)->increment('available_quantity');
            }
        }

        DB::table('library_copies')->where('id', $id)->update($up);
        Audit::log($actx, 'library.copy_update', 'library_copy', $id, $up);

        return self::serializeCopy(self::copyQuery()->where('c.id', $id)->first());
    }

    public static function deleteCopy(array $actx, int $id): array
    {
        $copy = DB::table('library_copies')->where('id', $id)->first();
        if (! $copy) throw ApiError::notFound('COPY_NOT_FOUND', 'Copy not found');

        $activeLoan = DB::table('library_loans')->where(['copy_id' => $id, 'status' => 'active'])->exists();
        if ($activeLoan) {
            throw ApiError::conflict('COPY_ON_LOAN', 'Cannot delete copy while currently on loan');
        }

        DB::transaction(function () use ($copy, $id, $actx) {
            DB::table('library_copies')->where('id', $id)->delete();
            $bookTable = \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
            DB::table($bookTable)->where('id', $copy->item_id)->where('quantity', '>', 0)->decrement('quantity');
            if ($copy->status === 'available') {
                DB::table($bookTable)->where('id', $copy->item_id)->where('available_quantity', '>', 0)->decrement('available_quantity');
            }
            if ($bookTable !== 'items' && \Illuminate\Support\Facades\Schema::hasTable('items')) {
                DB::table('items')->where('id', $copy->item_id)->where('quantity', '>', 0)->decrement('quantity');
                if ($copy->status === 'available') {
                    DB::table('items')->where('id', $copy->item_id)->where('available_quantity', '>', 0)->decrement('available_quantity');
                }
            }
            Audit::log($actx, 'library.copy_delete', 'library_copy', $id, ['copy_code' => $copy->copy_code]);
        });

        return ['id' => $id, 'deleted' => true];
    }

    // ------------------------------------------------------------------ Circulation Actions
    public static function checkout(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        $copyCode = trim((string) ($in['copy_code'] ?? ''));
        $copyId = ! empty($in['copy_id']) ? (int) $in['copy_id'] : null;
        $userId = (int) ($in['user_id'] ?? 0);
        $dueOn = trim((string) ($in['due_on'] ?? ''));
        $conditionOut = (! empty($in['condition_out']) && in_array($in['condition_out'], self::CONDITIONS, true)) ? $in['condition_out'] : 'good';
        $signatureData = $in['signature'] ?? null;
        $notes = ! empty($in['notes']) ? mb_substr(trim((string) $in['notes']), 0, 500) : null;

        if (! $userId || ! DB::table('users')->where('id', $userId)->whereNull('deleted_at')->exists()) {
            throw ApiError::field('user_id', 'USER_NOT_FOUND', 'Member not found');
        }

        if (empty($dueOn) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/', $dueOn)) {
            throw ApiError::field('due_on', 'INVALID_DATE', 'Due date required (YYYY-MM-DD)');
        }

        if (empty($signatureData)) {
            throw ApiError::field('signature', 'SIGNATURE_REQUIRED', 'Borrower signature required');
        }

        // Store signature
        $sig = Storage::save('signature', Storage::FOLDERS['SIGNATURES'], Storage::decodeDataUrl($signatureData));

        return DB::transaction(function () use ($actx, $auth, $copyCode, $copyId, $userId, $dueOn, $conditionOut, $sig, $notes) {
            $copyQuery = DB::table('library_copies')->lockForUpdate();
            if ($copyId) {
                $copyQuery->where('id', $copyId);
            } else {
                $copyQuery->where('copy_code', $copyCode);
            }
            $copy = $copyQuery->first();

            if (! $copy) {
                throw ApiError::notFound('COPY_NOT_FOUND', 'Library copy not found');
            }

            if ($copy->status !== 'available') {
                throw ApiError::conflict('COPY_ON_LOAN', 'This copy is already checked out or unavailable');
            }

            // Verify no open loan exists for this copy
            $openLoanExists = DB::table('library_loans')->where(['copy_id' => $copy->id, 'status' => 'active'])->exists();
            if ($openLoanExists) {
                throw ApiError::conflict('COPY_ON_LOAN', 'An active loan already exists for this copy');
            }

            // Verify no open loan exists for this user on this book title
            $userHasBook = DB::table('library_loans as l')
                ->join('library_copies as c', 'c.id', '=', 'l.copy_id')
                ->where(['l.user_id' => $userId, 'c.item_id' => $copy->item_id, 'l.status' => 'active'])
                ->exists();
            if ($userHasBook) {
                throw ApiError::conflict('ALREADY_BORROWED', 'This user already has an active loan for this book');
            }

            $loanId = DB::table('library_loans')->insertGetId([
                'copy_id' => $copy->id,
                'user_id' => $userId,
                'checked_out_at' => now(),
                'due_on' => $dueOn,
                'condition_out' => $conditionOut,
                'issued_by' => $auth->id,
                'signature_path' => $sig['path'],
                'sha256' => $sig['sha256'],
                'notes' => $notes,
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('library_copies')->where('id', $copy->id)->update([
                'status' => 'on_loan',
                'updated_at' => now(),
            ]);

            $bookTable = \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
            DB::table($bookTable)->where('id', $copy->item_id)->where('available_quantity', '>', 0)->decrement('available_quantity');
            if ($bookTable !== 'items' && \Illuminate\Support\Facades\Schema::hasTable('items')) {
                DB::table('items')->where('id', $copy->item_id)->where('available_quantity', '>', 0)->decrement('available_quantity');
            }

            Audit::log($actx, 'library.checkout', 'library_loan', $loanId, [
                'copy_id' => $copy->id,
                'copy_code' => $copy->copy_code,
                'user_id' => $userId,
                'due_on' => $dueOn,
            ], inTrx: true);

            return self::serializeLoan(self::loanQuery()->where('l.id', $loanId)->first());
        });
    }

    public static function returnCopy(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        $loanId = ! empty($in['loan_id']) ? (int) $in['loan_id'] : null;
        $copyCode = trim((string) ($in['copy_code'] ?? ''));
        $conditionIn = (! empty($in['condition_in']) && in_array($in['condition_in'], self::CONDITIONS, true)) ? $in['condition_in'] : 'good';
        $notes = ! empty($in['notes']) ? mb_substr(trim((string) $in['notes']), 0, 500) : null;

        return DB::transaction(function () use ($actx, $auth, $loanId, $copyCode, $conditionIn, $notes) {
            $lq = DB::table('library_loans as l')
                ->join('library_copies as c', 'c.id', '=', 'l.copy_id')
                ->lockForUpdate()
                ->select('l.*', 'c.item_id', 'c.copy_code');

            if ($loanId) {
                $lq->where('l.id', $loanId);
            } else {
                $lq->where('c.copy_code', $copyCode)->where('l.status', 'active');
            }

            $loan = $lq->first();
            if (! $loan) {
                throw ApiError::notFound('LOAN_NOT_FOUND', 'Active loan not found for this book');
            }

            if ($loan->status === 'returned') {
                throw ApiError::conflict('ALREADY_RETURNED', 'This loan is already returned');
            }

            DB::table('library_loans')->where('id', $loan->id)->update([
                'status' => 'returned',
                'returned_at' => now(),
                'condition_in' => $conditionIn,
                'received_by' => $auth->id,
                'notes' => $notes ?: $loan->notes,
                'updated_at' => now(),
            ]);

            $newCopyStatus = ($conditionIn === 'damaged') ? 'withdrawn' : 'available';
            DB::table('library_copies')->where('id', $loan->copy_id)->update([
                'status' => $newCopyStatus,
                'condition' => $conditionIn,
                'updated_at' => now(),
            ]);

            $bookTable = \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
            if ($newCopyStatus === 'available') {
                DB::table($bookTable)->where('id', $loan->item_id)->increment('available_quantity');
                if ($bookTable !== 'items' && \Illuminate\Support\Facades\Schema::hasTable('items')) {
                    DB::table('items')->where('id', $loan->item_id)->increment('available_quantity');
                }
            } else {
                DB::table($bookTable)->where('id', $loan->item_id)->where('quantity', '>', 0)->decrement('quantity');
                if ($bookTable !== 'items' && \Illuminate\Support\Facades\Schema::hasTable('items')) {
                    DB::table('items')->where('id', $loan->item_id)->where('quantity', '>', 0)->decrement('quantity');
                }
            }

            Audit::log($actx, 'library.return', 'library_loan', $loan->id, [
                'copy_id' => $loan->copy_id,
                'condition_in' => $conditionIn,
            ], inTrx: true);

            return self::serializeLoan(self::loanQuery()->where('l.id', $loan->id)->first());
        });
    }

    public static function loans(array $f, array $page): array
    {
        $qb = self::loanQuery()->orderByDesc('l.id');
        if (! empty($f['status'])) $qb->where('l.status', $f['status']);
        if (! empty($f['user_id'])) $qb->where('l.user_id', (int) $f['user_id']);
        if (! empty($f['copy_id'])) $qb->where('l.copy_id', (int) $f['copy_id']);
        if (! empty($f['item_id'])) $qb->where('c.item_id', (int) $f['item_id']);
        if (! empty($f['q'])) {
            $q = trim((string) $f['q']);
            $qb->where(fn ($w) => $w->where('c.copy_code', 'like', "{$q}%")
                ->orWhere('i.name', 'like', "%{$q}%")
                ->orWhere('u.full_name', 'like', "%{$q}%")
                ->orWhere('u.phone', 'like', "%{$q}%"));
        }
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => self::serializeLoan($r), $res['items']);
        return $res;
    }

    public static function overdue(array $page): array
    {
        $today = date('Y-m-d');
        $qb = self::loanQuery()
            ->where(fn ($w) => $w->where('l.status', 'overdue')->orWhere(fn ($q) => $q->where('l.status', 'active')->where('l.due_on', '<', $today)))
            ->orderBy('l.due_on');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => self::serializeLoan($r), $res['items']);
        return $res;
    }

    public static function copyHistory(int $copyId): array
    {
        $copy = DB::table('library_copies')->where('id', $copyId)->first();
        if (! $copy) throw ApiError::notFound('COPY_NOT_FOUND', 'Copy not found');

        $loans = self::loanQuery()->where('l.copy_id', $copyId)->orderByDesc('l.id')->get();
        return [
            'copy' => self::serializeCopy(self::copyQuery()->where('c.id', $copyId)->first()),
            'loans' => array_map(fn ($l) => self::serializeLoan($l), $loans->all()),
        ];
    }

    public static function userHistory(int $userId): array
    {
        $loans = self::loanQuery()->where('l.user_id', $userId)->orderByDesc('l.id')->get();
        return array_map(fn ($l) => self::serializeLoan($l), $loans->all());
    }

    // ------------------------------------------------------------------ Sync Conflicts
    public static function recordConflict(array $data): int
    {
        return DB::table('library_sync_conflicts')->insertGetId([
            'kind' => $data['kind'],
            'code' => $data['code'],
            'copy_code' => $data['copy_code'],
            'copy_id' => $data['copy_id'] ?? null,
            'user_id' => $data['user_id'] ?? null,
            'submitted_by' => $data['submitted_by'],
            'client_event_id' => $data['client_event_id'] ?? null,
            'payload' => json_encode($data['payload'] ?? [], JSON_UNESCAPED_UNICODE),
            'status' => 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public static function conflicts(array $f, array $page): array
    {
        $qb = DB::table('library_sync_conflicts as sc')
            ->leftJoin('users as su', 'su.id', '=', 'sc.submitted_by')
            ->leftJoin('users as u', 'u.id', '=', 'sc.user_id')
            ->select('sc.*', 'su.full_name as submitter_name', 'u.full_name as borrower_name')
            ->orderByDesc('sc.id');

        if (! empty($f['status'])) $qb->where('sc.status', $f['status']);
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => [
            'id' => (int) $r->id,
            'kind' => $r->kind,
            'code' => $r->code,
            'copy_code' => $r->copy_code,
            'copy_id' => $r->copy_id ? (int) $r->copy_id : null,
            'user_id' => $r->user_id ? (int) $r->user_id : null,
            'borrower_name' => $r->borrower_name,
            'submitted_by' => (int) $r->submitted_by,
            'submitter_name' => $r->submitter_name,
            'client_event_id' => $r->client_event_id,
            'payload' => json_decode($r->payload, true) ?: [],
            'status' => $r->status,
            'resolution_note' => $r->resolution_note,
            'resolved_at' => $r->resolved_at,
            'created_at' => $r->created_at,
        ], $res['items']);
        return $res;
    }

    public static function resolveConflict(array $actx, int $id, string $status, ?string $note): array
    {
        $c = DB::table('library_sync_conflicts')->where('id', $id)->first();
        if (! $c) throw ApiError::notFound('CONFLICT_NOT_FOUND', 'Conflict record not found');

        DB::table('library_sync_conflicts')->where('id', $id)->update([
            'status' => in_array($status, ['resolved', 'dismissed'], true) ? $status : 'resolved',
            'resolution_note' => $note,
            'resolved_by' => $actx['auth']->id,
            'resolved_at' => now(),
            'updated_at' => now(),
        ]);

        Audit::log($actx, 'library.conflict_resolve', 'library_sync_conflict', $id, ['status' => $status, 'note' => $note]);
        return ['id' => $id, 'status' => $status, 'resolved' => true];
    }
}
