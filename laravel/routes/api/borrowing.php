<?php

use App\Mz\Auth\Audit;
use App\Mz\Http\Ctx;
use App\Mz\Http\Middleware;
use App\Mz\Http\Upload;
use App\Mz\Services\Borrowings;
use App\Mz\Services\Items;
use App\Mz\Services\Settings;
use App\Mz\Support\BorrowSchemas;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// /items, /borrowings and /fines (port of borrowing.routes.js).
Route::prefix('items')->middleware('mz')->group(function () {
    $itemSchema = fn () => Z::object([
        'name' => V::text(1, 200),
        'author' => V::optionalText(200),
        'subtitle' => V::optionalText(200),
        'publisher' => V::optionalText(200),
        'publication_year' => Z::number()->int()->min(1000)->max(2100)->nullable()->optional(),
        'language' => Z::string()->trim()->max(10)->optional(),
        'library_category_id' => V::id()->nullable()->optional(),
        'kind' => Z::enum(['physical', 'digital'])->optional(),
        // Empty: generated from the department and category (e.g. FIN-EQ-0004).
        'code' => Z::string()->trim()->max(60)->regex('#^([A-Za-z0-9_./-]+)?$#', 'INVALID_CODE')->optional(),
        'category' => V::optionalText(100),
        'domain' => Z::enum(['mezmur', 'timhirt'])->optional(),
        'description' => V::optionalText(1000),
        'quantity' => Z::number()->int()->min(0)->max(100000),
        'condition' => V::optionalText(100),
        'status' => Z::enum(['active', 'inactive', 'retired'])->optional(),
        'location' => V::optionalText(200),
        'notes' => V::optionalText(1000),
        'department_id' => V::id()->nullable()->optional(),
        'direct_borrowable' => Z::boolean()->optional(),
        'max_quantity' => Z::number()->int()->min(1)->max(100000)->nullable()->optional(),
        'max_days' => Z::number()->int()->min(1)->max(365)->nullable()->optional(),
        'renewable' => Z::boolean()->optional(),
    ]);
    // Anyone issuing borrowings or requesting property browses items.
    $readItems = function () {
        $a = Ctx::auth();
        if (! ($a->can('items.manage') || $a->can('property.request') || $a->can('property.review'))) Middleware::requireAll('borrowing.manage');
    };
    Route::get('/', function () use ($readItems) {
        $readItems();
        $q = Ctx::q();
        $direct = ($q['direct'] ?? null) === 'true' ? true : (($q['direct'] ?? null) === 'false' ? false : null);
        $filter = [
            'q' => $q['q'] ?? null,
            'category' => $q['category'] ?? null,
            'status' => $q['status'] ?? null,
            'available' => ($q['available'] ?? null) === 'true',
            'domain' => in_array($q['domain'] ?? null, ['mezmur', 'timhirt'], true) ? $q['domain'] : null,
            'department_id' => (int) ($q['department_id'] ?? 0) ?: null,
            'kind' => in_array($q['kind'] ?? null, ['physical', 'digital'], true) ? $q['kind'] : null,
        ];
        if ($direct !== null) $filter['direct'] = $direct;
        return Http::page(Items::list($filter, Page::params($q)));
    });
    Route::get('categories', function () use ($readItems) {
        $readItems();
        return Http::ok(Items::categories((bool) (Ctx::q()['all'] ?? false) && Ctx::auth()->can('items.manage')));
    });
    $categorySchema = fn () => Z::object([
        'key' => Z::string()->trim()->max(40)->regex('/^[a-z0-9_]+$/', 'INVALID_KEY')->optional(),
        'name' => V::text(1, 100)->optional(),
        'name_en' => V::optionalText(100),
        'code' => Z::string()->trim()->min(1)->max(6)->regex('/^[A-Za-z0-9]+$/', 'INVALID_CODE')->optional(),
        'sort_order' => Z::number()->int()->min(0)->max(999)->optional(),
        'is_active' => Z::boolean()->optional(),
    ])->strict();
    Route::post('categories', fn () => Http::created(Items::saveCategory(Ctx::actx(), null, Ctx::body($categorySchema()))))->middleware('mz:all,items.manage');
    Route::patch('categories/{key}', fn (string $key) => Http::ok(Items::saveCategory(Ctx::actx(), $key, Ctx::body($categorySchema()))))->middleware('mz:all,items.manage');
    Route::delete('categories/{key}', fn (string $key) => Http::ok(Items::deleteCategory(Ctx::actx(), $key)))->middleware('mz:all,items.manage');
    // The code the server would give a new item (shown in the form before saving).
    Route::get('next-code', function () {
        $q = Ctx::q();
        return Http::ok(['code' => Items::nextCode((int) ($q['department_id'] ?? 0) ?: null, $q['category'] ?? null)]);
    })->middleware('mz:all,items.manage');
    // Inventory history (changes, borrowings / returns with conditions, department requests).
    Route::get('{id}/history', fn () => Http::ok(Items::history(Ctx::id())))->middleware('mz:any,items.manage,borrowing.manage,property.review');
    Route::get('{id}', function () use ($readItems) {
        $readItems();
        return Http::ok(Items::get(Ctx::id()));
    });
    Route::post('/', fn () => Http::created(Items::create(Ctx::actx(), Ctx::body($itemSchema()))))->middleware('mz:all,items.manage');
    Route::patch('{id}', function () use ($itemSchema) {
        $id = Ctx::id();
        return Http::ok(Items::update(Ctx::actx(), $id, Ctx::body($itemSchema()->partial()->strict())));
    })->middleware('mz:all,items.manage');
    Route::delete('{id}', function () {
        Items::remove(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    })->middleware('mz:all,items.manage');
    Route::post('{id}/file', function () {
        $id = Ctx::id();
        return Http::ok(Items::setFile(Ctx::actx(), $id, Upload::single('book')));
    })->middleware('mz:all,items.manage');
    Route::post('{id}/image', function () {
        $id = Ctx::id();
        return Http::ok(Items::setImage(Ctx::actx(), $id, Upload::single('image')));
    })->middleware('mz:all,items.manage');
});

Route::prefix('borrowings')->middleware('mz')->group(function () {
    $manage = 'mz:all,borrowing.manage';
    Route::get('me', function () {
        $q = Ctx::q();
        $status = in_array($q['status'] ?? null, ['open', 'returned', 'lost', 'overdue'], true) ? $q['status'] : null;
        $domain = in_array($q['domain'] ?? null, ['mezmur', 'timhirt'], true) ? $q['domain'] : null;
        return Http::page(Borrowings::listForUser(Ctx::auth()->id, ['status' => $status, 'domain' => $domain], Page::params($q)));
    });
    Route::get('me/{id}', fn () => Http::ok(Borrowings::getForUser(Ctx::auth()->id, Ctx::id())));
    Route::get('{id}/signature', function () {
        $abs = Borrowings::signatureFile(Ctx::auth(), Ctx::id());
        return response()->file($abs, ['Cache-Control' => 'private, no-store']);
    });

    Route::get('/', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'status' => Z::enum(['open', 'overdue', 'pending', 'active', 'returned', 'partially_returned', 'lost', 'rejected'])->optional(),
            'user_id' => Z::coerceNumber()->int()->positive()->optional(),
            'item_id' => Z::coerceNumber()->int()->positive()->optional(),
            'batch_id' => Z::coerceNumber()->int()->positive()->optional(),
            'due_from' => V::dateOnly()->optional(),
            'due_to' => V::dateOnly()->optional(),
            'fine_status' => Z::enum(['none', 'pending', 'paid', 'waived'])->optional(),
            'domain' => Z::enum(['mezmur', 'timhirt'])->optional(),
            'department_id' => Z::coerceNumber()->int()->positive()->optional(),
            'category' => Z::string()->trim()->max(60)->optional(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(Borrowings::adminList($q, $page));
    })->middleware($manage);
    Route::get('return-conditions', fn () => Http::ok(Borrowings::listConditions((Ctx::q()['all'] ?? null) === 'true' && Ctx::auth()->can('borrowing.manage'))));
    Route::post('return-conditions', function () {
        $b = Ctx::body(Z::object([
            'label' => V::text(1, 100),
            'marks_lost' => Z::boolean()->default(false),
            'restock' => Z::boolean()->default(true),
            'display_order' => Z::number()->int()->min(0)->default(0),
            'is_active' => Z::boolean()->default(true),
        ]));
        return Http::created(Borrowings::upsertCondition(Ctx::actx(), null, $b));
    })->middleware($manage);
    Route::patch('return-conditions/{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'label' => V::text(1, 100)->optional(),
            'marks_lost' => Z::boolean()->optional(),
            'restock' => Z::boolean()->optional(),
            'display_order' => Z::number()->int()->min(0)->optional(),
            'is_active' => Z::boolean()->optional(),
        ])->strict());
        return Http::ok(Borrowings::upsertCondition(Ctx::actx(), $id, $b));
    })->middleware($manage);

    Route::get('direct-policy', fn () => Http::ok(Settings::directBorrowingPolicy()))->middleware($manage);
    Route::put('direct-policy', function () {
        $b = Ctx::body(Settings::schema('borrowing.direct'));
        $before = Settings::directBorrowingPolicy();
        $saved = Settings::set('borrowing.direct', $b, Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'borrowing.direct', 'before' => $before, 'after' => $saved]);
        return Http::ok($saved);
    })->middleware('mz:all,borrowing.configure');
    Route::get('{id}', fn () => Http::ok(Borrowings::adminGet(Ctx::id())))->middleware($manage);
    Route::post('{id}/approve', fn () => Http::ok(Borrowings::approve(Ctx::actx(), Ctx::id())))->middleware('mz:all,borrowing.approve');
    Route::post('{id}/reject', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => V::text(3, 500)]));
        return Http::ok(Borrowings::reject(Ctx::actx(), $id, $b['reason']));
    })->middleware('mz:all,borrowing.approve');
    Route::post('{id}/renew', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['due_on' => V::dateOnly(), 'reason' => V::optionalText(500)])->strict());
        return Http::ok(Borrowings::renew(Ctx::actx(), $id, $b['due_on'], $b['reason'] ?? null));
    })->middleware($manage);
    Route::post('/', fn () => Http::created(Borrowings::create(Ctx::actx(), Ctx::body(BorrowSchemas::create()))))->middleware($manage);
    Route::post('bulk', function () {
        $b = Ctx::body(Z::object([
            'target' => V::bulkTarget(),
            'items' => Z::array(Z::object(['item_id' => V::id(), 'quantity' => Z::number()->int()->min(1)->max(1000), 'issue_condition' => V::optionalText(100)]))->min(1)->max(20),
            'borrowed_on' => V::dateOnly()->optional(),
            'due_on' => V::dateOnly()->optional(),
            'loan_days' => Z::number()->int()->min(0)->max(365)->optional(),
            'notes' => V::optionalText(500),
            'batch_notes' => V::optionalText(500),
            'signatures' => Z::record(BorrowSchemas::signature(), Z::string()->regex('/^\d+$/'))->optional(),
        ])
            ->refine(fn ($v) => ! (isset($v['due_on'], $v['borrowed_on'])) || $v['due_on'] >= $v['borrowed_on'], ['message' => 'DEADLINE_BEFORE_BORROW', 'path' => ['due_on']])
            ->refine(fn ($v) => count(array_unique(array_column($v['items'], 'item_id'))) === count($v['items']), ['message' => 'DUPLICATE_ITEM', 'path' => ['items']]));
        return Http::created(Borrowings::bulkCreate(Ctx::actx(), $b));
    })->middleware($manage);
    Route::post('{id}/signature', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['signature' => BorrowSchemas::signature()]));
        return Http::ok(Borrowings::addSignature(Ctx::actx(), $id, $b['signature']));
    })->middleware($manage);
    Route::post('{id}/return', function () {
        $id = Ctx::id();
        return Http::ok(Borrowings::returnItem(Ctx::actx(), $id, Ctx::body(Z::object(BorrowSchemas::returnShape()))));
    })->middleware($manage);

    $fines = 'mz:all,fines.manage';
    Route::put('{id}/fine', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['amount' => Z::number()->min(0, 'NEGATIVE_AMOUNT')->max(1000000), 'reason' => V::text(3, 500)]));
        return Http::ok(Borrowings::overrideFine(Ctx::actx(), $id, $b['amount'], $b['reason']));
    })->middleware($fines);
    Route::delete('{id}/fine', fn () => Http::ok(Borrowings::clearFineOverride(Ctx::actx(), Ctx::id())))->middleware($fines);
    Route::post('{id}/fine/status', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['status' => Z::enum(['pending', 'paid', 'waived'])]));
        return Http::ok(Borrowings::setFineStatus(Ctx::actx(), $id, $b['status']));
    })->middleware($fines);
});

Route::prefix('fines')->middleware('mz')->group(function () {
    Route::get('policy', fn () => Http::ok(Settings::get('fines.policy')));
    Route::put('policy', function () {
        $b = Ctx::body(Settings::schema('fines.policy'));
        $before = Settings::get('fines.policy');
        $after = Settings::set('fines.policy', $b, Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::FINE_POLICY, 'setting', null, ['before' => $before, 'after' => $after]);
        return Http::ok($after);
    })->middleware('mz:all,fines.manage');
    Route::get('summary', fn () => Http::ok(Borrowings::fineSummary()))->middleware('mz:all,fines.manage');
});
