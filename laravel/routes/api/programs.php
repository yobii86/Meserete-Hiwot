<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Attendance;
use App\Mz\Services\AttendanceSessions;
use App\Mz\Services\Permissions;
use App\Mz\Services\Programs;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\ProgramSchemas as PS;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// /programs (port of programs.routes.js).
Route::prefix('programs')->group(function () {
    $pageOf = fn (array $q) => Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
    $manageCats = ['mz', 'mz:all,program_categories.manage'];
    $manage = ['mz', 'mz:all,programs.manage'];
    // Recording: any signed-in account; the session's ONE assigned taker is checked in the service
    // (an HR assignment is what authorises someone to record — not a permission).
    $att = ['mz'];
    $attView = ['mz', 'mz:any,attendance.view,attendance.manage,attendance.override,attendance.assign,attendance.close,attendance.reports'];

    // ---- categories ----
    Route::get('categories', fn () => Http::ok(Programs::categories()));
    Route::get('categories/all', fn () => Http::ok(Programs::categories(true)))->middleware($manageCats);
    Route::post('categories', fn () => Http::created(Programs::createCategory(Ctx::actx(), Ctx::body(PS::categoryCreate()))))->middleware($manageCats);
    Route::patch('categories/{id}', function () {
        $id = Ctx::id();
        return Http::ok(Programs::updateCategory(Ctx::actx(), $id, Ctx::body(PS::categoryUpdate())));
    })->middleware($manageCats);
    Route::delete('categories/{id}', fn () => Http::ok(Programs::deleteCategory(Ctx::actx(), Ctx::id())))->middleware($manageCats);

    Route::get('calendar', function () {
        $q = Ctx::query(PS::calendarQuery());
        return Http::ok(Programs::calendar(Ctx::authOrNull(), $q['from'], $q['to'], $q['category_id'] ?? null));
    })->middleware('mz:optional');

    // ---- admin lists (before /{id}) ----
    Route::get('admin/list', function () use ($pageOf) {
        $q = Ctx::query(PS::programListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit']);
        return Http::page(Programs::list(Ctx::auth(), array_merge(['scope' => 'all'], $q), $page, true));
    })->middleware($manage);
    Route::get('admin/{id}', fn () => Http::ok(Programs::detail(Ctx::id(), Ctx::auth(), true)))->middleware($manage);

    // Programs this attendance taker may open (attendance taken, assigned to them or open to every taker).
    Route::get('attendance/takeable', function () use ($pageOf) {
        $q = Ctx::query(PS::programListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit']);
        return Http::page(Programs::list(Ctx::auth(), array_merge(['scope' => 'all'], $q, ['takeable_by' => Ctx::auth()]), $page, true));
    })->middleware($att);

    // ---- public / user ----
    Route::get('/', function () use ($pageOf) {
        $q = Ctx::query(PS::programListQuery());
        $page = $pageOf($q);
        unset($q['page'], $q['limit'], $q['status']);
        return Http::page(Programs::list(Ctx::authOrNull(), array_merge(['scope' => 'upcoming'], $q), $page));
    })->middleware('mz:optional');
    Route::get('{id}', fn () => Http::ok(Programs::detail(Ctx::id(), Ctx::authOrNull())))->middleware('mz:optional');
    // The member's own reminders (alarms) for this program: any of 2 days / 1 day / 6 h / 1 h before.
    Route::put('{id}/my-reminders', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['offsets' => PS::reminderOffsets()->nullable()]));
        return Http::ok(Programs::setMyReminders(Ctx::auth(), $id, $b['offsets']));
    })->middleware('mz');
    // The member's own attendance at this program: records and counts only (no percentages).
    Route::get('{id}/my-attendance', function () {
        $out = Attendance::forProgram(Ctx::auth()->id, Ctx::id());
        if (isset($out['stats'])) $out['stats'] = array_diff_key($out['stats'], array_flip(['percentage', 'rate', 'score', 'excused_weight']));
        return Http::ok($out);
    })->middleware('mz');
    Route::post('{id}/permission', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::permissionRequest());
        // Administrators are members too; only the hidden system authority has no attendance.
        if (Ctx::auth()->isSystem) throw ApiError::forbidden();
        Permissions::request(Ctx::auth(), $id, $b['reason'] ?? null, $b['date'] ?? null);
        return Http::ok(Programs::detail($id, Ctx::auth()), null, 'Requested');
    })->middleware('mz');
    Route::delete('{id}/permission', function () {
        $id = Ctx::id();
        $q = Ctx::query(PS::permissionCancel());
        Permissions::cancel(Ctx::auth(), $id, $q['date'] ?? null);
        return Http::ok(Programs::detail($id, Ctx::auth()));
    })->middleware('mz');

    // ---- admin: programs ----
    Route::get('{id}/occurrences', function () {
        $id = Ctx::id();
        $q = Ctx::query(PS::calendarQuery()->omit(['category_id']));
        return Http::ok(Programs::occurrences($id, $q['from'], $q['to']));
    })->middleware(['mz', 'mz:any,programs.manage,attendance.manage,attendance.view']);
    Route::post('preview-schedule', fn () => Http::ok(Programs::previewSchedule(Ctx::body(PS::checkOverlap()))))->middleware($manage);
    Route::post('check-overlap', fn () => Http::ok(Programs::checkOverlap(Ctx::body(PS::checkOverlap()))))->middleware($manage);
    Route::post('/', fn () => Http::created(Programs::create(Ctx::actx(), Ctx::body(PS::programCreate()))))->middleware($manage);
    Route::patch('{id}', function () {
        $id = Ctx::id();
        return Http::ok(Programs::update(Ctx::actx(), $id, Ctx::body(PS::programUpdate())));
    })->middleware($manage);
    Route::delete('{id}', function () {
        Programs::delete(Ctx::actx(), Ctx::id());
        return Http::ok(null, null, 'Program deleted successfully');
    })->middleware($manage);
    Route::post('{id}/image', function () {
        $id = Ctx::id();
        return Http::ok(Programs::setImage(Ctx::actx(), $id, Upload::single('image')));
    })->middleware($manage);

    Route::get('{id}/participants', function () {
        $id = Ctx::id();
        $q = Ctx::q();
        return Http::page(Programs::participants($id, ['q' => $q['q'] ?? null, 'status' => $q['status'] ?? null], Page::params($q)));
    })->middleware($manage);
    Route::post('{id}/participants/bulk', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::participantsBulk());
        return Http::ok(Programs::bulkAddParticipants(Ctx::actx(), $id, $b, Ctx::auth()->can('notifications.send_all')));
    })->middleware($manage);
    Route::delete('{id}/participants/{userId}', function () {
        Programs::removeParticipant(Ctx::actx(), Ctx::id(), Ctx::id('userId'));
        return Http::ok(null);
    })->middleware($manage);

    Route::put('{id}/occurrences/{date}', function () {
        $id = Ctx::id();
        $date = Z::parse(PS::isoDate(), request()->route('date'));
        $auth = Ctx::auth();
        $canManagePrograms = $auth->can('programs.manage');
        $canManageAttendance = $auth->canAny(['attendance.manage', 'attendance.override']);
        $isAssignedTaker = false;
        if (! $canManagePrograms && ! $canManageAttendance) {
            $isAssignedTaker = \Illuminate\Support\Facades\DB::table('program_attendance_takers')->where(['program_id' => $id, 'user_id' => $auth->id])->exists()
                || \Illuminate\Support\Facades\DB::table('attendance_sessions')->where(['program_id' => $id, 'occurrence_date' => $date, 'taker_id' => $auth->id])->exists();
        }
        if (! $canManagePrograms && ! $canManageAttendance && ! $isAssignedTaker) {
            throw \App\Mz\Support\ApiError::forbidden('OCCURRENCE_MANAGE_FORBIDDEN', 'Only an authorized administrator or the assigned attendance taker may update this occurrence');
        }
        return Http::ok(Programs::setOccurrence(Ctx::actx(), $id, $date, Ctx::body(PS::occurrenceChange())));
    })->middleware('mz');

    // ---- admin: attendance (?date=YYYY-MM-DD; default today's / latest) ----
    // The roster: HR / attendance viewers, and the occurrence's assigned taker.
    Route::get('{id}/attendance', function () use ($pageOf) {
        $id = Ctx::id();
        $q = Ctx::query(PS::rosterQuery());
        AttendanceSessions::get(Ctx::auth(), $id, $q['date'] ?? null); // taker or HR only
        $page = $pageOf($q);
        unset($q['page'], $q['limit']);
        $out = Attendance::roster($id, $q, $page, Ctx::auth());
        return Http::ok($out['items'], $out['meta']);
    })->middleware('mz');

    // ---- attendance session of one occurrence (one taker, Start / End) ----
    Route::get('{id}/attendance/session', function () {
        $id = Ctx::id();
        $q = Ctx::query(PS::occurrenceQuery());
        return Http::ok(AttendanceSessions::get(Ctx::auth(), $id, $q['date'] ?? null));
    })->middleware('mz');
    Route::post('{id}/attendance/session/start', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::occurrenceQuery());
        return Http::ok(AttendanceSessions::start(Ctx::actx(), $id, $b['date'] ?? null));
    })->middleware('mz');
    Route::post('{id}/attendance/session/end', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::occurrenceQuery());
        return Http::ok(AttendanceSessions::end(Ctx::actx(), $id, $b['date'] ?? null));
    })->middleware('mz');
    // HR assigns the occurrence's taker (or a recorded substitute while it runs: reason required).
    Route::put('{id}/attendance/session/taker', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['date' => PS::isoDate()->optional(), 'user_id' => Z::number()->int()->positive(), 'reason' => Z::string()->trim()->max(500)->optional()]));
        return Http::ok(AttendanceSessions::assign(Ctx::actx(), $id, $b['date'] ?? null, $b['user_id'], $b['reason'] ?? null));
    })->middleware(['mz', 'mz:all,attendance.assign']);
    // A member's signature on a mark (HR / reports / admin).
    Route::get('attendance/signatures/{attendanceId}', function () {
        $f = Attendance::signatureFile(Ctx::id('attendanceId'));
        return response()->file($f['abs'], ['Content-Type' => $f['mime'], 'Cache-Control' => 'private, no-store']);
    })->middleware(['mz', 'mz:any,attendance.reports,attendance.override,attendance.correction.approve,attendance.view,attendance.manage,programs.manage']);

    // Admin Attendance Management (History, Overview, Export, Year/Month Analytics)
    Route::middleware(['mz', 'mz:any,attendance.reports,attendance.view,attendance.manage,programs.manage'])->prefix('attendance/admin')->group(function () {
        Route::get('overview', fn () => Http::ok(Attendance::adminOverview(Ctx::q())));
        Route::get('yearly-summary', fn () => Http::ok(Attendance::yearlySummary(Ctx::q())));
        Route::get('monthly-summary', fn () => Http::ok(Attendance::monthlySummary(Ctx::q())));
        Route::get('by-program', fn () => Http::ok(Attendance::byProgram(Ctx::q())));
        Route::get('members/search', fn () => Http::ok(Attendance::searchMembers(Ctx::q('q'))));
        Route::get('member/{userId}', fn () => Http::ok(Attendance::adminMemberProfile(Ctx::id('userId'), (int) (Ctx::q('year') ?? 0))));
        Route::get('records', function () {
            $q = Ctx::q();
            $page = [
                'page' => max(1, (int) ($q['page'] ?? 1)),
                'limit' => min(100, max(1, (int) ($q['limit'] ?? $q['per_page'] ?? 25))),
            ];
            $page['offset'] = ($page['page'] - 1) * $page['limit'];
            return Http::page(Attendance::adminRecords($q, $page));
        });
        Route::get('export', fn () => Http::ok(Attendance::adminExport(Ctx::q())));
    });
    // Step 1 of taking attendance: identify the member (QR uuid or manual pick) and check they may be
    // recorded here; nothing is written. Step 2 is PUT {id}/attendance/{userId}.
    Route::get('{id}/attendance/check', function () {
        $id = Ctx::id();
        $q = Ctx::query(Z::object([
            'uuid' => Z::string()->uuid('INVALID_QR')->optional(),
            'user_id' => Z::coerceNumber()->int()->positive()->optional(),
            'date' => PS::isoDate()->optional(),
        ])->refine(fn ($v) => ! empty($v['uuid']) || ! empty($v['user_id']), ['message' => 'REQUIRED', 'path' => ['uuid']]));
        return Http::ok(Attendance::identify(Ctx::auth(), $id, $q));
    })->middleware($att);
    Route::get('{id}/attendance-takers', fn () => Http::ok(Programs::takers(Ctx::id())))->middleware(['mz', 'mz:any,attendance.view,attendance.manage,attendance.assign,programs.manage']);
    // HR sets the program's ONE default taker.
    Route::put('{id}/attendance-takers', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(Z::number()->int()->positive())->max(1)]));
        return Http::ok(Programs::setTakers(Ctx::actx(), $id, $b['user_ids']));
    })->middleware(['mz', 'mz:all,attendance.assign']);
    Route::post('{id}/attendance/close', function () {
        $id = Ctx::id();
        $b = Ctx::body(PS::occurrenceQuery());
        return Http::ok(Attendance::close(Ctx::actx(), $id, $b['date'] ?? null));
    })->middleware(['mz', 'mz:all,attendance.close']);
    Route::post('{id}/attendance/bulk', function () {
        $id = Ctx::id();
        return Http::ok(Attendance::bulkSet(Ctx::actx(), $id, Ctx::body(PS::attendanceBulk()), true));
    })->middleware($att);
    Route::put('{id}/attendance/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $out = Attendance::set(Ctx::actx(), $id, $uid, Ctx::body(PS::attendanceSet()));
        // A second scan (this phone or another) never creates a second record.
        return Http::ok($out, null, $out['duplicate'] ? 'Attendance already recorded for this program.' : 'OK');
    })->middleware($att);
    Route::delete('{id}/attendance/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $q = Ctx::query(PS::occurrenceQuery()->extend(['reason' => Z::string()->trim()->max(500)->optional()]));
        Attendance::remove(Ctx::actx(), $id, $uid, $q['date'] ?? null, $q['reason'] ?? null);
        return Http::ok(null);
    })->middleware($att);
    Route::post('{id}/attendance/{userId}/corrections', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        return Http::created(Attendance::requestCorrection(Ctx::actx(), $id, $uid, Ctx::body(PS::correctionRequest())));
    })->middleware(['mz', 'mz:all,attendance.correction.request']);
});
