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
import '../../../widgets/typed_picker.dart';
import '../../admin/admin_widgets.dart' show DateTimeField;
import '../../admin/edit_mode.dart' show contentRevisionProvider;
import '../../auth/session.dart' show currentUserProvider;
import 'edu_home.dart' show eduDashboardProvider;
import 'edu_widgets.dart';
import 'learn_screens.dart' show eduCategoriesProvider, eduLessonProvider, eduSubjectProvider;

String _statusLabel(AppLocalizations l, String? s) => switch (s) { 'published' => l.elStatusPublished, 'archived' => l.elStatusArchived, 'active' => l.elStatusActive, _ => l.elStatusDraft };

// =============================================================================
// Learning content: categories · subjects · featured banner (education.content / education.manage)
// =============================================================================
class EduContentScreen extends ConsumerWidget {
  const EduContentScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final editor = user?.canAny([Perm.educationContent, Perm.educationManage]) ?? false;
    if (!editor) {
      // Teachers write lessons of the subjects they teach, from the subject page.
      return PatternScaffold(appBar: AppBar(title: Text(l.elContentTitle)), body: const _AuthoringList());
    }
    final initialIndex = switch (initialTab?.toLowerCase()) {
      'featured' || 'feature' || '1' => 1,
      _ => 0,
    };
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: PatternScaffold(
        appBar: AppBar(
          title: Text(l.elContentTitle),
          bottom: TabBar(tabs: [Tab(text: l.elSubjects), Tab(text: l.elFeatured)]),
        ),
        body: const TabBarView(children: [_SubjectsTab(), _FeaturedTab()]),
      ),
    );
  }
}

/// Teachers without editor rights: the subjects they may write lessons for.
class _AuthoringList extends ConsumerWidget {
  const _AuthoringList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return FutureBuilder<List<Json>>(
      future: ref.read(eduRepositoryProvider).authoringSubjects(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error!);
        if (!snap.hasData) return const LoadingView();
        if (snap.data!.isEmpty) return EmptyView(message: l.elNoAuthoring, icon: Icons.edit_off_outlined);
        return ListView(padding: const EdgeInsets.all(12), children: [
          for (final s in snap.data!)
            TrackTile(
              title: eduNames(context, s).title,
              subtitle: l.elLessonCount(asIntOr(s['lesson_count'])),
              leading: const ListThumb(icon: Icons.menu_book_rounded, active: true),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/edu/content/subject/${s['id']}'),
            ),
        ]);
      },
    );
  }
}

// -----------------------------------------------------------------------------
class _CategoriesTab extends ConsumerStatefulWidget {
  const _CategoriesTab();
  @override
  ConsumerState<_CategoriesTab> createState() => _CategoriesTabState();
}

/// Open the education category editor bottom sheet, returning true if changes were saved.
Future<bool?> showEduCategoryEditor(BuildContext context, {Json? category}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _CategoryForm(category: category),
    ),
  );
}

class _CategoriesTabState extends ConsumerState<_CategoriesTab> {
  late Future<List<Json>> _future = ref.read(eduRepositoryProvider).categories(all: true);
  List<Json>? _items;

  void _reload() {
    setState(() {
      _items = null;
      _future = ref.read(eduRepositoryProvider).categories(all: true);
    });
    ref.invalidate(eduCategoriesProvider);
    ref.invalidate(eduDashboardProvider);
  }

  Future<void> _edit([Json? c]) async {
    final saved = await showEduCategoryEditor(context, category: c);
    if (saved == true) _reload();
  }

  Future<void> _reorder(int from, int to) async {
    // onReorderItem already gives the index after removing the moved item.
    final items = [...?_items];
    items.insert(to, items.removeAt(from));
    setState(() => _items = items);
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).reorderCategories([for (final c in items) asIntOr(c['id'])]));
    if (r == null) _reload();
    ref.invalidate(eduCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'new-cat', onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: Text(l.elNewCategory)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final items = _items ??= [...snap.data!];
          if (items.isEmpty) return EmptyView(message: l.elNoCategories, icon: Icons.category_outlined);
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            onReorderItem: _reorder,
            header: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.elDragToReorder, style: context.sans(12, color: p.muted))),
            itemBuilder: (context, i) {
              final c = items[i];
              final names = eduNames(context, c);
              final archived = c['status'] == 'archived';
              return Padding(
                key: ValueKey('cat-${c['id']}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => _edit(c),
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: asStr(c['image_url']) != null
                          ? CoverImage(url: asStr(c['image_url']), radius: 10, fit: BoxFit.contain)
                          : Container(decoration: BoxDecoration(color: p.pill, borderRadius: BorderRadius.circular(10)), child: Icon(categoryIcon(asStr(c['icon_key'])), color: AppColors.maroon)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(names.title, style: context.serif(14.5, color: archived ? p.muted : null)),
                        Text([if (names.subtitle != null) names.subtitle!, l.elSubjectCount(asIntOr(c['subject_count'])), l.elLessonCount(asIntOr(c['lesson_count']))].join(' · '), style: context.sans(11.5, color: p.muted)),
                      ]),
                    ),
                    if (archived) Pill(l.elStatusArchived),
                    ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded))),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category});
  final Json? category;
  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final _name = TextEditingController(text: asStr(widget.category?['name']));
  late final _nameEn = TextEditingController(text: asStr(widget.category?['name_en']));
  late final _desc = TextEditingController(text: asStr(widget.category?['description']));
  late final _descEn = TextEditingController(text: asStr(widget.category?['description_en']));
  late String? _icon = asStr(widget.category?['icon_key']);
  late String _status = asStr(widget.category?['status']) ?? 'active';
  late String? _image = asStr(widget.category?['image_url']);

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _desc.dispose();
    _descEn.dispose();
    super.dispose();
  }

  int? get _id => asInt(widget.category?['id']);

  Future<void> _save() async {
    final l = context.l10n;
    if (_name.text.trim().isEmpty) return showSnack(context, l.elNameRequired);
    final body = {
      'name': _name.text.trim(),
      'name_en': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'description_en': _descEn.text.trim().isEmpty ? null : _descEn.text.trim(),
      'icon_key': _icon,
      'status': _status,
    };
    final repo = ref.read(eduRepositoryProvider);
    final r = await runWithProgress(context, () => _id == null ? repo.createCategory(body) : repo.updateCategory(_id!, body), success: l.saved);
    if (r != null && mounted) Navigator.pop(context, true);
  }

  Future<void> _pickImage() async {
    if (_id == null) return;
    final f = await pickTypedFile(context, kinds: const {PickKind.image});
    if (f == null || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).setCategoryImage(_id!, f.path));
    if (r != null) setState(() => _image = asStr(r['image_url']));
  }

  Future<void> _removeImage() async {
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).removeCategoryImage(_id!));
    if (r != null) setState(() => _image = null);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elDeleteCategoryConfirm, destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteCategory(_id!);
      return true;
    });
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(_id == null ? l.elNewCategory : l.elEditCategory, style: context.serif(18)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: '${l.elNameAmharic} *')),
          const SizedBox(height: 10),
          TextField(controller: _nameEn, decoration: InputDecoration(labelText: l.elNameEnglish)),
          const SizedBox(height: 10),
          TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: '${l.elDescription} (አማርኛ)')),
          const SizedBox(height: 10),
          TextField(controller: _descEn, maxLines: 3, decoration: InputDecoration(labelText: '${l.elDescription} (English)')),
          const SizedBox(height: 12),
          Text(l.elIcon, style: context.sans(12.5, color: context.palette.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in categoryIconKeys)
              ChoiceChip(label: Icon(categoryIcon(k), size: 20), selected: _icon == k, onSelected: (_) => setState(() => _icon = k)),
          ]),
          const SizedBox(height: 12),
          if (_id != null)
            Row(children: [
              if (_image != null) SizedBox(width: 56, height: 56, child: CoverImage(url: _image, radius: 10, fit: BoxFit.contain)),
              const SizedBox(width: 8),
              TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: Text(_image == null ? l.elAddImage : l.elChangeImage)),
              if (_image != null) TextButton(onPressed: _removeImage, child: Text(l.elRemoveImage)),
            ])
          else
            Text(l.elImageAfterSave, style: context.sans(12, color: context.palette.muted)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.elStatusActive),
            subtitle: Text(l.elArchiveHint),
            value: _status == 'active',
            onChanged: (v) => setState(() => _status = v ? 'active' : 'archived'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: Text(l.save)),
          if (_id != null) TextButton(onPressed: _delete, style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: Text(l.delete)),
        ]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
class _SubjectsTab extends ConsumerStatefulWidget {
  const _SubjectsTab();
  @override
  ConsumerState<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends ConsumerState<_SubjectsTab> {
  late Future<List<Json>> _future = ref.read(eduRepositoryProvider).subjects(all: true);

  void _reload() => setState(() => _future = ref.read(eduRepositoryProvider).subjects(all: true));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!;
          if (list.isEmpty) return EmptyView(message: l.elNoSubjects, icon: Icons.menu_book_outlined);
          final groups = <String, List<Json>>{};
          for (final s in list) {
            (groups[asStr(s['category_name']) ?? l.elNoCategory] ??= []).add(s);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: [
              for (final g in groups.entries) ...[
                SectionHeader(title: g.key),
                for (final s in g.value)
                  TrackTile(
                    title: eduNames(context, s).title,
                    subtitle: [l.elLessonCount(asIntOr(s['lesson_count'])), _statusLabel(l, asStr(s['status'])), s['visibility'] == 'members' ? l.elVisibilityMembers : l.elVisibilityEnrolled].join(' · '),
                    leading: ListThumb(icon: Icons.menu_book_rounded, active: s['status'] == 'published', imageUrl: asStr(s['cover_url'])),
                    trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                    onTap: () async {
                      await context.push('/edu/content/subject/${s['id']}');
                      _reload();
                    },
                  ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

/// Open the education subject editor bottom sheet, returning the subject id if created/saved.
Future<int?> showEduSubjectEditor(BuildContext context, {Json? subject, int? categoryId}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SubjectForm(subject: subject, initialCategoryId: categoryId),
    ),
  );
}

/// Standalone screen for Subject creation/editing when navigated via URL.
class SubjectFormScreen extends StatelessWidget {
  const SubjectFormScreen({super.key, this.subject, this.initialCategoryId});
  final Json? subject;
  final int? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      appBar: AppBar(title: Text(subject == null ? context.l10n.elNewSubject : context.l10n.elEditSubject)),
      body: SubjectForm(subject: subject, initialCategoryId: initialCategoryId),
    );
  }
}

/// Create / edit a catalog subject (content editors). Returns the subject id when saved.
class SubjectForm extends ConsumerStatefulWidget {
  const SubjectForm({super.key, this.subject, this.initialCategoryId});
  final Json? subject;
  final int? initialCategoryId;

  @override
  ConsumerState<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<SubjectForm> {
  late final _name = TextEditingController(text: asStr(widget.subject?['name']));
  late final _nameEn = TextEditingController(text: asStr(widget.subject?['name_en']));
  late final _code = TextEditingController(text: asStr(widget.subject?['code']));
  late final _desc = TextEditingController(text: asStr(widget.subject?['description']));
  late final _descEn = TextEditingController(text: asStr(widget.subject?['description_en']));
  late final _objectives = TextEditingController(text: asStr(widget.subject?['objectives']));
  late final _objectivesEn = TextEditingController(text: asStr(widget.subject?['objectives_en']));
  late final int? _category = asInt(widget.subject?['category_id']) ?? widget.initialCategoryId;
  late String _visibility = asStr(widget.subject?['visibility']) ?? 'enrolled';
  late String _status = asStr(widget.subject?['status']) ?? 'draft';
  late bool _sequential = asBool(widget.subject?['sequential']);

  @override
  void dispose() {
    for (final c in [_name, _nameEn, _code, _desc, _descEn, _objectives, _objectivesEn]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _id => asInt(widget.subject?['id']);
  late String? _cover = asStr(widget.subject?['cover_url']);

  Future<void> _pickCover() async {
    if (_id == null) return;
    final f = await pickTypedFile(context, kinds: const {PickKind.image});
    if (f == null || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).setSubjectCover(_id!, f.path));
    if (r != null) setState(() => _cover = asStr(r['cover_url']));
  }

  Future<void> _removeCover() async {
    if (_id == null) return;
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).removeSubjectCover(_id!));
    if (r != null) setState(() => _cover = null);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.isEn ? 'Delete this subject?' : 'ይህን የትምህርት ዓይነት ይሰርዙት?', destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteSubject(_id!);
      return true;
    });
    if (ok == true && mounted) Navigator.pop(context, -1);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final isEn = l.isEn;
    if (_name.text.trim().isEmpty) return showSnack(context, l.elNameRequired);
    if (_status == 'published' && _nameEn.text.trim().isEmpty) {
      return showSnack(context, isEn ? 'English name is required for published subjects' : 'ለታተሙ የትምህርት ዓይነቶች የእንግሊዝኛ ስም ያስፈልጋል');
    }
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final body = {
      'category_id': _category,
      'name': _name.text.trim(),
      'name_en': t(_nameEn),
      'code': t(_code),
      'description': t(_desc),
      'description_en': t(_descEn),
      'objectives': t(_objectives),
      'objectives_en': t(_objectivesEn),
      'visibility': _visibility,
      'status': _status,
      'sequential': _sequential,
    };
    final repo = ref.read(eduRepositoryProvider);
    final id = asInt(widget.subject?['id']);
    final r = await runWithProgress(context, () => id == null ? repo.createSubject(body) : repo.updateSubject(id, body), success: l.saved);
    if (r != null && mounted) {
      final newId = asInt(r['id']);
      if (newId != null) ref.invalidate(eduSubjectProvider(newId));
      ref.invalidate(eduCategoriesProvider);
      ref.invalidate(eduDashboardProvider);
      ref.read(contentRevisionProvider.notifier).bump();
      Navigator.pop(context, newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.subject == null ? l.elNewSubject : l.elEditSubject, style: context.serif(18)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: '${l.elNameAmharic} *')),
          const SizedBox(height: 10),
          TextField(controller: _nameEn, decoration: InputDecoration(labelText: l.elNameEnglish)),
          const SizedBox(height: 10),
          TextField(controller: _code, decoration: InputDecoration(labelText: l.elCode)),
          const SizedBox(height: 10),
          TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: '${l.elDescription} (አማርኛ)')),
          const SizedBox(height: 10),
          TextField(controller: _descEn, maxLines: 3, decoration: InputDecoration(labelText: '${l.elDescription} (English)')),
          const SizedBox(height: 10),
          TextField(controller: _objectives, maxLines: 3, decoration: InputDecoration(labelText: '${l.elObjectives} (አማርኛ)')),
          const SizedBox(height: 10),
          TextField(controller: _objectivesEn, maxLines: 3, decoration: InputDecoration(labelText: '${l.elObjectives} (English)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.elWhoCanRead),
            items: [
              DropdownMenuItem(value: 'enrolled', child: Text(l.elVisibilityEnrolled)),
              DropdownMenuItem(value: 'members', child: Text(l.elVisibilityMembers)),
            ],
            onChanged: (v) => setState(() => _visibility = v ?? 'enrolled'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: l.elStatus),
            items: [for (final s in const ['draft', 'published', 'archived']) DropdownMenuItem(value: s, child: Text(_statusLabel(l, s)))],
            onChanged: (v) => setState(() => _status = v ?? 'draft'),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.elSequential), subtitle: Text(l.elSequentialHint), value: _sequential, onChanged: (v) => setState(() => _sequential = v)),
          const SizedBox(height: 10),
          if (_id != null)
            Row(children: [
              if (_cover != null) SizedBox(width: 56, height: 56, child: CoverImage(url: _cover, radius: 10, fit: BoxFit.contain)),
              const SizedBox(width: 8),
              TextButton.icon(onPressed: _pickCover, icon: const Icon(Icons.image_outlined), label: Text(_cover == null ? l.elAddImage : l.elChangeImage)),
              if (_cover != null) TextButton(onPressed: _removeCover, child: Text(l.elRemoveImage)),
            ])
          else
            Text(l.elImageAfterSave, style: context.sans(12, color: context.palette.muted)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: Text(l.save)),
          if (_id != null) TextButton(onPressed: _delete, style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: Text(l.delete)),
        ]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
class _FeaturedTab extends ConsumerStatefulWidget {
  const _FeaturedTab();
  @override
  ConsumerState<_FeaturedTab> createState() => _FeaturedTabState();
}

class _FeaturedTabState extends ConsumerState<_FeaturedTab> {
  late Future<List<Json>> _future = ref.read(eduRepositoryProvider).featured(all: true);

  void _set(Future<List<Json>> f) {
    setState(() => _future = f);
    f.then((_) => ref.invalidate(eduDashboardProvider), onError: (_) {});
  }

  Future<void> _edit([Json? item]) async {
    final saved = await showModalBottomSheet<List<Json>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: _FeaturedForm(item: item)),
    );
    if (saved != null) _set(Future.value(saved));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(heroTag: 'new-featured', onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: Text(l.elAddFeatured)),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => _set(ref.read(eduRepositoryProvider).featured(all: true)));
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!;
          if (list.isEmpty) return EmptyView(message: l.elNoFeatured, icon: Icons.view_carousel_outlined);
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
            for (final f in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(height: MediaQuery.textScalerOf(context).scale(168).clamp(168.0, 280.0), child: Opacity(opacity: asBool(f['is_active']) && f['target'] != null ? 1 : 0.5, child: FeaturedCard(item: f))),
                  Row(children: [
                    if (f['target'] == null) Pill(l.elTargetUnavailable, color: AppColors.danger),
                    if (!asBool(f['is_active'])) Pill(l.elInactive),
                    const Spacer(),
                    TextButton.icon(onPressed: () => _edit(f), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l.edit)),
                    TextButton.icon(
                      onPressed: () async {
                        final img = await pickTypedFile(context, kinds: const {PickKind.image});
                        if (img == null || !context.mounted) return;
                        final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).setFeaturedImage(asIntOr(f['id']), img.path));
                        if (r != null) _set(Future.value(r));
                      },
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(l.elImage),
                    ),
                    IconButton(
                      tooltip: l.delete,
                      icon: Icon(Icons.delete_outline_rounded, color: p.muted),
                      onPressed: () async {
                        if (!await showConfirm(context, l.elDeleteFeaturedConfirm, destructive: true) || !context.mounted) return;
                        final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteFeatured(asIntOr(f['id'])));
                        if (r != null) _set(Future.value(r));
                      },
                    ),
                  ]),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

class _FeaturedForm extends ConsumerStatefulWidget {
  const _FeaturedForm({this.item});
  final Json? item;
  @override
  ConsumerState<_FeaturedForm> createState() => _FeaturedFormState();
}

class _FeaturedFormState extends ConsumerState<_FeaturedForm> {
  late String _type = asStr(widget.item?['target_type']) ?? 'subject';
  late int? _target = asInt(widget.item?['target_id']);
  late final _title = TextEditingController(text: asStr(widget.item?['title']));
  late final _subtitle = TextEditingController(text: asStr(widget.item?['subtitle']));
  late bool _active = widget.item == null || asBool(widget.item?['is_active']);
  late DateTime? _starts = asDate(widget.item?['starts_at']);
  late DateTime? _ends = asDate(widget.item?['ends_at']);
  late final Future<List<Json>> _subjects = ref.read(eduRepositoryProvider).subjects(all: true);
  Future<List<Json>>? _lessons;
  int? _lessonSubject;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<List<Json>> _classes() async {
    try {
      return await ref.read(eduRepositoryProvider).adminClasses();
    } catch (_) {
      return const []; // content editors without class management
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_target == null) return showSnack(context, l.elChooseTarget);
    final body = {
      'target_type': _type,
      'target_id': _target,
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'subtitle': _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
      'is_active': _active,
      'starts_at': _starts?.toUtc().toIso8601String(),
      'ends_at': _ends?.toUtc().toIso8601String(),
    };
    final repo = ref.read(eduRepositoryProvider);
    final id = asInt(widget.item?['id']);
    final r = await runWithProgress(context, () => id == null ? repo.createFeatured(body) : repo.updateFeatured(id, body), success: l.saved);
    if (r != null && mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.item == null ? l.elAddFeatured : l.elEditFeatured, style: context.serif(18)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [ButtonSegment(value: 'subject', label: Text(l.elSubject)), ButtonSegment(value: 'lesson', label: Text(l.elLesson)), ButtonSegment(value: 'class', label: Text(l.elClass))],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _target = null;
            }),
          ),
          const SizedBox(height: 10),
          if (_type == 'subject' || _type == 'lesson')
            FutureBuilder<List<Json>>(
              future: _subjects,
              builder: (context, snap) => DropdownButtonFormField<int?>(
                initialValue: _type == 'subject' ? ((snap.data ?? const []).any((s) => asInt(s['id']) == _target) ? _target : null) : _lessonSubject,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.elSubject),
                items: [for (final s in snap.data ?? const <Json>[]) DropdownMenuItem<int?>(value: asInt(s['id']), child: Text(eduNames(context, s).title, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() {
                  if (_type == 'subject') {
                    _target = v;
                  } else {
                    _lessonSubject = v;
                    _target = null;
                    _lessons = v == null ? null : ref.read(eduRepositoryProvider).subject(v).then((s) => [for (final u in asJsonList(s['units'])) ...asJsonList(u['lessons']), ...asJsonList(s['lessons'])]);
                  }
                }),
              ),
            ),
          if (_type == 'lesson' && _lessons != null) ...[
            const SizedBox(height: 10),
            FutureBuilder<List<Json>>(
              future: _lessons,
              builder: (context, snap) => DropdownButtonFormField<int?>(
                initialValue: _target,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.elLesson),
                items: [for (final x in snap.data ?? const <Json>[]) DropdownMenuItem<int?>(value: asInt(x['id']), child: Text(asStr(x['title']) ?? '', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
          ],
          if (_type == 'class')
            FutureBuilder<List<Json>>(
              future: _classes(),
              builder: (context, snap) => DropdownButtonFormField<int?>(
                initialValue: (snap.data ?? const []).any((c) => asInt(c['id']) == _target) ? _target : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.elClass),
                items: [for (final c in snap.data ?? const <Json>[]) DropdownMenuItem<int?>(value: asInt(c['id']), child: Text('${c['name']}'))],
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
          const SizedBox(height: 10),
          TextField(controller: _title, decoration: InputDecoration(labelText: l.elTitleOverride, helperText: l.elTitleOverrideHint)),
          const SizedBox(height: 10),
          TextField(controller: _subtitle, decoration: InputDecoration(labelText: l.elSubtitle)),
          const SizedBox(height: 10),
          DateTimeField(label: l.elShowFrom, value: _starts, clearable: true, onChanged: (v) => setState(() => _starts = v)),
          const SizedBox(height: 10),
          DateTimeField(label: l.elShowUntil, value: _ends, clearable: true, onChanged: (v) => setState(() => _ends = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.elStatusActive), value: _active, onChanged: (v) => setState(() => _active = v)),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

// =============================================================================
// Subject curriculum: details (editors), units and lessons (editors and the subject's teachers)
// =============================================================================
class EduSubjectEditorScreen extends ConsumerWidget {
  const EduSubjectEditorScreen({super.key, required this.subjectId});
  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final editor = user?.canAny([Perm.educationContent, Perm.educationManage]) ?? false;
    final async = ref.watch(eduSubjectProvider(subjectId));
    final repo = ref.read(eduRepositoryProvider);
    void reload() {
      ref.invalidate(eduSubjectProvider(subjectId));
      ref.invalidate(eduCategoriesProvider);
    }

    Future<void> unitDialog([Json? u]) async {
      final unitId = asInt(u?['id']);
      if (unitId != null) {
        await context.push('/edu/content/unit/$unitId?subject_id=$subjectId');
      } else {
        await context.push('/edu/content/unit/new?subject_id=$subjectId');
      }
      reload();
    }

    return PatternScaffold(
      appBar: AppBar(
        title: Text(async.value == null ? l.elEditCurriculum : eduNames(context, async.value!).title),
        actions: [
          IconButton(tooltip: l.elPreview, icon: const Icon(Icons.visibility_outlined), onPressed: () => context.push('/edu/learn/subject/$subjectId')),
          if (editor && async.value != null)
            IconButton(
              tooltip: l.elEditSubject,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                final id = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: SubjectForm(subject: async.value)),
                );
                if (id != null) reload();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-lesson',
        onPressed: () async {
          await context.push('/edu/content/subject/$subjectId/new-lesson');
          reload();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.elNewLesson),
      ),
      body: AsyncView(
        value: async,
        onRetry: reload,
        data: (s) {
          final units = asJsonList(s['units']);
          final loose = asJsonList(s['lessons']);
          final classes = asJsonList(s['classes']);
          Widget lessonRow(Json x) => TrackTile(
                title: asStr(x['title']) ?? '',
                subtitle: [_statusLabel(l, asStr(x['status'])), if (asIntOr(x['material_count']) > 0) l.elMaterialCount(asIntOr(x['material_count']))].join(' · '),
                leading: ListThumb(icon: x['status'] == 'published' ? Icons.article_rounded : Icons.edit_note_rounded, active: x['status'] == 'published'),
                trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                onTap: () async {
                  await context.push('/edu/content/lesson/${x['id']}');
                  reload();
                },
              );
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Pill(_statusLabel(l, asStr(s['status']))),
                    Pill(s['visibility'] == 'members' ? l.elVisibilityMembers : l.elVisibilityEnrolled),
                    if (asBool(s['sequential'])) Pill(l.elSequential),
                  ]),
                  const SizedBox(height: 8),
                  Text(classes.isEmpty ? l.elNotLinkedYet : l.elTaughtIn(classes.map((c) => '${c['class_name']} — ${c['course_name']}').join(', ')), style: context.sans(12.5, color: p.muted, height: 1.5)),
                ]),
              ),
              SectionHeader(title: l.elUnits, trailing: l.elNewUnit, onTrailingTap: () => unitDialog()),
              if (units.isEmpty) Text(l.elNoUnits, style: context.sans(12.5, color: p.muted)),
              for (final u in units) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: Text(asStr(u['title']) ?? '', style: context.serif(15, color: p.primary))),
                    IconButton(tooltip: l.elRenameUnit, icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => unitDialog(u)),
                    IconButton(
                      tooltip: l.delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      onPressed: () async {
                        if (!await showConfirm(context, l.elDeleteUnitConfirm, destructive: true) || !context.mounted) return;
                        final r = await runWithProgress(context, () => repo.deleteUnit(asIntOr(u['id'])));
                        if (r != null) reload();
                      },
                    ),
                  ]),
                ),
                for (final x in asJsonList(u['lessons'])) lessonRow(x),
              ],
              if (loose.isNotEmpty) ...[
                SectionHeader(title: units.isEmpty ? l.elLessons : l.elMoreLessons),
                for (final x in loose) lessonRow(x),
              ],
              SectionHeader(
                title: l.elQuizzes,
                trailing: l.elNewQuiz,
                onTrailingTap: () async {
                  final title = await promptText(context, title: l.elNewQuiz, label: l.elTitle, required: true);
                  final trimmed = title?.trim() ?? '';
                  if (trimmed.isEmpty || !context.mounted) return;
                  final q = await runWithProgress(context, () => repo.createSubjectQuiz(subjectId, {'title': trimmed}));
                  if (q != null && context.mounted) {
                    await context.push('/edu/quiz-edit/${q['id']}');
                    reload();
                  }
                },
              ),
              if (asJsonList(s['quizzes']).isEmpty)
                Text(l.elNoQuizzes, style: context.sans(12.5, color: p.muted))
              else
                for (final q in asJsonList(s['quizzes']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TrackTile(
                      title: asStr(q['title']) ?? '',
                      subtitle: [
                        _statusLabel(l, asStr(q['status'])),
                        if (asStr(q['class_name']) != null) asStr(q['class_name'])!,
                        l.elQuestionCount(asIntOr(q['question_count'])),
                      ].join(' · '),
                      leading: const ListThumb(icon: Icons.quiz_outlined, active: true),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l.elResults,
                            icon: Icon(Icons.leaderboard_outlined, color: p.muted, size: 20),
                            onPressed: () => context.push('/edu/quiz-results/${q['id']}'),
                          ),
                          Icon(Icons.chevron_right_rounded, color: p.faint),
                        ],
                      ),
                      onTap: () async {
                        await context.push('/edu/quiz-edit/${q['id']}');
                        reload();
                      },
                    ),
                  ),
            ]),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Unit editor: bilingual title and description, status, lessons list
// =============================================================================
class EduUnitEditorScreen extends ConsumerStatefulWidget {
  const EduUnitEditorScreen({super.key, this.unitId, this.subjectId});
  final int? unitId;
  final int? subjectId;

  @override
  ConsumerState<EduUnitEditorScreen> createState() => _EduUnitEditorScreenState();
}

class _EduUnitEditorScreenState extends ConsumerState<EduUnitEditorScreen> {
  final _title = TextEditingController();
  final _titleEn = TextEditingController();
  final _desc = TextEditingController();
  final _descEn = TextEditingController();
  String _status = 'published';
  int? _unitId;
  int? _subjectId;
  List<Json> _lessons = const [];
  Future<List<Json>>? _subjectsFuture;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _unitId = widget.unitId;
    _subjectId = widget.subjectId;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleEn.dispose();
    _desc.dispose();
    _descEn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(eduRepositoryProvider);
      if (_subjectId == null || widget.subjectId == null) {
        _subjectsFuture = repo.subjects(all: true);
      }
      if (_unitId != null) {
        final u = await repo.unit(_unitId!);
        if (!mounted) return;
        _subjectId = asInt(u['subject_id']) ?? _subjectId;
        _title.text = asStr(u['title']) ?? '';
        _titleEn.text = asStr(u['title_en']) ?? '';
        _desc.text = asStr(u['description']) ?? '';
        _descEn.text = asStr(u['description_en']) ?? '';
        _status = asStr(u['status']) ?? 'published';
        _lessons = asJsonList(u['lessons']);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<bool> _save() async {
    final l = context.l10n;
    final isEn = l.isEn;
    if (_title.text.trim().isEmpty) {
      showSnack(context, l.elNameRequired);
      return false;
    }
    if (_status == 'published' && _titleEn.text.trim().isEmpty) {
      showSnack(context, isEn ? 'English title is required for published units' : 'ለታተሙ ምዕራፎች የእንግሊዝኛ ርዕስ ያስፈልጋል');
      return false;
    }
    if (_subjectId == null) {
      showSnack(context, isEn ? 'Please select a subject' : 'እባክዎ የትምህርት ዓይነት ይምረጡ');
      return false;
    }

    final repo = ref.read(eduRepositoryProvider);
    final payload = {
      'subject_id': _subjectId,
      'title': _title.text.trim(),
      'title_en': _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'description_en': _descEn.text.trim().isEmpty ? null : _descEn.text.trim(),
      'status': _status,
    };

    final r = await runWithProgress(
      context,
      () => _unitId == null
          ? repo.createUnit(_subjectId!, payload)
          : repo.updateUnit(_unitId!, payload),
      success: l.saved,
    );

    if (r == null) return false;

    if (mounted) {
      setState(() {
        _unitId = asInt(r['id']) ?? _unitId;
        if (r['unit'] is Map) {
          final u = asJson(r['unit']);
          _lessons = asJsonList(u['lessons']);
        }
      });
      ref.invalidate(eduSubjectProvider(_subjectId!));
      ref.invalidate(eduCategoriesProvider);
      ref.invalidate(eduDashboardProvider);
      ref.read(contentRevisionProvider.notifier).bump();
    }
    return true;
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elDeleteUnitConfirm, destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteUnit(_unitId!);
      return true;
    });
    if (ok == true && mounted) {
      if (_subjectId != null) {
        ref.invalidate(eduSubjectProvider(_subjectId!));
        ref.invalidate(eduCategoriesProvider);
        ref.invalidate(eduDashboardProvider);
        ref.read(contentRevisionProvider.notifier).bump();
      }
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(_unitId == null ? l.elNewUnit : (isEn ? 'Edit Unit' : 'ምዕራፍ አርትዕ')),
        actions: [
          if (_subjectId != null)
            IconButton(
              tooltip: l.elPreview,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () async {
                final ok = await _save();
                if (ok && context.mounted) {
                  ref.invalidate(eduSubjectProvider(_subjectId!));
                  context.push('/edu/learn/subject/$_subjectId');
                }
              },
            ),
          if (_unitId != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    if (widget.subjectId == null) ...[
                      FutureBuilder<List<Json>>(
                        future: _subjectsFuture,
                        builder: (context, snap) => DropdownButtonFormField<int?>(
                          initialValue: _subjectId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Subject *' : 'የትምህርት ዓይነት *',
                          ),
                          items: [
                            for (final s in snap.data ?? const <Json>[])
                              DropdownMenuItem<int?>(
                                value: asInt(s['id']),
                                child: Text(eduNames(context, s).title, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => _subjectId = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        labelText: '${l.elTitle} (አማርኛ) *',
                        hintText: 'ምዕራፍ ፩...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleEn,
                      decoration: InputDecoration(
                        labelText: '${l.elTitle} (English)',
                        hintText: 'Unit 1...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _desc,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '${l.elDescription} (አማርኛ)',
                        hintText: 'የምዕራፉ ማጠቃለያ...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descEn,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '${l.elDescription} (English)',
                        hintText: 'Unit summary in English...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: l.elStatus),
                      items: [
                        for (final s in const ['published', 'draft', 'archived'])
                          DropdownMenuItem(value: s, child: Text(_statusLabel(l, s)))
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'published'),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l.save),
                    ),
                    if (_unitId != null) ...[
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: l.elLessons,
                        trailing: l.elNewLesson,
                        onTrailingTap: () async {
                          await context.push('/edu/content/lesson/new?subject_id=$_subjectId&unit_id=$_unitId');
                          _load();
                        },
                      ),
                      if (_lessons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l.elNoLessonsYet, style: context.sans(12.5, color: p.muted)),
                        )
                      else
                        for (final lesson in _lessons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TrackTile(
                              title: asStr(lesson['title']) ?? '',
                              subtitle: asStr(lesson['summary']),
                              leading: const ListThumb(icon: Icons.auto_stories_rounded, active: true),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                await context.push('/edu/content/lesson/${lesson['id']}');
                                _load();
                              },
                            ),
                          ),
                    ],
                  ],
                ),
    );
  }
}

// =============================================================================
// Lesson editor: text with simple formatting, references, notes, status, materials
// =============================================================================
class EduLessonEditorScreen extends ConsumerStatefulWidget {
  const EduLessonEditorScreen({super.key, this.lessonId, this.subjectId, this.unitId});
  final int? lessonId;
  final int? subjectId;
  final int? unitId;
  @override
  ConsumerState<EduLessonEditorScreen> createState() => _EduLessonEditorScreenState();
}

class _EduLessonEditorScreenState extends ConsumerState<EduLessonEditorScreen> {
  final _title = TextEditingController();
  final _titleEn = TextEditingController();
  final _summary = TextEditingController();
  final _summaryEn = TextEditingController();
  final _body = TextEditingController();
  final _bodyEn = TextEditingController();
  final _refs = TextEditingController();
  final _objectives = TextEditingController();
  final _objectivesEn = TextEditingController();
  final _notes = TextEditingController();
  final _minutes = TextEditingController();
  bool _requiresQuiz = false;
  String _status = 'draft';
  int? _unit;
  int? _subjectId;
  int? _lessonId;
  List<Json> _units = const [];
  List<Json> _materials = const [];
  List<Json> _quizzes = const [];
  bool _loading = true;
  bool _preview = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _lessonId = widget.lessonId;
    _subjectId = widget.subjectId;
    _unit = widget.unitId;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _titleEn, _summary, _summaryEn, _body, _bodyEn, _refs, _objectives, _objectivesEn, _notes, _minutes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(eduRepositoryProvider);
    try {
      if (_lessonId != null) {
        final x = await repo.lesson(_lessonId!);
        _subjectId = asIntOr(asJson(x['subject'])['id']);
        _title.text = asStr(x['title']) ?? '';
        _titleEn.text = asStr(x['title_en']) ?? '';
        _summary.text = asStr(x['summary']) ?? '';
        _summaryEn.text = asStr(x['summary_en']) ?? '';
        _body.text = asStr(x['body']) ?? '';
        _bodyEn.text = asStr(x['body_en']) ?? '';
        _refs.text = asStr(x['scripture_refs']) ?? '';
        _objectives.text = asStr(x['objectives']) ?? '';
        _objectivesEn.text = asStr(x['objectives_en']) ?? '';
        _notes.text = asStr(x['teacher_notes']) ?? '';
        _minutes.text = asInt(x['est_minutes'])?.toString() ?? '';
        _status = asStr(x['status']) ?? 'draft';
        _requiresQuiz = asBool(x['requires_quiz']);
        _unit = asInt(x['unit_id']) ?? widget.unitId;
        _materials = asJsonList(x['materials']);
        _quizzes = asJsonList(x['quizzes']);
      }
      if (_subjectId != null) {
        final s = await repo.subject(_subjectId!);
        _units = asJsonList(s['units']);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Json _payload() {
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'title': _title.text.trim(),
      'title_en': t(_titleEn),
      'unit_id': _unit,
      'summary': t(_summary),
      'summary_en': t(_summaryEn),
      'body': _body.text.trim().isEmpty ? null : _body.text,
      'body_en': _bodyEn.text.trim().isEmpty ? null : _bodyEn.text,
      'scripture_refs': t(_refs),
      'objectives': t(_objectives),
      'objectives_en': t(_objectivesEn),
      'teacher_notes': t(_notes),
      'est_minutes': int.tryParse(_minutes.text.trim()),
      'status': _status,
      'requires_quiz': _requiresQuiz,
    };
  }

  Future<bool> _save() async {
    final l = context.l10n;
    final isEn = l.isEn;
    if (_title.text.trim().isEmpty) {
      showSnack(context, l.elNameRequired);
      return false;
    }
    if (_status == 'published' && _titleEn.text.trim().isEmpty) {
      showSnack(context, isEn ? 'English title is required for published lessons' : 'ለታተሙ ትምህርቶች የእንግሊዝኛ ርዕስ ያስፈልጋል');
      return false;
    }
    final repo = ref.read(eduRepositoryProvider);
    final r = await runWithProgress(context, () => _lessonId == null ? repo.createLesson(_subjectId!, _payload()) : repo.updateLesson(_lessonId!, _payload()), success: l.saved);
    if (r == null) return false;
    setState(() {
      _lessonId = asInt(r['id']);
      _materials = asJsonList(r['materials']);
    });
    ref.invalidate(eduSubjectProvider(_subjectId!));
    if (_lessonId != null) ref.invalidate(eduLessonProvider(_lessonId!));
    ref.invalidate(eduCategoriesProvider);
    ref.invalidate(eduDashboardProvider);
    ref.read(contentRevisionProvider.notifier).bump();
    return true;
  }

  Future<void> _addFile() async {
    final l = context.l10n;
    if (_lessonId == null && !await _save()) return;
    if (!mounted) return;
    final f = await pickTypedFile(context, kinds: const {PickKind.document, PickKind.image, PickKind.audio});
    if (f == null || !mounted) return;
    final title = await promptText(context, title: l.elMaterialTitle, label: l.elTitle, initial: f.name.contains('.') ? f.name.substring(0, f.name.lastIndexOf('.')) : f.name);
    if (!mounted) return;
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).uploadMaterial(_lessonId!, f.path, title: (title ?? '').isEmpty ? null : title));
    if (r != null) setState(() => _materials = [..._materials, r]);
  }

  Future<void> _addLink() async {
    if (_lessonId == null && !await _save()) return;
    if (!mounted) return;
    final r = await showDialog<Json>(context: context, builder: (_) => const _LinkDialog());
    if (r == null || !mounted) return;
    final m = await runWithProgress(context, () => ref.read(eduRepositoryProvider).addLink(_lessonId!, kind: r['kind'] as String, title: r['title'] as String, url: r['url'] as String));
    if (m != null) setState(() => _materials = [..._materials, m]);
  }

  Future<void> _deleteMaterial(Json m) async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elDeleteMaterialConfirm, destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteMaterial(asIntOr(m['id']));
      return true;
    });
    if (ok == true) setState(() => _materials = _materials.where((x) => x['id'] != m['id']).toList());
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.elDeleteLessonConfirm, destructive: true) || !mounted) return;
    final ok = await runWithProgress(context, () async {
      await ref.read(eduRepositoryProvider).deleteLesson(_lessonId!);
      return true;
    });
    if (ok == true && mounted) {
      ref.invalidate(eduSubjectProvider(_subjectId!));
      ref.read(contentRevisionProvider.notifier).bump();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;
    return PatternScaffold(
      appBar: AppBar(
        title: Text(_lessonId == null ? l.elNewLesson : l.elEditLesson),
        actions: [
          IconButton(
            tooltip: l.elPreview,
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () async {
              final ok = await _save();
              if (!ok || _lessonId == null) return;
              if (context.mounted) {
                ref.invalidate(eduLessonProvider(_lessonId!));
                context.push('/edu/learn/lesson/$_lessonId');
              }
            },
          ),
          if (_lessonId != null) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : _loading
              ? const LoadingView()
              : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                  TextField(controller: _title, decoration: InputDecoration(labelText: '${l.elTitle} (አማርኛ) *')),
                  const SizedBox(height: 10),
                  TextField(controller: _titleEn, decoration: InputDecoration(labelText: '${l.elTitle} (English)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _units.any((u) => asInt(u['id']) == _unit) ? _unit : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.elUnit),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(l.none)),
                      for (final u in _units) DropdownMenuItem<int?>(value: asInt(u['id']), child: Text(asStr(u['title']) ?? '', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _unit = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _summary, maxLines: 2, decoration: InputDecoration(labelText: '${l.elSummary} (አማርኛ)')),
                  const SizedBox(height: 10),
                  TextField(controller: _summaryEn, maxLines: 2, decoration: InputDecoration(labelText: '${l.elSummary} (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: _refs, decoration: InputDecoration(labelText: l.elScriptureRefs, hintText: l.elScriptureRefsHint)),
                  const SizedBox(height: 10),
                  TextField(controller: _minutes, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.elEstMinutes)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('${l.elLessonText} (አማርኛ)', style: context.sans(13, weight: FontWeight.w700)),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: [ButtonSegment(value: false, label: Text(l.edit)), ButtonSegment(value: true, label: Text(l.elPreview))],
                      selected: {_preview},
                      onSelectionChanged: (s) => setState(() => _preview = s.first),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (_preview)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                      child: LessonBody(body: _body.text),
                    )
                  else ...[
                    TextField(controller: _body, maxLines: 14, minLines: 8, decoration: const InputDecoration(alignLabelWithHint: true, hintText: 'የትምህርቱ ዝርዝር ጽሑፍ...')),
                    const SizedBox(height: 4),
                    Text(l.elFormattingHelp, style: context.sans(11.5, color: p.muted, height: 1.5)),
                  ],
                  const SizedBox(height: 14),
                  Text('${l.elLessonText} (English)', style: context.sans(13, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(controller: _bodyEn, maxLines: 10, minLines: 5, decoration: const InputDecoration(alignLabelWithHint: true, hintText: 'Lesson body text in English...')),
                  const SizedBox(height: 10),
                  TextField(controller: _objectives, maxLines: 3, decoration: InputDecoration(labelText: '${l.elObjectives} (አማርኛ)')),
                  const SizedBox(height: 10),
                  TextField(controller: _objectivesEn, maxLines: 3, decoration: InputDecoration(labelText: '${l.elObjectives} (English)')),
                  const SizedBox(height: 10),
                  TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: l.elTeacherNotes, helperText: l.elTeacherNotesHint)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(labelText: l.elStatus),
                    items: [for (final s in const ['draft', 'published', 'archived']) DropdownMenuItem(value: s, child: Text(_statusLabel(l, s)))],
                    onChanged: (v) => setState(() => _status = v ?? 'draft'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isEn ? 'Require Quiz Completion' : 'ፈተና ማጠናቀቅን ይጠይቃል'),
                    subtitle: Text(isEn
                        ? 'Student must complete any attached quiz before unlocking next lesson'
                        : 'ተማሪው ቀጣዩን ትምህርት ከመክፈቱ በፊት የተያያዘውን ፈተና ማጠናቀቅ አለበት'),
                    value: _requiresQuiz,
                    onChanged: (v) => setState(() => _requiresQuiz = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: Text(l.save)),
                  SectionHeader(title: l.elMaterials),
                  Text(l.elMaterialsHint, style: context.sans(12, color: p.muted, height: 1.5)),
                  const SizedBox(height: 8),
                  for (final m in _materials)
                    MaterialTile(material: m, trailing: IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _deleteMaterial(m))),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(onPressed: _addFile, icon: const Icon(Icons.upload_file_rounded), label: Text(l.elUploadFile)),
                    OutlinedButton.icon(onPressed: _addLink, icon: const Icon(Icons.add_link_rounded), label: Text(l.elAddLink)),
                  ]),
                  if (_lessonId != null) ...[
                    SectionHeader(
                      title: l.elQuizzes,
                      trailing: l.elNewQuiz,
                      onTrailingTap: () async {
                        if (_subjectId == null) return;
                        final title = await promptText(context, title: l.elNewQuiz, label: l.elTitle, required: true);
                        final trimmed = title?.trim() ?? '';
                        if (trimmed.isEmpty || !context.mounted) return;
                        final q = await runWithProgress(context, () => ref.read(eduRepositoryProvider).createSubjectQuiz(_subjectId!, {'title': trimmed, 'lesson_id': _lessonId}));
                        if (q != null && context.mounted) {
                          await context.push('/edu/quiz-edit/${q['id']}');
                          _load();
                        }
                      },
                    ),
                    if (_quizzes.isEmpty)
                      Text(l.elNoQuizzes, style: context.sans(12.5, color: p.muted))
                    else
                      for (final q in _quizzes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TrackTile(
                            title: asStr(q['title']) ?? '',
                            subtitle: [_statusLabel(l, asStr(q['status'])), if (asStr(q['class_name']) != null) asStr(q['class_name'])!].join(' · '),
                            leading: const ListThumb(icon: Icons.quiz_outlined, active: true),
                            trailing: Icon(Icons.chevron_right_rounded, color: p.faint),
                            onTap: () async {
                              await context.push('/edu/quiz-edit/${q['id']}');
                              _load();
                            },
                          ),
                        ),
                  ],
                ]),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _title = TextEditingController();
  final _titleEn = TextEditingController();
  final _url = TextEditingController();
  String _kind = 'video_link';

  @override
  void dispose() {
    _title.dispose();
    _titleEn.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.elAddLink),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'video_link', label: Text(l.elVideoLink)), ButtonSegment(value: 'link', label: Text(l.elWebLink))],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 10),
        TextField(controller: _title, decoration: InputDecoration(labelText: '${l.elTitle} (አማርኛ) *')),
        const SizedBox(height: 10),
        TextField(controller: _titleEn, decoration: InputDecoration(labelText: '${l.elTitle} (English)')),
        const SizedBox(height: 10),
        TextField(controller: _url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'https://…')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final url = _url.text.trim();
            final u = Uri.tryParse(url);
            if (_title.text.trim().isEmpty || u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty) return showSnack(context, l.elBadLink);
            Navigator.pop(context, {
              'kind': _kind,
              'title': _title.text.trim(),
              'title_en': _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
              'url': url,
            });
          },
          child: Text(l.ok),
        ),
      ],
    );
  }
}
