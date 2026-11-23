<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\EduMagazines;
use App\Mz\Services\Library;
use App\Mz\Services\MediaMigration;
use App\Mz\Services\MediaProcessing;
use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Media Migration & In-App PDF Rendering
Route::prefix('admin/media-migration')->middleware('mz')->group(function () {
    Route::get('summary', function () {
        return Http::ok(MediaMigration::summary());
    });

    Route::post('scan', function () {
        $body = request()->json()->all() ?: [];
        return Http::ok(MediaMigration::scan($body));
    });

    Route::post('run', function () {
        $body = request()->json()->all() ?: [];
        return Http::ok(MediaMigration::runBatch($body));
    });

    Route::post('retry', function () {
        return Http::ok(['retried' => MediaMigration::retryFailed()]);
    });

    Route::get('report', function () {
        $limit = (int) (request()->query('limit') ?? 200);
        return Http::ok(MediaMigration::getReport($limit));
    });
});

Route::prefix('pdf')->group(function () {
    /**
     * Get list of pre-rendered WebP pages for a document.
     * If pages are not yet rendered, automatically generates them.
     */
    Route::get('document/{type}/{id}/pages', function (string $type, int $id) {
        $type = strtolower($type);

        $pdfPath = null;
        $visibility = 'private';
        $storageSubfolder = 'pdf_pages/' . $type . '_' . $id;

        if ($type === 'item' || $type === 'book') {
            $book = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first();
            if (! $book || ! $book->file_path) {
                throw ApiError::notFound('DOCUMENT_NOT_FOUND', 'Book PDF not found');
            }
            $pdfPath = $book->file_path;
            $visibility = 'private';
            $type = 'item';
        } elseif ($type === 'magazine' || $type === 'edu_magazine') {
            $mag = DB::table('edu_magazines')->where('id', $id)->whereNull('deleted_at')->first();
            if (! $mag || ! $mag->pdf_path) {
                throw ApiError::notFound('DOCUMENT_NOT_FOUND', 'Magazine PDF not found');
            }
            $pdfPath = $mag->pdf_path;
            $visibility = 'public';
            $type = 'magazine';
            $storageSubfolder = 'images/magazines/pages_' . $id;
        } else {
            throw ApiError::badRequest('INVALID_DOC_TYPE', 'Unsupported document type');
        }

        // Check if pages already exist in database
        $pages = DB::table('pdf_document_pages')
            ->where('document_type', $type)
            ->where('document_id', $id)
            ->where('status', 'completed')
            ->orderBy('page_number', 'asc')
            ->get();

        // If not rendered yet, generate them now
        if ($pages->isEmpty() && $pdfPath) {
            $abs = Storage::resolveInside($pdfPath);
            if (file_exists($abs)) {
                try {
                    MediaProcessing::renderPdfPagesToWebp(
                        $abs,
                        $storageSubfolder,
                        $visibility,
                        150,
                        85,
                        $type,
                        $id
                    );
                    $pages = DB::table('pdf_document_pages')
                        ->where('document_type', $type)
                        ->where('document_id', $id)
                        ->where('status', 'completed')
                        ->orderBy('page_number', 'asc')
                        ->get();
                } catch (\Throwable $e) {
                    \Illuminate\Support\Facades\Log::error('On-demand PDF page rendering failed: ' . $e->getMessage());
                }
            }
        }

        $pageItems = $pages->map(function ($p) {
            return [
                'id' => $p->id,
                'page_number' => (int) $p->page_number,
                'width' => (int) $p->width,
                'height' => (int) $p->height,
                'file_size' => (int) $p->file_size,
                'url' => url('/api/v1/pdf/page/' . $p->id),
            ];
        })->values()->all();

        return Http::ok([
            'document_type' => $type,
            'document_id' => $id,
            'total_pages' => count($pageItems),
            'pages' => $pageItems,
        ]);
    });

    /**
     * Stream a single WebP page image.
     */
    Route::get('page/{pageId}', function (int $pageId) {
        $page = DB::table('pdf_document_pages')->where('id', $pageId)->first();
        if (! $page) {
            throw ApiError::notFound('PAGE_NOT_FOUND', 'PDF page not found');
        }

        $abs = Storage::resolveInside($page->webp_path);
        if (! file_exists($abs)) {
            throw ApiError::notFound('PAGE_FILE_NOT_FOUND', 'Rendered page file missing on disk');
        }

        return response()->file($abs, [
            'Content-Type' => 'image/webp',
            'Cache-Control' => 'public, max-age=604800',
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Headers' => 'Range, Authorization, Content-Type',
            'Access-Control-Expose-Headers' => 'Content-Range, Content-Length, Accept-Ranges',
        ]);
    });

    /**
     * Trigger manual re-rendering of PDF document pages.
     */
    Route::post('document/{type}/{id}/render', function (string $type, int $id) {
        $type = strtolower($type);
        if ($type === 'book') $type = 'item';
        if ($type === 'edu_magazine') $type = 'magazine';

        $pdfPath = null;
        $visibility = 'private';
        $storageSubfolder = 'pdf_pages/' . $type . '_' . $id;

        if ($type === 'item') {
            $book = DB::table('items')->where('id', $id)->whereNull('deleted_at')->first();
            if (! $book || ! $book->file_path) throw ApiError::notFound();
            $pdfPath = $book->file_path;
            $visibility = 'private';
        } elseif ($type === 'magazine') {
            $mag = DB::table('edu_magazines')->where('id', $id)->whereNull('deleted_at')->first();
            if (! $mag || ! $mag->pdf_path) throw ApiError::notFound();
            $pdfPath = $mag->pdf_path;
            $visibility = 'public';
            $storageSubfolder = 'images/magazines/pages_' . $id;
        }

        $abs = Storage::resolveInside($pdfPath);
        $pages = MediaProcessing::renderPdfPagesToWebp(
            $abs,
            $storageSubfolder,
            $visibility,
            150,
            85,
            $type,
            $id
        );

        return Http::ok([
            'document_type' => $type,
            'document_id' => $id,
            'rendered_pages' => count($pages),
        ]);
    });
});

