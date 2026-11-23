import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_links.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../admin/edit_mode.dart';
import '../../guidance/contextual_help_sheet.dart';
import 'content_admin.dart' show showEduCategoryEditor, showEduSubjectEditor;
import 'edu_home.dart' show eduDashboardProvider;
import '../edu_formatters.dart';
import 'edu_widgets.dart';

final eduCategoriesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(eduRepositoryProvider).categories());
final _allSubjectsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(eduRepositoryProvider).subjects());
final _categorySubjectsProvider = FutureProvider.autoDispose.family<List<Json>, int>((ref, id) => ref.watch(eduRepositoryProvider).categorySubjects(id));
final eduSubjectProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(eduRepositoryProvider).subject(id));
final eduLessonProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(eduRepositoryProvider).lesson(id));

// =============================================================================
// Learn tab: my subjects, every category, subjects without a category
// =============================================================================
class EduLearnScreen extends ConsumerWidget {
  const EduLearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    Future<void> refresh() async {
      ref.invalidate(eduCategoriesProvider);
      ref.invalidate(_allSubjectsProvider);
    }

    return PatternScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.elTabLearn),
        actions: const [
          EditModeToggle(module: 'edu'),
          ContextualHelpButton(screenRoute: '/edu/learn'),
        ],
      ),
      floatingActionButton: EditModeAddButton(
        actions: [
          (
            label: l.isEn ? 'Add Subject' : 'አዲስ የትምህርት ዓይነት',
            icon: Icons.menu_book_rounded,
            permission: Perm.educationContent,
            run: () async {
              final id = await showEduSubjectEditor(context);
              if (id != null && context.mounted) {
                ref.invalidate(_allSubjectsProvider);
                ref.invalidate(eduCategoriesProvider);
                context.push('/edu/learn/subject/$id');
              }
            },
          ),
          (
            label: l.isEn ? 'Add Category' : 'አዲስ ምድብ',
            icon: Icons.category_rounded,
            permission: Perm.educationContent,
            run: () async {
              final saved = await showEduCategoryEditor(context);
              if (saved == true) {
                ref.invalidate(eduCategoriesProvider);
                ref.invalidate(eduDashboardProvider);
                ref.read(contentRevisionProvider.notifier).bump();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const EditModeBanner(module: 'edu'),
            const SizedBox(height: 8),
            // Search field look-alike: opens the Education search.
            Material(
              color: p.fill,
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () => context.push('/edu/search'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: p.muted),
                    const SizedBox(width: 10),
                    Text(l.elSearchHint, style: context.sans(14, color: p.muted)),
                  ]),
                ),
              ),
            ),
            AsyncView(
              value: ref.watch(_allSubjectsProvider),
              onRetry: () => ref.invalidate(_allSubjectsProvider),
              loading: const SizedBox.shrink(),
              data: (subjects) {
                final mine = subjects.where((s) => asBool(s['enrolled']) || asIntOr(asJson(s['my_progress'])['completed']) > 0).toList();
                if (mine.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHeader(title: l.elMySubjects),
                  for (final s in mine) SubjectCard(subject: s),
                ]);
              },
            ),
            SectionHeader(title: l.elCategories),
            AsyncView(
              value: ref.watch(eduCategoriesProvider),
              onRetry: () => ref.invalidate(eduCategoriesProvider),
              data: (cats) => cats.isEmpty ? EduEmptyCard(icon: Icons.auto_stories_outlined, message: l.elNoCategories) : CategoryGrid(categories: cats),
            ),
            AsyncView(
              value: ref.watch(_allSubjectsProvider),
              onRetry: () => ref.invalidate(_allSubjectsProvider),
              loading: const SizedBox.shrink(),
              data: (subjects) {
                final loose = subjects.where((s) => s['category_id'] == null).toList();
                if (loose.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHeader(title: l.elOtherSubjects),
                  for (final s in loose) SubjectCard(subject: s),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A subject in a list: cover / icon, names, published lesson count, the member's real progress.
class SubjectCard extends ConsumerWidget {
  const SubjectCard({super.key, required this.subject});
  final Json subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final names = eduNames(context, subject);
    final progress = asJson(subject['my_progress']);
    final total = asIntOr(progress['total']);
    final done = asIntOr(progress['completed']);
    final canOpen = asBool(subject['can_open']);
    final status = asStr(subject['status']);
    final subjectId = asIntOr(subject['id']);
    final canEditThis = asBool(subject['can_edit']);

    final card = Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.eduGold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final assignedGrade = asInt(subject['assigned_grade']);
            if (assignedGrade != null && assignedGrade > 0) {
              context.push('/edu/subject/$subjectId/grade/$assignedGrade');
            } else {
              context.push('/edu/learn/subject/$subjectId');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: asStr(subject['cover_url']) != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(13), child: CoverImage(url: asStr(subject['cover_url']), fit: BoxFit.cover))
                      : (asInt(subject['sort_order']) != null && asInt(subject['sort_order'])! >= 1 && asInt(subject['sort_order'])! <= 12
                          ? Center(
                              child: Text(
                                '${subject['sort_order']}',
                                style: context.serif(21, weight: FontWeight.w800, color: AppColors.maroon),
                              ),
                            )
                          : const Icon(Icons.menu_book_rounded, color: AppColors.maroon, size: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(names.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.serif(15, weight: FontWeight.w600, color: p.primary)),
                      if (names.subtitle != null)
                        Text(names.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11.5, color: p.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_stories_rounded, size: 13, color: AppColors.goldDark),
                            const SizedBox(width: 4),
                            Text(total > 0 ? l.elLessonCount(total) : l.elNoLessonsYet, style: context.sans(11.5, color: p.subtle)),
                          ],
                        ),
                        if (status != null && status != 'published')
                          Pill(status == 'draft' ? l.elStatusDraft : l.elStatusArchived, color: AppColors.warning, background: AppColors.warning.withValues(alpha: 0.12)),
                        if (!canOpen)
                          Pill(l.elForStudents, icon: Icons.lock_outline_rounded),
                      ]),
                      if (canOpen && done > 0 && total > 0) ...[
                        const SizedBox(height: 8),
                        EduProgressBar(value: done / total, height: 6, label: l.elPercentDone((done * 100 / total).floor()), showPercentage: true),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.faint),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EditOverlay(
        permission: Perm.educationContent,
        isTeacherOwner: canEditThis,
        onEdit: () => openAdminEditor(context, ref, '/edu/content/subject/$subjectId'),
        child: card,
      ),
    );
  }
}

// =============================================================================
// Category → its subjects
// =============================================================================
class EduCategoryScreen extends ConsumerWidget {
  const EduCategoryScreen({super.key, required this.categoryId});
  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = l.isEn;
    final cat = ref.watch(eduCategoriesProvider).value?.where((c) => asIntOr(c['id']) == categoryId).firstOrNull;
    final names = cat == null ? null : eduNames(context, cat);
    const canonicalNames = <int, String>{
      1: 'ትምህርተ ሃይማኖት',
      4: 'የመጽሐፍ ቅዱስ ጥናት',
      5: 'ክርስቲያናዊ ሥነምግባር',
      6: 'ሥርዓተ ቤተ ክርስቲያን',
      3: 'የቤተክርስትያን ታሪክ',
      7: 'ልሳነ ግእዝ',
      8: 'ዜማ',
    };
    final displayTitle = names?.title ?? canonicalNames[categoryId] ?? l.elCategories;

    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/edu');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: PatternScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: isEn ? 'Back to categories' : 'ወደ ምድቦች ተመለስ',
            onPressed: handleBack,
          ),
          title: Text(displayTitle),
          actions: [
            if (cat != null && canEditFront(ref, module: 'edu'))
              IconButton(
                tooltip: l.edit,
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  final saved = await showEduCategoryEditor(context, category: cat);
                  if (saved == true) {
                    ref.invalidate(eduCategoriesProvider);
                    ref.invalidate(eduDashboardProvider);
                    ref.read(contentRevisionProvider.notifier).bump();
                  }
                },
              ),
          ],
        ),
        floatingActionButton: canEditFront(ref, module: 'edu')
            ? EditModeAddButton(
                actions: [
                  (
                    label: l.isEn ? 'Add Grade / Subject' : 'አዲስ ክፍል / ትምህርት',
                    icon: Icons.menu_book_rounded,
                    permission: Perm.educationContent,
                    run: () async {
                      final id = await showEduSubjectEditor(context, categoryId: categoryId);
                      if (id != null && context.mounted) {
                        ref.invalidate(_categorySubjectsProvider(categoryId));
                        ref.invalidate(eduCategoriesProvider);
                        ref.invalidate(eduDashboardProvider);
                        context.push('/edu/learn/subject/$id');
                      }
                    },
                  ),
                ],
              )
            : null,
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async => ref.invalidate(_categorySubjectsProvider(categoryId)),
          child: AsyncView(
            value: ref.watch(_categorySubjectsProvider(categoryId)),
            onRetry: () => ref.invalidate(_categorySubjectsProvider(categoryId)),
            data: (subjects) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Category Hero Card
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.maroon, AppColors.maroonDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.maroonDark.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: const Icon(Icons.church_rounded, color: AppColors.gold, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: context.serif(18, weight: FontWeight.w700, color: Colors.white),
                            ),
                            if (asStr(cat?['description']) != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                asStr(cat!['description'])!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.sans(12.5, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Grades section heading
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 18, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Curriculum Courses & Lessons' : 'የትምህርት ክፍሎች እና ይዘቶች',
                        style: context.serif(15, weight: FontWeight.w700, color: AppColors.maroon),
                      ),
                    ],
                  ),
                ),

                if (subjects.isEmpty)
                  EmptyView(message: l.elNoSubjectsInCategory, icon: Icons.menu_book_outlined)
                else
                  for (final s in subjects) SubjectCard(subject: s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Subject: header with real progress, units → lessons
// =============================================================================
class EduSubjectScreen extends ConsumerWidget {
  const EduSubjectScreen({super.key, required this.subjectId});
  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(contentRevisionProvider);
    final l = context.l10n;
    final async = ref.watch(eduSubjectProvider(subjectId));
    final s = async.value;
    final canEdit = s != null && asBool(s['can_edit']);
    return PatternScaffold(
      appBar: AppBar(
        title: Text(s == null ? l.elLessons : eduNames(context, s).title),
        actions: [
          if (canEdit && ref.watch(editModeProvider))
            IconButton(
              tooltip: l.elEditSubject,
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final id = await showEduSubjectEditor(context, subject: s);
                if (id == -1 && context.mounted) {
                  ref.invalidate(_allSubjectsProvider);
                  ref.invalidate(eduCategoriesProvider);
                  context.pop();
                } else if (id != null) {
                  ref.invalidate(eduSubjectProvider(subjectId));
                  ref.invalidate(_allSubjectsProvider);
                }
              },
            ),
          if (canEdit)
            IconButton(tooltip: l.elEditCurriculum, icon: const Icon(Icons.edit_note_rounded), onPressed: () async {
              await context.push('/edu/content/subject/$subjectId');
              ref.invalidate(eduSubjectProvider(subjectId));
            }),
        ],
      ),
      floatingActionButton: canEdit
          ? EditModeAddButton(
              actions: [
                (
                  label: l.isEn ? 'Add Lesson' : 'አዲስ ትምህርት',
                  icon: Icons.article_rounded,
                  permission: Perm.educationContent,
                  run: () => openAdminEditor(context, ref, '/edu/content/lesson/new?subject_id=$subjectId'),
                ),
                (
                  label: l.isEn ? 'Add Quiz' : 'አዲስ ፈተና / ጥያቄ',
                  icon: Icons.quiz_rounded,
                  permission: Perm.educationContent,
                  run: () async {
                    final title = await promptText(context, title: l.elNewQuiz, label: l.elTitle, required: true);
                    final trimmed = title?.trim() ?? '';
                    if (trimmed.isEmpty || !context.mounted) return;
                    final q = await runWithProgress(context, () => ref.read(eduRepositoryProvider).createSubjectQuiz(subjectId, {'title': trimmed}));
                    if (q != null && context.mounted) {
                      await context.push('/edu/quiz-edit/${q['id']}');
                      ref.invalidate(eduSubjectProvider(subjectId));
                    }
                  },
                ),
                (
                  label: l.isEn ? 'Add Unit' : 'አዲስ ምዕራፍ',
                  icon: Icons.folder_rounded,
                  permission: Perm.educationContent,
                  run: () => openAdminEditor(context, ref, '/edu/content/unit/new?subject_id=$subjectId'),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ref.invalidate(eduSubjectProvider(subjectId)),
        child: AsyncView(
          value: async,
          onRetry: () => ref.invalidate(eduSubjectProvider(subjectId)),
          data: (s) => _SubjectBody(subject: s),
        ),
      ),
    );
  }
}

class _SubjectBody extends ConsumerWidget {
  const _SubjectBody({required this.subject});
  final Json subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final names = eduNames(context, subject);
    final progress = asJson(subject['my_progress']);
    final total = asIntOr(progress['total']);
    final done = asIntOr(progress['completed']);
    final canOpen = asBool(subject['can_open']);
    final editing = asBool(subject['can_edit']);
    final units = asJsonList(subject['units']);
    final loose = asJsonList(subject['lessons']);
    var n = 0;
    Widget lessonTile(Json lesson) {
      n++;
      return LessonTile(
        lesson: lesson,
        number: n,
        editing: editing,
        onTap: canOpen ? () => context.push('/edu/learn/lesson/${lesson['id']}') : () => showSnack(context, l.errNotEnrolledSubject),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Maroon header: names, description, real progress (as in the design's chapter card).
        MaroonCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(names.title, style: context.serif(20, color: Colors.white, height: 1.25)),
            if (names.subtitle != null) Text('(${names.subtitle})', style: context.sans(13, color: Colors.white70)),
            if (asStr(subject['description']) != null) ...[
              const SizedBox(height: 8),
              Text(asStr(subject['description'])!, style: context.sans(13, color: Colors.white, height: 1.55)),
            ],
            if (canOpen && total > 0) ...[
              const SizedBox(height: 12),
              EduProgressBar(value: done / total, onDark: true, label: l.elPercentDone((done * 100 / total).floor())),
            ],
          ]),
        ),
        if (!canOpen)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EduEmptyCard(icon: Icons.lock_outline_rounded, message: l.elSubjectForStudents, actionLabel: l.eduRegister, onAction: () => context.push('/edu/register')),
          ),
        if (asStr(subject['objectives']) != null) ...[
          SectionHeader(title: l.elObjectives),
          AppCard(padding: const EdgeInsets.all(14), child: Text(asStr(subject['objectives'])!, style: context.sans(13.5, height: 1.6))),
        ],
        if (units.isEmpty && loose.isEmpty) ...[
          const SizedBox(height: 16),
          EmptyView(message: l.elNoLessonsYet, icon: Icons.menu_book_outlined),
        ],
        for (final u in units) ...[
          SectionHeader(
            title: asStr(u['title']) ?? '',
            trailingWidget: editing && ref.watch(editModeProvider)
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.goldDark),
                    tooltip: l.edit,
                    onPressed: () => openAdminEditor(context, ref, '/edu/content/unit/${u['id']}?subject_id=${subject['id']}'),
                  )
                : null,
          ),
          if (asStr(u['description']) != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(asStr(u['description'])!, style: context.sans(12.5, color: p.muted))),
          for (final lesson in asJsonList(u['lessons'])) lessonTile(lesson),
          if (asJsonList(u['lessons']).isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.elNoLessonsYet, style: context.sans(12.5, color: p.muted))),
        ],
        if (loose.isNotEmpty) ...[
          SectionHeader(title: units.isEmpty ? l.elLessons : l.elMoreLessons),
          for (final lesson in loose) lessonTile(lesson),
        ],
      ],
    );
  }
}

// =============================================================================
// Lesson reader
// =============================================================================
class EduLessonScreen extends ConsumerStatefulWidget {
  const EduLessonScreen({super.key, required this.lessonId});
  final int lessonId;

  @override
  ConsumerState<EduLessonScreen> createState() => _EduLessonScreenState();
}

class _EduLessonScreenState extends ConsumerState<EduLessonScreen> {
  double _scale = 1;

  Future<void> _progress(Json lesson, String action) async {
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).lessonProgress(widget.lessonId, action));
    if (r == null) return;
    ref.invalidate(eduLessonProvider(widget.lessonId));
    ref.invalidate(eduSubjectProvider(asIntOr(asJson(lesson['subject'])['id'])));
    ref.invalidate(eduDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final async = ref.watch(eduLessonProvider(widget.lessonId));
    final lesson = async.value;
    final Json? unit = lesson == null || lesson['unit'] == null ? null : asJson(lesson['unit']);
    final position = asInt(lesson?['position']);
    return PatternScaffold(
      appBar: AppBar(
        title: lesson == null
            ? Text(l.elLessons)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eduNames(context, asJson(lesson['subject'])).title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.serif(15)),
                Text(
                  [if (unit != null && unit.isNotEmpty) asStr(unit['title']) ?? '', if (position != null) l.elLessonN(eduNumber(context, position))].where((x) => x.isNotEmpty).join(' • '),
                  style: context.sans(11.5, color: p.muted),
                ),
              ]),
        actions: lesson == null
            ? null
            : [
                PopupMenuButton<double>(
                  tooltip: l.elTextSize,
                  icon: const Icon(Icons.format_size_rounded),
                  initialValue: _scale,
                  onSelected: (v) => setState(() => _scale = v),
                  itemBuilder: (_) => [
                    for (final (v, label) in [(0.9, 'A−'), (1.0, 'A'), (1.15, 'A+'), (1.3, 'A++')]) CheckedPopupMenuItem(value: v, checked: v == _scale, child: Text(label)),
                  ],
                ),
                IconButton(
                  tooltip: l.elBookmark,
                  icon: Icon(asBool(lesson['bookmarked']) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                  onPressed: asStr(lesson['status']) == 'published' ? () => _progress(lesson, asBool(lesson['bookmarked']) ? 'unbookmark' : 'bookmark') : null,
                ),
                IconButton(
                  tooltip: l.elShare,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareLink(kind: 'open/edu_lesson', id: widget.lessonId, title: asStr(lesson['title']) ?? ''),
                ),
                if (asBool(lesson['can_edit']))
                  IconButton(tooltip: l.elEditLesson, icon: const Icon(Icons.edit_outlined), onPressed: () async {
                    await context.push('/edu/content/lesson/${widget.lessonId}');
                    ref.invalidate(eduLessonProvider(widget.lessonId));
                  }),
              ],
      ),
      bottomNavigationBar: lesson == null ? null : _LessonNav(lesson: lesson, onComplete: () => _progress(lesson, asBool(lesson['completed']) ? 'uncomplete' : 'complete')),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ref.invalidate(eduLessonProvider(widget.lessonId)),
        child: AsyncView(
          value: async,
          onRetry: () => ref.invalidate(eduLessonProvider(widget.lessonId)),
          data: (lesson) => _LessonContent(lesson: lesson, scale: _scale),
        ),
      ),
    );
  }
}

class _LessonContent extends ConsumerWidget {
  const _LessonContent({required this.lesson, required this.scale});
  final Json lesson;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final materials = asJsonList(lesson['materials']);
    final quizzes = asJsonList(lesson['quizzes']);
    final images = materials.where((m) => m['kind'] == 'file' && (asStr(m['mime']) ?? '').startsWith('image/')).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (asStr(lesson['status']) != 'published')
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Pill(asStr(lesson['status']) == 'draft' ? l.elStatusDraft : l.elStatusArchived, color: AppColors.warning))),
              Text(asStr(lesson['title']) ?? '', textAlign: TextAlign.center, style: context.serif(22 * scale, color: p.primary, height: 1.3)),
              if (asStr(lesson['summary']) != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(asStr(lesson['summary'])!, textAlign: TextAlign.center, style: context.sans(13.5 * scale, color: p.muted))),
              if (asStr(lesson['scripture_refs']) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(child: Pill(asStr(lesson['scripture_refs'])!, icon: Icons.menu_book_outlined)),
                ),
              const SizedBox(height: 14),
              if (asStr(lesson['objectives']) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.elObjectives, style: context.sans(12, weight: FontWeight.w700, color: p.accentText)),
                      const SizedBox(height: 4),
                      Text(asStr(lesson['objectives'])!, style: context.sans(13.5 * scale, height: 1.6)),
                    ]),
                  ),
                ),
              // The reading page: a warm parchment card in light mode, the dark card in dark mode.
              if ((asStr(lesson['body']) ?? '').trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  decoration: BoxDecoration(
                    color: dark ? p.card : const Color(0xFFF8EFDC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                  ),
                  child: LessonBody(body: asStr(lesson['body']), scale: scale),
                ),
              if (images.isNotEmpty) ...[
                SectionHeader(title: l.elImages),
                for (final m in images) MaterialTile(material: m),
              ],
              if (materials.length > images.length) ...[
                SectionHeader(title: l.elMaterials),
                for (final m in materials.where((m) => !images.contains(m))) MaterialTile(material: m),
              ],
              if (quizzes.isNotEmpty) ...[
                SectionHeader(title: l.elQuizzes),
                for (final q in quizzes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push(asBool(lesson['can_edit']) ? '/edu/quiz-results/${q['id']}' : '/edu/quiz/${q['id']}'),
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.fact_check_rounded, color: AppColors.maroon),
                        const SizedBox(width: 12),
                        Expanded(child: Text(asStr(q['title']) ?? '', style: context.sans(14, weight: FontWeight.w600))),
                        Icon(Icons.chevron_right_rounded, color: p.faint),
                      ]),
                    ),
                  ),
              ],
              if (asStr(lesson['teacher_notes']) != null) ...[
                SectionHeader(title: l.elTeacherNotes),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.goldDark),
                    const SizedBox(width: 8),
                    Expanded(child: Text(asStr(lesson['teacher_notes'])!, style: context.sans(13, height: 1.55))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

/// Maroon bar: previous · (audio) · mark complete · next.
class _LessonNav extends ConsumerWidget {
  const _LessonNav({required this.lesson, required this.onComplete});
  final Json lesson;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prev = asInt(lesson['prev_id']);
    final next = asInt(lesson['next_id']);
    final completed = asBool(lesson['completed']);
    final published = asStr(lesson['status']) == 'published';
    final audio = asJsonList(lesson['materials']).where((m) => m['kind'] == 'file' && (asStr(m['mime']) ?? '').startsWith('audio/')).firstOrNull;
    final gold = FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.maroonDeep, padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    return Material(
      color: AppColors.maroon,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(children: [
            // Previous / next share the room left by the middle buttons (labels shorten on narrow phones).
            Expanded(
              child: FilledButton.icon(
                style: gold,
                onPressed: prev == null ? null : () => context.pushReplacement('/edu/learn/lesson/$prev'),
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(l.elPrevious, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            if (audio != null)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.maroonDeep),
                tooltip: l.elListen,
                onPressed: () => openMaterial(context, ref, audio),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            if (published)
              IconButton(
                tooltip: completed ? l.elMarkNotDone : l.elMarkDone,
                onPressed: onComplete,
                icon: Icon(completed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded, color: completed ? AppColors.goldLight : Colors.white),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FilledButton.icon(
                  style: gold,
                  onPressed: next == null ? null : () => context.pushReplacement('/edu/learn/lesson/$next'),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: Text(l.elNext, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Education search (categories, subjects, lessons)
// =============================================================================
class EduSearchScreen extends ConsumerStatefulWidget {
  const EduSearchScreen({super.key});

  @override
  ConsumerState<EduSearchScreen> createState() => _EduSearchScreenState();
}

class _EduSearchScreenState extends ConsumerState<EduSearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  Future<Json>? _results;
  String _activeFilter = 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _searchNow(String v) {
    _debounce?.cancel();
    final query = v.trim();
    setState(() {
      _results = query.length < 2 ? null : ref.read(eduRepositoryProvider).search(query);
    });
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _searchNow(_q.text);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          FilterChip(
            key: const ValueKey('edu-search-chip-all'),
            label: Text(l.all),
            selected: _activeFilter == 'all',
            onSelected: (_) => setState(() => _activeFilter = 'all'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const ValueKey('edu-search-chip-books'),
            avatar: const Icon(Icons.menu_book_rounded, size: 16),
            label: Text(l.libBooks),
            selected: _activeFilter == 'books',
            onSelected: (_) => setState(() => _activeFilter = 'books'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const ValueKey('edu-search-chip-classes'),
            avatar: const Icon(Icons.school_rounded, size: 16),
            label: Text(l.elClass),
            selected: _activeFilter == 'classes',
            onSelected: (_) => setState(() => _activeFilter = 'classes'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const ValueKey('edu-search-chip-lessons'),
            avatar: const Icon(Icons.article_rounded, size: 16),
            label: Text(l.elLessons),
            selected: _activeFilter == 'lessons',
            onSelected: (_) => setState(() => _activeFilter = 'lessons'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const ValueKey('edu-search-chip-assignments'),
            avatar: const Icon(Icons.assignment_rounded, size: 16),
            label: Text(l.elAssignments),
            selected: _activeFilter == 'assignments',
            onSelected: (_) => setState(() => _activeFilter = 'assignments'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const ValueKey('edu-search-chip-quizzes'),
            avatar: const Icon(Icons.quiz_rounded, size: 16),
            label: Text(l.elQuizzes),
            selected: _activeFilter == 'quizzes',
            onSelected: (_) => setState(() => _activeFilter = 'quizzes'),
          ),
        ],
      ),
    );

    return PatternScaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('edu-search-input'),
          controller: _q,
          autofocus: true,
          onChanged: _changed,
          onSubmitted: _searchNow,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.elSearchHint,
            border: InputBorder.none,
            filled: false,
            suffixIcon: _q.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _q.clear();
                      _searchNow('');
                    },
                  )
                : const Icon(Icons.search_rounded),
          ),
        ),
      ),
      body: _results == null
          ? EmptyView(message: l.elSearchStart, icon: Icons.search_rounded)
          : FutureBuilder<Json>(
              future: _results,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => _changed(_q.text));
                if (!snap.hasData) return const LoadingView();
                final d = snap.data!;
                final cats = asJsonList(d['categories']);
                final subjects = asJsonList(d['subjects']);
                final courses = asJsonList(d['courses']);
                final units = asJsonList(d['units']);
                final lessons = asJsonList(d['lessons']);
                final materials = asJsonList(d['materials']);
                final magazines = asJsonList(d['magazines']);
                final books = asJsonList(d['books']);
                final eduClasses = asJsonList(d['classes']);
                final assignments = asJsonList(d['assignments']);
                final quizzes = asJsonList(d['quizzes']);

                final showAll = _activeFilter == 'all';
                final showBooks = showAll || _activeFilter == 'books';
                final showClasses = showAll || _activeFilter == 'classes';
                final showLessons = showAll || _activeFilter == 'lessons';
                final showAssignments = showAll || _activeFilter == 'assignments';
                final showQuizzes = showAll || _activeFilter == 'quizzes';

                final totalMatches = cats.length +
                    subjects.length +
                    courses.length +
                    units.length +
                    lessons.length +
                    materials.length +
                    magazines.length +
                    books.length +
                    eduClasses.length +
                    assignments.length +
                    quizzes.length;

                if (totalMatches == 0) {
                  return EmptyView(message: l.elSearchNone, icon: Icons.search_off_rounded);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    filterChips,
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        children: [
                          // 1. Books
                          if (showBooks && books.isNotEmpty) ...[
                            SectionHeader(title: l.libBooks),
                            for (final b in books)
                              TrackTile(
                                title: asStr(b['title']) ?? '',
                                subtitle: [
                                  if (b['author'] != null) '${b['author']}',
                                  if (b['code'] != null) '${b['code']}',
                                  if (b['is_digital'] == true) (l.isEn ? 'Digital' : 'ዲጂታል') else (l.isEn ? 'Physical' : 'የወረቀት'),
                                ].join(' · '),
                                leading: ListThumb(
                                  icon: b['is_digital'] == true ? Icons.picture_as_pdf_outlined : Icons.menu_book_outlined,
                                  imageUrl: asStr(b['cover_url']),
                                ),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/library'),
                              ),
                          ],

                          // 2. Classes & Courses
                          if (showClasses && eduClasses.isNotEmpty) ...[
                            SectionHeader(title: l.myClasses),
                            for (final c in eduClasses)
                              TrackTile(
                                title: eduClassName(c),
                                subtitle: eduClassSubtitle(c, l).isNotEmpty ? eduClassSubtitle(c, l) : null,
                                leading: const ListThumb(icon: Icons.school_outlined),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/class/${c['id']}'),
                              ),
                          ],
                          if (showClasses && courses.isNotEmpty) ...[
                            SectionHeader(title: l.isEn ? 'Courses' : 'ኮርሶች'),
                            for (final c in courses)
                              TrackTile(
                                title: asStr(c['title']) ?? '',
                                subtitle: asStr(c['class_name']) ?? asStr(c['code']),
                                leading: const ListThumb(icon: Icons.class_outlined),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/course/${c['id']}'),
                              ),
                          ],

                          // 3. Curriculum Categories & Subjects
                          if (showLessons && cats.isNotEmpty) ...[
                            SectionHeader(title: l.elCategories),
                            for (final c in cats)
                              TrackTile(
                                title: eduNames(context, c).title,
                                subtitle: eduNames(context, c).subtitle,
                                leading: const ListThumb(icon: Icons.category_outlined),
                                onTap: () => context.push('/edu/learn/category/${c['id']}'),
                              ),
                          ],
                          if (showLessons && subjects.isNotEmpty) ...[
                            SectionHeader(title: l.elSubjects),
                            for (final s in subjects)
                              TrackTile(
                                title: eduNames(context, s).title,
                                subtitle: eduNames(context, s).subtitle,
                                leading: const ListThumb(icon: Icons.menu_book_rounded),
                                onTap: () => context.push('/edu/learn/subject/${s['id']}'),
                              ),
                          ],
                          if (showLessons && units.isNotEmpty) ...[
                            SectionHeader(title: l.isEn ? 'Units' : 'ምዕራፎች'),
                            for (final u in units)
                              TrackTile(
                                title: asStr(u['title']) ?? '',
                                subtitle: asStr(u['subject_name']),
                                leading: const ListThumb(icon: Icons.folder_open_rounded),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/learn/subject/${u['subject_id']}'),
                              ),
                          ],

                          // 4. Lessons & Learning Materials
                          if (showLessons && lessons.isNotEmpty) ...[
                            SectionHeader(title: l.elLessons),
                            for (final x in lessons)
                              TrackTile(
                                title: asStr(x['title']) ?? '',
                                subtitle: [if (x['subject_name'] != null) '${x['subject_name']}', if (x['unit_title'] != null) '${x['unit_title']}'].join(' · '),
                                leading: const ListThumb(icon: Icons.article_outlined),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/learn/lesson/${x['id']}'),
                              ),
                          ],
                          if (showLessons && materials.isNotEmpty) ...[
                            SectionHeader(title: l.isEn ? 'Learning Materials' : 'የማስተማሪያ ሰነዶች'),
                            for (final m in materials)
                              TrackTile(
                                title: asStr(m['title']) ?? '',
                                subtitle: [if (m['lesson_title'] != null) '${m['lesson_title']}', if (m['subject_name'] != null) '${m['subject_name']}'].join(' · '),
                                leading: const ListThumb(icon: Icons.attach_file_rounded),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/learn/lesson/${m['lesson_id']}'),
                              ),
                          ],

                          // 5. Assignments
                          if (showAssignments && assignments.isNotEmpty) ...[
                            SectionHeader(title: l.elAssignments),
                            for (final a in assignments)
                              TrackTile(
                                title: asStr(a['title']) ?? '',
                                subtitle: [
                                  if (a['course_title'] != null) '${a['course_title']}',
                                  if (a['class_name'] != null) '${a['class_name']}',
                                  if (a['due_at'] != null) '${l.isEn ? 'Due' : 'የሚያበቃበት'}: ${a['due_at']}',
                                  if (a['max_score'] != null) '${a['max_score']} pts',
                                ].join(' · '),
                                leading: const ListThumb(icon: Icons.assignment_outlined),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/assignment/${a['id']}'),
                              ),
                          ],

                          // 6. Quizzes
                          if (showQuizzes && quizzes.isNotEmpty) ...[
                            SectionHeader(title: l.elQuizzes),
                            for (final q in quizzes)
                              TrackTile(
                                title: asStr(q['title']) ?? '',
                                subtitle: [
                                  if (q['subject_title'] != null) '${q['subject_title']}',
                                  if (q['time_limit_minutes'] != null) '${q['time_limit_minutes']} min',
                                  if (q['pass_score'] != null) '${l.isEn ? 'Pass' : 'ማለፊያ'}: ${q['pass_score']}',
                                ].join(' · '),
                                leading: const ListThumb(icon: Icons.quiz_outlined),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/quiz/${q['id']}'),
                              ),
                          ],

                          // 7. Seleda Magazine
                          if (magazines.isNotEmpty) ...[
                            SectionHeader(title: l.isEn ? 'Seleda Magazine' : 'ሰሌዳ መጽሔት'),
                            for (final m in magazines)
                              TrackTile(
                                title: asStr(m['title']) ?? '',
                                subtitle: m['issue_no'] != null ? '${l.isEn ? 'Issue' : 'ዕትም'} ${m['issue_no']}' : null,
                                leading: const ListThumb(icon: Icons.auto_stories_rounded),
                                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                                onTap: () => context.push('/edu/magazine/${m['id']}'),
                              ),
                          ],
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
