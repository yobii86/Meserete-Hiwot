import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../services/book_vault.dart';
import '../../services/favorites_service.dart';
import '../../services/narration_player_service.dart';
import '../../widgets/dialogs.dart';
import '../edu/learn/digital_book_editor_sheet.dart';
import 'physical_book_editor_sheet.dart';
import '../auth/session.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import 'book_cover.dart';
import 'books_screen.dart' show BookReaderScreen, bookRequestStatusLabel;

/// Dedicated, premium reading app Book Details Screen
class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.book,
    this.onBookChanged,
  });

  final Book book;
  final VoidCallback? onBookChanged;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  late Book _book = widget.book;
  bool _downloaded = false;
  double? _downloadProgress;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _refreshBook();
  }

  Future<void> _checkStatus() async {
    if (_book.isDigital) {
      final exists = await BookVault.has(_book.id);
      if (mounted) setState(() => _downloaded = exists);
    }
  }

  Future<void> _refreshBook() async {
    try {
      final updated = await ref.read(libraryRepositoryProvider).book(_book.id);
      if (mounted) {
        setState(() {
          _book = updated;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final favCtrl = ref.read(bookFavoritesProvider.notifier);
    final current = favCtrl.isFavorite(_book.id, _book.isFavorite);
    try {
      await favCtrl.toggle(_book.id, currentState: current);
      widget.onBookChanged?.call();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _download() async {
    final l = context.l10n;
    if (_book.fileUrl == null || _book.fileUrl!.isEmpty) {
      showSnack(context, l.isEn ? 'Book file is not available on the server' : 'የመጽሐፉ ፋይል በሰርቨሩ ላይ አልተገኘም');
      return;
    }
    setState(() => _downloadProgress = 0);
    try {
      final pdf = await ref.read(libraryRepositoryProvider).downloadBook(_book, onProgress: (r, t) {
        if (t > 0 && mounted) setState(() => _downloadProgress = r / t);
      });
      await BookVault.save(_book.id, pdf);
      if (mounted) setState(() => _downloaded = true);
      widget.onBookChanged?.call();
      await _openReader();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
    }
  }

  Future<void> _openReader() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: _book)),
    );
    await _checkStatus();
    await _refreshBook();
    widget.onBookChanged?.call();
  }

  Future<void> _removeDownload() async {
    final l = context.l10n;
    final confirm = await showConfirm(
      context,
      l.isEn ? 'Remove this downloaded book from your device?' : 'የወረደውን መጽሐፍ ከመሣሪያዎ ላይ ማጥፋት ይፈልጋሉ?',
    );
    if (!confirm || !mounted) return;
    await BookVault.remove(_book.id);
    if (mounted) {
      setState(() => _downloaded = false);
      showSnack(context, l.isEn ? 'Download removed' : 'የወረደው ፋይል ተሰርዟል');
    }
    widget.onBookChanged?.call();
  }

  Future<void> _playNarration() async {
    final narrationCtrl = ref.read(narrationControllerProvider.notifier);
    await narrationCtrl.playBook(_book);
  }

  Future<void> _requestBorrow() async {
    if (_isRequesting) return;
    final l = context.l10n;
    final note = TextEditingController();
    DateTime? needed;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.menu_book_rounded, color: AppColors.eduBurgundy),
            const SizedBox(width: 8),
            Expanded(child: Text(l.libRequestTitle)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_book.title, style: context.serif(14, weight: FontWeight.w700)),
              if (_book.author != null)
                Text(_book.author!, style: context.sans(12, color: context.palette.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.libRequestNote,
                  hintText: l.isEn ? 'e.g., Needed for Sunday School class' : 'ምሳሌ፡ ለሰንበት ት/ቤት ትምህርት',
                ),
              ),
              const SizedBox(height: 12),
              DateTimeField(
                label: l.libNeededOn,
                value: needed,
                withTime: false,
                clearable: true,
                onChanged: (d) => setS(() => needed = d),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              key: const ValueKey('detail-book-request-send'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.libRequest),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _isRequesting = true);
    try {
      final res = await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).request(
          _book.id,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          neededOn: needed == null ? null : Formatters.isoDate(needed!),
        ),
        success: l.libRequestSent,
      );
      if (res != null && mounted) {
        await _refreshBook();
        widget.onBookChanged?.call();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    ref.watch(bookFavoritesProvider);
    final isFav = ref.read(bookFavoritesProvider.notifier).isFavorite(_book.id, _book.isFavorite);
    final user = ref.watch(currentUserProvider);
    final canEdit = user?.can(Perm.itemsManage) == true ||
        user?.can(Perm.borrowingManage) == true ||
        user?.can(Perm.libraryCirculate) == true ||
        user?.isAdmin == true;

    return Scaffold(
      backgroundColor: p.fill,
      appBar: AppBar(
        title: Text(l.isEn ? 'Book Details' : 'የመጽሐፍ ዝርዝር'),
        actions: [
          if (canEdit)
            IconButton(
              key: ValueKey('detail-edit-book-btn-${_book.id}'),
              tooltip: l.isEn ? 'Edit Book' : 'መጽሐፉን አስተካክል',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                    child: _book.kind == 'digital'
                        ? DigitalBookEditorSheet(book: _book)
                        : PhysicalBookEditorSheet(book: _book),
                  ),
                );
                if (saved == true && mounted) {
                  await _refreshBook();
                  widget.onBookChanged?.call();
                }
              },
            ),
          IconButton(
            key: ValueKey('detail-fav-btn-${_book.id}'),
            tooltip: isFav ? l.libRemoveFromFavorites : l.libAddToFavorites,
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? const Color(0xFF650D20) : p.text,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hero Book Cover
                    Center(
                      child: BookCover.fromBook(
                        _book,
                        width: 160,
                        height: 232,
                        heroTag: 'book-cover-${_book.id}',
                        borderRadius: 10,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Book Title
                    Text(
                      _book.title,
                      textAlign: TextAlign.center,
                      style: context.serif(20, weight: FontWeight.w700),
                    ),
                    if (_book.subtitle != null && _book.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _book.subtitle!,
                        textAlign: TextAlign.center,
                        style: context.sans(13, color: p.muted).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Author
                    if (_book.author != null && _book.author!.isNotEmpty)
                      Text(
                        _book.author!,
                        textAlign: TextAlign.center,
                        style: context.sans(14, color: AppColors.goldDark, weight: FontWeight.w600),
                      ),
                    const SizedBox(height: 12),

                    // Category & Code Badges Row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_book.categoryName != null || _book.category != null)
                                ? const Color(0xFF650D20).withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (_book.categoryName != null || _book.category != null)
                                  ? const Color(0xFF650D20).withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _book.categoryName ?? _book.category ?? (l.isEn ? 'Unclassified' : 'ያልተመደበ'),
                            style: context.sans(
                              12,
                              color: (_book.categoryName != null || _book.category != null)
                                  ? const Color(0xFF650D20)
                                  : p.muted,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            _book.isDigital ? 'PDF Document' : 'Physical Book',
                            style: context.sans(12, color: p.muted, weight: FontWeight.w500),
                          ),
                        ),
                        if (_book.code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              _book.code,
                              style: context.sans(11, color: p.subtle),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Reading Progress Card if in progress
                    if (_book.isDigital && _book.progress != null && _book.progress!.page > 0) ...[
                      _ReadingProgressCard(
                        progress: _book.progress!,
                        onResume: _openReader,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Metadata Metrics Grid
                    _MetadataGrid(
                      book: _book,
                      isDownloaded: _downloaded,
                    ),
                    const SizedBox(height: 20),

                    // Narration Audio Banner (if available)
                    if (_book.hasNarration) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6A044).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.headphones_rounded, color: AppColors.goldDark, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.libListenNarration,
                                    style: context.sans(13, weight: FontWeight.bold, color: p.text),
                                  ),
                                  if (_book.narrationDuration != null)
                                    Text(
                                      '${(_book.narrationDuration! ~/ 60)} min audio narration',
                                      style: context.sans(11, color: p.muted),
                                    ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _playNarration,
                              child: Text(l.isEn ? 'Listen' : 'አዳምጥ'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Description Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.isEn ? 'About This Book' : 'ስለ መጽሐፉ',
                        style: context.serif(16, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        (_book.description != null && _book.description!.trim().isNotEmpty)
                            ? _book.description!
                            : (l.isEn
                                ? 'No detailed description available for this book.'
                                : 'ለዚህ መጽሐፍ የተሰጠ ዝርዝር ማብራሪያ የለም።'),
                        style: context.sans(13.5, color: p.text).copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Primary Action Bar
            _buildBottomActionBar(context, p, l),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, Palette p, AppLocalizations l) {
    if (_book.isDigital) {
      if (_book.fileUrl == null || _book.fileUrl!.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.card,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.isEn ? 'Document file not available' : 'የመጽሐፉ ፋይል አልተገኘም',
              style: context.sans(13, color: p.muted),
            ),
          ),
        );
      }

      if (_downloadProgress != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: p.card,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.isEn ? 'Downloading book...' : 'መጽሐፉ በመውረድ ላይ...', style: context.sans(13, weight: FontWeight.w600)),
                  Text('${((_downloadProgress ?? 0) * 100).toInt()}%', style: context.sans(13, color: AppColors.goldDark, weight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress, color: const Color(0xFF650D20), backgroundColor: p.border),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            if (_downloaded) ...[
              IconButton(
                tooltip: l.libDeleteDownload,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: _removeDownload,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton.icon(
                key: ValueKey('detail-action-${_book.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF650D20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _downloaded ? _openReader : _download,
                icon: Icon(_downloaded ? Icons.menu_book_rounded : Icons.download_rounded, size: 20),
                label: Text(
                  _downloaded
                      ? (_book.progress != null && _book.progress!.page > 0
                          ? '${l.libOpen} (Page ${_book.progress!.page})'
                          : l.libRead)
                      : '${l.libDownload} & ${l.libRead}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Physical Book Action Bar
    Widget physicalAction;
    if (_book.myRequest != null) {
      final status = _book.myRequest!;
      final isIssued = status == 'issued' || status == 'borrowed' || status == 'active';
      physicalAction = Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isIssued ? const Color(0xFF1F5F8B).withValues(alpha: 0.12) : AppColors.goldDark.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isIssued ? const Color(0xFF1F5F8B) : AppColors.goldDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isIssued ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: isIssued ? const Color(0xFF1F5F8B) : AppColors.goldDark, size: 18),
            const SizedBox(width: 8),
            Text(
              isIssued ? (l.isEn ? 'Currently Borrowed' : 'ተወስዷል') : '${l.isEn ? 'Request' : 'የውሰት ሁኔታ'}: ${bookRequestStatusLabel(l, status)}',
              style: context.sans(14, weight: FontWeight.bold, color: isIssued ? const Color(0xFF1F5F8B) : AppColors.goldDark),
            ),
          ],
        ),
      );
    } else if (_book.effectiveAvailable <= 0 && (_book.available ?? 0) <= 0) {
      physicalAction = OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: null,
        child: Text(l.libNoneAvailable, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    } else {
      physicalAction = FilledButton.icon(
        key: ValueKey('detail-request-btn-${_book.id}'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF650D20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _isRequesting ? null : _requestBorrow,
        icon: _isRequesting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.outbox_rounded, size: 20),
        label: Text(l.libRequest, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SizedBox(width: double.infinity, child: physicalAction),
    );
  }
}

class _ReadingProgressCard extends StatelessWidget {
  const _ReadingProgressCard({required this.progress, required this.onResume});
  final BookProgress progress;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final double? fraction = (progress.pageCount != null && progress.pageCount! > 0)
        ? (progress.page / progress.pageCount!).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC6A044).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_added_rounded, color: AppColors.goldDark, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    l.isEn ? 'Reading Progress' : 'የንባብ ደረጃ',
                    style: context.sans(13, weight: FontWeight.bold, color: p.text),
                  ),
                ],
              ),
              Text(
                progress.pageCount != null ? '${progress.page} / ${progress.pageCount} pages' : 'Page ${progress.page}',
                style: context.sans(12, color: AppColors.goldDark, weight: FontWeight.w700),
              ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                color: const Color(0xFFC6A044),
                backgroundColor: p.border,
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(l.isEn ? 'Continue Reading' : 'ንባብ ይቀጥሉ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.book, required this.isDownloaded});
  final Book book;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: l.isEn ? 'Format' : 'ቅርጸት',
                value: book.isDigital ? 'PDF' : (l.isEn ? 'Printed' : 'የታተመ'),
                icon: book.isDigital ? Icons.picture_as_pdf_outlined : Icons.menu_book_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: book.isDigital ? (l.isEn ? 'File Size' : 'መጠን') : (l.isEn ? 'Available' : 'ያሉ ቅጂዎች'),
                value: book.isDigital
                    ? (book.fileSize != null ? Formatters.fileSize(book.fileSize!) : '—')
                    : '${book.effectiveAvailable} / ${book.effectiveTotal}',
                icon: book.isDigital ? Icons.sd_storage_outlined : Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: l.isEn ? 'Status' : 'ሁኔታ',
                value: book.isDigital
                    ? (isDownloaded ? (l.isEn ? 'Downloaded' : 'ወርዷል') : (l.isEn ? 'Online' : 'ኦንላይን'))
                    : (book.effectiveAvailable > 0 ? (l.isEn ? 'In Stock' : 'አለ') : (l.isEn ? 'Borrowed' : 'ተወስዷል')),
                icon: book.isDigital
                    ? (isDownloaded ? Icons.download_done_rounded : Icons.cloud_outlined)
                    : (book.effectiveAvailable > 0 ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded),
                color: (book.isDigital && isDownloaded) || (!book.isDigital && book.effectiveAvailable > 0)
                    ? AppColors.success
                    : null,
              ),
            ),
          ],
        ),
        if ((book.publisher != null && book.publisher!.trim().isNotEmpty) ||
            book.publicationYear != null ||
            (book.language != null && book.language!.trim().isNotEmpty)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (book.publisher != null && book.publisher!.trim().isNotEmpty)
                Expanded(
                  child: _MetricTile(
                    label: l.isEn ? 'Publisher' : 'አሳታሚ',
                    value: book.publisher!,
                    icon: Icons.business_outlined,
                  ),
                ),
              if (book.publisher != null &&
                  book.publisher!.trim().isNotEmpty &&
                  (book.publicationYear != null || (book.language != null && book.language!.trim().isNotEmpty)))
                const SizedBox(width: 8),
              if (book.publicationYear != null)
                Expanded(
                  child: _MetricTile(
                    label: l.isEn ? 'Year' : 'የታተመበት ዓመት',
                    value: '${book.publicationYear}',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              if (book.publicationYear != null && (book.language != null && book.language!.trim().isNotEmpty))
                const SizedBox(width: 8),
              if (book.language != null && book.language!.trim().isNotEmpty)
                Expanded(
                  child: _MetricTile(
                    label: l.isEn ? 'Language' : 'ቋንቋ',
                    value: book.languageLabel,
                    icon: Icons.translate_rounded,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color ?? p.muted),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(12, weight: FontWeight.bold, color: color ?? p.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.sans(10, color: p.subtle),
          ),
        ],
      ),
    );
  }
}
