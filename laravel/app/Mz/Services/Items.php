<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Sunday School property — books and every other kind (equipment, electronics, furniture,
 * instruments, office materials, department resources…) in one inventory (port of itemService.js).
 * Categories are configurable (item_categories). An item code left empty is generated from the
 * responsible department and the category, e.g. FIN-EQ-0004; codes stay unique.
 */
final class Items
{
    private const FIELDS = ['name', 'author', 'kind', 'code', 'category', 'description', 'condition', 'status', 'location', 'notes', 'domain', 'department_id', 'direct_borrowable', 'max_quantity', 'max_days', 'renewable', 'library_category_id', 'subtitle', 'publisher', 'publication_year', 'language'];

    public static function serialize(object $i): array
    {
        return [
            'id' => $i->id,
            'name' => $i->name,
            'subtitle' => $i->subtitle ?? null,
            'author' => $i->author ?? null,
            'publisher' => $i->publisher ?? null,
            'publication_year' => $i->publication_year !== null ? (int) $i->publication_year : null,
            'language' => $i->language ?? 'am',
            // physical book / item, or digital book (PDF)
            'kind' => $i->kind ?? 'physical',
            'code' => $i->code,
            'has_file' => ! empty($i->file_path),
            'file_size' => isset($i->file_size) ? (int) $i->file_size : null,
            'file_url' => ! empty($i->file_path) ? url("/api/v1/library/books/{$i->id}/file") : null,
            'stream_url' => ! empty($i->file_path) ? url("/api/v1/library/books/{$i->id}/file") : null,
            'downloads' => (int) ($i->downloads ?? 0),
            'category' => $i->category,
            'category_name' => $i->category_name ?? $i->category,
            'category_name_en' => $i->category_name_en ?? null,
            'library_category_id' => ! empty($i->library_category_id) ? (int) $i->library_category_id : null,
            'domain' => $i->domain ?? 'mezmur',
            'description' => $i->description,
            'quantity' => $i->quantity,
            'available_quantity' => $i->available_quantity,
            'borrowed_quantity' => $i->quantity - $i->available_quantity,
            'condition' => $i->condition,
            'status' => $i->status,
            'image_url' => Storage::url($i->image),
            'location' => $i->location,
            'notes' => $i->notes,
            'department_id' => $i->department_id ?? null,
            'department_name' => $i->department_name ?? null,
            'department_name_en' => $i->department_name_en ?? null,
            'direct_borrowable' => (bool) $i->direct_borrowable,
            'max_quantity' => $i->max_quantity ?? null,
            'max_days' => $i->max_days ?? null,
            'renewable' => (bool) $i->renewable,
            'created_at' => $i->created_at,
            'updated_at' => $i->updated_at,
        ];
    }

    private static function withDepartment()
    {
        return DB::table('items')->leftJoin('departments as dep', 'dep.id', '=', 'items.department_id')->leftJoin('item_categories as ic', 'ic.key', '=', 'items.category')
            ->select('items.*', 'dep.name as department_name', 'dep.name_en as department_name_en', 'ic.name as category_name', 'ic.name_en as category_name_en');
    }

    public static function list(array $f, array $page): array
    {
        $qb = self::withDepartment()->whereNull('items.deleted_at')->orderBy('items.name');
        // Strictly exclude books from generic items listing
        $qb->where(function ($w) {
            $w->whereNull('items.category')->orWhereNotIn('items.category', ['books', 'book', 'መጻሕፍት']);
        })->whereNull('items.library_category_id');
        // Amharic or English: name, author, description, code prefix and the category's names.
        if (! empty($f['q'])) $qb->where(fn ($w) => $w->where('items.name', 'like', "%{$f['q']}%")->orWhere('items.code', 'like', "{$f['q']}%")->orWhere('items.author', 'like', "%{$f['q']}%")
            ->orWhere('items.description', 'like', "%{$f['q']}%")->orWhere('ic.name', 'like', "%{$f['q']}%")->orWhere('ic.name_en', 'like', "%{$f['q']}%"));
        if (! empty($f['category'])) $qb->where('category', $f['category']);
        if (! empty($f['domain'])) $qb->where('domain', $f['domain']);
        if (! empty($f['status'])) $qb->where('items.status', $f['status']);
        if (! empty($f['available'])) $qb->where('available_quantity', '>', 0)->where('items.status', 'active');
        if (! empty($f['department_id'])) $qb->where('items.department_id', $f['department_id']);
        if (isset($f['direct'])) $qb->where('items.direct_borrowable', $f['direct']);
        if (! empty($f['kind'])) $qb->where('items.kind', $f['kind']);
        else $qb->where('items.kind', '<>', 'digital');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($i) => self::serialize($i), $res['items']), 'meta' => $res['meta']];
    }

    /** Configured categories (+ any older free-text category still used by an item). Excludes books. */
    public static function categories(bool $includeInactive = false): array
    {
        $q = DB::table('item_categories')->where('key', '<>', 'books')->orderBy('sort_order')->orderBy('name');
        if (! $includeInactive) $q->where('is_active', true);
        $out = $q->get()->map(fn ($c) => ['key' => $c->key, 'name' => $c->name, 'name_en' => $c->name_en, 'code' => $c->code, 'is_active' => (bool) $c->is_active, 'built_in' => (bool) $c->built_in])->all();
        $known = array_column($out, 'key');
        $known[] = 'books'; // exclude books from legacy fallback
        foreach (DB::table('items')->whereNull('deleted_at')->whereNotNull('category')->where('category', '!=', '')->distinct()->orderBy('category')->pluck('category') as $legacy) {
            if (! in_array($legacy, $known, true)) $out[] = ['key' => $legacy, 'name' => $legacy, 'name_en' => null, 'code' => 'OT', 'is_active' => true, 'built_in' => false, 'legacy' => true];
        }
        return $out;
    }

    public static function saveCategory(array $actx, ?string $key, array $in): array
    {
        $key ??= trim(preg_replace('/[^a-z0-9_]+/', '_', strtolower((string) ($in['key'] ?? $in['name_en'] ?? ''))), '_');
        if ($key === '' || $key === 'books') throw ApiError::field('key', 'INVALID_KEY');
        $exists = DB::table('item_categories')->where('key', $key)->exists();
        $row = array_intersect_key($in, array_flip(['name', 'name_en', 'code', 'sort_order', 'is_active']));
        if (isset($row['code'])) $row['code'] = strtoupper($row['code']);
        if ($exists) {
            if ($row) DB::table('item_categories')->where('key', $key)->update($row);
        } else {
            if (empty($row['name'])) throw ApiError::field('name', 'REQUIRED');
            DB::table('item_categories')->insert(['key' => $key, 'code' => $row['code'] ?? strtoupper(substr($key, 0, 2))] + $row);
        }
        Audit::log($actx, Audit::ITEM_UPDATE, 'item_category', null, ['key' => $key, 'changes' => $row]);
        return self::categories(true);
    }

    /** A built-in category (or one still used) is only switched off, never deleted. */
    public static function deleteCategory(array $actx, string $key): array
    {
        if ($key === 'books') throw ApiError::conflict('PROTECTED_CATEGORY', 'Cannot delete built-in book category');
        $c = DB::table('item_categories')->where('key', $key)->first();
        if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        if ($c->built_in || DB::table('items')->where('category', $key)->whereNull('deleted_at')->exists()) {
            DB::table('item_categories')->where('key', $key)->update(['is_active' => false]);
        } else {
            DB::table('item_categories')->where('key', $key)->delete();
        }
        Audit::log($actx, Audit::ITEM_UPDATE, 'item_category', null, ['key' => $key, 'removed' => true]);
        return self::categories(true);
    }

    /**
     * Next free code for a generic inventory item: CATEGORY-ITEMNAME-SEQUENCE (e.g. FURN-DESK-001).
     * If name is omitted, uses CATEGORY-ITEM-SEQUENCE. Call under the item-code lock.
     */
    public static function nextCode(?int $departmentId, ?string $category, ?string $name = null): string
    {
        $catCode = 'GEN';
        if ($category) {
            $catCode = DB::table('item_categories')->where('key', $category)->value('code') ?: strtoupper(substr(preg_replace('/[^a-zA-Z0-9]/', '', $category), 0, 4));
        }
        if (empty($catCode)) $catCode = 'PROP';
        $catCode = strtoupper($catCode);

        // Item tag from name (e.g., Desk -> DESK, Projector -> PROJ)
        $itemTag = 'ITEM';
        if (! empty($name)) {
            $cleanName = preg_replace('/[^a-zA-Z0-9]/', '', $name);
            if (strlen($cleanName) >= 2) {
                $itemTag = strtoupper(substr($cleanName, 0, 4));
            }
        }

        $base = "{$catCode}-{$itemTag}-";
        $max = 0;
        foreach (DB::table('items')->where('code', 'like', $base . '%')->pluck('code') as $code) {
            if (preg_match('/^' . preg_quote($base, '/') . '(\d+)$/', strtoupper($code), $m)) {
                $max = max($max, (int) $m[1]);
            }
        }
        return $base . str_pad((string) ($max + 1), 3, '0', STR_PAD_LEFT);
    }

    public static function get(int $id): array
    {
        $i = self::withDepartment()->where('items.id', $id)->whereNull('items.deleted_at')->first();
        if (! $i) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
        return self::serialize($i);
    }

    private static function codeTaken(): ApiError
    {
        return ApiError::conflict('ITEM_CODE_TAKEN', 'Item code already exists', [['field' => 'code', 'code' => 'ITEM_CODE_TAKEN', 'message' => 'ITEM_CODE_TAKEN']]);
    }

    public static function create(array $actx, array $input): array
    {
        if (($input['kind'] ?? '') === 'digital' || in_array($input['category'] ?? '', ['books', 'book', 'መጻሕፍት'], true) || ! empty($input['library_category_id'])) {
            throw ApiError::badRequest('BOOKS_NOT_GENERIC_ITEM', 'Books are managed in the Library and Education Catalog, not generic items');
        }
        $id = \App\Mz\Db\Locks::waitFor('mz:item-code', fn () => DB::transaction(function () use ($actx, $input) {
            if (trim((string) ($input['code'] ?? '')) === '') $input['code'] = self::nextCode($input['department_id'] ?? null, $input['category'] ?? null, $input['name'] ?? null);
            if (DB::table('items')->where('code', $input['code'])->exists()) throw self::codeTaken();
            $row = array_intersect_key($input, array_flip(self::FIELDS));
            $newId = DB::table('items')->insertGetId($row + ['quantity' => $input['quantity'], 'available_quantity' => $input['quantity'], 'created_by' => $actx['auth']->id, 'updated_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::ITEM_CREATE, 'item', $newId, ['code' => $input['code'], 'quantity' => $input['quantity']], inTrx: true);
            return $newId;
        }));
        return self::get($id);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        DB::transaction(function () use ($actx, $id, $input) {
            $i = DB::table('items')->where('id', $id)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $i) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
            if (array_key_exists('code', $input) && trim((string) $input['code']) === '') unset($input['code']); // keep the current code
            if (! empty($input['code']) && $input['code'] !== $i->code && DB::table('items')->where('code', $input['code'])->exists()) throw self::codeTaken();
            $patch = array_intersect_key($input, array_flip(self::FIELDS));
            if (isset($input['quantity']) && $input['quantity'] !== $i->quantity) {
                $borrowed = $i->quantity - $i->available_quantity;
                if ($input['quantity'] < $borrowed) throw ApiError::field('quantity', 'QUANTITY_BELOW_BORROWED');
                $patch['quantity'] = $input['quantity'];
                $patch['available_quantity'] = $input['quantity'] - $borrowed;
            }
            DB::table('items')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
            $previous = [];
            foreach (array_keys($patch) as $k) $previous[$k] = $i->{$k};
            Audit::log($actx, Audit::ITEM_UPDATE, 'item', $id, ['fields' => array_keys($patch), 'previous' => (object) $previous, 'next' => (object) $patch], inTrx: true);
        });
        return self::get($id);
    }

    public static function remove(array $actx, int $id): void
    {
        DB::transaction(function () use ($actx, $id) {
            $i = DB::table('items')->where('id', $id)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $i) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
            if (DB::table('borrowings')->where('item_id', $id)->whereIn('status', ['active', 'partially_returned'])->exists()) throw ApiError::conflict('ITEM_HAS_ACTIVE_BORROWINGS', 'Item has active borrowings');
            DB::table('items')->where('id', $id)->update(['deleted_at' => now(), 'status' => 'retired']);
            Audit::log($actx, Audit::ITEM_DELETE, 'item', $id, ['code' => $i->code], inTrx: true);
        });
    }

    /** The PDF of a digital book (replaces the previous one). */
    public static function setFile(array $actx, int $id, UploadedFile $file): array
    {
        $i = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first(['id', 'file_path']);
        if (! $i) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
        $saved = Storage::save('book', Storage::FOLDERS['BOOKS'], $file);
        DB::table('items')->where('id', $id)->update(['file_path' => $saved['path'], 'file_mime' => $saved['mime'], 'file_size' => $saved['size'], 'kind' => 'digital', 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::ITEM_UPDATE, 'item', $id, ['file' => 'replaced', 'size' => $saved['size']]);
        Storage::remove($i->file_path);
        return self::get($id);
    }

    /**
     * Inventory history of one item, newest first: changes to the item (with old → new values),
     * every borrowing (issue with its condition, return with its condition, fine) and every
     * department property request issued from / returned to it.
     */
    public static function history(int $id, int $limit = 200): array
    {
        if (! DB::table('items')->where('id', $id)->exists()) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
        $out = [];
        $audits = DB::table('audit_logs as l')->leftJoin('users as a', 'a.id', '=', 'l.actor_id')->leftJoin('roles as r', 'r.id', '=', 'a.role_id')
            ->where(['l.entity_type' => 'item', 'l.entity_id' => $id])->where('l.is_hidden', false)
            ->orderByDesc('l.id')->limit($limit)->get(['l.action', 'l.metadata', 'l.created_at', Actor::hiddenName('a', 'r', 'actor_name')]);
        foreach ($audits as $a) {
            $out[] = ['at' => $a->created_at, 'kind' => 'item', 'action' => $a->action, 'by' => $a->actor_name, 'details' => is_string($a->metadata) ? json_decode($a->metadata, true) : $a->metadata];
        }
        $borrowings = DB::table('borrowings as b')->join('users as u', 'u.id', '=', 'b.user_id')->leftJoin('users as i', 'i.id', '=', 'b.issued_by')->leftJoin('users as t', 't.id', '=', 'b.returned_to')
            ->where('b.item_id', $id)->orderByDesc('b.id')->limit($limit)
            ->get(['b.id', 'b.quantity', 'b.status', 'b.borrowed_on', 'b.due_on', 'b.returned_on', 'b.returned_quantity', 'b.issue_condition', 'b.return_condition', 'b.fine_amount', 'b.created_at', 'b.updated_at', 'u.full_name as recipient', 'i.full_name as issued_by', 't.full_name as returned_to']);
        foreach ($borrowings as $b) {
            $out[] = ['at' => $b->created_at, 'kind' => 'borrowing', 'action' => 'issue', 'by' => $b->issued_by, 'details' => ['borrowing_id' => $b->id, 'recipient' => $b->recipient, 'quantity' => $b->quantity, 'condition' => $b->issue_condition, 'due_on' => Dates::toDateOnly($b->due_on), 'status' => $b->status]];
            if ($b->returned_on) {
                $out[] = ['at' => $b->updated_at, 'kind' => 'borrowing', 'action' => 'return', 'by' => $b->returned_to, 'details' => ['borrowing_id' => $b->id, 'recipient' => $b->recipient, 'quantity' => $b->returned_quantity, 'condition' => $b->return_condition, 'returned_on' => Dates::toDateOnly($b->returned_on), 'fine' => \App\Mz\Support\Num::n($b->fine_amount)]];
            }
        }
        $requests = DB::table('property_request_events as e')->join('property_requests as r', 'r.id', '=', 'e.request_id')->join('departments as d', 'd.id', '=', 'r.department_id')->leftJoin('users as u', 'u.id', '=', 'e.actor_id')
            ->where('r.item_id', $id)->whereIn('e.action', ['issue', 'return'])->orderByDesc('e.id')->limit($limit)
            ->get(['e.action', 'e.quantity', 'e.note', 'e.created_at', 'r.id as request_id', 'd.name as department', 'u.full_name as actor']);
        foreach ($requests as $e) {
            $out[] = ['at' => $e->created_at, 'kind' => 'property_request', 'action' => $e->action, 'by' => $e->actor, 'details' => ['request_id' => $e->request_id, 'department' => $e->department, 'quantity' => $e->quantity, 'note' => $e->note]];
        }
        usort($out, fn ($a, $b) => \App\Mz\Support\Dates::ms($b['at']) <=> \App\Mz\Support\Dates::ms($a['at']));
        return array_slice($out, 0, $limit);
    }

    public static function setImage(array $actx, int $id, UploadedFile $file): array
    {
        $i = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first(['id', 'image']);
        if (! $i) throw ApiError::notFound('ITEM_NOT_FOUND', 'Item not found');
        $saved = Storage::save('image', Storage::FOLDERS['ITEM_IMAGES'], $file);
        DB::table('items')->where('id', $id)->update(['image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::ITEM_UPDATE, 'item', $id, ['image' => 'replaced']);
        Storage::remove($i->image);
        return self::get($id);
    }
}
