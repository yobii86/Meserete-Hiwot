<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

/** Dashboard, filterable reports and the audit / activity log readers (port of reportService.js + logQueryService.js). */
final class Reports
{
    private const REPORT_MAX_OCCURRENCES = 200;

    public static function range(array $f): array
    {
        $to = isset($f['to']) ? Dates::of($f['to']) : Dates::now();
        $from = isset($f['from']) ? Dates::of($f['from']) : $to->modify('-30 days');
        return [$from, $to];
    }

    public static function sqlRange(array $r): array
    {
        return [Dates::sql($r[0]), Dates::sql($r[1])];
    }

    private static function perDay($rows): array
    {
        return array_map(fn ($r) => ['day' => Dates::toDateOnly($r->day), 'count' => (int) $r->c], $rows->all());
    }

    private static function visibleRole($q, string $r = 'r')
    {
        return $q->where(fn ($w) => $w->whereNull("$r.is_hidden")->orWhere("$r.is_hidden", false));
    }

    public static function dashboard(AuthContext $auth): array
    {
        $now = Dates::sql(Dates::now());
        $monthAgo = Dates::sql(Dates::now()->modify('-30 days'));
        $today = Dates::todayLocal();
        $signups = DB::table('users')->where('account_type', 'user')->where('created_at', '>=', $monthAgo)->groupByRaw('DATE(created_at)')
            ->selectRaw('DATE(created_at) as day, COUNT(*) as c')->orderBy('day')->get();
        $nextPrograms = DB::table('programs')->where('status', 'published')->where('starts_at', '>=', $now)->orderBy('starts_at')->limit(5)
            ->select('id', 'title', 'starts_at', 'location', DB::raw("(SELECT COUNT(*) FROM program_participants pp WHERE pp.program_id = programs.id AND pp.status IN ('invited','registered')) as participants"))->get()->all();
        $recentActivity = DB::table('activity_logs as l')->join('users as u', 'u.id', '=', 'l.user_id')->where('u.account_type', 'user')->orderByDesc('l.occurred_at')->limit(10)
            ->select('l.id', 'l.action', 'l.entity_type', 'l.entity_id', 'l.occurred_at', 'u.full_name as user_name')->get()->all();
        $b = DB::table('notification_broadcasts as b')->leftJoin('users as s', 's.id', '=', 'b.sender_id')->leftJoin('roles as r', 'r.id', '=', 's.role_id');
        if (! $auth->isSystem) self::visibleRole($b);
        $recentBroadcasts = $b->orderByDesc('b.created_at')->limit(5)->select('b.id', 'b.kind', 'b.title', 'b.recipient_count', 'b.created_at', Actor::hiddenName('s', 'r', 'sender_name'))->get()->all();
        return [
            'totals' => [
                'users' => DB::table('users')->where('account_type', 'user')->whereNull('deleted_at')->count(),
                'active_users_30d' => DB::table('users')->where(['account_type' => 'user', 'status' => 'active'])->whereNull('deleted_at')->where('last_login_at', '>=', $monthAgo)->count(),
                'new_users_30d' => DB::table('users')->where('account_type', 'user')->where('created_at', '>=', $monthAgo)->count(),
                'mezmurs' => DB::table('mezmurs')->where('status', 'published')->whereNull('deleted_at')->count(),
                'categories' => DB::table('categories')->where('is_active', true)->count(),
                'upcoming_programs' => DB::table('programs')->where('status', 'published')->where('starts_at', '>=', $now)->count(),
                'attendance_30d' => DB::table('attendance')->whereIn('status', ['present', 'late'])->where('attended_at', '>=', $monthAgo)->count(),
                'active_borrowings' => DB::table('borrowings')->whereIn('status', ['active', 'partially_returned'])->count(),
                'overdue_borrowings' => DB::table('borrowings')->whereIn('status', ['active', 'partially_returned'])->where('due_on', '<', $today)->count(),
                'pending_fines' => Num::n(DB::table('borrowings')->where('fine_status', 'pending')->sum('fine_amount')),
            ],
            'signups_30d' => self::perDay($signups),
            'upcoming_programs' => $nextPrograms,
            'recent_activity' => $recentActivity,
            'recent_notifications' => $recentBroadcasts,
        ];
    }

    public static function users(array $f): array
    {
        $r = self::range($f);
        [$from, $to] = self::sqlRange($r);
        $perDay = DB::table('users')->where('account_type', 'user')->whereBetween('created_at', [$from, $to])->groupByRaw('DATE(created_at)')
            ->selectRaw('DATE(created_at) as day, COUNT(*) as c')->orderBy('day')->get();
        $byStatus = [];
        foreach (DB::table('users')->where('account_type', 'user')->whereNull('deleted_at')->groupBy('status')->selectRaw('status, COUNT(*) as c')->get() as $s) $byStatus[$s->status] = (int) $s->c;
        $logins = (int) DB::table('activity_logs')->where('action', 'login')->whereBetween('occurred_at', [$from, $to])->selectRaw('COUNT(DISTINCT user_id) as c')->value('c');
        return ['range' => ['from' => $r[0], 'to' => $r[1]], 'registrations_per_day' => self::perDay($perDay), 'by_status' => (object) $byStatus, 'distinct_logins' => $logins];
    }

    public static function mezmurs(array $f): array
    {
        $r = self::range($f);
        [$from, $to] = self::sqlRange($r);
        $top = function (string $action) use ($f, $from, $to) {
            $q = DB::table('activity_logs as l')->join('mezmurs as m', 'm.id', '=', 'l.entity_id')->where(['l.action' => $action, 'l.entity_type' => 'mezmur'])
                ->whereBetween('l.occurred_at', [$from, $to])->groupBy('m.id', 'm.title')->selectRaw('m.id, m.title, COUNT(*) as c')->orderByDesc('c')->limit(20);
            if (! empty($f['category_id'])) $q->where('m.category_id', $f['category_id']);
            if (! empty($f['user_id'])) $q->where('l.user_id', $f['user_id']);
            return $q->get()->map(fn ($x) => ['id' => $x->id, 'title' => $x->title, 'count' => (int) $x->c])->all();
        };
        $searches = DB::table('activity_logs')->where('action', 'mezmur_search')->whereBetween('occurred_at', [$from, $to])
            ->groupByRaw("JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.q'))")->selectRaw("JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.q')) as q, COUNT(*) as c")->orderByDesc('c')->limit(20)->get();
        return [
            'range' => ['from' => $r[0], 'to' => $r[1]],
            'top_viewed' => $top('mezmur_view'),
            'top_played' => $top('audio_play'),
            'top_favorited' => $top('favorite_add'),
            'top_downloaded' => $top('download'),
            'top_searches' => $searches->map(fn ($s) => ['q' => $s->q, 'count' => (int) $s->c])->all(),
        ];
    }

    /** Per program occurrence in the range, or — with user_id — one member's occurrences and statistics. */
    public static function attendance(array $f): array
    {
        $r = self::range($f);
        $fromDate = Dates::localDateOf($r[0]);
        $toDate = Dates::localDateOf($r[1]);
        $categoryIds = ! empty($f['program_category_id']) ? [$f['program_category_id']] : null;
        if (! empty($f['user_id'])) {
            $occ = array_values(array_filter(Attendance::memberOccurrences($f['user_id'], ['from' => $fromDate, 'to' => $toDate, 'categoryIds' => $categoryIds]), fn ($o) => $o['status'] !== 'upcoming'));
            return [
                'range' => ['from' => $r[0], 'to' => $r[1]],
                'stats' => Attendance::statsOf($occ, Settings::permissionPolicy()['weight']),
                'user_attendance' => array_map(fn ($o) => ['id' => $o['program_id'], 'title' => $o['title'], 'date' => $o['date'], 'starts_at' => $o['starts_at'], 'status' => $o['status'], 'category' => $o['category']], $occ),
            ];
        }
        [$from, $to] = self::sqlRange($r);
        $q = DB::table('programs as p')->where('p.status', '!=', 'draft')->where('p.requires_attendance', true)->where('p.starts_at', '<=', $to)
            ->where(fn ($w) => $w->where('p.ends_at', '>=', $from)->orWhere('p.recurrence', '!=', 'once'))->select('p.*');
        if (! empty($f['program_id'])) $q->where('p.id', $f['program_id']);
        if ($categoryIds) $q->whereIn('p.category_id', $categoryIds);
        if (! empty($f['class_id'])) {
            $q->whereExists(fn ($sq) => $sq->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id')->where('pec.class_id', $f['class_id']));
        }
        $programs = $q->get()->all();
        Schedule::loadOverrides($programs);
        $now = Dates::now();
        $rows = [];
        foreach ($programs as $p) {
            foreach (Schedule::between($p, $fromDate, $toDate) as $o) {
                if (Dates::of($o['starts_at']) > $now) continue;
                $rows[] = [$p, $o];
            }
        }
        usort($rows, fn ($a, $b) => Dates::ms($b[1]['starts_at']) <=> Dates::ms($a[1]['starts_at']));
        $out = [];
        foreach (array_slice($rows, 0, self::REPORT_MAX_OCCURRENCES) as [$p, $o]) {
            $s = Attendance::summary($p->id, $o['date']);
            // The occurrence's own taker (session), else the program's default taker.
            $sess = DB::table('attendance_sessions as ss')->leftJoin('users as u', 'u.id', '=', 'ss.taker_id')
                ->where(['ss.program_id' => $p->id, 'ss.occurrence_date' => $o['date']])->first(['u.full_name', 'ss.started_at']);
            $taker = $sess?->full_name ?? DB::table('program_attendance_takers as pat')->join('users as u', 'u.id', '=', 'pat.user_id')->where('pat.program_id', $p->id)->value('u.full_name');
            $out[] = [
                'id' => $p->id, 'title' => $p->title, 'category_id' => $p->category_id, 'date' => $o['date'], 'starts_at' => $o['starts_at'],
                'takers' => $taker ?: 'Not assigned', 'started_at' => $sess?->started_at,
                'participants' => $s['expected'], 'attended' => $s['present'], 'legacy_late' => $s['legacy_late'], 'excused' => $s['excused'], 'absent' => $s['absent'], 'unmarked' => $s['unmarked'],
            ];
        }
        return ['range' => ['from' => $r[0], 'to' => $r[1]], 'programs' => $out, 'truncated' => count($rows) > self::REPORT_MAX_OCCURRENCES];
    }

    public static function borrowings(array $f): array
    {
        $r = self::range($f);
        [$from, $to] = self::sqlRange($r);
        $today = Dates::todayLocal();
        $base = function () use ($f, $from, $to) {
            $q = DB::table('borrowings as b')->whereBetween('b.created_at', [$from, $to]);
            if (! empty($f['item_id'])) $q->where('b.item_id', $f['item_id']);
            if (! empty($f['user_id'])) $q->where('b.user_id', $f['user_id']);
            return $q;
        };
        $byStatus = [];
        foreach ($base()->groupBy('b.status')->selectRaw('b.status, COUNT(*) as c')->get() as $x) $byStatus[$x->status] = (int) $x->c;
        $byItem = $base()->join('items as i', 'i.id', '=', 'b.item_id')->groupBy('i.id', 'i.name', 'i.code')->selectRaw('i.id, i.name, i.code, SUM(b.quantity) as qty, COUNT(*) as c')->orderByDesc('c')->limit(20)->get();
        $overdue = DB::table('borrowings as b')->join('users as u', 'u.id', '=', 'b.user_id')->join('items as i', 'i.id', '=', 'b.item_id')
            ->whereIn('b.status', ['active', 'partially_returned'])->where('b.due_on', '<', $today)->orderBy('b.due_on')->limit(100)
            ->select('b.id', 'u.full_name', 'u.phone', 'i.name as item_name', 'b.quantity', 'b.due_on', 'b.fine_amount')->get()->all();
        $fines = [];
        foreach ($base()->where('b.fine_amount', '>', 0)->groupBy('b.fine_status')->selectRaw('b.fine_status, SUM(b.fine_amount) as total, COUNT(*) as c')->get() as $x) {
            $fines[$x->fine_status] = ['count' => (int) $x->c, 'total' => Num::n($x->total)];
        }
        return [
            'range' => ['from' => $r[0], 'to' => $r[1]],
            'by_status' => (object) $byStatus,
            'by_item' => $byItem->map(fn ($x) => ['id' => $x->id, 'name' => $x->name, 'code' => $x->code, 'borrowings' => (int) $x->c, 'quantity' => Num::n($x->qty)])->all(),
            'overdue' => $overdue,
            'fines' => (object) $fines,
        ];
    }

    public static function notifications(AuthContext $auth, array $f): array
    {
        $r = self::range($f);
        [$from, $to] = self::sqlRange($r);
        $byType = DB::table('notifications')->whereBetween('created_at', [$from, $to])->groupBy('type', 'delivery_status')
            ->selectRaw('type, delivery_status, COUNT(*) as c, SUM(read_at IS NOT NULL) as read_count')->get();
        $q = DB::table('notification_broadcasts as b')->leftJoin('users as s', 's.id', '=', 'b.sender_id')->leftJoin('roles as r', 'r.id', '=', 's.role_id')->whereBetween('b.created_at', [$from, $to]);
        if (! $auth->isSystem) self::visibleRole($q);
        if (! empty($f['admin_id'])) $q->where('b.sender_id', $f['admin_id']);
        $bySender = $q->groupBy('b.sender_id', 's.full_name', 'r.is_hidden')->select(Actor::hiddenName('s', 'r', 'sender_name'))
            ->selectRaw('COUNT(*) as c, SUM(b.recipient_count) as recipients')->get();
        return [
            'range' => ['from' => $r[0], 'to' => $r[1]],
            'by_type' => $byType->map(fn ($x) => ['type' => $x->type, 'delivery_status' => $x->delivery_status, 'count' => (int) $x->c, 'read' => Num::n($x->read_count)])->all(),
            'by_sender' => $bySender->map(fn ($x) => ['sender_name' => $x->sender_name, 'broadcasts' => (int) $x->c, 'recipients' => Num::n($x->recipients)])->all(),
        ];
    }

    public static function adminActivity(AuthContext $auth, array $f): array
    {
        $r = self::range($f);
        [$from, $to] = self::sqlRange($r);
        $q = DB::table('audit_logs as l')->leftJoin('users as a', 'a.id', '=', 'l.actor_id')->leftJoin('roles as r', 'r.id', '=', 'a.role_id')->whereBetween('l.created_at', [$from, $to])
            ->groupBy('l.actor_id', 'a.full_name', 'r.is_hidden', 'l.action')->select('l.action', Actor::hiddenName('a', 'r', 'actor_name'))->selectRaw('COUNT(*) as c')->orderByDesc('c');
        if (! $auth->isSystem) self::visibleRole($q->where('l.is_hidden', false));
        if (! empty($f['admin_id'])) $q->where('l.actor_id', $f['admin_id']);
        return ['range' => ['from' => $r[0], 'to' => $r[1]], 'actions' => $q->get()->map(fn ($x) => ['actor_name' => $x->actor_name, 'action' => $x->action, 'count' => (int) $x->c])->all()];
    }

    // ------------------------------------------------------------------ logs
    private static function meta($m)
    {
        return is_string($m) ? json_decode($m) : $m;
    }

    /** Regular admins never see hidden entries (actions by / about the internal system authority). */
    public static function auditLogs(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('audit_logs as l')->leftJoin('users as a', 'a.id', '=', 'l.actor_id')->leftJoin('roles as r', 'r.id', '=', 'a.role_id')
            ->select('l.id', 'l.action', 'l.entity_type', 'l.entity_id', 'l.metadata', 'l.ip', 'l.created_at', Actor::hiddenId('a', 'r', 'actor_id'), Actor::hiddenName('a', 'r', 'actor_name'))
            ->orderByDesc('l.id');
        if ($auth->isSystem) $qb->addSelect('l.is_hidden', 'a.full_name as actor_real_name', 'l.user_agent');
        else self::visibleRole($qb->where('l.is_hidden', false));
        if (! empty($f['actor_id'])) $qb->where('l.actor_id', $f['actor_id']);
        if (! empty($f['action'])) $qb->where('l.action', 'like', "{$f['action']}%");
        if (! empty($f['entity_type'])) $qb->where('l.entity_type', $f['entity_type']);
        if (! empty($f['entity_id'])) $qb->where('l.entity_id', $f['entity_id']);
        if (! empty($f['from'])) $qb->where('l.created_at', '>=', Dates::sql($f['from']));
        if (! empty($f['to'])) $qb->where('l.created_at', '<=', Dates::sql($f['to']));
        if (! empty($f['module'])) {
            $mod = strtolower(trim($f['module']));
            $qb->where(function ($q) use ($mod) {
                if ($mod === 'education' || $mod === 'edu') {
                    $q->where('l.action', 'like', 'edu%')->orWhere('l.action', 'like', 'education%')->orWhere('l.entity_type', 'like', 'edu%');
                } elseif ($mod === 'mezmur') {
                    $q->where('l.action', 'like', 'mezmur%')->orWhere('l.entity_type', 'like', 'mezmur%');
                } elseif ($mod === 'program' || $mod === 'programs') {
                    $q->where('l.action', 'like', 'program%')->orWhere('l.entity_type', 'like', 'program%');
                } elseif ($mod === 'attendance') {
                    $q->where('l.action', 'like', 'attendance%')->orWhere('l.entity_type', 'like', 'attendance%');
                } elseif ($mod === 'selection' || $mod === 'selections') {
                    $q->where('l.action', 'like', 'selection%')->orWhere('l.entity_type', 'like', 'selection%');
                } elseif ($mod === 'finance' || $mod === 'payment' || $mod === 'payments') {
                    $q->where('l.action', 'like', 'payment%')->orWhere('l.action', 'like', 'receipt%')
                        ->orWhere('l.entity_type', 'like', 'payment%')->orWhere('l.entity_type', 'like', 'receipt%');
                } elseif ($mod === 'system') {
                    $q->where('l.action', 'like', 'system%')->orWhere('l.action', 'like', 'setting%')
                        ->orWhere('l.entity_type', 'like', 'setting%')->orWhere('l.entity_type', 'like', 'system%');
                } else {
                    $q->where('l.action', 'like', "{$mod}%")->orWhere('l.entity_type', 'like', "{$mod}%");
                }
            });
        }
        $search = trim((string) ($f['q'] ?? $f['search'] ?? ''));
        if ($search !== '') {
            $qb->where(function ($q) use ($search) {
                $term = "%{$search}%";
                $q->where('a.full_name', 'like', $term)
                    ->orWhere('l.action', 'like', $term)
                    ->orWhere('l.entity_type', 'like', $term)
                    ->orWhere('l.metadata', 'like', $term);
            });
        }
        if (! empty($f['outcome'])) {
            $outcome = trim($f['outcome']);
            $qb->where(function ($q) use ($outcome) {
                $q->where('l.metadata', 'like', '%"outcome":"' . $outcome . '"%')
                    ->orWhere('l.metadata', 'like', '%"status":"' . $outcome . '"%')
                    ->orWhere('l.action', 'like', "%{$outcome}%");
            });
        }
        if ($auth->isSystem && ! empty($f['hidden_only'])) $qb->where('l.is_hidden', true);
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(function ($x) {
            $x->metadata = self::meta($x->metadata);
            return $x;
        }, $res['items']), 'meta' => $res['meta']];
    }

    public static function activityLogs(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('activity_logs as l')->leftJoin('users as u', 'u.id', '=', 'l.user_id')->leftJoin('roles as r', 'r.id', '=', 'u.role_id')
            ->leftJoin('mezmurs as em', fn ($j) => $j->on('em.id', '=', 'l.entity_id')->where('l.entity_type', '=', 'mezmur'))
            ->leftJoin('programs as ep', fn ($j) => $j->on('ep.id', '=', 'l.entity_id')->where('l.entity_type', '=', 'program'))
            ->leftJoin('categories as ec', fn ($j) => $j->on('ec.id', '=', 'l.entity_id')->where('l.entity_type', '=', 'category'))
            ->leftJoin('items as ei', fn ($j) => $j->on('ei.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['item', 'book', 'digital_book', 'physical_book']))
            ->leftJoin('edu_lessons as el', fn ($j) => $j->on('el.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['lesson', 'edu_lesson']))
            ->leftJoin('edu_lesson_materials as emat', fn ($j) => $j->on('emat.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['material', 'edu_material', 'lesson_material', 'edu_lesson_material']))
            ->leftJoin('edu_quizzes as eq', fn ($j) => $j->on('eq.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['quiz', 'edu_quiz']))
            ->leftJoin('edu_magazines as emag', fn ($j) => $j->on('emag.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['magazine', 'edu_magazine']))
            ->leftJoin('edu_courses as eco', fn ($j) => $j->on('eco.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['course', 'edu_course']))
            ->leftJoin('edu_classes as ecl', fn ($j) => $j->on('ecl.id', '=', 'l.entity_id')->whereIn('l.entity_type', ['class', 'edu_class']))
            ->select('l.id', 'l.user_id', 'u.full_name as user_name', 'u.phone as user_phone', 'l.action', 'l.entity_type', 'l.entity_id',
                // Human-readable subject: which Mezmur / program / category / book / lesson / material / quiz / magazine the action was about.
                DB::raw('COALESCE(em.title, ep.title, ec.name, ei.name, el.title, emat.title, eq.title, emag.title, eco.name, ecl.name) as entity_title'), 'l.metadata', 'l.occurred_at')
            ->orderByDesc('l.occurred_at');
        if (! $auth->isSystem) self::visibleRole($qb);
        if (! empty($f['user_id'])) $qb->where('l.user_id', $f['user_id']);
        if (! empty($f['action'])) $qb->where('l.action', $f['action']);
        if (! empty($f['entity_type'])) $qb->where('l.entity_type', $f['entity_type']);
        if (! empty($f['from'])) $qb->where('l.occurred_at', '>=', Dates::sql($f['from']));
        if (! empty($f['to'])) {
            $toStr = is_string($f['to']) ? trim($f['to']) : null;
            if ($toStr !== null && preg_match('/^\d{4}-\d{2}-\d{2}$/', $toStr)) {
                $qb->where('l.occurred_at', '<=', Dates::sql($toStr . ' 23:59:59'));
            } else {
                $qb->where('l.occurred_at', '<=', Dates::sql($f['to']));
            }
        }
        if (! empty($f['module'])) {
            $mod = strtolower(trim($f['module']));
            $qb->where(function ($q) use ($mod) {
                if ($mod === 'education' || $mod === 'edu') {
                    $q->whereIn('l.action', ['lesson_view', 'material_open', 'quiz_attempt', 'magazine_view'])
                        ->orWhere('l.action', 'like', 'edu%')
                        ->orWhere('l.action', 'like', 'lesson%')
                        ->orWhere('l.action', 'like', 'quiz%')
                        ->orWhereIn('l.entity_type', ['edu_lesson', 'lesson', 'edu_material', 'material', 'edu_quiz', 'quiz', 'edu_magazine', 'magazine', 'edu_course', 'course', 'edu_class', 'class']);
                } elseif ($mod === 'library') {
                    $q->whereIn('l.action', ['borrow', 'return', 'book_read', 'book_download'])
                        ->orWhere('l.action', 'like', 'book%')
                        ->orWhereIn('l.entity_type', ['item', 'book', 'digital_book', 'physical_book', 'borrowing']);
                } elseif ($mod === 'mezmur') {
                    $q->whereIn('l.action', ['mezmur_view', 'mezmur_search', 'audio_play', 'audio_complete', 'favorite_add', 'favorite_remove'])
                        ->orWhere('l.action', 'like', 'mezmur%')
                        ->orWhere('l.action', 'like', 'audio%')
                        ->orWhere('l.entity_type', 'mezmur');
                } elseif ($mod === 'program' || $mod === 'programs') {
                    $q->whereIn('l.action', ['program_view', 'program_register', 'program_unregister', 'reminder_create', 'reminder_update', 'reminder_delete'])
                        ->orWhere('l.action', 'like', 'program%')
                        ->orWhere('l.entity_type', 'program');
                } elseif ($mod === 'attendance') {
                    $q->where('l.action', 'attendance')
                        ->orWhere('l.entity_type', 'attendance');
                }
            });
        }
        $search = trim((string) ($f['q'] ?? $f['search'] ?? ''));
        if ($search !== '') {
            $qb->where(function ($q) use ($search) {
                $term = "%{$search}%";
                $q->where('u.full_name', 'like', $term)
                    ->orWhere('u.phone', 'like', $term)
                    ->orWhere('l.action', 'like', $term)
                    ->orWhere('l.entity_type', 'like', $term)
                    ->orWhere('l.metadata', 'like', $term);
            });
        }
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(function ($x) {
            $x->metadata = self::meta($x->metadata);
            return $x;
        }, $res['items']), 'meta' => $res['meta']];
    }
}
