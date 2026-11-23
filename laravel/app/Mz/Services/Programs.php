<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Programs (definitions), occurrences, participants and program categories (port of programService.js). */
final class Programs
{
    public const ACTIVE_PARTICIPANT = ['invited', 'registered'];
    private const UPDATABLE = ['title', 'description', 'location', 'starts_at', 'ends_at', 'requires_registration', 'requires_attendance', 'capacity', 'audience', 'status', 'reminder_enabled', 'reminder_days_before', 'reminder_title', 'reminder_body', 'is_additional', 'counts_for_selection', 'is_mandatory_reminder', 'reminder_interval_days', 'reminder_interval_start', 'schedule_id', 'ordinal_weeks', 'recurring_weekdays'];

    /** Offsets (minutes before the start) as stored: "1440,60". */
    public static function offsetsOf(?string $csv): array
    {
        $out = array_values(array_unique(array_filter(array_map('intval', explode(',', (string) $csv)), fn ($v) => $v > 0)));
        rsort($out);
        return $out;
    }

    private static function offsetsCsv(array $offsets): string
    {
        $o = array_values(array_unique(array_map('intval', $offsets)));
        rsort($o);
        return implode(',', $o);
    }

    /**
     * Default first day of an every-N-days reminder cycle: the program's (local) start date when it
     * has already started, otherwise today, so a program still ahead is announced from now on.
     */
    public static function intervalStart(mixed $startsAt): string
    {
        $start = Dates::toDateOnly(Dates::of($startsAt)->setTimezone(Dates::tz())->format('Y-m-d'));
        $today = Dates::todayLocal();
        return $start < $today ? $start : $today;
    }

    public static function endOfDay(mixed $startsAt): string
    {
        $d = $startsAt ? Dates::of($startsAt) : Dates::now();
        return Dates::sql(Dates::fromLocal(Dates::localDateOf($d) . ' 23:59:59'));
    }

    /** ends_at / has_end_time for a create or an update (null or missing = no end time). */
    private static function endFields(array $input, ?object $current = null): array
    {
        $startsAt = $input['starts_at'] ?? $current?->starts_at;
        $hasEnd = $current ? (bool) $current->has_end_time : true;
        if (array_key_exists('ends_at', $input)) $hasEnd = $input['ends_at'] !== null;
        elseif (! $current) $hasEnd = false;
        if ($hasEnd) {
            $endsAt = $input['ends_at'] ?? $current?->ends_at;
            self::assertDates($startsAt, $endsAt);
            return ['ends_at' => Dates::sql(Dates::of($endsAt)), 'has_end_time' => true];
        }
        return ['ends_at' => self::endOfDay($startsAt), 'has_end_time' => false];
    }

    public static function occ(?array $o): ?array
    {
        if (! $o) return null;
        $out = ['date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at']];
        if (! empty($o['rescheduled'])) $out['rescheduled'] = true;
        if (! empty($o['cancelled'])) $out['cancelled'] = true;
        if (! empty($o['suspended'])) $out['suspended'] = true;
        return $out;
    }

    public static function serialize(object $p, ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $next = Schedule::next($p, $now);
        $out = [
            'id' => $p->id,
            'title' => $p->title,
            'description' => $p->description,
            'image_url' => Storage::url($p->image),
            'location' => $p->location,
            'starts_at' => $p->starts_at,
            'ends_at' => $p->ends_at,
            'has_end_time' => property_exists($p, 'has_end_time') ? (bool) $p->has_end_time : true,
            'requires_registration' => (bool) $p->requires_registration,
            'requires_attendance' => (bool) $p->requires_attendance,
            'capacity' => $p->capacity,
            'audience' => $p->audience,
            'kind' => $p->audience === 'all' ? 'general' : 'special',
            'event_type' => $p->event_type ?? null,
            'category' => $p->category_id ? ['id' => $p->category_id, 'name' => $p->category_name ?? null, 'name_en' => $p->category_name_en ?? null, 'color' => $p->category_color ?? null] : null,
            'member_groups' => $p->member_groups ? array_values(array_filter(explode(',', $p->member_groups))) : [],
            'recurrence' => $p->recurrence ?? 'once',
            'monthly_rule' => $p->monthly_rule ?? null,
            'ordinal_weeks' => ! empty($p->ordinal_weeks) ? array_map('intval', explode(',', $p->ordinal_weeks)) : null,
            'recurring_weekdays' => isset($p->recurring_weekdays) && $p->recurring_weekdays !== null && $p->recurring_weekdays !== '' ? array_map('intval', explode(',', $p->recurring_weekdays)) : null,
            'ethiopian_days' => $p->ethiopian_days ? array_map('intval', explode(',', $p->ethiopian_days)) : null,
            'recurrence_until' => Dates::toDateOnly($p->recurrence_until ?? null),
            'is_additional' => (bool) ($p->is_additional ?? false),
            'counts_for_selection' => property_exists($p, 'counts_for_selection') ? (bool) $p->counts_for_selection : true,
            'next_occurrence' => self::occ($next),
            'upcoming_occurrences' => $p->status === 'published' ? array_map([self::class, 'occ'], Schedule::upcoming($p, 6, $now)) : [],
            'status' => $p->status,
        ];
        if (property_exists($p, 'participant_count')) {
            $out['participant_count'] = (int) $p->participant_count;
        }
        $isMandatory = (bool) ($p->is_mandatory_reminder ?? false);
        $out += [
            'my_participation' => $p->my_status ?? null,
            'my_attendance' => $p->my_attendance ?? null,
            'is_mandatory_reminder' => $isMandatory,
            'reminders_enforce' => $isMandatory,
            'reminder' => [
                'enabled' => (bool) $p->reminder_enabled,
                'days_before' => $p->reminder_days_before,
                'offsets' => self::offsetsOf($p->reminder_offsets ?? null),
                'title' => $p->reminder_title,
                'body' => $p->reminder_body,
                'is_mandatory_reminder' => $isMandatory,
                'enforce' => $isMandatory,
                'interval_days' => isset($p->reminder_interval_days) ? (int) $p->reminder_interval_days : null,
                'interval_start' => Dates::toDateOnly($p->reminder_interval_start ?? null),
                'interval_last_at' => $p->reminder_interval_last_at ?? null,
            ],
            // The member's own choice for this program (null = the program's reminders).
            'my_reminder_offsets' => property_exists($p, 'my_reminder_offsets') && $p->my_reminder_offsets !== null ? self::offsetsOf($p->my_reminder_offsets) : null,
            'created_at' => $p->created_at,
            'updated_at' => $p->updated_at,
        ];

        $classes = [];
        $classIds = [];
        if (Schema::hasTable('program_edu_classes')) {
            $classes = DB::table('program_edu_classes as pc')
                ->join('edu_classes as c', 'c.id', '=', 'pc.class_id')
                ->leftJoin('edu_levels as l', 'l.id', '=', 'c.level_id')
                ->leftJoin('edu_academic_years as y', 'y.id', '=', 'c.academic_year_id')
                ->where('pc.program_id', $p->id)
                ->select('c.id', 'c.name', 'c.status', 'l.code as level_code', 'l.name as level_name', 'y.eth_year', 'y.name as year_name')
                ->get()
                ->map(fn ($c) => [
                    'id' => (int) $c->id,
                    'name' => $c->name,
                    'status' => $c->status,
                    'level' => $c->level_code ? ['code' => $c->level_code, 'name' => $c->level_name] : null,
                    'academic_year' => $c->eth_year ? ['eth_year' => (int) $c->eth_year, 'name' => $c->year_name] : null,
                ])->all();
            $classIds = array_column($classes, 'id');
        }

        $courses = [];
        $courseIds = [];
        if (Schema::hasTable('program_edu_courses')) {
            $courses = DB::table('program_edu_courses as pc')
                ->join('edu_courses as co', 'co.id', '=', 'pc.course_id')
                ->where('pc.program_id', $p->id)
                ->select('co.id', 'co.name', 'co.class_id')
                ->get()
                ->map(fn ($c) => [
                    'id' => (int) $c->id,
                    'name' => $c->name,
                    'class_id' => (int) $c->class_id,
                ])->all();
            $courseIds = array_column($courses, 'id');
        }
        $schedule = null;
        if (property_exists($p, 'schedule_id') && $p->schedule_id && Schema::hasTable('edu_schedule')) {
            $sRow = DB::table('edu_schedule as s')
                ->leftJoin('edu_courses as co', 'co.id', '=', 's.course_id')
                ->leftJoin('edu_classes as c', 'c.id', '=', 's.class_id')
                ->where('s.id', $p->schedule_id)
                ->select('s.*', 'co.name as course_name', 'c.name as class_name')
                ->first();
            if ($sRow) {
                $schedule = [
                    'id' => (int) $sRow->id,
                    'class_id' => (int) $sRow->class_id,
                    'class_name' => $sRow->class_name,
                    'course_id' => $sRow->course_id ? (int) $sRow->course_id : null,
                    'course_name' => $sRow->course_name,
                    'weekday' => (int) $sRow->weekday,
                    'frequency' => $sRow->frequency ?? 'weekly',
                    'starts' => $sRow->starts,
                    'ends' => $sRow->ends,
                    'location' => $sRow->location,
                ];
            }
        }
        $out['schedule_id'] = property_exists($p, 'schedule_id') && $p->schedule_id ? (int) $p->schedule_id : null;
        $out['schedule'] = $schedule;
        $out['classes'] = $classes;
        $out['class_ids'] = $classIds;
        $out['courses'] = $courses;
        $out['course_ids'] = $courseIds;
        $catIsEdu = false;
        if (! empty($p->category_id) && Schema::hasTable('program_categories') && Schema::hasColumn('program_categories', 'is_education')) {
            $catIsEdu = (bool) DB::table('program_categories')->where('id', $p->category_id)->value('is_education');
        }
        $out['is_education'] = $catIsEdu || ! empty($classes) || ! empty($courses) || ! empty($out['schedule_id']);

        return $out;
    }

    private static function base(?AuthContext $auth): Builder
    {
        $qb = DB::table('programs as p')->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->select('p.*', 'pc.name as category_name', 'pc.name_en as category_name_en', 'pc.color as category_color', DB::raw("(SELECT COUNT(*) FROM program_participants pp WHERE pp.program_id = p.id AND pp.status IN ('invited','registered')) as participant_count"));
        if ($auth) {
            $qb->selectRaw("(SELECT pp.status FROM program_participants pp WHERE pp.program_id = p.id AND pp.user_id = ? AND pp.status <> 'cancelled') as my_status", [$auth->id]);
            $qb->selectRaw('(SELECT a.status FROM attendance a WHERE a.program_id = p.id AND a.user_id = ? ORDER BY a.occurrence_date DESC LIMIT 1) as my_attendance', [$auth->id]);
            $qb->selectRaw('(SELECT rc.offsets FROM program_reminder_choices rc WHERE rc.program_id = p.id AND rc.user_id = ?) as my_reminder_offsets', [$auth->id]);
        }
        return $qb;
    }

    /** General programs are public; special events only for invited; education programs restricted to their enrolled classes. */
    private static function visibleTo(Builder $qb, ?AuthContext $auth): Builder
    {
        return $qb->where(function ($w) use ($auth) {
            // Super admins and admins with program/attendance permissions see all programs
            if ($auth?->isSuperAdmin() || ($auth?->isAdmin && ($auth->can('programs.manage') || $auth->can('attendance.view') || $auth->can('attendance.manage')))) {
                $w->whereRaw('1 = 1');
                return;
            }

            if ($auth?->accountType === 'user') {
                $w->where(function ($sub) use ($auth) {
                    $sub->where(function ($q1) use ($auth) {
                        $q1->where('p.audience', 'all')
                            ->where(fn ($g) => $g->whereNull('p.member_groups')->orWhere('p.member_groups', '')->orWhereRaw('FIND_IN_SET((SELECT gu.member_group FROM users gu WHERE gu.id = ?), p.member_groups)', [$auth->id]));
                    });

                    $sub->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_participants as vp')->whereColumn('vp.program_id', 'p.id')->where('vp.user_id', $auth->id)->whereIn('vp.status', self::ACTIVE_PARTICIPANT));
                });

                // Education filtering: If program has linked classes, user must be enrolled in at least one or be a teacher
                if (Schema::hasTable('program_edu_classes') && ! $auth->can('education.manage') && ! $auth->can('education.view')) {
                    $w->where(function ($edu) use ($auth) {
                        $edu->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec_chk')->whereColumn('pec_chk.program_id', 'p.id'))
                            ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')
                                ->join('edu_enrollments as ee', 'ee.class_id', '=', 'pec.class_id')
                                ->whereColumn('pec.program_id', 'p.id')
                                ->where('ee.user_id', $auth->id)
                                ->where('ee.status', 'active')
                            )
                            ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec_t')
                                ->join('edu_courses as eco', 'eco.class_id', '=', 'pec_t.class_id')
                                ->whereColumn('pec_t.program_id', 'p.id')
                                ->where('eco.teacher_user_id', $auth->id)
                            );
                    });
                }
            } else {
                $w->where('p.audience', 'all')
                    ->where(fn ($g) => $g->whereNull('p.member_groups')->orWhere('p.member_groups', ''));
                if (Schema::hasTable('program_edu_classes')) {
                    $w->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec_anon')->whereColumn('pec_anon.program_id', 'p.id'));
                }
            }
        });
    }

    public static function list(?AuthContext $auth, array $filter, array $page, bool $admin = false): array
    {
        $qb = self::base($auth);
        if (! $admin) {
            $qb->whereIn('p.status', ['published', 'completed', 'cancelled'])->where('p.status', '<>', 'draft');
            self::visibleTo($qb, $auth);
        } elseif (! empty($filter['status'])) {
            $qb->where('p.status', $filter['status']);
        }
        if (! empty($filter['q'])) $qb->where('p.title', 'like', "%{$filter['q']}%");
        if (! empty($filter['category_id'])) $qb->where('p.category_id', $filter['category_id']);
        if (! empty($filter['recurrence'])) $qb->where('p.recurrence', $filter['recurrence']);
        // Programs this account takes attendance for: it is the program's default taker or HR assigned
        // it to one of the program's occurrences. HR (assign / close / override / manage) sees every
        // program that takes attendance — to assign and oversee; recording still needs the assignment.
        if (! empty($filter['takeable_by']) && $filter['takeable_by'] instanceof AuthContext) {
            $taker = $filter['takeable_by'];
            $qb->where('p.requires_attendance', true)->whereIn('p.status', ['published', 'completed']);
            $hr = $taker->can('attendance.assign') || $taker->can('attendance.override') || $taker->can('attendance.close') || $taker->can('attendance.manage');
            if (! $hr) {
                $qb->where(fn ($w) => $w->whereExists(fn ($s) => $s->select(DB::raw(1))->from('program_attendance_takers as t')->whereColumn('t.program_id', 'p.id')->where('t.user_id', $taker->id))
                    ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('attendance_sessions as ss')->whereColumn('ss.program_id', 'p.id')->where('ss.taker_id', $taker->id)->whereIn('ss.status', ['scheduled', 'active'])));
            }
        }
        $now = Dates::now();
        $nowSql = Dates::sql($now);
        $today = Dates::todayLocal($now);
        $seriesOpen = fn ($w) => $w->where('p.recurrence', '<>', 'once')->where(fn ($x) => $x->whereNull('p.recurrence_until')->orWhere('p.recurrence_until', '>=', $today));
        $scope = $filter['scope'] ?? null;
        if ($scope === 'upcoming') {
            $qb->where(fn ($w) => $w->where(fn ($x) => $x->where('p.recurrence', 'once')->where('p.ends_at', '>=', $nowSql))->orWhere($seriesOpen));
        } elseif ($scope === 'past') {
            $qb->whereNot($seriesOpen)->where('p.ends_at', '<', $nowSql)->orderByDesc('p.starts_at');
        } else {
            $qb->orderByDesc('p.starts_at');
        }
        if (! empty($filter['from'])) $qb->where('p.starts_at', '>=', Dates::sql($filter['from']));
        if (! empty($filter['to'])) $qb->where('p.starts_at', '<=', Dates::sql($filter['to']));
        if (! empty($filter['mine']) && $auth) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('program_participants as pp')->whereColumn('pp.program_id', 'p.id')->where('pp.user_id', $auth->id)->whereIn('pp.status', self::ACTIVE_PARTICIPANT));
        }
        if ($scope === 'upcoming') {
            $rows = $qb->get()->all();
            Schedule::loadOverrides($rows);
            $items = array_values(array_filter(array_map(fn ($p) => self::serialize($p, $now), $rows), fn ($p) => $p['next_occurrence'] !== null));
            usort($items, fn ($a, $b) => $a['next_occurrence']['starts_at'] <=> $b['next_occurrence']['starts_at']);
            $total = count($items);
            return ['items' => array_slice($items, $page['offset'], $page['limit']), 'meta' => ['page' => $page['page'], 'limit' => $page['limit'], 'total' => $total, 'pages' => max(1, (int) ceil($total / $page['limit']))]];
        }
        $res = Page::paginate($qb, $page);
        Schedule::loadOverrides($res['items']);
        return ['items' => array_map(fn ($p) => self::serialize($p, $now), $res['items']), 'meta' => $res['meta']];
    }

    public static function calendar(?AuthContext $auth, string $from, string $to, ?int $categoryId): array
    {
        $qb = self::base($auth)->whereIn('p.status', ['published', 'completed'])->where('p.starts_at', '<=', "$to 23:59:59");
        self::visibleTo($qb, $auth);
        if ($categoryId) $qb->where('p.category_id', $categoryId);
        $rows = $qb->get()->all();
        Schedule::loadOverrides($rows);
        $attendanceByOcc = [];
        if ($auth && ! empty($rows)) {
            $programIds = array_map(fn ($r) => $r->id, $rows);
            foreach (\Illuminate\Support\Facades\DB::table('attendance')->where('user_id', $auth->id)->whereIn('program_id', $programIds)->whereBetween('occurrence_date', [$from, $to])->get(['program_id', 'occurrence_date', 'status']) as $att) {
                $dOnly = Dates::toDateOnly($att->occurrence_date);
                $attendanceByOcc[$att->program_id . ':' . $dOnly] = $att->status === 'late' ? 'present' : $att->status;
            }
        }
        $todayLocal = Dates::todayLocal();
        $nowLocal = Dates::now();
        $out = [];
        foreach ($rows as $p) {
            $s = self::serialize($p);
            foreach (Schedule::between($p, $from, $to) as $o) {
                $y = (int) substr($o['date'], 0, 4);
                $m = (int) substr($o['date'], 5, 2);
                $d = (int) substr($o['date'], 8, 2);
                $eth = \App\Mz\Support\Ethiopian::toEthiopian($y, $m, $d);
                $monthNames = ['', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'];
                $out[] = [
                    'program_id' => $p->id,
                    'title' => $p->title,
                    'location' => $p->location,
                    'category' => $s['category'],
                    'audience' => $p->audience,
                    'recurrence' => $s['recurrence'],
                    'status' => $p->status,
                    'has_end_time' => property_exists($p, 'has_end_time') ? (bool) $p->has_end_time : true,
                    'is_education' => ! empty($s['is_education']),
                    'classes' => $s['classes'],
                    'requires_attendance' => (bool) $p->requires_attendance,
                    'my_attendance' => ! empty($o['suspended']) ? 'suspended' : (! empty($o['cancelled']) ? 'cancelled' : ($auth ? ($attendanceByOcc[$p->id . ':' . $o['date']] ?? ($o['ends_at'] < $nowLocal ? 'absent' : ($o['date'] === $todayLocal ? 'today' : 'upcoming'))) : null)),
                    'ethiopian_date' => ($monthNames[$eth['month']] ?? '') . " {$eth['day']}፣ {$eth['year']} ዓ.ም",
                    'ethiopian' => $eth,
                ] + self::occ($o);
            }
        }
        usort($out, fn ($a, $b) => $a['starts_at'] <=> $b['starts_at']);
        return $out;
    }

    /** Preview upcoming occurrences for a program schedule before saving. */
    public static function previewSchedule(array $input): array
    {
        $startsAt = $input['starts_at'] ?? now()->toIso8601String();
        $endsAt = $input['ends_at'] ?? self::endOfDay($startsAt);
        $recurrence = $input['recurrence'] ?? 'once';
        $from = Dates::localDateOf(Dates::of($startsAt));
        $maxTo = Dates::addDays($from, 365);
        $until = ! empty($input['recurrence_until']) ? Dates::toDateOnly($input['recurrence_until']) : null;
        $to = $recurrence === 'once' ? $from : ($until && $until < $maxTo ? $until : $maxTo);

        $ordinalWeeks = null;
        if (! empty($input['ordinal_weeks'])) {
            $w = is_array($input['ordinal_weeks']) ? $input['ordinal_weeks'] : explode(',', (string) $input['ordinal_weeks']);
            $ordinalWeeks = implode(',', array_filter(array_map('intval', (array) $w), fn ($x) => $x >= 1 && $x <= 5));
        }

        $recurringWeekdays = null;
        if (isset($input['recurring_weekdays'])) {
            $wds = is_array($input['recurring_weekdays']) ? $input['recurring_weekdays'] : explode(',', (string) $input['recurring_weekdays']);
            $recurringWeekdays = implode(',', array_filter(array_map('intval', (array) $wds), fn ($x) => $x >= 0 && $x <= 6));
        }

        $candidate = (object) [
            'starts_at' => Dates::sql(Dates::of($startsAt)),
            'ends_at' => Dates::sql(Dates::of($endsAt)),
            'recurrence' => $recurrence,
            'monthly_rule' => $input['monthly_rule'] ?? null,
            'ordinal_weeks' => $ordinalWeeks,
            'recurring_weekdays' => $recurringWeekdays,
            'recurrence_until' => $until,
            'ethiopian_days' => ! empty($input['ethiopian_days']) ? (is_array($input['ethiopian_days']) ? implode(',', $input['ethiopian_days']) : $input['ethiopian_days']) : null,
            '_overrides' => [],
        ];

        $occs = Schedule::between($candidate, $from, $to, null, false);
        $items = array_map(function ($o) {
            $date = $o['date'];
            [$y, $m, $d] = array_map('intval', explode('-', substr($date, 0, 10)));
            $eth = \App\Mz\Support\EthiopianCalendar::fromGregorian($y, $m, $d);
            $dayOfWeek = (new \DateTimeImmutable($date))->format('l');
            return [
                'date' => $date,
                'starts_at' => Dates::iso($o['starts_at']),
                'ends_at' => Dates::iso($o['ends_at']),
                'ethiopian_date' => $eth['formatted'] ?? '',
                'weekday_en' => $dayOfWeek,
            ];
        }, $occs);

        return [
            'total' => count($items),
            'from' => $from,
            'to' => $to,
            'occurrences' => $items,
        ];
    }

    /** Check for overlapping programs (warning only, never blocks authorized administrators). */
    public static function checkOverlap(array $input): array
    {
        $startsAt = $input['starts_at'];
        $endsAt = ! empty($input['ends_at']) ? $input['ends_at'] : Dates::sql(Dates::of($startsAt)->modify('+2 hours'));
        $recurrence = $input['recurrence'] ?? 'once';
        $location = trim($input['location'] ?? '');
        $excludeId = $input['exclude_program_id'] ?? null;

        $candidate = (object) [
            'starts_at' => Dates::sql(Dates::of($startsAt)),
            'ends_at' => Dates::sql(Dates::of($endsAt)),
            'recurrence' => $recurrence,
            'monthly_rule' => $input['monthly_rule'] ?? null,
            'recurrence_until' => $input['recurrence_until'] ?? null,
            'ethiopian_days' => ! empty($input['ethiopian_days']) ? (is_array($input['ethiopian_days']) ? implode(',', $input['ethiopian_days']) : $input['ethiopian_days']) : null,
            '_overrides' => [],
        ];

        $from = Dates::localDateOf($candidate->starts_at);
        $maxTo = Dates::addDays($from, 90);
        $to = $candidate->recurrence === 'once' ? $from : ($candidate->recurrence_until && $candidate->recurrence_until < $maxTo ? $candidate->recurrence_until : $maxTo);

        $candOccurrences = Schedule::between($candidate, $from, $to);
        if (! $candOccurrences) return [];

        $qb = DB::table('programs as p')
            ->leftJoin('program_categories as pc', 'pc.id', '=', 'p.category_id')
            ->whereIn('p.status', ['published', 'completed'])
            ->where('p.starts_at', '<=', "$to 23:59:59")
            ->select('p.*', 'pc.name as category_name', 'pc.name_en as category_name_en', 'pc.color as category_color');

        if ($excludeId) {
            $qb->where('p.id', '!=', $excludeId);
        }

        $existing = $qb->get()->all();
        Schedule::loadOverrides($existing);

        $candByDate = [];
        foreach ($candOccurrences as $co) {
            $candByDate[$co['date']][] = $co;
        }

        $conflicts = [];
        $seen = [];

        foreach ($existing as $ep) {
            $existOccs = Schedule::between($ep, $from, $to);
            foreach ($existOccs as $eo) {
                if (empty($candByDate[$eo['date']])) continue;
                $eStarts = Dates::of($eo['starts_at']);
                $eEnds = empty($ep->has_end_time) ? Dates::of($eo['starts_at'])->modify('+2 hours') : Dates::of($eo['ends_at']);

                foreach ($candByDate[$eo['date']] as $co) {
                    $cStarts = Dates::of($co['starts_at']);
                    $cEnds = Dates::of($co['ends_at']);

                    if ($cStarts < $eEnds && $eStarts < $cEnds) {
                        $key = "{$ep->id}:{$eo['date']}";
                        if (isset($seen[$key])) continue;
                        $seen[$key] = true;

                        $eLoc = trim($ep->location ?? '');
                        $sameVenue = ($location !== '' && $eLoc !== '' && strcasecmp($location, $eLoc) === 0);

                        $eth = \App\Mz\Support\Ethiopian::toEthiopian((int) substr($eo['date'], 0, 4), (int) substr($eo['date'], 5, 2), (int) substr($eo['date'], 8, 2));
                        $monthNames = ['', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'];
                        $ethFormatted = ($monthNames[$eth['month']] ?? '') . " {$eth['day']}፣ {$eth['year']} ዓ.ም";

                        $conflicts[] = [
                            'program_id' => (int) $ep->id,
                            'title' => $ep->title,
                            'category' => $ep->category_id ? [
                                'id' => (int) $ep->category_id,
                                'name' => $ep->category_name,
                                'name_en' => $ep->category_name_en,
                                'color' => $ep->category_color,
                            ] : null,
                            'date' => $eo['date'],
                            'ethiopian_date' => $ethFormatted,
                            'ethiopian' => $eth,
                            'starts_at' => $eo['starts_at'],
                            'ends_at' => $eo['ends_at'],
                            'location' => $ep->location,
                            'conflict_type' => $sameVenue ? 'same_venue' : 'time_overlap',
                            'is_same_venue' => $sameVenue,
                        ];
                    }
                }
            }
        }

        return $conflicts;
    }

    public static function occurrences(int $id, string $from, string $to): array
    {
        $p = DB::table('programs')->where('id', $id)->first();
        if (! $p) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        $today = Dates::todayLocal();
        $closures = array_flip(array_map(fn ($d) => Dates::toDateOnly($d), DB::table('attendance_closures')->where('program_id', $id)->pluck('occurrence_date')->all()));
        $now = Dates::now();
        return array_map(function ($o) use ($today, $closures, $now) {
            $ld = Schedule::localDate($o['starts_at']);
            $cancelled = ! empty($o['cancelled']);
            $suspended = ! empty($o['suspended']);
            return self::occ($o) + [
                'reason' => $o['reason'] ?? null,
                'today' => $ld === $today,
                'active' => ! $cancelled && ! $suspended && $ld <= $today,
                'closed' => ! $cancelled && ! $suspended && ($o['ends_at'] < $now || isset($closures[$o['date']])),
                'suspended' => $suspended,
            ];
        }, Schedule::between($p, $from, $to, null, true));
    }

    /** Cancel, reschedule or restore one occurrence; invited participants of a special event are told. */
    public static function setOccurrence(array $actx, int $id, string $date, array $in): array
    {
        $p = DB::table('programs')->where('id', $id)->first();
        if (! $p) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        $o = Schedule::between($p, $date, $date, null, true)[0] ?? null;
        if (! $o) throw ApiError::field('date', 'NOT_AN_OCCURRENCE');
        $previous = $p->_overrides[$date] ?? null;
        $action = $in['action'] === 'unsuspend' ? 'restore' : $in['action'];
        $startsAt = $in['starts_at'] ?? null;
        $endsAt = $in['ends_at'] ?? null;
        $reason = $in['reason'] ?? null;
        if ($action === 'suspended') {
            $today = Dates::todayLocal();
            if ($date < $today) {
                throw ApiError::badRequest('PAST_OCCURRENCE_CANNOT_BE_SUSPENDED', 'Cannot suspend a past occurrence');
            }
        }
        if ($action === 'rescheduled') {
            if (! $startsAt) throw ApiError::field('starts_at', 'REQUIRED');
            if (! $endsAt) $endsAt = self::endOfDay($startsAt);
            self::assertDates($startsAt, $endsAt);
        }
        if ($action !== 'restore' && ! trim((string) $reason)) throw ApiError::field('reason', 'REASON_REQUIRED');
        DB::transaction(function () use ($actx, $id, $date, $action, $startsAt, $endsAt, $reason, $previous) {
            if ($action === 'restore') {
                DB::table('program_occurrence_overrides')->where(['program_id' => $id, 'occurrence_date' => $date])->delete();
                if (Schema::hasTable('attendance_sessions')) {
                    DB::table('attendance_sessions')->where(['program_id' => $id, 'occurrence_date' => $date, 'status' => 'suspended'])->update(['status' => 'scheduled']);
                }
            } else {
                $row = ['action' => $action, 'starts_at' => $action === 'rescheduled' ? Dates::sql($startsAt) : null, 'ends_at' => $action === 'rescheduled' ? Dates::sql($endsAt) : null, 'reason' => $reason, 'changed_by' => $actx['auth']->id];
                DB::table('program_occurrence_overrides')->upsert([['program_id' => $id, 'occurrence_date' => $date] + $row], ['program_id', 'occurrence_date'], array_keys($row));
                if (Schema::hasTable('attendance_sessions') && $action === 'suspended') {
                    DB::table('attendance_sessions')->where(['program_id' => $id, 'occurrence_date' => $date])->whereNotIn('status', ['ended', 'suspended'])->update(['status' => 'suspended']);
                }
            }
            Audit::log($actx, Audit::PROGRAM_OCCURRENCE, 'program', $id, [
                'date' => $date,
                'action' => $action,
                'previous' => $previous ? ['action' => $previous->action, 'starts_at' => $previous->starts_at] : null,
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'reason' => $reason,
            ], inTrx: true);
        });
        // One day cancelled / moved: everyone who expects that day hears about it (not only invitees).
        if ($action !== 'restore' && $p->status === 'published') {
            $params = ['date' => \App\Mz\Services\ReportExport::ethiopianDate($date . ' 12:00:00'), 'reason' => (string) $reason, 'new_time' => $startsAt ? \App\Mz\Notifications\Mailer::when($startsAt) : ''];
            $announceKind = match ($action) {
                'cancelled' => 'occurrence_cancelled',
                'suspended' => 'occurrence_suspended',
                default => 'occurrence_moved',
            };
            self::announce($id, $announceKind, $actx['auth']->id, $params, "$date:$action:" . \App\Mz\Projects\Pm::stamp());
        }
        $occs = self::occurrences($id, $date, $date);
        $res = $occs;
        $res['success'] = true;
        $res['action'] = $action;
        $res['date'] = $date;
        $res['message'] = $action === 'suspended' ? 'Program occurrence successfully suspended for today' : ($action === 'restore' ? 'Program occurrence restored' : 'Occurrence updated');
        $res['occurrences'] = $occs;
        $res['occurrence'] = $occs[0] ?? null;
        return $res;
    }

    public static function detail(int $id, ?AuthContext $auth, bool $admin = false): array
    {
        $q = self::base($auth)->where('p.id', $id);
        if (! $admin) self::visibleTo($q, $auth);
        $p = $q->first();
        if (! $p || (! $admin && $p->status === 'draft')) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        if (! $admin && $auth?->accountType === 'user') Activity::track($auth->id, Activity::PROGRAM_VIEW, 'program', $id);
        $out = self::serialize($p);
        $out['page_id'] = Schema::hasTable('pages') ? DB::table('pages')->where(['program_id' => $id, 'status' => 'published'])->value('id') : null;
        if (! $admin && $auth && ! $auth->isSystem) $out['permission'] = Permissions::forProgram($p, $auth->id);
        if ($admin) $out['attendance_takers'] = self::takers($id);
        return $out;
    }

    /** The program's default attendance taker (a list of at most one; empty = none assigned yet). */
    public static function takers(int $id): array
    {
        if (! Schema::hasTable('program_attendance_takers')) return [];
        $rows = DB::table('program_attendance_takers as t')->join('users as u', 'u.id', '=', 't.user_id')->where('t.program_id', $id)
            ->orderBy('u.full_name')->get(['u.id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.profile_image']);
        return array_map(fn ($u) => ['id' => $u->id, 'full_name' => $u->full_name, 'member_id' => MemberIds::format($u->member_no, $u->member_group), 'avatar_url' => Storage::url($u->profile_image)], $rows->all());
    }

    /**
     * HR sets the program's ONE default taker (used by every occurrence HR does not assign
     * separately). The assignment itself authorises the person to record; an empty list clears it.
     */
    public static function setTakers(array $actx, int $id, array $userIds): array
    {
        if (! DB::table('programs')->where('id', $id)->exists()) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        $userIds = array_values(array_unique($userIds));
        if (count($userIds) > 1) throw ApiError::field('user_ids', 'ONE_TAKER_ONLY');
        foreach ($userIds as $uid) AttendanceSessions::assertTakerAccount((int) $uid);
        DB::transaction(function () use ($actx, $id, $userIds) {
            $before = DB::table('program_attendance_takers')->where('program_id', $id)->pluck('user_id')->all();
            DB::table('program_attendance_takers')->where('program_id', $id)->delete();
            if ($userIds) DB::table('program_attendance_takers')->insert(array_map(fn ($u) => ['program_id' => $id, 'user_id' => $u, 'added_by' => $actx['auth']->id], $userIds));
            Audit::log($actx, Audit::PROGRAM_UPDATE, 'program', $id, ['attendance_takers' => ['before' => $before, 'after' => $userIds]], inTrx: true);
        });
        return self::takers($id);
    }

    private static function assertDates(mixed $startsAt, mixed $endsAt): void
    {
        $s = Dates::of($startsAt);
        $e = Dates::of($endsAt);
        if ($e <= $s) throw ApiError::field('ends_at', 'END_BEFORE_START');
        if (Dates::ms($e) - Dates::ms($s) > 86400 * 1000) {
            throw ApiError::field('ends_at', 'MAX_ONE_DAY_DURATION');
        }
    }

    /** Normalise recurrence fields and check category / end date. $current = the stored row on update. */
    private static function recurrenceFields(array $input, array $current = []): array
    {
        $merged = array_merge($current, $input);
        $out = [];
        if (array_key_exists('category_id', $input)) {
            if ($input['category_id'] !== null && ! DB::table('program_categories')->where('id', $input['category_id'])->exists()) {
                throw ApiError::field('category_id', 'CATEGORY_NOT_FOUND');
            }
            $out['category_id'] = $input['category_id'];
        }
        $recurrence = $merged['recurrence'] ?? 'once';
        if (array_key_exists('recurrence', $input) || array_key_exists('monthly_rule', $input) || array_key_exists('recurrence_until', $input) || array_key_exists('ethiopian_days', $input) || array_key_exists('ordinal_weeks', $input) || array_key_exists('recurring_weekdays', $input)) {
            $out['recurrence'] = $recurrence;
            // Monthly and twice-a-month programs: on a day of the month, or on the nth weekday (1st & 3rd / 2nd & 4th).
            $out['monthly_rule'] = in_array($recurrence, ['monthly', 'twice_monthly'], true) ? ($merged['monthly_rule'] ?? 'day_of_month') : null;
            if (array_key_exists('ordinal_weeks', $input)) {
                $weeks = is_array($input['ordinal_weeks']) ? $input['ordinal_weeks'] : (is_string($input['ordinal_weeks']) ? explode(',', $input['ordinal_weeks']) : []);
                $weeks = array_values(array_unique(array_filter(array_map('intval', (array) $weeks), fn ($w) => $w >= 1 && $w <= 5)));
                sort($weeks);
                $out['ordinal_weeks'] = ! empty($weeks) ? implode(',', $weeks) : null;
            } elseif (array_key_exists('ordinal_weeks', $current)) {
                $out['ordinal_weeks'] = $current['ordinal_weeks'];
            }
            if (array_key_exists('recurring_weekdays', $input)) {
                $wds = is_array($input['recurring_weekdays']) ? $input['recurring_weekdays'] : (is_string($input['recurring_weekdays']) ? explode(',', $input['recurring_weekdays']) : []);
                $wds = array_values(array_unique(array_filter(array_map('intval', (array) $wds), fn ($w) => $w >= 0 && $w <= 6)));
                sort($wds);
                $out['recurring_weekdays'] = ! empty($wds) ? implode(',', $wds) : null;
            } elseif (array_key_exists('recurring_weekdays', $current)) {
                $out['recurring_weekdays'] = $current['recurring_weekdays'];
            }
            if ($recurrence === 'ethiopian_days') {
                $days = array_key_exists('ethiopian_days', $input) ? $input['ethiopian_days'] : (! empty($current['ethiopian_days']) ? array_map('intval', explode(',', $current['ethiopian_days'])) : null);
                if (! $days) throw ApiError::field('ethiopian_days', 'REQUIRED');
                $days = array_values(array_unique($days));
                sort($days);
                $out['ethiopian_days'] = implode(',', $days);
            } else {
                $out['ethiopian_days'] = null;
            }
            $out['recurrence_until'] = $recurrence === 'once' ? null : ($merged['recurrence_until'] ?? null);
            if ($out['recurrence_until'] !== null) $out['recurrence_until'] = Dates::toDateOnly($out['recurrence_until']);
            $until = $out['recurrence_until'];
            if ($until && $until < Dates::todayLocal(Dates::of($merged['starts_at']))) throw ApiError::field('recurrence_until', 'END_BEFORE_START');
        }
        return $out;
    }

    private static function defaultCategoryId(): ?int
    {
        return DB::table('program_categories')->where('is_active', true)->orderBy('display_order')->orderBy('id')->value('id');
    }

    /**
     * Tell the program's real audience (every active member, the selected member types, or the
     * invited / registered participants of a special event) about a change — in-app, push and email.
     * The actor is not notified of their own change.
     */
    private static function announce(int $id, string $event, int $actorId, array $params = [], ?string $key = null): int
    {
        $p = DB::table('programs')->where('id', $id)->first();
        if (! $p || $p->status === 'draft') return 0;
        $ids = array_values(array_filter(array_map('intval', \App\Mz\Jobs\ReminderJobs::recipients($p)->pluck('u.id')->all()), fn ($u) => $u !== $actorId));
        $when = Dates::of($p->starts_at);
        $y = (int) substr($p->starts_at, 0, 4);
        $m = (int) substr($p->starts_at, 5, 2);
        $d = (int) substr($p->starts_at, 8, 2);
        $eth = \App\Mz\Support\Ethiopian::toEthiopian($y, $m, $d);
        $monthNames = ['', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'];
        $ethDate = ($monthNames[$eth['month']] ?? '') . " {$eth['day']}፣ {$eth['year']} ዓ.ም";
        $categoryName = $p->category_id ? DB::table('program_categories')->where('id', $p->category_id)->value('name') : '';

        $params += [
            'title' => $p->title,
            'category' => $categoryName ?: '-',
            'ethiopian_date' => $ethDate,
            'when' => $when ? \App\Mz\Notifications\Mailer::when($when) : '',
            'location' => $p->location ?: '-',
        ];
        return Notifications::createForUsers($ids, [
            'type' => 'program',
            'title' => T::t("program.$event.title", $params),
            'body' => T::t("program.$event.body", $params),
            'entityType' => 'program',
            'entityId' => $id,
            'email' => true,
            'dedupeKey' => fn ($uid) => 'program:' . $id . ':' . ($key ?? $event) . ':' . $uid,
        ]);
    }

    private static function syncEducationLinks(array $actx, int $programId, array $input): void
    {
        $hasClasses = array_key_exists('class_ids', $input);
        $hasCourses = array_key_exists('course_ids', $input);

        // Auto-link class from schedule_id if class_ids was not explicitly provided
        if (! $hasClasses && ! empty($input['schedule_id']) && Schema::hasTable('edu_schedule')) {
            $schedClassId = DB::table('edu_schedule')->where('id', $input['schedule_id'])->value('class_id');
            if ($schedClassId) {
                $input['class_ids'] = [$schedClassId];
                $hasClasses = true;
            }
        }

        $p = DB::table('programs')->where('id', $programId)->first(['category_id']);
        $isEduCategory = false;
        if ($p && $p->category_id && Schema::hasTable('program_categories') && Schema::hasColumn('program_categories', 'is_education')) {
            $isEduCategory = (bool) DB::table('program_categories')->where('id', $p->category_id)->value('is_education');
        }

        // If category is not education and no explicit classes provided, clear any old education links
        if (! $isEduCategory && ! $hasClasses && ! $hasCourses && empty($input['schedule_id'])) {
            if (Schema::hasTable('program_edu_classes')) {
                DB::table('program_edu_classes')->where('program_id', $programId)->delete();
            }
            if (Schema::hasTable('program_edu_courses')) {
                DB::table('program_edu_courses')->where('program_id', $programId)->delete();
            }
            return;
        }

        if (! $hasClasses && ! $hasCourses) return;

        $auth = $actx['auth'];
        if (! $auth->isSystem && ! $auth->can('education.manage') && ! $auth->can('education.classes') && ! $auth->can('programs.manage') && ! ($auth->isAdmin && $auth->level >= 100)) {
            throw ApiError::forbidden('PERMISSION_DENIED', 'Education manage permission is required to link classes or courses');
        }

        if ($hasClasses && Schema::hasTable('program_edu_classes')) {
            $classIds = array_values(array_unique(array_filter(array_map('intval', (array) $input['class_ids']))));
            if ($classIds) {
                $activeCount = DB::table('edu_classes')->whereIn('id', $classIds)->where('status', 'active')->count();
                if ($activeCount !== count($classIds)) {
                    throw ApiError::conflict('CLASS_NOT_ACTIVE', 'One or more selected classes are not active');
                }
            }
            DB::table('program_edu_classes')->where('program_id', $programId)->delete();
            if ($classIds) {
                DB::table('program_edu_classes')->insert(array_map(fn ($cid) => [
                    'program_id' => $programId,
                    'class_id' => $cid,
                ], $classIds));
            }
            Audit::log($actx, Audit::PROGRAM_UPDATE, 'program', $programId, ['linked_classes' => $classIds], inTrx: true);
        }

        if ($hasCourses && Schema::hasTable('program_edu_courses')) {
            $courseIds = array_values(array_unique(array_filter(array_map('intval', (array) $input['course_ids']))));
            if ($courseIds) {
                $activeCount = DB::table('edu_courses as co')
                    ->join('edu_classes as c', 'c.id', '=', 'co.class_id')
                    ->whereIn('co.id', $courseIds)
                    ->where('c.status', 'active')
                    ->count();
                if ($activeCount !== count($courseIds)) {
                    throw ApiError::conflict('CLASS_NOT_ACTIVE', 'One or more selected courses belong to an inactive class');
                }
            }
            DB::table('program_edu_courses')->where('program_id', $programId)->delete();
            if ($courseIds) {
                DB::table('program_edu_courses')->insert(array_map(fn ($cid) => [
                    'program_id' => $programId,
                    'course_id' => $cid,
                ], $courseIds));
            }
            Audit::log($actx, Audit::PROGRAM_UPDATE, 'program', $programId, ['linked_courses' => $courseIds], inTrx: true);
        }
    }

    public static function create(array $actx, array $input): array
    {
        $end = self::endFields($input);
        $rec = self::recurrenceFields($input);
        $categoryId = array_key_exists('category_id', $rec) ? $rec['category_id'] : self::defaultCategoryId();
        $defaults = Settings::get('programs.reminder_defaults') ?? ['enabled' => true, 'days_before' => 1];
        // Reminder rules of the program type (category) come before the general defaults.
        $type = $categoryId ? DB::table('program_categories')->where('id', $categoryId)->first(['reminder_offsets', 'reminder_interval_days']) : null;
        if ($type?->reminder_offsets) $defaults['offsets'] = self::offsetsOf($type->reminder_offsets);
        $interval = array_key_exists('reminder_interval_days', $input) ? $input['reminder_interval_days'] : ($type?->reminder_interval_days ? (int) $type->reminder_interval_days : null);
        $isMandatory = ! empty($input['is_mandatory_reminder']) || ! empty($input['reminders_enforce']);
        if ($isMandatory) {
            $auth = $actx['auth'];
            if (! $auth->isSystem && ! $auth->can('programs.reminders_enforce') && ! ($auth->isAdmin && $auth->level >= 100)) {
                throw ApiError::forbidden('UNAUTHORIZED_REMINDER_ENFORCE', 'Only authorized administrators with programs.reminders_enforce permission can enforce mandatory reminder policies.');
            }
        }
        $id = DB::transaction(function () use ($actx, $input, $rec, $categoryId, $defaults, $end, $isMandatory, $interval) {
            $groups = ! empty($input['member_groups']) ? implode(',', array_values(array_unique($input['member_groups']))) : null;
            $row = [
                'title' => $input['title'],
                'description' => $input['description'] ?? null,
                'location' => $input['location'] ?? null,
                'starts_at' => $input['starts_at'],
                'ends_at' => $end['ends_at'],
                'has_end_time' => $end['has_end_time'],
                'reminder_offsets' => self::offsetsCsv($input['reminder_offsets'] ?? ($defaults['offsets'] ?? [1440, 60])),
                'requires_registration' => $input['requires_registration'] ?? false,
                'requires_attendance' => $input['requires_attendance'] ?? true,
                'capacity' => $input['capacity'] ?? null,
                'audience' => $input['audience'] ?? 'all',
                'event_type' => ($input['audience'] ?? null) === 'participants' ? ($input['event_type'] ?? null) : null,
                'status' => $input['status'] ?? 'draft',
                'reminder_enabled' => $input['reminder_enabled'] ?? $defaults['enabled'],
                'reminder_days_before' => $input['reminder_days_before'] ?? $defaults['days_before'],
                'is_mandatory_reminder' => $isMandatory,
                'reminder_interval_days' => $interval,
                'reminder_interval_start' => $interval ? ($input['reminder_interval_start'] ?? self::intervalStart($input['starts_at'])) : null,
                'reminder_title' => $input['reminder_title'] ?? null,
                'reminder_body' => $input['reminder_body'] ?? null,
                'recurrence' => $rec['recurrence'] ?? 'once',
                'monthly_rule' => $rec['monthly_rule'] ?? null,
                'recurrence_until' => $rec['recurrence_until'] ?? null,
                'ethiopian_days' => $rec['ethiopian_days'] ?? null,
                'is_additional' => $input['is_additional'] ?? false,
                'counts_for_selection' => $input['counts_for_selection'] ?? true,
                'category_id' => $categoryId,
                'member_groups' => $groups,
                'schedule_id' => $input['schedule_id'] ?? null,
                'created_by' => $actx['auth']->id,
                'updated_by' => $actx['auth']->id,
            ];
            if (Schema::hasColumn('programs', 'ordinal_weeks')) {
                $row['ordinal_weeks'] = $rec['ordinal_weeks'] ?? null;
            }
            if (Schema::hasColumn('programs', 'recurring_weekdays')) {
                $row['recurring_weekdays'] = $rec['recurring_weekdays'] ?? null;
            }
            $newId = DB::table('programs')->insertGetId($row);
            self::syncEducationLinks($actx, $newId, $input);
            Audit::log($actx, Audit::PROGRAM_CREATE, 'program', $newId, ['title' => $input['title']], inTrx: true);
            return $newId;
        });
        // A program published right away is announced to its audience (a draft waits for publishing).
        if (($input['status'] ?? 'draft') === 'published') self::announce($id, 'created', $actx['auth']->id, [], 'published');
        return self::detail($id, $actx['auth'], true);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $event = null;
        DB::transaction(function () use ($actx, $id, $input, &$event) {
            $p = DB::table('programs')->where('id', $id)->lockForUpdate()->first();
            if (! $p) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
            $patch = array_merge(array_intersect_key($input, array_flip(self::UPDATABLE)), self::recurrenceFields($input, (array) $p));
            if (array_key_exists('ends_at', $input) || array_key_exists('starts_at', $input)) $patch = array_merge($patch, self::endFields($input, $p));
            if (array_key_exists('reminder_offsets', $input)) $patch['reminder_offsets'] = self::offsetsCsv($input['reminder_offsets']);
            if (array_key_exists('reminder_interval_days', $input)) {
                // Switching the repeat on without a start date counts from the program start (or today).
                if ($input['reminder_interval_days'] && ! ($input['reminder_interval_start'] ?? null) && ! $p->reminder_interval_start) {
                    $patch['reminder_interval_start'] = self::intervalStart($input['starts_at'] ?? $p->starts_at);
                }
                if (! $input['reminder_interval_days']) $patch['reminder_interval_start'] = null;
            }
            if (array_key_exists('member_groups', $input)) $patch['member_groups'] = $input['member_groups'] ? implode(',', array_values(array_unique($input['member_groups']))) : null;
            if (array_key_exists('is_mandatory_reminder', $input) || array_key_exists('reminders_enforce', $input)) {
                $enforceVal = ! empty($input['is_mandatory_reminder']) || ! empty($input['reminders_enforce']);
                if ($enforceVal !== (bool) ($p->is_mandatory_reminder ?? false)) {
                    $auth = $actx['auth'];
                    if (! $auth->isSystem && ! $auth->can('programs.reminders_enforce') && ! ($auth->isAdmin && $auth->level >= 100)) {
                        throw ApiError::forbidden('UNAUTHORIZED_REMINDER_ENFORCE', 'Only authorized administrators with programs.reminders_enforce permission can enforce mandatory reminder policies.');
                    }
                    $patch['is_mandatory_reminder'] = $enforceVal;
                }
            }
            $patch['updated_by'] = $actx['auth']->id;
            if (! Schema::hasColumn('programs', 'ordinal_weeks')) {
                unset($patch['ordinal_weeks']);
            }
            if (! Schema::hasColumn('programs', 'recurring_weekdays')) {
                unset($patch['recurring_weekdays']);
            }
            DB::table('programs')->where('id', $id)->update($patch);
            self::syncEducationLinks($actx, $id, $input);
            // A one-day program moved to another day keeps its attendance and permission requests.
            $after = array_merge((array) $p, $patch);
            if (($after['recurrence'] ?? 'once') === 'once' && isset($patch['starts_at'])) {
                $from = Dates::localDateOf($p->starts_at);
                $to = Dates::localDateOf($after['starts_at']);
                if ($from !== $to) {
                    foreach (['attendance', 'permission_requests'] as $table) {
                        DB::table($table)->where(['program_id' => $id, 'occurrence_date' => $from])->update(['occurrence_date' => $to]);
                    }
                }
            }
            $action = ($input['status'] ?? null) === 'cancelled' && $p->status !== 'cancelled' ? Audit::PROGRAM_CANCEL : Audit::PROGRAM_UPDATE;
            Audit::log($actx, $action, 'program', $id, ['fields' => array_keys($patch)], inTrx: true);
            if ($action === Audit::PROGRAM_CANCEL) {
                $event = 'cancelled';
            } elseif (($input['status'] ?? null) === 'published' && $p->status === 'draft') {
                $event = 'created';
            } elseif ($p->status === 'published' && ($after['status'] ?? 'published') === 'published') {
                // Members only hear about changes that affect them: time, place or schedule.
                foreach (['starts_at', 'ends_at', 'location', 'recurrence', 'monthly_rule', 'ethiopian_days', 'recurrence_until'] as $f) {
                    $norm = fn ($v) => $v instanceof \DateTimeInterface || (is_string($v) && preg_match('/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/', $v)) ? Dates::sql(Dates::of($v)) : (string) $v;
                    if (array_key_exists($f, $patch) && $norm($patch[$f]) !== $norm($p->{$f})) {
                        $event = 'changed';
                        break;
                    }
                }
            }
        });
        // After the commit, to the audience of the saved program.
        if ($event === 'cancelled') {
            self::announce($id, 'cancelled', $actx['auth']->id);
        } elseif ($event === 'created') {
            self::announce($id, 'created', $actx['auth']->id, [], 'published');
        } elseif ($event === 'changed') {
            self::announce($id, 'changed', $actx['auth']->id, [], 'changed:' . \App\Mz\Projects\Pm::stamp());
        }
        return self::detail($id, $actx['auth'], true);
    }

    /** A member's own reminders for one program (null = follow the program's reminders). */
    public static function setMyReminders(AuthContext $auth, int $id, ?array $offsets): array
    {
        $prg = self::detail($id, $auth); // visible to this member
        if (! empty($prg['is_mandatory_reminder'])) {
            if ($offsets === null || empty($offsets)) {
                throw ApiError::forbidden('MANDATORY_REMINDER_ENFORCED', 'This program has mandatory reminders enforced by administration and cannot be disabled.');
            }
        }
        if ($offsets === null) {
            DB::table('program_reminder_choices')->where(['user_id' => $auth->id, 'program_id' => $id])->delete();
        } else {
            DB::table('program_reminder_choices')->upsert([['user_id' => $auth->id, 'program_id' => $id, 'offsets' => self::offsetsCsv($offsets)]], ['user_id', 'program_id'], ['offsets']);
        }
        return self::detail($id, $auth);
    }

    public static function setImage(array $actx, int $id, UploadedFile $file): array
    {
        $p = DB::table('programs')->where('id', $id)->first(['id', 'image']);
        if (! $p) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        $saved = Storage::save('image', Storage::FOLDERS['PROGRAM_IMAGES'], $file);
        DB::table('programs')->where('id', $id)->update(['image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::PROGRAM_UPDATE, 'program', $id, ['image' => 'replaced']);
        Storage::remove($p->image);
        return self::detail($id, $actx['auth'], true);
    }

    /** Delete a program if attendance has not started and no attendance records exist. */
    public static function delete(array $actx, int $id): void
    {
        $p = DB::table('programs')->where('id', $id)->first();
        if (! $p) throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');

        $hasAttendance = DB::table('attendance')->where('program_id', $id)->exists()
            || DB::table('attendance_closures')->where('program_id', $id)->exists()
            || DB::table('attendance_corrections')->where('program_id', $id)->exists();

        $now = Dates::now();
        $hasStarted = false;
        if ($p->starts_at && strtotime($p->starts_at) <= $now->getTimestamp()) {
            $hasStarted = true;
        }
        if (! $hasStarted && DB::table('program_occurrence_overrides')->where('program_id', $id)->where('starts_at', '<=', Dates::sql($now))->exists()) {
            $hasStarted = true;
        }

        if ($hasAttendance || $hasStarted) {
            Audit::log($actx, Audit::PROGRAM_UPDATE, 'program', $id, [
                'op' => 'delete_rejected',
                'reason' => $hasAttendance ? 'attendance_recorded' : 'already_started',
            ]);
            throw ApiError::conflict(
                'CANNOT_DELETE_PROGRAM',
                $hasAttendance
                    ? 'Cannot delete program: attendance records already exist.'
                    : 'Cannot delete program: the program occurrence has already started.'
            );
        }

        DB::transaction(function () use ($actx, $id, $p) {
            DB::table('program_participants')->where('program_id', $id)->delete();
            DB::table('program_reminder_choices')->where('program_id', $id)->delete();
            DB::table('program_occurrence_overrides')->where('program_id', $id)->delete();
            DB::table('program_attendance_takers')->where('program_id', $id)->delete();
            DB::table('reminders')->where('program_id', $id)->delete();
            if (! empty($p->image)) {
                Storage::remove($p->image);
            }
            DB::table('programs')->where('id', $id)->delete();
            Audit::log($actx, Audit::PROGRAM_DELETE, 'program', $id, ['title' => $p->title], inTrx: true);
        });
    }

    // ------------------------------------------------------------------ participants
    public static function participants(int $id, array $filter, array $page): array
    {
        $qb = DB::table('program_participants as pp')->join('users as u', 'u.id', '=', 'pp.user_id')->where('pp.program_id', $id)
            ->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'pp.status', 'pp.source', 'pp.created_at',
                DB::raw('(SELECT a.status FROM attendance a WHERE a.program_id = pp.program_id AND a.user_id = pp.user_id ORDER BY a.occurrence_date DESC LIMIT 1) as attendance_status'),
                DB::raw('(SELECT a.attended_at FROM attendance a WHERE a.program_id = pp.program_id AND a.user_id = pp.user_id ORDER BY a.occurrence_date DESC LIMIT 1) as attended_at'))
            ->orderBy('u.full_name');
        if (! empty($filter['status'])) $qb->where('pp.status', $filter['status']);
        else $qb->where('pp.status', '<>', 'cancelled');
        MemberIds::search($qb, $filter['q'] ?? null);
        $res = Page::paginate($qb, $page);
        $res['items'] = MemberIds::decorate($res['items']);
        return $res;
    }

    /** Bulk-invite (one transaction); only members of the program's target groups are added. */
    public static function bulkAddParticipants(array $actx, int $id, array $in, bool $allowAll): array
    {
        $target = $in['target'];
        $status = $in['status'] ?? 'invited';
        $notify = $in['notify'] ?? true;
        $result = DB::transaction(function () use ($actx, $id, $target, $status, $notify, $allowAll) {
            $p = DB::table('programs')->where('id', $id)->lockForUpdate()->first();
            if (! $p || $p->status === 'cancelled') throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
            if (! empty($target['user_ids'])) {
                $exclude = $target['exclude_ids'] ?? [];
                $ids = MemberIds::memberAccounts(DB::table('users as u'))->where('u.status', 'active')->whereIn('u.id', array_values(array_filter($target['user_ids'], fn ($x) => ! in_array($x, $exclude, true))))->pluck('u.id')->all();
            } else {
                $ids = Targeting::resolve($target, $allowAll);
            }
            $groups = $p->member_groups ? array_values(array_filter(explode(',', $p->member_groups))) : [];
            $before = count($ids);
            if ($groups && $ids) $ids = DB::table('users')->whereIn('id', $ids)->whereIn('member_group', $groups)->pluck('id')->all();
            $skipped = $before - count($ids);
            if (! $ids) return ['added' => 0, 'notified' => 0, 'skipped' => $skipped];
            foreach (array_chunk($ids, 1000) as $chunk) {
                $rows = array_map(fn ($uid) => ['program_id' => $id, 'user_id' => $uid, 'status' => $status, 'source' => 'admin', 'added_by' => $actx['auth']->id], $chunk);
                // Never downgrade a registered participant back to invited.
                DB::table('program_participants')->upsert($rows, ['program_id', 'user_id'], ['status' => DB::raw("IF(status = 'registered', 'registered', VALUES(status))"), 'added_by' => $actx['auth']->id]);
            }
            $notified = 0;
            if ($notify) {
                $notified = Notifications::createForUsers($ids, [
                    'type' => 'program',
                    'title' => T::t('program.invited.title'),
                    'body' => T::t('program.invited.body', ['title' => $p->title]),
                    'entityType' => 'program',
                    'entityId' => $id,
                    'email' => true,
                    'dedupeKey' => fn ($uid) => "program:$id:invited:$uid",
                ]);
            }
            Audit::log($actx, Audit::PROGRAM_PARTICIPANTS, 'program', $id, ['op' => 'bulk_add', 'count' => count($ids), 'status' => $status, 'notify' => $notify], inTrx: true);
            return ['added' => count($ids), 'notified' => $notified, 'skipped' => $skipped];
        });
        if ($result['notified']) Notifications::kick();
        return $result;
    }

    public static function removeParticipant(array $actx, int $id, int $userId): void
    {
        $n = DB::table('program_participants')->where(['program_id' => $id, 'user_id' => $userId])->update(['status' => 'cancelled']);
        if (! $n) throw ApiError::notFound('PARTICIPANT_NOT_FOUND', 'Participant not found');
        Audit::log($actx, Audit::PROGRAM_PARTICIPANTS, 'program', $id, ['op' => 'remove', 'user_id' => $userId]);
    }

    // ------------------------------------------------------------------ program categories
    public static function categories(bool $all = false): array
    {
        $q = DB::table('program_categories')->orderBy('display_order')->orderBy('id');
        if (! $all) $q->where('is_active', true);
        $cols = ['id', 'name', 'name_en', 'color', 'display_order', 'is_active', 'reminder_offsets', 'reminder_interval_days'];
        if (Schema::hasColumn('program_categories', 'is_education')) {
            $cols[] = 'is_education';
        }
        return $q->select($cols)->get()->map(fn ($c) => self::serializeCategory($c))->all();
    }

    private static function serializeCategory(object $c): object
    {
        $c->is_active = (bool) $c->is_active;
        $c->is_education = (bool) ($c->is_education ?? false);
        $c->reminder_offsets = $c->reminder_offsets ? self::offsetsOf($c->reminder_offsets) : null;
        $c->reminder_interval_days = $c->reminder_interval_days !== null ? (int) $c->reminder_interval_days : null;
        return $c;
    }

    private static function categoryRow(array $input): array
    {
        if (array_key_exists('reminder_offsets', $input)) $input['reminder_offsets'] = $input['reminder_offsets'] ? self::offsetsCsv($input['reminder_offsets']) : null;
        if (array_key_exists('is_education', $input)) $input['is_education'] = (bool) $input['is_education'];
        return $input;
    }

    public static function createCategory(array $actx, array $input): object
    {
        $input = self::categoryRow($input);
        $id = DB::table('program_categories')->insertGetId([
            'name' => $input['name'],
            'name_en' => $input['name_en'] ?? null,
            'color' => $input['color'] ?? '#8A7A7D',
            'display_order' => $input['display_order'] ?? 0,
            'is_active' => $input['is_active'] ?? true,
            'is_education' => ! empty($input['is_education']),
            'reminder_offsets' => $input['reminder_offsets'] ?? null,
            'reminder_interval_days' => $input['reminder_interval_days'] ?? null,
            'created_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::PROGRAM_CATEGORY, 'program_category', $id, ['op' => 'create', 'name' => $input['name']]);
        return self::serializeCategory(DB::table('program_categories')->where('id', $id)->first());
    }

    public static function updateCategory(array $actx, int $id, array $input): object
    {
        if (! DB::table('program_categories')->where('id', $id)->exists()) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        $input = self::categoryRow($input);
        if ($input) DB::table('program_categories')->where('id', $id)->update($input);
        Audit::log($actx, Audit::PROGRAM_CATEGORY, 'program_category', $id, ['op' => 'update', 'fields' => array_keys($input)]);
        return self::serializeCategory(DB::table('program_categories')->where('id', $id)->first());
    }

    public static function deleteCategory(array $actx, int $id): array
    {
        if (! DB::table('program_categories')->where('id', $id)->exists()) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        $used = DB::table('programs')->where('category_id', $id)->exists();
        if ($used) DB::table('program_categories')->where('id', $id)->update(['is_active' => false]);
        else DB::table('program_categories')->where('id', $id)->delete();
        Audit::log($actx, Audit::PROGRAM_CATEGORY, 'program_category', $id, ['op' => $used ? 'deactivate' : 'delete']);
        return ['deleted' => ! $used, 'deactivated' => $used];
    }
}
