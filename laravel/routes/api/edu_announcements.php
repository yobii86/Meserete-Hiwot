<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\EduAnnouncements;
use App\Mz\Support\EduSchemas;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

Route::prefix('edu')->middleware(['mz', 'mz.module:education'])->group(function () {
    // ---- students: class announcement feed & detail ----
    $feedHandler = function () {
        $courseId = Ctx::q()['course_id'] ?? null;
        $classId = Ctx::q()['class_id'] ?? null;
        return Http::ok(EduAnnouncements::feed(
            Ctx::auth(),
            is_numeric($courseId) ? (int) $courseId : null,
            is_numeric($classId) ? (int) $classId : null
        ));
    };
    Route::get('announcements', $feedHandler);
    Route::get('me/announcements', $feedHandler);

    $detailHandler = fn () => Http::ok(EduAnnouncements::detail(Ctx::auth(), Ctx::id()));
    Route::get('announcements/{id}', $detailHandler);
    Route::get('me/announcements/{id}', $detailHandler);

    // ---- teachers & admins: announcement publishing & management ----
    Route::get('courses/{id}/announcements', fn () => Http::ok(EduAnnouncements::teacherList(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/announcements', function () {
        $id = Ctx::id();
        $b = Ctx::body(EduSchemas::announcement()->partial());
        $b['course_id'] = $id;
        return Http::created(EduAnnouncements::create(Ctx::actx(), $b));
    });
    Route::get('teacher/announcements', fn () => Http::ok(EduAnnouncements::teacherList(Ctx::auth())));

    $createHandler = fn () => Http::created(EduAnnouncements::create(Ctx::actx(), Ctx::body(EduSchemas::announcement())));
    Route::post('announcements', $createHandler);
    Route::post('teacher/announcements', $createHandler);

    $updateHandler = function () {
        $id = Ctx::id();
        return Http::ok(EduAnnouncements::update(Ctx::actx(), $id, Ctx::body(EduSchemas::announcement()->partial()->strict())));
    };
    Route::patch('announcements/{id}', $updateHandler);
    Route::patch('teacher/announcements/{id}', $updateHandler);

    $deleteHandler = function () {
        EduAnnouncements::delete(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    };
    Route::delete('announcements/{id}', $deleteHandler);
    Route::delete('teacher/announcements/{id}', $deleteHandler);
});
