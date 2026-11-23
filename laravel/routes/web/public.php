<?php

use App\Mz\Services\Releases;
use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Public files, the APK download page, share links and Android App Links verification
// (port of the static /files mount in app.js, share.routes.js and the /download router).

/**
 * Public uploads (covers, audio, images). Range requests are supported for audio seeking.
 * /storage/… is normally served by the web server through the public/storage link; this route answers
 * when the link is missing. /files/… keeps older links working.
 */
$publicFile = function (string $path) {
    $segments = explode('/', $path);
    foreach ($segments as $s) {
        if ($s === '' || $s === '..' || str_starts_with($s, '.')) throw ApiError::notFound('ROUTE_NOT_FOUND', 'Route not found');
    }
    try {
        $abs = Storage::publicPath($path);
    } catch (\Throwable) {
        throw ApiError::notFound('ROUTE_NOT_FOUND', 'Route not found');
    }
    if (! is_file($abs)) throw ApiError::notFound('ROUTE_NOT_FOUND', 'Route not found');
    $headers = [
        'Cache-Control' => 'public, max-age=604800',
        'X-Content-Type-Options' => 'nosniff',
        'Accept-Ranges' => 'bytes',
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Headers' => 'Range, Authorization, Content-Type',
        'Access-Control-Expose-Headers' => 'Content-Range, Content-Length, Accept-Ranges',
    ];
    $ext = strtolower(pathinfo($abs, PATHINFO_EXTENSION));
    $isMediaOrDoc = in_array($ext, [
        'pdf', 'mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac', 'amr', 'aif', 'aiff',
        'mp4', 'webm', 'mov', '3gp', '3g2', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'lrc', 'txt'
    ], true);
    if (! $isMediaOrDoc) {
        $headers['Content-Security-Policy'] = "default-src 'none'; sandbox";
    }
    return response()->file($abs, $headers);
};
Route::get('files/{path}', $publicFile)->where('path', '.*');
Route::get('storage/{path}', $publicFile)->where('path', '.*');

// Web alias for library books file (so older clients and web readers work seamlessly)
Route::get('library/books/{id}/file', function (int $id) {
    $token = request()->bearerToken() ?: request()->query('token');
    $auth = $token ? \App\Mz\Auth\Catalog::authenticateToken($token) : \App\Mz\Http\Ctx::auth();
    $f = \App\Mz\Services\Library::file($auth, $id);
    $headers = [
        'Content-Type' => $f['mime'],
        'Accept-Ranges' => 'bytes',
        'Cache-Control' => 'private, max-age=3600',
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Headers' => 'Range, Authorization, Content-Type',
        'Access-Control-Expose-Headers' => 'Content-Range, Content-Length, Accept-Ranges',
    ];
    if (request()->query('download') === '1' || request()->query('download') === 'true') {
        return response()->download($f['abs'], $f['name'], $headers);
    }
    return response()->file($f['abs'], $headers + [
        'Content-Disposition' => 'inline; filename="' . $f['name'] . '"',
    ]);
});

// OpenAPI spec (generated from ../backend/docs/openapi.yaml).
Route::get('api/openapi.json', fn () => response(file_get_contents(resource_path('openapi.json')), 200, ['Content-Type' => 'application/json; charset=utf-8']));

// ---- /download ----
Route::get('download', fn () => response(Releases::renderDownloadPage(), 200, ['Content-Type' => 'text/html; charset=utf-8', 'Cache-Control' => 'no-cache']));
Route::get('download/assets/logo.jpg', fn () => response()->file(resource_path('static/logo.jpg'), ['Cache-Control' => 'public, max-age=86400']));
Route::get('download/android/{code}.apk', function (string $code) {
    if ($code !== 'latest' && ! preg_match('/^\d+$/', $code)) throw ApiError::notFound();
    $f = Releases::fileFor($code);
    return response()->download($f['abs'], $f['filename'], ['Content-Type' => 'application/vnd.android.package-archive']);
});

// ---- Share links: /m/12 (Mezmur), /p/12 (program), /c/12 (category), /pg/12 (page) ----
Route::get('.well-known/assetlinks.json', function () {
    $certs = config('mz.android.cert_sha256', []);
    $statements = $certs ? [[
        'relation' => ['delegate_permission/common.handle_all_urls'],
        'target' => ['namespace' => 'android_app', 'package_name' => config('mz.android.package'), 'sha256_cert_fingerprints' => $certs],
    ]] : [];
    return response()->json($statements, 200, ['Cache-Control' => 'public, max-age=3600'], JSON_UNESCAPED_SLASHES);
});

Route::get('{kind}/{id}', function (string $kind, string $id) {
    $id = (int) $id;
    $kinds = [
        'm' => ["/home/mezmur/$id", fn () => DB::table('mezmurs')->where(['id' => $id, 'status' => 'published'])->whereNull('deleted_at')->first(['title', DB::raw('LEFT(lyrics, 200) as description'), 'cover_image as image'])],
        // Special events stay private: only general programs show their details publicly.
        'p' => ["/programs/$id", fn () => DB::table('programs')->where(['id' => $id, 'audience' => 'all'])->where('status', '!=', 'draft')->first(['title', 'description', 'image'])],
        'c' => ["/home/category/$id", fn () => DB::table('categories')->where(['id' => $id, 'is_active' => true])->first(['name as title', 'description', 'image'])],
        'pg' => ["/home/page/$id", fn () => DB::table('pages')->where(['id' => $id, 'status' => 'published'])->first(['title', 'summary as description', 'cover_image as image'])],
    ];
    [$appPath, $load] = $kinds[$kind];
    $row = $load();
    $base = config('mz.public_base_url');
    $title = $row->title ?? T::t('share.notfound');
    $description = mb_substr(trim(preg_replace('/\s+/u', ' ', (string) ($row->description ?? ''))), 0, 180);
    $image = ! empty($row->image) ? Storage::url($row->image) : "$base/download/assets/logo.jpg";
    $html = \App\Mz\Notifications\DeepLinks::landing($appPath, $title, $description, $image);
    return response($html, 200, ['Content-Type' => 'text/html; charset=utf-8', 'Cache-Control' => 'public, max-age=300']);
})->where(['kind' => 'm|p|c|pg', 'id' => '\d+']);

// ---- Links from emails / notifications to content that has no public preview (a task, a
// borrowing, a class…): the page shows nothing about it — the app opens it and checks access.
Route::get('open/{type}/{id}', function (string $type, string $id) {
    $html = \App\Mz\Notifications\DeepLinks::landing('/o/' . $type . '/' . (int) $id, T::t('share.open'));
    return response($html, 200, ['Content-Type' => 'text/html; charset=utf-8', 'Cache-Control' => 'no-store']);
})->where(['type' => implode('|', \App\Mz\Notifications\DeepLinks::OPEN_TYPES), 'id' => '\d+']);

// ---- Certificate Verification (F13) ----
Route::get('verify/{code}', fn (string $code) => \App\Mz\Services\EduCertificates::renderVerifyWebPage($code));
Route::get('api/v1/certificates/verify/{code}', fn (string $code) => \App\Mz\Support\Http::ok(\App\Mz\Services\EduCertificates::verify($code)));
