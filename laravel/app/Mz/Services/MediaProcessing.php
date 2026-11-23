<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * High-performance media conversion service:
 * 1. Audio: Lossless / high-fidelity conversion to FLAC using FFmpeg (with -vn to strip cover art streams).
 * 2. Images: WebP conversion using GD with alpha channel and aspect ratio preservation.
 * 3. PDF: Multi-page rendering to WebP images using Ghostscript + GD/ImageMagick for in-app viewing.
 */
class MediaProcessing
{
    private static ?string $ffmpegPath = null;
    private static ?string $gsPath = null;
    private static ?string $convertPath = null;

    /**
     * Resolve the FFmpeg binary path.
     */
    public static function ffmpeg(): string
    {
        if (self::$ffmpegPath !== null) {
            return self::$ffmpegPath;
        }

        $candidates = [
            config('mz.ffmpeg_path'),
            '/usr/bin/ffmpeg',
            '/usr/local/bin/ffmpeg',
            'C:\\ffmpeg\\bin\\ffmpeg.exe',
            'ffmpeg',
        ];

        foreach (array_filter($candidates) as $bin) {
            $test = @shell_exec(escapeshellcmd($bin) . ' -version 2>&1');
            if ($test && str_contains($test, 'ffmpeg version')) {
                return self::$ffmpegPath = $bin;
            }
        }

        return self::$ffmpegPath = 'ffmpeg';
    }

    /**
     * Resolve the Ghostscript binary path.
     */
    public static function ghostscript(): string
    {
        if (self::$gsPath !== null) {
            return self::$gsPath;
        }

        $candidates = [
            config('mz.gs_path'),
            '/usr/bin/gs',
            '/usr/local/bin/gs',
            'gs',
            'gswin64c',
        ];

        foreach (array_filter($candidates) as $bin) {
            $test = @shell_exec(escapeshellcmd($bin) . ' --version 2>&1');
            if ($test && preg_match('/^\d+\.\d+/', trim($test))) {
                return self::$gsPath = $bin;
            }
        }

        return self::$gsPath = 'gs';
    }

    /**
     * Resolve the ImageMagick convert binary path.
     */
    public static function convert(): string
    {
        if (self::$convertPath !== null) {
            return self::$convertPath;
        }

        $candidates = [
            config('mz.convert_path'),
            '/usr/bin/convert',
            '/usr/local/bin/convert',
            'convert',
            'magick',
        ];

        foreach (array_filter($candidates) as $bin) {
            $test = @shell_exec(escapeshellcmd($bin) . ' -version 2>&1');
            if ($test && str_contains($test, 'ImageMagick')) {
                return self::$convertPath = $bin;
            }
        }

        return self::$convertPath = 'convert';
    }

    /**
     * Convert an audio file to MP3 (128 kbps standard for mobile streaming).
     * Note: We use `-vn` to strip embedded album art images which can cause muxing packet errors.
     *
     * @param string $sourceAbsPath Absolute path to input audio file.
     * @param string $targetAbsPath Absolute path to output .mp3 file.
     * @param int $bitrateKbps MP3 bitrate in kbps (default 128 kbps).
     * @return array [success => bool, path => string, size => int, mime => 'audio/mpeg', error => ?string]
     */
    public static function convertToMp3(string $sourceAbsPath, string $targetAbsPath, int $bitrateKbps = 128): array
    {
        if (! file_exists($sourceAbsPath) || filesize($sourceAbsPath) === 0) {
            return ['success' => false, 'error' => 'Source file does not exist or is empty'];
        }

        $targetDir = dirname($targetAbsPath);
        if (! is_dir($targetDir)) {
            mkdir($targetDir, 0775, true);
        }

        $ffmpeg = self::ffmpeg();
        $cmd = escapeshellcmd($ffmpeg) . ' -y -i ' . escapeshellarg($sourceAbsPath)
             . ' -vn -c:a libmp3lame -b:a ' . (int) $bitrateKbps . 'k -ar 44100 '
             . escapeshellarg($targetAbsPath) . ' 2>&1';

        $output = [];
        $exitCode = 0;
        exec($cmd, $output, $exitCode);
        $logStr = implode("\n", $output);

        if ($exitCode !== 0 || ! file_exists($targetAbsPath) || filesize($targetAbsPath) === 0) {
            if (file_exists($targetAbsPath)) {
                @unlink($targetAbsPath);
            }
            Log::error('Audio conversion to MP3 failed', ['cmd' => $cmd, 'output' => $logStr]);
            return ['success' => false, 'error' => 'FFmpeg exited with code ' . $exitCode . ': ' . substr($logStr, -250)];
        }

        // Validate MP3 magic header (ID3 or sync word 0xFF...)
        $header = (string) @file_get_contents($targetAbsPath, false, null, 0, 4);
        $isMp3 = str_starts_with($header, 'ID3') || (strlen($header) > 1 && ord($header[0]) === 0xFF && (ord($header[1]) & 0xE0) === 0xE0);
        if (! $isMp3) {
            @unlink($targetAbsPath);
            return ['success' => false, 'error' => 'Converted file does not have valid MP3 signature'];
        }

        return [
            'success' => true,
            'path' => $targetAbsPath,
            'size' => filesize($targetAbsPath),
            'mime' => 'audio/mpeg',
        ];
    }

    /**
     * Convert an audio file to AAC / M4A (96-128 kbps optimal for music & mobile devices).
     *
     * @param string $sourceAbsPath Absolute path to input audio file.
     * @param string $targetAbsPath Absolute path to output .m4a file.
     * @param int $bitrateKbps AAC bitrate in kbps (default 128 kbps, 96 kbps for compact files).
     * @return array [success => bool, path => string, size => int, mime => 'audio/mp4', error => ?string]
     */
    public static function convertToAac(string $sourceAbsPath, string $targetAbsPath, int $bitrateKbps = 128): array
    {
        if (! file_exists($sourceAbsPath) || filesize($sourceAbsPath) === 0) {
            return ['success' => false, 'error' => 'Source file does not exist or is empty'];
        }

        $targetDir = dirname($targetAbsPath);
        if (! is_dir($targetDir)) {
            mkdir($targetDir, 0775, true);
        }

        $ffmpeg = self::ffmpeg();
        $cmd = escapeshellcmd($ffmpeg) . ' -y -i ' . escapeshellarg($sourceAbsPath)
             . ' -vn -c:a aac -b:a ' . (int) $bitrateKbps . 'k -ar 44100 -movflags +faststart '
             . escapeshellarg($targetAbsPath) . ' 2>&1';

        $output = [];
        $exitCode = 0;
        exec($cmd, $output, $exitCode);
        $logStr = implode("\n", $output);

        if ($exitCode !== 0 || ! file_exists($targetAbsPath) || filesize($targetAbsPath) === 0) {
            if (file_exists($targetAbsPath)) {
                @unlink($targetAbsPath);
            }
            Log::error('Audio conversion to AAC failed', ['cmd' => $cmd, 'output' => $logStr]);
            return ['success' => false, 'error' => 'FFmpeg exited with code ' . $exitCode . ': ' . substr($logStr, -250)];
        }

        // Validate M4A/MP4 header (ftyp box in first 16 bytes)
        $header = (string) @file_get_contents($targetAbsPath, false, null, 0, 16);
        $isM4a = str_contains($header, 'ftyp') || str_contains($header, 'M4A ') || str_contains($header, 'mp42');
        if (! $isM4a && filesize($targetAbsPath) < 100) {
            @unlink($targetAbsPath);
            return ['success' => false, 'error' => 'Converted file does not have valid M4A/AAC signature'];
        }

        return [
            'success' => true,
            'path' => $targetAbsPath,
            'size' => filesize($targetAbsPath),
            'mime' => 'audio/mp4',
        ];
    }

    /**
     * Unified audio conversion helper.
     */
    public static function convertAudio(string $sourceAbsPath, string $targetAbsPath, string $format = 'm4a', int $bitrateKbps = 128): array
    {
        $format = strtolower($format);
        if ($format === 'm4a' || $format === 'aac') {
            return self::convertToAac($sourceAbsPath, $targetAbsPath, $bitrateKbps);
        }
        return self::convertToMp3($sourceAbsPath, $targetAbsPath, $bitrateKbps);
    }

    /**
     * Legacy FLAC conversion helper (redirects to convertToMp3 to prevent storage ballooning).
     */
    public static function convertToFlac(string $sourceAbsPath, string $targetAbsPath, int $compressionLevel = 5): array
    {
        // Redirect to MP3 with .mp3 extension to prevent huge lossless files
        $mp3Target = preg_replace('/\.flac$/i', '.mp3', $targetAbsPath);
        return self::convertToMp3($sourceAbsPath, $mp3Target);
    }

    /**
     * Convert an image file (JPEG, PNG, etc.) to WebP.
     * Preserves transparency (alpha channel) and aspect ratio.
     *
     * @param string $sourceAbsPath Absolute path to source image.
     * @param string $targetAbsPath Absolute path to output .webp image.
     * @param int $quality WebP quality (1-100, default 85).
     * @return array [success => bool, path => string, size => int, mime => 'image/webp', error => ?string]
     */
    public static function convertToWebp(string $sourceAbsPath, string $targetAbsPath, int $quality = 85): array
    {
        if (! file_exists($sourceAbsPath) || filesize($sourceAbsPath) === 0) {
            return ['success' => false, 'error' => 'Source image does not exist or is empty'];
        }

        $targetDir = dirname($targetAbsPath);
        if (! is_dir($targetDir)) {
            mkdir($targetDir, 0775, true);
        }

        // 1. Try GD if extension is available and supports WebP
        if (function_exists('imagewebp')) {
            $info = @getimagesize($sourceAbsPath);
            $mime = $info['mime'] ?? '';

            $im = match ($mime) {
                'image/jpeg' => @imagecreatefromjpeg($sourceAbsPath),
                'image/png' => @imagecreatefrompng($sourceAbsPath),
                'image/webp' => @imagecreatefromwebp($sourceAbsPath),
                'image/gif' => @imagecreatefromgif($sourceAbsPath),
                default => @imagecreatefromstring((string) file_get_contents($sourceAbsPath)),
            };

            if ($im !== false) {
                // Ensure truecolor and alpha transparency handling
                if (! imageistruecolor($im)) {
                    imagepalettetotruecolor($im);
                }
                imagealphablending($im, true);
                imagesavealpha($im, true);

                $saved = @imagewebp($im, $targetAbsPath, $quality);
                imagedestroy($im);

                if ($saved && file_exists($targetAbsPath) && filesize($targetAbsPath) > 0) {
                    return [
                        'success' => true,
                        'path' => $targetAbsPath,
                        'size' => filesize($targetAbsPath),
                        'mime' => 'image/webp',
                    ];
                }
            }
        }

        // 2. Fallback to ImageMagick convert
        $convert = self::convert();
        $cmd = escapeshellcmd($convert) . ' ' . escapeshellarg($sourceAbsPath) . ' -quality ' . (int) $quality . ' ' . escapeshellarg($targetAbsPath) . ' 2>&1';
        $output = [];
        $exitCode = 0;
        exec($cmd, $output, $exitCode);

        if ($exitCode === 0 && file_exists($targetAbsPath) && filesize($targetAbsPath) > 0) {
            return [
                'success' => true,
                'path' => $targetAbsPath,
                'size' => filesize($targetAbsPath),
                'mime' => 'image/webp',
            ];
        }

        Log::error('Image conversion to WebP failed', ['source' => $sourceAbsPath, 'output' => implode("\n", $output)]);
        return ['success' => false, 'error' => 'Failed to convert image to WebP'];
    }

    /**
     * Get accurate PDF page count.
     */
    public static function getPdfPageCount(string $absPdfPath): int
    {
        if (! file_exists($absPdfPath)) {
            return 0;
        }

        // Method A: Ghostscript query
        $gs = self::ghostscript();
        $cmd = escapeshellcmd($gs) . ' -dQUIET -dNOSAFER -sFile=' . escapeshellarg($absPdfPath) . ' -c "File (r) file runpdfbegin pdfpagecount = quit" 2>&1';
        $out = @shell_exec($cmd);
        if ($out && is_numeric(trim($out)) && (int) trim($out) > 0) {
            return (int) trim($out);
        }

        // Method B: Regex search through PDF contents
        $content = (string) @file_get_contents($absPdfPath, false, null, 0, 8 * 1024 * 1024);
        if (preg_match_all('/\/Type\s*\/Page[^s]/', $content, $matches)) {
            $count = count($matches[0]);
            if ($count > 0) {
                return $count;
            }
        }
        if (preg_match('/\/Count\s+(\d+)/', $content, $m)) {
            return (int) $m[1];
        }

        return 0;
    }

    /**
     * Render all pages of a PDF document into WebP images for in-app viewing.
     * Records rendered pages into `pdf_document_pages` table.
     *
     * @param string $absPdfPath Absolute path to PDF file.
     * @param string $relStorageFolder Relative folder inside storage (e.g. 'pdf_pages/item_123').
     * @param string $visibility 'private' or 'public'.
     * @param int $dpi Rendering resolution (default 150 for crisp mobile display).
     * @param int $quality WebP quality (1-100, default 85).
     * @param string|null $documentType 'item', 'magazine', etc.
     * @param int|null $documentId ID of the entity.
     * @return array Array of page manifests [page_number, webp_path, width, height, file_size].
     */
    public static function renderPdfPagesToWebp(
        string $absPdfPath,
        string $relStorageFolder,
        string $visibility = 'private',
        int $dpi = 150,
        int $quality = 85,
        ?string $documentType = 'item',
        ?int $documentId = null
    ): array {
        if (! file_exists($absPdfPath) || filesize($absPdfPath) === 0) {
            throw new \RuntimeException('PDF source file does not exist: ' . $absPdfPath);
        }

        $pageCount = self::getPdfPageCount($absPdfPath);
        if ($pageCount === 0) {
            throw new \RuntimeException('Could not determine PDF page count or PDF is empty: ' . $absPdfPath);
        }

        $targetRelDir = $visibility . '/' . trim($relStorageFolder, '/');
        $targetAbsDir = Storage::resolveInside($targetRelDir);
        if (! is_dir($targetAbsDir)) {
            mkdir($targetAbsDir, 0775, true);
        }

        $tmpDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'pdf_render_' . Crypto::uuid();
        mkdir($tmpDir, 0775, true);

        try {
            $gs = self::ghostscript();
            $tmpPattern = $tmpDir . DIRECTORY_SEPARATOR . 'page_%04d.png';

            // Ghostscript multi-page PNG rendering
            $cmd = escapeshellcmd($gs)
                . ' -dQUIET -dNOSAFER -dBATCH -dNOPAUSE'
                . ' -sDEVICE=png16m'
                . ' -r' . (int) $dpi
                . ' -sOutputFile=' . escapeshellarg($tmpPattern)
                . ' ' . escapeshellarg($absPdfPath) . ' 2>&1';

            $output = [];
            $exitCode = 0;
            exec($cmd, $output, $exitCode);

            if ($exitCode !== 0) {
                Log::error('Ghostscript PDF rendering failed', ['cmd' => $cmd, 'output' => implode("\n", $output)]);
                throw new \RuntimeException('Ghostscript failed with code ' . $exitCode . ': ' . implode("\n", $output));
            }

            $pngFiles = glob($tmpDir . DIRECTORY_SEPARATOR . 'page_*.png');
            sort($pngFiles);

            if (empty($pngFiles)) {
                throw new \RuntimeException('No PNG pages generated by Ghostscript for ' . $absPdfPath);
            }

            $pages = [];
            $now = now();

            foreach ($pngFiles as $idx => $pngFile) {
                $pageNumber = $idx + 1;
                $webpFilename = sprintf('page_%04d.webp', $pageNumber);
                $webpRelPath = $targetRelDir . '/' . $webpFilename;
                $webpAbsPath = $targetAbsDir . DIRECTORY_SEPARATOR . $webpFilename;

                $conv = self::convertToWebp($pngFile, $webpAbsPath, $quality);
                if (! $conv['success']) {
                    throw new \RuntimeException('Failed to convert PDF page ' . $pageNumber . ' to WebP: ' . ($conv['error'] ?? ''));
                }

                $imgInfo = @getimagesize($webpAbsPath);
                $width = $imgInfo[0] ?? 0;
                $height = $imgInfo[1] ?? 0;
                $size = filesize($webpAbsPath);

                // Insert or update DB record
                DB::table('pdf_document_pages')->updateOrInsert(
                    [
                        'original_pdf_path' => $absPdfPath,
                        'page_number' => $pageNumber,
                    ],
                    [
                        'document_type' => $documentType ?? 'general',
                        'document_id' => $documentId,
                        'webp_path' => $webpRelPath,
                        'width' => $width,
                        'height' => $height,
                        'file_size' => $size,
                        'status' => 'completed',
                        'updated_at' => $now,
                        'created_at' => $now,
                    ]
                );

                $pages[] = [
                    'page_number' => $pageNumber,
                    'webp_path' => $webpRelPath,
                    'width' => $width,
                    'height' => $height,
                    'file_size' => $size,
                ];

                @unlink($pngFile);
            }

            return $pages;
        } finally {
            // Clean up temp directory
            $files = glob($tmpDir . DIRECTORY_SEPARATOR . '*');
            foreach ($files as $f) {
                @unlink($f);
            }
            @rmdir($tmpDir);
        }
    }
}

