<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

final class DecisionService
{
    public static function serialize(object $d): array
    {
        $actions = [];
        if (! empty($d->follow_up_actions)) {
            $actions = is_array($d->follow_up_actions) ? $d->follow_up_actions : json_decode($d->follow_up_actions, true);
        }

        return [
            'id' => (int) $d->id,
            'department_id' => (int) $d->department_id,
            'department_name' => $d->department_name ?? null,
            'project_id' => $d->project_id ? (int) $d->project_id : null,
            'project_title' => $d->project_title ?? null,
            'title' => $d->title,
            'description' => $d->description,
            'decision_date' => Dates::toDateOnly($d->decision_date),
            'decision_maker_id' => (int) $d->decision_maker_id,
            'decision_maker_name' => $d->decision_maker_name ?? null,
            'meeting_minutes' => $d->meeting_minutes,
            'follow_up_actions' => $actions ?: [],
            'status' => $d->status,
            'reviewed_by' => $d->reviewed_by ? (int) $d->reviewed_by : null,
            'reviewer_name' => $d->reviewer_name ?? null,
            'reviewed_at' => $d->reviewed_at,
            'created_by' => (int) $d->created_by,
            'creator_name' => $d->creator_name ?? null,
            'created_at' => $d->created_at,
            'updated_at' => $d->updated_at,
        ];
    }

    public static function create(array $actx, array $input): array
    {
        $deptId = (int) $input['department_id'];
        Access::requireDepartment($actx['auth'], $deptId, 'view');

        $actionsJson = ! empty($input['follow_up_actions']) ? json_encode($input['follow_up_actions'], JSON_UNESCAPED_UNICODE) : null;

        $id = DB::table('project_decisions')->insertGetId([
            'department_id' => $deptId,
            'project_id' => ! empty($input['project_id']) ? (int) $input['project_id'] : null,
            'title' => $input['title'],
            'description' => $input['description'],
            'decision_date' => $input['decision_date'] ?? Dates::todayLocal(),
            'decision_maker_id' => ! empty($input['decision_maker_id']) ? (int) $input['decision_maker_id'] : $actx['auth']->id,
            'meeting_minutes' => $input['meeting_minutes'] ?? null,
            'follow_up_actions' => $actionsJson,
            'status' => $input['status'] ?? 'draft',
            'created_by' => $actx['auth']->id,
        ]);

        Pm::log($actx, 'project.decision.create', $input['project_id'] ?? 0, [
            'decision_id' => $id,
            'title' => $input['title'],
            'status' => $input['status'] ?? 'draft',
        ]);

        return self::get($id);
    }

    public static function get(int $id): array
    {
        $d = DB::table('project_decisions as pd')
            ->join('departments as dept', 'dept.id', '=', 'pd.department_id')
            ->leftJoin('projects as p', 'p.id', '=', 'pd.project_id')
            ->join('users as dm', 'dm.id', '=', 'pd.decision_maker_id')
            ->join('users as cr', 'cr.id', '=', 'pd.created_by')
            ->leftJoin('users as rv', 'rv.id', '=', 'pd.reviewed_by')
            ->where('pd.id', $id)
            ->select('pd.*', 'dept.name as department_name', 'p.title as project_title', 'dm.full_name as decision_maker_name', 'cr.full_name as creator_name', 'rv.full_name as reviewer_name')
            ->first();
        if (! $d) throw ApiError::notFound('DECISION_NOT_FOUND', 'Decision record not found');
        return self::serialize($d);
    }

    public static function list(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_decisions as pd')
            ->join('departments as dept', 'dept.id', '=', 'pd.department_id')
            ->leftJoin('projects as p', 'p.id', '=', 'pd.project_id')
            ->join('users as dm', 'dm.id', '=', 'pd.decision_maker_id')
            ->join('users as cr', 'cr.id', '=', 'pd.created_by')
            ->leftJoin('users as rv', 'rv.id', '=', 'pd.reviewed_by')
            ->select('pd.*', 'dept.name as department_name', 'p.title as project_title', 'dm.full_name as decision_maker_name', 'cr.full_name as creator_name', 'rv.full_name as reviewer_name')
            ->orderByDesc('pd.decision_date')
            ->orderByDesc('pd.id');

        $isPrivileged = $auth->can('pm.decisions.manage') || $auth->accountType === 'admin';
        if (! $isPrivileged) {
            // Ordinary users only see published decisions or ones they created
            $qb->where(function ($w) use ($auth) {
                $w->where('pd.status', 'published')
                    ->orWhere('pd.created_by', $auth->id)
                    ->orWhere('pd.decision_maker_id', $auth->id);
            });
        }

        if (! empty($f['department_id'])) $qb->where('pd.department_id', $f['department_id']);
        if (! empty($f['project_id'])) $qb->where('pd.project_id', $f['project_id']);
        if (! empty($f['status'])) $qb->where('pd.status', $f['status']);

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map([self::class, 'serialize'], $res['items']);
        return $res;
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $d = DB::table('project_decisions')->where('id', $id)->first();
        if (! $d) throw ApiError::notFound('DECISION_NOT_FOUND', 'Decision not found');

        $patch = array_intersect_key($input, array_flip(['title', 'description', 'decision_date', 'decision_maker_id', 'meeting_minutes', 'status']));
        if (isset($input['follow_up_actions'])) {
            $patch['follow_up_actions'] = json_encode($input['follow_up_actions'], JSON_UNESCAPED_UNICODE);
        }

        if (($patch['status'] ?? '') === 'approved' && $d->status !== 'approved') {
            $patch['reviewed_by'] = $actx['auth']->id;
            $patch['reviewed_at'] = Dates::now();
        }

        if ($patch) {
            DB::table('project_decisions')->where('id', $id)->update($patch);
            Pm::log($actx, 'project.decision.update', (int) ($d->project_id ?? 0), ['decision_id' => $id]);
        }

        return self::get($id);
    }

    public static function publish(array $actx, int $id): array
    {
        $d = DB::table('project_decisions')->where('id', $id)->first();
        if (! $d) throw ApiError::notFound('DECISION_NOT_FOUND', 'Decision not found');

        DB::table('project_decisions')->where('id', $id)->update([
            'status' => 'published',
            'reviewed_by' => $actx['auth']->id,
            'reviewed_at' => Dates::now(),
        ]);

        Pm::log($actx, 'project.decision.publish', (int) ($d->project_id ?? 0), ['decision_id' => $id]);

        // Notify people assigned to follow-up actions
        $actions = ! empty($d->follow_up_actions) ? json_decode($d->follow_up_actions, true) : [];
        $assignedUserIds = [];
        foreach ($actions as $act) {
            if (! empty($act['responsible_person_id'])) {
                $assignedUserIds[] = (int) $act['responsible_person_id'];
            }
        }
        if ($assignedUserIds) {
            Notifications::createForUsers(array_unique($assignedUserIds), [
                'type' => 'project',
                'title' => 'የአመራር ውሳኔ የተግባር ኃላፊነት ተሰጥቶዎታል',
                'body' => "በውሳኔ «{$d->title}» ላይ የተመደበልዎ የክትትል ተግባር አለ።",
                'entityType' => 'decision',
                'entityId' => $id,
                'dedupeKey' => fn ($uid) => "dec:act:$id:$uid",
            ]);
        }

        return self::get($id);
    }
}
