// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/ethiopian_date_picker.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import '../admin/report_export.dart';
import '../../widgets/typed_picker.dart';
import '../guidance/contextual_help_sheet.dart';
import '../auth/session.dart' show currentUserProvider;
import 'edu_academics.dart';
import 'edu_formatters.dart';
import 'learn/edu_home.dart' show CanonicalCategoriesSection;
import 'learn/quiz_screens.dart' show CourseQuizzesTab;

// =============================================================================
// Shared bits
// =============================================================================
String weekdayName(AppLocalizations l, int wd) => [
  l.weekday1,
  l.weekday2,
  l.weekday3,
  l.weekday4,
  l.weekday5,
  l.weekday6,
  l.weekday7,
][(wd - 1).clamp(0, 6)];

String eduWeekOfMonthLabel(AppLocalizations l, int w) => switch (w) {
  1 => l.eduWeek1,
  2 => l.eduWeek2,
  3 => l.eduWeek3,
  4 => l.eduWeek4,
  _ => l.eduWeekLast,
};

/// "Saturday" or "2nd Saturday of the month".
String eduScheduleDayText(AppLocalizations l, Json s) {
  final day = weekdayName(l, asIntOr(s['weekday']));
  return s['frequency'] == 'monthly'
      ? l.eduMonthlyDay(
          eduWeekOfMonthLabel(l, asIntOr(s['week_of_month'], 1)),
          day,
        )
      : day;
}

String programLabel(AppLocalizations l, String? p) =>
    p == 'distance' ? l.programDistance : l.programRegular;

String attendanceStatusLabel(AppLocalizations l, String? s) => switch (s) {
  'present' => l.attPresent,
  'late' => l.attLate,
  'absent' => l.attAbsent,
  'excused' => l.attExcused,
  _ => l.notMarked,
};

Color attendanceStatusColor(String? s) => switch (s) {
  'present' => AppColors.success,
  'late' => AppColors.warning,
  'absent' => AppColors.danger,
  'excused' => AppColors.goldDark,
  _ => AppColors.faint,
};

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _score(Object? v) {
  final n = asDouble(v);
  if (v == null) return null;
  return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
}

Future<void> _openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

final eduOverviewProvider = FutureProvider.autoDispose<Json>(
  (ref) => ref.watch(eduRepositoryProvider).overview(),
);

// =============================================================================
// ትምህርት → Classes tab: registration, upcoming sessions, my classes, teaching, attendance
// (the former ትምህርት home; requests, the review center and the library are under More)
// =============================================================================
class EduClassesScreen extends ConsumerWidget {
  const EduClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final canPop = Navigator.of(context).canPop();
    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final isClassTabRoot = currentPath == '/edu/class' || currentPath == '/edu/classes';

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (canPop) {
          Navigator.of(context).pop();
        } else {
          context.go('/edu');
        }
      },
      child: PatternScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: (canPop && !isClassTabRoot)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(l.elClass),
          actions: const [ContextualHelpButton(screenRoute: '/edu/classes')],
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async => ref.invalidate(eduOverviewProvider),
          child: AsyncView(
            value: ref.watch(eduOverviewProvider),
            onRetry: () => ref.invalidate(eduOverviewProvider),
            data: (d) {
              final classes = asJsonList(d['classes']);
              final teaching = asJsonList(d['teaching']);
              final sessions = asJsonList(d['next_sessions']);
              final open = asIntOr(d['open_registration']);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. Quick access actions: Assignments and Class Stream
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          onTap: () => context.push('/edu/assignments'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.maroon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment_outlined, color: AppColors.maroon, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.elAssignments, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(l.isEn ? 'Tasks & quizzes' : 'ሥራዎችና ፈተናዎች', style: context.sans(10.5, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppCard(
                          onTap: () => context.push('/edu/announcements'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.campaign_outlined, color: AppColors.goldDark, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.elClassFeed, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(l.isEn ? 'Stream & notes' : 'የክፍል መልእክቶች', style: context.sans(10.5, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Registration banner (if registration open)
                  if (open > 0) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      onTap: () async {
                        await context.push('/edu/register');
                        ref.invalidate(eduOverviewProvider);
                      },
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.how_to_reg_rounded,
                            color: AppColors.gold,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.eduRegister,
                                  style: context.sans(15, weight: FontWeight.w700),
                                ),
                                Text(
                                  l.eduOpenCount(open),
                                  style: context.sans(12, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: p.faint),
                        ],
                      ),
                    ),
                  ],

                  // 3. My Classes section
                  const SizedBox(height: 10),
                  SectionHeader(title: l.myClasses),
                  if (classes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l.eduNotEnrolled,
                        style: context.sans(13, color: p.muted),
                      ),
                    )
                  else
                    for (final c in classes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => context.push('/edu/class/${c['id']}'),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.maroon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
                                ),
                                child: const Icon(Icons.school_rounded, color: AppColors.maroon, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eduClassName(c),
                                      style: context.serif(15, weight: FontWeight.w700),
                                    ),
                                    if (eduClassSubtitle(c, l).isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        eduClassSubtitle(c, l),
                                        style: context.sans(12, color: p.muted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.gold),
                            ],
                          ),
                        ),
                      ),

                  // 4. Teaching / Instructor Section (for assigned teachers)
                  if (teaching.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SectionHeader(title: l.eduTeaching),
                    for (final c in teaching)
                      TrackTile(
                        title: '${c['name']}',
                        subtitle:
                            '${c['class_name']} · ${l.eduStudentCount(asIntOr(c['student_count']))}',
                        leading: const ListThumb(icon: Icons.co_present_rounded),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/edu/course/${c['id']}'),
                      ),
                  ],

                  // 5. Upcoming Sessions / Timetable
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SectionHeader(title: l.eduUpcoming),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final s in sessions.take(6))
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.event_note_rounded,
                                color: AppColors.gold,
                              ),
                              title: Text(
                                [
                                  asStr(s['class_name']),
                                  if (asStr(s['course_name']) != null)
                                    asStr(s['course_name']),
                                ].whereType<String>().join(' · '),
                              ),
                              subtitle: Text(
                                [
                                  f.date(
                                    DateTime.tryParse('${s['date']}'),
                                    withWeekday: true,
                                  ),
                                  '${s['starts']}–${s['ends']}',
                                  if (asStr(s['location']) != null)
                                    asStr(s['location'])!,
                                ].join(' · '),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // 6. Canonical 7 Curriculum Categories (with 12 Grades)
                  const SizedBox(height: 14),
                  CanonicalCategoriesSection(
                    refresh: () => ref.invalidate(eduOverviewProvider),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Registration
// =============================================================================
final _openClassesProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(eduRepositoryProvider).openClasses(),
);

class EduRegisterScreen extends ConsumerWidget {
  const EduRegisterScreen({super.key});

  Future<void> _enroll(BuildContext context, WidgetRef ref, Json c) async {
    final l = context.l10n;
    final options = [
      if (c['allow_regular'] == true) 'regular',
      if (c['allow_distance'] == true) 'distance',
    ];
    final program = options.length == 1
        ? options.first
        : await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.eduChooseProgram, style: ctx.serif(18)),
                  ),
                  for (final o in options)
                    ListTile(
                      leading: Icon(
                        o == 'distance'
                            ? Icons.wifi_rounded
                            : Icons.meeting_room_rounded,
                        color: AppColors.gold,
                      ),
                      title: Text(programLabel(l, o)),
                      onTap: () => Navigator.pop(ctx, o),
                    ),
                ],
              ),
            ),
          );
    if (program == null || !context.mounted) return;
    final ok = await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).enroll(asIntOr(c['id']), program),
      success: l.eduEnrolled,
    );
    if (ok != null) {
      ref.invalidate(_openClassesProvider);
      ref.invalidate(eduOverviewProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PatternScaffold(
      appBar: AppBar(title: Text(l.eduRegister)),
      body: AsyncView(
        value: ref.watch(_openClassesProvider),
        onRetry: () => ref.invalidate(_openClassesProvider),
        data: (list) => list.isEmpty
            ? EmptyView(message: l.eduNoOpen, icon: Icons.school_outlined)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${c['name']}', style: context.serif(18)),
                            if (asStr(c['term']) != null)
                              Text(
                                asStr(c['term'])!,
                                style: context.sans(12, color: p.muted),
                              ),
                            if (asStr(c['description']) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  asStr(c['description'])!,
                                  style: context.sans(13),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (c['allow_regular'] == true)
                                  Pill(l.programRegular),
                                if (c['allow_distance'] == true)
                                  Pill(l.programDistance),
                                if (c['capacity'] != null)
                                  Pill(
                                    l.eduSeats(
                                      asIntOr(c['student_count']),
                                      asIntOr(c['capacity']),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c['registration'] == 'upcoming'
                                  ? l.eduOpensOn(
                                      f.dateTime(
                                        asDate(c['registration_opens_at']),
                                      ),
                                    )
                                  : (c['registration_closes_at'] != null
                                        ? l.eduClosesOn(
                                            f.dateTime(
                                              asDate(
                                                c['registration_closes_at'],
                                              ),
                                            ),
                                          )
                                        : l.eduOpenNow),
                              style: context.sans(12, color: p.muted),
                            ),
                            const SizedBox(height: 10),
                            if (c['my_program'] != null)
                              Pill(
                                l.eduYouAreEnrolled(
                                  programLabel(l, asStr(c['my_program'])),
                                ),
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                              )
                            else if (c['allow_self_registration'] != true)
                              Pill(
                                l.isEn
                                    ? 'Registration by Administrator Only'
                                    : 'ምደባ በአስተዳዳሪ ብቻ',
                                icon: Icons.lock_outline_rounded,
                                color: p.muted,
                              )
                            else
                              FilledButton(
                                onPressed: c['registration'] == 'open'
                                    ? () => _enroll(context, ref, c)
                                    : null,
                                child: Text(l.eduEnroll),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// A class (student view; teachers and attendance takers see the details)
// =============================================================================
final _classProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(eduRepositoryProvider).classDetail(id),
);

class EduClassScreen extends ConsumerWidget {
  const EduClassScreen({super.key, required this.classId, this.initialTab});
  final int classId;

  /// 'assignments' / 'results' / 'attendance' open that tab (e.g. from an internal page's button).
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(_classProvider(classId));
    final c = async.value;
    final enrolled = c?['my_program'] != null;
    // Takes subjects of this class added from another class: their work and results, no class attendance.
    final addedOnly = !enrolled && c?['has_added_subjects'] == true;
    return DefaultTabController(
      // Rebuilt once the class is loaded so the requested tab can be the first one shown.
      key: ValueKey('$enrolled|$addedOnly'),
      length: enrolled ? 4 : (addedOnly ? 3 : 1),
      initialIndex: enrolled
          ? switch (initialTab) {
              'attendance' => 1,
              'assignments' => 2,
              'results' => 3,
              _ => 0,
            }
          : (addedOnly
                ? switch (initialTab) {
                    'assignments' => 1,
                    'results' => 2,
                    _ => 0,
                  }
                : 0),
      child: PatternScaffold(
        appBar: AppBar(
          title: Text(eduClassName(c).isNotEmpty ? eduClassName(c) : l.elClass),
          actions: [
            if (enrolled && c?['registration'] == 'open')
              PopupMenuButton<String>(
                onSelected: (_) async {
                  if (!await showConfirm(
                        context,
                        l.eduWithdrawConfirm,
                        destructive: true,
                      ) ||
                      !context.mounted)
                    return;
                  final ok = await runWithProgress(context, () async {
                    await ref.read(eduRepositoryProvider).withdraw(classId);
                    return true;
                  });
                  if (ok == true && context.mounted) {
                    ref.invalidate(eduOverviewProvider);
                    context.pop();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'withdraw', child: Text(l.eduWithdraw)),
                ],
              ),
          ],
          bottom: enrolled || addedOnly
              ? TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: l.eduDetails),
                    if (enrolled) Tab(text: l.attendance),
                    Tab(text: l.eduAssignments),
                    Tab(text: l.eduResults),
                  ],
                )
              : null,
        ),
        body: AsyncView(
          value: async,
          onRetry: () => ref.invalidate(_classProvider(classId)),
          data: (c) => TabBarView(
            children: [
              _ClassDetails(c: c),
              if (enrolled) ...[
                _MyAttendanceTab(classId: classId),
                _MyAssignmentsTab(classId: classId),
                _MyResultsTab(classId: classId),
              ],
              if (addedOnly) ...[
                _MyAssignmentsTab(classId: classId),
                _MyResultsTab(classId: classId),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassDetails extends StatelessWidget {
  const _ClassDetails({required this.c});
  final Json c;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final courses = asJsonList(c['courses']);
    final schedule = asJsonList(c['schedule']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eduClassName(c),
                style: context.serif(18, weight: FontWeight.w700, color: AppColors.eduBurgundy),
              ),
              if (eduClassSubtitle(c, l).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  eduClassSubtitle(c, l),
                  style: context.sans(12.5, color: p.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (c['my_program'] != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              programLabel(l, asStr(c['my_program'])),
              icon: Icons.badge_rounded,
            ),
          ),
        if (asStr(c['description']) != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              asStr(c['description'])!,
              style: context.sans(14, height: 1.6),
            ),
          ),
        SectionHeader(title: l.eduSchedule),
        if (schedule.isEmpty)
          Text(l.eduNoSchedule, style: context.sans(13, color: p.muted)),
        for (final s in schedule)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: p.pill,
              child: Text(
                weekdayName(
                  l,
                  asIntOr(s['weekday']),
                ).characters.take(2).toString(),
                style: context.sans(12, weight: FontWeight.w700),
              ),
            ),
            title: Text(
              '${eduScheduleDayText(l, s)} · ${s['starts']}–${s['ends']}',
            ),
            subtitle: Text(
              [
                if (asStr(s['course_name']) != null) asStr(s['course_name'])!,
                if (s['mode'] == 'online') l.eduOnline,
                if (asStr(s['location']) != null) asStr(s['location'])!,
              ].join(' · '),
            ),
          ),
        SectionHeader(title: l.eduCourses),
        for (final co in courses)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
            title: Text('${co['name']}'),
            subtitle: Text(
              asStr(asJson(co['teacher'])['full_name']) ?? l.eduNoTeacher,
            ),
          ),
        if (c['my_attendance'] != null) ...[
          SectionHeader(title: l.attendance),
          Text(
            asJson(c['my_attendance'])['rate'] == null
                ? l.eduNoAttendanceYet
                : l.attendanceRate('${asJson(c['my_attendance'])['rate']}'),
            style: context.sans(13, color: p.muted),
          ),
        ],
      ],
    );
  }
}

class _MyAttendanceTab extends ConsumerWidget {
  const _MyAttendanceTab({required this.classId});
  final int classId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return FutureBuilder<Json>(
      future: ref.read(eduRepositoryProvider).myAttendance(classId),
      builder: (context, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? ErrorView(error: snap.error!)
              : const LoadingView();
        final sum = asJson(snap.data!['summary']);
        final sessions = asJsonList(snap.data!['sessions']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            MaroonCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final k in ['present', 'absent', 'excused'])
                    Column(
                      children: [
                        Text(
                          '${asIntOr(sum[k])}',
                          style: context.serif(22, color: Colors.white),
                        ),
                        Text(
                          attendanceStatusLabel(l, k),
                          style: context.sans(11, color: AppColors.goldLight),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (sum['rate'] != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  l.attendanceRate('${sum['rate']}'),
                  textAlign: TextAlign.center,
                ),
              ),
            if (sessions.isEmpty)
              EmptyView(
                message: l.eduNoAttendanceYet,
                icon: Icons.event_busy_outlined,
              ),
            for (final s in sessions)
              ListTile(
                title: Text(
                  f.date(
                    DateTime.tryParse('${s['session_date']}'),
                    withWeekday: true,
                  ),
                ),
                trailing: Pill(
                  attendanceStatusLabel(l, asStr(s['status'])),
                  color: attendanceStatusColor(asStr(s['status'])),
                ),
                leading: Icon(
                  s['via'] == 'qr'
                      ? Icons.qr_code_rounded
                      : Icons.edit_note_rounded,
                  color: AppColors.gold,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyAssignmentsTab extends ConsumerStatefulWidget {
  const _MyAssignmentsTab({required this.classId});
  final int classId;
  @override
  ConsumerState<_MyAssignmentsTab> createState() => _MyAssignmentsTabState();
}

class _MyAssignmentsTabState extends ConsumerState<_MyAssignmentsTab> {
  late Future<List<Json>> _future = ref
      .read(eduRepositoryProvider)
      .myAssignments(widget.classId);
  void _reload() => setState(
    () =>
        _future = ref.read(eduRepositoryProvider).myAssignments(widget.classId),
  );

  Future<void> _submit(Json a) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _SubmitSheet(assignment: a),
      ),
    );
    if (done == true) _reload();
  }

  Future<void> _showVersions(int submissionId) async {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.eduVersions, style: context.serif(18)),
              const SizedBox(height: 12),
              FutureBuilder<List<Json>>(
                future: ref
                    .read(eduRepositoryProvider)
                    .submissionVersions(submissionId),
                builder: (ctx, snap) {
                  if (!snap.hasData)
                    return snap.hasError
                        ? ErrorView(error: snap.error!)
                        : const LoadingView();
                  final versions = snap.data!;
                  if (versions.isEmpty)
                    return EmptyView(
                      message: l.eduNoSubmissions,
                      icon: Icons.history_rounded,
                    );
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: versions.length,
                      separatorBuilder: (_, i) => const Divider(height: 16),
                      itemBuilder: (ctx, i) {
                        final v = versions[i];
                        final subDate = asDate(v['submitted_at']);
                        final isLate = asBool(v['is_late']);
                        final fileName =
                            asStr(v['file_name']) ??
                            (asStr(
                              v['file_path'],
                            )?.split(RegExp(r'[\\/]')).last);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${l.eduVersion} #${v['version_number'] ?? (versions.length - i)}',
                                  style: context.sans(
                                    14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (isLate)
                                  Pill(
                                    l.eduLate,
                                    color: AppColors.warning,
                                    icon: Icons.schedule_rounded,
                                  ),
                              ],
                            ),
                            if (subDate != null)
                              Text(
                                f.dateTime(subDate),
                                style: context.sans(12, color: p.muted),
                              ),
                            if (asStr(v['text']) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  asStr(v['text'])!,
                                  style: context.sans(13),
                                ),
                              ),
                            if (fileName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        style: context.sans(12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return FutureBuilder<List<Json>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? ErrorView(error: snap.error!, onRetry: _reload)
              : const LoadingView();
        final list = snap.data!;
        if (list.isEmpty)
          return EmptyView(
            message: l.eduNoAssignments,
            icon: Icons.assignment_outlined,
          );
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final a in list)
                Builder(
                  builder: (context) {
                    final sub = asJson(a['submission']);
                    final due = asDate(a['due_at']);
                    final late =
                        due != null &&
                        due.isBefore(DateTime.now()) &&
                        sub.isEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${a['title']}',
                                    style: context.sans(
                                      15,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (a['is_group'] == true)
                                  Pill(
                                    asStr(asJson(a['my_group'])['name']) ??
                                        l.eduGroupWork,
                                    icon: Icons.groups_rounded,
                                  ),
                              ],
                            ),
                            Text(
                              <String>[
                                asStr(a['course_name']) ?? '',
                                if (due != null) l.eduDue(f.dateTime(due)),
                              ].where((x) => x.isNotEmpty).join(' · '),
                              style: context.sans(
                                12,
                                color: late ? AppColors.danger : p.muted,
                              ),
                            ),
                            if (asStr(a['instructions']) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  asStr(a['instructions'])!,
                                  style: context.sans(13),
                                ),
                              ),
                            if (asStr(a['attachment_url']) != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _openUrl(asStr(a['attachment_url'])!),
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: Text(l.eduOpenAttachment),
                                ),
                              ),
                            const SizedBox(height: 6),
                            if (sub.isNotEmpty) ...[
                              Row(
                                children: [
                                  Pill(
                                    sub['score'] != null
                                        ? l.eduScore(
                                            _score(sub['score'])!,
                                            _score(a['max_score'])!,
                                          )
                                        : l.eduSubmitted,
                                    icon: sub['score'] != null
                                        ? Icons.grade_rounded
                                        : Icons.check_rounded,
                                    color: AppColors.success,
                                  ),
                                  if (asBool(sub['is_late'])) ...[
                                    const SizedBox(width: 6),
                                    Pill(
                                      l.eduLate,
                                      icon: Icons.schedule_rounded,
                                      color: AppColors.warning,
                                    ),
                                  ],
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.history_rounded),
                                    tooltip: l.eduVersions,
                                    onPressed: () =>
                                        _showVersions(asIntOr(sub['id'])),
                                  ),
                                  if (sub['graded_at'] == null &&
                                      (a['allow_resubmit'] == null ||
                                          asBool(a['allow_resubmit'])))
                                    TextButton(
                                      onPressed: () => _submit(a),
                                      child: Text(l.eduResubmit),
                                    ),
                                ],
                              ),
                              if (asStr(sub['feedback']) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '— ${sub['feedback']}',
                                    style: context.sans(12, color: p.muted),
                                  ),
                                ),
                            ] else
                              FilledButton.icon(
                                onPressed: () => _submit(a),
                                icon: const Icon(Icons.upload_rounded),
                                label: Text(l.eduSubmit),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SubmitSheet extends ConsumerStatefulWidget {
  const _SubmitSheet({required this.assignment});
  final Json assignment;
  @override
  ConsumerState<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends ConsumerState<_SubmitSheet> {
  final _text = TextEditingController();
  String? _path;
  bool _busy = false;
  Object? _error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.assignment['title']}', style: context.serif(19)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: l.eduAnswer,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final path = (await pickTypedFile(context))?.path;
                if (path != null) setState(() => _path = path);
              },
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(
                _path == null
                    ? l.eduAttachFile
                    : _path!.split(RegExp(r'[\\/]')).last,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorText(l, _error!),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (_text.text.trim().isEmpty && _path == null) return;
                      setState(() => _busy = true);
                      try {
                        await ref
                            .read(eduRepositoryProvider)
                            .submit(
                              asIntOr(widget.assignment['id']),
                              text: _text.text.trim().isEmpty
                                  ? null
                                  : _text.text.trim(),
                              filePath: _path,
                            );
                        if (!context.mounted) return;
                        showSnack(context, l.eduSubmitted);
                        Navigator.pop(context, true);
                      } catch (e) {
                        setState(() => _error = e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.eduSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyResultsTab extends ConsumerStatefulWidget {
  const _MyResultsTab({required this.classId});
  final int classId;
  @override
  ConsumerState<_MyResultsTab> createState() => _MyResultsTabState();
}

class _MyResultsTabState extends ConsumerState<_MyResultsTab> {
  late Future<({Json results, List<Json> outcomes})> _future = _load();
  bool _requestingRetake = false;

  Future<({Json results, List<Json> outcomes})> _load() async {
    final repo = ref.read(eduRepositoryProvider);
    final results = await repo.myResults(widget.classId);
    final outcomes = await repo.myOutcomes().catchError((_) => <Json>[]);
    return (results: results, outcomes: outcomes);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _requestRetake(int outcomeId) async {
    setState(() => _requestingRetake = true);
    try {
      await ref.read(eduRepositoryProvider).requestRetake(outcomeId);
      if (!mounted) return;
      showSnack(context, context.l10n.eduRetakeRequestedSuccess);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _requestingRetake = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return FutureBuilder<({Json results, List<Json> outcomes})>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? ErrorView(error: snap.error!, onRetry: _reload)
              : const LoadingView();
        final courses = asJsonList(snap.data!.results['courses']);
        final outcomes = snap.data!.outcomes;
        if (courses.isEmpty)
          return EmptyView(message: l.eduNoResults, icon: Icons.grade_outlined);
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final c in courses)
                Builder(
                  builder: (context) {
                    final courseId = asInt(asJson(c['course'])['id']);
                    final outcome = outcomes.cast<Json?>().firstWhere(
                      (o) => asInt(o?['course_id']) == courseId,
                      orElse: () => null,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${asJson(c['course'])['name']}',
                                    style: context.sans(
                                      15,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (outcome != null) ...[
                                  if (outcome['result'] == 'passed')
                                    Pill(
                                      l.eduPassed,
                                      color: AppColors.success,
                                      icon: Icons.check_circle_rounded,
                                    )
                                  else if (outcome['result'] == 'failed')
                                    Pill(
                                      l.eduFailed,
                                      color: AppColors.danger,
                                      icon: Icons.cancel_rounded,
                                    )
                                  else
                                    Pill(
                                      l.eduIncomplete,
                                      color: AppColors.warning,
                                      icon: Icons.hourglass_empty_rounded,
                                    ),
                                ] else if (c['total_percent'] != null)
                                  Pill(
                                    '${_score(c['total_percent'])}%',
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                            if (outcome != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${l.eduScoreLabel}: ${_score(outcome['score_percent'])}% · ${l.eduPassMark}: ${_score(outcome['pass_mark'])}%',
                                      style: context.sans(12, color: p.muted),
                                    ),
                                    if (outcome['status'] == 'finalized')
                                      Pill(
                                        asStr(outcome['status']) ?? 'finalized',
                                        color: AppColors.faint,
                                        icon: Icons.lock_outline_rounded,
                                      ),
                                    if (asBool(
                                      outcome['counts_for_progression'],
                                    ))
                                      Pill(
                                        l.eduCountsForProgression,
                                        color: AppColors.goldDark,
                                        icon: Icons.star_rounded,
                                      ),
                                  ],
                                ),
                              ),
                            if (outcome != null &&
                                outcome['result'] == 'failed' &&
                                outcome['status'] == 'finalized') ...[
                              const SizedBox(height: 6),
                              if (outcome['retake'] != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Pill(
                                    '${l.eduRetake}: ${asJson(outcome['retake'])['status']}',
                                    color: AppColors.goldDark,
                                    icon: Icons.replay_rounded,
                                  ),
                                )
                              else
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _requestingRetake
                                        ? null
                                        : () => _requestRetake(
                                            asIntOr(outcome['id']),
                                          ),
                                    icon: const Icon(Icons.replay_rounded),
                                    label: Text(l.eduRequestRetake),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 6),
                            if (asJsonList(c['assessments']).isEmpty)
                              Text(
                                l.eduNoResults,
                                style: context.sans(12, color: p.muted),
                              ),
                            for (final a in asJsonList(c['assessments']))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${a['title']}${asDouble(a['weight']) > 0 ? ' (${_score(a['weight'])}%)' : ''}',
                                        style: context.sans(13),
                                      ),
                                    ),
                                    // Not yet published (or not entered): shown as pending, never as 0.
                                    a['score'] == null
                                        ? Text(
                                            l.eaResultPending,
                                            style: context.sans(
                                              12,
                                              color: p.muted,
                                            ),
                                          )
                                        : Text(
                                            '${_score(a['score'])} / ${_score(a['max_score'])}',
                                            style: context.sans(
                                              13,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Attendance taking (attendance takers, teachers, moderator)
// =============================================================================
class EduAttendanceScreen extends ConsumerStatefulWidget {
  const EduAttendanceScreen({super.key, required this.classId});
  final int classId;
  @override
  ConsumerState<EduAttendanceScreen> createState() =>
      _EduAttendanceScreenState();
}

class _EduAttendanceScreenState extends ConsumerState<EduAttendanceScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  late Future<List<Json>> _future = _load();

  /// The roster read-only view from attendance records.
  Future<List<Json>> _load() async {
    return await ref
        .read(eduRepositoryProvider)
        .roster(widget.classId, ymd(_date));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return PatternScaffold(
      appBar: AppBar(title: Text(l.attendanceRoster)),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.goldDark,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Attendance is unified with the church attendance system. Direct marking here is retired.'
                        : 'የክፍል መገኘት ከዋናው የሰንበት ት/ቤት መገኘት ጋር ተዋህዷል። ቀጥታ እዚህ መመዝገብ አቁሟል።',
                    style: context.sans(12),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/admin/attendance'),
                  child: Text(
                    isEn ? 'Scanner' : 'መቆጣጠሪያ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await showEthiopianDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) {
                  _date = d;
                  _reload();
                }
              },
              icon: const Icon(Icons.event_rounded, color: AppColors.gold),
              label: Text(f.date(_date, withWeekday: true)),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Json>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData)
                  return snap.hasError
                      ? ErrorView(error: snap.error!, onRetry: _reload)
                      : const LoadingView();
                final rows = snap.data!;
                if (rows.isEmpty)
                  return EmptyView(
                    message: l.eduNoStudents,
                    icon: Icons.groups_outlined,
                  );
                final marked = rows.where((r) => r['status'] != null).length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l.eduMarkedCount(marked, rows.length),
                        style: context.sans(12, color: context.palette.muted),
                      ),
                    ),
                    for (final r in rows)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: asStr(r['avatar_url']) != null
                              ? NetworkImage(asStr(r['avatar_url'])!)
                              : null,
                          child: asStr(r['avatar_url']) == null
                              ? Text('${r['full_name']}'.characters.first)
                              : null,
                        ),
                        title: Text('${r['full_name']}'),
                        subtitle: Text(programLabel(l, asStr(r['program']))),
                        trailing: Pill(
                          attendanceStatusLabel(l, asStr(r['status'])),
                          color: attendanceStatusColor(asStr(r['status'])),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Teacher: one course
// =============================================================================
final _courseProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(eduRepositoryProvider).course(id),
);

class EduCourseScreen extends ConsumerWidget {
  const EduCourseScreen({super.key, required this.courseId, this.initialTab});
  final int courseId;

  /// 'assignments' / 'assessments' / 'quizzes' open that tab (from the home's teaching counts).
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(_courseProvider(courseId));
    final c = async.value;
    final subjectId = asInt(c?['subject_id']);
    return DefaultTabController(
      length: 5,
      initialIndex: switch (initialTab) {
        'assignments' => 1,
        'assessments' => 2,
        'quizzes' => 3,
        'results' => 4,
        'outcomes' => 4,
        _ => 0,
      },
      child: PatternScaffold(
        appBar: AppBar(
          title: Text(asStr(c?['name']) ?? l.eduCourses),
          actions: [
            // The curriculum (units, lessons, materials) of the catalog subject this class subject teaches.
            if (subjectId != null)
              IconButton(
                tooltip: l.elLessons,
                icon: const Icon(Icons.auto_stories_outlined),
                onPressed: () => context.push('/edu/learn/subject/$subjectId'),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l.eduStudents),
              Tab(text: l.eduAssignments),
              Tab(text: l.eduAssessments),
              Tab(text: l.elQuizzes),
              Tab(text: l.eduOutcomes),
            ],
          ),
        ),
        body: AsyncView(
          value: async,
          onRetry: () => ref.invalidate(_courseProvider(courseId)),
          data: (c) => TabBarView(
            children: [
              _StudentsTab(
                course: c,
                onChanged: () => ref.invalidate(_courseProvider(courseId)),
              ),
              _AssignmentsTab(courseId: courseId),
              _AssessmentsTab(courseId: courseId),
              CourseQuizzesTab(courseId: courseId),
              _CourseOutcomesTab(courseId: courseId),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentsTab extends ConsumerWidget {
  const _StudentsTab({required this.course, required this.onChanged});
  final Json course;
  final VoidCallback onChanged;

  Future<List<int>?> _pickStudents(
    BuildContext context,
    List<Json> students,
    Set<int> initial,
  ) {
    final selected = {...initial};
    return showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(ctx.l10n.eduGroupMembers),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in students)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(asIntOr(s['user_id'])),
                  title: Text('${s['full_name']}'),
                  subtitle: s['group'] != null ? Text('${s['group']}') : null,
                  onChanged: (v) => setS(
                    () => v == true
                        ? selected.add(asIntOr(s['user_id']))
                        : selected.remove(asIntOr(s['user_id'])),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected.toList()),
              child: Text(ctx.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(eduRepositoryProvider);
    final students = asJsonList(course['students']);
    final groups = asJsonList(course['groups']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: l.eduGroups)),
            TextButton.icon(
              icon: const Icon(Icons.group_add_rounded),
              label: Text(l.eduNewGroup),
              onPressed: () async {
                final name = await promptText(
                  context,
                  title: l.eduNewGroup,
                  label: l.title,
                  required: true,
                );
                if (name == null || name.trim().isEmpty || !context.mounted)
                  return;
                final ids = await _pickStudents(context, students, {});
                if (ids == null || !context.mounted) return;
                await runWithProgress(
                  context,
                  () =>
                      repo.createGroup(asIntOr(course['id']), name.trim(), ids),
                  success: l.saved,
                );
                onChanged();
              },
            ),
          ],
        ),
        if (groups.isEmpty)
          Text(
            l.eduNoGroups,
            style: context.sans(13, color: context.palette.muted),
          ),
        for (final g in groups)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_rounded, color: AppColors.gold),
            title: Text('${g['name']}'),
            subtitle: Text(
              asJsonList(g['members']).map((m) => m['full_name']).join('، '),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'members') {
                  final ids = await _pickStudents(
                    context,
                    students,
                    asJsonList(
                      g['members'],
                    ).map((m) => asIntOr(m['user_id'])).toSet(),
                  );
                  if (ids == null || !context.mounted) return;
                  await runWithProgress(
                    context,
                    () => repo.setGroupMembers(asIntOr(g['id']), ids),
                    success: l.saved,
                  );
                } else {
                  if (!await showConfirm(
                        context,
                        l.deleteConfirm,
                        destructive: true,
                      ) ||
                      !context.mounted)
                    return;
                  await runWithProgress(
                    context,
                    () => repo.deleteGroup(asIntOr(g['id'])),
                  );
                }
                onChanged();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'members', child: Text(l.eduGroupMembers)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ),
        SectionHeader(title: '${l.eduStudents} (${students.length})'),
        if (students.isEmpty)
          Text(
            l.eduNoStudents,
            style: context.sans(13, color: context.palette.muted),
          ),
        for (final s in students)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text('${s['full_name']}'.characters.first),
            ),
            title: Text('${s['full_name']}'),
            subtitle: Text(
              [
                programLabel(l, asStr(s['program'])),
                if (s['group'] != null) '${s['group']}',
              ].join(' · '),
            ),
          ),
      ],
    );
  }
}

class _AssignmentsTab extends ConsumerStatefulWidget {
  const _AssignmentsTab({required this.courseId});
  final int courseId;
  @override
  ConsumerState<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab> {
  late Future<List<Json>> _future = ref
      .read(eduRepositoryProvider)
      .assignments(widget.courseId);
  void _reload() => setState(
    () =>
        _future = ref.read(eduRepositoryProvider).assignments(widget.courseId),
  );

  Future<void> _create() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _AssignmentEditor(courseId: widget.courseId),
      ),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-assignment',
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.eduNewAssignment),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData)
            return snap.hasError
                ? ErrorView(error: snap.error!, onRetry: _reload)
                : const LoadingView();
          final list = snap.data!;
          if (list.isEmpty)
            return EmptyView(
              message: l.eduNoAssignments,
              icon: Icons.assignment_outlined,
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              for (final a in list)
                TrackTile(
                  title: '${a['title']}',
                  subtitle: [
                    l.eduSubmissionCount(asIntOr(a['submission_count'])),
                    if (asDate(a['due_at']) != null)
                      l.eduDue(f.dateTime(asDate(a['due_at']))),
                    if (a['is_group'] == true) l.eduGroupWork,
                  ].join(' · '),
                  leading: const ListThumb(icon: Icons.assignment_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _SubmissionsScreen(assignmentId: asIntOr(a['id'])),
                      ),
                    );
                    _reload();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentEditor extends ConsumerStatefulWidget {
  const _AssignmentEditor({required this.courseId});
  final int courseId;
  @override
  ConsumerState<_AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends ConsumerState<_AssignmentEditor> {
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _max = TextEditingController(text: '100');
  DateTime? _due;
  DateTime? _publishAt;
  String _latePolicy = 'refuse';
  DateTime? _lateUntil;
  bool _allowResubmit = true;
  bool _group = false;
  String? _file;
  Object? _error;
  bool _busy = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(eduRepositoryProvider);
      final a = await repo.createAssignment(widget.courseId, {
        'title': _title.text.trim(),
        'instructions': _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
        'due_at': _due?.toUtc().toIso8601String(),
        'max_score': double.tryParse(_max.text.trim()) ?? 100,
        'is_group': _group,
        'publish_at': _publishAt?.toUtc().toIso8601String(),
        'late_policy': _latePolicy,
        'late_until': _latePolicy == 'accept_marked'
            ? _lateUntil?.toUtc().toIso8601String()
            : null,
        'allow_resubmit': _allowResubmit,
      });
      if (_file != null)
        await repo.uploadAssignmentFile(asIntOr(a['id']), _file!);
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(l.eduNewAssignment, style: context.serif(19)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.title),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructions,
            minLines: 2,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l.eduInstructions,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          DateTimeField(
            label: l.eduDueDate,
            value: _due,
            clearable: true,
            onChanged: (d) => setState(() => _due = d),
          ),
          const SizedBox(height: 10),
          DateTimeField(
            label: l.eduPublishAt,
            value: _publishAt,
            clearable: true,
            onChanged: (d) => setState(() => _publishAt = d),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _latePolicy,
            decoration: InputDecoration(labelText: l.eduLatePolicy),
            items: [
              DropdownMenuItem(
                value: 'refuse',
                child: Text(l.eduLatePolicyRefuse),
              ),
              DropdownMenuItem(
                value: 'accept_marked',
                child: Text(l.eduLatePolicyAccept),
              ),
            ],
            onChanged: (v) => setState(() => _latePolicy = v ?? 'refuse'),
          ),
          if (_latePolicy == 'accept_marked') ...[
            const SizedBox(height: 10),
            DateTimeField(
              label: l.eduLateUntil,
              value: _lateUntil,
              clearable: true,
              onChanged: (d) => setState(() => _lateUntil = d),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _max,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.eduMaxScore),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.eduAllowResubmit),
            value: _allowResubmit,
            onChanged: (v) => setState(() => _allowResubmit = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.eduGroupWork),
            value: _group,
            onChanged: (v) => setState(() => _group = v),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final path = (await pickTypedFile(context))?.path;
              if (path != null) setState(() => _file = path);
            },
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              _file == null
                  ? l.eduAttachFile
                  : _file!.split(RegExp(r'[\\/]')).last,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                errorText(l, _error!),
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

class _SubmissionsScreen extends ConsumerStatefulWidget {
  const _SubmissionsScreen({required this.assignmentId});
  final int assignmentId;
  @override
  ConsumerState<_SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends ConsumerState<_SubmissionsScreen> {
  late Future<Json> _future = ref
      .read(eduRepositoryProvider)
      .submissions(widget.assignmentId);
  void _reload() => setState(
    () => _future = ref
        .read(eduRepositoryProvider)
        .submissions(widget.assignmentId),
  );

  Future<void> _grade(Json s, double max) async {
    final l = context.l10n;
    final score = TextEditingController(text: _score(s['score']) ?? '');
    final feedback = TextEditingController(text: asStr(s['feedback']) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('${s['full_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: score,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '${l.eduScoreLabel} / ${_score(max)}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedback,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.eduFeedback),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runWithProgress(
      context,
      () => ref
          .read(eduRepositoryProvider)
          .grade(
            asIntOr(s['id']),
            score: double.tryParse(score.text.trim()),
            feedback: feedback.text.trim().isEmpty
                ? null
                : feedback.text.trim(),
          ),
      success: l.saved,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PatternScaffold(
      appBar: AppBar(title: Text(l.eduSubmissions)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData)
            return snap.hasError
                ? ErrorView(error: snap.error!, onRetry: _reload)
                : const LoadingView();
          final a = asJson(snap.data!['assignment']);
          final subs = asJsonList(snap.data!['submissions']);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('${a['title']}', style: context.serif(19)),
              const SizedBox(height: 8),
              if (subs.isEmpty)
                EmptyView(
                  message: l.eduNoSubmissions,
                  icon: Icons.inbox_outlined,
                ),
              for (final s in subs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                [
                                  s['full_name'],
                                  if (s['group_name'] != null) s['group_name'],
                                ].join(' · '),
                                style: context.sans(
                                  14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              f.relative(asDate(s['submitted_at'])),
                              style: context.sans(
                                11,
                                color: context.palette.subtle,
                              ),
                            ),
                          ],
                        ),
                        if (asStr(s['text']) != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SelectableText(asStr(s['text'])!),
                          ),
                        if (asStr(s['file_url']) != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openUrl(asStr(s['file_url'])!),
                              icon: const Icon(Icons.attach_file_rounded),
                              label: Text(
                                asStr(s['file_name']) ?? l.eduOpenAttachment,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            if (s['score'] != null)
                              Pill(
                                l.eduScore(
                                  _score(s['score'])!,
                                  _score(a['max_score'])!,
                                ),
                                color: AppColors.success,
                              ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  _grade(s, asDouble(a['max_score'])),
                              icon: const Icon(Icons.grade_rounded),
                              label: Text(l.eduGrade),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AssessmentsTab extends ConsumerStatefulWidget {
  const _AssessmentsTab({required this.courseId});
  final int courseId;
  @override
  ConsumerState<_AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends ConsumerState<_AssessmentsTab> {
  late Future<List<Json>> _future = ref
      .read(eduRepositoryProvider)
      .assessments(widget.courseId);
  void _reload() => setState(
    () =>
        _future = ref.read(eduRepositoryProvider).assessments(widget.courseId),
  );

  Future<void> _create() async {
    final l = context.l10n;
    final title = TextEditingController();
    final max = TextEditingController(text: '100');
    final weight = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l.eduNewAssessment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: l.title,
                hintText: l.eduAssessmentHint,
              ),
            ),
            TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.eduMaxScore),
            ),
            TextField(
              controller: weight,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.eduWeight),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty || !mounted) return;
    await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).createAssessment(widget.courseId, {
        'title': title.text.trim(),
        'max_score': double.tryParse(max.text) ?? 100,
        'weight': double.tryParse(weight.text) ?? 0,
      }),
      success: l.saved,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-assessment',
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.eduNewAssessment),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData)
            return snap.hasError
                ? ErrorView(error: snap.error!, onRetry: _reload)
                : const LoadingView();
          final list = snap.data!;
          if (list.isEmpty)
            return EmptyView(
              message: l.eduNoAssessments,
              icon: Icons.grade_outlined,
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              for (final a in list)
                TrackTile(
                  title: '${a['title']}',
                  subtitle:
                      '${l.eduMaxScore}: ${_score(a['max_score'])} · ${l.eduWeight}: ${_score(a['weight'])}%',
                  leading: const ListThumb(icon: Icons.grade_rounded),
                  trailing: PopupMenuButton<String>(
                    onSelected: (_) async {
                      if (!await showConfirm(
                            context,
                            l.deleteConfirm,
                            destructive: true,
                          ) ||
                          !context.mounted)
                        return;
                      await runWithProgress(
                        context,
                        () => ref
                            .read(eduRepositoryProvider)
                            .deleteAssessment(asIntOr(a['id'])),
                      );
                      _reload();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _ScoreSheetScreen(assessmentId: asIntOr(a['id'])),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreSheetScreen extends ConsumerStatefulWidget {
  const _ScoreSheetScreen({required this.assessmentId});
  final int assessmentId;
  @override
  ConsumerState<_ScoreSheetScreen> createState() => _ScoreSheetScreenState();
}

class _ScoreSheetScreenState extends ConsumerState<_ScoreSheetScreen> {
  Json? _sheet;
  final _ctrls = <int, TextEditingController>{};
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ref
          .read(eduRepositoryProvider)
          .scoreSheet(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _sheet = s;
        for (final r in asJsonList(s['scores'])) {
          _ctrls[asIntOr(r['user_id'])] = TextEditingController(
            text: _score(r['score']) ?? '',
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final editable = {
        for (final r in asJsonList(_sheet?['scores']))
          if (r['editable'] != false) asIntOr(r['user_id']),
      };
      await ref.read(eduRepositoryProvider).saveScores(widget.assessmentId, [
        for (final e in _ctrls.entries)
          if (editable.contains(e.key))
            {'user_id': e.key, 'score': double.tryParse(e.value.text.trim())},
      ]);
      if (mounted) showSnack(context, context.l10n.saved);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Send the saved draft / corrected marks to the education administrators.
  Future<void> _submit() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.eaSubmitMarksConfirm) || !mounted) return;
    await _save();
    if (!mounted) return;
    final r = await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).submitMarks(widget.assessmentId),
    );
    if (r != null && mounted)
      showSnack(
        context,
        l.eaMarksSubmitted(asIntOr(r['submitted']), asIntOr(r['left_empty'])),
      );
    await _load();
  }

  /// Education administrator: correct an approved / published mark (reason required).
  Future<void> _amend(Json r) async {
    final l = context.l10n;
    final score = await promptText(
      context,
      title: '${l.eaAmend} — ${r['full_name']}',
      label: l.eduMaxScore,
      initial: _score(r['score']) ?? '',
    );
    if (score == null || !mounted) return;
    final reason = await promptText(
      context,
      title: l.eaAmend,
      label: l.eaAmendReason,
      maxLines: 2,
      required: true,
    );
    if (reason == null || reason.length < 3 || !mounted) return;
    await runWithProgress(
      context,
      () => ref
          .read(eduRepositoryProvider)
          .amendMark(
            widget.assessmentId,
            asIntOr(r['user_id']),
            double.tryParse(score.trim()),
            reason,
          ),
      success: l.saved,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = asJson(_sheet?['assessment']);
    final admin =
        ref.watch(currentUserProvider)?.can('education.manage') ?? false;
    final canSubmit = asJsonList(
      _sheet?['scores'],
    ).any((r) => r['status'] == 'draft' || r['status'] == 'rejected');
    return PatternScaffold(
      appBar: AppBar(
        title: Text(asStr(a['title']) ?? l.eduAssessments),
        actions: [
          if (canSubmit)
            IconButton(
              tooltip: l.eaSubmitMarks,
              icon: const Icon(Icons.send_rounded),
              onPressed: _submit,
            ),
          ReportExportButton(
            kind: 'education',
            filters: () => {'course_id': a['course_id']},
          ),
        ],
      ),
      floatingActionButton: _sheet == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(l.save),
            ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : _sheet == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  '${l.eduMaxScore}: ${_score(a['max_score'])}',
                  style: context.sans(12, color: context.palette.muted),
                ),
                Text(
                  l.eaMarksWorkflowHint,
                  style: context.sans(11, color: context.palette.subtle),
                ),
                for (final r in asJsonList(_sheet!['scores']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r['full_name']}'),
                              Row(
                                children: [
                                  Pill(
                                    eduMarkStatusLabel(l, asStr(r['status'])),
                                    color: eduStatusColor(asStr(r['status'])),
                                  ),
                                  if (r['recorded_by_name'] != null)
                                    Flexible(
                                      child: Text(
                                        '  ${l.eaEnteredBy} ${r['recorded_by_name']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: context.sans(
                                          11,
                                          color: context.palette.muted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (r['status'] == 'rejected' &&
                                  r['review_note'] != null)
                                Text(
                                  '${l.eaRejectReason}: ${r['review_note']}',
                                  style: context.sans(
                                    11,
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (admin &&
                            (r['status'] == 'approved' ||
                                r['status'] == 'published'))
                          IconButton(
                            tooltip: l.eaAmend,
                            icon: const Icon(Icons.edit_note_rounded),
                            onPressed: () => _amend(r),
                          ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _ctrls[asIntOr(r['user_id'])],
                            // Submitted / approved / published marks are locked here.
                            enabled: r['editable'] != false,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '—',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CourseOutcomesTab extends ConsumerStatefulWidget {
  const _CourseOutcomesTab({required this.courseId});
  final int courseId;
  @override
  ConsumerState<_CourseOutcomesTab> createState() => _CourseOutcomesTabState();
}

class _CourseOutcomesTabState extends ConsumerState<_CourseOutcomesTab> {
  late Future<List<Json>> _future = ref
      .read(eduRepositoryProvider)
      .courseOutcomes(widget.courseId);
  bool _busy = false;

  void _reload() => setState(
    () => _future = ref
        .read(eduRepositoryProvider)
        .courseOutcomes(widget.courseId),
  );

  Future<void> _compute() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(eduRepositoryProvider)
          .computeCourseOutcomes(widget.courseId);
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final ok = await showConfirm(
      context,
      context.l10n.eduFinalizeConfirm,
      title: context.l10n.eduFinalizeOutcomes,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(eduRepositoryProvider)
          .finalizeCourseOutcomes(widget.courseId);
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issueCertificates() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final eligible = await ref
          .read(eduRepositoryProvider)
          .courseEligibleCertificates(widget.courseId);
      if (!mounted) return;
      if (eligible.isEmpty) {
        showInfo(context, l.eduNoEligibleStudents);
        return;
      }
      final toIssue = eligible
          .where((e) => e['has_certificate'] != true)
          .toList();
      if (toIssue.isEmpty) {
        showInfo(context, l.eduNoEligibleStudents);
        return;
      }

      final selectedIds = <int>{...toIssue.map((e) => asIntOr(e['user_id']))};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(ctx.l10n.eduIssueCertificates)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctx.l10n.eduIssueCertificatesConfirm(selectedIds.length),
                  ),
                  const SizedBox(height: 12),
                  for (final st in toIssue)
                    CheckboxListTile(
                      dense: true,
                      value: selectedIds.contains(st['user_id']),
                      title: Text(
                        asStr(st['full_name']) ?? 'Student #${st['user_id']}',
                      ),
                      subtitle: Text(
                        '${st['score_percent']}% · ${asDouble(st['completion_percent']).toStringAsFixed(0)}%',
                      ),
                      onChanged: (val) {
                        setDState(() {
                          if (val == true) {
                            selectedIds.add(asIntOr(st['user_id']));
                          } else {
                            selectedIds.remove(asIntOr(st['user_id']));
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.eduIssueCertificates),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true || selectedIds.isEmpty || !mounted) return;

      final issued = await ref
          .read(eduRepositoryProvider)
          .issueCertificates(widget.courseId, selectedIds.toList());
      if (!mounted) return;
      showSnack(context, l.eduIssuedSuccess(issued.length));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return FutureBuilder<List<Json>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return snap.hasError
              ? ErrorView(error: snap.error!, onRetry: _reload)
              : const LoadingView();
        final list = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _compute,
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(l.eduComputeOutcomes),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _finalize,
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: Text(l.eduFinalizeOutcomes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _issueCertificates,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(l.eduIssueCertificates),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyView(message: l.eduNoResults, icon: Icons.grade_outlined)
              else
                for (final o in list)
                  Builder(
                    builder: (context) {
                      final student = asJson(o['student']);
                      final name =
                          asStr(student['name']) ?? 'Student #${o['user_id']}';
                      final result = asStr(o['result']);
                      final status = asStr(o['status']);
                      final score = o['score_percent'];
                      final isFinal = status == 'finalized';
                      final pass = result == 'passed';
                      final fail = result == 'failed';
                      final counts = asBool(o['counts_for_progression']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: pass
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : (fail
                                          ? AppColors.danger.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.goldLight.withValues(
                                              alpha: 0.15,
                                            )),
                                foregroundColor: pass
                                    ? AppColors.success
                                    : (fail
                                          ? AppColors.danger
                                          : AppColors.goldDark),
                                child: Icon(
                                  pass
                                      ? Icons.check_circle_outline
                                      : (fail
                                            ? Icons.cancel_outlined
                                            : Icons.hourglass_empty_rounded),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: context.sans(
                                        14,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${score != null ? '$score%' : '—'} · ${pass ? l.eduPassed : (fail ? l.eduFailed : l.eduIncomplete)} · ${isFinal ? 'Final' : 'Draft'}',
                                      style: context.sans(12, color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                              if (counts)
                                Pill(
                                  l.eduCountsForProgression,
                                  icon: Icons.star_rounded,
                                  color: AppColors.goldDark,
                                )
                              else if (isFinal)
                                TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(eduRepositoryProvider)
                                        .setCountingOutcome(asIntOr(o['id']));
                                    _reload();
                                  },
                                  child: Text(l.eduCountsForProgression),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        );
      },
    );
  }
}
