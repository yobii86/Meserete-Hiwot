<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

final class MilestoneService
{
    public static function serialize(object $m): array
    {
        return [
            'id' => (int) $m->id,
            'project_id' => (int) $m->project_id,
            'title' => $m->title,
            'description' => $m->description,
            'due_date' => Dates::toDateOnly($m->due_date),
            'status' => $m->status,
            'completed_at' => $m->completed_at,
            'created_by' => $m->created_by ? (int) $m->created_by : null,
            'created_at' => $m->created_at,
            'updated_at' => $m->updated_at,
        ];
    }

    public static function listForProject(AuthContext $auth, int $projectId): array
    {
        Access::loadProject($auth, $projectId);
        $rows = DB::table('project_milestones')->where('project_id', $projectId)->orderBy('due_date')->get();
        return array_map([self::class, 'serialize'], $rows->all());
    }

    public static function create(array $actx, int $projectId, array $input): array
    {
        Access::loadProject($actx['auth'], $projectId, 'project_manage');
        $id = DB::table('project_milestones')->insertGetId([
            'project_id' => $projectId,
            'title' => $input['title'],
            'description' => $input['description'] ?? null,
            'due_date' => $input['due_date'],
            'status' => $input['status'] ?? 'planned',
            'created_by' => $actx['auth']->id,
        ]);
        Pm::log($actx, 'project.milestone.create', $projectId, ['milestone_id' => $id, 'title' => $input['title']]);
        $row = DB::table('project_milestones')->where('id', $id)->first();
        return self::serialize($row);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $m = DB::table('project_milestones')->where('id', $id)->first();
        if (! $m) throw ApiError::notFound('MILESTONE_NOT_FOUND', 'Milestone not found');
        Access::loadProject($actx['auth'], (int) $m->project_id, 'project_manage');

        $patch = array_intersect_key($input, array_flip(['title', 'description', 'due_date', 'status']));
        if (($patch['status'] ?? '') === 'completed' && $m->status !== 'completed') {
            $patch['completed_at'] = Dates::now();
        } elseif (isset($patch['status']) && $patch['status'] !== 'completed') {
            $patch['completed_at'] = null;
        }

        if ($patch) {
            DB::table('project_milestones')->where('id', $id)->update($patch);
            Pm::log($actx, 'project.milestone.update', (int) $m->project_id, ['milestone_id' => $id, 'patch' => array_keys($patch)]);
        }
        $row = DB::table('project_milestones')->where('id', $id)->first();
        return self::serialize($row);
    }

    public static function delete(array $actx, int $id): void
    {
        $m = DB::table('project_milestones')->where('id', $id)->first();
        if (! $m) throw ApiError::notFound('MILESTONE_NOT_FOUND', 'Milestone not found');
        Access::loadProject($actx['auth'], (int) $m->project_id, 'project_manage');
        DB::table('project_milestones')->where('id', $id)->delete();
        Pm::log($actx, 'project.milestone.delete', (int) $m->project_id, ['milestone_id' => $id]);
    }
}
