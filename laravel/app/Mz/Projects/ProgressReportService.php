<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

final class ProgressReportService
{
    public static function serialize(object $r): array
    {
        return [
            'id' => (int) $r->id,
            'project_id' => (int) $r->project_id,
            'project_title' => $r->project_title ?? null,
            'reporting_period' => $r->reporting_period,
            'work_completed' => $r->work_completed,
            'planned_work' => $r->planned_work,
            'progress_percent' => (int) $r->progress_percent,
            'blockers' => $r->blockers,
            'next_steps' => $r->next_steps,
            'status' => $r->status,
            'submitted_by' => (int) $r->submitted_by,
            'submitter_name' => $r->submitter_name ?? null,
            'reviewed_by' => $r->reviewed_by ? (int) $r->reviewed_by : null,
            'reviewer_name' => $r->reviewer_name ?? null,
            'reviewed_at' => $r->reviewed_at,
            'review_notes' => $r->review_notes,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
        ];
    }

    public static function create(array $actx, int $projectId, array $input): array
    {
        Access::loadProject($actx['auth'], $projectId);

        $id = DB::table('project_progress_reports')->insertGetId([
            'project_id' => $projectId,
            'reporting_period' => $input['reporting_period'],
            'work_completed' => $input['work_completed'],
            'planned_work' => $input['planned_work'],
            'progress_percent' => (int) ($input['progress_percent'] ?? 0),
            'blockers' => $input['blockers'] ?? null,
            'next_steps' => $input['next_steps'] ?? null,
            'status' => $input['status'] ?? 'submitted',
            'submitted_by' => $actx['auth']->id,
        ]);

        Pm::log($actx, 'project.report.create', $projectId, [
            'report_id' => $id,
            'period' => $input['reporting_period'],
        ]);

        return self::get($id);
    }

    public static function get(int $id): array
    {
        $row = DB::table('project_progress_reports as ppr')
            ->join('projects as p', 'p.id', '=', 'ppr.project_id')
            ->join('users as s', 's.id', '=', 'ppr.submitted_by')
            ->leftJoin('users as r', 'r.id', '=', 'ppr.reviewed_by')
            ->where('ppr.id', $id)
            ->select('ppr.*', 'p.title as project_title', 's.full_name as submitter_name', 'r.full_name as reviewer_name')
            ->first();
        if (! $row) throw ApiError::notFound('REPORT_NOT_FOUND', 'Progress report not found');
        return self::serialize($row);
    }

    public static function listForProject(AuthContext $auth, int $projectId, array $page): array
    {
        Access::loadProject($auth, $projectId);
        $qb = DB::table('project_progress_reports as ppr')
            ->join('projects as p', 'p.id', '=', 'ppr.project_id')
            ->join('users as s', 's.id', '=', 'ppr.submitted_by')
            ->leftJoin('users as r', 'r.id', '=', 'ppr.reviewed_by')
            ->where('ppr.project_id', $projectId)
            ->orderByDesc('ppr.id')
            ->select('ppr.*', 'p.title as project_title', 's.full_name as submitter_name', 'r.full_name as reviewer_name');

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map([self::class, 'serialize'], $res['items']);
        return $res;
    }

    public static function review(array $actx, int $id, array $input): array
    {
        $r = DB::table('project_progress_reports')->where('id', $id)->first();
        if (! $r) throw ApiError::notFound('REPORT_NOT_FOUND', 'Progress report not found');

        Access::loadProject($actx['auth'], (int) $r->project_id, 'project_manage');

        $status = $input['status'] ?? 'reviewed';
        $note = $input['review_notes'] ?? null;

        DB::table('project_progress_reports')->where('id', $id)->update([
            'status' => $status,
            'reviewed_by' => $actx['auth']->id,
            'reviewed_at' => Dates::now(),
            'review_notes' => $note,
        ]);

        Pm::log($actx, 'project.report.review', (int) $r->project_id, [
            'report_id' => $id,
            'status' => $status,
        ]);

        return self::get($id);
    }
}
