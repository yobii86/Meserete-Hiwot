import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/file_upload_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../../widgets/typed_picker.dart';
import '../../auth/session.dart' show currentUserProvider;
import 'magazine_screens.dart';

String _resolveMediaUrl(String? url, String baseUrl) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final baseUri = Uri.parse(baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
  final path = url.startsWith('/') ? url : '/$url';
  return '$origin$path';
}

/// Admin Management screen for ሰሌዳ መጽሔት (Seleda Magazine).
/// Allows Education Administrators to view all issues (draft, published, scheduled, archived),
/// create new issues, edit issue metadata & files, toggle publication, preview,
/// and configure 1-week availability / 1-attempt quizzes.
class EduMagazinesAdminScreen extends ConsumerStatefulWidget {
  const EduMagazinesAdminScreen({super.key});

  @override
  ConsumerState<EduMagazinesAdminScreen> createState() => _EduMagazinesAdminScreenState();
}

class _EduMagazinesAdminScreenState extends ConsumerState<EduMagazinesAdminScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all'; // 'all', 'published', 'draft', 'scheduled', 'archived'
  bool _loading = false;
  Object? _error;
  List<Json> _magazines = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMagazines();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMagazines() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(eduRepositoryProvider);
      final statusParam = _selectedStatus == 'all' ? null : _selectedStatus;
      final items = await repo.magazines(status: statusParam);
      if (mounted) {
        setState(() {
          _magazines = items;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  List<Json> get _filteredMagazines {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _magazines;
    return _magazines.where((m) {
      final title = (asStr(m['title']) ?? '').toLowerCase();
      final titleEn = (asStr(m['title_en']) ?? '').toLowerCase();
      final issueNum = (asStr(m['issue_number']) ?? '').toLowerCase();
      final period = (asStr(m['period_info']) ?? '').toLowerCase();
      return title.contains(q) || titleEn.contains(q) || issueNum.contains(q) || period.contains(q);
    }).toList();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'published':
        return const Color(0xFF2E7D32);
      case 'scheduled':
        return const Color(0xFF1976D2);
      case 'draft':
        return const Color(0xFFE65100);
      case 'archived':
      default:
        return const Color(0xFF757575);
    }
  }

  String _statusLabel(BuildContext context, String? status) {
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    switch (status) {
      case 'published':
        return isEn ? 'Published' : 'የታተመ';
      case 'scheduled':
        return isEn ? 'Scheduled' : 'የታቀደ';
      case 'draft':
        return isEn ? 'Draft' : 'ረቂቅ';
      case 'archived':
        return isEn ? 'Archived' : 'ማህደር';
      default:
        return status ?? '';
    }
  }

  Future<void> _openEditor([Json? issue]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EduMagazineEditorSheet(issue: issue),
    );
    if (result == true) {
      _loadMagazines();
      ref.invalidate(latestMagazineProvider);
      ref.invalidate(magazinesListProvider);
    }
  }

  Future<void> _togglePublish(Json issue) async {
    final currentStatus = asStr(issue['status']);
    final isPublished = currentStatus == 'published';
    final nextStatus = isPublished ? 'draft' : 'published';
    final id = asIntOr(issue['id']);
    final title = asStr(issue['title']) ?? '';
    final l = context.l10n;

    final confirm = await showConfirm(
      context,
      title: isPublished ? (l.isEn ? 'Unpublish Issue' : 'እትሙን ከህትመት አንሳ') : (l.isEn ? 'Publish Issue' : 'እትሙን አትም'),
       isPublished
          ? (l.isEn ? 'Unpublishing "$title" will hide it from students.' : '«$title» ከህትመት ሲነሳ ከተማሪዎች ይሰወራል። እርግጠኛ ነዎት?')
          : (l.isEn ? 'Publishing "$title" will make it available to all students.' : '«$title» ሲታተም ለሁሉም ተማሪዎች ወዲያውኑ ይታያል። እርግጠኛ ነዎት?'),
      confirmLabel: isPublished ? (l.isEn ? 'Unpublish' : 'አንሳ') : (l.isEn ? 'Publish' : 'አትም'),
    );
    if (confirm != true) return;

    try {
      await ref.read(eduRepositoryProvider).updateMagazine(id, {'status': nextStatus});
      if (mounted) {
        showSnack(
          context,
          isPublished
              ? (l.isEn ? 'Issue moved to draft' : 'እትሙ ወደ ረቂቅ ተቀይሯል')
              : (l.isEn ? 'Issue published successfully' : 'እትሙ በተሳካ ሁኔታ ታትሟል'),
        );
      }
      _loadMagazines();
      ref.invalidate(latestMagazineProvider);
      ref.invalidate(magazinesListProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _deleteIssue(Json issue) async {
    final id = asIntOr(issue['id']);
    final title = asStr(issue['title']) ?? '';
    final l = context.l10n;

    final confirm = await showConfirm(
      context,
      title: l.isEn ? 'Delete Magazine Issue' : 'የመጽሔት እትሙን ሰርዝ',
       l.isEn ? 'Are you sure you want to permanently delete "$title"?' : '«$title» የተሰኘውን እትም ሙሉ በሙሉ ለመሰረዝ እርግጠኛ ነዎት?',
      confirmLabel: l.isEn ? 'Delete' : 'ሰርዝ',
      destructive: true,
    );
    if (confirm != true) return;

    try {
      await ref.read(eduRepositoryProvider).deleteMagazine(id);
      if (mounted) showSnack(context, l.isEn ? 'Magazine issue deleted' : 'የመጽሔት እትሙ ተሰርዟል');
      _loadMagazines();
      ref.invalidate(latestMagazineProvider);
      ref.invalidate(magazinesListProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _openQuizDialog(Json issue) async {
    final id = asIntOr(issue['id']);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EduMagazineQuizEditorDialog(magazineId: id, magazineTitle: asStr(issue['title']) ?? ''),
    );
    if (result == true) {
      _loadMagazines();
      ref.invalidate(latestMagazineProvider);
      ref.invalidate(magazinesListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final canManage = user?.can(Perm.educationManage) == true ||
        user?.can(Perm.educationContent) == true ||
        user?.isAdmin == true;

    if (!canManage) {
      return PatternScaffold(
        appBar: AppBar(title: Text(isEn ? 'Seleda Magazine' : 'ሰሌዳ መጽሔት')),
        body: Center(
          child: Text(isEn ? 'Admin permission required' : 'የአስተዳዳሪ ፈቃድ ያስፈልጋል።'),
        ),
      );
    }

    final items = _filteredMagazines;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Seleda Magazine Admin' : 'የሰሌዳ መጽሔት አስተዳደር'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isEn ? 'Refresh' : 'አድስ',
            onPressed: _loadMagazines,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF650D20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isEn ? 'New Issue' : 'አዲስ እትም'),
        onPressed: () => _openEditor(),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: p.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search by title, volume or date...' : 'በርዕስ፣ በቅጽ ወይም በዘመን ፈልግ...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    filled: true,
                    fillColor: p.fill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusChip('all', isEn ? 'All' : 'ሁሉም'),
                      const SizedBox(width: 6),
                      _statusChip('published', isEn ? 'Published' : 'የታተሙ'),
                      const SizedBox(width: 6),
                      _statusChip('draft', isEn ? 'Drafts' : 'ረቂቆች'),
                      const SizedBox(width: 6),
                      _statusChip('scheduled', isEn ? 'Scheduled' : 'የታቀዱ'),
                      const SizedBox(width: 6),
                      _statusChip('archived', isEn ? 'Archived' : 'ማህደር'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Issue list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: ErrorView(
                          error: _error!,
                          onRetry: _loadMagazines,
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 64, color: p.muted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              isEn ? 'No magazine issues found' : 'ምንም የሰሌዳ መጽሔት እትም አልተገኘም',
                              style: context.serif(16, color: p.muted, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isEn ? 'Tap "New Issue" to publish the first edition.' : 'የመጀመሪያውን እትም ለማውጣት «አዲስ እትም»ን ይጫኑ።',
                              style: context.sans(13, color: p.subtle),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMagazines,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 84),
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final m = items[i];
                            return _buildMagazineCard(m, isEn);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF650D20).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF650D20) : null,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        fontSize: 12.5,
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = status);
          _loadMagazines();
        }
      },
    );
  }

  Widget _cardCoverFallback() {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A101D), Color(0xFF28070E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 28),
      ),
    );
  }

  Widget _buildMagazineCard(Json m, bool isEn) {
    final title = isEn ? (asStr(m['title_en']) ?? asStr(m['title']) ?? '') : (asStr(m['title']) ?? '');
    final issueNum = asStr(m['issue_number']) ?? '';
    final period = asStr(m['period_info']) ?? '';
    final status = asStr(m['status']);
    final hasPdf = m['pdf_path'] != null && (m['pdf_path'] as String).isNotEmpty;
    final quizzes = asJsonList(m['quizzes']);
    final quizCount = quizzes.isNotEmpty ? quizzes.length : asIntOr(m['quiz_count']);
    final baseUrl = ref.watch(eduRepositoryProvider).api.dio.options.baseUrl;
    final coverUrl = _resolveMediaUrl(asStr(m['cover_url']), baseUrl);
    final id = asIntOr(m['id']);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover icon or thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _cardCoverFallback(),
                      )
                    : _cardCoverFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (issueNum.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              issueNum,
                              style: const TextStyle(color: AppColors.goldDark, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabel(context, status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(title, style: context.serif(15, weight: FontWeight.w700)),
                    if (period.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(period, style: context.sans(12, color: context.palette.muted)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(hasPdf ? Icons.picture_as_pdf_rounded : Icons.link_off_rounded,
                            size: 14, color: hasPdf ? Colors.red.shade700 : Colors.grey),
                        const SizedBox(width: 4),
                        Text(hasPdf ? (isEn ? 'PDF uploaded' : 'ፒዲኤፍ ተጭኗል') : (isEn ? 'No PDF' : 'ፋይል የለውም'),
                            style: context.sans(11, color: context.palette.subtle)),
                        const SizedBox(width: 12),
                        Icon(Icons.quiz_rounded, size: 14, color: quizCount > 0 ? AppColors.goldDark : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          quizCount > 0 ? '$quizCount ${isEn ? 'Quiz' : 'ጥያቄ'}' : (isEn ? 'No Quiz' : 'ጥያቄ የለውም'),
                          style: context.sans(11, color: context.palette.subtle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          // Action Buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(isEn ? 'Preview' : 'ይመልከቱ', style: const TextStyle(fontSize: 12)),
                onPressed: () => context.push('/edu/magazine/$id'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(isEn ? 'Edit' : 'አስተካክል', style: const TextStyle(fontSize: 12)),
                onPressed: () => _openEditor(m),
              ),
              OutlinedButton.icon(
                icon: Icon(status == 'published' ? Icons.unpublished_outlined : Icons.publish_rounded, size: 16),
                label: Text(status == 'published' ? (isEn ? 'Unpublish' : 'አንሳ') : (isEn ? 'Publish' : 'አትም'),
                    style: const TextStyle(fontSize: 12)),
                onPressed: () => _togglePublish(m),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.quiz_outlined, size: 16),
                label: Text(isEn ? 'Add Quiz' : '+ ጥያቄ', style: const TextStyle(fontSize: 12)),
                onPressed: () => _openQuizDialog(m),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                tooltip: isEn ? 'Delete' : 'ሰርዝ',
                onPressed: () => _deleteIssue(m),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet for creating or editing a Magazine Issue.
class EduMagazineEditorSheet extends ConsumerStatefulWidget {
  const EduMagazineEditorSheet({super.key, this.issue});
  final Json? issue;

  @override
  ConsumerState<EduMagazineEditorSheet> createState() => _EduMagazineEditorSheetState();
}

class _EduMagazineEditorSheetState extends ConsumerState<EduMagazineEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _titleEnController;
  late final TextEditingController _issueNumController;
  late final TextEditingController _periodController;
  late final TextEditingController _descController;

  PickedFile? _selectedPdf;
  PickedFile? _selectedCover;
  String? _existingPdfPath;
  int? _existingPdfSize;
  String? _existingCoverUrl;
  bool _removeCover = false;

  late String _status;
  DateTime _issueDate = DateTime.now();
  DateTime? _publishedAt;
  bool _saving = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;

  @override
  void initState() {
    super.initState();
    final m = widget.issue;
    _titleController = TextEditingController(text: asStr(m?['title']) ?? '');
    _titleEnController = TextEditingController(text: asStr(m?['title_en']) ?? '');
    _issueNumController = TextEditingController(text: asStr(m?['issue_number']) ?? '');
    _periodController = TextEditingController(text: asStr(m?['period_info']) ?? '');
    _descController = TextEditingController(text: asStr(m?['description']) ?? '');

    _existingPdfPath = asStr(m?['pdf_path']);
    _existingPdfSize = asIntOr(m?['pdf_size']);
    _existingCoverUrl = asStr(m?['cover_url']) ?? asStr(m?['cover_image']);

    _status = asStr(m?['status']) ?? 'draft';
    if (m?['issue_date'] != null) {
      _issueDate = DateTime.tryParse(asStr(m!['issue_date'])!) ?? DateTime.now();
    }
    if (m?['published_at'] != null) {
      _publishedAt = DateTime.tryParse(asStr(m!['published_at'])!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleEnController.dispose();
    _issueNumController.dispose();
    _periodController.dispose();
    _descController.dispose();
    super.dispose();
  }

  int _getFileSize(String path) {
    if (kIsWeb) {
      return getUploadBytes(path)?.length ?? 0;
    }
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickCover() async {
    final picked = await pickTypedFile(context, kinds: const {PickKind.image});
    if (picked != null) {
      setState(() {
        _selectedCover = picked;
        _removeCover = false;
      });
    }
  }

  void _clearSelectedCover() {
    setState(() {
      _selectedCover = null;
    });
  }

  void _removeExistingCover() {
    setState(() {
      _removeCover = true;
      _selectedCover = null;
      _existingCoverUrl = null;
    });
  }

  Future<void> _pickPdf() async {
    final picked = await pickTypedFile(
      context,
      kinds: const {PickKind.document},
      documents: const ['pdf'],
    );
    if (picked != null) {
      setState(() {
        _selectedPdf = picked;
      });
    }
  }

  void _clearSelectedPdf() {
    setState(() {
      _selectedPdf = null;
    });
  }

  Future<void> _pickDate(bool isIssueDate) async {
    final initial = isIssueDate ? _issueDate : (_publishedAt ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _publishedAt = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    final isEn = l.isEn;
    if (!_formKey.currentState!.validate()) return;

    final hasPdf = _selectedPdf != null || (_existingPdfPath != null && _existingPdfPath!.isNotEmpty);
    if (_status == 'published' && !hasPdf) {
      showErrorSnack(
        context,
        isEn
            ? 'A published magazine issue must have a PDF file uploaded.'
            : 'የታተመ እትም ፒዲኤፍ ፋይል ሊኖረው ይገባል፤ እባክዎ ፒዲኤፍ ይምረጡ።',
      );
      return;
    }

    setState(() {
      _saving = true;
      _uploadProgress = 0.0;
      _uploadStatusText = isEn ? 'Saving magazine details...' : 'የእትሙን መረጃዎች በመመዝገብ ላይ...';
    });

    final isNew = widget.issue == null;
    final id = isNew ? null : asIntOr(widget.issue!['id']);

    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'title_en': _titleEnController.text.trim().isEmpty ? null : _titleEnController.text.trim(),
      'issue_number': _issueNumController.text.trim().isEmpty ? null : _issueNumController.text.trim(),
      'period_info': _periodController.text.trim().isEmpty ? null : _periodController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'issue_date': _issueDate.toIso8601String().split('T').first,
      'status': _status,
      if (_publishedAt != null) 'published_at': _publishedAt!.toIso8601String(),
    };

    try {
      final repo = ref.read(eduRepositoryProvider);
      final int issueId;
      if (isNew) {
        final res = await repo.createMagazine(body);
        issueId = asIntOr(res['id']);
      } else {
        issueId = id!;
        await repo.updateMagazine(issueId, body);
      }

      // Handle Cover Removal
      if (_removeCover && _selectedCover == null && !isNew) {
        setState(() => _uploadStatusText = isEn ? 'Removing cover image...' : 'የሽፋን ምስሉን በማስወገድ ላይ...');
        await repo.deleteMagazineCover(issueId);
      }

      // Handle Cover Upload
      if (_selectedCover != null) {
        setState(() => _uploadStatusText = isEn ? 'Uploading cover image...' : 'የሽፋን ምስሉን በመጫን ላይ...');
        Uint8List? coverBytes;
        if (kIsWeb) {
          coverBytes = getUploadBytes(_selectedCover!.path);
        }
        await repo.uploadMagazineCover(
          issueId,
          _selectedCover!.path,
          fileBytes: coverBytes,
          filename: _selectedCover!.name,
        );
      }

      // Handle PDF Upload
      if (_selectedPdf != null) {
        setState(() {
          _uploadStatusText = isEn ? 'Uploading PDF file (0%)...' : 'የፒዲኤፍ ፋይሉን በመጫን ላይ (0%)...';
          _uploadProgress = 0.05;
        });
        Uint8List? pdfBytes;
        if (kIsWeb) {
          pdfBytes = getUploadBytes(_selectedPdf!.path);
        }
        await repo.uploadMagazinePdf(
          issueId,
          _selectedPdf!.path,
          fileBytes: pdfBytes,
          filename: _selectedPdf!.name,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _uploadProgress = p;
                final pct = (p * 100).toInt();
                _uploadStatusText = '${isEn ? 'Uploading PDF file' : 'የፒዲኤፍ ፋይሉን በመጫን ላይ'} ($pct%)...';
              });
            }
          },
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = 0.0;
          _uploadStatusText = null;
        });
        showErrorSnack(context, e);
      }
    }
  }

  Widget _buildCoverPicker(bool isEn) {
    final baseUrl = ref.watch(eduRepositoryProvider).api.dio.options.baseUrl;
    final resolvedExistingCover = _resolveMediaUrl(_existingCoverUrl, baseUrl);

    Widget thumbnail;
    if (_selectedCover != null) {
      if (kIsWeb) {
        final bytes = getUploadBytes(_selectedCover!.path);
        thumbnail = bytes != null
            ? Image.memory(bytes, width: 68, height: 86, fit: BoxFit.cover)
            : Container(width: 68, height: 86, color: Colors.grey.shade200, child: const Icon(Icons.image));
      } else {
        thumbnail = Image.file(File(_selectedCover!.path), width: 68, height: 86, fit: BoxFit.cover);
      }
    } else if (!_removeCover && resolvedExistingCover.isNotEmpty) {
      thumbnail = Image.network(
        resolvedExistingCover,
        width: 68,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 68,
          height: 86,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    } else {
      thumbnail = Container(
        width: 68,
        height: 86,
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Icon(Icons.photo_outlined, color: Colors.grey, size: 28),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: AppColors.maroon),
              const SizedBox(width: 6),
              Text(
                isEn ? 'Cover Image (Optional)' : 'የሽፋን ምስል (አማራጭ)',
                style: context.sans(13, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedCover != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEn ? 'Ready to upload' : 'ለመጫን ዝግጁ',
                              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatBytes(_getFileSize(_selectedCover!.path)),
                            style: context.sans(11, color: context.palette.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedCover!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(12.5, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: Text(isEn ? 'Replace' : 'ቀይር', style: const TextStyle(fontSize: 12)),
                            onPressed: _saving ? null : _pickCover,
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                            label: Text(isEn ? 'Cancel' : 'ሰርዝ', style: const TextStyle(fontSize: 12, color: Colors.red)),
                            onPressed: _saving ? null : _clearSelectedCover,
                          ),
                        ],
                      ),
                    ] else if (!_removeCover && resolvedExistingCover.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isEn ? 'Current cover' : 'ያለ ሽፋን ምስል',
                          style: const TextStyle(color: AppColors.goldDark, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 14),
                            label: Text(isEn ? 'Replace' : 'ቀይር', style: const TextStyle(fontSize: 12)),
                            onPressed: _saving ? null : _pickCover,
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                            label: Text(isEn ? 'Remove' : 'አስወግድ', style: const TextStyle(fontSize: 12, color: Colors.red)),
                            onPressed: _saving ? null : _removeExistingCover,
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        isEn ? 'No cover image selected' : 'ምንም የሽፋን ምስል አልተመረጠም',
                        style: context.sans(12, color: context.palette.muted),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                        label: Text(isEn ? 'Choose Cover Image' : 'የሽፋን ምስል ምረጥ', style: const TextStyle(fontSize: 12)),
                        onPressed: _saving ? null : _pickCover,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPicker(bool isEn) {
    final hasExisting = _existingPdfPath != null && _existingPdfPath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedPdf != null
              ? Colors.green.withValues(alpha: 0.5)
              : (hasExisting ? AppColors.gold.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.red),
              const SizedBox(width: 6),
              Text(
                isEn ? 'PDF Document *' : 'የፒዲኤፍ እትም ሰነድ *',
                style: context.sans(13, weight: FontWeight.w700),
              ),
              const Spacer(),
              if (_selectedPdf != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEn ? 'New File Selected' : 'አዲስ ፋይል ተመርጧል',
                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                )
              else if (hasExisting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEn ? 'Uploaded' : 'የተጫነ ፒዲኤፍ',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedPdf != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPdf!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(13, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isEn ? 'Size' : 'መጠን'}: ${_formatBytes(_getFileSize(_selectedPdf!.path))}',
                          style: context.sans(11.5, color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isEn ? 'Remove selected file' : 'የተመረጠውን ፋይል ሰርዝ',
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    onPressed: _saving ? null : _clearSelectedPdf,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(isEn ? 'Choose Different PDF' : 'ሌላ ፒዲኤፍ ምረጥ', style: const TextStyle(fontSize: 12)),
                onPressed: _saving ? null : _pickPdf,
              ),
            ),
          ] else if (hasExisting) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _existingPdfPath?.split('/').last ?? 'seleda_magazine.pdf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(13, weight: FontWeight.w700),
                        ),
                        if (_existingPdfSize != null && _existingPdfSize! > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${isEn ? 'Size' : 'መጠን'}: ${_formatBytes(_existingPdfSize!)}',
                            style: context.sans(11.5, color: context.palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 15),
                label: Text(isEn ? 'Replace PDF File' : 'አዲስ ፒዲኤፍ ቀይር', style: const TextStyle(fontSize: 12)),
                onPressed: _saving ? null : _pickPdf,
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    isEn ? 'No PDF file selected' : 'ምንም የፒዲኤፍ ፋይል አልተመረጠም',
                    style: context.sans(13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEn ? 'Browse your device storage to select the magazine PDF' : 'የመጽሔቱን ፒዲኤፍ ፋይል ከመሣሪያዎ ይምረጡ',
                    textAlign: TextAlign.center,
                    style: context.sans(11.5, color: context.palette.muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF650D20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: Text(isEn ? 'Browse PDF File' : 'ፒዲኤፍ ፋይል ምረጥ'),
                    onPressed: _saving ? null : _pickPdf,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final isNew = widget.issue == null;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew ? (isEn ? 'Create Magazine Issue' : 'አዲስ የሰሌዳ መጽሔት እትም') : (isEn ? 'Edit Issue' : 'እትሙን አስተካክል'),
                    style: context.serif(18, weight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title (Amharic)
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Title (Amharic) *' : 'የእትሙ ርዕስ (በአማርኛ) *',
                  hintText: isEn ? 'e.g. ሰሌዳ መጽሔት ቁጥር ፩' : 'ምሳሌ፡ ሰሌዳ መጽሔት ቁጥር ፩',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isEn ? 'Title is required' : 'ርዕስ ያስፈልጋል') : null,
              ),
              const SizedBox(height: 12),

              // Title (English)
              TextFormField(
                controller: _titleEnController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Title (English)' : 'ርዕስ (በእንግሊዝኛ)',
                  hintText: 'e.g. Seleda Magazine Issue 1',
                ),
              ),
              const SizedBox(height: 12),

              // Issue Number & Period Info
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _issueNumController,
                      decoration: InputDecoration(
                        labelText: isEn ? 'Issue No. *' : 'የእትም ቁጥር *',
                        hintText: 'ቅጽ ፩ ቁ. ፩',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? (isEn ? 'Required' : 'ያስፈልጋል') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _periodController,
                      decoration: InputDecoration(
                        labelText: isEn ? 'Period Info' : 'የጊዜ መግለጫ',
                        hintText: 'ጥቅምት ፳፻፲፱',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isEn ? 'Description' : 'ማብራሪያ / ይዘት',
                  hintText: isEn ? 'Key topics covered in this edition...' : 'በዚህ እትም የተካተቱ ዋና ዋና ርዕሶች...',
                ),
              ),
              const SizedBox(height: 12),

              // Status Dropdown
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(labelText: isEn ? 'Status' : 'ሁኔታ'),
                items: [
                  DropdownMenuItem(value: 'draft', child: Text(isEn ? 'Draft' : 'ረቂቅ')),
                  DropdownMenuItem(value: 'published', child: Text(isEn ? 'Published' : 'የታተመ')),
                  DropdownMenuItem(value: 'scheduled', child: Text(isEn ? 'Scheduled' : 'የታቀደ')),
                  DropdownMenuItem(value: 'archived', child: Text(isEn ? 'Archived' : 'ማህደር')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 12),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        '${isEn ? 'Issue Date' : 'የዕትም ቀን'}: ${_issueDate.toIso8601String().split('T').first}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  if (_status == 'scheduled' || _status == 'published') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule_rounded, size: 16),
                        label: Text(
                          _publishedAt != null
                              ? '${isEn ? 'Pub' : 'ሕትመት'}: ${_publishedAt!.toIso8601String().split('T').first}'
                              : (isEn ? 'Set Pub Date' : 'የህትመት ቀን'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _pickDate(false),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // PDF Document Picker Section
              _buildPdfPicker(isEn),
              const SizedBox(height: 14),

              // Cover Image Picker Section
              _buildCoverPicker(isEn),

              // Progress banner when uploading
              if (_saving && _uploadStatusText != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF650D20).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF650D20).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF650D20)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _uploadStatusText!,
                              style: context.sans(12, weight: FontWeight.w600, color: const Color(0xFF650D20)),
                            ),
                          ),
                        ],
                      ),
                      if (_uploadProgress > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF650D20)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF650D20)),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isNew ? (isEn ? 'Create Issue' : 'እትሙን ፍጠር') : (isEn ? 'Save Changes' : 'ለውጦችን መዝግብ')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for creating a 1-Week Availability / 1-Attempt Quiz linked to a Magazine issue.
class EduMagazineQuizEditorDialog extends ConsumerStatefulWidget {
  const EduMagazineQuizEditorDialog({super.key, required this.magazineId, required this.magazineTitle});
  final int magazineId;
  final String magazineTitle;

  @override
  ConsumerState<EduMagazineQuizEditorDialog> createState() => _EduMagazineQuizEditorDialogState();
}

class _EduMagazineQuizEditorDialogState extends ConsumerState<EduMagazineQuizEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _durationController;
  DateTime _closesAt = DateTime.now().add(const Duration(days: 7)); // 1-week availability default
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'የ${widget.magazineTitle} የክለሳ ጥያቄዎች');
    _instructionsController = TextEditingController(
      text: 'ይህ ፈተና ለ1 ሳምንት ብቻ ክፍት ሲሆን 1 ሙከራ ብቻ ይፈቀዳል። እባክዎ መጽሔቱን በጥሞና አንብበው ይመልሱ።',
    );
    _durationController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _closesAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _closesAt = picked.add(const Duration(hours: 23, minutes: 59)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final duration = int.tryParse(_durationController.text.trim()) ?? 30;

    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'time_limit_minutes': duration,
      'max_attempts': 1, // Enforce exact 1 attempt as required
      'closes_at': _closesAt.toIso8601String(), // 1-week availability
      'scoring': 'best',
      'review_policy': 'after_submit',
      'status': 'published',
    };

    try {
      await ref.read(eduRepositoryProvider).createMagazineQuiz(widget.magazineId, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.quiz_rounded, color: AppColors.goldDark, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEn ? 'Add Magazine Quiz' : 'የመጽሔት ጥያቄ አክል',
              style: context.serif(16, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.goldDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Configured with 1-Week Availability and strictly 1 Attempt per student.'
                            : 'ለ1 ሳምንት ብቻ ክፍት ሆኖ ለእያንዳንዱ ተማሪ 1 ሙከራ ብቻ እንዲኖረው ይዘጋጃል።',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.goldDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Quiz Title *' : 'የፈተናው ርዕስ *',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isEn ? 'Title required' : 'ርዕስ ያስፈልጋል') : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _instructionsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isEn ? 'Instructions' : 'መመሪያ',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isEn ? 'Duration (min)' : 'የፈተናው ርዝመት (ደቂቃ)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isEn ? 'Max Attempts' : 'የሙከራ ብዛት',
                      ),
                      child: Text('1 ${isEn ? 'attempt' : 'ሙከራ'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: Text(
                  '${isEn ? 'Closes on' : 'የሚዘጋበት ቀን'}: ${_closesAt.toIso8601String().split('T').first}',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _pickDueDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF650D20)),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEn ? 'Create Quiz' : 'ጥያቄውን ፍጠር'),
        ),
      ],
    );
  }
}
