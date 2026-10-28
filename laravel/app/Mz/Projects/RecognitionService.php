<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

final class RecognitionService
{
    public const CATEGORIES = [
        'exceptional_service' => 'ልዩ አገልግሎት',
        'leadership' => 'አመራር እና ቅንጅት',
        'teamwork' => 'የቡድን ተሳትፎ',
        'dedication' => 'ታማኝነት እና ቁርጠኝነት',
        'innovation' => 'ፈጠራ እና ማሻሻያ',
    ];

    public static function serialize(object $r): array
    {
        return [
            'id' => (int) $r->id,
            'nominee_id' => (int) $r->nominee_id,
            'nominee_name' => $r->nominee_name ?? null,
            'nominator_id' => (int) $r->nominator_id,
            'nominator_name' => $r->nominator_name ?? null,
            'project_id' => $r->project_id ? (int) $r->project_id : null,
            'project_title' => $r->project_title ?? null,
            'task_id' => $r->task_id ? (int) $r->task_id : null,
            'task_title' => $r->task_title ?? null,
            'category' => $r->category,
            'category_label' => self::CATEGORIES[$r->category] ?? $r->category,
            'description' => $r->description,
            'supporting_evidence' => $r->supporting_evidence,
            'status' => $r->status,
            'reviewed_by' => $r->reviewed_by ? (int) $r->reviewed_by : null,
            'reviewer_name' => $r->reviewer_name ?? null,
            'reviewed_at' => $r->reviewed_at,
            'review_note' => $r->review_note,
            'award_date' => Dates::toDateOnly($r->award_date),
            'certificate_note' => $r->certificate_note,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
        ];
    }

    public static function nominate(array $actx, array $input): array
    {
        $nomineeId = (int) $input['nominee_id'];
        $nominatorId = $actx['auth']->id;

        if ($nomineeId === $nominatorId) {
            throw ApiError::conflict('SELF_NOMINATION', 'Cannot nominate oneself for recognition');
        }

        $projectId = ! empty($input['project_id']) ? (int) $input['project_id'] : null;
        $taskId = ! empty($input['task_id']) ? (int) $input['task_id'] : null;

        // Prevent duplicate nominations for the exact same task
        if ($taskId) {
            $exists = DB::table('project_recognitions')
                ->where('nominee_id', $nomineeId)
                ->where('task_id', $taskId)
                ->whereIn('status', ['nominated', 'under_review', 'approved'])
                ->exists();
            if ($exists) {
                throw ApiError::conflict('DUPLICATE_NOMINATION', 'A recognition nomination for this member and task already exists');
            }
        }

        $id = DB::table('project_recognitions')->insertGetId([
            'nominee_id' => $nomineeId,
            'nominator_id' => $nominatorId,
            'project_id' => $projectId,
            'task_id' => $taskId,
            'category' => $input['category'],
            'description' => $input['description'],
            'supporting_evidence' => $input['supporting_evidence'] ?? null,
            'status' => 'nominated',
        ]);

        if ($projectId) {
            Pm::log($actx, 'project.recognition.nominate', $projectId, [
                'recognition_id' => $id,
                'nominee_id' => $nomineeId,
                'category' => $input['category'],
            ]);
        }

        return self::get($id);
    }

    public static function get(int $id): array
    {
        $r = DB::table('project_recognitions as pr')
            ->join('users as nom', 'nom.id', '=', 'pr.nominee_id')
            ->join('users as nor', 'nor.id', '=', 'pr.nominator_id')
            ->leftJoin('projects as p', 'p.id', '=', 'pr.project_id')
            ->leftJoin('project_tasks as t', 't.id', '=', 'pr.task_id')
            ->leftJoin('users as rv', 'rv.id', '=', 'pr.reviewed_by')
            ->where('pr.id', $id)
            ->select('pr.*', 'nom.full_name as nominee_name', 'nor.full_name as nominator_name', 'p.title as project_title', 't.title as task_title', 'rv.full_name as reviewer_name')
            ->first();
        if (! $r) throw ApiError::notFound('RECOGNITION_NOT_FOUND', 'Recognition not found');
        return self::serialize($r);
    }

    public static function list(AuthContext $auth, array $f, array $page): array
    {
        $canManage = $auth->can('pm.recognitions.manage') || $auth->accountType === 'admin';

        $qb = DB::table('project_recognitions as pr')
            ->join('users as nom', 'nom.id', '=', 'pr.nominee_id')
            ->join('users as nor', 'nor.id', '=', 'pr.nominator_id')
            ->leftJoin('projects as p', 'p.id', '=', 'pr.project_id')
            ->leftJoin('project_tasks as t', 't.id', '=', 'pr.task_id')
            ->leftJoin('users as rv', 'rv.id', '=', 'pr.reviewed_by')
            ->select('pr.*', 'nom.full_name as nominee_name', 'nor.full_name as nominator_name', 'p.title as project_title', 't.title as task_title', 'rv.full_name as reviewer_name')
            ->orderByDesc('pr.id');

        if (! $canManage) {
            // Regular members see approved recognitions or their own nominations/awards
            $qb->where(function ($w) use ($auth) {
                $w->where('pr.status', 'approved')
                    ->orWhere('pr.nominator_id', $auth->id)
                    ->orWhere('pr.nominee_id', $auth->id);
            });
        }

        if (! empty($f['status'])) $qb->where('pr.status', $f['status']);
        if (! empty($f['category'])) $qb->where('pr.category', $f['category']);
        if (! empty($f['nominee_id'])) $qb->where('pr.nominee_id', $f['nominee_id']);

        $res = Page::paginate($qb, $page);
        $res['items'] = array_map([self::class, 'serialize'], $res['items']);
        return $res;
    }

    public static function review(array $actx, int $id, array $input): array
    {
        $status = $input['status']; // 'approved' | 'rejected' | 'under_review'
        if (! in_array($status, ['approved', 'rejected', 'under_review'], true)) {
            throw ApiError::field('status', 'INVALID_STATUS');
        }

        $r = DB::table('project_recognitions')->where('id', $id)->first();
        if (! $r) throw ApiError::notFound('RECOGNITION_NOT_FOUND', 'Recognition not found');

        $awardDate = $status === 'approved' ? ($input['award_date'] ?? Dates::todayLocal()) : null;
        $cert = $input['certificate_note'] ?? null;
        $note = $input['review_note'] ?? null;

        DB::table('project_recognitions')->where('id', $id)->update([
            'status' => $status,
            'reviewed_by' => $actx['auth']->id,
            'reviewed_at' => Dates::now(),
            'review_note' => $note,
            'award_date' => $awardDate,
            'certificate_note' => $cert,
        ]);

        if ($status === 'approved') {
            Notifications::createForUsers([(int) $r->nominee_id], [
                'type' => 'project',
                'title' => 'የዕውቅና እና ምስጋና ምስክር ወረቀት ተሰጥቶዎታል',
                'body' => "ለሰጡት የላቀ አገልግሎት የማኅበሩ የዕውቅና ምስክርነት ጸድቆ ተሰጥቶዎታል!",
                'entityType' => 'recognition',
                'entityId' => $id,
                'dedupeKey' => fn ($uid) => "rec:appr:$id:$uid",
            ]);
        }

        return self::get($id);
    }
}
