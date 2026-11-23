<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * The library for members (ትምህርት and መዝሙር): books are items with a cover and a code managed by
 * the administrator. Digital books (PDF) are downloaded by any signed-in member; physical books are
 * requested, approved by the librarian and handed over with the member's signature.
 *
 * F16: Categories hierarchy, favorites, progress tracking (pages & audio narration), background narration.
 */
final class Library
{
    private const OPEN = ['requested', 'approved'];

    public static function bookTable(): string
    {
        return \Illuminate\Support\Facades\Schema::hasTable('books') ? 'books' : 'items';
    }

    // ------------------------------------------------------------------ catalog (members)
    public static function books(AuthContext $auth, array $f, array $page): array
    {
        $canManage = $auth->isAdmin || $auth->can('items.manage') || $auth->can('education.manage') || $auth->can('library.circulate') || $auth->can('borrowing.manage');

        $table = self::bookTable();
        $qb = DB::table("{$table} as i")
            ->leftJoin('library_categories as cat', 'cat.id', '=', 'i.library_category_id')
            ->whereNull('i.deleted_at')
            ->orderBy('i.name')
            ->select('i.*', 'cat.name as category_name');

        if (! empty($f['status'])) {
            if ($f['status'] === 'all' && $canManage) {
                // No status filter
            } elseif ($canManage || $f['status'] === 'active') {
                $qb->where('i.status', $f['status']);
            } else {
                $qb->where('i.status', 'active');
            }
        } elseif (! $canManage || empty($f['status_any'])) {
            $qb->where('i.status', 'active');
        }

        // Education books follow the ትምህርት module switch (server-side, not only hidden in the app).
        if (($f['domain'] ?? null) === 'timhirt') \App\Mz\Http\ModuleGate::assert($auth, 'education');
        if (! empty($f['domain'])) $qb->where('i.domain', $f['domain']);
        elseif (! \App\Mz\Http\ModuleGate::allows($auth, 'education')) $qb->where('i.domain', '<>', 'timhirt');

        // Only return library books: items that belong to the library catalog, never generic property items.
        $qb->where(function ($w) {
            $w->whereNotNull('i.library_category_id')
              ->orWhere('i.kind', 'digital')
              ->orWhere('i.domain', 'timhirt')
              ->orWhereIn('i.category', ['books', 'book', 'መጻሕፍት']);
        });

        if (! empty($f['kind'])) $qb->where('i.kind', $f['kind']);
        if (! empty($f['category'])) $qb->where('i.category', $f['category']);
        if (isset($f['category_id']) && $f['category_id'] !== '' && $f['category_id'] !== null) {
            $catId = (int) $f['category_id'];
            if ($catId === -1) {
                $qb->whereNull('i.library_category_id');
            } elseif ($catId > 0) {
                $childIds = DB::table('library_categories')->where('id', $catId)->orWhere('parent_id', $catId)->pluck('id')->all();
                $qb->whereIn('i.library_category_id', $childIds ?: [$catId]);
            }
        }
        if (! empty($f['favorites_only'])) {
            $qb->join('library_favorites as fav', fn ($j) => $j->on('fav.item_id', '=', 'i.id')->where('fav.user_id', $auth->id));
        }
        if (! empty($f['language']) && $f['language'] !== 'all') {
            $qb->where('i.language', $f['language']);
        }
        if (! empty($f['available_only'])) {
            $qb->where(fn ($w) => $w->where('i.kind', 'digital')->orWhere('i.available_quantity', '>', 0));
        }

        if (! empty($f['q'])) {
            $q = trim((string) $f['q']);
            $qb->where(fn ($w) => $w->where('i.name', 'like', "%{$q}%")
                ->orWhere('i.subtitle', 'like', "%{$q}%")
                ->orWhere('i.author', 'like', "%{$q}%")
                ->orWhere('i.publisher', 'like', "%{$q}%")
                ->orWhere('cat.name', 'like', "%{$q}%")
                ->orWhere('cat.name_en', 'like', "%{$q}%")
                ->orWhere('i.code', 'like', "{$q}%"));
        }

        // A digital book without its PDF yet is not shown to regular members. Admins can view drafts with include_drafts=true.
        if (! $canManage || empty($f['include_drafts'])) {
            $qb->where(fn ($w) => $w->where('i.kind', 'physical')->orWhereNotNull('i.file_path'));
        }

        $res = Page::paginate($qb, $page);

        $itemIds = array_column($res['items'], 'id');
        $mine = ! empty($itemIds)
            ? DB::table('library_requests')->where('user_id', $auth->id)->whereIn('item_id', $itemIds)->whereIn('status', self::OPEN)->pluck('status', 'item_id')->all()
            : [];

        // Check active borrowings in borrowings and library_loans so borrowed books are recognized
        if (! empty($itemIds)) {
            if (\Illuminate\Support\Facades\Schema::hasTable('borrowings')) {
                $activeLoans = DB::table('borrowings')
                    ->where('user_id', $auth->id)
                    ->whereIn('item_id', $itemIds)
                    ->whereIn('status', ['pending_approval', 'active', 'partially_returned'])
                    ->pluck('status', 'item_id')
                    ->all();
                foreach ($activeLoans as $itemId => $status) {
                    $mine[$itemId] = $status === 'pending_approval' ? 'requested' : 'issued';
                }
            }
            if (\Illuminate\Support\Facades\Schema::hasTable('library_loans') && \Illuminate\Support\Facades\Schema::hasTable('library_copies')) {
                $activeCopyLoans = DB::table('library_loans as l')
                    ->join('library_copies as c', 'c.id', '=', 'l.copy_id')
                    ->where('l.user_id', $auth->id)
                    ->whereIn('c.item_id', $itemIds)
                    ->where('l.status', 'active')
                    ->pluck('l.status', 'c.item_id')
                    ->all();
                foreach ($activeCopyLoans as $itemId => $status) {
                    $mine[$itemId] = 'issued';
                }
            }
        }
        $favorites = ! empty($itemIds)
            ? DB::table('library_favorites')->where('user_id', $auth->id)->whereIn('item_id', $itemIds)->pluck('item_id')->flip()->all()
            : [];
        $progress = ! empty($itemIds)
            ? DB::table('library_progress')->where('user_id', $auth->id)->whereIn('item_id', $itemIds)->get()->keyBy('item_id')->all()
            : [];

        // Physical copies counts
        $copiesAvail = [];
        $copiesTotal = [];
        if (! empty($itemIds)) {
            $copyCounts = DB::table('library_copies')->whereIn('item_id', $itemIds)
                ->selectRaw("item_id, count(*) as total, sum(case when status = 'available' then 1 else 0 end) as avail")
                ->groupBy('item_id')
                ->get();
            foreach ($copyCounts as $cc) {
                $copiesAvail[$cc->item_id] = (int) $cc->avail;
                $copiesTotal[$cc->item_id] = (int) $cc->total;
            }
        }

        $res['items'] = array_map(function ($i) use ($auth, $mine, $favorites, $progress, $copiesAvail, $copiesTotal) {
            $p = $progress[$i->id] ?? null;
            return self::serializeBook($i, [
                'my_request' => $mine[$i->id] ?? null,
                'is_favorite' => isset($favorites[$i->id]),
                'progress' => $p ? [
                    'page' => (int) $p->page,
                    'page_count' => $p->page_count ? (int) $p->page_count : null,
                    'audio_position_ms' => (int) $p->audio_position_ms,
                    'updated_at' => $p->updated_at,
                ] : null,
                'copies_available' => $copiesAvail[$i->id] ?? ($i->kind === 'physical' ? (int) $i->available_quantity : null),
                'copies_total' => $copiesTotal[$i->id] ?? ($i->kind === 'physical' ? (int) $i->quantity : null),
            ]);
        }, $res['items']);

        return $res;
    }

    public static function book(AuthContext $auth, int $id): array
    {
        $canManage = $auth->isAdmin || $auth->can('items.manage') || $auth->can('education.manage') || $auth->can('library.circulate') || $auth->can('borrowing.manage');

        $table = self::bookTable();
        $qb = DB::table("{$table} as i")
            ->leftJoin('library_categories as cat', 'cat.id', '=', 'i.library_category_id')
            ->where('i.id', $id)
            ->whereNull('i.deleted_at')
            ->select('i.*', 'cat.name as category_name');

        if (! $canManage) {
            $qb->where('i.status', 'active');
        }

        $i = $qb->first();

        if (! $i) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');
        if ($i->domain === 'timhirt') \App\Mz\Http\ModuleGate::assert($auth, 'education');

        $isFav = DB::table('library_favorites')->where(['user_id' => $auth->id, 'item_id' => $id])->exists();
        $p = DB::table('library_progress')->where(['user_id' => $auth->id, 'item_id' => $id])->first();
        $myReq = DB::table('library_requests')->where(['user_id' => $auth->id, 'item_id' => $id])->whereIn('status', self::OPEN)->value('status');

        $copiesAvail = DB::table('library_copies')->where(['item_id' => $id, 'status' => 'available'])->count();
        $copiesTotal = DB::table('library_copies')->where('item_id', $id)->count();

        return self::serializeBook($i, [
            'my_request' => $myReq,
            'is_favorite' => $isFav,
            'progress' => $p ? [
                'page' => (int) $p->page,
                'page_count' => $p->page_count ? (int) $p->page_count : null,
                'audio_position_ms' => (int) $p->audio_position_ms,
                'updated_at' => $p->updated_at,
            ] : null,
            'copies_available' => $copiesTotal > 0 ? $copiesAvail : (int) $i->available_quantity,
            'copies_total' => $copiesTotal > 0 ? $copiesTotal : (int) $i->quantity,
        ]);
    }

    public static function serializeBook(object $i, array $extra = []): array
    {
        return [
            'id' => (int) $i->id,
            'title' => $i->name,
            'subtitle' => $i->subtitle ?? null,
            'author' => $i->author,
            'publisher' => $i->publisher ?? null,
            'publication_year' => $i->publication_year !== null ? (int) $i->publication_year : null,
            'language' => $i->language ?? 'am',
            'code' => $i->code,
            'kind' => $i->kind,
            'category' => $i->category,
            'category_id' => $i->library_category_id ? (int) $i->library_category_id : null,
            'category_name' => $extra['category_name'] ?? ($i->category_name ?? $i->category ?? null),
            'category_type' => $i->category_type ?? null,
            'description' => $i->description,
            'domain' => $i->domain,
            'cover_url' => Storage::url($i->image),
            'available' => $extra['copies_available'] ?? ($i->kind === 'physical' ? (int) $i->available_quantity : null),
            'quantity' => $extra['copies_total'] ?? ($i->kind === 'physical' ? (int) $i->quantity : null),
            'file_url' => $i->kind === 'digital' && $i->file_path ? url("/api/v1/library/books/{$i->id}/file") : null,
            'stream_url' => $i->kind === 'digital' && $i->file_path ? url("/api/v1/library/books/{$i->id}/file") : null,
            'file_size' => $i->file_size !== null ? (int) $i->file_size : null,
            'narration_url' => ! empty($i->narration_path) ? url("/api/v1/library/books/{$i->id}/narration") : null,
            'narration_mime' => $i->narration_mime ?? null,
            'narration_duration' => $i->narration_duration !== null ? (int) $i->narration_duration : null,
            'downloads' => (int) $i->downloads,
            'is_favorite' => (bool) ($extra['is_favorite'] ?? false),
            'progress' => $extra['progress'] ?? null,
            'my_request' => $extra['my_request'] ?? null,
            'status' => $i->status ?? 'active',
            'condition' => $i->condition ?? null,
            'location' => $i->location ?? null,
            'notes' => $i->notes ?? null,
        ];
    }

    // ------------------------------------------------------------------ categories (F16)
    public static function categories(?string $domain, bool $tree = false, ?string $type = null, bool $onlyActive = false): array
    {
        $q = DB::table('library_categories')->orderBy('sort_order')->orderBy('name');
        if ($domain) {
            $q->where(function ($w) use ($domain) {
                $w->where('domain', $domain)
                  ->orWhere('domain', '')
                  ->orWhereNull('domain');
            });
        }
        if ($type) {
            $q->where(fn ($w) => $w->where('category_type', $type)->orWhere('category_type', 'both'));
        }
        if ($onlyActive) {
            $q->where('is_active', true);
        }
        $cats = $q->get();

        $countsQ = DB::table('items')
            ->whereNull('deleted_at')
            ->where('status', 'active')
            ->whereNotNull('library_category_id');

        if ($domain) {
            $countsQ->where(function ($w) use ($domain) {
                $w->where('domain', $domain)
                  ->orWhere('domain', '')
                  ->orWhereNull('domain');
            });
        }

        $counts = $countsQ->groupBy('library_category_id')
            ->selectRaw('library_category_id, count(*) as c')
            ->pluck('c', 'library_category_id')
            ->all();

        $flat = array_map(fn ($c) => [
            'id' => (int) $c->id,
            'parent_id' => $c->parent_id ? (int) $c->parent_id : null,
            'domain' => $c->domain,
            'category_type' => $c->category_type ?? 'physical',
            'name' => $c->name,
            'name_en' => $c->name_en,
            'description' => $c->description ?? null,
            'code' => $c->code,
            'is_active' => (bool) ($c->is_active ?? true),
            'sort_order' => (int) $c->sort_order,
            'books_count' => (int) ($counts[$c->id] ?? 0),
        ], $cats->all());

        if (! $tree) return $flat;

        $byId = [];
        foreach ($flat as $item) {
            $item['children'] = [];
            $byId[$item['id']] = $item;
        }
        $root = [];
        foreach ($byId as $id => &$item) {
            if ($item['parent_id'] && isset($byId[$item['parent_id']])) {
                $byId[$item['parent_id']]['children'][] = &$item;
            } else {
                $root[] = &$item;
            }
        }
        return $root;
    }

    public static function saveCategory(array $actx, array $data, ?int $id = null): array
    {
        $name = trim((string) ($data['name'] ?? ''));
        if (empty($name)) throw ApiError::field('name', 'REQUIRED', 'Category name is required');

        $row = [
            'parent_id' => ! empty($data['parent_id']) ? (int) $data['parent_id'] : null,
            'domain' => in_array($data['domain'] ?? 'timhirt', ['timhirt', 'mezmur'], true) ? $data['domain'] : 'timhirt',
            'name' => $name,
            'name_en' => ! empty($data['name_en']) ? mb_substr(trim($data['name_en']), 0, 200) : null,
            'code' => ! empty($data['code']) ? strtoupper(mb_substr(trim($data['code']), 0, 32)) : null,
            'sort_order' => (int) ($data['sort_order'] ?? 0),
            'updated_at' => now(),
        ];

        if (\Illuminate\Support\Facades\Schema::hasColumn('library_categories', 'category_type')) {
            $catType = $data['category_type'] ?? 'both';
            $row['category_type'] = in_array($catType, ['physical', 'digital', 'both'], true) ? $catType : 'both';
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('library_categories', 'description')) {
            $row['description'] = ! empty($data['description']) ? trim((string) $data['description']) : null;
        }
        if (\Illuminate\Support\Facades\Schema::hasColumn('library_categories', 'is_active')) {
            $row['is_active'] = array_key_exists('is_active', $data) ? (bool) $data['is_active'] : true;
        }

        if ($id) {
            $existing = DB::table('library_categories')->where('id', $id)->first();
            if (! $existing) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
            DB::table('library_categories')->where('id', $id)->update($row);
            Audit::log($actx, 'library.category_update', 'library_category', $id, $row);
        } else {
            $row['created_at'] = now();
            $id = DB::table('library_categories')->insertGetId($row);
            Audit::log($actx, 'library.category_create', 'library_category', $id, $row);
        }

        return (array) DB::table('library_categories')->where('id', $id)->first();
    }

    public static function deleteCategory(array $actx, int $id): array
    {
        $existing = DB::table('library_categories')->where('id', $id)->first();
        if (! $existing) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');

        $hasBooks = DB::table('items')->where('library_category_id', $id)->whereNull('deleted_at')->exists();
        if ($hasBooks) throw ApiError::conflict('CATEGORY_HAS_BOOKS', 'Cannot delete category containing active books');

        $hasChildren = DB::table('library_categories')->where('parent_id', $id)->exists();
        if ($hasChildren) throw ApiError::conflict('CATEGORY_HAS_CHILDREN', 'Cannot delete category containing subcategories');

        DB::table('library_categories')->where('id', $id)->delete();
        Audit::log($actx, 'library.category_delete', 'library_category', $id);
        return ['id' => $id, 'deleted' => true];
    }

    // ------------------------------------------------------------------ favorites & progress (F16)
    public static function favorite(int $userId, int $itemId, ?bool $fav = null): array
    {
        $book = DB::table(self::bookTable())->where(['id' => $itemId, 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $book) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');

        if ($fav === null) {
            $isFav = DB::table('library_favorites')->where(['user_id' => $userId, 'item_id' => $itemId])->exists();
            $fav = ! $isFav;
        }

        if ($fav) {
            DB::table('library_favorites')->insertOrIgnore([
                'user_id' => $userId,
                'item_id' => $itemId,
                'created_at' => now(),
            ]);
        } else {
            DB::table('library_favorites')->where(['user_id' => $userId, 'item_id' => $itemId])->delete();
        }

        return ['item_id' => $itemId, 'is_favorite' => (bool) $fav, 'favorited' => (bool) $fav];
    }

    public static function myFavorites(AuthContext $auth, array $page): array
    {
        return self::books($auth, ['favorites_only' => true], $page);
    }

    public static function myFavoriteIds(int $userId): array
    {
        return DB::table('library_favorites')
            ->where('user_id', $userId)
            ->pluck('item_id')
            ->map(fn ($id) => (int) $id)
            ->values()
            ->all();
    }

    public static function saveProgress(int $userId, int $itemId, array $data): array
    {
        $book = DB::table(self::bookTable())->where(['id' => $itemId, 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $book) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');

        $page = max(1, (int) ($data['page'] ?? 1));
        $pageCount = ! empty($data['page_count']) ? max(1, (int) $data['page_count']) : null;
        $audioPos = max(0, (int) ($data['audio_position_ms'] ?? 0));

        $exists = DB::table('library_progress')->where(['user_id' => $userId, 'item_id' => $itemId])->exists();
        if ($exists) {
            DB::table('library_progress')->where(['user_id' => $userId, 'item_id' => $itemId])->update([
                'page' => $page,
                'page_count' => $pageCount,
                'audio_position_ms' => $audioPos,
                'updated_at' => now(),
            ]);
        } else {
            DB::table('library_progress')->insert([
                'user_id' => $userId,
                'item_id' => $itemId,
                'page' => $page,
                'page_count' => $pageCount,
                'audio_position_ms' => $audioPos,
                'updated_at' => now(),
            ]);
        }

        return [
            'item_id' => $itemId,
            'page' => $page,
            'page_count' => $pageCount,
            'audio_position_ms' => $audioPos,
        ];
    }

    public static function getProgress(int $userId, int $itemId): ?array
    {
        $p = DB::table('library_progress')->where(['user_id' => $userId, 'item_id' => $itemId])->first();
        if (! $p) return null;
        return [
            'item_id' => $itemId,
            'page' => (int) $p->page,
            'page_count' => $p->page_count ? (int) $p->page_count : null,
            'audio_position_ms' => (int) $p->audio_position_ms,
            'updated_at' => $p->updated_at,
        ];
    }

    // ------------------------------------------------------------------ files & narration
    public static function file(AuthContext $auth, int $id): array
    {
        $i = DB::table(self::bookTable())->where(['id' => $id, 'kind' => 'digital', 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $i || ! $i->file_path) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');
        if ($i->domain === 'timhirt') \App\Mz\Http\ModuleGate::assert($auth, 'education');
        $abs = Storage::privatePath($i->file_path);
        if (! is_file($abs)) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');
        DB::table(self::bookTable())->where('id', $id)->increment('downloads');
        if ($auth->accountType === 'user') {
            Activity::track($auth->id, Activity::BOOK_READ, 'book', $id, ['name' => $i->name, 'kind' => 'digital']);
            Activity::track($auth->id, Activity::DOWNLOAD, 'item', $id, ['kind' => 'book']);
        }
        $name = preg_replace('/[^\p{L}\p{N}._ -]/u', '', $i->name) ?: "book-$id";
        return ['abs' => $abs, 'mime' => $i->file_mime ?: 'application/pdf', 'name' => mb_substr($name, 0, 120) . '.pdf'];
    }

    public static function narrationFile(AuthContext $auth, int $id): array
    {
        $i = DB::table(self::bookTable())->where(['id' => $id, 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $i || ! $i->narration_path) throw ApiError::notFound('NARRATION_NOT_FOUND', 'Narration audio not found');
        if ($i->domain === 'timhirt') \App\Mz\Http\ModuleGate::assert($auth, 'education');

        $abs = str_starts_with($i->narration_path, 'public/')
            ? Storage::publicPath($i->narration_path)
            : Storage::privatePath($i->narration_path);

        if (! is_file($abs)) throw ApiError::notFound('NARRATION_NOT_FOUND', 'Audio file not found on disk');

        $name = preg_replace('/[^\p{L}\p{N}._ -]/u', '', $i->name) ?: "narration-$id";
        return ['abs' => $abs, 'mime' => $i->narration_mime ?: 'audio/mpeg', 'name' => mb_substr($name, 0, 120) . '.mp3'];
    }

    public static function uploadNarration(array $actx, int $id, mixed $file, ?int $duration = null): array
    {
        $i = DB::table('items')->where(['id' => $id, 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $i) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');

        $saved = Storage::save('audio', Storage::FOLDERS['BOOKS'], $file);
        DB::table('items')->where('id', $id)->update([
            'narration_path' => $saved['path'],
            'narration_mime' => $saved['mime'] ?? 'audio/mpeg',
            'narration_duration' => $duration ?: ($saved['duration'] ?? null),
        ]);

        Audit::log($actx, 'library.narration_upload', 'item', $id, ['path' => $saved['path']]);
        return self::book($actx['auth'], $id);
    }

    // ------------------------------------------------------------------ requests
    private static function serializeRequest(object $r): array
    {
        return [
            'id' => (int) $r->id,
            'status' => $r->status,
            'quantity' => (int) $r->quantity,
            'note' => $r->note,
            'needed_on' => Dates::toDateOnly($r->needed_on),
            'review_note' => $r->review_note,
            'reviewed_at' => $r->reviewed_at,
            'borrowing_id' => $r->borrowing_id ? (int) $r->borrowing_id : null,
            'book' => [
                'id' => (int) $r->item_id,
                'title' => $r->item_name,
                'code' => $r->item_code,
                'author' => $r->item_author,
                'cover_url' => Storage::url($r->item_image),
                'available' => (int) $r->item_available,
            ],
            'user' => [
                'id' => (int) $r->user_id,
                'full_name' => $r->user_name,
                'phone' => $r->user_phone,
                'member_id' => MemberIds::format($r->user_no, $r->user_group),
            ],
            'created_at' => $r->created_at,
        ];
    }

    private static function requestQuery()
    {
        return DB::table('library_requests as r')->join('items as i', 'i.id', '=', 'r.item_id')->join('users as u', 'u.id', '=', 'r.user_id')
            ->select('r.*', 'i.name as item_name', 'i.code as item_code', 'i.author as item_author', 'i.image as item_image', 'i.available_quantity as item_available',
                'u.full_name as user_name', 'u.phone as user_phone', 'u.member_no as user_no', 'u.member_group as user_group');
    }

    public static function request(array $actx, int $itemId, array $in): array
    {
        $auth = $actx['auth'];
        $i = DB::table('items')->where(['id' => $itemId, 'status' => 'active'])->whereNull('deleted_at')->first();
        if (! $i) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');
        if ($i->domain === 'timhirt') \App\Mz\Http\ModuleGate::assert($auth, 'education');
        if ($i->kind !== 'physical') throw ApiError::conflict('BOOK_IS_DIGITAL', 'Digital books are downloaded, not borrowed');

        // Check if user already has an active borrowing in borrowings
        $activeBorrowing = DB::table('borrowings')
            ->where(['user_id' => $auth->id, 'item_id' => $itemId])
            ->whereIn('status', ['pending_approval', 'active', 'partially_returned'])
            ->first();
        if ($activeBorrowing) {
            throw ApiError::conflict('ALREADY_BORROWED', 'You already have an active loan for this book', [
                'borrowing_id' => $activeBorrowing->id,
                'due_on' => $activeBorrowing->due_on,
            ]);
        }

        // Check if user already has an active loan in library_loans
        $activeCopyLoan = DB::table('library_loans as l')
            ->join('library_copies as c', 'c.id', '=', 'l.copy_id')
            ->where(['l.user_id' => $auth->id, 'c.item_id' => $itemId, 'l.status' => 'active'])
            ->first();
        if ($activeCopyLoan) {
            throw ApiError::conflict('ALREADY_BORROWED', 'You already have an active loan for this book', [
                'loan_id' => $activeCopyLoan->id,
                'due_on' => $activeCopyLoan->due_on,
            ]);
        }

        // Check book availability
        $avail = (int) ($i->available_quantity ?? $i->quantity ?? 0);
        if ($avail <= 0) {
            throw ApiError::conflict('BOOK_UNAVAILABLE', 'This book has no copies available to borrow right now');
        }

        $qty = (int) ($in['quantity'] ?? 1);
        if ($qty > max(1, (int) $i->quantity)) throw ApiError::field('quantity', 'INSUFFICIENT_QUANTITY');

        // Idempotent: If an existing open request already exists, return it instead of creating duplicate
        $existingReq = DB::table('library_requests')
            ->where(['user_id' => $auth->id, 'item_id' => $itemId])
            ->whereIn('status', self::OPEN)
            ->first();
        if ($existingReq) {
            return self::serializeRequest(self::requestQuery()->where('r.id', $existingReq->id)->first());
        }

        // Lock & insert under transaction to prevent concurrent duplicate submissions
        $createdNew = false;
        $id = DB::transaction(function () use ($auth, $itemId, $qty, $in, &$createdNew) {
            $locked = DB::table('library_requests')
                ->where(['user_id' => $auth->id, 'item_id' => $itemId])
                ->whereIn('status', self::OPEN)
                ->lockForUpdate()
                ->first();
            if ($locked) {
                return (int) $locked->id;
            }

            $createdNew = true;
            return DB::table('library_requests')->insertGetId([
                'user_id' => $auth->id,
                'item_id' => $itemId,
                'quantity' => $qty,
                'note' => $in['note'] ?? null,
                'needed_on' => $in['needed_on'] ?? null,
                'status' => 'requested',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        });

        if ($createdNew) {
            Audit::log($actx, 'library.request', 'library_request', $id, ['item_id' => $itemId, 'quantity' => $qty]);
            $n = Notifications::createForUsers(array_diff(Holders::of('borrowing.manage'), [$auth->id]), [
                'type' => 'borrowing', 'title' => T::t('library.request.title'), 'body' => T::t('library.request.body', ['name' => $auth->fullName, 'book' => $i->name]),
                'entityType' => 'library_request', 'entityId' => $id, 'dedupeKey' => fn ($uid) => "libreq:$id:new:$uid",
            ]);
            if ($n) Notifications::kick();
        }

        return self::serializeRequest(self::requestQuery()->where('r.id', $id)->first());
    }

    public static function myRequests(AuthContext $auth, array $page): array
    {
        $res = Page::paginate(self::requestQuery()->where('r.user_id', $auth->id)->orderByRaw("FIELD(r.status, 'approved', 'requested', 'issued', 'rejected', 'cancelled')")->orderByDesc('r.id'), $page);
        $res['items'] = array_map(fn ($r) => self::serializeRequest($r), $res['items']);
        return $res;
    }

    public static function cancel(array $actx, int $id): array
    {
        $r = DB::table('library_requests')->where(['id' => $id, 'user_id' => $actx['auth']->id])->first();
        if (! $r) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Request not found');
        if (! in_array($r->status, self::OPEN, true)) throw ApiError::conflict('REQUEST_CLOSED', 'This request is already closed');
        DB::table('library_requests')->where('id', $id)->update(['status' => 'cancelled']);
        Audit::log($actx, 'library.request_cancel', 'library_request', $id);
        return self::serializeRequest(self::requestQuery()->where('r.id', $id)->first());
    }

    // ------------------------------------------------------------------ librarian
    public static function adminRequests(array $f, array $page): array
    {
        $qb = self::requestQuery()->orderByRaw("FIELD(r.status, 'requested', 'approved', 'issued', 'rejected', 'cancelled')")->orderBy('r.id');
        if (! empty($f['status'])) $qb->whereIn('r.status', (array) $f['status']);
        if (! empty($f['domain'])) $qb->where('i.domain', $f['domain']);
        if (! empty($f['q'])) $qb->where(fn ($w) => $w->where('u.full_name', 'like', "%{$f['q']}%")->orWhere('i.name', 'like', "%{$f['q']}%")->orWhere('i.code', 'like', "{$f['q']}%"));
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => self::serializeRequest($r), $res['items']);
        return $res;
    }

    private static function open(int $id): object
    {
        $r = DB::table('library_requests')->where('id', $id)->lockForUpdate()->first();
        if (! $r) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Request not found');
        if (! in_array($r->status, self::OPEN, true)) throw ApiError::conflict('REQUEST_CLOSED', 'This request is already closed');
        return $r;
    }

    private static function tell(object $r, string $key, string $book, array $extra = []): void
    {
        Notifications::createForUsers([(int) $r->user_id], [
            'type' => 'borrowing', 'title' => T::t("library.$key.title"), 'body' => T::t("library.$key.body", ['book' => $book] + $extra),
            'entityType' => 'library_request', 'entityId' => (int) $r->id, 'dedupeKey' => fn () => "libreq:{$r->id}:$key",
        ]);
        Notifications::kick();
    }

    public static function approve(array $actx, int $id, ?string $note): array
    {
        $r = DB::transaction(function () use ($actx, $id, $note) {
            $r = self::open($id);
            if ($r->status !== 'requested') throw ApiError::conflict('REQUEST_CLOSED', 'Already approved');
            DB::table('library_requests')->where('id', $id)->update(['status' => 'approved', 'review_note' => $note, 'reviewed_by' => $actx['auth']->id, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, 'library.request_approve', 'library_request', $id, ['note' => $note], inTrx: true);
            return $r;
        });
        self::tell($r, 'approved', DB::table('items')->where('id', $r->item_id)->value('name'));
        return self::serializeRequest(self::requestQuery()->where('r.id', $id)->first());
    }

    public static function reject(array $actx, int $id, string $reason): array
    {
        $r = DB::transaction(function () use ($actx, $id, $reason) {
            $r = self::open($id);
            DB::table('library_requests')->where('id', $id)->update(['status' => 'rejected', 'review_note' => $reason, 'reviewed_by' => $actx['auth']->id, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, 'library.request_reject', 'library_request', $id, ['reason' => $reason], inTrx: true);
            return $r;
        });
        self::tell($r, 'rejected', DB::table('items')->where('id', $r->item_id)->value('name'), ['reason' => $reason]);
        return self::serializeRequest(self::requestQuery()->where('r.id', $id)->first());
    }

    public static function issue(array $actx, int $id, array $in): array
    {
        DB::transaction(function () use ($actx, $id, $in) {
            $r = self::open($id);
            $borrowingId = Borrowings::issueForRequest($actx, (int) $r->user_id, (int) $r->item_id, (int) $r->quantity, $in);
            DB::table('library_requests')->where('id', $id)->update(['status' => 'issued', 'borrowing_id' => $borrowingId, 'reviewed_by' => $actx['auth']->id, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, 'library.request_issue', 'library_request', $id, ['borrowing_id' => $borrowingId], inTrx: true);
        });
        return self::serializeRequest(self::requestQuery()->where('r.id', $id)->first());
    }

    // ------------------------------------------------------------------ Dedicated Book Management
    public static function saveDigitalBook(array $actx, array $data, ?int $id = null): array
    {
        $name = trim((string) ($data['name'] ?? $data['title'] ?? ''));
        if ($name === '') throw ApiError::field('name', 'REQUIRED');

        $categoryId = ! empty($data['library_category_id']) ? (int) $data['library_category_id'] : (! empty($data['category_id']) ? (int) $data['category_id'] : null);
        if ($categoryId) {
            $cat = DB::table('library_categories')->where('id', $categoryId)->first();
            if (! $cat) throw ApiError::field('library_category_id', 'CATEGORY_NOT_FOUND');
            if (isset($cat->category_type) && $cat->category_type === 'physical') {
                throw ApiError::field('library_category_id', 'CATEGORY_MUST_BE_DIGITAL', 'Selected category is restricted to physical books.');
            }
        }

        return DB::transaction(function () use ($actx, $data, $id, $name, $categoryId) {
            $table = self::bookTable();
            $existing = null;
            if ($id) {
                $existing = DB::table($table)->where('id', $id)->whereNull('deleted_at')->lockForUpdate()->first();
                if (! $existing && $table !== 'items') {
                    $existing = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first();
                }
                if (! $existing) throw ApiError::notFound('BOOK_NOT_FOUND', 'Digital book not found');
            }

            // Generate unique digital book code if creating or missing
            $code = ! empty($data['code']) ? trim((string) $data['code']) : ($existing->code ?? null);
            if (empty($code)) {
                $catCode = $categoryId ? (DB::table('library_categories')->where('id', $categoryId)->value('code') ?: 'DIG') : 'DIG';
                $codePrefix = strtoupper("DIG-{$catCode}-");
                $maxNum = 0;
                foreach (DB::table($table)->where('code', 'like', $codePrefix . '%')->pluck('code') as $c) {
                    if (preg_match('/^' . preg_quote($codePrefix, '/') . '(\d+)$/', strtoupper($c), $m)) {
                        $maxNum = max($maxNum, (int) $m[1]);
                    }
                }
                $code = $codePrefix . str_pad((string) ($maxNum + 1), 3, '0', STR_PAD_LEFT);
            }

            $dupQ = DB::table($table)->where('code', $code)->whereNull('deleted_at');
            if ($id) $dupQ->where('id', '<>', $id);
            if ($dupQ->exists()) throw ApiError::conflict('ITEM_CODE_TAKEN', 'Book code already exists');

            // Status: strictly preserve existing if not given; default to 'active'
            $status = $data['status'] ?? ($existing ? $existing->status : 'active');
            if (! in_array($status, ['active', 'inactive'], true)) $status = 'active';

            // Domain: strictly preserve existing or default to 'timhirt' for Education
            $domain = ! empty($data['domain']) ? $data['domain'] : ($existing ? $existing->domain : 'timhirt');

            $row = [
                'name' => $name,
                'subtitle' => array_key_exists('subtitle', $data) ? (! empty($data['subtitle']) ? trim((string) $data['subtitle']) : null) : ($existing->subtitle ?? null),
                'author' => array_key_exists('author', $data) ? (! empty($data['author']) ? trim((string) $data['author']) : null) : ($existing->author ?? null),
                'publisher' => array_key_exists('publisher', $data) ? (! empty($data['publisher']) ? trim((string) $data['publisher']) : null) : ($existing->publisher ?? null),
                'publication_year' => array_key_exists('publication_year', $data) && $data['publication_year'] !== null && $data['publication_year'] !== '' ? (int) $data['publication_year'] : ($existing->publication_year ?? null),
                'language' => ! empty($data['language']) ? $data['language'] : ($existing->language ?? 'am'),
                'description' => array_key_exists('description', $data) ? (! empty($data['description']) ? trim((string) $data['description']) : null) : ($existing->description ?? null),
                'library_category_id' => $categoryId,
                'category' => 'books',
                'kind' => 'digital',
                'domain' => $domain,
                'code' => $code,
                'status' => $status,
                'quantity' => 0,
                'available_quantity' => 0,
                'updated_by' => $actx['auth']->id,
                'updated_at' => now(),
            ];

            if ($id) {
                DB::table($table)->where('id', $id)->update($row);
                Audit::log($actx, 'library.digital_book_update', 'book', $id, ['name' => $name, 'status' => $status], inTrx: true);
                $bookId = $id;
            } else {
                $row['created_by'] = $actx['auth']->id;
                $row['created_at'] = now();
                $bookId = DB::table($table)->insertGetId($row);
                Audit::log($actx, 'library.digital_book_create', 'book', $bookId, ['name' => $name, 'status' => $status], inTrx: true);
            }

            return self::book($actx['auth'], $bookId);
        });
    }

    public static function savePhysicalBook(array $actx, array $data, ?int $id = null): array
    {
        $name = trim((string) ($data['name'] ?? $data['title'] ?? ''));
        if ($name === '') throw ApiError::field('name', 'REQUIRED');

        $categoryId = ! empty($data['library_category_id']) ? (int) $data['library_category_id'] : (! empty($data['category_id']) ? (int) $data['category_id'] : null);
        if ($categoryId) {
            $cat = DB::table('library_categories')->where('id', $categoryId)->first();
            if (! $cat) throw ApiError::field('library_category_id', 'CATEGORY_NOT_FOUND');
            if (isset($cat->category_type) && $cat->category_type === 'digital') {
                throw ApiError::field('library_category_id', 'CATEGORY_MUST_BE_PHYSICAL', 'Selected category is restricted to digital books.');
            }
        }

        return DB::transaction(function () use ($actx, $data, $id, $name, $categoryId) {
            $table = self::bookTable();
            $existing = null;
            if ($id) {
                $existing = DB::table($table)->where('id', $id)->whereNull('deleted_at')->lockForUpdate()->first();
                if (! $existing && $table !== 'items') {
                    $existing = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first();
                }
                if (! $existing) throw ApiError::notFound('BOOK_NOT_FOUND', 'Physical book not found');
            }

            $code = ! empty($data['code']) ? trim((string) $data['code']) : ($existing->code ?? null);
            if (empty($code)) {
                $catCode = $categoryId ? (DB::table('library_categories')->where('id', $categoryId)->value('code') ?: 'LIB') : 'LIB';
                $codePrefix = strtoupper("LIB-{$catCode}-");
                $maxNum = 0;
                foreach (DB::table($table)->where('code', 'like', $codePrefix . '%')->pluck('code') as $c) {
                    if (preg_match('/^' . preg_quote($codePrefix, '/') . '(\d+)$/', strtoupper($c), $m)) {
                        $maxNum = max($maxNum, (int) $m[1]);
                    }
                }
                $code = $codePrefix . str_pad((string) ($maxNum + 1), 3, '0', STR_PAD_LEFT);
            }

            $dupQ = DB::table($table)->where('code', $code)->whereNull('deleted_at');
            if ($id) $dupQ->where('id', '<>', $id);
            if ($dupQ->exists()) throw ApiError::conflict('ITEM_CODE_TAKEN', 'Book code already exists');

            $status = $data['status'] ?? ($existing ? $existing->status : 'active');
            $domain = ! empty($data['domain']) ? $data['domain'] : ($existing ? $existing->domain : 'mezmur');
            $qty = isset($data['quantity']) ? (int) $data['quantity'] : ($existing ? $existing->quantity : 1);
            $borrowed = $existing ? ($existing->quantity - $existing->available_quantity) : 0;
            if ($qty < $borrowed) throw ApiError::field('quantity', 'QUANTITY_BELOW_BORROWED');
            $available = $qty - $borrowed;

            $row = [
                'name' => $name,
                'subtitle' => array_key_exists('subtitle', $data) ? (! empty($data['subtitle']) ? trim((string) $data['subtitle']) : null) : ($existing->subtitle ?? null),
                'author' => array_key_exists('author', $data) ? (! empty($data['author']) ? trim((string) $data['author']) : null) : ($existing->author ?? null),
                'publisher' => array_key_exists('publisher', $data) ? (! empty($data['publisher']) ? trim((string) $data['publisher']) : null) : ($existing->publisher ?? null),
                'publication_year' => array_key_exists('publication_year', $data) && $data['publication_year'] !== null && $data['publication_year'] !== '' ? (int) $data['publication_year'] : ($existing->publication_year ?? null),
                'language' => ! empty($data['language']) ? $data['language'] : ($existing->language ?? 'am'),
                'description' => array_key_exists('description', $data) ? (! empty($data['description']) ? trim((string) $data['description']) : null) : ($existing->description ?? null),
                'library_category_id' => $categoryId,
                'category' => 'books',
                'kind' => 'physical',
                'domain' => $domain,
                'code' => $code,
                'status' => $status,
                'quantity' => $qty,
                'available_quantity' => $available,
                'condition' => array_key_exists('condition', $data) ? (! empty($data['condition']) ? trim((string) $data['condition']) : null) : ($existing->condition ?? null),
                'location' => array_key_exists('location', $data) ? (! empty($data['location']) ? trim((string) $data['location']) : null) : ($existing->location ?? null),
                'notes' => array_key_exists('notes', $data) ? (! empty($data['notes']) ? trim((string) $data['notes']) : null) : ($existing->notes ?? null),
                'updated_by' => $actx['auth']->id,
                'updated_at' => now(),
            ];

            if ($id) {
                DB::table($table)->where('id', $id)->update($row);
                Audit::log($actx, 'library.physical_book_update', 'book', $id, ['name' => $name, 'status' => $status], inTrx: true);
                $bookId = $id;
            } else {
                $row['created_by'] = $actx['auth']->id;
                $row['created_at'] = now();
                $bookId = DB::table($table)->insertGetId($row);
                Audit::log($actx, 'library.physical_book_create', 'book', $bookId, ['name' => $name, 'status' => $status], inTrx: true);
            }

            return self::book($actx['auth'], $bookId);
        });
    }

    public static function uploadDigitalBookFile(array $actx, int $id, \Illuminate\Http\UploadedFile $file): array
    {
        $table = self::bookTable();
        $book = DB::table($table)->where('id', $id)->whereNull('deleted_at')->first();
        if (! $book) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');

        $saved = Storage::save('book', Storage::FOLDERS['BOOKS'], $file);
        $oldFile = $book->file_path;

        DB::table($table)->where('id', $id)->update([
            'file_path' => $saved['path'],
            'file_mime' => $saved['mime'],
            'file_size' => $saved['size'],
            'kind' => 'digital',
            'updated_by' => $actx['auth']->id,
            'updated_at' => now(),
        ]);

        try {
            MediaProcessing::renderPdfPagesToWebp(
                Storage::resolveInside($saved['path']),
                'pdf_pages/book_' . $id,
                'private',
                150,
                85,
                'item',
                $id
            );
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Book PDF rendering error: ' . $e->getMessage());
        }

        Audit::log($actx, 'library.digital_book_file_replace', 'book', $id, ['size' => $saved['size']]);
        if ($oldFile && $oldFile !== $saved['path']) {
            Storage::remove($oldFile);
        }

        return self::book($actx['auth'], $id);
    }

    public static function uploadBookCover(array $actx, int $id, \Illuminate\Http\UploadedFile $file): array
    {
        $table = self::bookTable();
        $book = DB::table($table)->where('id', $id)->whereNull('deleted_at')->first();
        if (! $book) throw ApiError::notFound('BOOK_NOT_FOUND', 'Book not found');

        $saved = Storage::save('image', Storage::FOLDERS['ITEM_IMAGES'], $file);
        $oldImage = $book->image;

        DB::table($table)->where('id', $id)->update([
            'image' => $saved['path'],
            'updated_by' => $actx['auth']->id,
            'updated_at' => now(),
        ]);

        Audit::log($actx, 'library.book_cover_replace', 'book', $id, ['image' => 'replaced']);
        if ($oldImage && $oldImage !== $saved['path']) {
            Storage::remove($oldImage);
        }

        return self::book($actx['auth'], $id);
    }
}
