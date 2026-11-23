<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\GuidanceService;
use App\Mz\Support\Http;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Guidance Center, Contextual Help, Interactive Tours, and Admin Management
Route::prefix('guidance')->group(function () {

    // 1. Public / Member Accessible Endpoints
    Route::get('/', function () {
        $q = Ctx::q();
        $filters = [
            'category' => $q['category'] ?? null,
            'screen' => $q['screen'] ?? null,
            'tour_id' => $q['tour_id'] ?? null,
            'search' => $q['search'] ?? null,
        ];
        return Http::ok(GuidanceService::listForUser(Ctx::authOrNull(), array_filter($filters)));
    })->middleware('mz:optional');

    Route::get('contextual', function () {
        $screen = Ctx::q()['screen'] ?? '';
        $article = GuidanceService::getForScreen(Ctx::authOrNull(), $screen);
        return Http::ok($article);
    })->middleware('mz:optional');

    // 2. Authenticated Tour Progress Persistence
    Route::middleware('mz')->group(function () {
        Route::get('progress', function () {
            return Http::ok(GuidanceService::getTourProgress(Ctx::auth()));
        });

        Route::post('progress', function () {
            $schema = Z::object([
                'tour_id' => V::text(1, 60),
                'completed' => Z::boolean(),
                'dismissed' => Z::boolean()->optional(),
            ]);
            $body = Ctx::body($schema);
            $res = GuidanceService::saveTourProgress(
                Ctx::auth(),
                $body['tour_id'],
                $body['completed'],
                $body['dismissed'] ?? false
            );
            return Http::ok($res);
        });

        Route::post('progress/reset', function () {
            $tourId = Ctx::input()['tour_id'] ?? null;
            GuidanceService::resetTourProgress(Ctx::auth(), $tourId);
            return Http::ok(null, null, 'Tour progress reset successfully');
        });
    });

    // 3. Admin Guidance Management Endpoints
    Route::prefix('admin')->middleware(['mz'])->group(function () {
        $assertCan = function () {
            $auth = Ctx::auth();
            if (! $auth->isAdmin && ! $auth->can('guidance.manage') && ! $auth->can('settings.manage')) {
                throw \App\Mz\Support\ApiError::forbidden('FORBIDDEN', 'Guidance management permission required');
            }
        };

        $articleSchema = fn () => Z::object([
            'title' => V::text(2, 255),
            'slug' => V::optionalText(100),
            'category' => V::text(2, 60),
            'summary' => V::optionalText(1000),
            'overview' => V::optionalText(1000),
            'content' => V::optionalText(65000),
            'target_role' => Z::enum(['all', 'member', 'leader', 'department_leader', 'teacher', 'admin'])->optional(),
            'target_screen' => V::optionalText(100),
            'required_permission' => V::optionalText(80),
            'steps' => Z::array(Z::object([
                'title' => V::text(1, 150),
                'description' => V::optionalText(500),
                'instruction' => V::optionalText(500),
                'tip' => V::optionalText(300),
                'target_key' => V::optionalText(100),
                'step' => Z::number()->int()->optional(),
            ]))->optional(),
            'tips' => Z::array(Z::string())->optional(),
            'quick_tips' => Z::array(Z::string())->optional(),
            'faq_items' => Z::array(Z::object([
                'q' => V::optionalText(255),
                'question' => V::optionalText(255),
                'a' => V::optionalText(1000),
                'answer' => V::optionalText(1000),
            ]))->optional(),
            'faqs' => Z::array(Z::object([
                'q' => V::optionalText(255),
                'question' => V::optionalText(255),
                'a' => V::optionalText(1000),
                'answer' => V::optionalText(1000),
            ]))->optional(),
            'tour_id' => V::optionalText(60),
            'icon' => V::optionalText(60),
            'sort_order' => Z::number()->int()->optional(),
            'status' => Z::enum(['draft', 'published', 'retired'])->optional(),
        ]);

        Route::get('all', function () use ($assertCan) {
            $assertCan();
            $q = Ctx::q();
            $filters = [
                'status' => $q['status'] ?? null,
                'category' => $q['category'] ?? null,
                'search' => $q['search'] ?? null,
            ];
            return Http::ok(GuidanceService::adminList(Ctx::auth(), array_filter($filters)));
        });

        Route::post('/', function () use ($assertCan, $articleSchema) {
            $assertCan();
            $data = Ctx::body($articleSchema());
            return Http::created(GuidanceService::create(Ctx::auth(), $data));
        });

        Route::patch('{id}', function (int $id) use ($assertCan, $articleSchema) {
            $assertCan();
            $data = Ctx::body($articleSchema()->partial());
            return Http::ok(GuidanceService::update(Ctx::auth(), $id, $data));
        });

        Route::post('{id}/publish', function (int $id) use ($assertCan) {
            $assertCan();
            return Http::ok(GuidanceService::publish(Ctx::auth(), $id));
        });

        Route::post('{id}/retire', function (int $id) use ($assertCan) {
            $assertCan();
            return Http::ok(GuidanceService::retire(Ctx::auth(), $id));
        });

        Route::delete('{id}', function (int $id) use ($assertCan) {
            $assertCan();
            GuidanceService::delete(Ctx::auth(), $id);
            return Http::ok(null, null, 'Guidance article deleted');
        });
    });

    // 4. Detail view by slug or ID
    Route::get('{idOrSlug}', function (string $idOrSlug) {
        $article = GuidanceService::getBySlugOrId(Ctx::authOrNull(), $idOrSlug);
        return Http::ok($article);
    })->middleware('mz:optional');
});
