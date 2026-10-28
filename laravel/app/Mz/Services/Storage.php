<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use finfo;
use Illuminate\Http\UploadedFile;
use ZipArchive;

/**
 * Uploaded files (port of storageService.js). The real type is detected from the file's bytes —
 * the client's filename and Content-Type are never trusted. Stored paths are "public/<folder>/<uuid>.<ext>"
 * or "private/<folder>/…"; each prefix maps to its own root (config mz.storage):
 *   public  → storage/app/public (linked as public/storage, URL /storage/…), or STORAGE_PATH/public (/files/…)
 *   private → storage/app/private, or STORAGE_PATH/private — only through authorised routes, never linked
 */
final class Storage
{
    public const FOLDERS = [
        'MEZMUR_COVERS' => 'images/mezmurs',
        'MEZMUR_AUDIO' => 'audio/mezmurs',
        'CATEGORY_IMAGES' => 'images/categories',
        'AD_IMAGES' => 'images/advertisements',
        'AD_FILES' => 'files/advertisements',
        'EDU_FILES' => 'files/education',
        'EDU_LESSONS' => 'files/lessons',
        'EDU_IMAGES' => 'images/education',
        'PAYMENT_RECEIPTS' => 'images/receipts',
        'PAGE_IMAGES' => 'images/pages',
        'PROGRAM_IMAGES' => 'images/programs',
        'ITEM_IMAGES' => 'images/items',
        'AVATARS' => 'images/avatars',
        'SIGNATURES' => 'signatures',
        'RELEASES' => 'releases',
        'CHAT' => 'chat',
        'PROJECTS' => 'projects',
        'BOOKS' => 'books',
        'COMPLAINTS' => 'complaints',
        'RECEIPTS' => 'receipts',
        'CONTRIBUTION_RECEIPTS' => 'receipts/contributions',
        'DIAGNOSTICS' => 'diagnostics',
    ];

    private const AUDIO_EXTS = ['mp3', 'm4a', 'aac', 'ogg', 'opus', 'oga', 'wav', 'flac', 'amr', 'aif', 'aiff', 'ape', 'wv', 'mpc', 'asf', 'mp4', 'm4b', '3gp', '3g2', 'webm', 'mka', 'mkv', 'mid', 'qcp', 'ac3', 'dsf'];

    public static function kinds(): array
    {
        $c = config('mz.storage');
        return [
            'image' => ['exts' => ['jpg', 'png', 'webp'], 'max' => $c['max_image_bytes'], 'visibility' => 'public'],
            'audio' => ['exts' => self::AUDIO_EXTS, 'audio' => true, 'max' => $c['max_audio_bytes'], 'visibility' => 'public'],
            'document' => ['exts' => ['pdf', 'jpg', 'png', 'webp', 'gif', 'docx', 'pptx', 'xlsx'], 'max' => $c['max_document_bytes'], 'visibility' => 'public'],
            'signature' => ['exts' => ['png'], 'max' => 512 * 1024, 'visibility' => 'private'],
            'chat' => ['exts' => ['jpg', 'png', 'webp', 'gif', 'mp4', 'mov', 'webm', '3gp', 'pdf', 'docx', 'pptx', 'xlsx'], 'audio' => true, 'max' => $c['max_audio_bytes'], 'visibility' => 'private'],
            // Project files and expense receipts: documents and pictures, private (department only).
            'project' => ['exts' => ['jpg', 'png', 'webp', 'gif', 'pdf', 'docx', 'pptx', 'xlsx'], 'max' => $c['max_document_bytes'], 'visibility' => 'private'],
            // Digital library books (PDF), private: downloaded only by signed-in members.
            'book' => ['exts' => ['pdf'], 'max' => $c['max_book_bytes'] ?? 60 * 1024 * 1024, 'visibility' => 'private'],
            // Lesson materials: documents, pictures and audio, private (only those who may open the
            // lesson download them). Video is linked, not uploaded; audio keeps the audio size limit.
            'lesson' => ['exts' => ['pdf', 'jpg', 'png', 'webp', 'gif', 'docx', 'pptx', 'xlsx'], 'audio' => true, 'max' => $c['max_audio_bytes'], 'visibility' => 'private'],
            'apk' => ['exts' => ['apk'], 'max' => $c['max_apk_bytes'], 'visibility' => 'private'],
            'receipt' => ['exts' => ['jpg', 'png', 'webp', 'pdf'], 'max' => $c['max_document_bytes'] ?? 10 * 1024 * 1024, 'visibility' => 'private'],
            'contribution_receipt' => ['exts' => ['jpg', 'png', 'webp', 'pdf'], 'max' => $c['max_image_bytes'] ?? 10 * 1024 * 1024, 'visibility' => 'private'],
            'diagnostic' => ['exts' => ['jpg', 'png', 'webp'], 'max' => $c['max_image_bytes'] ?? 5 * 1024 * 1024, 'visibility' => 'private'],
        ];
    }

    public static function root(): string
    {
        return rtrim((string) config('mz.storage.root'), '/\\');
    }

    /** The folder of the public or private files. */
    private static function base(string $visibility): string
    {
        $c = config('mz.storage');
        $root = $visibility === 'public' ? ($c['public_root'] ?? null) : ($c['private_root'] ?? null);
        return rtrim((string) ($root ?? self::root() . DIRECTORY_SEPARATOR . $visibility), '/\\');
    }

    /** "public/…" or "private/…" → the absolute path inside that visibility's root (no escaping it). */
    private static function resolveInside(string $rel): string
    {
        $rel = ltrim(str_replace('\\', '/', $rel), '/');
        [$visibility, $rest] = array_pad(explode('/', $rel, 2), 2, '');
        if (! in_array($visibility, ['public', 'private'], true) || $rest === '') {
            throw ApiError::badRequest('INVALID_PATH', 'Invalid path');
        }
        $root = self::base($visibility);
        $norm = self::normalize($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $rest));
        if (! str_starts_with($norm, self::normalize($root) . DIRECTORY_SEPARATOR)) {
            throw ApiError::badRequest('INVALID_PATH', 'Invalid path');
        }
        return $norm;
    }

    private static function normalize(string $path): string
    {
        $path = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $path);
        $parts = [];
        $prefix = '';
        if (preg_match('#^([A-Za-z]:)#', $path, $m)) {
            $prefix = $m[1];
            $path = substr($path, 2);
        }
        $lead = str_starts_with($path, DIRECTORY_SEPARATOR) ? DIRECTORY_SEPARATOR : '';
        foreach (explode(DIRECTORY_SEPARATOR, $path) as $p) {
            if ($p === '' || $p === '.') continue;
            if ($p === '..') { array_pop($parts); continue; }
            $parts[] = $p;
        }
        return $prefix . $lead . implode(DIRECTORY_SEPARATOR, $parts);
    }

    /** Detect the real type of a file from its bytes: [ext, mime] or null. */
    public static function detect(string $absPath): ?array
    {
        $head = (string) @file_get_contents($absPath, false, null, 0, 64);
        if ($head === '') {
            return null;
        }
        // Common signatures first (fast and exact).
        if (str_starts_with($head, "\xFF\xD8\xFF")) return ['jpg', 'image/jpeg'];
        if (str_starts_with($head, "\x89PNG\r\n\x1A\n")) return ['png', 'image/png'];
        if (str_starts_with($head, 'GIF87a') || str_starts_with($head, 'GIF89a')) return ['gif', 'image/gif'];
        if (str_starts_with($head, 'RIFF') && substr($head, 8, 4) === 'WEBP') return ['webp', 'image/webp'];
        if (str_starts_with($head, 'RIFF') && substr($head, 8, 4) === 'WAVE') return ['wav', 'audio/wav'];
        if (str_starts_with($head, '%PDF')) return ['pdf', 'application/pdf'];
        if (str_starts_with($head, 'ID3') || (strlen($head) > 1 && ord($head[0]) === 0xFF && (ord($head[1]) & 0xE0) === 0xE0 && (ord($head[1]) & 0x06) !== 0)) {
            if ((ord($head[1]) & 0xF6) === 0xF0) return ['aac', 'audio/aac'];
            return ['mp3', 'audio/mpeg'];
        }
        if (str_starts_with($head, 'OggS')) {
            if (str_contains($head, 'OpusHead')) return ['opus', 'audio/opus'];
            if (str_contains($head, "\x01vorbis")) return ['ogg', 'audio/ogg'];
            if (str_contains($head, "\x80theora")) return ['ogv', 'video/ogg'];
            return ['ogx', 'application/ogg'];
        }
        if (str_starts_with($head, 'fLaC')) return ['flac', 'audio/flac'];
        if (str_starts_with($head, '#!AMR')) return ['amr', 'audio/amr'];
        if (str_starts_with($head, 'FORM') && in_array(substr($head, 8, 4), ['AIFF', 'AIFC'], true)) return ['aif', 'audio/aiff'];
        if (str_starts_with($head, "\x1A\x45\xDF\xA3")) {
            return str_contains($head, 'webm') ? ['webm', 'video/webm'] : ['mkv', 'video/x-matroska'];
        }
        if (substr($head, 4, 4) === 'ftyp') {
            $brand = substr($head, 8, 4);
            return match (true) {
                in_array($brand, ['M4A ', 'M4B ', 'M4P '], true) => [$brand === 'M4B ' ? 'm4b' : 'm4a', 'audio/mp4'],
                str_starts_with($brand, '3g2') => ['3g2', 'video/3gpp2'],
                str_starts_with($brand, '3gp') => ['3gp', 'video/3gpp'],
                $brand === 'qt  ' => ['mov', 'video/quicktime'],
                default => ['mp4', 'video/mp4'],
            };
        }
        if (str_starts_with($head, "PK\x03\x04")) {
            return self::detectZip($absPath);
        }
        if (str_starts_with($head, "\x30\x26\xB2\x75\x8E\x66\xCF\x11")) return ['asf', 'audio/x-ms-asf'];
        if (str_starts_with($head, 'MThd')) return ['mid', 'audio/midi'];
        if (str_starts_with($head, "\x0B\x77")) return ['ac3', 'audio/vnd.dolby.dd-raw'];
        // Anything else: libmagic.
        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($absPath) ?: '';
        return $mime && $mime !== 'application/octet-stream' && $mime !== 'text/plain' ? [explode('/', $mime)[1] ?? 'bin', $mime] : null;
    }

    private static function detectZip(string $absPath): ?array
    {
        if (! class_exists(ZipArchive::class)) {
            return ['zip', 'application/zip'];
        }
        $z = new ZipArchive();
        $names = [];
        if ($z->open($absPath) === true) {
            for ($i = 0; $i < min($z->numFiles, 2000); $i++) {
                $names[] = $z->getNameIndex($i);
            }
            $z->close();
        } else {
            // No readable central directory: walk the local file headers instead.
            $buf = (string) @file_get_contents($absPath, false, null, 0, 4 * 1024 * 1024);
            $pos = 0;
            while (count($names) < 2000 && ($pos = strpos($buf, "PK\x03\x04", $pos)) !== false && $pos + 30 <= strlen($buf)) {
                $nameLen = unpack('v', substr($buf, $pos + 26, 2))[1];
                $names[] = substr($buf, $pos + 30, $nameLen);
                $pos += 30 + $nameLen;
            }
        }
        $has = fn (string $prefix) => (bool) array_filter($names, fn ($n) => str_starts_with($n, $prefix));
        if (in_array('AndroidManifest.xml', $names, true) || in_array('classes.dex', $names, true)) return ['apk', 'application/vnd.android.package-archive'];
        if ($has('word/')) return ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
        if ($has('ppt/')) return ['pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'];
        if ($has('xl/')) return ['xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'];
        return ['zip', 'application/zip'];
    }

    /**
     * Validate and persist an upload. Returns [path (relative to the storage root), mime, size, sha256].
     */
    public static function save(string $kind, string $folder, UploadedFile|string|null $file): array
    {
        $policy = self::kinds()[$kind] ?? null;
        if (! $policy) {
            throw new \RuntimeException("unknown upload kind $kind");
        }
        if (! in_array($folder, self::FOLDERS, true)) {
            throw new \RuntimeException("unknown folder $folder");
        }
        $tmp = null;
        if (is_string($file)) {
            // raw bytes
            $tmp = tempnam(sys_get_temp_dir(), 'mzu');
            file_put_contents($tmp, $file);
            $src = $tmp;
        } else {
            $src = $file?->getRealPath() ?: null;
        }
        try {
            $size = $src ? (int) filesize($src) : 0;
            if (! $src || $size === 0) {
                throw ApiError::badRequest('FILE_REQUIRED', 'File is required');
            }
            if ($size > $policy['max']) {
                throw new ApiError(413, 'FILE_TOO_LARGE', 'File is too large');
            }
            $det = self::detect($src);
            $ok = $det && (in_array($det[0], $policy['exts'], true) || (! empty($policy['audio']) && str_starts_with($det[1], 'audio/')));
            if (! $ok) {
                throw ApiError::badRequest('INVALID_FILE_TYPE', 'File type not allowed');
            }
            $rel = $policy['visibility'] . '/' . $folder . '/' . Crypto::uuid() . '.' . $det[0];
            $abs = self::resolveInside($rel);
            if (! is_dir(dirname($abs))) {
                mkdir(dirname($abs), 0775, true);
            }
            if (! copy($src, $abs)) {
                throw new \RuntimeException('could not store upload');
            }
            return ['path' => $rel, 'mime' => $det[1], 'size' => $size, 'sha256' => hash_file('sha256', $abs)];
        } finally {
            if ($tmp) {
                @unlink($tmp);
            }
        }
    }

    public static function remove(?string $rel): void
    {
        if (! $rel) {
            return;
        }
        $abs = self::resolveInside($rel);
        if (is_file($abs)) {
            @unlink($abs);
        }
    }

    public static function privatePath(?string $rel): string
    {
        if (! $rel || ! str_starts_with($rel, 'private/')) {
            throw ApiError::notFound();
        }
        return self::resolveInside($rel);
    }

    public static function publicPath(string $rel): string
    {
        return self::resolveInside('public/' . ltrim($rel, '/'));
    }

    /** Absolute URL of a public file, or null. */
    public static function url(?string $rel): ?string
    {
        if (! $rel || ! str_starts_with($rel, 'public/')) {
            return null;
        }
        return config('mz.public_base_url') . (config('mz.storage.public_prefix') ?: '/files') . '/' . substr($rel, strlen('public/'));
    }

    /** `data:image/png;base64,...` from the signature pad → bytes. */
    public static function decodeDataUrl(?string $dataUrl): string
    {
        if (! preg_match('#^data:image/png;base64,([A-Za-z0-9+/=\s]+)$#', (string) $dataUrl, $m)) {
            throw ApiError::validation([['field' => 'signature', 'code' => 'INVALID_SIGNATURE', 'message' => 'INVALID_SIGNATURE']]);
        }
        return base64_decode(preg_replace('/\s+/', '', $m[1]));
    }
}
