<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Migration engine for audio (FLAC), images (WebP), and PDF documents (WebP pages).
 * Provides safe, non-destructive, batch processing with dry-run support, atomic DB updates,
 * and comprehensive savings reporting.
 */
class MediaMigration
{
    /**
     * Scan database and storage for unconverted media items.
     * Populates or updates the `media_conversions` table.
     */
    public static function scan(array $options = []): array
    {
        $now = now();
        $discovered = ['audio' => 0, 'image' => 0, 'pdf' => 0];
        $targetAudioFormat = strtolower($options['audio_format'] ?? 'm4a');
        if ($targetAudioFormat !== 'mp3' && $targetAudioFormat !== 'm4a') {
            $targetAudioFormat = 'm4a';
        }
        $force = ! empty($options['force']) || ! empty($options['rescan']);

        // 1. Scan Audio: mezmurs (audio_path)
        $mezmurs = DB::table('mezmurs')
            ->whereNull('deleted_at')
            ->whereNotNull('audio_path')
            ->where('audio_path', '!=', '')
            ->get(['id', 'audio_path', 'audio_mime', 'audio_size']);

        foreach ($mezmurs as $m) {
            $path = $m->audio_path;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));

            if ($ext === $targetAudioFormat && ! $force) {
                // Already in target format, no conversion needed.
                continue;
            }

            $needsConversion = $force || ($ext !== $targetAudioFormat);
            if (! $needsConversion) {
                $existing = DB::table('media_conversions')
                    ->where('original_path', $path)
                    ->where('converted_format', $targetAudioFormat)
                    ->where('status', 'completed')
                    ->first();
                if (! $existing) {
                    $needsConversion = true;
                }
            }

            if ($needsConversion) {
                $abs = self::resolveSafe($path);
                if (! $abs || ! file_exists($abs)) {
                    continue;
                }
                $size = filesize($abs);

                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => $targetAudioFormat],
                    [
                        'media_type' => 'audio',
                        'entity_type' => 'mezmur',
                        'entity_id' => $m->id,
                        'source_column' => 'audio_path',
                        'original_format' => $ext ?: 'audio',
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['audio']++;
            }
        }

        // 2. Scan Images: mezmurs (cover_image)
        $covers = DB::table('mezmurs')
            ->whereNull('deleted_at')
            ->whereNotNull('cover_image')
            ->where('cover_image', '!=', '')
            ->get(['id', 'cover_image']);

        foreach ($covers as $m) {
            $path = $m->cover_image;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif'], true)) {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : 0;
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp'],
                    [
                        'media_type' => 'image',
                        'entity_type' => 'mezmur',
                        'entity_id' => $m->id,
                        'source_column' => 'cover_image',
                        'original_format' => $ext,
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['image']++;
            }
        }

        // 3. Scan Images: items (image)
        $itemImages = DB::table('items')
            ->whereNull('deleted_at')
            ->whereNotNull('image')
            ->where('image', '!=', '')
            ->get(['id', 'image']);

        foreach ($itemImages as $it) {
            $path = $it->image;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif'], true)) {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : 0;
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp'],
                    [
                        'media_type' => 'image',
                        'entity_type' => 'item',
                        'entity_id' => $it->id,
                        'source_column' => 'image',
                        'original_format' => $ext,
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['image']++;
            }
        }

        // 4. Scan Images: edu_magazines (cover_image)
        $magCovers = DB::table('edu_magazines')
            ->whereNull('deleted_at')
            ->whereNotNull('cover_image')
            ->where('cover_image', '!=', '')
            ->get(['id', 'cover_image']);

        foreach ($magCovers as $mag) {
            $path = $mag->cover_image;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif'], true)) {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : 0;
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp'],
                    [
                        'media_type' => 'image',
                        'entity_type' => 'edu_magazine',
                        'entity_id' => $mag->id,
                        'source_column' => 'cover_image',
                        'original_format' => $ext,
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['image']++;
            }
        }

        // 5. Scan Images: users (profile_image)
        $users = DB::table('users')
            ->whereNull('deleted_at')
            ->whereNotNull('profile_image')
            ->where('profile_image', '!=', '')
            ->get(['id', 'profile_image']);

        foreach ($users as $u) {
            $path = $u->profile_image;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if (in_array($ext, ['jpg', 'jpeg', 'png'], true)) {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : 0;
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp'],
                    [
                        'media_type' => 'image',
                        'entity_type' => 'user',
                        'entity_id' => $u->id,
                        'source_column' => 'profile_image',
                        'original_format' => $ext,
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['image']++;
            }
        }

        // 6. Scan Images: categories (image)
        $cats = DB::table('categories')
            ->whereNotNull('image')
            ->where('image', '!=', '')
            ->get(['id', 'image']);

        foreach ($cats as $c) {
            $path = $c->image;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if (in_array($ext, ['jpg', 'jpeg', 'png'], true)) {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : 0;
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp'],
                    [
                        'media_type' => 'image',
                        'entity_type' => 'category',
                        'entity_id' => $c->id,
                        'source_column' => 'image',
                        'original_format' => $ext,
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['image']++;
            }
        }

        // 7. Scan PDFs: items (digital books)
        $books = DB::table('items')
            ->whereNull('deleted_at')
            ->where('kind', 'digital')
            ->whereNotNull('file_path')
            ->where('file_path', '!=', '')
            ->get(['id', 'file_path', 'file_size']);

        foreach ($books as $b) {
            $path = $b->file_path;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if ($ext === 'pdf') {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : ($b->file_size ?: 0);
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp_pages'],
                    [
                        'media_type' => 'pdf',
                        'entity_type' => 'item',
                        'entity_id' => $b->id,
                        'source_column' => 'file_path',
                        'original_format' => 'pdf',
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['pdf']++;
            }
        }

        // 8. Scan PDFs: edu_magazines (pdf_path)
        $mags = DB::table('edu_magazines')
            ->whereNull('deleted_at')
            ->whereNotNull('pdf_path')
            ->where('pdf_path', '!=', '')
            ->get(['id', 'pdf_path', 'pdf_size']);

        foreach ($mags as $m) {
            $path = $m->pdf_path;
            $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
            if ($ext === 'pdf') {
                $abs = self::resolveSafe($path);
                $size = ($abs && file_exists($abs)) ? filesize($abs) : ($m->pdf_size ?: 0);
                DB::table('media_conversions')->updateOrInsert(
                    ['original_path' => $path, 'converted_format' => 'webp_pages'],
                    [
                        'media_type' => 'pdf',
                        'entity_type' => 'edu_magazine',
                        'entity_id' => $m->id,
                        'source_column' => 'pdf_path',
                        'original_format' => 'pdf',
                        'original_size' => $size,
                        'status' => 'pending',
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                );
                $discovered['pdf']++;
            }
        }

        return [
            'audio' => $discovered['audio'],
            'image' => $discovered['image'],
            'pdf' => $discovered['pdf'],
            'total' => array_sum($discovered),
        ];
    }

    /**
     * Get aggregate statistics on media conversions and storage savings.
     */
    public static function summary(): array
    {
        $statusCounts = DB::table('media_conversions')
            ->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();

        $typeCounts = DB::table('media_conversions')
            ->select('media_type', DB::raw('count(*) as count'))
            ->groupBy('media_type')
            ->pluck('count', 'media_type')
            ->toArray();

        $sizes = DB::table('media_conversions')
            ->where('status', 'completed')
            ->select(
                DB::raw('COALESCE(SUM(original_size), 0) as total_orig'),
                DB::raw('COALESCE(SUM(converted_size), 0) as total_conv')
            )
            ->first();

        $totalOrig = (int) ($sizes->total_orig ?? 0);
        $totalConv = (int) ($sizes->total_conv ?? 0);
        $bytesSaved = max(0, $totalOrig - $totalConv);
        $savingsPct = $totalOrig > 0 ? round(($bytesSaved / $totalOrig) * 100, 1) : 0;

        return [
            'total_items' => DB::table('media_conversions')->count(),
            'pending' => $statusCounts['pending'] ?? 0,
            'processing' => $statusCounts['processing'] ?? 0,
            'completed' => $statusCounts['completed'] ?? 0,
            'failed' => $statusCounts['failed'] ?? 0,
            'skipped' => $statusCounts['skipped'] ?? 0,
            'types' => [
                'audio' => $typeCounts['audio'] ?? 0,
                'image' => $typeCounts['image'] ?? 0,
                'pdf' => $typeCounts['pdf'] ?? 0,
            ],
            'storage' => [
                'original_bytes' => $totalOrig,
                'converted_bytes' => $totalConv,
                'bytes_saved' => $bytesSaved,
                'savings_percent' => $savingsPct,
            ],
        ];
    }

    /**
     * Run a batch of conversions.
     */
    public static function runBatch(array $options = []): array
    {
        $type = $options['type'] ?? 'all';
        $dryRun = ! empty($options['dry_run']);
        $limit = min(50, max(1, (int) ($options['limit'] ?? 10)));
        // Audio conversion ceiling for synchronous HTTP requests: max 2 tracks per batch to prevent 30s timeout
        if ($type === 'audio' && ! $dryRun && $limit > 2) {
            $limit = 2;
        }
        $force = ! empty($options['force']);
        $targetAudioFormat = strtolower($options['audio_format'] ?? 'm4a');
        if ($targetAudioFormat !== 'mp3' && $targetAudioFormat !== 'm4a') {
            $targetAudioFormat = 'm4a';
        }
        $audioBitrate = (int) ($options['audio_bitrate'] ?? 128);
        if ($audioBitrate < 64 || $audioBitrate > 320) {
            $audioBitrate = 128;
        }

        $query = DB::table('media_conversions')
            ->where(function ($q) use ($force) {
                $q->where('status', 'pending');
                if ($force) {
                    $q->orWhere('status', 'failed');
                }
            });

        if ($type !== 'all' && in_array($type, ['audio', 'image', 'pdf'], true)) {
            $query->where('media_type', $type);
        }

        $items = $query->orderBy('id', 'asc')->limit($limit)->get();
        $results = [];

        foreach ($items as $item) {
            $results[] = self::processItem($item, $dryRun, [
                'audio_format' => $targetAudioFormat,
                'audio_bitrate' => $audioBitrate,
            ]);
        }

        return [
            'processed' => count($results),
            'dry_run' => $dryRun,
            'items' => $results,
            'summary' => self::summary(),
        ];
    }

    /**
     * Process a single media conversion record.
     */
    private static function processItem(object $item, bool $dryRun, array $options = []): array
    {
        $sourceAbs = self::resolveSafe($item->original_path);
        if (! $sourceAbs || ! file_exists($sourceAbs)) {
            if (! $dryRun) {
                DB::table('media_conversions')->where('id', $item->id)->update([
                    'status' => 'skipped',
                    'error_message' => 'Source file not found on disk: ' . $item->original_path,
                    'updated_at' => now(),
                ]);
            }
            return [
                'id' => $item->id,
                'path' => $item->original_path,
                'status' => 'skipped',
                'error' => 'Source file not found on disk',
            ];
        }

        if ($dryRun) {
            // Dry run estimation
            $origSize = filesize($sourceAbs);
            $estSize = match ($item->media_type) {
                'image' => (int) ($origSize * 0.65), // avg 35% reduction for WebP
                'audio' => min($origSize, (int) ($origSize * 0.6)), // AAC/M4A 128k optimization
                'pdf' => $origSize,
                default => $origSize,
            };
            return [
                'id' => $item->id,
                'media_type' => $item->media_type,
                'path' => $item->original_path,
                'status' => 'simulated',
                'original_size' => $origSize,
                'estimated_size' => $estSize,
            ];
        }

        DB::table('media_conversions')->where('id', $item->id)->update([
            'status' => 'processing',
            'started_at' => now(),
            'updated_at' => now(),
        ]);

        try {
            return match ($item->media_type) {
                'image' => self::processImage($item, $sourceAbs),
                'audio' => self::processAudio($item, $sourceAbs, $options),
                'pdf' => self::processPdf($item, $sourceAbs),
                default => throw new \RuntimeException('Unsupported media type: ' . $item->media_type),
            };
        } catch (\Throwable $e) {
            Log::error('Media conversion failed for item ' . $item->id, ['error' => $e->getMessage()]);
            DB::table('media_conversions')->where('id', $item->id)->update([
                'status' => 'failed',
                'error_message' => substr($e->getMessage(), 0, 500),
                'retry_count' => DB::raw('retry_count + 1'),
                'updated_at' => now(),
            ]);
            return [
                'id' => $item->id,
                'path' => $item->original_path,
                'status' => 'failed',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process image -> WebP conversion and update DB.
     */
    private static function processImage(object $item, string $sourceAbs): array
    {
        $pathInfo = pathinfo($item->original_path);
        $newRel = $pathInfo['dirname'] . '/' . $pathInfo['filename'] . '.webp';
        $newAbs = Storage::resolveInside($newRel);

        $res = MediaProcessing::convertToWebp($sourceAbs, $newAbs, 85);
        if (! $res['success']) {
            throw new \RuntimeException($res['error'] ?? 'WebP conversion failed');
        }

        $now = now();
        $origSize = filesize($sourceAbs);
        $convSize = $res['size'];

        // Update database table pointer
        $table = match ($item->entity_type) {
            'mezmur' => 'mezmurs',
            'item' => 'items',
            'edu_magazine' => 'edu_magazines',
            'user' => 'users',
            'category' => 'categories',
            default => null,
        };

        if ($table && $item->source_column && $item->entity_id) {
            DB::table($table)->where('id', $item->entity_id)->update([
                $item->source_column => $newRel,
                'updated_at' => $now,
            ]);
        }

        DB::table('media_conversions')->where('id', $item->id)->update([
            'converted_path' => $newRel,
            'converted_format' => 'webp',
            'original_size' => $origSize,
            'converted_size' => $convSize,
            'status' => 'completed',
            'completed_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'id' => $item->id,
            'media_type' => 'image',
            'original_path' => $item->original_path,
            'converted_path' => $newRel,
            'original_size' => $origSize,
            'converted_size' => $convSize,
            'status' => 'completed',
        ];
    }

    /**
     * Process audio -> AAC (.m4a) or MP3 conversion and update DB.
     */
    private static function processAudio(object $item, string $sourceAbs, array $options = []): array
    {
        $targetFormat = strtolower($options['audio_format'] ?? $item->converted_format ?? 'm4a');
        if ($targetFormat !== 'mp3' && $targetFormat !== 'm4a') {
            $targetFormat = 'm4a';
        }
        $bitrate = (int) ($options['audio_bitrate'] ?? 128);
        if ($bitrate < 64 || $bitrate > 320) {
            $bitrate = 128;
        }

        $pathInfo = pathinfo($item->original_path);
        $ext = strtolower($pathInfo['extension'] ?? '');
        $baseRel = $pathInfo['dirname'] . '/' . $pathInfo['filename'];
        $now = now();
        $origSize = filesize($sourceAbs);

        // If source is already in the target format and not forcing re-encode, mark completed
        if ($ext === $targetFormat && empty($options['force_reencode'])) {
            DB::table('media_conversions')->where('id', $item->id)->update([
                'converted_path' => $item->original_path,
                'converted_format' => $targetFormat,
                'original_size' => $origSize,
                'converted_size' => $origSize,
                'status' => 'completed',
                'completed_at' => $now,
                'updated_at' => $now,
            ]);

            return [
                'id' => $item->id,
                'media_type' => 'audio',
                'original_path' => $item->original_path,
                'converted_path' => $item->original_path,
                'original_size' => $origSize,
                'converted_size' => $origSize,
                'status' => 'completed',
            ];
        }

        // New relative and absolute destination paths
        $newRel = $baseRel . '.' . $targetFormat;
        $newAbs = Storage::resolveInside($newRel);

        // Retain and safeguard original audio in backup folder
        $backupDir = storage_path('app/backups/audio');
        if (! is_dir($backupDir)) {
            @mkdir($backupDir, 0775, true);
        }
        $backupPath = $backupDir . '/' . basename($item->original_path);
        if (! file_exists($backupPath)) {
            @copy($sourceAbs, $backupPath);
        }

        // Convert audio using FFmpeg with duplicate prevention and safe atomic file replacement
        if (file_exists($newAbs) && filesize($newAbs) > 0 && empty($options['force_reencode'])) {
            $convSize = filesize($newAbs);
        } else {
            $tmpAbs = $newAbs . '.tmp.' . uniqid();
            $res = MediaProcessing::convertAudio($sourceAbs, $tmpAbs, $targetFormat, $bitrate);
            if (! $res['success'] || ! file_exists($tmpAbs) || filesize($tmpAbs) === 0) {
                if (file_exists($tmpAbs)) @unlink($tmpAbs);
                throw new \RuntimeException($res['error'] ?? 'Audio conversion failed or output is empty');
            }
            @rename($tmpAbs, $newAbs);
            $convSize = filesize($newAbs);
        }

        // If conversion created a larger file and original was already lightweight voice/amr, keep original
        if ($convSize >= $origSize && in_array($ext, ['3gp', 'amr'], true)) {
            @unlink($newAbs);
            $newRel = $item->original_path;
            $convSize = $origSize;
            $targetFormat = $ext;
        }

        // Verify converted output exists and is non-empty before updating DB
        $finalAbs = Storage::resolveInside($newRel);
        if (! file_exists($finalAbs) || filesize($finalAbs) === 0) {
            throw new \RuntimeException("Final audio file does not exist on disk at {$newRel}");
        }

        // Transactionally update mezmurs table and media_conversions table
        DB::transaction(function () use ($item, $newRel, $targetFormat, $convSize, $origSize, $now) {
            if ($item->entity_type === 'mezmur' && $item->entity_id) {
                $mime = ($targetFormat === 'm4a') ? 'audio/mp4' : 'audio/mpeg';
                DB::table('mezmurs')->where('id', $item->entity_id)->update([
                    'audio_path' => $newRel,
                    'audio_mime' => $mime,
                    'audio_size' => $convSize,
                    'content_version' => DB::raw('content_version + 1'),
                    'updated_at' => $now,
                ]);
            }

            DB::table('media_conversions')->where('id', $item->id)->update([
                'converted_path' => $newRel,
                'converted_format' => $targetFormat,
                'original_size' => $origSize,
                'converted_size' => $convSize,
                'status' => 'completed',
                'completed_at' => $now,
                'updated_at' => $now,
            ]);
        });

        return [
            'id' => $item->id,
            'media_type' => 'audio',
            'original_path' => $item->original_path,
            'converted_path' => $newRel,
            'original_size' => $origSize,
            'converted_size' => $convSize,
            'status' => 'completed',
        ];
    }

    /**
     * Process PDF -> multi-page WebP rendering.
     */
    private static function processPdf(object $item, string $sourceAbs): array
    {
        $folder = match ($item->entity_type) {
            'item' => 'pdf_pages/book_' . $item->entity_id,
            'edu_magazine' => 'images/magazines/pages_' . $item->entity_id,
            default => 'pdf_pages/doc_' . $item->id,
        };

        $visibility = ($item->entity_type === 'edu_magazine') ? 'public' : 'private';

        $pages = MediaProcessing::renderPdfPagesToWebp(
            $sourceAbs,
            $folder,
            $visibility,
            150,
            85,
            $item->entity_type,
            $item->entity_id
        );

        $now = now();
        $origSize = filesize($sourceAbs);
        $convSize = array_sum(array_column($pages, 'file_size'));

        DB::table('media_conversions')->where('id', $item->id)->update([
            'converted_path' => $visibility . '/' . $folder,
            'converted_format' => 'webp_pages',
            'original_size' => $origSize,
            'converted_size' => $convSize,
            'status' => 'completed',
            'completed_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'id' => $item->id,
            'media_type' => 'pdf',
            'original_path' => $item->original_path,
            'page_count' => count($pages),
            'original_size' => $origSize,
            'converted_size' => $convSize,
            'status' => 'completed',
        ];
    }

    /**
     * Retry failed conversions (or mark permanently missing source files as skipped).
     */
    public static function retryFailed(): int
    {
        $failed = DB::table('media_conversions')->where('status', 'failed')->get();
        $resetCount = 0;
        foreach ($failed as $item) {
            $abs = self::resolveSafe($item->original_path);
            if (! $abs || ! file_exists($abs)) {
                DB::table('media_conversions')->where('id', $item->id)->update([
                    'status' => 'skipped',
                    'error_message' => 'Source file not found on disk: ' . $item->original_path,
                    'updated_at' => now(),
                ]);
            } else {
                DB::table('media_conversions')->where('id', $item->id)->update([
                    'status' => 'pending',
                    'updated_at' => now(),
                ]);
                $resetCount++;
            }
        }
        return $resetCount;
    }

    /**
     * Detailed report of conversions for export.
     */
    public static function getReport(int $limit = 200): array
    {
        $rows = DB::table('media_conversions')
            ->orderBy('id', 'desc')
            ->limit($limit)
            ->get();

        return [
            'total' => count($rows),
            'items' => $rows,
            'summary' => self::summary(),
        ];
    }

    /**
     * Resolve a relative path safely without throwing.
     */
    private static function resolveSafe(?string $rel): ?string
    {
        if (! $rel) return null;
        try {
            return Storage::resolveInside($rel);
        } catch (\Throwable) {
            return null;
        }
    }
}

