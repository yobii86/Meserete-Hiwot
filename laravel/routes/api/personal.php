<?php

use App\Mz\Auth\Audit;
use App\Mz\Http\Ctx;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\Activity;
use App\Mz\Services\Attendance;
use App\Mz\Services\Permissions;
use App\Mz\Services\Reminders;
use App\Mz\Services\Settings;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\ProgramSchemas as PS;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// /attendance (admin parts first — attendanceAdmin.routes.js), then the member's own views
// (personal.routes.js), /reminders, /notifications and /permissions.
Route::prefix('attendance')->middleware('mz')->group(function () {
    // HR: who signs. Members of the exempt groups are recorded without a signature (audited).
    Route::get('signature-policy', fn () => Http::ok(Settings::signaturePolicy()))->middleware('mz:any,attendance.manage,attendance.view,attendance.configure,attendance.assign');
    Route::put('signature-policy', function () {
        $body = Ctx::body(Settings::schema('attendance.signature'));
        $before = Settings::signaturePolicy();
        $saved = Settings::set('attendance.signature', $body, Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'attendance.signature', 'before' => $before, 'after' => $saved]);
        return Http::ok(Settings::signaturePolicy());
    })->middleware('mz:all,attendance.configure');

    // HR: offline attendance the server could not apply as sent — decided, never dropped.
    Route::get('sync-conflicts', function () {
        $q = Ctx::query(Z::object([
            'status' => Z::enum(['open', 'accepted', 'rejected'])->optional(),
            'program_id' => Z::coerceNumber()->int()->positive()->optional(),
            'batch_id' => Z::string()->max(36)->optional(),
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
        ]));
        return Http::page(\App\Mz\Services\AttendanceSessions::conflicts($q, Page::params(Ctx::q())));
    })->middleware('mz:any,attendance.override,attendance.correction.approve');
    Route::get('sync-conflicts/batches', function () {
        $q = Ctx::query(Z::object([
            'status' => Z::enum(['open', 'resolved'])->optional(),
            'program_id' => Z::coerceNumber()->int()->positive()->optional(),
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
        ]));
        return Http::page(\App\Mz\Services\AttendanceSessions::conflictBatches($q, Page::params(Ctx::q())));
    })->middleware('mz:any,attendance.override,attendance.correction.approve');
    Route::post('sync-conflicts/bulk-resolve', function () {
        $b = Ctx::body(Z::object([
            'batch_id' => Z::string()->max(36)->optional(),
            'conflict_ids' => Z::array(Z::coerceNumber()->int()->positive())->min(1)->max(500)->optional(),
            'decision' => Z::enum(['accept', 'reject']),
            'note' => V::text(3, 1000),
        ])->strict());
        return Http::ok(\App\Mz\Services\AttendanceSessions::bulkResolveConflicts(Ctx::actx(), $b));
    })->middleware('mz:all,attendance.override');
    Route::post('sync-conflicts/{id}/resolve', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['decision' => Z::enum(['accept', 'reject']), 'note' => V::text(3, 1000)])->strict());
        return Http::ok(\App\Mz\Services\AttendanceSessions::resolveConflict(Ctx::actx(), $id, $b['decision'], $b['note']));
    })->middleware('mz:all,attendance.override')->whereNumber('id');
    Route::get('sync-conflicts/{id}/signature', function () {
        $f = \App\Mz\Services\AttendanceSessions::conflictSignature(Ctx::id());
        return response()->file($f['abs'], ['Content-Type' => $f['mime'], 'Cache-Control' => 'private, no-store']);
    })->middleware('mz:any,attendance.override,attendance.correction.approve')->whereNumber('id');
    Route::get('corrections', function () {
        $q = Ctx::query(PS::correctionListQuery());
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(Attendance::listCorrections(Ctx::auth(), $q, $page));
    })->middleware('mz:any,attendance.correction.approve,attendance.correction.request');
    Route::post('corrections/{id}/review', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::correctionReview());
        return Http::ok(Attendance::reviewCorrection(Ctx::actx(), $id, $b['decision'], $b['note'] ?? null));
    })->middleware('mz:all,attendance.correction.approve');

    $cats = fn (array $q) => ! empty($q['category_id']) ? [$q['category_id']] : null;
    // A member sees only their OWN program attendance: their records and how many were present /
    // late / excused / absent — never percentages, scores, other members or group figures.
    $own = fn (array $s) => array_diff_key($s, array_flip(['percentage', 'rate', 'score', 'excused_weight']));
    Route::get('me', function () use ($own) {
        $out = Attendance::forUser(Ctx::auth()->id, Page::params(Ctx::q()));
        return Http::ok($out['items'], $out['meta'] + ['summary' => $own(Attendance::rateSummary(Ctx::auth()->id))]);
    });
    Route::get('me/calendar', function () use ($cats, $own) {
        $q = Ctx::query(PS::calendarQuery());
        $out = Attendance::calendar(Ctx::auth()->id, $q['from'], $q['to'], $cats($q));
        $out['stats'] = $own($out['stats']);
        return Http::ok($out);
    });
    Route::get('me/stats', function () use ($cats, $own) {
        $q = Ctx::query(PS::statsQuery());
        return Http::ok($own(Attendance::stats(Ctx::auth()->id, ['from' => $q['from'] ?? null, 'to' => $q['to'] ?? null, 'categoryIds' => $cats($q)])));
    });
    Route::get('my-yearly-summary', function () {
        $year = (int) (Ctx::q('year') ?? 0);
        return Http::ok(Attendance::myYearlySummary(Ctx::auth()->id, $year));
    });
    $view = 'mz:any,attendance.manage,attendance.reports,attendance.view';
    Route::get('users/{id}', function () {
        $id = Ctx::id();
        $out = Attendance::forUser($id, Page::params(Ctx::q()));
        return Http::ok($out['items'], $out['meta'] + ['summary' => Attendance::rateSummary($id)]);
    })->middleware($view);
    Route::get('users/{id}/calendar', function () use ($cats) {
        $id = Ctx::id();
        $q = Ctx::query(PS::calendarQuery());
        return Http::ok(Attendance::calendar($id, $q['from'], $q['to'], $cats($q)));
    })->middleware($view);
    Route::get('users/{id}/stats', function () use ($cats) {
        $id = Ctx::id();
        $q = Ctx::query(PS::statsQuery());
        return Http::ok(Attendance::stats($id, ['from' => $q['from'] ?? null, 'to' => $q['to'] ?? null, 'categoryIds' => $cats($q)]));
    })->middleware($view);
});

Route::prefix('reminders')->middleware('mz')->group(function () {
    $key = function (): int|string {
        $raw = (string) request()->route('id');
        $v = Z::parse(Z::union([Z::string()->uuid(), V::id()]), $raw);
        return $v;
    };
    Route::get('/', function () {
        $q = Ctx::query(Z::object(['since' => Z::coerceDate()->optional()]));
        return Http::ok(Reminders::list(Ctx::auth()->id, $q['since'] ?? null));
    });
    Route::post('/', function () {
        $out = Reminders::create(Ctx::auth()->id, Ctx::body(PS::reminderCreate()));
        return $out['created'] ? Http::created($out['reminder']) : Http::ok($out['reminder']);
    });
    Route::patch('{id}', function () use ($key) {
        $k = $key();
        return Http::ok(Reminders::update(Ctx::auth()->id, $k, Ctx::body(PS::reminderUpdate())));
    });
    Route::delete('{id}', function () use ($key) {
        if (! Reminders::remove(Ctx::auth()->id, $key())) throw ApiError::notFound('REMINDER_NOT_FOUND', 'Reminder not found');
        return Http::ok(null);
    });
});

Route::prefix('notifications')->middleware('mz')->group(function () {
    Route::get('/', function () {
        $q = Ctx::q();
        $page = Page::params($q);
        $out = Notifications::listForUser(Ctx::auth()->id, ($q['unread'] ?? null) === 'true', is_string($q['q'] ?? null) ? mb_substr($q['q'], 0, 100) : null, $page['limit'], $page['offset']);
        return Http::ok($out['items'], ['page' => $page['page'], 'limit' => $page['limit'], 'total' => $out['total'], 'pages' => (int) ceil($out['total'] / $page['limit']), 'unread' => Notifications::unreadCount(Ctx::auth()->id)]);
    });
    Route::get('unread-count', fn () => Http::ok(['unread' => Notifications::unreadCount(Ctx::auth()->id)]));
    Route::post('read-all', fn () => Http::ok(['updated' => Notifications::markAllRead(Ctx::auth()->id)]));
    Route::post('{id}/read', function () {
        $id = Ctx::id();
        if (! Notifications::markRead(Ctx::auth()->id, $id)) throw ApiError::notFound();
        if (Ctx::auth()->accountType === 'user') Activity::track(Ctx::auth()->id, Activity::NOTIFICATION_OPEN, 'notification', $id);
        return Http::ok(null);
    });
});

// Admin review of absence permission requests.
Route::prefix('permissions')->middleware(['mz', 'mz:all,attendance.manage'])->group(function () {
    Route::get('policy', fn () => Http::ok(Settings::permissionPolicy()));
    Route::put('policy', function () {
        $value = Settings::set('attendance.permissions', Ctx::input(), Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'attendance.permissions', 'value' => $value]);
        return Http::ok($value);
    });
    Route::get('summary', fn () => Http::ok(Permissions::pendingSummary()));
    Route::get('/', function () {
        $q = Ctx::query(PS::permissionListQuery());
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(Permissions::adminList($q, $page));
    });
    Route::patch('{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::permissionReview());
        return Http::ok(Permissions::review(Ctx::actx(), $id, $b['status'], $b['note'] ?? null));
    });
    // Undo an approval given by mistake (the excused mark it created is removed).
    Route::post('{id}/cancel', function () {
        $b = Ctx::body(PS::permissionCancelApproved());
        return Http::ok(Permissions::cancelApproved(Ctx::actx(), Ctx::id(), $b['reason']));
    });
});
