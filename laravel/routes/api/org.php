<?php

use App\Mz\Auth\Catalog;
use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\ContributionReceipts;
use App\Mz\Services\DepartmentAdmins;
use App\Mz\Services\Departments;
use App\Mz\Services\Members;
use App\Mz\Services\Payments;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Departments, HR assignments, payments and member QR lookups (port of org.routes.js).
$period = fn () => Z::string()->regex('/^\d{4}-(0[1-9]|1[0-2])$/', 'INVALID_PERIOD');

Route::prefix('departments')->middleware('mz')->group(function () use ($period) {
    Route::get('led', fn () => Http::ok(Departments::ledBy(Ctx::auth()->id)));
    Route::get('{id}/participation', function () use ($period) {
        $id = Ctx::id();
        $q = Ctx::query(Z::object(['period' => $period()]));
        $admin = Ctx::auth()->can('hr.manage') || Ctx::auth()->can('selection.view');
        return Http::ok(Departments::participationSheet($id, $q['period'], $admin ? null : Ctx::auth()->id));
    });
    Route::put('{id}/participation', function () use ($period) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'period' => $period(),
            'entries' => Z::array(Z::object(['user_id' => V::id(), 'score' => Z::number()->min(0)->max(100)->nullable(), 'note' => V::optionalText(300)]))->min(1)->max(500),
        ])->strict());
        return Http::ok(Departments::saveParticipation(Ctx::actx(), $id, $b['period'], $b['entries']));
    });

    // ---- department administrators ----
    Route::get('admins', fn () => Http::ok(DepartmentAdmins::all()))->middleware('mz:all,admins.view');
    Route::get('admins/of-user/{id}', fn () => Http::ok(DepartmentAdmins::ofUser(Ctx::id())))->middleware('mz:all,admins.view');
    Route::put('admins/of-user/{id}/permissions', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'permissions' => Z::array(Z::enum(Catalog::allKeys()))->max(count(Catalog::allKeys())),
            // Permissions of their department roles taken away from this one person.
            'revoked_permissions' => Z::array(Z::enum(Catalog::allKeys()))->max(count(Catalog::allKeys()))->optional(),
            'reason' => V::optionalText(500),
        ])->strict());
        return Http::ok(DepartmentAdmins::setExtraPermissions(Ctx::actx(), $id, $b['permissions'], $b['reason'] ?? null, $b['revoked_permissions'] ?? null));
    })->middleware('mz:all,admins.manage');
    Route::get('{id}/admins', fn () => Http::ok(DepartmentAdmins::list(Ctx::id())))->middleware('mz:all,admins.view');
    Route::put('{id}/admins/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $b = Ctx::body(Z::object(['role_ids' => Z::array(V::id())->max(20), 'reason' => V::optionalText(500)])->strict());
        return Http::ok(DepartmentAdmins::setRoles(Ctx::actx(), $id, $uid, $b['role_ids'], $b['reason'] ?? null));
    })->middleware('mz:all,admins.manage');

    // ---- the 7 departments ----
    Route::get('/', function () {
        if (! Ctx::auth()->isAdmin) throw ApiError::forbidden();
        return Http::ok(Departments::list());
    });
    Route::patch('{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['description' => V::optionalText(1000), 'name_en' => V::optionalText(150)])->strict());
        return Http::ok(Departments::update(Ctx::actx(), $id, $b));
    })->middleware('mz:all,departments.manage');

    // ---- HR: members and the one leader ----
    Route::get('{id}/members', function () {
        $id = Ctx::id();
        $q = Ctx::q();
        return Http::page(Departments::members($id, is_string($q['q'] ?? null) ? $q['q'] : null, Page::params($q)));
    })->middleware('mz:all,hr.manage');
    Route::post('{id}/members', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['member_ids' => Z::array(V::id())->max(1000)->optional(), 'leader_id' => V::id()->optional()])->strict());
        return Http::ok(Departments::assign(Ctx::actx(), $id, $b['member_ids'] ?? [], $b['leader_id'] ?? null));
    })->middleware('mz:all,hr.manage');
    Route::patch('{id}/members/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $b = Ctx::body(Z::object(['role' => Z::enum(['member', 'leader'])]));
        return Http::ok(Departments::setRole(Ctx::actx(), $id, $uid, $b['role']));
    })->middleware('mz:all,hr.manage');
    Route::delete('{id}/members/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        Departments::unassign(Ctx::actx(), $uid, $id);
        return Http::ok(null);
    })->middleware('mz:all,hr.manage');
    Route::get('of-user/{id}', fn () => Http::ok(Departments::departmentsOf(Ctx::id())))->middleware('mz:all,hr.manage');
});

Route::prefix('payments')->middleware('mz')->group(function () use ($period) {
    $manage = 'mz:all,payments.manage';
    $view = 'mz:any,payments.view,payments.manage';
    $configure = 'mz:all,payments.configure';
    $memberType = fn () => Z::enum(['student', 'worker']);
    $paymentShape = fn () => [
        'user_id' => V::id(),
        'period' => $period(),
        'months' => Z::number()->int()->min(1)->max(12)->optional(),
        'method' => Z::enum(['cash', 'bank', 'telebirr', 'other'])->optional(),
        'reference' => V::optionalText(120),
        'paid_on' => V::dateOnly()->optional(),
        'note' => V::optionalText(500),
    ];
    $rateShape = fn () => [
        'member_type' => $memberType(),
        'monthly_amount' => Z::number()->min(0)->max(10000000),
        'currency' => Z::string()->trim()->min(1)->max(8)->optional(),
        'effective_from' => V::dateOnly()->optional(),
    ];

    Route::get('policy', fn () => Http::ok(Payments::policy()))->middleware($view);
    Route::put('policy', function () use ($period) {
        $b = Ctx::body(Z::object([
            'currency' => Z::string()->trim()->min(1)->max(8)->optional(),
            'start_period' => $period()->nullable()->optional(),
            'grace_days' => Z::number()->int()->min(0)->max(60)->optional(),
        ])->strict());
        return Http::ok(Payments::saveSettings(Ctx::actx(), $b));
    })->middleware($configure);
    Route::get('rates', fn () => Http::ok(Payments::rateHistory()))->middleware($view);
    Route::post('rates', fn () => Http::created(Payments::addRate(Ctx::actx(), Ctx::body(Z::object($rateShape())->strict()))))->middleware($configure);
    Route::patch('rates/{id}', function () use ($rateShape) {
        $id = Ctx::id();
        return Http::ok(Payments::updateRate(Ctx::actx(), $id, Ctx::body(Z::object($rateShape())->partial()->strict())));
    })->middleware($configure);
    Route::delete('rates/{id}', fn () => Http::ok(Payments::removeRate(Ctx::actx(), Ctx::id())))->middleware($configure);
    Route::post('{id}/verify', fn () => Http::ok(Payments::verify(Ctx::actx(), Ctx::id())))->middleware($manage);
    Route::get('/', function () use ($period, $memberType) {
        $q = Ctx::query(Z::object([
            'period' => $period()->optional(),
            'status' => Z::enum(['paid', 'unpaid'])->optional(),
            'member_type' => $memberType()->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'page' => Z::coerceNumber()->optional(),
            'limit' => Z::coerceNumber()->optional(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(Payments::adminList($q, $page));
    })->middleware($view);
    Route::get('member/{id}', fn () => Http::ok(Payments::forMember(Ctx::id())))->middleware($view);
    Route::post('/', fn () => Http::created(Payments::record(Ctx::actx(), Ctx::body(Z::object($paymentShape())->strict()))))->middleware($manage);
    Route::patch('{id}', function () use ($paymentShape) {
        $id = Ctx::id();
        return Http::ok(Payments::update(Ctx::actx(), $id, Ctx::body(Z::object($paymentShape())->omit(['user_id', 'period'])->partial()->strict())));
    })->middleware($manage);
    Route::delete('{id}', function () {
        Payments::remove(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    })->middleware($manage);
    Route::post('{id}/receipt', function () {
        $id = Ctx::id();
        return Http::ok(Payments::setReceipt(Ctx::actx(), $id, Upload::single('image')));
    })->middleware($manage);

    // Receipt review queue (Requirement 1)
    Route::get('receipts', fn () => Http::page(Payments::receiptList(Ctx::q(), Page::params(Ctx::q()))))->middleware($view);
    Route::post('receipts/{id}/approve', fn () => Http::ok(Payments::approveReceipt(Ctx::actx(), Ctx::id())))->middleware($manage);
    Route::post('receipts/{id}/reject', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => V::text(1, 1000)])->strict());
        return Http::ok(Payments::rejectReceipt(Ctx::actx(), $id, $b['reason']));
    })->middleware($manage);
    Route::get('receipts/{id}/file', fn () => Payments::downloadReceiptFile(Ctx::auth(), Ctx::id()))->middleware($view);
});


Route::prefix('org/contribution-receipts')->middleware('mz')->group(function () use ($period) {
    $review = ['mz:any,payments.manage,contributions.review'];
    $view = ['mz:any,payments.view,payments.manage,contributions.review'];

    Route::get('/', function () use ($period, $view) {
        $q = Ctx::query(Z::object([
            'period' => $period()->optional(),
            'status' => Z::enum(['submitted', 'under_review', 'approved', 'rejected', 'correction_needed'])->optional(),
            'user_id' => Z::coerceNumber()->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'page' => Z::coerceNumber()->optional(),
            'limit' => Z::coerceNumber()->optional(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(ContributionReceipts::adminList($q, $page));
    })->middleware($view);

    Route::get('{id}', fn () => Http::ok(ContributionReceipts::get(Ctx::id())))->middleware($view);

    Route::post('{id}/review', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'status' => Z::enum(['approved', 'rejected', 'under_review', 'correction_needed']),
            'review_note' => V::optionalText(1000),
            'approved_amount' => Z::coerceNumber()->min(0)->optional(),
        ])->strict());
        return Http::ok(ContributionReceipts::review(Ctx::actx(), $id, $b));
    })->middleware($review);

    Route::get('{id}/file', fn () => ContributionReceipts::fileResponse(Ctx::auth(), Ctx::id()))->middleware($view);
});

Route::get('members/{uuid}', function () {
    $p = Z::parse(Z::object(['uuid' => Z::string()->uuid('INVALID_QR')]), ['uuid' => request()->route('uuid')]);
    return Http::ok(Members::lookup(Ctx::auth(), $p['uuid']));
})->middleware('mz');
