<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    try {
        DB::select('SELECT 1');
        return response()->json(['status' => 'ok']);
    } catch (Throwable) {
        return response()->json(['status' => 'unavailable'], 503);
    }
});

$serveSpaHtml = function () {
    $path = public_path('index.html');
    if (file_exists($path)) {
        return response()->file($path, [
            'Cache-Control' => 'no-cache, no-store, must-revalidate',
            'Pragma' => 'no-cache',
            'Expires' => '0',
        ]);
    }
    return response()->json([
        'name' => 'Mezmur Zemseretee Hiwot API',
        'status' => 'running',
        'version' => '1.5.3',
        'health' => '/health',
        'download' => '/download',
    ]);
};

Route::get('/', $serveSpaHtml);

// Public files, the download page and share links: routes/web/*.php.
foreach (glob(__DIR__ . '/web/*.php') as $file) {
    require $file;
}

// SPA fallback for Flutter Web: return index.html for GET requests that are not API calls.
Route::fallback(function (\Illuminate\Http\Request $request) use ($serveSpaHtml) {
    if ($request->isMethod('GET') && ! $request->is('api/*') && file_exists(public_path('index.html'))) {
        return $serveSpaHtml();
    }
    throw \App\Mz\Support\ApiError::notFound('ROUTE_NOT_FOUND', 'Route not found');
});
