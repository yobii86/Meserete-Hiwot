<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Categories;
use App\Mz\Services\Mezmurs;
use App\Mz\Support\ContentSchemas as CS;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Categories, Mezmurs, favorites and downloads (port of categories / mezmurs / library routes).
$canManageCategories = fn () => (bool) (Ctx::authOrNull()?->isAdmin && Ctx::authOrNull()->can('categories.manage'));
$pageOf = fn (array $q) => Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);

Route::prefix('categories')->group(function () use ($canManageCategories, $pageOf) {
    Route::get('/', fn () => Http::ok(Categories::tree((Ctx::q()['include_inactive'] ?? null) === 'true' && $canManageCategories())))->middleware('mz:optional');
    Route::get('{id}', fn () => Http::ok(Categories::detail(Ctx::id(), $canManageCategories())))->middleware('mz:optional');
    Route::get('{id}/mezmurs', function () use ($pageOf) {
        $id = Ctx::id();
        $q = Ctx::query(CS::mezmurListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit']);
        Categories::detail($id); // 404 for inactive / missing categories
        return Http::page(Mezmurs::list(Ctx::authOrNull(), ['category_id' => $id] + $q, $page));
    })->middleware('mz:optional');

    Route::middleware(['mz', 'mz:all,categories.manage'])->group(function () {
        Route::post('/', fn () => Http::created(Categories::create(Ctx::actx(), Ctx::body(CS::categoryCreate()))));
        Route::post('reorder', function () {
            Categories::reorder(Ctx::actx(), Ctx::body(CS::categoryReorder())['items']);
            return Http::ok(null, null, 'Reordered');
        });
        Route::patch('{id}', function () {
            $id = Ctx::id();
            return Http::ok(Categories::update(Ctx::actx(), $id, Ctx::body(CS::categoryUpdate())));
        });
        Route::delete('{id}', function () {
            Categories::remove(Ctx::actx(), Ctx::id());
            return Http::ok(null, null, 'Deleted');
        });
        Route::put('{id}/today', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['today' => Z::boolean()]));
            Categories::setToday(Ctx::actx(), $id, $b['today']);
            return Http::ok(Categories::detail($id, true));
        });
        Route::post('{id}/image', function () {
            $id = Ctx::id();
            return Http::ok(Categories::setImage(Ctx::actx(), $id, Upload::single('image')));
        });
        Route::delete('{id}/image', function () {
            Categories::removeImage(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
    });
});

Route::prefix('mezmurs')->group(function () use ($pageOf) {
    Route::get('/', function () use ($pageOf) {
        $q = Ctx::query(CS::mezmurListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit'], $q['status']);
        return Http::page(Mezmurs::list(Ctx::authOrNull(), $q, $page));
    })->middleware('mz:optional');
    Route::post('changes', fn () => Http::ok(Mezmurs::changes(Ctx::auth(), Ctx::body(CS::mezmurChanges())['held'])))->middleware('mz');
    Route::get('lyrics-pack', function () {
        $q = Ctx::q();
        $limit = min((int) ($q['limit'] ?? 0) ?: 200, 200);
        return Http::page(Mezmurs::lyricsPack(Ctx::auth(), Page::params(['page' => $q['page'] ?? null, 'limit' => $limit])));
    })->middleware('mz');

    Route::get('admin/list', function () use ($pageOf) {
        $q = Ctx::query(CS::mezmurListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit']);
        return Http::page(Mezmurs::list(Ctx::auth(), $q, $page, true));
    })->middleware(['mz', 'mz:all,mezmurs.view']);
    Route::get('admin/{id}', fn () => Http::ok(Mezmurs::detail(Ctx::id(), Ctx::auth(), true, false)))->middleware(['mz', 'mz:all,mezmurs.view']);

    Route::get('{id}/stream.mp3', fn () => Mezmurs::streamAudio(Ctx::id()))->where('id', '[0-9]+')->middleware('mz:optional');
    Route::get('{id}/stream', fn () => Mezmurs::streamAudio(Ctx::id()))->where('id', '[0-9]+')->middleware('mz:optional');
    Route::get('{id}', fn () => Http::ok(Mezmurs::detail(Ctx::id(), Ctx::authOrNull())))->where('id', '[0-9]+')->middleware('mz:optional');

    Route::post('/', fn () => Http::created(Mezmurs::create(Ctx::actx(), Ctx::body(CS::mezmurCreate()))))->middleware(['mz', 'mz:all,mezmurs.create']);
    Route::patch('{id}', function () {
        $id = Ctx::id();
        return Http::ok(Mezmurs::update(Ctx::actx(), $id, Ctx::body(CS::mezmurUpdate())));
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::delete('{id}', function () {
        Mezmurs::remove(Ctx::actx(), Ctx::id());
        return Http::ok(null, null, 'Deleted');
    })->middleware(['mz', 'mz:all,mezmurs.delete']);
    Route::post('bulk/category', function () {
        $b = Ctx::body(Z::object(['ids' => Z::array(V::id())->min(1)->max(1000), 'category_id' => V::id()->nullable()]));
        return Http::ok(Mezmurs::bulkAssignCategory(Ctx::actx(), $b['ids'], $b['category_id']));
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::put('{id}/today', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['today' => Z::boolean()]));
        Mezmurs::setToday(Ctx::actx(), $id, $b['today']);
        return Http::ok(Mezmurs::detail($id, Ctx::auth(), true, false));
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::post('{id}/audio', function () {
        $id = Ctx::id();
        $file = Upload::single('audio');
        $d = Ctx::input()['duration_sec'] ?? null;
        $dur = is_numeric($d) && (int) $d >= 0 ? (int) $d : null;
        return Http::ok(Mezmurs::setMedia(Ctx::actx(), $id, 'audio', $file, $dur));
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::delete('{id}/audio', function () {
        Mezmurs::removeMedia(Ctx::actx(), Ctx::id(), 'audio');
        return Http::ok(null);
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::post('{id}/cover', function () {
        $id = Ctx::id();
        return Http::ok(Mezmurs::setMedia(Ctx::actx(), $id, 'cover', Upload::single('image')));
    })->middleware(['mz', 'mz:all,mezmurs.update']);
    Route::delete('{id}/cover', function () {
        Mezmurs::removeMedia(Ctx::actx(), Ctx::id(), 'cover');
        return Http::ok(null);
    })->middleware(['mz', 'mz:all,mezmurs.update']);
});

Route::prefix('favorites')->middleware('mz')->group(function () {
    Route::get('/', function () {
        $q = Ctx::q();
        if (($q['ids_only'] ?? null) === 'true') return Http::ok(Mezmurs::favoriteIds(Ctx::auth()->id));
        return Http::page(Mezmurs::listFavorites(Ctx::auth(), Page::params($q)));
    });
    Route::put('{mezmurId}', function () {
        $id = Ctx::id('mezmurId');
        return Http::ok(['mezmur_id' => $id, 'is_favorite' => true, 'changed' => Mezmurs::addFavorite(Ctx::auth()->id, $id)]);
    });
    Route::delete('{mezmurId}', function () {
        $id = Ctx::id('mezmurId');
        return Http::ok(['mezmur_id' => $id, 'is_favorite' => false, 'changed' => Mezmurs::removeFavorite(Ctx::auth()->id, $id)]);
    });
});

Route::prefix('downloads')->middleware('mz')->group(function () {
    Route::get('/', fn () => Http::ok(Mezmurs::listDownloads(Ctx::auth()->id)));
    Route::put('{mezmurId}', function () {
        $id = Ctx::id('mezmurId');
        $b = Ctx::body(Z::object(['with_audio' => Z::boolean()->default(false)]));
        Mezmurs::recordDownload(Ctx::auth()->id, $id, $b['with_audio']);
        return Http::ok(Mezmurs::detail($id, Ctx::auth(), false, false));
    });
    Route::delete('{mezmurId}', function () {
        Mezmurs::removeDownload(Ctx::auth()->id, Ctx::id('mezmurId'));
        return Http::ok(null);
    });
});
