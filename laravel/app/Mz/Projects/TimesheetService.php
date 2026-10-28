<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

final class TimesheetService
{
    public static function serialize(object $ts, ?object $user = null): array
    {
        return [
            'id' => (int) $ts->id,
            'user_id' => (int) $ts->user_id,
            'user_name' => $ts->user_name ?? ($user->full_name ?? null),
            'project_id' => (int) $ts->project_id,
            'project_title' => $ts->project_title ?? null,
            'task_id' => $ts->task_id ? (int) $ts->task_id : null,
            'task_title' => $ts->task_title ?? null,
            'work_date' => Dates::toDateOnly($ts->work_date),
            'duration_minutes' => (int) $ts->duration_minutes,
            'hours' => round($ts->duration_minutes / 60, 2),
            'description' => $ts->description,
            'status' => $ts->status,
            'reviewed_by' => $ts->reviewed_by ? (int) $ts->reviewed_by : null,
            'reviewer_name' => $ts->reviewer_name ?? null,
            'reviewed_at' => $ts->reviewed_at,
            'review_note' => $ts->review_note,
            'created_at' => $ts->created_at,
            'updated_at' => $ts->updated_at,
        ];
    }

    public static function record(array $actx, array $input): array
    {
        $userId = $actx['auth']->id;
        $projectId = (int) $input['project_id'];
        Access::loadProject($actx['auth'], $projectId);

        $duration = (int) ($input['duration_minutes'] ?? round(((float) ($input['hours'] ?? 0)) * 60));
        if ($duration <= 0 || $duration > 24 * 60) {
            throw ApiError::field('duration_minutes', 'INVALID_DURATION');
        }

        $workDate = $input['work_date'] ?? Dates::todayLocal();
        $taskId = ! empty($input['task_id']) ? (int) $input['task_id'] : null;

        if ($taskId) {
            $task = DB::table('project_tasks')->where('id', $taskId)->where('project_id', $projectId)->first();
            if (! $task) throw ApiError::notFound('TASK_NOT_FOUND', 'Task not found in this project');
        }

        $id = DB::table('project_timesheets')->insertGetId([
            'user_id' => $userId,
            'project_id' => $projectId,
            'task_id' => $taskId,
            'work_date' => $workDate,
            'duration_minutes' => $duration,
            'description' => $input['description'],
            'status' => 'submitted',
        ]);

        Pm::log($actx, 'project.timesheet.record', $projectId, [
            'timesheet_id' => $id,
            'duration_minutes' => $duration,
            'work_date' => $workDate,
        ]);

        return self::get($id);
    }

    public static function get(int $id): array
    {
        $row = DB::table('project_timesheets as pt')
            ->join('users as u', 'u.id', '=', 'pt.user_id')
            ->join('projects as p', 'p.id', '=', 'pt.project_id')
            ->leftJoin('project_tasks as t', 't.id', '=', 'pt.task_id')
            ->leftJoin('users as r', 'r.id', '=', 'pt.reviewed_by')
            ->where('pt.id', $id)
            ->select('pt.*', 'u.full_name as user_name', 'p.title as project_title', 't.title as task_title', 'r.full_name as reviewer_name')
            ->first();
        if (! $row) throw ApiError::notFound('TIMESHEET_NOT_FOUND', 'Timesheet entry not found');
        return self::serialize($row);
    }

    public static function myTimesheets(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_timesheets as pt')
            ->join('users as u', 'u.id', '=', 'pt.user_id')
            ->join('projects as p', 'p.id', '=', 'pt.project_id')
            ->leftJoin('project_tasks as t', 't.id', '=', 'pt.task_id')
            ->leftJoin('users as r', 'r.id', '=', 'pt.reviewed_by')
            ->where('pt.user_id', $auth->id)
            ->orderByDesc('pt.work_date')
            ->orderByDesc('pt.id')
            ->select('pt.*', 'u.full_name as user_name', 'p.title as project_title', 't.title as task_title', 'r.full_name as reviewer_name');

        if (! empty($f['project_id'])) $qb->where('pt.project_id', $f['project_id']);
        if (! empty($f['status'])) $qb->where('pt.status', $f['status']);
        if (! empty($f['from'])) $qb->where('pt.work_date', '>=', $f['from']);
        if (! empty($f['to'])) $qb->where('pt.work_date', '<=', $f['to']);

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map([self::class, 'serialize'], $res['items']);
        return $res;
    }

    public static function listForProject(AuthContext $auth, int $projectId, array $f, array $page): array
    {
        Access::loadProject($auth, $projectId);
        $qb = DB::table('project_timesheets as pt')
            ->join('users as u', 'u.id', '=', 'pt.user_id')
            ->join('projects as p', 'p.id', '=', 'pt.project_id')
            ->leftJoin('project_tasks as t', 't.id', '=', 'pt.task_id')
            ->leftJoin('users as r', 'r.id', '=', 'pt.reviewed_by')
            ->where('pt.project_id', $projectId)
            ->orderByDesc('pt.work_date')
            ->orderByDesc('pt.id')
            ->select('pt.*', 'u.full_name as user_name', 'p.title as project_title', 't.title as task_title', 'r.full_name as reviewer_name');

        if (! empty($f['user_id'])) $qb->where('pt.user_id', $f['user_id']);
        if (! empty($f['status'])) $qb->where('pt.status', $f['status']);

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map([self::class, 'serialize'], $res['items']);
        return $res;
    }

    public static function review(array $actx, int $id, array $input): array
    {
        $ts = DB::table('project_timesheets')->where('id', $id)->first();
        if (! $ts) throw ApiError::notFound('TIMESHEET_NOT_FOUND', 'Timesheet entry not found');

        Access::loadProject($actx['auth'], (int) $ts->project_id, 'project_manage');

        $status = $input['status']; // 'approved' | 'rejected'
        if (! in_array($status, ['approved', 'rejected'], true)) throw ApiError::field('status', 'INVALID_STATUS');

        $note = $input['review_note'] ?? null;

        DB::table('project_timesheets')->where('id', $id)->update([
            'status' => $status,
            'reviewed_by' => $actx['auth']->id,
            'reviewed_at' => Dates::now(),
            'review_note' => $note,
        ]);

        Pm::log($actx, 'project.timesheet.review', (int) $ts->project_id, [
            'timesheet_id' => $id,
            'status' => $status,
            'review_note' => $note,
        ]);

        return self::get($id);
    }
}
