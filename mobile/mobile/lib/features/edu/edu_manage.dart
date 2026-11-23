import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show DateTimeField, SearchBox, pickUsers;
import '../guidance/contextual_help_sheet.dart';
import 'edu_academics.dart' show EduCourseTeachersSheet;
import 'edu_assign.dart' show showTransferDialog;
import 'edu_screens.dart';

import '../../models/admin.dart' show Perm;
import '../auth/session.dart' show currentUserProvider;
import 'learn/edu_home.dart' show eduDashboardProvider;

final _adminClassesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(eduRepositoryProvider).adminClasses());

/// Centralized Course Management Hub for authorized administrators.
class EduManageScreen extends ConsumerStatefulWidget {
  const EduManageScreen({super.key});

  @override
  ConsumerState<EduManageScreen> createState() => _EduManageScreenState();
}

class _EduManageScreenState extends ConsumerState<EduManageScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final user = ref.watch(currentUserProvider);

    final canManage = user != null &&
        (user.isSuperAdmin ||
            user.canAny([
              Perm.educationManage,
              Perm.educationRegister,
              Perm.educationContent,
              Perm.educationReports,
              Perm.educationCertify,
            ]));

    if (!canManage) {
      return PatternScaffold(
        appBar: AppBar(title: Text(l.courseManagement)),
        body: Center(
          child: EmptyView(
            message: l.errorForbidden,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      );
    }

    final dashAsync = ref.watch(eduDashboardProvider);
    final adminData = dashAsync.value?['admin'] is Map ? asJson(dashAsync.value!['admin']) : null;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.courseManagement),
        actions: [
          if (user.isSuperAdmin || user.can(Perm.educationManage))
            IconButton(
              tooltip: l.isEn ? 'Establish / Sync Grades 1–12' : 'ክፍል 1–12 ስርዓተ-ትምህርት አመሳስል',
              icon: const Icon(Icons.sync_rounded),
              onPressed: () async {
                final confirm = await showConfirm(
                  context,
                  l.isEn
                      ? 'Establish and connect all 12 grade classes to the official curriculum for the current academic year?'
                      : 'ለሁሉም ከክፍል 1–12 ያሉ ክፍሎች ይፈጠሩ እና ከስርዓተ-ትምህርቱ ጋር ይገናኙ?',
                );
                if (!confirm || !context.mounted) return;
                await runWithProgress(
                  context,
                  () => ref.read(eduRepositoryProvider).syncGradeClasses(),
                  success: l.isEn ? 'Grades 1–12 classes synced with official curriculum' : 'ክፍል 1–12 ከስርዓተ-ትምህርቱ ጋር ተገናኝቷል',
                );
                ref.invalidate(_adminClassesProvider);
                ref.invalidate(eduDashboardProvider);
              },
            ),
          const ContextualHelpButton(screenRoute: '/edu'),
        ],
      ),
      floatingActionButton: (user.isSuperAdmin || user.can(Perm.educationManage))
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/edu/manage/class/new');
                ref.invalidate(_adminClassesProvider);
                ref.invalidate(eduDashboardProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l.eduNewClass),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(_adminClassesProvider);
          ref.invalidate(eduDashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
          children: [
            // Admin pending metrics
            if (adminData != null) ...[
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 560 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: c.maxWidth / cols / 58,
                  children: [
                    _MetricCard(
                      icon: Icons.fact_check_outlined,
                      label: l.elMarksToReview,
                      count: asIntOr(adminData['marks_submitted']),
                      onTap: () => context.push('/edu/review'),
                    ),
                    _MetricCard(
                      icon: Icons.publish_rounded,
                      label: l.elMarksToPublish,
                      count: asIntOr(adminData['marks_approved_unpublished']),
                      onTap: () => context.push('/edu/review'),
                    ),
                    _MetricCard(
                      icon: Icons.swap_horiz_rounded,
                      label: l.elRequestsPending,
                      count: asIntOr(adminData['requests_pending']),
                      onTap: () => context.push('/edu/review?tab=requests'),
                    ),
                    _MetricCard(
                      icon: Icons.report_outlined,
                      label: l.elComplaintsOpen,
                      count: asIntOr(adminData['complaints_open']),
                      onTap: () => context.push('/edu/review?tab=complaints'),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 14),
            ],

            // Core admin tools tiles
            Text(l.courseManagement, style: context.sans(13, weight: FontWeight.w700, color: p.muted)),
            const SizedBox(height: 8),
            Row(children: [
              if (user.isSuperAdmin || user.canAny([Perm.educationManage, Perm.educationRegister]))
                Expanded(
                  child: _HubTile(
                    icon: Icons.how_to_reg_rounded,
                    label: l.regTitle,
                    onTap: () => context.push('/edu/registrations'),
                  ),
                ),
              const SizedBox(width: 8),
              if (user.isSuperAdmin || user.canAny([Perm.educationManage, Perm.educationContent]))
                Expanded(
                  child: _HubTile(
                    icon: Icons.auto_stories_outlined,
                    label: l.elContentTitle,
                    onTap: () => context.push('/edu/content'),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (user.isSuperAdmin || user.canAny([Perm.educationManage, Perm.educationReports]))
                Expanded(
                  child: _HubTile(
                    icon: Icons.query_stats_rounded,
                    label: l.eduScoresAndActivity,
                    onTap: () => context.push('/edu/admin/scores'),
                  ),
                ),
              const SizedBox(width: 8),
              if (user.isSuperAdmin || user.can(Perm.educationManage))
                Expanded(
                  child: _HubTile(
                    icon: Icons.fact_check_outlined,
                    label: l.eaReviewCenter,
                    onTap: () => context.push('/edu/review'),
                  ),
                ),
            ]),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text(l.elTabClasses, style: context.sans(13, weight: FontWeight.w700, color: p.muted))),
            ]),
            const SizedBox(height: 6),
            SearchBox(
              hint: l.search,
              onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),

            AsyncView(
              value: ref.watch(_adminClassesProvider),
              onRetry: () => ref.invalidate(_adminClassesProvider),
              data: (list) {
                final filtered = list.where((c) {
                  if (_query.isEmpty) return true;
                  final name = '${c['name']}'.toLowerCase();
                  final term = '${c['term'] ?? ''}'.toLowerCase();
                  return name.contains(_query) || term.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyView(message: l.eduNoClasses, icon: Icons.school_outlined);
                }

                return Column(
                  children: [
                    for (final c in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TrackTile(
                          title: '${c['name']}',
                          subtitle: [
                            if (asStr(c['term']) != null) asStr(c['term'])!,
                            l.eduStudentCount(asIntOr(c['student_count'])),
                            switch (c['registration']) {
                              'open' => l.eduRegOpen,
                              'upcoming' => l.eduOpensOn(f.date(asDate(c['registration_opens_at']))),
                              _ => l.eduRegClosed,
                            },
                            if (c['status'] == 'archived') l.statusArchived,
                          ].join(' · '),
                          leading: ListThumb(icon: Icons.school_rounded, active: c['status'] == 'active'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await context.push('/edu/manage/class/${c['id']}');
                            ref.invalidate(_adminClassesProvider);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.count, required this.onTap});
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count > 0 ? AppColors.eduGold.withValues(alpha: 0.5) : p.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundy.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Icon(icon, color: count > 0 ? AppColors.eduBurgundy : p.faint, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(11.5, height: 1.2))),
              Text('$count', style: context.serif(17, weight: FontWeight.w700, color: count > 0 ? AppColors.eduBurgundy : p.faint)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.eduGold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.eduGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.goldDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: context.sans(12.5, weight: FontWeight.w600, color: p.primary), maxLines: 2)),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Create / edit a class: details, courses (with teachers), weekly schedule, attendance takers, students.
class EduClassEditorScreen extends ConsumerStatefulWidget {
  const EduClassEditorScreen({super.key, this.classId});
  final int? classId;
  @override
  ConsumerState<EduClassEditorScreen> createState() => _EduClassEditorScreenState();
}

class _EduClassEditorScreenState extends ConsumerState<EduClassEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _term = TextEditingController();
  final _desc = TextEditingController();
  final _descEn = TextEditingController();
  final _capacity = TextEditingController();
  final _year = TextEditingController();
  final _semester = TextEditingController();
  final _streams = TextEditingController();
  DateTime? _opens;
  DateTime? _closes;
  bool _regular = true;
  bool _distance = true;
  bool _active = true;
  bool _allowSelfRegistration = false;
  int? _academicYearId;
  int? _termId;
  int? _levelId;
  bool _allowMultiple = false;
  List<Json> _academicYears = const [];
  List<Json> _terms = const [];
  List<Json> _levels = const [];
  Json? _curriculumPreview;
  bool _loadingCurriculum = false;
  Json? _class;
  List<Json> _staff = const [];
  bool _loading = false;
  bool _saving = false;
  Object? _error;

  int? get _id => asInt(_class?['id']) ?? widget.classId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _term.dispose();
    _desc.dispose();
    _descEn.dispose();
    _capacity.dispose();
    _year.dispose();
    _semester.dispose();
    _streams.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(eduRepositoryProvider);
      final years = await repo.academicYears();
      final levels = await repo.levels();
      Json? c;
      List<Json> staff = const [];
      if (_id != null) {
        c = await repo.classDetail(_id!);
        staff = await repo.staff(_id!);
      }
      int? yearId = asInt(c?['academic_year_id']);
      if (yearId == null && years.isNotEmpty) {
        final current = years.firstWhere((y) => y['is_current'] == true, orElse: () => years.first);
        yearId = asInt(current['id']);
      }
      List<Json> terms = const [];
      if (yearId != null) {
        try {
          terms = await repo.terms(yearId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _academicYears = years;
        _levels = levels;
        _terms = terms;
        _academicYearId = yearId;
        _termId = asInt(c?['term_id']);
        _levelId = asInt(c?['level_id']);
        _allowMultiple = c?['allow_multiple'] == true;
        if (c != null) {
          _class = c;
          _staff = staff;
          _name.text = asStr(c['name']) ?? '';
          _nameEn.text = asStr(c['name_en']) ?? '';
          _term.text = asStr(c['term']) ?? '';
          _desc.text = asStr(c['description']) ?? '';
          _descEn.text = asStr(c['description_en']) ?? '';
          _capacity.text = c['capacity']?.toString() ?? '';
          _year.text = asStr(c['academic_year']) ?? '';
          _semester.text = asStr(c['semester']) ?? '';
          _streams.text = asValues(c['streams'], (e) => '$e').join(', ');
          _opens = asDate(c['registration_opens_at']);
          _closes = asDate(c['registration_closes_at']);
          _regular = c['allow_regular'] != false;
          _distance = c['allow_distance'] != false;
          _active = c['status'] != 'archived';
          _allowSelfRegistration = c['allow_self_registration'] == true;
        }
      });
      if (_levelId != null) {
        _loadCurriculumPreview(_levelId!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCurriculumPreview(int levelId) async {
    setState(() => _loadingCurriculum = true);
    try {
      final p = await ref.read(eduRepositoryProvider).previewCurriculum(levelId);
      if (mounted) setState(() => _curriculumPreview = p);
    } catch (_) {
      if (mounted) setState(() => _curriculumPreview = null);
    } finally {
      if (mounted) setState(() => _loadingCurriculum = false);
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return showSnack(context, l.checkFields);
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'name_en': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
      'term': _term.text.trim().isEmpty ? null : _term.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'description_en': _descEn.text.trim().isEmpty ? null : _descEn.text.trim(),
      'capacity': int.tryParse(_capacity.text.trim()),
      'academic_year': _year.text.trim().isEmpty ? null : _year.text.trim(),
      'semester': _semester.text.trim().isEmpty ? null : _semester.text.trim(),
      'academic_year_id': _academicYearId,
      'term_id': _termId,
      'level_id': _levelId,
      'allow_multiple': _allowMultiple,
      'allow_self_registration': _allowSelfRegistration,
      'streams': [for (final s in _streams.text.split(',')) if (s.trim().isNotEmpty) s.trim()],
      'registration_opens_at': _opens?.toUtc().toIso8601String(),
      'registration_closes_at': _closes?.toUtc().toIso8601String(),
      'allow_regular': _regular,
      'allow_distance': _distance,
      'status': _active ? 'active' : 'archived',
    };
    try {
      final repo = ref.read(eduRepositoryProvider);
      final c = _id == null ? await repo.createClass(body) : await repo.updateClass(_id!, body);
      if (!mounted) return;
      setState(() {
        _class = c;
        _error = null;
      });
      ref.invalidate(_adminClassesProvider);
      ref.invalidate(eduDashboardProvider);
      showSnack(context, l.saved);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showSnack(context, errorText(l, e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCourse(Json course) async {
    final l = context.l10n;
    final name = TextEditingController(text: asStr(course['name']) ?? '');
    final code = TextEditingController(text: asStr(course['code']) ?? '');
    var status = asStr(course['status']) ?? 'active';
    var mode = asStr(course['mode']) ?? 'physical';
    var passMark = TextEditingController(text: course['pass_mark'] != null ? '${course['pass_mark']}' : '50');
    final memberGroups = TextEditingController(text: asValues(course['member_groups'], (e) => '$e').join(', '));
    int? termId = asInt(course['term_id']) ?? _termId;
    int? teacherId = asInt(asJson(course['teacher'])['id']);
    String? teacherName = asStr(asJson(course['teacher'])['full_name']);
    var progress = asIntOr(course['progress']).toDouble();
    final subjectId = asInt(course['subject_id']);
    final curr = asJson(course['curriculum_subject']);
    final linkedPrograms = asJsonList(course['programs']);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(l.isEn ? 'Course Offering Settings' : 'የኮርስ መረጃ ማስተካከያ'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (curr.isNotEmpty || subjectId != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.maroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.maroon.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.maroon),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            asStr(curr['name']) ?? asStr(course['name']) ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (asStr(curr['name_en']) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(asStr(curr['name_en'])!, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.outline)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${curr['units_count'] ?? 0} ${l.isEn ? "units" : "ምዕራፎች"} · ${curr['lessons_count'] ?? 0} ${l.isEn ? "lessons" : "ትምህርቶች"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (subjectId != null) {
                          context.push('/edu/learn/subject/$subjectId');
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text(l.isEn ? 'Open Curriculum Subject' : 'ስርዓተ-ትምህርቱን ተመልከት'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: name, decoration: InputDecoration(labelText: '${l.title} (${l.isEn ? "Display Name" : "የሚታየው ስም"})')),
            TextField(controller: code, decoration: InputDecoration(labelText: l.eaSubjectCode)),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(labelText: l.status),
              items: [
                DropdownMenuItem(value: 'active', child: Text(l.active)),
                DropdownMenuItem(value: 'inactive', child: Text(l.inactive)),
                DropdownMenuItem(value: 'archived', child: Text(l.eaArchived)),
              ],
              onChanged: (v) => setS(() => status = v ?? 'active'),
            ),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: InputDecoration(labelText: l.eduMode),
              items: [
                DropdownMenuItem(value: 'physical', child: Text(l.eduModePhysical)),
                DropdownMenuItem(value: 'online', child: Text(l.eduModeOnline)),
                DropdownMenuItem(value: 'hybrid', child: Text(l.eduModeHybrid)),
              ],
              onChanged: (v) => setS(() => mode = v ?? 'physical'),
            ),
            if (_terms.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: _terms.any((t) => asInt(t['id']) == termId) ? termId : null,
                decoration: InputDecoration(labelText: l.eduTerm),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                  for (final t in _terms)
                    DropdownMenuItem<int?>(value: asInt(t['id']), child: Text('${t['name']}')),
                ],
                onChanged: (v) => setS(() => termId = v),
              ),
            TextField(
              controller: passMark,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.eduPassMark, hintText: '50'),
            ),
            TextField(
              controller: memberGroups,
              decoration: InputDecoration(
                labelText: l.eduEligibleGroups,
                helperText: l.eduAllGroups,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.co_present_rounded, color: AppColors.gold),
              title: Text(teacherName ?? l.eduNoTeacher),
              subtitle: Text(l.eduTeacher),
              trailing: TextButton(
                onPressed: () async {
                  final sel = await pickUsers(ctx, multiple: false, title: l.eduTeacher);
                  if (sel == null || sel.ids.isEmpty) return;
                  setS(() {
                    teacherId = sel.ids.first;
                    teacherName = sel.names[teacherId] ?? '#$teacherId';
                  });
                },
                child: Text(l.select),
              ),
            ),
            if (linkedPrograms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l.eduLinkedPrograms, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final lp in linkedPrograms)
                    Chip(
                      label: Text('${lp['program_title'] ?? lp['program_name'] ?? lp['id']}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            Align(alignment: Alignment.centerLeft, child: Text(l.eduCourseProgress(progress.round().toString()))),
            Slider(value: progress, min: 0, max: 100, divisions: 20, label: '${progress.round()} %', onChanged: (v) => setS(() => progress = v)),
            if (progress >= 100) Text(l.eduCourseCompletedHint, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.outline)),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok == null || !mounted) return;
    final repo = ref.read(eduRepositoryProvider);
    if (ok == false) {
      if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !mounted) return;
      await runWithProgress(context, () => repo.deleteCourse(asIntOr(course['id'])), success: l.deleted);
    } else if (name.text.trim().isNotEmpty) {
      final body = {
        'name': name.text.trim(),
        'code': code.text.trim().isEmpty ? null : code.text.trim(),
        'status': status,
        'mode': mode,
        'term_id': termId,
        'pass_mark': double.tryParse(passMark.text.trim()) ?? 50.0,
        'member_groups': [for (final g in memberGroups.text.split(',')) if (g.trim().isNotEmpty) g.trim()],
        'teacher_user_id': teacherId,
        'subject_id': ?subjectId,
        'progress': progress.round(),
      };
      await runWithProgress(context, () => repo.updateCourse(asIntOr(course['id']), body), success: l.saved);
    }
    await _load();
  }

  Future<void> _addScheduleRow() async {
    final l = context.l10n;
    final courses = asJsonList(_class?['courses']);
    var weekday = 7;
    // 2 / 4 days a week = 2 / 4 weekly rows; 1 day a month (or distance 1–2 days a month) = monthly rows.
    var frequency = 'weekly';
    var weekOfMonth = 1;
    var program = 'all';
    var mode = 'in_person';
    int? courseId = courses.isEmpty ? null : asIntOr(courses.first['id']);
    var starts = const TimeOfDay(hour: 9, minute: 0);
    var ends = const TimeOfDay(hour: 11, minute: 0);
    final location = TextEditingController();
    String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(l.eduAddSession),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: weekday,
              decoration: InputDecoration(labelText: l.eduWeekday),
              items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekdayName(l, d)))],
              onChanged: (v) => setS(() => weekday = v ?? weekday),
            ),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: InputDecoration(labelText: l.eduFrequency),
              items: [DropdownMenuItem(value: 'weekly', child: Text(l.eduWeekly)), DropdownMenuItem(value: 'monthly', child: Text(l.eduMonthly))],
              onChanged: (v) => setS(() => frequency = v ?? frequency),
            ),
            if (frequency == 'monthly')
              DropdownButtonFormField<int>(
                initialValue: weekOfMonth,
                decoration: InputDecoration(labelText: l.eduWeekOfMonth),
                items: [for (var w = 1; w <= 5; w++) DropdownMenuItem(value: w, child: Text(eduWeekOfMonthLabel(l, w)))],
                onChanged: (v) => setS(() => weekOfMonth = v ?? weekOfMonth),
              ),
            DropdownButtonFormField<String>(
              initialValue: program,
              decoration: InputDecoration(labelText: l.eduSessionFor),
              items: [
                DropdownMenuItem(value: 'all', child: Text(l.all)),
                DropdownMenuItem(value: 'regular', child: Text(l.programRegular)),
                DropdownMenuItem(value: 'distance', child: Text(l.programDistance)),
              ],
              onChanged: (v) => setS(() => program = v ?? program),
            ),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: InputDecoration(labelText: l.eduMode),
              items: [DropdownMenuItem(value: 'in_person', child: Text(l.eduInPerson)), DropdownMenuItem(value: 'online', child: Text(l.eduOnline))],
              onChanged: (v) => setS(() => mode = v ?? mode),
            ),
            if (courses.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: courseId,
                decoration: InputDecoration(labelText: l.eduCourses),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.none)),
                  for (final c in courses) DropdownMenuItem(value: asIntOr(c['id']), child: Text('${c['name']}')),
                ],
                onChanged: (v) => setS(() => courseId = v),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: starts);
                    if (t != null) setS(() => starts = t);
                  },
                  child: Text('${l.startsAt}: ${hhmm(starts)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: ends);
                    if (t != null) setS(() => ends = t);
                  },
                  child: Text('${l.endsAt}: ${hhmm(ends)}'),
                ),
              ),
            ]),
            TextField(controller: location, decoration: InputDecoration(labelText: l.location)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final items = [
      ...asJsonList(_class?['schedule']).map(_scheduleRow),
      {
        'course_id': courseId,
        'weekday': weekday,
        'frequency': frequency,
        'week_of_month': frequency == 'monthly' ? weekOfMonth : null,
        'program': program,
        'mode': mode,
        'starts': hhmm(starts),
        'ends': hhmm(ends),
        'location': location.text.trim().isEmpty ? null : location.text.trim(),
      },
    ];
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).setSchedule(_id!, items), success: l.saved);
    await _load();
  }

  /// A saved schedule row as sent back when the schedule is replaced (keeps every option).
  static Json _scheduleRow(Json s) => {
        'course_id': s['course_id'],
        'weekday': s['weekday'],
        'frequency': s['frequency'] ?? 'weekly',
        'week_of_month': s['week_of_month'],
        'program': s['program'] ?? 'all',
        'mode': s['mode'] ?? 'in_person',
        'starts': s['starts'],
        'ends': s['ends'],
        'location': s['location'],
      };

  Future<void> _removeScheduleRow(Json row) async {
    final items = [
      for (final s in asJsonList(_class?['schedule']))
        if (s['id'] != row['id']) _scheduleRow(s),
    ];
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).setSchedule(_id!, items));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final repo = ref.read(eduRepositoryProvider);
    final courses = asJsonList(_class?['courses']);
    final schedule = asJsonList(_class?['schedule']);
    return PatternScaffold(
      appBar: AppBar(
        title: Text(_id == null ? l.eduNewClass : (asStr(_class?['name']) ?? l.eduManage)),
        actions: [
          if (_id != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                final ok = await runWithProgress(context, () async {
                  await repo.deleteClass(_id!);
                  return true;
                }, success: l.deleted);
                if (ok == true && context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
                TextFormField(
                  controller: _name,
                  validator: (s) => (s ?? '').trim().isEmpty ? l.vRequired : null,
                  decoration: InputDecoration(labelText: '${l.title} (Amharic) *'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameEn,
                  decoration: const InputDecoration(labelText: 'Class Name (English)'),
                ),
                const SizedBox(height: 10),
                if (_academicYears.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: _academicYears.any((y) => asInt(y['id']) == _academicYearId) ? _academicYearId : null,
                    decoration: InputDecoration(labelText: l.eduAcademicYear),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                      for (final y in _academicYears)
                        DropdownMenuItem<int?>(
                          value: asInt(y['id']),
                          child: Text('${y['name']}${y['is_current'] == true ? ' (${l.eduCurrentYear})' : ''}'),
                        ),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _academicYearId = v;
                        _termId = null;
                        _terms = const [];
                      });
                      if (v != null) {
                        try {
                          final t = await ref.read(eduRepositoryProvider).terms(v);
                          if (mounted) setState(() => _terms = t);
                        } catch (_) {}
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (_terms.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: _terms.any((t) => asInt(t['id']) == _termId) ? _termId : null,
                    decoration: InputDecoration(labelText: l.eduTerm),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                      for (final t in _terms)
                        DropdownMenuItem<int?>(value: asInt(t['id']), child: Text('${t['name']}')),
                    ],
                    onChanged: (v) => setState(() => _termId = v),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_levels.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: _levels.any((lv) => asInt(lv['id']) == _levelId) ? _levelId : null,
                    decoration: InputDecoration(labelText: l.eduLevel),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                      for (final lv in _levels)
                        DropdownMenuItem<int?>(value: asInt(lv['id']), child: Text('${lv['name']}')),
                    ],
                    onChanged: (v) {
                      setState(() => _levelId = v);
                      if (v != null) {
                        _loadCurriculumPreview(v);
                      } else {
                        setState(() => _curriculumPreview = null);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_loadingCurriculum)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (_curriculumPreview != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.maroon.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 18, color: AppColors.gold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.isEn
                                      ? 'Official Curriculum (${_curriculumPreview!['grade_label'] ?? ''}): ${_curriculumPreview!['subjects_count'] ?? 0} Subjects'
                                      : 'ይፋዊ ስርዓተ-ትምህርት (${_curriculumPreview!['grade_label'] ?? ''})፡ ${_curriculumPreview!['subjects_count'] ?? 0} የትምህርት አይነቶች',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.isEn
                                ? 'These curriculum subjects will be automatically connected to this class. No duplicate course creation needed.'
                                : 'እነዚህ የስርዓተ-ትምህርት አይነቶች በራስ-ሰር ከዚህ ክፍል ጋር ይገናኛሉ። ድጋሚ ኮርስ መፍጠር አያስፈልግም።',
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final s in asJsonList(_curriculumPreview!['subjects']))
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: p.card,
                                  avatar: const Icon(Icons.book_rounded, size: 14, color: AppColors.maroon),
                                  label: Text(
                                    '${s['name']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.eduAllowMultiple),
                  subtitle: Text(l.eduAllowMultipleHint),
                  value: _allowMultiple,
                  onChanged: (v) => setState(() => _allowMultiple = v),
                ),
                TextFormField(controller: _streams, decoration: InputDecoration(labelText: l.eaStreams, helperText: l.eaStreamsHint)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desc,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: '${l.description} (Amharic)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descEn,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (English)'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.isEn ? 'Allow Student Self-Registration' : 'የተማሪዎች የቀጥታ ምዝገባ ይፈቀድ'),
                  subtitle: Text(l.isEn
                      ? 'When disabled, students are assigned by registrar / administrator only'
                      : 'ሲጠፋ ተማሪዎች የሚመደቡት በሬጅስትራር / አስተዳዳሪ ብቻ ይሆናል'),
                  value: _allowSelfRegistration,
                  onChanged: (v) => setState(() => _allowSelfRegistration = v),
                ),
                const SizedBox(height: 10),
                DateTimeField(label: l.eduRegOpens, value: _opens, clearable: true, onChanged: (d) => setState(() => _opens = d)),
                const SizedBox(height: 10),
                DateTimeField(
                  label: l.eduRegCloses,
                  value: _closes,
                  clearable: true,
                  errorText: _opens != null && _closes != null && _closes!.isBefore(_opens!) ? l.vEndBeforeStart : null,
                  onChanged: (d) => setState(() => _closes = d),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _capacity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.capacityLabel)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.programRegular), value: _regular, onChanged: (v) => setState(() => _regular = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.programDistance), value: _distance, onChanged: (v) => setState(() => _distance = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.active), value: _active, onChanged: (v) => setState(() => _active = v)),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.save),
                ),
                if (_id == null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.eduSaveFirst, textAlign: TextAlign.center, style: context.sans(12, color: p.muted))),
                if (_id != null) ...[
                  // ---- curriculum-connected courses & teachers
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: l.eduCourses),
                          if (_class?['curriculum'] != null)
                            Text(
                              l.isEn
                                  ? '${_class!['curriculum']['grade_label'] ?? "Grade"} Curriculum · ${courses.length} Subjects Connected'
                                  : '${_class!['curriculum']['grade_label'] ?? "ክፍል"} ስርዓተ-ትምህርት · ${courses.length} ትምህርቶች ተገናኝተዋል',
                              style: TextStyle(fontSize: 11, color: AppColors.maroon, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final res = await runWithProgress(
                          context,
                          () => repo.syncClassCurriculum(_id!),
                        );
                        if (res != null && mounted && context.mounted) {
                          final stats = res['sync_stats'] as Map<String, dynamic>?;
                          final connected = stats?['connected'] ?? courses.length;
                          final total = stats?['total_subjects'] ?? courses.length;
                          final grade = stats?['grade'] ?? _class?['level']?['name'] ?? '';
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: AppColors.goldLight),
                                  const SizedBox(width: 8),
                                  Text(l.isEn ? 'Curriculum Synced' : 'ስርዓተ-ትምህርት ተመሳስሏል'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.isEn
                                        ? 'Successfully synchronized class with official curriculum ($grade).'
                                        : 'ክፍሉ ከይፋዊው ስርዓተ-ትምህርት ($grade) ጋር በተሳካ ሁኔታ ተመሳስሏል።',
                                  ),
                                  const SizedBox(height: 12),
                                  Text('• ${l.isEn ? "Connected Subjects" : "የተገናኙ ትምህርቶች"}: $connected / $total'),
                                  Text('• ${l.isEn ? "Student enrollments & records" : "የተማሪዎች ምዝገባ እና መረጃዎች"}: ${l.isEn ? "Preserved" : "ተጠብቀዋል"}'),
                                ],
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(l.ok),
                                ),
                              ],
                            ),
                          );
                        }
                        await _load();
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: Text(l.isEn ? 'Sync Curriculum' : 'ስርዓተ-ትምህርት አመሳስል'),
                    ),
                  ]),
                  if (courses.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.eduNoCourses, style: context.sans(13, color: p.muted)),
                          const SizedBox(height: 6),
                          Text(
                            l.isEn
                                ? 'Courses for this class are automatically derived from the official curriculum for its grade. Click "Sync Curriculum" or verify the grade level.'
                                : 'የዚህ ክፍል ኮርሶች በቀጥታ ከክፍሉ ይፋዊ ስርዓተ-ትምህርት የሚወሰዱ ናቸው። "ስርዓተ-ትምህርት አመሳስል" የሚለውን ይጫኑ ወይም የክፍሉን ደረጃ ያረጋግጡ።',
                            style: TextStyle(fontSize: 11, color: p.muted),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/edu/content'),
                            icon: const Icon(Icons.auto_stories_outlined, size: 16),
                            label: Text(l.isEn ? 'Manage Curriculum' : 'ስርዓተ-ትምህርት አስተዳድር'),
                          ),
                        ],
                      ),
                    ),
                  for (final c in courses)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: AppColors.maroon, size: 20),
                      ),
                      title: Text(
                        '${c['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (asStr(c['code']) != null) asStr(c['code'])!,
                              if (asJson(c['curriculum_subject'])['units_count'] != null)
                                '${asJson(c['curriculum_subject'])['units_count']} ${l.isEn ? "units" : "ምዕራፎች"} · ${asJson(c['curriculum_subject'])['lessons_count'] ?? 0} ${l.isEn ? "lessons" : "ትምህርቶች"}',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 13, color: p.muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  asStr(asJson(c['teacher'])['full_name']) ?? l.eduNoTeacher,
                                  style: TextStyle(fontSize: 11, color: asStr(asJson(c['teacher'])['full_name']) != null ? AppColors.maroon : p.muted),
                                ),
                              ),
                              if (c['status'] != null && c['status'] != 'active')
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: p.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    c['status'] == 'archived' ? l.eaArchived : l.inactive,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.eaTeachers,
                            icon: const Icon(Icons.groups_2_outlined),
                            onPressed: () async {
                              await showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useRootNavigator: true,
                                builder: (_) => EduCourseTeachersSheet(courseId: asIntOr(c['id']), courseName: '${c['name']}'),
                              );
                              await _load();
                            },
                          ),
                          const Icon(Icons.settings_outlined, size: 18),
                        ],
                      ),
                      onTap: () => _editCourse(c),
                    ),
                  // ---- weekly schedule
                  Row(children: [
                    Expanded(child: SectionHeader(title: l.eduSchedule)),
                    TextButton.icon(onPressed: _addScheduleRow, icon: const Icon(Icons.add_rounded), label: Text(l.eduAddSession)),
                  ]),
                  if (schedule.isEmpty) Text(l.eduNoSchedule, style: context.sans(13, color: p.muted)),
                  for (final s in schedule)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded, color: AppColors.gold),
                      title: Text('${eduScheduleDayText(l, s)} · ${s['starts']}–${s['ends']}'),
                      subtitle: Text([
                        if (asStr(s['course_name']) != null) asStr(s['course_name'])!,
                        if (s['program'] == 'regular') l.programRegular,
                        if (s['program'] == 'distance') l.programDistance,
                        if (s['mode'] == 'online') l.eduOnline,
                        if (asStr(s['location']) != null) asStr(s['location'])!,
                      ].join(' · ')),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _removeScheduleRow(s)),
                    ),
                  // ---- attendance takers
                  Row(children: [
                    Expanded(child: SectionHeader(title: l.eduAttendanceTakers)),
                    TextButton.icon(
                      onPressed: () async {
                        final sel = await pickUsers(context, multiple: false, title: l.eduAttendanceTakers);
                        if (sel == null || sel.ids.isEmpty || !context.mounted) return;
                        await runWithProgress(context, () => repo.addStaff(_id!, sel.ids.first), success: l.saved);
                        await _load();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(l.add),
                    ),
                  ]),
                  if (_staff.isEmpty) Text(l.eduNoTakers, style: context.sans(13, color: p.muted)),
                  for (final s in _staff)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fact_check_rounded, color: AppColors.gold),
                      title: Text('${s['full_name']}'),
                      subtitle: Text('${s['phone'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                        onPressed: () async {
                          await runWithProgress(context, () => repo.removeStaff(_id!, asIntOr(s['id'])));
                          await _load();
                        },
                      ),
                    ),
                  // ---- students
                  SectionHeader(title: '${l.eduStudents} (${asIntOr(_class?['student_count'])})'),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ClassStudentsScreen(classId: _id!, className: asStr(_class?['name'])))),
                    icon: const Icon(Icons.groups_rounded),
                    label: Text(l.eduViewStudents),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/edu/manage/class/$_id/assign?name=${Uri.encodeComponent(asStr(_class?['name']) ?? '')}');
                      await _load();
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(l.eduAssignStudents),
                  ),
                ],
              ]),
            ),
    );
  }
}

class _ClassStudentsScreen extends ConsumerStatefulWidget {
  const _ClassStudentsScreen({required this.classId, this.className});
  final int classId;
  final String? className;
  @override
  ConsumerState<_ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<_ClassStudentsScreen> {
  final _ctrl = PagedListController<Json>();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(eduRepositoryProvider);
    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.eduStudents),
        actions: [
          IconButton(
            tooltip: l.eduAssignStudents,
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () async {
              await context.push('/edu/manage/class/${widget.classId}/assign?name=${Uri.encodeComponent(widget.className ?? '')}');
              _ctrl.refresh();
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_q),
            controller: _ctrl,
            fetch: (page) => repo.students(widget.classId, q: _q.isEmpty ? null : _q, page: page),
            emptyMessage: l.eduNoStudents,
            itemBuilder: (context, s, _) => TrackTile(
              title: '${s['full_name']}',
              subtitle: [programLabel(l, asStr(s['program'])), if (s['phone'] != null) '${s['phone']}'].join(' · '),
              leading: const ListThumb(icon: Icons.person_rounded),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l.eduTransferStudent,
                    icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.gold),
                    onPressed: () async {
                      final enrollmentId = asInt(s['enrollment_id']) ?? asInt(s['id']);
                      if (enrollmentId == null) return;
                      final ok = await showTransferDialog(
                        context,
                        ref,
                        enrollmentId: enrollmentId,
                        studentName: '${s['full_name']}',
                        currentClassId: widget.classId,
                      );
                      if (ok) _ctrl.refresh();
                    },
                  ),
                  IconButton(
                    tooltip: l.eduRemoveStudent,
                    icon: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
                    onPressed: () async {
                      if (!await showConfirm(context, l.eduRemoveStudentConfirm, destructive: true) || !context.mounted) return;
                      await runWithProgress(context, () => repo.removeStudent(widget.classId, asIntOr(s['user_id'])), success: l.saved);
                      await _ctrl.refresh();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


