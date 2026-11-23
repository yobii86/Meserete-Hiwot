<?php

use App\Mz\Services\Synaxarium;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

// Ethiopian Orthodox Tewahedo Synaxarium (ስንክሳር) API
Route::prefix('synaxarium')->group(function () {
    // 1. List 13 Ethiopian months
    Route::get('months', fn () => Http::ok(Synaxarium::listMonths()));

    // 2. Today's Synaxarium reading (Addis Ababa timezone)
    Route::get('today', fn () => Http::ok(Synaxarium::getToday()));

    // 3. Search Synaxarium entries and commemorated saints
    Route::get('search', function () {
        $q = (string) request()->query('q', '');
        $limit = (int) request()->query('limit', 25);
        return Http::ok(Synaxarium::search($q, $limit));
    });

    // 4. Monthly overview of entries
    Route::get('{month}', function (string $month) {
        return Http::ok(Synaxarium::getMonthEntries((int) $month));
    })->where('month', '[0-9]+');

    // 5. Daily reading with full narrative, daily saints, and saints
    Route::get('{month}/{day}', function (string $month, string $day) {
        $year = request()->query('year') ? (int) request()->query('year') : null;
        return Http::ok(Synaxarium::getEntry((int) $month, (int) $day, $year));
    })->where(['month' => '[0-9]+', 'day' => '[0-9]+']);

    // 6. Commemorated saints for specific date
    Route::get('{month}/{day}/saints', function (string $month, string $day) {
        return Http::ok(Synaxarium::getSaints((int) $month, (int) $day));
    })->where(['month' => '[0-9]+', 'day' => '[0-9]+']);
});
