import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../admin/edit_mode.dart' show contentRevisionProvider;
import '../../auth/session.dart' show currentUserProvider;
import 'edu_widgets.dart';
import 'learn_screens.dart' show eduCategoriesProvider, eduSubjectProvider;

/// Dedicated Units & Lessons Management screen for Education Admin Panel.
/// Allows direct viewing, editing, adding, and outlining units and lessons per curriculum subject.
class EduUnitsLessonsAdminScreen extends ConsumerStatefulWidget {
  const EduUnitsLessonsAdminScreen({super.key, this.initialSubjectId});
  final int? initialSubjectId;

  @override
  ConsumerState<EduUnitsLessonsAdminScreen> createState() => _EduUnitsLessonsAdminScreenState();
}

class _EduUnitsLessonsAdminScreenState extends ConsumerState<EduUnitsLessonsAdminScreen> {
  int? _selectedSubjectId;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
  }

  void _reloadSubject() {
    if (_selectedSubjectId != null) {
      ref.invalidate(eduSubjectProvider(_selectedSubjectId!));
      ref.invalidate(eduCategoriesProvider);
      ref.read(contentRevisionProvider.notifier).bump();
    }
  }

  Future<void> _deleteUnit(int unitId, String title) async {
    final l = context.l10n;
    final confirmed = await showConfirm(
      context,
      l.isEn ? 'Delete unit "$title"? Lessons will be moved to unassigned.' : 'ምዕራፍ "$title" ይሰረዝ? ትምህርቶቹ ወደ ያልተመደቡ ይዛወራሉ።',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteUnit(unitId));
    _reloadSubject();
  }

  Future<void> _deleteLesson(int lessonId, String title) async {
    final l = context.l10n;
    final confirmed = await showConfirm(
      context,
      l.isEn ? 'Delete lesson "$title"? All materials will be removed.' : 'ትምህርት "$title" ይሰረዝ? ሁሉም ተያያዥ ማጣቀሻዎች ይወገዳሉ።',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteLesson(lessonId));
    _reloadSubject();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;
    final user = ref.watch(currentUserProvider);
    final canEdit = user?.canAny([Perm.educationContent, Perm.educationManage]) ?? false;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Units & Lessons' : 'ምዕራፎች እና ትምህርቶች'),
        actions: [
          if (_selectedSubjectId != null && canEdit)
            IconButton(
              tooltip: isEn ? 'Preview Subject' : 'የትምህርቱን ገጽ እይ',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => context.push('/edu/learn/subject/$_selectedSubjectId'),
            ),
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(eduCategoriesProvider);
              _reloadSubject();
            },
          ),
        ],
      ),
      floatingActionButton: (_selectedSubjectId != null && canEdit)
          ? FloatingActionButton.extended(
              heroTag: 'add-unit-or-lesson',
              backgroundColor: AppColors.maroon,
              foregroundColor: AppColors.goldLight,
              icon: const Icon(Icons.add_rounded),
              label: Text(isEn ? 'New Lesson' : 'አዲስ ትምህርት'),
              onPressed: () async {
                await context.push('/edu/content/subject/$_selectedSubjectId/new-lesson');
                _reloadSubject();
              },
            )
          : null,
      body: FutureBuilder<List<Json>>(
        future: ref.read(eduRepositoryProvider).subjects(all: true),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() {}));
          if (!snap.hasData) return const LoadingView();

          final subjects = snap.data!;
          if (subjects.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.menu_book_rounded,
                message: isEn ? 'No subjects created yet. Add subjects first.' : 'ምንም የትምህርት ዓይነቶች አልተፈጠሩም። መጀመሪያ የትምህርት ዓይነት ያክሉ።',
              ),
            );
          }

          // Categories list
          final categories = <String>[];
          for (final s in subjects) {
            final cat = asStr(s['category_name']) ?? (isEn ? 'Other' : 'ሌሎች');
            if (!categories.contains(cat)) categories.add(cat);
          }

          // Pick the first subject if none selected
          if (_selectedSubjectId == null || !subjects.any((s) => s['id'] == _selectedSubjectId)) {
            _selectedSubjectId = asInt(subjects.first['id']);
          }

          final currentSub = subjects.firstWhere(
            (s) => s['id'] == _selectedSubjectId,
            orElse: () => subjects.first,
          );
          final currentCat = asStr(currentSub['category_name']) ?? (isEn ? 'Other' : 'ሌሎች');
          _selectedCategory ??= currentCat;

          // Filter subjects for the selected category
          final visibleSubjects = subjects.where((s) {
            final cat = asStr(s['category_name']) ?? (isEn ? 'Other' : 'ሌሎች');
            return cat == _selectedCategory;
          }).toList();

          return Column(
            children: [
              // 1. Category and Grade selector bar
              Container(
                color: p.card,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category row
                    Row(
                      children: [
                        Icon(Icons.category_outlined, size: 16, color: AppColors.goldDark),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Subject:' : 'የትምህርት ዓይነት፦',
                          style: context.sans(12, weight: FontWeight.w600, color: p.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = categories[i];
                          final isSelected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppColors.maroon,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : p.text,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = cat;
                                final firstInCat = subjects.firstWhere(
                                  (s) => (asStr(s['category_name']) ?? (isEn ? 'Other' : 'ሌሎች')) == cat,
                                  orElse: () => subjects.first,
                                );
                                _selectedSubjectId = asInt(firstInCat['id']);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grade subjects row
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 16, color: AppColors.goldDark),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Grade / Subject (1 - 12):' : 'ክፍል / የትምህርት ዓይነት ይምረጡ፦',
                          style: context.sans(12, weight: FontWeight.w600, color: p.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleSubjects.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final sub = visibleSubjects[i];
                          final id = asInt(sub['id']);
                          final isSelected = id == _selectedSubjectId;
                          final name = eduNames(context, sub).title;
                          final lessonCount = asIntOr(sub['lesson_count']);

                          return ChoiceChip(
                            label: Text('$name ($lessonCount)'),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.maroonDark : p.text,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedSubjectId = id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Search filter bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search lessons or units...' : 'ትምህርቶችን ወይም ምዕራፎችን ፈልግ...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                ),
              ),

              // 3. Subject content details: Units & Lessons
              Expanded(
                child: _selectedSubjectId == null
                    ? const SizedBox()
                    : Consumer(
                        builder: (context, ref, _) {
                          final subjectAsync = ref.watch(eduSubjectProvider(_selectedSubjectId!));
                          return AsyncView(
                            value: subjectAsync,
                            onRetry: _reloadSubject,
                            data: (sub) {
                              final units = asJsonList(sub['units']);
                              final looseLessons = asJsonList(sub['lessons']);

                              final filteredUnits = units.where((u) {
                                if (_searchQuery.isEmpty) return true;
                                final title = asStr(u['title'])?.toLowerCase() ?? '';
                                final desc = asStr(u['description'])?.toLowerCase() ?? '';
                                final lessons = asJsonList(u['lessons']);
                                final matchesLesson = lessons.any((l) => (asStr(l['title'])?.toLowerCase() ?? '').contains(_searchQuery));
                                return title.contains(_searchQuery) || desc.contains(_searchQuery) || matchesLesson;
                              }).toList();

                              final filteredLoose = looseLessons.where((l) {
                                if (_searchQuery.isEmpty) return true;
                                final title = asStr(l['title'])?.toLowerCase() ?? '';
                                return title.contains(_searchQuery);
                              }).toList();

                              if (filteredUnits.isEmpty && filteredLoose.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      EmptyView(
                                        icon: Icons.menu_book_outlined,
                                        message: _searchQuery.isEmpty
                                            ? (isEn ? 'No units or lessons outline yet.' : 'ምንም የተዘጋጀ ምዕራፍ ወይም ትምህርት የለም።')
                                            : (isEn ? 'No matching lessons found.' : 'ምንም የተገኘ ትምህርት የለም።'),
                                      ),
                                      if (canEdit) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            FilledButton.tonalIcon(
                                              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                                              label: Text(isEn ? 'Create Unit' : 'አዲስ ምዕራፍ'),
                                              onPressed: () async {
                                                await context.push('/edu/content/unit/new?subject_id=$_selectedSubjectId');
                                                _reloadSubject();
                                              },
                                            ),
                                            const SizedBox(width: 10),
                                            FilledButton.icon(
                                              style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                                              icon: const Icon(Icons.add_rounded, size: 18),
                                              label: Text(isEn ? 'Create Lesson' : 'አዲስ ትምህርት'),
                                              onPressed: () async {
                                                await context.push('/edu/content/subject/$_selectedSubjectId/new-lesson');
                                                _reloadSubject();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }

                              return RefreshIndicator(
                                onRefresh: () async => _reloadSubject(),
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                                  children: [
                                    // Quick subject summary & Unit creation button
                                    if (canEdit)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isEn
                                                    ? '${units.length} Units · ${sub['lesson_count'] ?? 0} Total Lessons'
                                                    : '${units.length} ምዕራፎች · ${sub['lesson_count'] ?? 0} ጠቅላላ ትምህርቶች',
                                                style: context.sans(12.5, weight: FontWeight.w600, color: p.muted),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.create_new_folder_rounded, size: 16),
                                              label: Text(isEn ? 'Add Unit' : 'ምዕራፍ አክል', style: context.sans(12)),
                                              onPressed: () async {
                                                await context.push('/edu/content/unit/new?subject_id=$_selectedSubjectId');
                                                _reloadSubject();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Units List
                                    for (var uIdx = 0; uIdx < filteredUnits.length; uIdx++) ...[
                                      _UnitCard(
                                        unit: filteredUnits[uIdx],
                                        index: uIdx + 1,
                                        subjectId: _selectedSubjectId!,
                                        canEdit: canEdit,
                                        onEditUnit: () async {
                                          await context.push('/edu/content/unit/${filteredUnits[uIdx]['id']}?subject_id=$_selectedSubjectId');
                                          _reloadSubject();
                                        },
                                        onDeleteUnit: () => _deleteUnit(
                                          asIntOr(filteredUnits[uIdx]['id']),
                                          asStr(filteredUnits[uIdx]['title']) ?? '',
                                        ),
                                        onAddLesson: () async {
                                          await context.push(
                                            '/edu/content/lesson/new?subject_id=$_selectedSubjectId&unit_id=${filteredUnits[uIdx]['id']}',
                                          );
                                          _reloadSubject();
                                        },
                                        onEditLesson: (lessonId) async {
                                          await context.push('/edu/content/lesson/$lessonId');
                                          _reloadSubject();
                                        },
                                        onDeleteLesson: (lessonId, title) => _deleteLesson(lessonId, title),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    // Loose Lessons (unassigned to any unit)
                                    if (filteredLoose.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.folder_off_outlined, size: 18, color: p.muted),
                                          const SizedBox(width: 8),
                                          Text(
                                            isEn ? 'Lessons Without Unit' : 'ያልተመደቡ ትምህርቶች',
                                            style: context.serif(14, weight: FontWeight.w700, color: p.muted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      for (final lsn in filteredLoose)
                                        _LessonTile(
                                          lesson: lsn,
                                          canEdit: canEdit,
                                          onTap: () async {
                                            await context.push('/edu/content/lesson/${lsn['id']}');
                                            _reloadSubject();
                                          },
                                          onDelete: () => _deleteLesson(asIntOr(lsn['id']), asStr(lsn['title']) ?? ''),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.index,
    required this.subjectId,
    required this.canEdit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onDeleteLesson,
  });

  final Json unit;
  final int index;
  final int subjectId;
  final bool canEdit;
  final VoidCallback onEditUnit;
  final VoidCallback onDeleteUnit;
  final VoidCallback onAddLesson;
  final void Function(int lessonId) onEditLesson;
  final void Function(int lessonId, String title) onDeleteLesson;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final isEn = l.isEn;
    final title = asStr(unit['title']) ?? '';
    final summary = asStr(unit['description']);
    final lessons = asJsonList(unit['lessons']);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEn ? 'Unit $index' : 'ምዕራፍ $index',
                    style: context.sans(11.5, weight: FontWeight.w700, color: AppColors.maroon),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.serif(15, weight: FontWeight.w700, color: p.text),
                      ),
                      if (summary != null && summary.isNotEmpty)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(11.5, color: p.muted),
                        ),
                    ],
                  ),
                ),
                if (canEdit) ...[
                  IconButton(
                    tooltip: isEn ? 'Edit Unit' : 'ምዕራፉን አርትዕ',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEditUnit,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onSelected: (v) {
                      if (v == 'delete') onDeleteUnit();
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Lessons list inside Unit
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    isEn ? 'No lessons in this unit yet.' : 'በዚህ ምዕራፍ ውስጥ ምንም ትምህርት የለም።',
                    style: context.sans(12, color: p.muted),
                  ),
                  const Spacer(),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: onAddLesson,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(isEn ? 'Add Lesson' : 'ትምህርት አክል', style: context.sans(12)),
                    ),
                ],
              ),
            )
          else ...[
            for (var lIdx = 0; lIdx < lessons.length; lIdx++)
              _LessonTile(
                lesson: lessons[lIdx],
                canEdit: canEdit,
                onTap: () => onEditLesson(asIntOr(lessons[lIdx]['id'])),
                onDelete: () => onDeleteLesson(
                  asIntOr(lessons[lIdx]['id']),
                  asStr(lessons[lIdx]['title']) ?? '',
                ),
              ),
            if (canEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAddLesson,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(isEn ? 'Add Lesson to Unit' : 'ወደዚህ ምዕራፍ ትምህርት አክል', style: context.sans(12)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.canEdit,
    required this.onTap,
    required this.onDelete,
  });

  final Json lesson;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final isEn = l.isEn;
    final title = asStr(lesson['title']) ?? '';
    final status = asStr(lesson['status']) ?? 'draft';
    final minutes = asInt(lesson['est_minutes']);
    final materialCount = asIntOr(lesson['material_count']);
    final hasQuiz = asBool(lesson['requires_quiz']) || asIntOr(lesson['quiz_count']) > 0;

    final isPublished = status == 'published';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              isPublished ? Icons.article_rounded : Icons.edit_note_rounded,
              size: 20,
              color: isPublished ? AppColors.goldDark : p.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.sans(13.5, weight: FontWeight.w600, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isPublished ? AppColors.success.withValues(alpha: 0.15) : p.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPublished
                              ? (isEn ? 'Published' : 'የታተመ')
                              : (isEn ? 'Draft' : 'ረቂቅ'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isPublished ? AppColors.success : p.muted,
                          ),
                        ),
                      ),
                      if (minutes != null && minutes > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          isEn ? '$minutes min' : '$minutes ደቂቃ',
                          style: context.sans(11, color: p.muted),
                        ),
                      ],
                      if (materialCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.attach_file_rounded, size: 13, color: p.muted),
                        Text(
                          '$materialCount',
                          style: context.sans(11, color: p.muted),
                        ),
                      ],
                      if (hasQuiz) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.quiz_rounded, size: 13, color: AppColors.maroon),
                        const SizedBox(width: 2),
                        Text(
                          isEn ? 'Quiz' : 'ፈተና',
                          style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onDelete,
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.faint),
          ],
        ),
      ),
    );
  }
}
