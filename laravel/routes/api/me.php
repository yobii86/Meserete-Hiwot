<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Notifications\Fcm;
use App\Mz\Notifications\Telegram;
use App\Mz\Services\Account;
use App\Mz\Services\Activity;
use App\Mz\Services\ContributionReceipts;
use App\Mz\Services\Departments;
use App\Mz\Services\MemberProfile;
use App\Mz\Services\Members;
use App\Mz\Services\Payments;
use App\Mz\Services\ProfileChanges;
use App\Mz\Services\Sessions;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Endpoints scoped to the signed-in account (port of me.routes.js). Ownership is implicit.
Route::prefix('me')->middleware('mz')->group(function () {
    Route::get('/', fn () => Http::ok(Account::profile(Ctx::auth())));
    // A member asks for changes to their details (name, phone, any membership-form field); an
    // administrator approves or declines with a reason. Previous values are kept in the history.
    Route::post('change-request', function () {
        $b = Ctx::body(Z::object([
            'full_name' => V::text(2, 150)->optional(),
            'phone' => V::phone()->optional(),
            'profile' => \App\Mz\Support\MemberSchemas::profile()->optional(),
            'note' => V::optionalText(500),
        ])->strict());
        $r = ProfileChanges::submit(Ctx::auth()->id, $b);
        if (! $r) throw ApiError::field('profile', 'NO_CHANGES');
        return Http::created($r);
    });
    Route::get('change-requests', fn () => Http::ok(
        DB::table('profile_change_requests')->where('user_id', Ctx::auth()->id)->whereIn('status', ['pending', 'approved', 'rejected'])->orderByDesc('id')->limit(20)->get()
            ->map(fn ($r) => ProfileChanges::serialize($r))->all()
    ));
    Route::delete('change-request', function () {
        ProfileChanges::cancel(Ctx::auth()->id);
        return Http::ok(Account::profile(Ctx::auth()));
    });

    Route::post('telegram/link', fn () => Http::ok(Telegram::createLinkToken(Ctx::auth()->id)));
    Route::delete('telegram', function () {
        Telegram::unlink(Ctx::auth()->id);
        return Http::ok(Account::profile(Ctx::auth()));
    });

    // Regular users cannot change their own profile — administrators edit it for them.
    Route::patch('/', function () {
        if (Ctx::auth()->accountType !== 'admin') {
            throw ApiError::forbidden('PROFILE_LOCKED', 'Profile changes are made by administrators');
        }
        $b = Ctx::body(Z::object([
            'full_name' => V::text(2, 150)->optional(),
            'phone' => V::phone()->optional(),
            'email' => V::patchEmail(),
        ])->strict());
        return Http::ok(Account::updateProfile(Ctx::auth(), $b));
    });
    Route::post('avatar', fn () => Http::ok(Account::setAvatar(Ctx::auth(), Upload::single('image'))));
    Route::delete('avatar', function () {
        Account::removeAvatar(Ctx::auth());
        return Http::ok(null);
    });

    Route::get('preferences', fn () => Http::ok(Account::getPreferences(Ctx::auth()->id)));
    Route::put('preferences', function () {
        $b = Ctx::body(Z::object([
            'notifications_enabled' => Z::boolean()->optional(),
            'audio_autoplay' => Z::boolean()->optional(),
            'download_audio' => Z::boolean()->optional(),
            'theme' => Z::enum(['system', 'light', 'dark'])->optional(),
            'reminder_time' => Z::string()->regex('/^([01]\d|2[0-3]):[0-5]\d$/', 'INVALID_TIME')->optional(),
            'language' => Z::enum(['am', 'en'])->optional(),
            'lyrics_font_scale' => Z::number()->int()->min(70)->max(200)->optional(),
            'preferred_category_ids' => Z::array(Z::number()->int()->positive())->max(100)->optional(),
        ])->strict());
        return Http::ok(Account::updatePreferences(Ctx::auth()->id, $b));
    });
    // Per topic: push / email on or off (administrative messages stay on).
    Route::get('notification-preferences', fn () => Http::ok(Account::notificationPreferences(Ctx::auth()->id)));
    Route::put('notification-preferences', function () {
        $b = Ctx::body(Z::object([
            'enabled' => Z::boolean()->optional(),
            'topics' => Z::array(Z::object([
                'topic' => Z::enum(\App\Mz\Notifications\Notifications::TOPICS),
                'push' => Z::boolean()->optional(),
                'email' => Z::boolean()->optional(),
            ]))->max(20)->optional(),
        ])->strict());
        return Http::ok(Account::updateNotificationPreferences(Ctx::auth()->id, $b));
    });

    Route::post('fcm-tokens', function () {
        $b = Ctx::body(Z::object([
            'token' => Z::string()->min(20)->max(255),
            'platform' => Z::enum(['android', 'ios', 'web'])->default('android'),
        ]));
        Account::registerFcmToken(Ctx::auth(), $b['token'], $b['platform']);
        return Http::ok(null, null, 'Token registered');
    });

    Route::get('profile', fn () => Http::ok(['profile' => MemberProfile::get(Ctx::auth()->id), 'departments' => Departments::departmentsOf(Ctx::auth()->id)]));
    // Sign-in sessions: list, revoke one ("delete" = revoke, never the account), revoke the others,
    // sign out everywhere.
    Route::get('sessions', fn () => Http::ok(Sessions::list(Ctx::auth())));
    Route::post('sessions/revoke-others', fn () => Http::ok(['revoked' => Sessions::revokeOthers(Ctx::actx())]));
    Route::post('sessions/revoke-all', function () {
        Sessions::revokeAll(Ctx::actx());
        return Http::ok(null);
    });
    Route::delete('sessions/{sid}', function (string $sid) {
        $sid = Z::parse(Z::string()->uuid('INVALID_SESSION'), $sid);
        Sessions::revoke(Ctx::actx(), $sid);
        return Http::ok(null);
    });

    Route::get('card', function () {
        $card = Members::card(Ctx::auth()->id);
        return Http::ok($card + ['qr' => Members::qrPayload($card['uuid'])]);
    });
    Route::get('payments', fn () => Http::ok(Payments::forMember(Ctx::auth()->id)));

    // Contribution receipts
    Route::get('contribution-receipts/calculate', function () {
        $q = Ctx::query(Z::object([
            'period' => Z::string()->regex('/^\d{4}-\d{2}$/'),
            'months' => Z::coerceNumber()->min(1)->max(12),
        ]));
        return Http::ok(ContributionReceipts::calculateExpected(Ctx::auth()->id, $q['period'], (int) $q['months']));
    });
    Route::get('contribution-receipts', fn () => Http::ok(ContributionReceipts::forMember(Ctx::auth()->id)));
    Route::post('contribution-receipts', function () {
        $field = request()->hasFile('receipt') ? 'receipt' : 'file';
        $file = Upload::single('contribution_receipt', $field);
        $b = Ctx::body(Z::object([
            'period' => Z::string()->regex('/^\d{4}-\d{2}$/'),
            'months' => Z::coerceNumber()->min(1)->max(12),
            'method' => Z::enum(['cash', 'bank', 'telebirr', 'other'])->optional(),
            'reference' => V::optionalText(120),
            'paid_on' => V::dateOnly()->optional(),
            'member_note' => V::optionalText(1000),
            'submitted_amount' => Z::coerceNumber()->min(0)->optional(),
        ]));
        return Http::created(ContributionReceipts::submit(Ctx::actx(), $b, $file));
    });
    Route::get('contribution-receipts/{id}/file', fn () => ContributionReceipts::fileResponse(Ctx::auth(), Ctx::id()));

    Route::get('payments/receipts', fn () => Http::ok(Payments::myReceipts(Ctx::auth()->id)));
    Route::post('payments/receipt', function () {
        $file = Upload::single('receipt', request()->hasFile('receipt') ? 'receipt' : 'file');
        $input = [
            'months' => (int) (request()->input('months') ?? 1),
            'period' => request()->input('period'),
            'amount' => request()->input('amount'),
            'note' => request()->input('note'),
        ];
        return Http::created(Payments::submitReceipt(Ctx::actx(), $input, $file));
    });
    Route::get('payments/receipts/{id}/file', fn () => Payments::downloadReceiptFile(Ctx::auth(), Ctx::id()));

    // Push diagnostics: one test notification to the caller's own devices.
    Route::post('push-test', function () {
        $status = Fcm::status();
        $tokens = DB::table('fcm_tokens')->where('user_id', Ctx::auth()->id)->whereNull('invalidated_at')->pluck('token')->all();
        $results = $status['ready'] && $tokens
            ? Fcm::sendBatch(array_map(fn ($t) => ['token' => $t, 'title' => 'መሠረተ ሕይወት', 'body' => 'Test ✓', 'data' => ['channel' => 'default', 'entity_type' => 'system', 'entity_id' => '']], $tokens))
            : [];
        $errors = array_values(array_unique(array_filter(array_map(fn ($x) => $x['ok'] ? null : ($x['error'] ?? null), $results))));
        return Http::ok($status + ['tokens' => count($tokens), 'delivered' => count(array_filter($results, fn ($x) => $x['ok'])), 'errors' => $errors]);
    });
    Route::delete('fcm-tokens', function () {
        $b = Ctx::body(Z::object(['token' => Z::string()->min(20)->max(255)]));
        Account::removeFcmToken(Ctx::auth(), $b['token']);
        return Http::ok(null);
    });

    Route::get('activity', fn () => Http::ok(Account::myActivity(Ctx::auth()->id, Page::params(Ctx::q()))));
    Route::post('activity', function () {
        $b = Ctx::body(Z::object([
            'action' => Z::string()->refine(fn ($a) => in_array($a, Activity::CLIENT_REPORTABLE, true), 'ACTION_NOT_ALLOWED'),
            'entity_type' => Z::enum(['mezmur', 'program', 'notification', 'page', 'category'])->optional(),
            'entity_id' => Z::number()->int()->positive()->optional(),
            'metadata' => Z::record(Z::union([Z::string()->max(200), Z::number(), Z::boolean()]))->optional(),
            'client_event_id' => Z::string()->uuid()->optional(),
            'occurred_at' => Z::coerceDate()->optional(),
        ]));
        if (Ctx::auth()->isSystem) {
            throw ApiError::forbidden();
        }
        Activity::track(Ctx::auth()->id, $b['action'], $b['entity_type'] ?? null, $b['entity_id'] ?? null, $b['metadata'] ?? null, $b['client_event_id'] ?? null, $b['occurred_at'] ?? null);
        return Http::ok(null, null, 'Recorded', 202);
    });
});
