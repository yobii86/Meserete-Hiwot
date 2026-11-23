import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/admin.dart';
import '../../models/content.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../hub/hub_screen.dart' show hubBannersProvider;
import '../../core/utils/lrc.dart';
import 'admin_widgets.dart';
import 'lrc_maker.dart';
import 'drafts.dart';
import 'programs_admin.dart' show createProgram, pickProgram;

final adminCategoryTreeProvider = FutureProvider.autoDispose<List<CategoryNode>>((ref) => ref.watch(adminRepositoryProvider).categoryTree());

String statusLabel(AppLocalizations l, String s) => switch (s) {
  'published' => l.statusPublished,
  'archived' => l.statusArchived,
  'cancelled' => l.statusCancelled,
  'completed' => l.statusCompleted,
  _ => l.statusDraft,
};

/// Category dropdown (flattened tree with indentation).
class CategoryDropdown extends ConsumerWidget {
  const CategoryDropdown({super.key, required this.value, required this.onChanged, this.label, this.allowNone = true, this.excludeId, this.allowCreate = true});
  final bool allowCreate;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? label;
  final bool allowNone;
  final int? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tree = ref.watch(adminCategoryTreeProvider).value ?? const [];
    final flat = tree.expand((c) => c.flatten()).where((c) => c.id != excludeId).toList();
    final canCreate = allowCreate && (ref.watch(currentUserProvider)?.can(Perm.categoriesManage) ?? false);
    final dropdown = DropdownButtonFormField<int?>(
      key: ValueKey('cat-${value ?? 0}-${flat.length}'),
      initialValue: flat.any((c) => c.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label ?? l.category),
      items: [
        if (allowNone) DropdownMenuItem(value: null, child: Text(label == l.parentCategory ? l.topLevel : l.noCategory)),
        for (final c in flat)
          DropdownMenuItem(
            value: c.id,
            child: Text('${'  ' * c.depth}${c.depth > 0 ? '› ' : ''}${c.name}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
    if (!canCreate) return dropdown;
    return Row(
      children: [
        Expanded(child: dropdown),
        IconButton(
          tooltip: l.newCategory,
          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
          onPressed: () async {
            final c = await showCategoryEditor(context, returnOnCreate: true);
            if (c == null) return;
            ref.invalidate(adminCategoryTreeProvider);
            onChanged(c.id);
          },
        ),
      ],
    );
  }
}

// =============================================================================
// Mezmurs
// =============================================================================
class MezmursAdminScreen extends ConsumerStatefulWidget {
  const MezmursAdminScreen({super.key});
  @override
  ConsumerState<MezmursAdminScreen> createState() => _MezmursAdminScreenState();
}

class _MezmursAdminScreenState extends ConsumerState<MezmursAdminScreen> {
  final _ctrl = PagedListController<MezmurSummary>();
  String _q = '';
  String? _status;
  int? _category;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    return AdminScaffold(
      title: l.mezmurs,
      actions: const [
        ContextualHelpButton(screenRoute: '/admin/mezmurs'),
      ],
      fab: me.can(Perm.mezmursCreate)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/mezmurs/edit/new').then((_) => _ctrl.refresh()),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.newMezmur),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _status,
                    isDense: true,
                    decoration: InputDecoration(labelText: l.status, isDense: true),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.all)),
                      for (final s in ['published', 'draft', 'archived']) DropdownMenuItem(value: s, child: Text(statusLabel(l, s))),
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CategoryDropdown(value: _category, onChanged: (v) => setState(() => _category = v)),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<MezmurSummary>(
              key: ValueKey('$_q|$_status|$_category'),
              controller: _ctrl,
              fetch: (page) => repo.mezmurs(q: _q.isEmpty ? null : _q, status: _status, categoryId: _category, page: page),
              emptyMessage: l.noResults,
              itemBuilder: (context, m, _) => TrackTile(
                title: m.title,
                subtitle: [statusLabel(l, m.status), if (m.categoryName != null) m.categoryName!, if (m.hasAudio) l.audio].join(' · '),
                leading: ListThumb(icon: m.hasAudio ? Icons.music_note_rounded : Icons.menu_book_rounded, imageUrl: m.coverUrl),
                trailing: m.isFeatured ? const Icon(Icons.star_rounded, color: AppColors.gold, size: 18) : null,
                onTap: () => context.push('/admin/mezmurs/edit/${m.id}').then((_) => _ctrl.refresh()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MezmurEditorScreen extends ConsumerStatefulWidget {
  const MezmurEditorScreen({super.key, this.mezmurId, this.initialCategoryId});
  final int? mezmurId;

  /// New Mezmur started from a category page (edit mode): that category is preselected.
  final int? initialCategoryId;
  @override
  ConsumerState<MezmurEditorScreen> createState() => _MezmurEditorScreenState();
}

class _MezmurEditorScreenState extends ConsumerState<MezmurEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _lyrics = TextEditingController();
  final _desc = TextEditingController();
  final _tags = TextEditingController();
  final _duration = TextEditingController();
  final _youtube = TextEditingController();
  final _lrc = TextEditingController();
  int? _categoryId;
  String _status = 'draft';
  bool _featured = false;
  Mezmur? _loaded;
  bool _loading = false;
  bool _saving = false;
  Object? _error;
  double? _uploadProgress;
  // Every change is kept as a local draft until Save; see _leave for new Mezmurs.
  late final DraftKeeper _draft = DraftKeeper(ref.read(localPrefsProvider), 'mezmur:${widget.mezmurId ?? 'new'}');
  late final _repo = ref.read(adminRepositoryProvider);
  bool _restored = false;
  bool _submitted = false;

  int? get _id => _loaded?.id ?? widget.mezmurId;

  Json _snapshot() => {
    'title': _title.text,
    'lyrics': _lyrics.text,
    'description': _desc.text,
    'tags': _tags.text,
    'duration': _duration.text,
    'youtube': _youtube.text,
    'lrc': _lrc.text,
    'category_id': _categoryId,
    'status': _status,
    'featured': _featured,
  };

  void _restore(Json d) {
    _title.text = asStr(d['title']) ?? '';
    _lyrics.text = asStr(d['lyrics']) ?? '';
    _desc.text = asStr(d['description']) ?? '';
    _tags.text = asStr(d['tags']) ?? '';
    _duration.text = asStr(d['duration']) ?? '';
    _youtube.text = asStr(d['youtube']) ?? '';
    _lrc.text = asStr(d['lrc']) ?? '';
    _categoryId = asInt(d['category_id']);
    _status = asStr(d['status']) ?? 'draft';
    _featured = asBool(d['featured']);
  }

  /// Compare with the saved version and bring back unsaved changes from last time.
  void _checkDraft() {
    _draft.setBaseline(_snapshot());
    final d = _draft.pending();
    if (d != null) {
      _restore(d);
      _restored = true;
    }
  }

  void _discardDraft() {
    if (_loaded != null) {
      _apply(_loaded!);
    } else {
      _restore({'category_id': widget.initialCategoryId});
    }
    unawaited(_draft.clear(baseline: _snapshot()));
    setState(() => _restored = false);
  }

  /// Leaving without Save: a new Mezmur with a title and lyrics is stored on the server as a draft;
  /// otherwise the local draft stays and is restored next time.
  void _leave() {
    _draft.flush();
    if (_submitted || _id != null || _title.text.trim().isEmpty || _lyrics.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    unawaited(
      _repo
          .createMezmur({..._body(), 'status': 'draft'})
          .then((_) async {
            await ref.read(localPrefsProvider).removeDraft('mezmur:new');
            messenger?.showSnackBar(SnackBar(content: Text(l.savedAsDraft)));
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    _categoryId ??= widget.initialCategoryId;
    if (widget.mezmurId != null) {
      _load(widget.mezmurId!);
    } else {
      _checkDraft();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    try {
      _apply(await ref.read(adminRepositoryProvider).mezmur(id));
      _checkDraft();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Mezmur m) {
    _loaded = m;
    _title.text = m.title;
    _lyrics.text = m.lyrics;
    _desc.text = m.description ?? '';
    _tags.text = m.tags.join(', ');
    _duration.text = m.audio?.durationSec?.toString() ?? '';
    _youtube.text = m.youtubeUrl ?? '';
    _lrc.text = m.lrc ?? '';
    _categoryId = m.summary.categoryId;
    _status = m.summary.status;
    _featured = m.summary.isFeatured;
  }

  Future<bool> _save({bool quiet = false}) async {
    if (!_form.currentState!.validate()) {
      showSnack(context, context.l10n.checkFields);
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = _body();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final m = _id == null ? await repo.createMezmur(body) : await repo.updateMezmur(_id!, body);
      setState(() {
        _apply(m);
        _restored = false;
      });
      _submitted = true;
      await _draft.rekey('mezmur:${m.id}');
      await _draft.clear(baseline: _snapshot());
      if (mounted && !quiet) showSnack(context, context.l10n.saved);
      return true;
    } catch (e) {
      setState(() => _error = e);
      _form.currentState!.validate();
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Json _body() => {
    'title': _title.text.trim(),
    'lyrics': _lyrics.text.trim(),
    'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    'category_id': _categoryId,
    'status': _status,
    'is_featured': _featured,
    'tags': _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
    'youtube_url': _youtube.text.trim(),
    'lrc': _lrc.text.trim(),
    if (int.tryParse(_duration.text.trim()) != null) 'audio_duration_sec': int.parse(_duration.text.trim()),
  };

  /// A .lrc file chosen on the phone goes into the synced-lyrics field (saved with Save).
  Future<void> _pickLrc() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty || !mounted) return;
    final f = res.first;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
    if (parseLrc(text).isEmpty) {
      showSnack(context, context.l10n.lrcInvalid);
      return;
    }
    setState(() => _lrc.text = text.trim());
    _draft.changed(_snapshot());
    showSnack(context, context.l10n.lrcLoaded('${parseLrc(text).length}'));
  }

  /// Time the lyrics in the app while the recording plays, then save.
  Future<void> _makeLrc() async {
    final m = _loaded;
    final track = m == null ? null : PlayerTrack.fromMezmur(m);
    if (track == null) return;
    final lrc = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => LrcMakerScreen(track: track, lyrics: _lyrics.text, existing: _lrc.text)),
    );
    if (lrc == null || !mounted) return;
    setState(() => _lrc.text = lrc);
    await _save();
  }

  Future<void> _uploadAudio() async {
    final path = await pickAudioPath(context);
    if (path == null || !mounted) return;
    if (_id == null) {
      // New Mezmur: save it first so the recording has something to attach to.
      if (!await _save(quiet: true) || !mounted) return;
      showSnack(context, context.l10n.savedForUpload);
    }
    setState(() => _uploadProgress = 0);
    try {
      final m = await ref
          .read(adminRepositoryProvider)
          .uploadAudio(
            _id!,
            path,
            durationSec: int.tryParse(_duration.text.trim()),
            onProgress: (p) {
              if (mounted) setState(() => _uploadProgress = p);
            },
          );
      setState(() => _apply(m));
      if (mounted) showSnack(context, context.l10n.uploadDone);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final me = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    final canEdit = _id == null ? me.can(Perm.mezmursCreate) : me.can(Perm.mezmursUpdate);
    if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _draft.changed(_snapshot()));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: AdminScaffold(
        title: _id == null ? l.newMezmur : l.editMezmur,
        actions: [
          if (_id != null && me.can(Perm.mezmursDelete))
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                final ok = await runWithProgress(context, () async {
                  await repo.deleteMezmur(_id!);
                  return true;
                }, success: l.deleted);
                if (ok == true && context.mounted) context.pop();
              },
            ),
        ],
        body: _loading
            ? const LoadingView()
            : Form(
                key: _form,
                onChanged: () => _draft.changed(_snapshot()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_restored) DraftRestoredBanner(onDiscard: _discardDraft),
                    TextFormField(
                      controller: _title,
                      enabled: canEdit,
                      validator: (s) => v.text(s, max: 255),
                      decoration: InputDecoration(labelText: l.title),
                    ),
                    const SizedBox(height: 12),
                    CategoryDropdown(value: _categoryId, onChanged: canEdit ? (x) => setState(() => _categoryId = x) : (_) {}),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lyrics,
                      enabled: canEdit,
                      minLines: 8,
                      maxLines: 24,
                      validator: (s) => v.text(s, max: 100000),
                      style: context.serif(15, weight: FontWeight.w500, color: context.palette.text, height: 1.7),
                      decoration: InputDecoration(labelText: l.lyrics, alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      enabled: canEdit,
                      maxLines: 3,
                      validator: (s) => v.text(s, max: 2000, optional: true),
                      decoration: InputDecoration(labelText: l.description),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tags,
                      enabled: canEdit,
                      decoration: InputDecoration(labelText: l.tagsHint),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _youtube,
                      enabled: canEdit,
                      keyboardType: TextInputType.url,
                      validator: v.youtube,
                      decoration: InputDecoration(
                        labelText: l.youtubeLink,
                        hintText: 'https://youtu.be/…',
                        prefixIcon: const Icon(Icons.smart_display_outlined),
                        errorText: serverFieldError(l, _error, 'youtube_url'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: l.status),
                      items: [
                        for (final s in ['draft', 'published', 'archived']) DropdownMenuItem(value: s, child: Text(statusLabel(l, s))),
                      ],
                      onChanged: canEdit ? (x) => setState(() => _status = x!) : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.featuredFlag),
                      value: _featured,
                      onChanged: canEdit ? (x) => setState(() => _featured = x) : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
                      ),
                    if (_id != null && canEdit)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.today_rounded, color: AppColors.gold),
                        title: Text(l.markToday),
                        value: _loaded?.summary.isToday ?? false,
                        onChanged: (x) async {
                          final m = await runWithProgress(context, () => repo.setMezmurToday(_id!, x), success: l.saved);
                          if (m != null && mounted) setState(() => _apply(m));
                        },
                      ),
                    if (canEdit)
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.save),
                      ),
                    if (canEdit) const DraftHint(),
                    const SizedBox(height: 20),
                    SectionHeader(title: l.audio),
                    AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loaded?.audio != null)
                            _RecordingPreview(mezmur: _loaded!)
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(l.noRecordingYet, style: context.sans(12, color: context.palette.muted)),
                            ),
                          TextFormField(
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            validator: (s) => v.intRange(s, max: 86400, optional: true),
                            decoration: InputDecoration(labelText: l.audioDuration),
                          ),
                          if (_uploadProgress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: LinearProgressIndicator(value: _uploadProgress),
                            ),
                          Wrap(
                            spacing: 6,
                            children: [
                              TextButton.icon(
                                onPressed: !canEdit || _uploadProgress != null ? null : _uploadAudio,
                                icon: const Icon(Icons.upload_rounded),
                                label: Text(l.uploadAudio),
                              ),
                              if (_loaded?.audio != null && canEdit)
                                TextButton(
                                  onPressed: () async {
                                    await runWithProgress(context, () => repo.removeAudio(_id!));
                                    await _load(_id!);
                                  },
                                  child: Text(l.removeAudio, style: const TextStyle(color: AppColors.danger)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Time-synced lyrics (.lrc): type / paste, upload a .lrc file, or make them in the app.
                    SectionHeader(title: l.syncedLyrics),
                    AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(l.syncedLyricsHint, style: context.sans(12, color: context.palette.muted)),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('mezmur-lrc'),
                          controller: _lrc,
                          enabled: canEdit,
                          minLines: 3,
                          maxLines: 10,
                          style: context.sans(13).copyWith(fontFamily: 'monospace'),
                          validator: (s) => (s ?? '').trim().isEmpty || parseLrc(s).isNotEmpty ? null : l.lrcInvalid,
                          decoration: InputDecoration(
                            labelText: '.lrc',
                            hintText: '[00:12.50] …',
                            alignLabelWithHint: true,
                            errorText: serverFieldError(l, _error, 'lrc'),
                            helperText: _lrc.text.trim().isEmpty ? null : l.lrcLines('${parseLrc(_lrc.text).length}'),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        Wrap(spacing: 6, children: [
                          TextButton.icon(key: const ValueKey('lrc-upload'), onPressed: canEdit ? _pickLrc : null, icon: const Icon(Icons.upload_file_rounded), label: Text(l.lrcUpload)),
                          TextButton.icon(
                            key: const ValueKey('lrc-make'),
                            onPressed: canEdit && _loaded?.audio != null && _lyrics.text.trim().isNotEmpty ? _makeLrc : null,
                            icon: const Icon(Icons.timer_outlined),
                            label: Text(l.lrcMake),
                          ),
                          if (_lrc.text.isNotEmpty && canEdit)
                            TextButton(onPressed: () => setState(() => _lrc.clear()), child: Text(l.remove, style: const TextStyle(color: AppColors.danger))),
                        ]),
                        if (_loaded?.audio == null)
                          Text(l.lrcNeedsAudio, style: context.sans(11, color: context.palette.subtle)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    ImageUploadTile(
                      label: l.coverImage,
                      url: _loaded?.summary.coverUrl,
                      enabled: _id != null && canEdit,
                      onUpload: (p) async {
                        final m = await repo.uploadCover(_id!, p);
                        setState(() => _apply(m));
                      },
                      onRemove: () async {
                        await repo.removeCover(_id!);
                        await _load(_id!);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// =============================================================================
// Categories
// =============================================================================
class CategoriesAdminScreen extends ConsumerWidget {
  const CategoriesAdminScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {CategoryNode? existing, int? parentId}) async {
    await showCategoryEditor(context, existing: existing, parentId: parentId);
    // Refresh however the sheet was dismissed (swipe / tap outside return null).
    ref.invalidate(adminCategoryTreeProvider);
  }

  Future<void> _move(BuildContext context, WidgetRef ref, List<CategoryNode> siblings, int index, int delta) async {
    final j = index + delta;
    if (j < 0 || j >= siblings.length) return;
    final list = [...siblings];
    final item = list.removeAt(index);
    list.insert(j, item);
    await runWithProgress(context, () => ref.read(adminRepositoryProvider).reorderCategories([for (var i = 0; i < list.length; i++) (id: list[i].id, order: i)]));
    ref.invalidate(adminCategoryTreeProvider);
  }

  List<Widget> _nodes(BuildContext context, WidgetRef ref, List<CategoryNode> nodes) {
    final l = context.l10n;
    return [
      for (var i = 0; i < nodes.length; i++)
        Padding(
          padding: EdgeInsets.only(left: nodes[i].depth * 18.0),
          child: TrackTile(
            title: nodes[i].name,
            subtitle: [l.mezmurCount(nodes[i].mezmurCount), if (!nodes[i].isActive) l.inactive].join(' · '),
            leading: ListThumb(icon: nodes[i].depth == 0 ? Icons.folder_rounded : Icons.subdirectory_arrow_right_rounded, imageUrl: nodes[i].imageUrl, active: nodes[i].depth == 0),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await _edit(context, ref, existing: nodes[i]);
                  case 'sub':
                    await _edit(context, ref, parentId: nodes[i].id);
                  case 'up':
                    await _move(context, ref, nodes, i, -1);
                  case 'down':
                    await _move(context, ref, nodes, i, 1);
                  case 'delete':
                    if (await showConfirm(context, l.deleteConfirm, destructive: true) && context.mounted) {
                      await runWithProgress(context, () => ref.read(adminRepositoryProvider).deleteCategory(nodes[i].id), success: l.deleted);
                      ref.invalidate(adminCategoryTreeProvider);
                    }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.edit)),
                PopupMenuItem(value: 'sub', child: Text(l.addSubcategory)),
                if (i > 0) PopupMenuItem(value: 'up', child: Text(l.moveUp)),
                if (i < nodes.length - 1) PopupMenuItem(value: 'down', child: Text(l.moveDown)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.delete, style: const TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
            onTap: () => _edit(context, ref, existing: nodes[i]),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AdminScaffold(
      title: l.categories,
      fab: FloatingActionButton.extended(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add_rounded), label: Text(l.newCategory)),
      body: AsyncView(
        value: ref.watch(adminCategoryTreeProvider),
        onRetry: () => ref.invalidate(adminCategoryTreeProvider),
        data: (roots) => roots.isEmpty
            ? EmptyView(message: l.emptyCategories, icon: Icons.category_outlined)
            : ListView(padding: const EdgeInsets.fromLTRB(10, 8, 10, 96), children: _tree(context, ref, roots)),
      ),
    );
  }

  /// Depth-first rendering so children appear under their parent.
  List<Widget> _tree(BuildContext context, WidgetRef ref, List<CategoryNode> nodes) {
    final tiles = _nodes(context, ref, nodes);
    final out = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      out.add(tiles[i]);
      if (nodes[i].children.isNotEmpty) out.addAll(_tree(context, ref, nodes[i].children));
    }
    return out;
  }
}

/// Category editor sheet; returns the saved category (or null when closed without saving).
Future<CategoryNode?> showCategoryEditor(BuildContext context, {CategoryNode? existing, int? parentId, bool returnOnCreate = false}) async {
  final r = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _CategoryEditor(existing: existing, parentId: parentId, returnOnCreate: returnOnCreate),
    ),
  );
  return r is CategoryNode ? r : null;
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({this.existing, this.parentId, this.returnOnCreate = false});
  final CategoryNode? existing;
  final int? parentId;
  final bool returnOnCreate;
  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name);
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description);
  late final TextEditingController _order = TextEditingController(text: '${widget.existing?.displayOrder ?? 0}');
  late int? _parent = widget.existing?.parentId ?? widget.parentId;
  late bool _active = widget.existing?.isActive ?? true;
  CategoryNode? _saved;
  Object? _error;

  CategoryNode? get _node => _saved ?? widget.existing;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(adminRepositoryProvider);
    final body = {
      'name': _name.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'display_order': int.tryParse(_order.text) ?? 0,
      'is_active': _active,
      'parent_id': _parent,
    };
    try {
      final isNew = _node == null;
      final c = isNew ? await repo.createCategory(body) : await repo.updateCategory(_node!.id, body);
      ref.invalidate(adminCategoryTreeProvider);
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      // Edits close the sheet; "add new" from another editor gets the new category back;
      // otherwise a new category stays open so an image can be added.
      if (!isNew || widget.returnOnCreate) {
        Navigator.pop(context, c);
        return;
      }
      setState(() {
        _saved = c;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final repo = ref.read(adminRepositoryProvider);
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(_node == null ? l.newCategory : l.editCategory, style: context.serif(19)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              validator: (s) => v.text(s, max: 150),
              decoration: InputDecoration(labelText: l.title),
            ),
            const SizedBox(height: 12),
            CategoryDropdown(value: _parent, label: l.parentCategory, excludeId: _node?.id, onChanged: (x) => setState(() => _parent = x)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              validator: (s) => v.text(s, max: 1000, optional: true),
              decoration: InputDecoration(labelText: l.description),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              keyboardType: TextInputType.number,
              validator: (s) => v.intRange(s, max: 100000),
              decoration: InputDecoration(labelText: l.displayOrder),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.active), value: _active, onChanged: (x) => setState(() => _active = x)),
            if (_node != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.today_rounded, color: AppColors.gold),
                title: Text(l.markToday),
                value: _node!.isToday,
                onChanged: (x) async {
                  final c = await runWithProgress(context, () => repo.setCategoryToday(_node!.id, x), success: l.saved);
                  if (c != null && mounted) setState(() => _saved = c);
                },
              ),
            if (_error != null) Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: Text(l.save)),
            const SizedBox(height: 14),
            ImageUploadTile(
              label: l.categoryImage,
              url: _node?.imageUrl,
              enabled: _node != null,
              onUpload: (p) async {
                final c = await repo.uploadCategoryImage(_node!.id, p);
                setState(() => _saved = c);
              },
              onRemove: () async {
                await repo.removeCategoryImage(_node!.id);
                setState(() => _saved = CategoryNode.fromJson({..._node!.toJson(), 'image_url': null}));
              },
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.close)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Advertisements (banners) — internal links only
// =============================================================================
class AdsAdminScreen extends ConsumerStatefulWidget {
  const AdsAdminScreen({super.key});
  @override
  ConsumerState<AdsAdminScreen> createState() => _AdsAdminScreenState();
}

class _AdsAdminScreenState extends ConsumerState<AdsAdminScreen> {
  final _ctrl = PagedListController<Json>();

  Future<void> _edit([Json? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _AdEditor(existing: existing),
      ),
    );
    if (saved == true) await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.advertisements,
      fab: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: Text(l.newAd)),
      body: PagedListView<Json>(
        controller: _ctrl,
        fetch: (page) => ref.read(adminRepositoryProvider).ads(page: page),
        emptyMessage: l.noResults,
        emptyIcon: Icons.campaign_outlined,
        itemBuilder: (context, a, _) => TrackTile(
          title: '${a['title']}',
          subtitle: [
            asBool(a['is_active']) ? l.active : l.inactive,
            if (a['starts_at'] != null || a['ends_at'] != null) '${f.shortDate(asDate(a['starts_at']))} – ${f.shortDate(asDate(a['ends_at']))}',
          ].join(' · '),
          leading: ListThumb(icon: Icons.campaign_outlined, imageUrl: asStr(a['image_url'])),
          onTap: () => _edit(a),
        ),
      ),
    );
  }
}

class _AdEditor extends ConsumerStatefulWidget {
  const _AdEditor({this.existing});
  final Json? existing;
  @override
  ConsumerState<_AdEditor> createState() => _AdEditorState();
}

class _AdEditorState extends ConsumerState<_AdEditor> {
  final _form = GlobalKey<FormState>();
  late Json? _ad = widget.existing;
  late final _title = TextEditingController(text: asStr(_ad?['title']));
  late final _desc = TextEditingController(text: asStr(_ad?['short_description']));
  late final _order = TextEditingController(text: '${asIntOr(_ad?['display_order'])}');
  late String _kind = asStr(_ad?['kind']) ?? 'advertisement';
  late bool _active = _ad == null || asBool(_ad!['is_active']);
  late DateTime? _starts = asDate(_ad?['starts_at']);
  late DateTime? _ends = asDate(_ad?['ends_at']);
  late int? _pageId = asJson(_ad?['target'])['type'] == 'page' ? asInt(asJson(_ad?['target'])['id']) : null;
  late int? _programId = asJson(_ad?['target'])['type'] == 'program' ? asInt(asJson(_ad?['target'])['id']) : null;
  Object? _error;
  bool _submitting = false;

  Future<void> _save() async {
    if (_submitting) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = ref.read(adminRepositoryProvider);
    final body = {
      'kind': _kind,
      'title': _title.text.trim(),
      'short_description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'display_order': int.tryParse(_order.text) ?? 0,
      'is_active': _active,
      'starts_at': _starts?.toUtc().toIso8601String(),
      'ends_at': _ends?.toUtc().toIso8601String(),
      'page_id': _pageId,
      'program_id': _pageId == null ? _programId : null,
    };
    try {
      final a = _ad == null ? await repo.createAd(body) : await repo.updateAd(asIntOr(_ad!['id']), body);
      // Invalidate home hub banners cache so new banner shows immediately
      ref.invalidate(hubBannersProvider);
      if (mounted) {
        setState(() {
          _ad = a;
          _error = null;
          _submitting = false;
        });
        showSnack(context, context.l10n.saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final repo = ref.read(adminRepositoryProvider);
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(_ad == null ? l.newAd : l.editAd, style: context.serif(19)),
            const SizedBox(height: 4),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.adKind),
              items: [
                DropdownMenuItem(value: 'advertisement', child: Text(l.kindAdvertisement)),
                DropdownMenuItem(value: 'event', child: Text(l.kindEvent)),
                DropdownMenuItem(value: 'announcement', child: Text(l.kindAnnouncement)),
                DropdownMenuItem(value: 'campaign', child: Text(l.kindCampaign)),
                DropdownMenuItem(value: 'info', child: Text(l.kindInfo)),
              ],
              onChanged: (x) => setState(() => _kind = x!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              validator: (s) => v.text(s, max: 255),
              decoration: InputDecoration(labelText: l.title),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              validator: (s) => v.text(s, max: 500, optional: true),
              decoration: InputDecoration(labelText: l.shortDescription),
            ),
            const SizedBox(height: 12),
            DateTimeField(label: l.startsAt, value: _starts, clearable: true, onChanged: (d) => setState(() => _starts = d)),
            const SizedBox(height: 12),
            DateTimeField(
              label: l.endsAt,
              value: _ends,
              clearable: true,
              errorText: _starts != null && _ends != null && _ends!.isBefore(_starts!) ? l.vEndBeforeStart : null,
              onChanged: (d) => setState(() => _ends = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              keyboardType: TextInputType.number,
              validator: (s) => v.intRange(s, max: 100000),
              decoration: InputDecoration(labelText: l.displayOrder),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PagePickerField(key: ValueKey(_pageId), value: _pageId, onChanged: (x) => setState(() => _pageId = x)),
                ),
                IconButton(
                  tooltip: l.newPage,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
                  onPressed: () async {
                    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const PageEditorScreen(returnOnSave: true)));
                    if (id != null) setState(() => _pageId = id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.linkedProgram),
              subtitle: Text(_programId == null ? l.none : '#$_programId'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_programId != null) IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _programId = null)),
                  TextButton(
                    onPressed: () async {
                      final p = await pickProgram(context);
                      if (p != null) setState(() => _programId = p.id);
                    },
                    child: Text(l.select),
                  ),
                  IconButton(
                    tooltip: l.newProgram,
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
                    onPressed: () async {
                      final p = await createProgram(context);
                      if (p != null) setState(() => _programId = p.id);
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.active), value: _active, onChanged: (x) => setState(() => _active = x)),
            if (_error != null) Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_ad != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    onPressed: () async {
                      if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                      await runWithProgress(context, () => repo.deleteAd(asIntOr(_ad!['id'])), success: l.deleted);
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l.save),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ImageUploadTile(
              label: l.coverImage,
              url: asStr(_ad?['image_url']),
              enabled: _ad != null,
              onUpload: (p) async {
                final a = await repo.uploadAdImage(asIntOr(_ad!['id']), p);
                setState(() => _ad = a);
              },
            ),
            if (_ad != null) _AdAttachments(ad: _ad!, onChanged: (a) => setState(() => _ad = a)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.close)),
          ],
        ),
      ),
    );
  }
}

class _PagePickerField extends ConsumerWidget {
  const _PagePickerField({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return FutureBuilder(
      future: ref.read(adminRepositoryProvider).pages(page: 1),
      builder: (context, snap) {
        final pages = snap.data?.items ?? const <Json>[];
        return DropdownButtonFormField<int?>(
          initialValue: pages.any((p) => asInt(p['id']) == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.linkedPage),
          items: [
            DropdownMenuItem(value: null, child: Text(l.none)),
            for (final p in pages)
              DropdownMenuItem(
                value: asInt(p['id']),
                child: Text('${p['title']}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

// =============================================================================
// Internal pages
// =============================================================================
class PagesAdminScreen extends ConsumerStatefulWidget {
  const PagesAdminScreen({super.key});
  @override
  ConsumerState<PagesAdminScreen> createState() => _PagesAdminScreenState();
}

class _PagesAdminScreenState extends ConsumerState<PagesAdminScreen> {
  final _ctrl = PagedListController<Json>();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AdminScaffold(
      title: l.pages,
      fab: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/pages/edit/new').then((_) => _ctrl.refresh()),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newPage),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Expanded(
            child: PagedListView<Json>(
              key: ValueKey(_q),
              controller: _ctrl,
              fetch: (page) => ref.read(adminRepositoryProvider).pages(q: _q.isEmpty ? null : _q, page: page),
              emptyMessage: l.noResults,
              itemBuilder: (context, p, _) => TrackTile(
                title: '${p['title']}',
                subtitle: statusLabel(l, '${p['status']}'),
                leading: ListThumb(icon: Icons.article_outlined, imageUrl: asStr(p['cover_url'])),
                onTap: () => context.push('/admin/pages/edit/${p['id']}').then((_) => _ctrl.refresh()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({super.key, this.pageId, this.returnOnSave = false});
  final int? pageId;
  final bool returnOnSave;
  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _content = TextEditingController();
  final _location = TextEditingController();
  final _ctaLabel = TextEditingController();
  final _ctaTarget = TextEditingController();
  final _ctaUrl = TextEditingController();
  String? _ctaTargetTitle;
  DateTime? _eventDate;
  String _ctaAction = 'none';
  String _status = 'draft';
  int? _programId;
  PageContent? _page;
  bool _loading = false;
  Object? _error;
  late final DraftKeeper _draft = DraftKeeper(ref.read(localPrefsProvider), 'page:${widget.pageId ?? 'new'}');
  late final _repo = ref.read(adminRepositoryProvider);
  bool _restored = false;
  bool _submitted = false;

  Json _snapshot() => {
    'title': _title.text,
    'summary': _summary.text,
    'content': _content.text,
    'location': _location.text,
    'cta_label': _ctaLabel.text,
    'cta_target': _ctaTarget.text,
    'cta_target_title': _ctaTargetTitle,
    'cta_url': _ctaUrl.text,
    'event_date': _eventDate?.toIso8601String(),
    'cta_action': _ctaAction,
    'status': _status,
    'program_id': _programId,
  };

  void _restore(Json d) {
    _title.text = asStr(d['title']) ?? '';
    _summary.text = asStr(d['summary']) ?? '';
    _content.text = asStr(d['content']) ?? '';
    _location.text = asStr(d['location']) ?? '';
    _ctaLabel.text = asStr(d['cta_label']) ?? '';
    _ctaTarget.text = asStr(d['cta_target']) ?? '';
    _ctaTargetTitle = asStr(d['cta_target_title']);
    _ctaUrl.text = asStr(d['cta_url']) ?? '';
    _eventDate = asDate(d['event_date']);
    _ctaAction = asStr(d['cta_action']) ?? 'none';
    _status = asStr(d['status']) ?? 'draft';
    _programId = asInt(d['program_id']);
  }

  void _checkDraft() {
    _draft.setBaseline(_snapshot());
    final d = _draft.pending();
    if (d != null) {
      _restore(d);
      _restored = true;
    }
  }

  void _discardDraft() {
    if (_page != null) {
      _apply(_page!);
    } else {
      _restore(const {});
    }
    unawaited(_draft.clear(baseline: _snapshot()));
    setState(() => _restored = false);
  }

  void _leave() {
    _draft.flush();
    if (_submitted || _page != null || _title.text.trim().isEmpty || _content.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    unawaited(
      _repo
          .createPage({..._body(), 'status': 'draft'})
          .then((_) async {
            await ref.read(localPrefsProvider).removeDraft('page:new');
            messenger?.showSnackBar(SnackBar(content: Text(l.savedAsDraft)));
          })
          .catchError((Object _) {}),
    );
  }

  Json _body() => {
    'title': _title.text.trim(),
    'summary': _summary.text.trim().isEmpty ? null : _summary.text.trim(),
    'content': _content.text.trim(),
    'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
    'event_date': _eventDate?.toUtc().toIso8601String(),
    'cta_action': _ctaAction,
    'cta_label': _ctaLabel.text.trim().isEmpty ? null : _ctaLabel.text.trim(),
    'cta_target_id': ctaTargetType(_ctaAction) == null ? null : int.tryParse(_ctaTarget.text.trim()),
    'cta_url': _ctaAction == 'open_url' ? _ctaUrl.text.trim() : null,
    'program_id': _programId,
    'status': _status,
  };

  @override
  void initState() {
    super.initState();
    if (widget.pageId != null) {
      _load(widget.pageId!);
    } else {
      _checkDraft();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    try {
      _apply(await ref.read(adminRepositoryProvider).page(id));
      if (!_restored) _checkDraft();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(PageContent p) {
    _page = p;
    _title.text = p.title;
    _summary.text = p.summary ?? '';
    _content.text = p.content;
    _location.text = p.location ?? '';
    _ctaLabel.text = p.ctaLabel ?? '';
    _ctaTarget.text = p.ctaTargetId?.toString() ?? '';
    _ctaTargetTitle = p.ctaTargetTitle;
    _ctaUrl.text = p.ctaUrl ?? '';
    _eventDate = p.eventDate;
    _ctaAction = p.ctaAction ?? 'none';
    _status = p.status;
    _programId = p.programId;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showSnack(context, context.l10n.checkFields);
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    final body = _body();
    try {
      final p = _page == null ? await repo.createPage(body) : await repo.updatePage(_page!.id, body);
      setState(() {
        _apply(p);
        _error = null;
        _restored = false;
      });
      _submitted = true;
      await _draft.rekey('page:${p.id}');
      await _draft.clear(baseline: _snapshot());
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      if (widget.returnOnSave) Navigator.of(context).pop(p.id);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final repo = ref.read(adminRepositoryProvider);
    if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _draft.changed(_snapshot()));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: AdminScaffold(
        title: _page == null ? l.newPage : l.editPage,
        actions: [
          if (_page != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                await runWithProgress(context, () => repo.deletePage(_page!.id), success: l.deleted);
                if (context.mounted) context.pop();
              },
            ),
        ],
        body: _loading
            ? const LoadingView()
            : Form(
                key: _form,
                onChanged: () => _draft.changed(_snapshot()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_restored) DraftRestoredBanner(onDiscard: _discardDraft),
                    TextFormField(
                      controller: _title,
                      validator: (s) => v.text(s, max: 255),
                      decoration: InputDecoration(labelText: l.title),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _summary,
                      validator: (s) => v.text(s, max: 500, optional: true),
                      decoration: InputDecoration(labelText: l.summary),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _content,
                      minLines: 6,
                      maxLines: 20,
                      validator: (s) => v.text(s, max: 100000),
                      decoration: InputDecoration(labelText: l.content, alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 12),
                    DateTimeField(label: l.eventDate, value: _eventDate, clearable: true, onChanged: (d) => setState(() => _eventDate = d)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      validator: (s) => v.text(s, max: 255, optional: true),
                      decoration: InputDecoration(labelText: l.location),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.linkedProgram),
                      subtitle: Text(_programId == null ? l.none : (_page?.programTitle ?? '#$_programId')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_programId != null) IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _programId = null)),
                          TextButton(
                            onPressed: () async {
                              final p = await pickProgram(context);
                              if (p != null) setState(() => _programId = p.id);
                            },
                            child: Text(l.select),
                          ),
                        ],
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _ctaAction,
                      decoration: InputDecoration(labelText: l.ctaAction),
                      items: [
                        DropdownMenuItem(value: 'none', child: Text(l.ctaNone)),
                        DropdownMenuItem(value: 'open_program', child: Text(l.ctaOpenProgram)),
                        DropdownMenuItem(value: 'register_program', child: Text(l.ctaRegisterProgram)),
                        DropdownMenuItem(value: 'open_mezmur', child: Text(l.ctaOpenMezmur)),
                        DropdownMenuItem(value: 'open_category', child: Text(l.ctaOpenCategory)),
                        DropdownMenuItem(value: 'open_class', child: Text(l.ctaOpenClass)),
                        DropdownMenuItem(value: 'open_course', child: Text(l.ctaOpenCourse)),
                        DropdownMenuItem(value: 'open_assignment', child: Text(l.ctaOpenAssignment)),
                        DropdownMenuItem(value: 'open_page', child: Text(l.ctaOpenPage)),
                        DropdownMenuItem(value: 'open_library', child: Text(l.ctaOpenLibrary)),
                        DropdownMenuItem(value: 'open_url', child: Text(l.ctaOpenUrl)),
                      ],
                      onChanged: (x) => setState(() {
                        if (ctaTargetType(x) != ctaTargetType(_ctaAction)) {
                          _ctaTarget.clear();
                          _ctaTargetTitle = null;
                        }
                        _ctaAction = x!;
                      }),
                    ),
                    if (_ctaAction != 'none') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ctaLabel,
                        validator: (s) => v.text(s, max: 80, optional: true),
                        decoration: InputDecoration(labelText: l.ctaLabel),
                      ),
                      // What the button opens: picked from a searchable list (or a web link).
                      if (ctaTargetType(_ctaAction) != null) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          key: const ValueKey('cta-target'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link_rounded),
                          title: Text(_ctaTargetTitle ?? (_ctaTarget.text.isEmpty ? l.ctaNothingChosen : '#${_ctaTarget.text}')),
                          subtitle: Text(l.ctaTarget),
                          trailing: TextButton(
                            onPressed: () async {
                              final t = await pickPageLinkTarget(context, ctaTargetType(_ctaAction)!);
                              if (t != null) {
                                setState(() {
                                  _ctaTarget.text = '${t['id']}';
                                  _ctaTargetTitle = asStr(t['title']);
                                });
                              }
                            },
                            child: Text(l.select),
                          ),
                        ),
                      ],
                      if (_ctaAction == 'open_url') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('cta-url'),
                          controller: _ctaUrl,
                          keyboardType: TextInputType.url,
                          validator: (s) => RegExp(r'^https://\S+$').hasMatch((s ?? '').trim()) ? null : l.errInvalidUrl,
                          decoration: InputDecoration(labelText: l.ctaUrl),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: l.status),
                      items: [
                        for (final s in ['draft', 'published']) DropdownMenuItem(value: s, child: Text(statusLabel(l, s))),
                      ],
                      onChanged: (x) => setState(() => _status = x!),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _save, child: Text(l.save)),
                    const DraftHint(),
                    const SizedBox(height: 20),
                    ImageUploadTile(
                      label: l.coverImage,
                      url: _page?.coverUrl,
                      enabled: _page != null,
                      onUpload: (p) async {
                        final pg = await repo.uploadPageCover(_page!.id, p);
                        setState(() => _apply(pg));
                      },
                    ),
                    if (_page != null) ...[
                      SectionHeader(title: l.gallery),
                      for (final img in _page!.images)
                        TrackTile(
                          title: img.caption ?? '#${img.id}',
                          leading: ListThumb(icon: Icons.image_outlined, imageUrl: img.url),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () async {
                              await runWithProgress(context, () => repo.removePageImage(_page!.id, img.id));
                              await _load(_page!.id);
                            },
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path = await pickImagePath();
                          if (path == null || !context.mounted) return;
                          final pg = await runWithProgress(context, () => repo.addPageImage(_page!.id, path), success: l.uploadDone);
                          if (pg != null) setState(() => _apply(pg));
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(l.addImage),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// The recording attached to a Mezmur, with a play/pause preview through the app player.
class _RecordingPreview extends ConsumerWidget {
  const _RecordingPreview({required this.mezmur});
  final Mezmur mezmur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final player = ref.watch(audioProvider);
    final isCurrent = player.current?.id == mezmur.id;
    final a = mezmur.audio!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: isCurrent && player.playing ? l.pause : l.play,
            style: IconButton.styleFrom(backgroundColor: AppColors.maroon),
            icon: Icon(isCurrent && player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () {
              if (isCurrent) {
                ref.read(audioProvider.notifier).toggle();
              } else {
                final t = PlayerTrack.fromMezmur(mezmur);
                if (t != null) ref.read(audioProvider.notifier).playSingle(t);
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.currentRecording, style: context.sans(13, weight: FontWeight.w600)),
                Text(
                  [a.mime ?? '', Formatters.fileSize(a.size ?? 0), Formatters.durationSec(a.durationSec)].where((x) => x.isNotEmpty).join(' · '),
                  style: context.sans(12, color: context.palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner files (PDF / images) and web links about the event.
class _AdAttachments extends ConsumerWidget {
  const _AdAttachments({required this.ad, required this.onChanged});
  final Json ad;
  final ValueChanged<Json> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    final id = asIntOr(ad['id']);
    final items = asList(ad['attachments'], BannerAttachment.fromJson);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.attachments),
        for (final a in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.kind == 'link' ? Icons.link_rounded : (a.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded), color: AppColors.gold),
            title: Text(a.title ?? a.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: a.title == null ? null : Text(a.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () async {
                final r = await runWithProgress(context, () => repo.removeAdAttachment(id, a.id));
                if (r != null) onChanged(r);
              },
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(l.addFile),
              onPressed: () async {
                final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif']);
                final path = files.isEmpty ? null : files.first.path;
                if (path == null || !context.mounted) return;
                final title = await promptText(context, title: l.addFile, label: l.title);
                if (title == null || !context.mounted) return;
                final r = await runWithProgress(context, () => repo.addAdFile(id, path, title: title.trim().isEmpty ? null : title.trim()), success: l.saved);
                if (r != null) onChanged(r);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l.addLink),
              onPressed: () async {
                final url = await promptText(context, title: l.addLink, label: l.linkUrl, initial: 'https://');
                if (url == null || !context.mounted) return;
                if (!RegExp(r'^https?://[^\s]+\.[^\s]+').hasMatch(url.trim())) {
                  showSnack(context, l.vInvalidUrl);
                  return;
                }
                final title = await promptText(context, title: l.addLink, label: l.title);
                if (title == null || !context.mounted) return;
                final r = await runWithProgress(
                  context,
                  () => repo.addAdLink(id, url: url.trim(), title: title.trim().isEmpty ? null : title.trim()),
                  success: l.saved,
                );
                if (r != null) onChanged(r);
              },
            ),
          ],
        ),
      ],
    );
  }
}


/// The kind of thing an internal page button opens (null = no target: library, web link, none).
String? ctaTargetType(String? action) => switch (action) {
      'open_program' || 'register_program' => 'program',
      'open_mezmur' => 'mezmur',
      'open_category' => 'category',
      'open_class' => 'class',
      'open_course' => 'course',
      'open_assignment' => 'assignment',
      'open_page' => 'page',
      _ => null,
    };

/// Searchable picker of what a page button can open ({id, title, subtitle}).
Future<Json?> pickPageLinkTarget(BuildContext context, String type) => showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LinkTargetSheet(type: type),
    );

class _LinkTargetSheet extends ConsumerStatefulWidget {
  const _LinkTargetSheet({required this.type});
  final String type;
  @override
  ConsumerState<_LinkTargetSheet> createState() => _LinkTargetSheetState();
}

class _LinkTargetSheetState extends ConsumerState<_LinkTargetSheet> {
  List<Json> _rows = const [];
  bool _loading = true;
  Object? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final rows = await ref.read(stageRepositoryProvider).pageLinkTargets(widget.type, q: q.trim().isEmpty ? null : q.trim());
      if (mounted && seq == _seq) {
        setState(() {
          _rows = rows;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(autofocus: true, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.search), onChanged: _search),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(errorText(l, _error!))),
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final r = _rows[i];
                return ListTile(
                  title: Text(asStr(r['title']) ?? '#${r['id']}'),
                  subtitle: asStr(r['subtitle']) == null ? null : Text(asStr(r['subtitle'])!),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
