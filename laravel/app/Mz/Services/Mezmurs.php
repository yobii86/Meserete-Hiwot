<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Mezmurs, favorites and downloads (port of mezmurService.js). */
final class Mezmurs
{
    private static function excerpt(?string $lyrics): string
    {
        foreach (explode("\n", (string) $lyrics) as $l) {
            if (trim($l) !== '') {
                return mb_substr(trim($l), 0, 140);
            }
        }
        return '';
    }

    public static function serializeListItem(object $m): array
    {
        $baseUrl = rtrim((string) config('mz.public_base_url'), '/');
        $streamUrl = $m->audio_path ? ($baseUrl . '/api/v1/mezmurs/' . $m->id . '/stream.mp3') : null;
        $directUrl = $m->audio_path ? Storage::url($m->audio_path) : null;
        $out = [
            'id' => $m->id,
            'title' => $m->title,
            'excerpt' => self::excerpt($m->lyrics_head ?? ($m->lyrics ?? null)),
            'category' => $m->category_id ? ['id' => $m->category_id, 'name' => $m->category_name] : null,
            'cover_url' => Storage::url($m->cover_image),
            'has_audio' => (bool) $m->audio_path,
            // Lets the app queue the next / previous Mezmur straight from a list.
            'audio_url' => $streamUrl,
            'stream_url' => $streamUrl,
            'direct_audio_url' => $directUrl,
            'audio_duration_sec' => $m->audio_duration_sec,
            'is_featured' => (bool) $m->is_featured,
            'is_today' => $m->study_on ? Dates::toDateOnly($m->study_on) === Dates::todayLocal() : false,
        ];
        if (property_exists($m, 'is_favorite')) {
            $out['is_favorite'] = (bool) $m->is_favorite;
        }
        $out += [
            'favorite_count' => $m->favorite_count,
            'status' => $m->status,
            'content_version' => $m->content_version,
            'published_at' => $m->published_at,
            'updated_at' => $m->updated_at,
        ];
        return $out;
    }

    private static function tagsFor(array $ids): array
    {
        if (! $ids) return [];
        $out = [];
        foreach (DB::table('mezmur_tags as mt')->join('tags as t', 't.id', '=', 'mt.tag_id')->whereIn('mt.mezmur_id', $ids)->select('mt.mezmur_id', 't.name')->get() as $r) {
            $out[$r->mezmur_id][] = $r->name;
        }
        return $out;
    }

    private static function serializeFull(object $m, array $tags = []): array
    {
        $baseUrl = rtrim((string) config('mz.public_base_url'), '/');
        $streamUrl = $m->audio_path ? ($baseUrl . '/api/v1/mezmurs/' . $m->id . '/stream.mp3') : null;
        $directUrl = $m->audio_path ? Storage::url($m->audio_path) : null;
        return self::serializeListItem($m) + [
            'lyrics' => $m->lyrics,
            'lrc' => $m->lrc ?? null,
            'description' => $m->description,
            'tags' => $tags,
            'audio' => $m->audio_path ? [
                'url' => $streamUrl,
                'stream_url' => $streamUrl,
                'direct_url' => $directUrl,
                'mime' => $m->audio_mime ?: 'audio/mpeg',
                'size' => $m->audio_size,
                'duration_sec' => $m->audio_duration_sec,
            ] : null,
            'view_count' => $m->view_count,
            'download_count' => $m->download_count,
            'youtube_url' => $m->youtube_url ?? null,
            'created_at' => $m->created_at,
        ];
    }

    /** Boolean-mode FULLTEXT: every word required, prefix-matched. */
    public static function ftQuery(string $q): string
    {
        $words = array_values(array_filter(preg_split('/\s+/u', preg_replace('/[+\-<>()~*"@]/', ' ', $q))));
        return implode(' ', array_map(fn ($w) => "+$w*", array_slice($words, 0, 8)));
    }

    private static function base(?AuthContext $auth, bool $admin = false): Builder
    {
        $qb = DB::table('mezmurs as m')->leftJoin('categories as c', 'c.id', '=', 'm.category_id')->whereNull('m.deleted_at')
            ->select('m.id', 'm.title', DB::raw('LEFT(m.lyrics, 400) as lyrics_head'), 'm.category_id', 'c.name as category_name', 'm.cover_image', 'm.audio_path', 'm.audio_duration_sec', 'm.is_featured', 'm.study_on', 'm.favorite_count', 'm.status', 'm.content_version', 'm.published_at', 'm.updated_at');
        if (! $admin) $qb->where('m.status', 'published');
        if ($auth) $qb->selectRaw('EXISTS(SELECT 1 FROM favorites f WHERE f.user_id = ? AND f.mezmur_id = m.id) as is_favorite', [$auth->id]);
        return $qb;
    }

    public static function list(?AuthContext $auth, array $filter, array $page, bool $admin = false): array
    {
        $qb = self::base($auth, $admin);
        if ($admin && ! empty($filter['status'])) $qb->where('m.status', $filter['status']);
        if (! empty($filter['category_id'])) {
            $ids = ($filter['include_subcategories'] ?? null) === false ? [$filter['category_id']] : Categories::descendantIds($filter['category_id'], ! $admin);
            $qb->whereIn('m.category_id', $ids);
        }
        if (! empty($filter['featured'])) $qb->where('m.is_featured', true);
        if (array_key_exists('has_audio', $filter)) $filter['has_audio'] ? $qb->whereNotNull('m.audio_path') : $qb->whereNull('m.audio_path');
        if (! empty($filter['tag'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('mezmur_tags as mt')->join('tags as t', 't.id', '=', 'mt.tag_id')->whereColumn('mt.mezmur_id', 'm.id')->where('t.name', $filter['tag']));
        }
        if (! empty($filter['ids'])) $qb->whereIn('m.id', $filter['ids']);
        $q = $filter['q'] ?? null;
        $ft = $q ? self::ftQuery($q) : '';
        if ($q) {
            $qb->where(function ($w) use ($ft, $q) {
                if ($ft) $w->whereRaw('MATCH(m.title, m.lyrics) AGAINST (? IN BOOLEAN MODE)', [$ft]);
                $w->orWhere('m.title', 'like', addcslashes($q, '%_') . '%');
            });
        }
        $sort = $filter['sort'] ?? ($q ? 'relevance' : 'recent');
        if ($sort === 'popular') $qb->orderByDesc('m.favorite_count')->orderByDesc('m.view_count');
        elseif ($sort === 'title') $qb->orderBy('m.title');
        elseif ($sort === 'relevance' && $q && $ft) $qb->orderByRaw('MATCH(m.title, m.lyrics) AGAINST (? IN BOOLEAN MODE) DESC', [$ft]);
        else $qb->orderByDesc($admin ? 'm.updated_at' : 'm.published_at')->orderByDesc('m.id');
        $res = Page::paginate($qb, $page);
        if ($auth?->accountType === 'user' && $q && $page['page'] === 1 && ($filter['log'] ?? null) !== false) {
            Activity::track($auth->id, Activity::MEZMUR_SEARCH, metadata: ['q' => mb_substr($q, 0, 100), 'results' => $res['meta']['total']]);
        }
        return ['items' => array_map(fn ($m) => self::serializeListItem($m), $res['items']), 'meta' => $res['meta']];
    }

    private static function loadFull(int $id, ?AuthContext $auth, bool $admin = false): object
    {
        $m = self::base($auth, $admin)->where('m.id', $id)
            ->addSelect('m.lyrics', 'm.lrc', 'm.description', 'm.audio_mime', 'm.audio_size', 'm.view_count', 'm.download_count', 'm.created_at', 'm.youtube_url')->first();
        if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
        return $m;
    }

    public static function detail(int $id, ?AuthContext $auth, bool $admin = false, bool $track = true): array
    {
        $m = self::loadFull($id, $auth, $admin);
        $tags = self::tagsFor([$id])[$id] ?? [];
        $out = self::serializeFull($m, $tags);
        $out['breadcrumb'] = $m->category_id ? Categories::ancestors($m->category_id) : [];
        if ($auth) {
            $out['is_downloaded'] = DB::table('downloads')->where(['user_id' => $auth->id, 'mezmur_id' => $id])->exists();
        }
        // The category's Mezmurs — this exact category and its subcategories only, never others —
        // in folder order (the category itself, then each subcategory), then by title. `queue`
        // (this Mezmur included) is what the player plays, so next / previous stay in the category.
        $queue = collect();
        if ($m->category_id) {
            $queue = self::base($auth)->whereIn('m.category_id', Categories::descendantIds((int) $m->category_id, ! $admin))
                ->orderByRaw('m.category_id = ? DESC', [$m->category_id])->orderBy('c.display_order')->orderBy('c.name')->orderBy('m.title')
                ->limit(300)->get();
        }
        $out['queue'] = $queue->map(fn ($r) => self::serializeListItem($r))->all();
        $out['related'] = array_values(array_filter($out['queue'], fn ($r) => $r['id'] !== $id));
        if ($track && ! $admin) {
            DB::table('mezmurs')->where('id', $id)->increment('view_count');
            if ($auth?->accountType === 'user') Activity::track($auth->id, Activity::MEZMUR_VIEW, 'mezmur', $id);
        }
        return $out;
    }

    /** Offline sync: which held Mezmurs changed (full content) and which were removed. */
    public static function changes(AuthContext $auth, array $held): array
    {
        $ids = array_column($held, 'id');
        if (! $ids) return ['updated' => [], 'removed' => []];
        $rows = DB::table('mezmurs')->whereIn('id', $ids)->select('id', 'status', 'deleted_at', 'content_version')->get();
        $version = array_column($held, 'content_version', 'id');
        $alive = [];
        foreach ($rows as $r) {
            if ($r->status === 'published' && ! $r->deleted_at) $alive[$r->id] = $r;
        }
        $removed = array_values(array_filter($ids, fn ($id) => ! isset($alive[$id])));
        $stale = array_values(array_map(fn ($r) => $r->id, array_filter($alive, fn ($r) => $r->content_version > ($version[$r->id] ?? 0))));
        $updated = [];
        foreach (array_slice($stale, 0, 50) as $id) $updated[] = self::detail($id, $auth, false, false);
        return ['updated' => $updated, 'removed' => $removed, 'has_more' => count($stale) > 50];
    }

    // ------------------------------------------------------------------ admin
    private static function syncTags(int $mezmurId, ?array $names): void
    {
        if ($names === null) return;
        $clean = array_values(array_unique(array_filter(array_map('trim', $names), fn ($n) => $n !== '')));
        DB::table('mezmur_tags')->where('mezmur_id', $mezmurId)->delete();
        if (! $clean) return;
        DB::table('tags')->insertOrIgnore(array_map(fn ($n) => ['name' => $n], $clean));
        $tagIds = DB::table('tags')->whereIn('name', $clean)->pluck('id')->all();
        DB::table('mezmur_tags')->insert(array_map(fn ($t) => ['mezmur_id' => $mezmurId, 'tag_id' => $t], $tagIds));
    }

    /** Compare titles ignoring case and extra spaces ("ሰላም  ለኪ" = "ሰላም ለኪ"). */
    public static function normalizeTitle(string $t): string
    {
        return mb_strtolower(trim(preg_replace('/\s+/u', ' ', $t)));
    }

    /** Is [title] used by another (not deleted) Mezmur? */
    public static function titleTaken(string $title, ?int $exceptId = null): bool
    {
        $norm = self::normalizeTitle($title);
        // Portable (no REGEXP_REPLACE on MySQL 5.7): candidates without spaces, then the exact check.
        $q = DB::table('mezmurs')->whereNull('deleted_at')
            ->whereRaw("LOWER(REPLACE(REPLACE(REPLACE(REPLACE(title, ' ', ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) = ?", [preg_replace('/\s+/u', '', $norm)]);
        if ($exceptId) $q->where('id', '<>', $exceptId);
        foreach ($q->pluck('title') as $t) {
            if (self::normalizeTitle($t) === $norm) return true;
        }
        return false;
    }

    /** Mezmur titles are unique (never two Mezmurs with the same name). */
    private static function assertTitleFree(string $title, ?int $exceptId = null): void
    {
        if (self::titleTaken($title, $exceptId)) {
            throw ApiError::conflict('MEZMUR_TITLE_TAKEN', 'A Mezmur with this title already exists', [['field' => 'title', 'code' => 'MEZMUR_TITLE_TAKEN', 'message' => 'MEZMUR_TITLE_TAKEN']]);
        }
    }

    private static function assertCategory(?int $categoryId): void
    {
        if ($categoryId && ! DB::table('categories')->where('id', $categoryId)->exists()) throw ApiError::field('category_id', 'CATEGORY_NOT_FOUND');
    }

    public static function create(array $actx, array $input): array
    {
        // One title at a time: two administrators saving the same new title cannot both succeed.
        $id = \App\Mz\Db\Locks::waitFor('mz:mezmur-title', fn () => DB::transaction(function () use ($actx, $input) {
            self::assertCategory($input['category_id'] ?? null);
            self::assertTitleFree($input['title']);
            $newId = DB::table('mezmurs')->insertGetId([
                'title' => $input['title'],
                'lyrics' => $input['lyrics'],
                'lrc' => $input['lrc'] ?? null,
                'description' => $input['description'] ?? null,
                'category_id' => $input['category_id'] ?? null,
                'status' => $input['status'] ?? 'draft',
                'is_featured' => $input['is_featured'] ?? false,
                'audio_duration_sec' => $input['audio_duration_sec'] ?? null,
                'youtube_url' => $input['youtube_url'] ?? null,
                'published_at' => ($input['status'] ?? null) === 'published' ? DB::raw('NOW()') : null,
                'created_by' => $actx['auth']->id,
                'updated_by' => $actx['auth']->id,
            ]);
            self::syncTags($newId, $input['tags'] ?? null);
            Audit::log($actx, Audit::MEZMUR_CREATE, 'mezmur', $newId, ['title' => $input['title']], inTrx: true);
            return $newId;
        }));
        return self::detail($id, $actx['auth'], true, false);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        \App\Mz\Db\Locks::named('mz:mezmur-title', fn () => DB::transaction(function () use ($actx, $id, $input) {
            $m = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
            self::assertCategory($input['category_id'] ?? null);
            if (array_key_exists('title', $input)) self::assertTitleFree($input['title'], $id);
            $patch = ['updated_by' => $actx['auth']->id];
            foreach (['title', 'lyrics', 'lrc', 'description', 'category_id', 'status', 'is_featured', 'audio_duration_sec', 'youtube_url'] as $k) {
                if (array_key_exists($k, $input)) $patch[$k] = $input[$k];
            }
            if (($input['status'] ?? null) === 'published' && ! $m->published_at) $patch['published_at'] = DB::raw('NOW()');
            $changed = array_key_exists('tags', $input);
            foreach (['title', 'lyrics', 'lrc', 'category_id', 'youtube_url'] as $k) {
                if (array_key_exists($k, $input) && $input[$k] !== $m->{$k}) $changed = true;
            }
            if ($changed) $patch['content_version'] = $m->content_version + 1;
            DB::table('mezmurs')->where('id', $id)->update($patch);
            self::syncTags($id, $input['tags'] ?? null);
            Audit::log($actx, Audit::MEZMUR_UPDATE, 'mezmur', $id, ['fields' => array_values(array_filter(array_keys($patch), fn ($k) => $k !== 'updated_by'))], inTrx: true);
        }));
        return self::detail($id, $actx['auth'], true, false);
    }

    public static function remove(array $actx, int $id): void
    {
        DB::transaction(function () use ($actx, $id) {
            $m = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->first(['id', 'title']);
            if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
            DB::table('mezmurs')->where('id', $id)->update(['deleted_at' => DB::raw('NOW()'), 'status' => 'archived', 'updated_by' => $actx['auth']->id, 'content_version' => DB::raw('content_version + 1')]);
            Audit::log($actx, Audit::MEZMUR_DELETE, 'mezmur', $id, ['title' => $m->title], inTrx: true);
        });
    }

    public static function setMedia(array $actx, int $id, string $kind, UploadedFile $file, ?int $durationSec = null): array
    {
        $m = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->first(['id', 'cover_image', 'audio_path']);
        if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
        if ($kind === 'audio') {
            $saved = Storage::save('audio', Storage::FOLDERS['MEZMUR_AUDIO'], $file);
            $old = $m->audio_path;
            DB::table('mezmurs')->where('id', $id)->update(['audio_path' => $saved['path'], 'audio_mime' => $saved['mime'], 'audio_size' => $saved['size'], 'audio_duration_sec' => $durationSec, 'updated_by' => $actx['auth']->id, 'content_version' => DB::raw('content_version + 1')]);
        } else {
            $saved = Storage::save('image', Storage::FOLDERS['MEZMUR_COVERS'], $file);
            $old = $m->cover_image;
            DB::table('mezmurs')->where('id', $id)->update(['cover_image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        }
        Audit::log($actx, Audit::MEZMUR_MEDIA, 'mezmur', $id, ['kind' => $kind, 'op' => 'set']);
        Storage::remove($old);
        return self::detail($id, $actx['auth'], true, false);
    }

    public static function removeMedia(array $actx, int $id, string $kind): void
    {
        $m = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->first(['id', 'cover_image', 'audio_path']);
        if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
        if ($kind === 'audio') {
            DB::table('mezmurs')->where('id', $id)->update(['audio_path' => null, 'audio_mime' => null, 'audio_size' => null, 'audio_duration_sec' => null, 'content_version' => DB::raw('content_version + 1')]);
            Storage::remove($m->audio_path);
        } else {
            DB::table('mezmurs')->where('id', $id)->update(['cover_image' => null]);
            Storage::remove($m->cover_image);
        }
        Audit::log($actx, Audit::MEZMUR_MEDIA, 'mezmur', $id, ['kind' => $kind, 'op' => 'remove']);
    }

    public static function bulkAssignCategory(array $actx, array $ids, ?int $categoryId): array
    {
        return DB::transaction(function () use ($actx, $ids, $categoryId) {
            self::assertCategory($categoryId);
            $n = DB::table('mezmurs')->whereIn('id', $ids)->whereNull('deleted_at')->update(['category_id' => $categoryId, 'updated_by' => $actx['auth']->id, 'content_version' => DB::raw('content_version + 1')]);
            Audit::log($actx, Audit::MEZMUR_UPDATE, 'mezmur', null, ['bulk_category' => $categoryId, 'ids' => $ids], inTrx: true);
            return ['updated' => $n];
        });
    }

    // ------------------------------------------------------------------ favorites & downloads
    private static function assertPublished(int $id): object
    {
        $m = DB::table('mezmurs')->where(['id' => $id, 'status' => 'published'])->whereNull('deleted_at')->first(['id', 'content_version']);
        if (! $m) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
        return $m;
    }

    public static function addFavorite(int $userId, int $mezmurId): bool
    {
        return DB::transaction(function () use ($userId, $mezmurId) {
            self::assertPublished($mezmurId);
            $n = DB::table('favorites')->insertOrIgnore(['user_id' => $userId, 'mezmur_id' => $mezmurId]);
            if ($n) {
                DB::table('mezmurs')->where('id', $mezmurId)->increment('favorite_count');
                Activity::track($userId, Activity::FAVORITE_ADD, 'mezmur', $mezmurId, inTrx: true);
            }
            return (bool) $n;
        });
    }

    public static function removeFavorite(int $userId, int $mezmurId): bool
    {
        return DB::transaction(function () use ($userId, $mezmurId) {
            $n = DB::table('favorites')->where(['user_id' => $userId, 'mezmur_id' => $mezmurId])->delete();
            if ($n) {
                DB::table('mezmurs')->where('id', $mezmurId)->where('favorite_count', '>', 0)->decrement('favorite_count');
                Activity::track($userId, Activity::FAVORITE_REMOVE, 'mezmur', $mezmurId, inTrx: true);
            }
            return $n > 0;
        });
    }

    public static function listFavorites(AuthContext $auth, array $page): array
    {
        $qb = self::base($auth)->join('favorites as fav', fn ($j) => $j->on('fav.mezmur_id', '=', 'm.id')->where('fav.user_id', '=', $auth->id))
            ->addSelect('fav.created_at as favorited_at')->orderByDesc('fav.created_at');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($m) => self::serializeListItem($m) + ['favorited_at' => $m->favorited_at], $res['items']), 'meta' => $res['meta']];
    }

    public static function favoriteIds(int $userId): array
    {
        return DB::table('favorites')->where('user_id', $userId)->pluck('mezmur_id')->all();
    }

    public static function recordDownload(int $userId, int $mezmurId, bool $withAudio): void
    {
        $m = self::assertPublished($mezmurId);
        $existing = DB::table('downloads')->where(['user_id' => $userId, 'mezmur_id' => $mezmurId])->exists();
        DB::table('downloads')->upsert([['user_id' => $userId, 'mezmur_id' => $mezmurId, 'with_audio' => $withAudio, 'content_version' => $m->content_version]], ['user_id', 'mezmur_id'], ['with_audio' => $withAudio, 'content_version' => $m->content_version, 'downloaded_at' => DB::raw('NOW()')]);
        if (! $existing) DB::table('mezmurs')->where('id', $mezmurId)->increment('download_count');
        Activity::track($userId, Activity::DOWNLOAD, 'mezmur', $mezmurId, ['with_audio' => $withAudio]);
    }

    public static function removeDownload(int $userId, int $mezmurId): bool
    {
        $n = DB::table('downloads')->where(['user_id' => $userId, 'mezmur_id' => $mezmurId])->delete();
        if ($n) Activity::track($userId, Activity::DOWNLOAD_REMOVE, 'mezmur', $mezmurId);
        return $n > 0;
    }

    public static function listDownloads(int $userId): array
    {
        return DB::table('downloads as d')->join('mezmurs as m', 'm.id', '=', 'd.mezmur_id')->where('d.user_id', $userId)->orderByDesc('d.downloaded_at')
            ->select('d.mezmur_id', 'd.with_audio', 'd.content_version as downloaded_version', 'm.content_version as current_version', 'm.title', 'd.downloaded_at', 'm.status', 'm.deleted_at')
            ->get()->map(fn ($r) => [
                'mezmur_id' => $r->mezmur_id,
                'title' => $r->title,
                'with_audio' => (bool) $r->with_audio,
                'downloaded_at' => $r->downloaded_at,
                'is_stale' => $r->current_version > $r->downloaded_version,
                'is_available' => $r->status === 'published' && ! $r->deleted_at,
            ])->all();
    }

    public static function setToday(array $actx, int $id, bool $today): void
    {
        $n = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->update(['study_on' => $today ? Dates::todayLocal() : null, 'updated_by' => $actx['auth']->id]);
        if (! $n) throw ApiError::notFound('MEZMUR_NOT_FOUND', 'Mezmur not found');
        Audit::log($actx, Audit::MEZMUR_UPDATE, 'mezmur', $id, ['today' => $today]);
    }

    public static function todayList(?AuthContext $auth): array
    {
        return self::base($auth)->where('m.study_on', Dates::todayLocal())->orderBy('m.title')->get()->map(fn ($m) => self::serializeListItem($m))->all();
    }

    /** Every published Mezmur with full lyrics, paged (automatic offline lyrics). */
    public static function lyricsPack(?AuthContext $auth, array $page): array
    {
        $qb = self::base($auth)->addSelect('m.lyrics', 'm.lrc', 'm.description', 'm.audio_mime', 'm.audio_size', 'm.view_count', 'm.download_count', 'm.created_at', 'm.youtube_url')->orderBy('m.id');
        $res = Page::paginate($qb, $page);
        $tags = self::tagsFor(array_map(fn ($m) => $m->id, $res['items']));
        return ['items' => array_map(fn ($m) => self::serializeFull($m, $tags[$m->id] ?? []), $res['items']), 'meta' => $res['meta']];
    }

    /** Stream Mezmur audio supporting HTTP 206 byte-range seeking. */
    public static function streamAudio(int $id)
    {
        $m = DB::table('mezmurs')->where('id', $id)->whereNull('deleted_at')->first(['id', 'audio_path', 'audio_mime']);
        if (! $m || ! $m->audio_path) {
            throw ApiError::notFound('AUDIO_NOT_FOUND', 'Audio not found');
        }

        try {
            $abs = Storage::resolveInside($m->audio_path);
        } catch (\Throwable) {
            throw ApiError::notFound('AUDIO_NOT_FOUND', 'Audio file not found');
        }

        // Check companion .mp3 if target is missing
        if (! file_exists($abs)) {
            $pathInfo = pathinfo($abs);
            $companionMp3 = $pathInfo['dirname'] . DIRECTORY_SEPARATOR . $pathInfo['filename'] . '.mp3';
            if (file_exists($companionMp3)) {
                $abs = $companionMp3;
                $m->audio_mime = 'audio/mpeg';
            } else {
                throw ApiError::notFound('AUDIO_NOT_FOUND', 'Audio file not found on disk');
            }
        }

        $mime = $m->audio_mime ?: 'audio/mpeg';
        $headers = [
            'Content-Type' => $mime,
            'Accept-Ranges' => 'bytes',
            'Cache-Control' => 'public, max-age=604800',
            'X-Content-Type-Options' => 'nosniff',
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Headers' => 'Range, Authorization, Content-Type',
            'Access-Control-Expose-Headers' => 'Content-Range, Content-Length, Accept-Ranges',
        ];

        return response()->file($abs, $headers);
    }
}
