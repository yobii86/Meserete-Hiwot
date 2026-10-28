<?php

namespace App\Mz\Projects;

use App\Mz\Auth\Audit;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\MemberIds;
use App\Mz\Services\Storage;
use App\Mz\Support\Dates;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/** Shared helpers of the Project Management module. */
final class Pm
{
    public const PROJECT_STATUSES = ['planning', 'not_started', 'in_progress', 'on_hold', 'completed', 'cancelled'];
    public const TASK_STATUSES = ['not_started', 'pending', 'in_progress', 'awaiting_review', 'blocked', 'completed', 'cancelled'];
    public const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
    public const PENDING_REASONS = ['approval', 'materials', 'finance', 'another_task', 'another_department', 'paused', 'other'];
    public const ISSUE_STATUSES = ['open', 'under_review', 'assigned', 'in_progress', 'resolved', 'closed'];
    public const SOURCES = ['app', 'web', 'chat_bot', 'offline_sync', 'system'];
    /** Tasks that still count as open work. */
    public const OPEN_TASK = ['not_started', 'pending', 'in_progress', 'awaiting_review', 'blocked'];

    /**
     * Every Project Management change is an audit_logs row with entity ('project', project id).
     * That one record is the activity history, the audit trail and the change feed the app polls
     * for live updates — no separate event table. metadata: task/issue ids, before/after, reason, source.
     */
    public static function log(array $actx, string $action, int $projectId, array $meta = []): void
    {
        $meta['source'] ??= $actx['source'] ?? 'app';
        Audit::log($actx, $action, 'project', $projectId, $meta, inTrx: DB::transactionLevel() > 0);
    }

    /** Notify users (never the actor), type 'project'. */
    public static function notify(array $userIds, int $actorId, string $titleKey, string $bodyKey, array $params, string $entityType, int $entityId, string $dedupe, bool $email = false): int
    {
        $ids = array_values(array_filter(array_unique(array_map('intval', $userIds)), fn ($id) => $id !== $actorId && $id > 0));
        if (! $ids) return 0;
        $n = Notifications::createForUsers($ids, [
            'type' => 'project',
            'title' => T::t($titleKey, $params),
            'body' => T::t($bodyKey, $params),
            'entityType' => $entityType,
            'entityId' => $entityId,
            'email' => $email,
            'dedupeKey' => fn ($uid) => mb_substr("pm:$dedupe:$uid", 0, 150),
        ]);
        return $n;
    }

    /** A short unique token for dedupe keys of one-off events. */
    public static function stamp(): string
    {
        return substr(str_replace('.', '', (string) microtime(true)), -10) . random_int(10, 99);
    }

    public static function users(array $ids): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
        if (! $ids) return [];
        $out = [];
        foreach (DB::table('users')->whereIn('id', $ids)->get(['id', 'full_name', 'member_no', 'member_group', 'profile_image']) as $u) {
            $out[(int) $u->id] = self::user($u);
        }
        return $out;
    }

    public static function user(?object $u): ?array
    {
        if (! $u) return null;
        return ['id' => (int) $u->id, 'full_name' => $u->full_name, 'member_id' => MemberIds::format($u->member_no ?? null, $u->member_group ?? null), 'avatar_url' => Storage::url($u->profile_image ?? null)];
    }

    public static function names(array $userIds): string
    {
        $names = DB::table('users')->whereIn('id', $userIds ?: [0])->orderBy('full_name')->pluck('full_name')->all();
        return $names ? implode(', ', $names) : '-';
    }

    public static function localTime(mixed $dt): string
    {
        $d = Dates::of($dt);
        if (! $d) return T::t('bot.no_deadline');
        return \DateTimeImmutable::createFromInterface($d)->setTimezone(Dates::tz())->format('Y-m-d H:i');
    }

    public static function money(mixed $v): float
    {
        return round((float) $v, 2);
    }

    public static function isOverdue(object $t, ?\DateTimeInterface $now = null): bool
    {
        return $t->deadline && in_array($t->status, self::OPEN_TASK, true) && Dates::of($t->deadline) < ($now ?? Dates::now());
    }
}
