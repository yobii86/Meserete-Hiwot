<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * ሰሌዳ መጽሔት (Seleda Magazine)
 *
 * Recurring PDF publication (monthly or bi-weekly) with optional linked quizzes.
 * Each issue has an issue date, publication date, PDF file, status, and associated quizzes.
 * Older issues and their quizzes are preserved.
 * Featured banner on Education Home presents the current published issue.
 */
final class EduMagazines
{
    public const STATUSES = ['draft', 'published', 'scheduled', 'archived'];

    public static function canManage(AuthContext $auth): bool
    {
        return $auth->isAdmin || ! empty($auth->permissions['education.manage']) || ! empty($auth->permissions['education.content']);
    }

    public static function assertCanManage(AuthContext $auth): void
    {
        if (! self::canManage($auth)) {
            throw ApiError::forbidden('FORBIDDEN', 'Permission denied');
        }
    }

    private static function now(): string
    {
        return Dates::sql(Dates::now());
    }

    private static function issueQuery()
    {
        return DB::table('edu_magazines')->whereNull('deleted_at');
    }

    public static function list(AuthContext $auth, array $f, array $page): array
    {
        $qb = self::issueQuery()->orderByDesc('issue_date')->orderByDesc('id');
        $canManage = self::canManage($auth);

        if (! $canManage) {
            // Ordinary members only see published issues whose publication date has passed
            $qb->where('status', 'published')
               ->whereNotNull('published_at')
               ->where('published_at', '<=', self::now());
        } elseif (! empty($f['status'])) {
            $qb->where('status', $f['status']);
        }

        if (! empty($f['q'])) {
            $q = trim((string) $f['q']);
            $qb->where(function ($w) use ($q) {
                $w->where('title', 'like', "%{$q}%")
                  ->orWhere('title_en', 'like', "%{$q}%")
                  ->orWhere('issue_number', 'like', "%{$q}%")
                  ->orWhere('period_info', 'like', "%{$q}%");
            });
        }

        $res = Page::paginate($qb, $page);
        $items = array_map(fn ($m) => self::serialize($m, $canManage), $res['items']);

        return ['items' => $items, 'meta' => $res['meta']];
    }

    /** The latest published issue for the Education Home featured banner. */
    public static function latest(AuthContext $auth): ?array
    {
        $now = self::now();
        $mag = self::issueQuery()
            ->where('status', 'published')
            ->whereNotNull('published_at')
            ->where('published_at', '<=', $now)
            ->orderByDesc('published_at')
            ->orderByDesc('issue_date')
            ->first();

        if (! $mag) return null;
        return self::detail($auth, (int) $mag->id);
    }

    public static function detail(AuthContext $auth, int $id): array
    {
        $canManage = self::canManage($auth);
        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        if (! $canManage) {
            if ($mag->status !== 'published' || ! $mag->published_at || Dates::sql($mag->published_at) > self::now()) {
                throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');
            }
            if ($auth->accountType === 'user') {
                Activity::track($auth->id, Activity::MAGAZINE_VIEW, 'edu_magazine', $id, ['title' => $mag->title, 'issue_number' => $mag->issue_number]);
            }
        }

        $quizzes = self::quizzes($auth, $id);
        return self::serialize($mag, $canManage) + [
            'quizzes' => $quizzes,
            'quiz_count' => count($quizzes),
        ];
    }

    public static function create(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        $title = trim((string) ($in['title'] ?? ''));
        if ($title === '') throw ApiError::field('title', 'REQUIRED');

        $issueDate = trim((string) ($in['issue_date'] ?? ''));
        if ($issueDate === '') throw ApiError::field('issue_date', 'REQUIRED');

        $status = $in['status'] ?? 'draft';
        if (! in_array($status, self::STATUSES, true)) throw ApiError::field('status', 'INVALID_STATUS');

        $pdfPath = trim((string) ($in['pdf_path'] ?? ''));
        $pdfMime = trim((string) ($in['pdf_mime'] ?? 'application/pdf'));
        $pdfSize = (int) ($in['pdf_size'] ?? 0);

        if ($pdfPath === '' && $status === 'published') throw ApiError::field('pdf_path', 'REQUIRED');

        $now = self::now();
        $publishedAt = null;
        if ($status === 'published') {
            $publishedAt = ! empty($in['published_at']) ? Dates::sql($in['published_at']) : $now;
        } elseif ($status === 'scheduled') {
            if (empty($in['published_at'])) throw ApiError::field('published_at', 'REQUIRED');
            $publishedAt = Dates::sql($in['published_at']);
        }

        $id = (int) DB::table('edu_magazines')->insertGetId([
            'title' => $title,
            'title_en' => ! empty($in['title_en']) ? trim((string) $in['title_en']) : null,
            'issue_number' => ! empty($in['issue_number']) ? trim((string) $in['issue_number']) : null,
            'period_info' => ! empty($in['period_info']) ? trim((string) $in['period_info']) : null,
            'description' => ! empty($in['description']) ? trim((string) $in['description']) : null,
            'cover_image' => ! empty($in['cover_image']) ? trim((string) $in['cover_image']) : null,
            'pdf_path' => $pdfPath,
            'pdf_mime' => $pdfMime,
            'pdf_size' => $pdfSize,
            'status' => $status,
            'issue_date' => Dates::toDateOnly($issueDate),
            'published_at' => $publishedAt,
            'created_by' => $auth->id,
            'notification_sent' => 0,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $mag = DB::table('edu_magazines')->where('id', $id)->first();
        if ($status === 'published' && $publishedAt <= $now) {
            self::sendPublishNotification($mag);
        }

        Audit::log($actx, 'edu_magazine.create', 'edu_magazine', $id, ['title' => $title, 'status' => $status]);
        return self::detail($auth, $id);
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        $up = ['updated_by' => $auth->id, 'updated_at' => self::now()];

        if (array_key_exists('title', $in)) {
            $t = trim((string) $in['title']);
            if ($t === '') throw ApiError::field('title', 'REQUIRED');
            $up['title'] = $t;
        }
        if (array_key_exists('title_en', $in)) $up['title_en'] = $in['title_en'] ? trim((string) $in['title_en']) : null;
        if (array_key_exists('issue_number', $in)) $up['issue_number'] = $in['issue_number'] ? trim((string) $in['issue_number']) : null;
        if (array_key_exists('period_info', $in)) $up['period_info'] = $in['period_info'] ? trim((string) $in['period_info']) : null;
        if (array_key_exists('description', $in)) $up['description'] = $in['description'] ? trim((string) $in['description']) : null;
        if (array_key_exists('cover_image', $in)) $up['cover_image'] = $in['cover_image'] ? trim((string) $in['cover_image']) : null;
        if (array_key_exists('pdf_path', $in)) $up['pdf_path'] = trim((string) $in['pdf_path']);
        if (array_key_exists('pdf_mime', $in)) $up['pdf_mime'] = trim((string) $in['pdf_mime']);
        if (array_key_exists('pdf_size', $in)) $up['pdf_size'] = (int) $in['pdf_size'];
        if (array_key_exists('issue_date', $in)) $up['issue_date'] = Dates::toDateOnly($in['issue_date']);

        if (array_key_exists('status', $in)) {
            $s = $in['status'];
            if (! in_array($s, self::STATUSES, true)) throw ApiError::field('status', 'INVALID_STATUS');
            $up['status'] = $s;
            if ($s === 'published' && empty($mag->published_at) && empty($in['published_at'])) {
                $up['published_at'] = self::now();
            }
        }

        if (array_key_exists('published_at', $in)) {
            $up['published_at'] = $in['published_at'] ? Dates::sql($in['published_at']) : null;
        }

        DB::table('edu_magazines')->where('id', $id)->update($up);
        $fresh = DB::table('edu_magazines')->where('id', $id)->first();

        if ($fresh->status === 'published' && ! $fresh->notification_sent && $fresh->published_at && Dates::sql($fresh->published_at) <= self::now()) {
            self::sendPublishNotification($fresh);
        }

        Audit::log($actx, 'edu_magazine.update', 'edu_magazine', $id, ['changes' => array_keys($up)]);
        return self::detail($auth, $id);
    }

    public static function delete(array $actx, int $id): void
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        DB::table('edu_magazines')->where('id', $id)->update(['deleted_at' => self::now(), 'updated_by' => $auth->id]);
        Audit::log($actx, 'edu_magazine.delete', 'edu_magazine', $id, ['title' => $mag->title]);
    }

    public static function uploadPdf(array $actx, int $id, ?UploadedFile $file): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        if (! $file) {
            throw ApiError::badRequest('FILE_REQUIRED', 'PDF file is required');
        }

        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        $saved = Storage::save('document', Storage::FOLDERS['MAGAZINES'], $file);
        if ($saved['mime'] !== 'application/pdf') {
            Storage::remove($saved['path']);
            throw ApiError::badRequest('INVALID_FILE_TYPE', 'Only PDF files are supported for magazine issues');
        }

        if (! empty($mag->pdf_path) && $mag->pdf_path !== $saved['path'] && str_starts_with($mag->pdf_path, 'public/magazines/')) {
            Storage::remove($mag->pdf_path);
        }

        DB::table('edu_magazines')->where('id', $id)->update([
            'pdf_path' => $saved['path'],
            'pdf_mime' => $saved['mime'],
            'pdf_size' => $saved['size'],
            'updated_by' => $auth->id,
            'updated_at' => self::now(),
        ]);

        try {
            MediaProcessing::renderPdfPagesToWebp(
                Storage::resolveInside($saved['path']),
                'images/magazines/pages_' . $id,
                'public',
                150,
                85,
                'magazine',
                $id
            );
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('EduMagazine PDF rendering error: ' . $e->getMessage());
        }

        Audit::log($actx, 'edu_magazine.upload_pdf', 'edu_magazine', $id, ['path' => $saved['path'], 'size' => $saved['size']]);
        return self::detail($auth, $id);
    }

    public static function uploadCover(array $actx, int $id, ?UploadedFile $file): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        if (! $file) {
            throw ApiError::badRequest('FILE_REQUIRED', 'Cover image file is required');
        }

        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        $saved = Storage::save('image', Storage::FOLDERS['MAGAZINE_COVERS'], $file);

        if (! empty($mag->cover_image) && $mag->cover_image !== $saved['path'] && str_starts_with($mag->cover_image, 'public/images/magazines/')) {
            Storage::remove($mag->cover_image);
        }

        DB::table('edu_magazines')->where('id', $id)->update([
            'cover_image' => $saved['path'],
            'updated_by' => $auth->id,
            'updated_at' => self::now(),
        ]);

        Audit::log($actx, 'edu_magazine.upload_cover', 'edu_magazine', $id, ['path' => $saved['path']]);
        return self::detail($auth, $id);
    }

    public static function removeCover(array $actx, int $id): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        $mag = self::issueQuery()->where('id', $id)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        if (! empty($mag->cover_image) && str_starts_with($mag->cover_image, 'public/images/magazines/')) {
            Storage::remove($mag->cover_image);
        }

        DB::table('edu_magazines')->where('id', $id)->update([
            'cover_image' => null,
            'updated_by' => $auth->id,
            'updated_at' => self::now(),
        ]);

        Audit::log($actx, 'edu_magazine.remove_cover', 'edu_magazine', $id);
        return self::detail($auth, $id);
    }

    /** Quizzes associated with this magazine issue. */
    public static function quizzes(AuthContext $auth, int $id): array
    {
        $canManage = self::canManage($auth);
        $now = self::now();

        $qb = DB::table('edu_quizzes as q')
            ->where('q.magazine_id', $id);

        if (! $canManage) {
            $qb->where('q.status', '<>', 'draft');
        }

        $rows = $qb->orderBy('q.id')->get();
        if ($rows->isEmpty()) return [];

        $quizIds = $rows->pluck('id')->all();
        $attempts = DB::table('edu_quiz_attempts')
            ->where('user_id', $auth->id)
            ->whereIn('quiz_id', $quizIds)
            ->orderBy('attempt_no')
            ->get()
            ->groupBy('quiz_id');

        return $rows->map(function ($q) use ($attempts, $auth, $canManage) {
            $mine = $attempts->get($q->id, collect())->all();
            $inProgress = current(array_filter($mine, fn ($a) => $a->status === 'in_progress')) ?: null;
            $done = array_values(array_filter($mine, fn ($a) => $a->status !== 'in_progress'));
            $chosen = ! empty($done) ? end($done) : null;

            return [
                'id' => (int) $q->id,
                'magazine_id' => (int) $q->magazine_id,
                'course_id' => $q->course_id ? (int) $q->course_id : null,
                'title' => $q->title,
                'title_en' => $q->title_en,
                'instructions' => $q->instructions,
                'instructions_en' => $q->instructions_en,
                'status' => $q->status,
                'time_limit_minutes' => $q->time_limit_minutes,
                'max_attempts' => (int) $q->max_attempts,
                'attempts_used' => count($mine),
                'attempts_left' => max(0, (int) $q->max_attempts - count($mine)),
                'in_progress_attempt_id' => $inProgress ? (int) $inProgress->id : null,
                'last_attempt_id' => ! empty($mine) ? (int) end($mine)->id : null,
                'needs_grading' => $chosen ? (bool) $chosen->needs_grading : false,
                'my_score' => $chosen && ! $chosen->needs_grading ? (float) ($chosen->auto_score ?? 0) + (float) ($chosen->manual_score ?? 0) : null,
                'my_max_score' => $chosen ? (float) $chosen->max_score : null,
            ];
        })->all();
    }

    /** Create a quiz linked to a magazine issue. */
    public static function createQuiz(array $actx, int $magazineId, array $in): array
    {
        $auth = $actx['auth'];
        self::assertCanManage($auth);

        $mag = self::issueQuery()->where('id', $magazineId)->first();
        if (! $mag) throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine issue not found');

        $title = trim((string) ($in['title'] ?? ''));
        if ($title === '') throw ApiError::field('title', 'REQUIRED');

        $now = self::now();
        $quizId = (int) DB::table('edu_quizzes')->insertGetId([
            'magazine_id' => $magazineId,
            'course_id' => ! empty($in['course_id']) ? (int) $in['course_id'] : null,
            'title' => $title,
            'title_en' => ! empty($in['title_en']) ? trim((string) $in['title_en']) : null,
            'instructions' => ! empty($in['instructions']) ? trim((string) $in['instructions']) : null,
            'instructions_en' => ! empty($in['instructions_en']) ? trim((string) $in['instructions_en']) : null,
            'opens_at' => ! empty($in['opens_at']) ? Dates::sql($in['opens_at']) : $now,
            'closes_at' => ! empty($in['closes_at']) ? Dates::sql($in['closes_at']) : null,
            'results_release_at' => ! empty($in['results_release_at']) ? Dates::sql($in['results_release_at']) : null,
            'time_limit_minutes' => ! empty($in['time_limit_minutes']) ? (int) $in['time_limit_minutes'] : null,
            'max_attempts' => max(1, (int) ($in['max_attempts'] ?? 1)),
            'scoring' => in_array($in['scoring'] ?? '', ['best', 'last', 'average'], true) ? $in['scoring'] : 'best',
            'shuffle' => ! empty($in['shuffle']),
            'review_policy' => in_array($in['review_policy'] ?? '', ['never', 'after_submit', 'after_close', 'practice'], true) ? $in['review_policy'] : 'after_submit',
            'status' => in_array($in['status'] ?? '', ['draft', 'published', 'closed'], true) ? $in['status'] : 'published',
            'kind' => 'quiz',
            'created_by' => $auth->id,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        if (! empty($in['questions']) && is_array($in['questions'])) {
            EduQuizzes::setQuestions($actx, $quizId, $in['questions']);
        }

        Audit::log($actx, 'edu_quiz.create', 'edu_quiz', $quizId, ['magazine_id' => $magazineId, 'title' => $title]);
        return EduQuizzes::quizDetail($auth, $quizId);
    }

    private static function sendPublishNotification(object $mag): void
    {
        try {
            DB::table('edu_magazines')->where('id', $mag->id)->update(['notification_sent' => 1]);
            $title = "ሰሌዳ መጽሔት ታተመ";
            $body = "{$mag->title} አሁን ዝግጁ ነው። ያንብቡ እና ጥያቄዎችን ይመልሱ!";
            $url = "/edu/magazines/{$mag->id}";

            // Send notification to all active users interested in Education
            Notifications::sendToAll([
                'title' => $title,
                'body' => $body,
                'url' => $url,
                'type' => 'magazine_published',
                'entity_id' => (int) $mag->id,
            ]);
        } catch (\Throwable $e) {
            // Notification failures must not abort the database transaction
        }
    }

    /** Stream or download Magazine PDF supporting HTTP 206 byte ranges. */
    public static function streamPdf(int $id, bool $download = false)
    {
        $mag = DB::table('edu_magazines')->where('id', $id)->whereNull('deleted_at')->first();
        if (! $mag || ! $mag->pdf_path) {
            throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine PDF not found');
        }

        try {
            $abs = Storage::resolveInside($mag->pdf_path);
        } catch (\Throwable) {
            throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine PDF file not found');
        }

        if (! file_exists($abs)) {
            throw ApiError::notFound('MAGAZINE_NOT_FOUND', 'Magazine PDF file not found on disk');
        }

        $headers = [
            'Content-Type' => 'application/pdf',
            'Accept-Ranges' => 'bytes',
            'Cache-Control' => 'public, max-age=604800',
            'X-Content-Type-Options' => 'nosniff',
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Headers' => 'Range, Authorization, Content-Type',
            'Access-Control-Expose-Headers' => 'Content-Range, Content-Length, Accept-Ranges',
        ];

        if ($download) {
            $filename = ($mag->title ? preg_replace('/[^a-zA-Z0-9_\-\.]/', '_', $mag->title) : 'magazine') . '.pdf';
            return response()->download($abs, $filename, $headers);
        }

        return response()->file($abs, $headers);
    }

    private static function serialize(object $m, bool $canManage): array
    {
        $now = self::now();
        $isPublished = $m->status === 'published' && $m->published_at && Dates::sql($m->published_at) <= $now;

        $streamUrl = $m->pdf_path ? url("/api/v1/edu/magazines/{$m->id}/pdf") : null;
        $pdfUrl = Storage::url($m->pdf_path);
        if (! $pdfUrl && $m->pdf_path) {
            $base = config('mz.public_base_url');
            $pdfUrl = "$base/files/" . ltrim(str_replace('public/', '', $m->pdf_path), '/');
        }

        $coverUrl = null;
        if (! empty($m->cover_image)) {
            $coverUrl = Storage::url($m->cover_image);
            if (! $coverUrl) {
                $base = config('mz.public_base_url');
                $coverUrl = "$base/files/" . ltrim(str_replace('public/', '', $m->cover_image), '/');
            }
        }

        $out = [
            'id' => (int) $m->id,
            'title' => $m->title,
            'title_en' => $m->title_en,
            'issue_number' => $m->issue_number,
            'period_info' => $m->period_info,
            'description' => $m->description,
            'cover_url' => $coverUrl,
            'pdf_url' => $streamUrl ?: $pdfUrl,
            'stream_url' => $streamUrl,
            'direct_pdf_url' => $pdfUrl,
            'pdf_mime' => $m->pdf_mime,
            'pdf_size' => (int) $m->pdf_size,
            'status' => $m->status,
            'is_published' => $isPublished,
            'issue_date' => $m->issue_date,
            'published_at' => $m->published_at,
            'created_at' => $m->created_at,
            'updated_at' => $m->updated_at,
        ];

        if ($canManage) {
            $out['notification_sent'] = (bool) $m->notification_sent;
            $out['created_by'] = (int) $m->created_by;
        }

        return $out;
    }
}
