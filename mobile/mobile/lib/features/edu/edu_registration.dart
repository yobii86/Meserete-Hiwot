import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../members/member_form.dart' show memberGroupLabel;
import 'edu_academics.dart' show EduCourseTeachersSheet;
import 'edu_screens.dart' show programLabel;
import 'edu_formatters.dart';
import '../../core/member_groups.dart';

final _regClassesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(libraryRepositoryProvider).registrationClasses());
final _regStudentsProvider = FutureProvider.autoDispose.family<List<Json>, int>((ref, id) => ref.watch(libraryRepositoryProvider).registeredStudents(id));

/// Student registration (education.register — the registrar — or education.manage): choose a class
/// with its courses, then register existing members or create a new member account (a temporary
/// 6-digit PIN is shown once) into it.
class EduRegistrationScreen extends ConsumerStatefulWidget {
  const EduRegistrationScreen({super.key});
  @override
  ConsumerState<EduRegistrationScreen> createState() => _EduRegistrationScreenState();
}

class _EduRegistrationScreenState extends ConsumerState<EduRegistrationScreen> {
  int? _classId;
  String _program = 'regular';

  Future<void> _submit(Json klass, Json body) async {
    final l = context.l10n;
    final r = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).register({'class_id': klass['id'], 'program': _program, ...body}));
    if (r == null || !mounted) return;
    ref.invalidate(_regStudentsProvider(asIntOr(klass['id'])));
    ref.invalidate(_regClassesProvider);
    final already = asIntOr(r['already_enrolled']);
    showSnack(context, [l.regDone('${asIntOr(r['registered'])}'), if (already > 0) l.regAlready('$already')].join(' · '));
    final pin = asStr(r['temporary_pin']);
    if (pin != null) await _showPin(asStr(asJson(r['new_user'])['full_name']) ?? '', pin);
  }

  Future<void> _showPin(String name, String pin) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.regTempPin),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(name, style: ctx.sans(14, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          SelectableText(pin, key: const ValueKey('reg-temp-pin'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6)),
          const SizedBox(height: 10),
          Text(l.regTempPinHint, style: ctx.sans(12, color: ctx.palette.muted)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok))],
      ),
    );
  }

  Future<void> _existing(Json klass) async {
    final l = context.l10n;
    final sel = await pickUsers(context, title: l.regExisting);
    if (sel == null || sel.ids.isEmpty || !mounted) return;
    await _submit(klass, {'user_ids': sel.ids.toList()});
  }

  Future<void> _newMember(Json klass) async {
    final body = await showDialog<Json>(context: context, builder: (_) => const _NewMemberDialog());
    if (body == null || !mounted) return;
    await _submit(klass, {'new_user': body});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return AdminScaffold(
      title: l.regTitle,
      actions: const [
        ContextualHelpButton(screenRoute: '/edu'),
      ],
      body: AsyncView(
        value: ref.watch(_regClassesProvider),
        onRetry: () => ref.invalidate(_regClassesProvider),
        data: (classes) {
          if (classes.isEmpty) return EmptyView(message: l.regNoClasses, icon: Icons.school_outlined);
          final klass = classes.firstWhere((c) => asIntOr(c['id']) == _classId, orElse: () => classes.first);
          final id = asIntOr(klass['id']);
          final regular = klass['allow_regular'] != false;
          final distance = klass['allow_distance'] == true;
          if (!regular && _program == 'regular') _program = 'distance';
          if (!distance && _program == 'distance') _program = 'regular';
          final courses = asJsonList(klass['courses']);
          final cap = asInt(klass['capacity']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Text(l.regSubtitle, style: context.sans(13, color: p.muted)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: const ValueKey('reg-class'),
              initialValue: id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.regChooseClass),
              items: [
                for (final c in classes)
                  DropdownMenuItem(
                    value: asIntOr(c['id']),
                    child: Text(
                      eduClassSubtitle(c, l).isNotEmpty
                          ? '${eduClassName(c)} · ${eduClassSubtitle(c, l)}'
                          : eduClassName(c),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _classId = v),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.regCourses, style: context.sans(12, color: p.muted, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (courses.isEmpty) Text('—', style: context.sans(13)),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in courses) Pill([c['name'], ?asStr(c['teacher_name'])].join(' · '), color: AppColors.goldDark),
                ]),
                const SizedBox(height: 8),
                Text(cap != null ? '${asIntOr(klass['student_count'])} / $cap' : l.eduStudentCount(asIntOr(klass['student_count'])), style: context.sans(12, color: p.subtle)),
              ]),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                if (regular) ButtonSegment(value: 'regular', label: Text(programLabel(l, 'regular'))),
                if (distance) ButtonSegment(value: 'distance', label: Text(programLabel(l, 'distance'))),
              ],
              selected: {_program},
              onSelectionChanged: (s) => setState(() => _program = s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(key: const ValueKey('reg-existing'), onPressed: () => _existing(klass), icon: const Icon(Icons.group_add_rounded, size: 18), label: Text(l.regExisting)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(key: const ValueKey('reg-new'), onPressed: () => _newMember(klass), icon: const Icon(Icons.person_add_alt_rounded, size: 18), label: Text(l.regNewMember)),
              ),
            ]),
            SectionHeader(title: l.regStudents),
            AsyncView(
              value: ref.watch(_regStudentsProvider(id)),
              onRetry: () => ref.invalidate(_regStudentsProvider(id)),
              loading: const LoadingView(padding: EdgeInsets.all(24)),
              data: (students) => students.isEmpty
                  ? Padding(padding: const EdgeInsets.all(8), child: Text(l.eduStudentCount(0), style: context.sans(13, color: p.muted)))
                  : Column(children: [
                      for (final s in students)
                        TrackTile(
                          title: '${s['full_name']}',
                          subtitle: [?asStr(s['member_id']), ?asStr(s['phone']), programLabel(l, asStr(s['program']))].join(' · '),
                          leading: const ListThumb(icon: Icons.person_rounded),
                          trailing: IconButton(
                            tooltip: l.remove,
                            icon: const Icon(Icons.person_remove_alt_1_outlined, color: AppColors.danger),
                            onPressed: () async {
                              if (!await showConfirm(context, l.regRemoveConfirm) || !context.mounted) return;
                              final x = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).unregister(id, asIntOr(s['id'])));
                              if (x != null) {
                                ref.invalidate(_regStudentsProvider(id));
                                ref.invalidate(_regClassesProvider);
                              }
                            },
                          ),
                        ),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _NewMemberDialog extends StatefulWidget {
  const _NewMemberDialog();
  @override
  State<_NewMemberDialog> createState() => _NewMemberDialogState();
}

class _NewMemberDialogState extends State<_NewMemberDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _group = 'youth_adult';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.regNewMember),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            key: const ValueKey('reg-new-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l.fullName),
            validator: (v) => (v ?? '').trim().length < 2 ? l.required : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('reg-new-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.phone),
            validator: (v) => (v ?? '').trim().length < 9 ? l.required : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _group,
            decoration: InputDecoration(labelText: l.memberGroup),
            items: [for (final g in MemberGroups.keys()) DropdownMenuItem(value: g, child: Text(memberGroupLabel(l, g)))],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('reg-new-save'),
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop(context, {'full_name': _name.text.trim(), 'phone': _phone.text.trim(), 'member_group': _group});
          },
          child: Text(l.regNewMember),
        ),
      ],
    );
  }
}

/// Every course of every active class (teacher, class); supports Grade 1-12 filtering,
/// direct course editing with pre-populated fields, and teacher assignments.
class EduCoursesScreen extends ConsumerStatefulWidget {
  const EduCoursesScreen({super.key});

  @override
  ConsumerState<EduCoursesScreen> createState() => _EduCoursesScreenState();
}

class _EduCoursesScreenState extends ConsumerState<EduCoursesScreen> {
  int? _selectedClassId;

  Future<void> _editCourse(Json course) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final courseId = asIntOr(course['id']);
    final name = TextEditingController(text: asStr(course['name']) ?? '');
    final code = TextEditingController(text: asStr(course['code']) ?? '');
    var status = asStr(course['status']) ?? 'active';
    var mode = asStr(course['mode']) ?? 'physical';
    var passMark = TextEditingController(text: course['pass_mark'] != null ? '${course['pass_mark']}' : '50');
    int? teacherId = asInt(course['teacher_user_id']) ?? asInt(asJson(course['teacher'])['id']);
    String? teacherName = asStr(course['teacher_name']) ?? asStr(asJson(course['teacher'])['full_name']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(isEn ? 'Edit Course Offering' : 'የኮርስ መረጃ ማስተካከያ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: isEn ? 'Course Name' : 'የኮርሱ ስም',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: isEn ? 'Course Code' : 'የኮርሱ መለያ ኮድ',
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              TextField(
                controller: passMark,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.eduPassMark,
                  hintText: '50',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.co_present_rounded, color: AppColors.maroon),
                title: Text(teacherName ?? (isEn ? 'No teacher assigned' : 'አስተማሪ አልተመደበም')),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final repo = ref.read(eduRepositoryProvider);
    final body = {
      'name': name.text.trim().isNotEmpty ? name.text.trim() : course['name'],
      'code': code.text.trim().isEmpty ? null : code.text.trim(),
      'status': status,
      'mode': mode,
      'pass_mark': double.tryParse(passMark.text.trim()) ?? 50.0,
      'teacher_user_id': teacherId,
    };

    await runWithProgress(
      context,
      () => repo.updateCourse(courseId, body),
      success: l.saved,
    );
    ref.invalidate(_regClassesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final canManage = ref.watch(currentUserProvider)?.can(Perm.educationManage) ?? false;

    return AdminScaffold(
      title: isEn ? 'Courses & Teacher Assignments' : 'የኮርሶች እና የአስተማሪዎች ምደባ',
      body: AsyncView(
        value: ref.watch(_regClassesProvider),
        onRetry: () => ref.invalidate(_regClassesProvider),
        data: (classes) {
          final filteredClasses = _selectedClassId == null
              ? classes
              : classes.where((c) => asIntOr(c['id']) == _selectedClassId).toList();

          final rows = [
            for (final c in filteredClasses)
              for (final co in asJsonList(c['courses'])) (klass: c, course: co),
          ];

          return Column(
            children: [
              if (classes.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(isEn ? 'All Grades (1–12)' : 'ሁሉም ክፍሎች (1–12)'),
                        selected: _selectedClassId == null,
                        onSelected: (_) => setState(() => _selectedClassId = null),
                        selectedColor: AppColors.maroon.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.maroon,
                      ),
                      const SizedBox(width: 8),
                      for (final c in classes)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${c['name']}'),
                            selected: _selectedClassId == asIntOr(c['id']),
                            onSelected: (sel) => setState(() => _selectedClassId = sel ? asIntOr(c['id']) : null),
                            selectedColor: AppColors.maroon.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.maroon,
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: rows.isEmpty
                    ? EmptyView(message: l.eduNoCourses, icon: Icons.menu_book_outlined)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final r in rows)
                            TrackTile(
                              key: ValueKey('course-${r.course['id']}'),
                              title: '${r.course['name']}',
                              subtitle: [
                                r.klass['name'],
                                (asStr(r.course['teacher_name']) != null && asStr(r.course['teacher_name'])!.isNotEmpty)
                                    ? (isEn ? 'Teacher: ${r.course['teacher_name']}' : 'አስተማሪ፡ ${r.course['teacher_name']}')
                                    : (isEn ? 'No teacher assigned' : 'አስተማሪ አልተመደበም'),
                              ].join(' · '),
                              leading: const ListThumb(icon: Icons.menu_book_rounded, active: true),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canManage)
                                    IconButton(
                                      tooltip: isEn ? 'Edit Course' : 'ኮርስ አርትዕ',
                                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.maroon, size: 22),
                                      onPressed: () => _editCourse(r.course),
                                    ),
                                  if (canManage)
                                    IconButton(
                                      tooltip: isEn ? 'Assign Teachers' : 'አስተማሪ መመደብ',
                                      icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.goldDark, size: 20),
                                      onPressed: () async {
                                        await showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => EduCourseTeachersSheet(
                                            courseId: asIntOr(r.course['id']),
                                            courseName: '${r.course['name']}',
                                          ),
                                        );
                                        ref.invalidate(_regClassesProvider);
                                      },
                                    ),
                                  if (canManage)
                                    IconButton(
                                      tooltip: isEn ? 'Edit Class' : 'ክፍል አርትዕ',
                                      icon: const Icon(Icons.tune_rounded, size: 20),
                                      onPressed: () async {
                                        await context.push('/edu/manage/class/${r.klass['id']}');
                                        ref.invalidate(_regClassesProvider);
                                      },
                                    ),
                                ],
                              ),
                              onTap: canManage ? () => _editCourse(r.course) : null,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
