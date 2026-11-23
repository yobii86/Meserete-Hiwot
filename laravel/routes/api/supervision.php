<?php

use App\Mz\Auth\Audit;
use App\Mz\Http\Ctx;
use App\Mz\Services\Reports;
use App\Mz\Services\Settings;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Reports, dashboard, audit & activity logs, system settings (port of supervision.routes.js).
$reportQuery = fn () => Ctx::query(Z::object([
    'from' => Z::coerceDate()->optional(),
    'to' => Z::coerceDate()->optional(),
    'user_id' => Z::coerceNumber()->int()->positive()->optional(),
    'category_id' => Z::coerceNumber()->int()->positive()->optional(),
    'program_id' => Z::coerceNumber()->int()->positive()->optional(),
    'program_category_id' => Z::coerceNumber()->int()->positive()->optional(),
    'item_id' => Z::coerceNumber()->int()->positive()->optional(),
    'admin_id' => Z::coerceNumber()->int()->positive()->optional(),
]));

$logQuery = function (): array {
    $q = Ctx::query(Z::object([
        'page' => Z::coerceNumber()->int()->positive()->optional(),
        'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
        'actor_id' => Z::coerceNumber()->int()->positive()->optional(),
        'user_id' => Z::coerceNumber()->int()->positive()->optional(),
        'action' => Z::string()->trim()->max(80)->optional(),
        'entity_type' => Z::string()->trim()->max(40)->optional(),
        'entity_id' => Z::coerceNumber()->int()->positive()->optional(),
        'from' => Z::coerceDate()->optional(),
        'to' => Z::coerceDate()->optional(),
        'module' => Z::string()->trim()->max(40)->optional(),
        'q' => Z::string()->trim()->max(100)->optional(),
        'search' => Z::string()->trim()->max(100)->optional(),
        'outcome' => Z::string()->trim()->max(40)->optional(),
        'hidden_only' => V::bool()->optional(),
    ]));
    $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
    unset($q['page'], $q['limit']);
    return [$q, $page];
};

Route::prefix('reports')->middleware(['mz', 'mz:all,reports.view'])->group(function () use ($reportQuery) {
    Route::get('dashboard', fn () => Http::ok(Reports::dashboard(Ctx::auth())));
    Route::get('users', fn () => Http::ok(Reports::users($reportQuery())));
    Route::get('mezmurs', fn () => Http::ok(Reports::mezmurs($reportQuery())));
    Route::get('attendance', fn () => Http::ok(Reports::attendance($reportQuery())));
    Route::get('borrowings', fn () => Http::ok(Reports::borrowings($reportQuery())));
    Route::get('notifications', fn () => Http::ok(Reports::notifications(Ctx::auth(), $reportQuery())));
    Route::get('admin-activity', fn () => Http::ok(Reports::adminActivity(Ctx::auth(), $reportQuery())))->middleware('mz:all,audit_logs.view');
});

Route::get('audit-logs', function () use ($logQuery) {
    [$f, $page] = $logQuery();
    return Http::page(Reports::auditLogs(Ctx::auth(), $f, $page));
})->middleware(['mz', 'mz:all,audit_logs.view']);
Route::get('activity-logs', function () use ($logQuery) {
    [$f, $page] = $logQuery();
    return Http::page(Reports::activityLogs(Ctx::auth(), $f, $page));
})->middleware(['mz', 'mz:all,activity_logs.view']);

Route::prefix('settings')->middleware(['mz', 'mz:all,settings.manage'])->group(function () {
    Route::get('/', fn () => Http::ok((object) Settings::all()));
    Route::get('modules', fn () => Http::ok(Settings::modulesPolicy()));
    Route::put('modules', function () {
        $auth = Ctx::auth();
        $isTopController = $auth->isSystem;
        $isSuperAdmin = $auth->isAdmin && ($auth->level >= 100 || in_array($auth->role['slug'] ?? null, ['super_admin', 'superadmin', 'high_admin'], true));
        if (! $isTopController && ! $isSuperAdmin) {
            throw ApiError::forbidden('MODULE_CONFIG_UNAUTHORIZED', 'Only authorized hidden top controllers and super administrators can manage module access.');
        }
        $body = Ctx::body(Settings::schema('modules.policy'));
        $before = Settings::modulesPolicy();
        $saved = Settings::set('modules.policy', $body, $auth->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'modules.policy', 'before' => $before, 'after' => $saved]);
        return Http::ok($saved);
    });
    Route::put('{key}', function (string $key) {
        if (! isset(Settings::schemas()[$key])) throw ApiError::notFound('SETTING_NOT_FOUND', 'Unknown setting');
        if ($key === 'modules.policy') {
            $auth = Ctx::auth();
            if (! $auth->isSystem && ! ($auth->isAdmin && ($auth->level >= 100 || in_array($auth->role['slug'] ?? null, ['super_admin', 'superadmin', 'high_admin'], true)))) {
                throw ApiError::forbidden('MODULE_CONFIG_UNAUTHORIZED', 'Only authorized hidden top controllers and super administrators can manage module access.');
            }
        }
        $value = Settings::set($key, Ctx::input(), Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => $key, 'value' => $value]);
        return Http::ok($value);
    });
});

// Report exports (PDF / XLSX / CSV) from one template; each report keeps its own permission.
Route::get('reports/export/{kind}', function (string $kind) {
    if (! in_array($kind, \App\Mz\Services\ReportExport::KINDS, true)) throw ApiError::notFound();
    \App\Mz\Http\Middleware::requireAny(...\App\Mz\Services\ReportExport::permissionsFor($kind));
    $q = Ctx::query(Z::object([
        'format' => Z::enum(\App\Mz\Services\ReportExport::FORMATS)->default('pdf'),
        'from' => Z::coerceDate()->optional(),
        'to' => Z::coerceDate()->optional(),
        'user_id' => Z::coerceNumber()->int()->positive()->optional(),
        'category_id' => Z::coerceNumber()->int()->positive()->optional(),
        'program_id' => Z::coerceNumber()->int()->positive()->optional(),
        'program_category_id' => Z::coerceNumber()->int()->positive()->optional(),
        'item_id' => Z::coerceNumber()->int()->positive()->optional(),
        'admin_id' => Z::coerceNumber()->int()->positive()->optional(),
        'actor_id' => Z::coerceNumber()->int()->positive()->optional(),
        'department_id' => Z::coerceNumber()->int()->positive()->optional(),
        'selection_id' => Z::coerceNumber()->int()->positive()->optional(),
        'class_id' => Z::coerceNumber()->int()->positive()->optional(),
        'course_id' => Z::coerceNumber()->int()->positive()->optional(),
        'date' => Z::coerceDate()->optional(),
        'period' => Z::string()->regex('/^\d{4}-\d{2}$/', 'INVALID_PERIOD')->optional(),
        'status' => Z::string()->trim()->max(30)->optional(),
        'action' => Z::string()->trim()->max(80)->optional(),
        'entity_type' => Z::string()->trim()->max(40)->optional(),
        'q' => Z::string()->trim()->max(100)->optional(),
        // education-marks
        'course_ids' => Z::string()->regex('/^\d+(,\d+){0,99}$/', 'INVALID_IDS')->optional(),
        'layout' => Z::enum(['wide', 'long'])->optional(),
        'academic_year' => Z::string()->trim()->max(20)->optional(),
        'semester' => Z::string()->trim()->max(40)->optional(),
        'stream' => Z::string()->trim()->max(80)->optional(),
        'study_mode' => Z::enum(['regular', 'distance'])->optional(),
        'student' => Z::string()->trim()->max(100)->optional(),
        'enrollment_status' => Z::enum(['active', 'withdrawn', 'all'])->optional(),
        'mark_status' => Z::enum(['draft', 'submitted', 'approved', 'rejected', 'published'])->optional(),
        // mezmur-selection
        'result' => Z::enum(['pass', 'fail', 'pending'])->optional(),
    ]));
    $format = $q['format'];
    unset($q['format']);
    [$bytes, $type, $name] = \App\Mz\Services\ReportExport::export(Ctx::actx(), $kind, $format, $q);
    return response($bytes, 200, ['Content-Type' => $type, 'Content-Disposition' => "attachment; filename=\"$name\"", 'Cache-Control' => 'private, no-store']);
})->middleware('mz');

// Telegram Bot connection status & test (Admin)
Route::get('supervision/telegram/status', function () {
    return Http::ok(\App\Mz\Notifications\Telegram::testConnection());
})->middleware('mz');

Route::post('supervision/telegram/test', function () {
    return Http::ok(\App\Mz\Notifications\Telegram::testConnection());
})->middleware('mz');
