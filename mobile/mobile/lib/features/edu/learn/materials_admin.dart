import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../services/file_opening_service.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../../widgets/typed_picker.dart';
import '../../auth/session.dart' show currentUserProvider;

/// Dedicated Learning Materials management screen for Education Admin Panel.
/// Allows viewing, searching, uploading, and managing PDF guides, multimedia links,
/// audio recordings, and documents across all lessons.
class EduMaterialsAdminScreen extends ConsumerStatefulWidget {
  const EduMaterialsAdminScreen({super.key, this.initialSubjectId});
  final int? initialSubjectId;

  @override
  ConsumerState<EduMaterialsAdminScreen> createState() => _EduMaterialsAdminScreenState();
}

class _EduMaterialsAdminScreenState extends ConsumerState<EduMaterialsAdminScreen> {
  int? _selectedSubjectId;
  String _selectedKind = 'all'; // 'all', 'file', 'audio', 'video', 'link'
  String _searchQuery = '';
  bool _loading = false;
  List<Json> _allMaterials = [];
  List<Json> _subjects = [];

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final repo = ref.read(eduRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.subjects(all: true),
        repo.allMaterials(),
      ]);
      _subjects = results[0];
      final materials = results[1];

      if (mounted) {
        setState(() {
          _allMaterials = materials;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteMaterial(Json m) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final title = asStr(m['title']) ?? asStr(m['name']) ?? '';
    final confirmed = await showConfirm(
      context,
      isEn ? 'Delete material "$title"?' : 'ማጣቀሻ "$title" ይሰረዝ?',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteMaterial(asIntOr(m['id'])));
    _loadAll();
  }

  Future<void> _openMaterial(Json m) async {
    final kind = asStr(m['kind']);
    final url = asStr(m['url']);
    final fileUrl = asStr(m['file_url']);
    final id = asInt(m['id']);
    final originalName = asStr(m['name']) ?? asStr(m['original_name']);
    final rawTitle = asStr(m['title']) ?? asStr(m['title_en']) ?? originalName ?? 'material';
    final String filename;
    if (originalName != null && originalName.contains('.')) {
      final ext = originalName.split('.').last;
      filename = rawTitle.toLowerCase().endsWith('.$ext') ? rawTitle : '$rawTitle.$ext';
    } else {
      filename = rawTitle;
    }
    final mime = asStr(m['mime']);

    if (kind == 'link' || (url != null && (url.startsWith('http://') || url.startsWith('https://')) && kind != 'file')) {
      final uri = Uri.tryParse(url ?? '');
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final source = id != null ? '/edu/materials/$id/file' : (fileUrl ?? url ?? '');
    if (source.isNotEmpty && mounted) {
      await ref.read(fileOpeningServiceProvider).openFile(
        context,
        source: source,
        filename: filename,
        mime: mime,
      );
    }
  }

  Future<void> _addMaterialDialog() async {
    final l = context.l10n;
    final isEn = l.isEn;

    if (_subjects.isEmpty) return;

    int selectedSubId = _selectedSubjectId ?? asIntOr(_subjects.first['id']);
    List<Json> availableLessons = [];

    // Load lessons for chosen subject
    final repo = ref.read(eduRepositoryProvider);
    final detail = await repo.subject(selectedSubId);
    final units = asJsonList(detail['units']);
    availableLessons = [...asJsonList(detail['lessons'])];
    for (final u in units) {
      availableLessons.addAll(asJsonList(u['lessons']));
    }

    if (!mounted) return;

    int? selectedLessonId = availableLessons.isNotEmpty ? asIntOr(availableLessons.first['id']) : null;
    String targetMode = 'direct'; // 'direct' (Feature B) or 'lesson'
    int selectedGrade = 1;
    String uploadType = 'file'; // 'file' or 'link'
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? pickedFilePath;
    String? pickedFileName;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final p = ctx.palette;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file_rounded, color: AppColors.maroon, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEn ? 'Add Learning Material' : 'አዲስ የትምህርት ግብዓት አክል',
                        style: ctx.serif(17, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Target mode toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(isEn ? 'Direct to Grade' : 'ቀጥታ ለክፍል ደረጃ')),
                          selected: targetMode == 'direct',
                          selectedColor: AppColors.maroon,
                          labelStyle: TextStyle(color: targetMode == 'direct' ? Colors.white : p.text, fontWeight: FontWeight.w600, fontSize: 12),
                          onSelected: (_) => setModalState(() => targetMode = 'direct'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(isEn ? 'Attach to Lesson' : 'ከትምህርት ጋር አያይዝ')),
                          selected: targetMode == 'lesson',
                          selectedColor: AppColors.maroon,
                          labelStyle: TextStyle(color: targetMode == 'lesson' ? Colors.white : p.text, fontWeight: FontWeight.w600, fontSize: 12),
                          onSelected: availableLessons.isEmpty ? null : (_) => setModalState(() => targetMode = 'lesson'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Subject dropdown
                  DropdownButtonFormField<int>(
                    initialValue: selectedSubId,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Subject' : 'የትምህርት ዓይነት',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      for (final s in _subjects)
                        DropdownMenuItem<int>(
                          value: asIntOr(s['id']),
                          child: Text(
                            asStr(s['category_name']) != null
                                ? '${s['category_name']} · ${asStr(s['name']) ?? asStr(s['title']) ?? ''}'
                                : (asStr(s['name']) ?? asStr(s['title']) ?? ''),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setModalState(() => selectedSubId = v);
                      final d = await repo.subject(v);
                      final uList = asJsonList(d['units']);
                      final lList = [...asJsonList(d['lessons'])];
                      for (final u in uList) {
                        lList.addAll(asJsonList(u['lessons']));
                      }
                      setModalState(() {
                        availableLessons = lList;
                        if (lList.isNotEmpty) {
                          selectedLessonId = asIntOr(lList.first['id']);
                        } else {
                          selectedLessonId = null;
                          targetMode = 'direct';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  if (targetMode == 'direct') ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedGrade,
                      decoration: InputDecoration(
                        labelText: isEn ? 'Grade Level (1–12)' : 'የክፍል ደረጃ (1–12)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        for (int g = 1; g <= 12; g++)
                          DropdownMenuItem<int>(
                            value: g,
                            child: Text(isEn ? 'Grade $g' : '$gኛ ክፍል'),
                          ),
                      ],
                      onChanged: (g) {
                        if (g != null) setModalState(() => selectedGrade = g);
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Lesson dropdown
                    DropdownButtonFormField<int>(
                      initialValue: availableLessons.any((l) => asInt(l['id']) == selectedLessonId)
                          ? selectedLessonId
                          : (availableLessons.isNotEmpty ? asIntOr(availableLessons.first['id']) : null),
                      decoration: InputDecoration(
                        labelText: isEn ? 'Lesson' : 'ትምህርት',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        for (final lsn in availableLessons)
                          DropdownMenuItem<int>(
                            value: asIntOr(lsn['id']),
                            child: Text(asStr(lsn['title']) ?? '', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedLessonId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Segmented toggle: File vs Link
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(isEn ? 'Document / PDF' : 'ሰነድ / ፒዲኤፍ')),
                          selected: uploadType == 'file',
                          selectedColor: AppColors.maroon,
                          labelStyle: TextStyle(color: uploadType == 'file' ? Colors.white : p.text, fontWeight: FontWeight.w600),
                          onSelected: (_) => setModalState(() => uploadType = 'file'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(isEn ? 'Web / Video Link' : 'የቪዲዮ / ድረ-ገጽ ማስፈንጠሪያ')),
                          selected: uploadType == 'link',
                          selectedColor: AppColors.maroon,
                          labelStyle: TextStyle(color: uploadType == 'link' ? Colors.white : p.text, fontWeight: FontWeight.w600),
                          onSelected: (_) => setModalState(() => uploadType = 'link'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: '${isEn ? "Material Title" : "የግብዓቱ ርእስ"} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (uploadType == 'file') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        pickedFileName != null
                            ? '$pickedFileName'
                            : (isEn ? 'Choose PDF or Document' : 'ፒዲኤፍ ወይም ሰነድ ይምረጡ'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final file = await pickOfKind('document');
                        if (file != null) {
                          setModalState(() {
                            pickedFilePath = file.path;
                            pickedFileName = file.name;
                            if (titleCtrl.text.isEmpty) titleCtrl.text = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                          });
                        }
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: '${isEn ? "URL / Link" : "የድረ-ገጽ አድራሻ (URL)"} *',
                        hintText: 'https://...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        showSnack(ctx, isEn ? 'Please enter a title' : 'እባክዎ ርእስ ያስገቡ');
                        return;
                      }

                      if (targetMode == 'direct') {
                        if (uploadType == 'file') {
                          if (pickedFilePath == null) {
                            showSnack(ctx, isEn ? 'Please select a file' : 'እባክዎ ፋይል ይምረጡ');
                            return;
                          }
                          Navigator.pop(ctx);
                          await runWithProgress(context, () => repo.addDirectMaterialFile(selectedSubId, selectedGrade, pickedFilePath!, title: title));
                        } else {
                          final url = urlCtrl.text.trim();
                          if (url.isEmpty || !url.startsWith('http')) {
                            showSnack(ctx, isEn ? 'Please enter a valid URL' : 'እባክዎ ትክክለኛ የድረ-ገጽ አድራሻ ያስገቡ');
                            return;
                          }
                          Navigator.pop(ctx);
                          final kind = url.contains('youtube') || url.contains('youtu.be') ? 'video' : 'link';
                          await runWithProgress(context, () => repo.addDirectMaterialLink(selectedSubId, selectedGrade, kind: kind, title: title, url: url));
                        }
                      } else {
                        if (selectedLessonId == null) {
                          showSnack(ctx, isEn ? 'Please select a lesson' : 'እባክዎ ትምህርት ይምረጡ');
                          return;
                        }
                        if (uploadType == 'file') {
                          if (pickedFilePath == null) {
                            showSnack(ctx, isEn ? 'Please select a file' : 'እባክዎ ፋይል ይምረጡ');
                            return;
                          }
                          Navigator.pop(ctx);
                          await runWithProgress(context, () => repo.uploadMaterial(selectedLessonId!, pickedFilePath!, title: title));
                        } else {
                          final url = urlCtrl.text.trim();
                          if (url.isEmpty || !url.startsWith('http')) {
                            showSnack(ctx, isEn ? 'Please enter a valid URL' : 'እባክዎ ትክክለኛ የድረ-ገጽ አድራሻ ያስገቡ');
                            return;
                          }
                          Navigator.pop(ctx);
                          final kind = url.contains('youtube') || url.contains('youtu.be') ? 'video' : 'link';
                          await runWithProgress(context, () => repo.addLink(selectedLessonId!, kind: kind, title: title, url: url));
                        }
                      }
                      _loadAll();
                    },
                    child: Text(isEn ? 'Save Material' : 'ግብዓቱን መዝግብ'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;
    final user = ref.watch(currentUserProvider);
    final canEdit = user?.canAny([Perm.educationContent, Perm.educationManage]) ?? false;

    // Filter materials
    final filtered = _allMaterials.where((m) {
      if (_selectedSubjectId != null && m['subject_id'] != _selectedSubjectId) {
        return false;
      }

      if (_selectedKind != 'all') {
        final kind = asStr(m['kind']) ?? 'file';
        if (_selectedKind == 'file' && kind != 'file') return false;
        if (_selectedKind == 'video' && kind != 'video') return false;
        if (_selectedKind == 'audio' && kind != 'audio') return false;
        if (_selectedKind == 'link' && kind != 'link' && kind != 'video') return false;
      }

      if (_searchQuery.isNotEmpty) {
        final title = (asStr(m['title']) ?? asStr(m['name']) ?? '').toLowerCase();
        final lTitle = (asStr(m['lesson_title']) ?? '').toLowerCase();
        final sTitle = (asStr(m['subject_name']) ?? '').toLowerCase();
        if (!title.contains(_searchQuery) && !lTitle.contains(_searchQuery) && !sTitle.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Learning Materials' : 'የትምህርት ግብዓቶችና ሰነዶች'),
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'add-material',
              backgroundColor: AppColors.maroon,
              foregroundColor: AppColors.goldLight,
              icon: const Icon(Icons.add_rounded),
              label: Text(isEn ? 'Add Material' : 'ግብዓት አክል'),
              onPressed: _addMaterialDialog,
            )
          : null,
      body: Column(
        children: [
          // 1. Top Filters Bar
          Container(
            color: p.card,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                // Subject filter row
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded, size: 18, color: AppColors.goldDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedSubjectId,
                          isExpanded: true,
                          hint: Text(isEn ? 'All Subjects / Curricula' : 'ሁሉም የትምህርት ዓይነቶች', style: context.sans(13)),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(isEn ? 'All Subjects / Curricula' : 'ሁሉም የትምህርት ዓይነቶች', style: context.sans(13)),
                            ),
                            for (final s in _subjects)
                              DropdownMenuItem<int?>(
                                value: asInt(s['id']),
                                child: Text(
                                  asStr(s['category_name']) != null
                                      ? '${s['category_name']} · ${asStr(s['name']) ?? asStr(s['title']) ?? ''}'
                                      : (asStr(s['name']) ?? asStr(s['title']) ?? ''),
                                  style: context.sans(13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _selectedSubjectId = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Kind chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _kindChip('all', isEn ? 'All' : 'ሁሉም', Icons.apps_rounded),
                      const SizedBox(width: 6),
                      _kindChip('file', isEn ? 'PDF / Documents' : 'ፒዲኤፍ / ሰነዶች', Icons.picture_as_pdf_rounded),
                      const SizedBox(width: 6),
                      _kindChip('video', isEn ? 'Videos' : 'ቪዲዮዎች', Icons.ondemand_video_rounded),
                      const SizedBox(width: 6),
                      _kindChip('audio', isEn ? 'Audio' : 'የድምጽ ፋይሎች', Icons.audiotrack_rounded),
                      const SizedBox(width: 6),
                      _kindChip('link', isEn ? 'Web Links' : 'ድረ-ገጾች', Icons.link_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: isEn ? 'Search materials, lessons, or subjects...' : 'ግብዓት፣ ትምህርት ወይም የትምህርት ዓይነት ፈልግ...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
            ),
          ),

          // 3. Materials List
          Expanded(
            child: _loading
                ? const LoadingView()
                : filtered.isEmpty
                    ? Center(
                        child: EmptyView(
                          icon: Icons.attach_file_rounded,
                          message: _allMaterials.isEmpty
                              ? (isEn ? 'No learning materials uploaded yet.' : 'ምንም የትምህርት ግብዓቶች አልተጫኑም።')
                              : (isEn ? 'No materials match the filter.' : 'ምንም የሚስማማ ግብዓት አልተገኘም።'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final m = filtered[i];
                            return _MaterialCard(
                              material: m,
                              canEdit: canEdit,
                              onOpen: () => _openMaterial(m),
                              onDelete: () => _deleteMaterial(m),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(String kind, String label, IconData icon) {
    final isSelected = _selectedKind == kind;
    return ChoiceChip(
      avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : AppColors.goldDark),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.maroon,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      onSelected: (_) => setState(() => _selectedKind = kind),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.canEdit,
    required this.onOpen,
    required this.onDelete,
  });

  final Json material;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final isEn = l.isEn;
    final title = asStr(material['title']) ?? asStr(material['name']) ?? '';
    final kind = asStr(material['kind']) ?? 'file';
    final lessonTitle = asStr(material['lesson_title']) ?? '';
    final subjectName = asStr(material['subject_name']) ?? '';
    final fileSize = asInt(material['file_size']);
    final url = asStr(material['url']);

    IconData icon;
    Color iconColor;
    if (kind == 'file') {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = AppColors.danger;
    } else if (kind == 'video' || (url != null && (url.contains('youtu.be') || url.contains('youtube')))) {
      icon = Icons.ondemand_video_rounded;
      iconColor = const Color(0xFF1976D2);
    } else if (kind == 'audio') {
      icon = Icons.audiotrack_rounded;
      iconColor = const Color(0xFF7B1FA2);
    } else {
      icon = Icons.link_rounded;
      iconColor = const Color(0xFF00796B);
    }

    String sizeLabel = '';
    if (fileSize != null && fileSize > 0) {
      if (fileSize > 1024 * 1024) {
        sizeLabel = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeLabel = '${(fileSize / 1024).toStringAsFixed(0)} KB';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.sans(14, weight: FontWeight.w600, color: p.text),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (subjectName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.maroon.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subjectName,
                              style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600),
                            ),
                          ),
                        if (lessonTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              lessonTitle,
                              style: context.sans(11, color: p.muted),
                            ),
                          ),
                        if (sizeLabel.isNotEmpty)
                          Text(
                            sizeLabel,
                            style: context.sans(11, color: p.faint),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isEn ? 'Open' : 'ክፈት',
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                onPressed: onOpen,
              ),
              if (canEdit)
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
