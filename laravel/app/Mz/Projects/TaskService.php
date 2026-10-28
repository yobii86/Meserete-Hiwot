<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Jobs\ScheduledNotifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Tasks: several responsible people, reassignment, statuses with reasons, deadlines under the
 * project deadline, progress. Screens, the chat Task Bot and offline sync all call changeStatus(),
 * so the same rules and the same record apply everywhere.
 */
final class TaskService
{
    private const EDITABLE = ['title', 'description', 'start_date', 'deadline', 'priority', 'notes', 'weight', 'issue_id', 'program_id'];

    public static function serialize(object $t, AuthContext $auth, ?array $access = null): array
    {
        $access ??= Access::task($auth, $t);
        $assignees = Access::assigneeIds((int) $t->id);
        $users = Pm::users(array_merge($assignees, [$t->created_by, $t->completed_by]));
        $p = DB::table('projects')->where('id', $t->project_id)->first(['id', 'title', 'deadline', 'department_id']);
        $program = $t->program_id ? DB::table('programs')->where('id', $t->program_id)->first(['id', 'title', 'starts_at']) : null;
        $issue = $t->issue_id ? DB::table('project_issues')->where('id', $t->issue_id)->first(['id', 'title', 'status']) : null;
        $now = Dates::now();
        return [
            'id' => (int) $t->id,
            'project' => ['id' => (int) $p->id, 'title' => $p->title, 'deadline' => $p->deadline, 'department_id' => (int) $p->department_id],
            'department_id' => (int) $t->department_id,
            'title' => $t->title,
            'description' => $t->description,
            'assignees' => array_values(array_filter(array_map(fn ($id) => $users[$id] ?? null, $assignees))),
            'start_date' => Dates::toDateOnly($t->start_date),
            'deadline' => $t->deadline,
            'overdue' => Pm::isOverdue($t, $now),
            'seconds_remaining' => $t->deadline ? Dates::of($t->deadline)->getTimestamp() - $now->getTimestamp() : null,
            'priority' => $t->priority,
            'status' => $t->status,
            'status_reason' => $t->status_reason,
            'pending_reason' => $t->pending_reason,
            'progress' => (int) $t->progress,
            'weight' => (int) $t->weight,
            'notes' => $t->notes,
            'issue' => $issue,
            'program' => $program,
            'suggestion_id' => $t->suggestion_id ? (int) $t->suggestion_id : null,
            'completed_at' => $t->completed_at,
            'completed_by' => $t->completed_by ? ($users[(int) $t->completed_by] ?? null) : null,
            'completion_note' => $t->completion_note,
            'deliverable_achieved' => isset($t->deliverable_achieved) ? (bool) $t->deliverable_achieved : null,
            'completion_evidence' => $t->completion_evidence ?? null,
            'review_feedback' => $t->review_feedback ?? null,
            'reviewed_by' => isset($t->reviewed_by) && $t->reviewed_by ? ($users[(int) $t->reviewed_by] ?? null) : null,
            'reviewed_at' => $t->reviewed_at ?? null,
            'version' => (int) $t->version,
            'created_by' => $t->created_by ? ($users[(int) $t->created_by] ?? null) : null,
            'created_at' => $t->created_at,
            'updated_at' => $t->updated_at,
            'files' => DB::table('project_files')->where('task_id', $t->id)->count(),
            'can' => ['update_status' => $access['update_status'], 'edit' => $access['edit']],
        ];
    }

    public static function get(AuthContext $auth, int $id): array
    {
        [$t, $a] = Access::loadTask($auth, $id);
        return self::serialize($t, $auth, $a);
    }

    private static function applyFilters(Builder $qb, array $f, AuthContext $auth): Builder
    {
        $now = Dates::sql(Dates::now());
        if (! empty($f['status'])) $qb->whereIn('t.status', (array) $f['status']);
        if (! empty($f['open'])) $qb->whereIn('t.status', Pm::OPEN_TASK);
        if (! empty($f['priority'])) $qb->whereIn('t.priority', (array) $f['priority']);
        if (! empty($f['overdue'])) $qb->whereIn('t.status', Pm::OPEN_TASK)->whereNotNull('t.deadline')->where('t.deadline', '<', $now);
        if (! empty($f['assignee_ids'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('project_task_assignees as fa')->whereColumn('fa.task_id', 't.id')->whereIn('fa.user_id', (array) $f['assignee_ids']));
        }
        if (! empty($f['mine'])) $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('project_task_assignees as ma')->whereColumn('ma.task_id', 't.id')->where('ma.user_id', $auth->id));
        if (! empty($f['created_by'])) $qb->whereIn('t.created_by', (array) $f['created_by']);
        if (! empty($f['deadline_from'])) $qb->where('t.deadline', '>=', Dates::sql(Dates::fromLocal($f['deadline_from'] . ' 00:00:00')));
        if (! empty($f['deadline_to'])) $qb->where('t.deadline', '<=', Dates::sql(Dates::fromLocal($f['deadline_to'] . ' 23:59:59')));
        if (! empty($f['q'])) $qb->where('t.title', 'like', '%' . $f['q'] . '%');
        if (! empty($f['program_id'])) $qb->where('t.program_id', $f['program_id']);
        return $qb;
    }

    public static function listForProject(AuthContext $auth, int $projectId, array $f, array $page): array
    {
        Access::loadProject($auth, $projectId);
        $qb = DB::table('project_tasks as t')->where('t.project_id', $projectId)->whereNull('t.deleted_at')->select('t.*');
        self::applyFilters($qb, $f, $auth)->orderByRaw("FIELD(t.status, 'blocked', 'pending', 'in_progress', 'not_started', 'completed', 'cancelled')")
            ->orderByRaw('t.deadline IS NULL')->orderBy('t.deadline')->orderBy('t.id');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($t) => self::serialize($t, $auth), $res['items']);
        return $res;
    }

    /** "My Tasks": every task the person is responsible for, across departments. */
    public static function mine(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_tasks as t')->join('projects as p', 'p.id', '=', 't.project_id')->whereNull('t.deleted_at')->whereNull('p.deleted_at')
            ->whereExists(fn ($s) => $s->select(DB::raw(1))->from('project_task_assignees as a')->whereColumn('a.task_id', 't.id')->where('a.user_id', $auth->id))
            ->select('t.*');
        if (! empty($f['department_id'])) $qb->where('t.department_id', $f['department_id']);
        self::applyFilters($qb, $f, $auth)->orderByRaw("FIELD(t.status, 'blocked', 'pending', 'in_progress', 'not_started', 'completed', 'cancelled')")
            ->orderByRaw('t.deadline IS NULL')->orderBy('t.deadline');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($t) => self::serialize($t, $auth), $res['items']);
        return $res;
    }

    /** A task deadline beyond the project deadline needs the project to allow it, or a department manager's override. */
    private static function assertDeadline(object $p, array $a, ?string $deadline, bool $override): void
    {
        if (! $deadline || ! $p->deadline || Dates::of($deadline) <= Dates::of($p->deadline)) return;
        if ($p->allow_late_tasks) return;
        if ($override && $a['manage']) return;
        throw ApiError::field('deadline', 'TASK_AFTER_PROJECT_DEADLINE');
    }

    private static function assertRefs(array $in, int $projectId): void
    {
        if (! empty($in['program_id']) && ! DB::table('programs')->where('id', $in['program_id'])->exists()) throw ApiError::field('program_id', 'PROGRAM_NOT_FOUND');
        if (! empty($in['issue_id']) && ! DB::table('project_issues')->where(['id' => $in['issue_id'], 'project_id' => $projectId])->exists()) throw ApiError::field('issue_id', 'ISSUE_NOT_FOUND');
    }

    public static function create(array $actx, int $projectId, array $in, ?int $suggestionId = null): array
    {
        $auth = $actx['auth'];
        [$p, $a] = Access::loadProject($auth, $projectId, 'project_manage');
        if (in_array($p->status, ['completed', 'cancelled'], true)) throw ApiError::conflict('PROJECT_CLOSED', 'This project is closed');
        $deadline = isset($in['deadline']) ? Dates::sql(Dates::of($in['deadline'])) : null;
        self::assertDeadline($p, $a, $deadline, (bool) ($in['allow_after_project_deadline'] ?? false));
        self::assertRefs($in, $projectId);
        $assignees = array_values(array_unique(array_map('intval', $in['assignee_ids'] ?? [])));
        Access::assertAssignable((int) $p->department_id, $assignees);
        $id = DB::transaction(function () use ($actx, $auth, $p, $in, $deadline, $assignees, $suggestionId) {
            $id = DB::table('project_tasks')->insertGetId([
                'project_id' => $p->id,
                'department_id' => $p->department_id,
                'title' => $in['title'],
                'description' => $in['description'] ?? null,
                'start_date' => $in['start_date'] ?? null,
                'deadline' => $deadline,
                'priority' => $in['priority'] ?? 'medium',
                'status' => 'not_started',
                'weight' => $in['weight'] ?? 1,
                'notes' => $in['notes'] ?? null,
                'issue_id' => $in['issue_id'] ?? null,
                'program_id' => $in['program_id'] ?? null,
                'suggestion_id' => $suggestionId,
                'created_by' => $auth->id,
            ]);
            foreach ($assignees as $uid) DB::table('project_task_assignees')->insert(['task_id' => $id, 'user_id' => $uid, 'assigned_by' => $auth->id]);
            Pm::log($actx, 'project.task.create', (int) $p->id, ['task_id' => $id, 'after' => ['title' => $in['title'], 'deadline' => $deadline, 'assignees' => $assignees, 'program_id' => $in['program_id'] ?? null]]);
            if ($assignees) Pm::log($actx, 'project.task.assign', (int) $p->id, ['task_id' => $id, 'before' => [], 'after' => $assignees]);
            ProjectService::recalculate((int) $p->id);
            return $id;
        });
        $due = $deadline ? T::t('project.due.suffix', ['due' => Pm::localTime($deadline)]) : '';
        Pm::notify($assignees, $auth->id, 'project.assigned.title', 'project.assigned.body', ['task' => $in['title'], 'project' => $p->title, 'due' => $due], 'project_task', $id, "assign:$id:" . Pm::stamp(), true);
        if ($assignees) Bot::event(DB::table('project_tasks')->where('id', $id)->first(), 'assigned', $auth->id);
        ProjectReminders::planTask($id);
        return self::get($auth, $id);
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        [$t, $a] = Access::loadTask($auth, $id, 'edit');
        $p = DB::table('projects')->where('id', $t->project_id)->first();
        $patch = array_intersect_key($in, array_flip(self::EDITABLE));
        if (array_key_exists('deadline', $patch)) {
            $patch['deadline'] = $patch['deadline'] ? Dates::sql(Dates::of($patch['deadline'])) : null;
            self::assertDeadline($p, $a, $patch['deadline'], (bool) ($in['allow_after_project_deadline'] ?? false));
        }
        self::assertRefs($patch, (int) $t->project_id);
        if (! $patch) return self::serialize($t, $auth, $a);
        $before = [];
        foreach (array_keys($patch) as $k) $before[$k] = $t->{$k};
        $deadlineChanged = array_key_exists('deadline', $patch) && Dates::sql($t->deadline) !== $patch['deadline'];
        DB::transaction(function () use ($actx, $id, $t, $patch, $before, $in, $deadlineChanged) {
            DB::table('project_tasks')->where('id', $id)->update($patch + ['version' => DB::raw('version + 1')]);
            Pm::log($actx, $deadlineChanged ? 'project.task.deadline' : 'project.task.update', (int) $t->project_id, ['task_id' => $id, 'before' => $before, 'after' => $patch, 'reason' => $in['reason'] ?? null]);
            if (array_key_exists('weight', $patch)) ProjectService::recalculate((int) $t->project_id);
        });
        if ($deadlineChanged) {
            Pm::notify(array_merge(Access::assigneeIds($id), Access::managersOf((int) $t->department_id)), $auth->id, 'project.deadline.title', 'project.deadline.body',
                ['task' => $patch['title'] ?? $t->title, 'due' => Pm::localTime($patch['deadline'])], 'project_task', $id, "deadline:$id:" . Pm::stamp(), true);
            ProjectReminders::planTask($id);
        }
        return self::get($auth, $id);
    }

    /** Assign / add / remove / reassign responsible people (the whole list is sent). */
    public static function setAssignees(array $actx, int $id, array $userIds, ?string $reason): array
    {
        $auth = $actx['auth'];
        [$t] = Access::loadTask($auth, $id, 'edit');
        $p = DB::table('projects')->where('id', $t->project_id)->first(['id', 'title']);
        $next = array_values(array_unique(array_map('intval', $userIds)));
        Access::assertAssignable((int) $t->department_id, $next);
        $before = Access::assigneeIds($id);
        $added = array_values(array_diff($next, $before));
        $removed = array_values(array_diff($before, $next));
        if (! $added && ! $removed) return self::get($auth, $id);
        DB::transaction(function () use ($actx, $auth, $id, $t, $added, $removed, $before, $next, $reason) {
            if ($removed) DB::table('project_task_assignees')->where('task_id', $id)->whereIn('user_id', $removed)->delete();
            foreach ($added as $uid) DB::table('project_task_assignees')->insert(['task_id' => $id, 'user_id' => $uid, 'assigned_by' => $auth->id]);
            DB::table('project_tasks')->where('id', $id)->update(['version' => DB::raw('version + 1')]);
            Pm::log($actx, $before ? 'project.task.reassign' : 'project.task.assign', (int) $t->project_id, ['task_id' => $id, 'before' => $before, 'after' => $next, 'added' => $added, 'removed' => $removed, 'reason' => $reason]);
        });
        $stamp = Pm::stamp();
        $due = $t->deadline ? T::t('project.due.suffix', ['due' => Pm::localTime($t->deadline)]) : '';
        Pm::notify($added, $auth->id, 'project.assigned.title', 'project.assigned.body', ['task' => $t->title, 'project' => $p->title, 'due' => $due], 'project_task', $id, "assign:$id:$stamp", true);
        Pm::notify($removed, $auth->id, 'project.unassigned.title', 'project.unassigned.body', ['task' => $t->title, 'project' => $p->title], 'project_task', $id, "unassign:$id:$stamp");
        if ($before) {
            Pm::notify(Access::managersOf((int) $t->department_id), $auth->id, 'project.reassigned.title', 'project.reassigned.body', ['task' => $t->title, 'names' => Pm::names($next)], 'project_task', $id, "reassign:$id:$stamp");
        }
        $fresh = DB::table('project_tasks')->where('id', $id)->first();
        if ($added) Bot::event($fresh, $before ? 'reassigned' : 'assigned', $auth->id, ['added' => Pm::names($added), 'removed' => $removed ? Pm::names($removed) : '-']);
        ProjectReminders::planTask($id);
        return self::get($auth, $id);
    }

    /**
     * Status / progress / notes by a responsible person or a manager.
     * in: status?, reason?, pending_reason?, progress?, note?, base_version?
     * Pending needs a reason (what it waits for); Blocked needs what is blocking it.
     * base_version (offline sync): when the task changed on the server since, nothing is applied
     * and the server copy is returned as a conflict.
     * @return array{task: array, conflict?: bool}
     */
    public static function changeStatus(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        [$t, $a] = Access::loadTask($auth, $id, 'update_status');
        if (isset($in['base_version']) && (int) $in['base_version'] !== (int) $t->version) {
            return ['task' => self::serialize($t, $auth, $a), 'conflict' => true];
        }
        $status = $in['status'] ?? $t->status;
        $reason = isset($in['reason']) ? trim((string) $in['reason']) : null;
        $patch = [];
        if ($status !== $t->status) {
            if (! in_array($status, Pm::TASK_STATUSES, true)) throw ApiError::field('status', 'INVALID_STATUS');
            // Reopening or cancelling a task is a manager's decision.
            if (($status === 'cancelled' || $t->status === 'cancelled') && ! $a['edit']) throw ApiError::forbidden('TASK_UPDATE_FORBIDDEN', 'You are not authorized to update this task');
            $patch['status'] = $status;
        }
        if ($status === 'pending') {
            $code = $in['pending_reason'] ?? ($status === $t->status ? $t->pending_reason : null);
            if (! $code && ! $reason) throw ApiError::field('reason', 'PENDING_REASON_REQUIRED');
            if ($code && ! in_array($code, Pm::PENDING_REASONS, true)) throw ApiError::field('pending_reason', 'INVALID_REASON');
            if ($code === 'other' && ! $reason) throw ApiError::field('reason', 'PENDING_REASON_REQUIRED');
            $patch['pending_reason'] = $code ?: 'other';
            if ($reason !== null || isset($patch['status'])) $patch['status_reason'] = $reason;
        } elseif ($status === 'blocked') {
            if (! $reason && ! ($status === $t->status && $t->status_reason)) throw ApiError::field('reason', 'BLOCKER_REQUIRED');
            if ($reason) $patch['status_reason'] = $reason;
            $patch['pending_reason'] = null;
        } elseif (isset($patch['status'])) {
            $patch['status_reason'] = $reason;
            $patch['pending_reason'] = null;
        }
        if ($status === 'completed' && $t->status !== 'completed') {
            $patch['completed_at'] = Dates::sql(Dates::now());
            $patch['completed_by'] = $auth->id;
            $patch['completion_note'] = isset($in['note']) ? mb_substr(trim((string) $in['note']), 0, 1000) : null;
            $patch['progress'] = 100;
        } elseif (isset($patch['status']) && $t->status === 'completed') {
            $patch['completed_at'] = null;
            $patch['completed_by'] = null;
            $patch['completion_note'] = null;
        }
        if (array_key_exists('progress', $in) && $in['progress'] !== null && $status !== 'completed') {
            $patch['progress'] = max(0, min(100, (int) $in['progress']));
            // Progress moves a not-started task into In Progress.
            if ($patch['progress'] > 0 && $status === 'not_started' && ! isset($patch['status'])) $patch['status'] = $status = 'in_progress';
        }
        if (array_key_exists('notes', $in)) $patch['notes'] = $in['notes'];
        if (! $patch) return ['task' => self::serialize($t, $auth, $a)];
        $before = [];
        foreach (array_keys($patch) as $k) $before[$k] = $t->{$k};
        $statusChanged = isset($patch['status']) && $patch['status'] !== $t->status;
        DB::transaction(function () use ($actx, $id, $t, $patch, $before, $statusChanged, $reason) {
            DB::table('project_tasks')->where('id', $id)->update($patch + ['version' => DB::raw('version + 1')]);
            $action = $statusChanged ? match ($patch['status']) {
                'completed' => 'project.task.completed',
                'pending' => 'project.task.pending',
                'blocked' => 'project.task.blocked',
                default => 'project.task.status',
            } : (isset($patch['progress']) ? 'project.task.progress' : 'project.task.update');
            Pm::log($actx, $action, (int) $t->project_id, ['task_id' => $id, 'before' => $before, 'after' => $patch, 'reason' => $reason]);
            if ($statusChanged || isset($patch['progress'])) ProjectService::recalculate((int) $t->project_id);
        });
        if ($statusChanged) self::notifyStatus($actx, $t, $patch['status'], $reason);
        if ($statusChanged && ($actx['source'] ?? null) !== 'chat_bot') {
            $fresh = DB::table('project_tasks')->where('id', $id)->first();
            Bot::event($fresh, $patch['status'] === 'completed' ? 'completed' : 'status', $auth->id, ['actor' => $auth->fullName, 'reason' => $reason ? T::t('project.reason.suffix', ['reason' => $reason]) : '']);
        }
        if ($statusChanged) ProjectReminders::planTask($id);
        [$fresh, $a2] = Access::loadTask($auth, $id);
        return ['task' => self::serialize($fresh, $auth, $a2)];
    }

    private static function notifyStatus(array $actx, object $t, string $status, ?string $reason): void
    {
        $auth = $actx['auth'];
        $p = DB::table('projects')->where('id', $t->project_id)->first(['id', 'title', 'leader_id', 'department_id']);
        $assignees = Access::assigneeIds((int) $t->id);
        $managers = Access::managersOf((int) $t->department_id);
        $leader = $p->leader_id ? [(int) $p->leader_id] : [];
        $stamp = Pm::stamp();
        if ($status === 'completed') {
            $team = array_map('intval', DB::table('project_members')->where('project_id', $p->id)->pluck('user_id')->all());
            Pm::notify(array_merge($managers, $leader, $team, $assignees), $auth->id, 'project.completed.title', 'project.completed.body',
                ['task' => $t->title, 'project' => $p->title, 'actor' => $auth->fullName], 'project_task', (int) $t->id, "status:{$t->id}:$stamp", true);
            return;
        }
        Pm::notify(array_merge($assignees, $managers, $leader), $auth->id, 'project.status.title', 'project.status.body', [
            'task' => $t->title, 'status' => T::t("task.status.$status"), 'actor' => $auth->fullName,
            'reason' => $reason ? T::t('project.reason.suffix', ['reason' => $reason]) : '',
        ], 'project_task', (int) $t->id, "status:{$t->id}:$stamp");
    }

    public static function submitCompletion(array $actx, int $id, array $input): array
    {
        [$t, $access] = Access::loadTask($actx['auth'], $id);
        if (! $access['update_status']) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Cannot update this task');

        $deliverableAchieved = ! empty($input['deliverable_achieved']);
        $notes = $input['completion_note'] ?? null;
        $evidence = $input['completion_evidence'] ?? null;

        DB::transaction(function () use ($actx, $id, $t, $deliverableAchieved, $notes, $evidence) {
            DB::table('project_tasks')->where('id', $id)->update([
                'status' => 'awaiting_review',
                'progress' => 100,
                'deliverable_achieved' => $deliverableAchieved ? 1 : 0,
                'completion_note' => $notes,
                'completion_evidence' => $evidence,
                'completed_by' => $actx['auth']->id,
                'version' => DB::raw('version + 1'),
            ]);
            Pm::log($actx, 'project.task.submit_completion', (int) $t->project_id, [
                'task_id' => $id,
                'deliverable_achieved' => $deliverableAchieved,
                'completion_note' => $notes,
            ]);
        });

        $p = DB::table('projects')->where('id', $t->project_id)->first(['id', 'title', 'leader_id', 'department_id']);
        $recipients = array_merge(
            $p->leader_id ? [(int) $p->leader_id] : [],
            Access::managersOf((int) $p->department_id)
        );
        $stamp = Pm::stamp();
        Pm::notify($recipients, $actx['auth']->id, 'task.awaiting_review.title', 'task.awaiting_review.body', [
            'task' => $t->title, 'project' => $p->title, 'actor' => $actx['auth']->fullName,
        ], 'project_task', $id, "review:$id:$stamp");

        [$fresh, $a2] = Access::loadTask($actx['auth'], $id);
        return ['task' => self::serialize($fresh, $actx['auth'], $a2)];
    }

    public static function reviewCompletion(array $actx, int $id, array $input): array
    {
        [$t] = Access::loadTask($actx['auth'], $id, 'edit');
        $approved = ($input['decision'] ?? '') === 'approved';
        $feedback = $input['feedback'] ?? null;
        $newStatus = $approved ? 'completed' : ($input['status'] ?? 'in_progress');

        DB::transaction(function () use ($actx, $id, $t, $approved, $newStatus, $feedback) {
            $patch = [
                'status' => $newStatus,
                'reviewed_by' => $actx['auth']->id,
                'reviewed_at' => Dates::now(),
                'review_feedback' => $feedback,
                'version' => DB::raw('version + 1'),
            ];
            if ($approved) {
                $patch['completed_at'] = Dates::now();
                $patch['completed_by'] = $t->completed_by ?: $actx['auth']->id;
                $patch['progress'] = 100;
            } else {
                $patch['progress'] = min(90, (int) $t->progress);
            }
            DB::table('project_tasks')->where('id', $id)->update($patch);
            Pm::log($actx, $approved ? 'project.task.approve_completion' : 'project.task.reject_completion', (int) $t->project_id, [
                'task_id' => $id,
                'decision' => $approved ? 'approved' : 'rejected',
                'feedback' => $feedback,
            ]);
            ProjectService::recalculate((int) $t->project_id);
        });

        $assignees = Access::assigneeIds($id);
        $p = DB::table('projects')->where('id', $t->project_id)->first(['id', 'title']);
        $stamp = Pm::stamp();
        Pm::notify($assignees, $actx['auth']->id, $approved ? 'task.approved.title' : 'task.returned.title', $approved ? 'task.approved.body' : 'task.returned.body', [
            'task' => $t->title, 'project' => $p->title, 'feedback' => $feedback ?: '',
        ], 'project_task', $id, "rev_done:$id:$stamp");

        [$fresh, $a2] = Access::loadTask($actx['auth'], $id);
        return ['task' => self::serialize($fresh, $actx['auth'], $a2)];
    }

    public static function delete(array $actx, int $id): void
    {
        [$t] = Access::loadTask($actx['auth'], $id, 'edit');
        DB::transaction(function () use ($actx, $id, $t) {
            DB::table('project_tasks')->where('id', $id)->update(['deleted_at' => DB::raw('NOW()'), 'version' => DB::raw('version + 1')]);
            ScheduledNotifications::cancel('project_task', $id);
            Pm::log($actx, 'project.task.delete', (int) $t->project_id, ['task_id' => $id, 'before' => ['title' => $t->title, 'status' => $t->status]]);
            ProjectService::recalculate((int) $t->project_id);
        });
    }
}
