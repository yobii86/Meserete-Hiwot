import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/library.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../../widgets/typed_picker.dart';
import '../../admin/library_admin.dart' show libraryCategoriesProvider, openLibraryCategoriesConfig;
import '../../library/book_cover.dart';
import '../../library/physical_book_editor_sheet.dart';
import '../learn/digital_book_editor_sheet.dart';

/// Dedicated Education Book Catalog Administration Workspace.
/// Fully separates administrative book record management, detailed metadata,
/// categories, authors, publishers, digital PDF/cover uploads, and physical copies
/// from the student/member-facing "My Library" screen.
class EduBookCatalogScreen extends ConsumerStatefulWidget {
  const EduBookCatalogScreen({super.key});

  @override
  ConsumerState<EduBookCatalogScreen> createState() => _EduBookCatalogScreenState();
}

class _EduBookCatalogScreenState extends ConsumerState<EduBookCatalogScreen> {
  final _ctrl = PagedListController<Book>();
  final _searchCtrl = TextEditingController();

  String _q = '';
  String _kind = 'all'; // 'all' | 'digital' | 'physical'
  int? _selectedCategoryId;
  String _status = 'all'; // 'all' | 'active' | 'inactive'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    _ctrl.refresh();
    setState(() {});
  }

  Future<void> _openNewDigitalBook() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => const DigitalBookEditorSheet(),
    );
    if (res == true) _refresh();
  }

  Future<void> _openNewPhysicalBook() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => const PhysicalBookEditorSheet(),
    );
    if (res == true) _refresh();
  }

  Future<void> _editBook(Book book) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => book.isDigital
          ? DigitalBookEditorSheet(book: book)
          : PhysicalBookEditorSheet(book: book),
    );
    if (res == true) _refresh();
  }

  Future<void> _uploadPdf(Book book) async {
    final l = context.l10n;
    try {
      final picked = await pickTypedFile(
        context,
        kinds: {PickKind.document},
        documents: ['pdf'],
      );
      if (picked == null || !mounted) return;

      final updated = await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).uploadDigitalBookPdf(book.id, picked.path),
        success: l.isEn ? 'PDF file uploaded successfully' : 'የመጽሐፉ ፒዲኤፍ በተሳካ ሁኔታ ተጭኗል',
      );
      if (updated != null) _refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _uploadCover(Book book) async {
    final l = context.l10n;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      if (!mounted) return;
      final repo = ref.read(libraryRepositoryProvider);
      final updated = await runWithProgress(
        context,
        () => book.isDigital
            ? repo.uploadDigitalBookCover(book.id, picked.path)
            : repo.uploadPhysicalBookCover(book.id, picked.path),
        success: l.isEn ? 'Book cover uploaded' : 'የመጽሐፉ ሽፋን በተሳካ ሁኔታ ተጭኗል',
      );
      if (updated != null) _refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _manageCopies(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _PhysicalCopiesManagerSheet(book: book),
    );
    _refresh();
  }

  Future<void> _deleteBook(Book book) async {
    final l = context.l10n;
    final confirm = await showConfirm(
      context,
      l.isEn
          ? 'Are you sure you want to delete "${book.title}"?'
          : '"${book.title}" የሚለውን መጽሐፍ ለማስወገድ እርግጠኛ ነዎት?',
    );
    if (!confirm || !mounted) return;

    try {
      await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).deleteBook(book.id),
        success: l.isEn ? 'Book deleted' : 'መጽሐፉ ተሰርዟል',
      );
      _refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final categoriesAsync = ref.watch(libraryCategoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          l.isEn ? 'Book Catalog Administration' : 'የመጻሕፍት ካታሎግ አስተዳደር',
          style: context.serif(18, weight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: l.isEn ? 'Manage Categories' : 'የመጽሐፍ ምድቦች',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () async {
              await openLibraryCategoriesConfig(context, ref);
              ref.invalidate(libraryCategoriesProvider);
              _refresh();
            },
          ),
          PopupMenuButton<String>(
            tooltip: l.isEn ? 'Quick Actions' : 'ፈጣን ድርጊቶች',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'circulation') {
                context.push('/edu/circulation');
              } else if (val == 'requests') {
                context.push('/edu/library-requests');
              } else if (val == 'my_library') {
                context.push('/edu/library');
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'circulation',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF650D20)),
                    const SizedBox(width: 10),
                    Text(l.libCirculation),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'requests',
                child: Row(
                  children: [
                    const Icon(Icons.outbox_rounded, size: 20, color: AppColors.goldDark),
                    const SizedBox(width: 10),
                    Text(l.isEn ? 'Student Book Requests' : 'የተማሪዎች የውሰት ጥያቄዎች'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'my_library',
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded, size: 20, color: Colors.teal),
                    const SizedBox(width: 10),
                    Text(l.isEn ? 'View as Member (My Library)' : 'እንደ አባል ይመልከቱ (ቤተ-መጻሕፍት)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Primary Action Row & Quick Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openNewDigitalBook,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF650D20),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: Text(
                            l.isEn ? '+ Digital Book' : '+ ዲጂታል መጽሐፍ',
                            style: context.sans(12.5, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _openNewPhysicalBook,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            l.isEn ? '+ Physical Book' : '+ የታተመ መጽሐፍ',
                            style: context.sans(12.5, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border.withValues(alpha: 0.8)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: p.muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: l.isEn
                              ? 'Search title, author, code, publisher...'
                              : 'መጻሕፍትን፣ ደራሲን፣ ኮድ ወይም አሳታሚን ይፈልጉ...',
                          hintStyle: context.sans(12.5, color: p.subtle),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: context.sans(13, color: p.text),
                        onChanged: (v) {
                          setState(() => _q = v.trim());
                          _ctrl.refresh();
                        },
                      ),
                    ),
                    if (_q.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                          _ctrl.refresh();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 3. Filter Row: Format, Category & Status
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Format Filter Chips
                  FilterChip(
                    label: Text(l.isEn ? 'All Formats' : 'ሁሉም ዓይነቶች'),
                    selected: _kind == 'all',
                    onSelected: (_) => setState(() {
                      _kind = 'all';
                      _ctrl.refresh();
                    }),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: Text(l.libDigital),
                    selected: _kind == 'digital',
                    onSelected: (_) => setState(() {
                      _kind = 'digital';
                      _ctrl.refresh();
                    }),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: Text(l.libPhysical),
                    selected: _kind == 'physical',
                    onSelected: (_) => setState(() {
                      _kind = 'physical';
                      _ctrl.refresh();
                    }),
                  ),
                  const SizedBox(width: 8),

                  // Category Filter Dropdown
                  categoriesAsync.maybeWhen(
                    data: (cats) {
                      return PopupMenuButton<int?>(
                        tooltip: l.isEn ? 'Filter by Category' : 'በምድብ ያጣሩ',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedCategoryId != null
                                ? const Color(0xFF650D20).withValues(alpha: 0.12)
                                : p.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedCategoryId != null
                                  ? const Color(0xFF650D20)
                                  : p.border.withValues(alpha: 0.8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 16,
                                color: _selectedCategoryId != null ? const Color(0xFF650D20) : p.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedCategoryId == null
                                    ? (l.isEn ? 'All Categories' : 'ሁሉም ምድቦች')
                                    : _selectedCategoryId == -1
                                        ? (l.isEn ? 'Unclassified' : 'ያልተመደበ')
                                        : cats.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => cats.first).name,
                                style: context.sans(
                                  12,
                                  color: _selectedCategoryId != null ? const Color(0xFF650D20) : p.text,
                                  weight: _selectedCategoryId != null ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down_rounded, size: 18, color: p.muted),
                            ],
                          ),
                        ),
                        onSelected: (catId) {
                          setState(() => _selectedCategoryId = catId);
                          _ctrl.refresh();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem<int?>(
                            value: null,
                            child: Text(l.isEn ? 'All Categories' : 'ሁሉም ምድቦች'),
                          ),
                          PopupMenuItem<int?>(
                            value: -1,
                            child: Text(l.isEn ? 'Unclassified (ያልተመደበ)' : 'ያልተመደበ'),
                          ),
                          const PopupMenuDivider(),
                          ...cats.map((c) => PopupMenuItem<int?>(
                                value: c.id,
                                child: Text('${c.name} (${c.booksCount})'),
                              )),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  const SizedBox(width: 8),

                  // Status Filter (All vs Active)
                  FilterChip(
                    label: Text(_status == 'all' ? (l.isEn ? 'Status: All' : 'ሁኔታ፡ ሁሉም') : (l.isEn ? 'Active Only' : 'ንቁ ብቻ')),
                    selected: _status == 'all',
                    onSelected: (selected) => setState(() {
                      _status = selected ? 'all' : 'active';
                      _ctrl.refresh();
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 4. Admin Catalog List
            Expanded(
              child: PagedListView<Book>(
                key: ValueKey('admin-catalog-$_q-$_kind-$_selectedCategoryId-$_status'),
                controller: _ctrl,
                emptyMessage: l.libNoBooks,
                emptyIcon: Icons.menu_book_rounded,
                fetch: (page) => ref.read(libraryRepositoryProvider).books(
                      domain: 'timhirt',
                      kind: _kind == 'all' ? null : _kind,
                      q: _q.isEmpty ? null : _q,
                      categoryId: _selectedCategoryId,
                      status: _status,
                      includeDrafts: true,
                      page: page,
                    ),
                itemBuilder: (context, book, _) {
                  return _AdminBookCard(
                    book: book,
                    onEdit: () => _editBook(book),
                    onUploadPdf: () => _uploadPdf(book),
                    onUploadCover: () => _uploadCover(book),
                    onManageCopies: () => _manageCopies(book),
                    onDelete: () => _deleteBook(book),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBookCard extends StatelessWidget {
  const _AdminBookCard({
    required this.book,
    required this.onEdit,
    required this.onUploadPdf,
    required this.onUploadCover,
    required this.onManageCopies,
    required this.onDelete,
  });

  final Book book;
  final VoidCallback onEdit;
  final VoidCallback onUploadPdf;
  final VoidCallback onUploadCover;
  final VoidCallback onManageCopies;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;

    final categoryLabel = book.categoryName ?? (book.categoryId != null ? 'ID #${book.categoryId}' : (isEn ? 'Unclassified' : 'ያልተመደበ'));
    final isUnclassified = book.categoryName == null && book.categoryId == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Cover Thumbnail
                SizedBox(
                  width: 68,
                  height: 98,
                  child: Stack(
                    children: [
                      BookCover.fromBook(book, borderRadius: 6),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            book.isDigital ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book.title,
                              style: context.serif(15, weight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: book.status == 'active'
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : p.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book.status == 'active' ? (isEn ? 'Active' : 'ንቁ') : (isEn ? 'Inactive' : 'ያልነቃ'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: book.status == 'active' ? AppColors.success : p.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (book.subtitle != null && book.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          book.subtitle!,
                          style: context.sans(11.5, color: p.muted).copyWith(fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),

                      // Author & Year & Code
                      Text(
                        [
                          if (book.author != null) book.author!,
                          if (book.publicationYear != null) '${book.publicationYear}',
                          book.code,
                        ].join(' · '),
                        style: context.sans(11.5, color: AppColors.goldDark, weight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Badges: Category & Format details
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUnclassified
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : const Color(0xFF650D20).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isUnclassified
                                    ? Colors.grey.withValues(alpha: 0.4)
                                    : const Color(0xFF650D20).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isUnclassified ? p.muted : const Color(0xFF650D20),
                              ),
                            ),
                          ),

                          // Digital File details / Physical Copies details
                          if (book.isDigital) ...[
                            if (book.hasFile)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  book.fileSize != null
                                      ? 'PDF · ${Formatters.fileSize(book.fileSize!)}'
                                      : 'PDF ተጭኗል',
                                  style: const TextStyle(fontSize: 10.5, color: Colors.blue, fontWeight: FontWeight.w600),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  isEn ? 'PDF Missing' : 'ፒዲኤፍ አልተጫነም',
                                  style: const TextStyle(fontSize: 10.5, color: Colors.amber, fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (book.downloads > 0)
                              Text(
                                '${book.downloads} ${isEn ? "downloads" : "ወርዷል"}',
                                style: context.sans(10.5, color: p.subtle),
                              ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book.effectiveTotal > 0
                                    ? '${book.effectiveAvailable}/${book.effectiveTotal} ${isEn ? "copies" : "ቅጂዎች"}'
                                    : (isEn ? 'No copies' : 'ቅጂ የለም'),
                                style: const TextStyle(fontSize: 10.5, color: Colors.teal, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (book.location != null && book.location!.isNotEmpty)
                              Text(
                                '📍 ${book.location!}',
                                style: context.sans(10.5, color: p.subtle),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Administrative Action Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit Details
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(l.isEn ? 'Edit' : 'አስተካክል', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),

                // Upload PDF (for digital)
                if (book.isDigital)
                  TextButton.icon(
                    onPressed: onUploadPdf,
                    icon: Icon(book.hasFile ? Icons.file_upload_outlined : Icons.upload_file_rounded, size: 16),
                    label: Text(
                      book.hasFile ? (isEn ? 'Replace PDF' : 'ፒዲኤፍ ቀይር') : (isEn ? 'Upload PDF' : 'ፒዲኤፍ ጫን'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),

                // Manage Physical Copies (for physical)
                if (!book.isDigital)
                  TextButton.icon(
                    onPressed: onManageCopies,
                    icon: const Icon(Icons.inventory_rounded, size: 16),
                    label: Text(l.isEn ? 'Copies' : 'ቅጂዎች', style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),

                // More Menu: Upload cover, delete
                PopupMenuButton<String>(
                  tooltip: l.isEn ? 'More options' : 'ተጨማሪ',
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'cover') {
                      onUploadCover();
                    } else if (val == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'cover',
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(isEn ? 'Change Cover Image' : 'የሽፋን ምስል ቀይር'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(isEn ? 'Delete Book' : 'መጽሐፉን ሰርዝ', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Physical Copies Manager Sheet for a single book.
class _PhysicalCopiesManagerSheet extends ConsumerStatefulWidget {
  const _PhysicalCopiesManagerSheet({required this.book});

  final Book book;

  @override
  ConsumerState<_PhysicalCopiesManagerSheet> createState() => _PhysicalCopiesManagerSheetState();
}

class _PhysicalCopiesManagerSheetState extends ConsumerState<_PhysicalCopiesManagerSheet> {
  final _ctrl = PagedListController<LibraryCopy>();

  Future<void> _addCopy() async {
    final l = context.l10n;
    final isEn = l.isEn;
    final locationCtrl = TextEditingController(text: widget.book.location ?? '');
    String condition = 'good';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEn ? 'Add Physical Copy' : 'አዲስ የታተመ ቅጂ ጨምር'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.book.title, style: context.sans(13, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: isEn ? 'Shelf / Cabinet Location' : 'የመደርደሪያ ቦታ',
                  hintText: 'e.g. Shelf B-4, Room 2',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: InputDecoration(labelText: isEn ? 'Condition' : 'ሁኔታ'),
                items: [
                  DropdownMenuItem(value: 'good', child: Text(isEn ? 'Good (ጥሩ)' : 'ጥሩ')),
                  DropdownMenuItem(value: 'fair', child: Text(isEn ? 'Fair (መካከለኛ)' : 'መካከለኛ')),
                  DropdownMenuItem(value: 'poor', child: Text(isEn ? 'Poor (ያረጀ)' : 'ያረጀ')),
                  DropdownMenuItem(value: 'damaged', child: Text(isEn ? 'Damaged (የተጎዳ)' : 'የተጎዳ')),
                ],
                onChanged: (v) => setD(() => condition = v ?? 'good'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).addCopy(
              widget.book.id,
              location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
              condition: condition,
            ),
        success: isEn ? 'Copy added successfully' : 'አዲስ ቅጂ በተሳካ ሁኔታ ተጨምሯል',
      );
      _ctrl.refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _editCopy(LibraryCopy copy) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final locationCtrl = TextEditingController(text: copy.location ?? '');
    String condition = copy.condition;
    String status = copy.status;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEn ? 'Edit Copy ${copy.copyCode}' : 'ቅጂ ${copy.copyCode} አስተካክል'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: isEn ? 'Shelf Location' : 'የመደርደሪያ ቦታ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: InputDecoration(labelText: isEn ? 'Condition' : 'ሁኔታ'),
                items: [
                  DropdownMenuItem(value: 'good', child: Text(isEn ? 'Good' : 'ጥሩ')),
                  DropdownMenuItem(value: 'fair', child: Text(isEn ? 'Fair' : 'መካከለኛ')),
                  DropdownMenuItem(value: 'poor', child: Text(isEn ? 'Poor' : 'ያረጀ')),
                  DropdownMenuItem(value: 'damaged', child: Text(isEn ? 'Damaged' : 'የተጎዳ')),
                ],
                onChanged: (v) => setD(() => condition = v ?? 'good'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: InputDecoration(labelText: isEn ? 'Status' : 'የቅጂ ሁኔታ'),
                items: [
                  DropdownMenuItem(value: 'available', child: Text(isEn ? 'Available' : 'ይገኛል')),
                  DropdownMenuItem(value: 'on_loan', child: Text(isEn ? 'On Loan' : 'ተወስዷል')),
                  DropdownMenuItem(value: 'lost', child: Text(isEn ? 'Lost' : 'የጠፋ')),
                  DropdownMenuItem(value: 'withdrawn', child: Text(isEn ? 'Withdrawn' : 'የተሰረዘ')),
                ],
                onChanged: (v) => setD(() => status = v ?? 'available'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).updateCopy(
              copy.id,
              location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
              condition: condition,
              status: status,
            ),
        success: l.saved,
      );
      _ctrl.refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _deleteCopy(LibraryCopy copy) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final confirm = await showConfirm(
      context,
      isEn
          ? 'Are you sure you want to remove copy ${copy.copyCode}?'
          : 'ቅጂ ${copy.copyCode} ለማስወገድ እርግጠኛ ነዎት?',
    );
    if (!confirm || !mounted) return;

    try {
      await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).deleteCopy(copy.id),
        success: isEn ? 'Copy deleted' : 'ቅጂው ተወግዷል',
      );
      _ctrl.refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Physical Copies' : 'የታተሙ ቅጂዎች ዝርዝር',
                      style: context.serif(17, weight: FontWeight.w700),
                    ),
                    Text(
                      widget.book.title,
                      style: context.sans(12, color: p.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _addCopy,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isEn ? 'Add Copy' : 'ቅጂ ጨምር'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF650D20),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // Copies List
          Expanded(
            child: PagedListView<LibraryCopy>(
              controller: _ctrl,
              emptyMessage: isEn ? 'No physical copies registered yet' : 'ምንም የተመዘገቡ ቅጂዎች የሉም',
              emptyIcon: Icons.menu_book_rounded,
              fetch: (page) => ref.read(libraryRepositoryProvider).getCopies(
                    itemId: widget.book.id,
                    page: page,
                  ),
              itemBuilder: (ctx, copy, _) {
                final statusColor = switch (copy.status) {
                  'available' => AppColors.success,
                  'on_loan' => const Color(0xFF1F5F8B),
                  'lost' => Colors.red,
                  _ => p.muted,
                };

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.qr_code_2_rounded, size: 24, color: statusColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    copy.copyCode,
                                    style: context.sans(13.5, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      copy.status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  'Condition: ${copy.condition}',
                                  if (copy.location != null) '📍 ${copy.location}',
                                  if (copy.currentLoan != null) '👤 ${copy.currentLoan!.borrowerName}',
                                ].join(' · '),
                                style: context.sans(11.5, color: p.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isEn ? 'Edit Copy' : 'ቅጂ አስተካክል',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editCopy(copy),
                        ),
                        if (copy.isAvailable)
                          IconButton(
                            tooltip: isEn ? 'Delete Copy' : 'ቅጂ ሰርዝ',
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () => _deleteCopy(copy),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
