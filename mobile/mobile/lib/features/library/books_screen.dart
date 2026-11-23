import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/library.dart';
import '../../repositories/providers.dart';
import '../../services/book_vault.dart';
import '../../services/favorites_service.dart';
import '../../services/narration_player_service.dart';
import '../../widgets/secure_screen.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import '../auth/session.dart';
import 'book_cover.dart';
import 'book_detail_screen.dart';

String bookRequestStatusLabel(AppLocalizations l, String s) => switch (s) {
      'approved' => l.libReqApproved,
      'rejected' => l.libReqRejected,
      'issued' => l.libReqIssued,
      'cancelled' => l.libReqCancelled,
      _ => l.libRequested,
    };

Color bookRequestStatusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      'issued' => const Color(0xFF1F5F8B),
      _ => AppColors.goldDark,
    };

/// Upgraded PDF reader (F16):
/// - Restores last page (page memory & offline progress sync)
/// - Text search with PdfTextSearcher & in-memory highlights
/// - Page-number jump & zoom controls
/// - Landscape / auto-rotation support
/// - Integrated audio narration playback with background lock-screen controls
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.book, this.initialBytes});
  final Book book;
  final Uint8List? initialBytes;

  static const _channel = MethodChannel('mezmur/settings');

  static Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod('setSecure', {'on': on});
    } catch (_) {
      // Not Android / tests: nothing to do.
    }
  }

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  late Future<Uint8List> _pdf;
  late final PdfViewerController _controller = PdfViewerController();
  PdfTextSearcher? _searcher;

  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  late int _currentPage = widget.book.progress?.page ?? 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _pdf = Future.value(widget.initialBytes!);
    } else {
      _pdf = _loadPdf();
    }
    SecureScreen.acquire();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<Uint8List> _loadPdf() async {
    try {
      return await BookVault.read(widget.book.id);
    } catch (_) {
      final pdf = await ref.read(libraryRepositoryProvider).downloadBook(widget.book);
      await BookVault.save(widget.book.id, pdf);
      return pdf;
    }
  }

  void _onSearcherChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher?.removeListener(_onSearcherChanged);
    _searcher?.dispose();
    _searchCtrl.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SecureScreen.release();
    super.dispose();
  }

  void _onPageChanged(int? page) {
    if (page == null || page == _currentPage) return;
    setState(() => _currentPage = page);
    ref.read(libraryRepositoryProvider).saveProgress(
          widget.book.id,
          page: page,
          pageCount: _controller.isReady ? _controller.pageCount : null,
        );
  }

  Future<void> _jumpToPageDialog() async {
    final l = context.l10n;
    final total = _controller.isReady ? _controller.pageCount : null;
    final pageCtrl = TextEditingController(text: '$_currentPage');

    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.libJumpToPage),
        content: TextField(
          controller: pageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l.libPageNumber,
            hintText: total != null ? '1 – $total' : '1, 2…',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(pageCtrl.text.trim());
              Navigator.pop(ctx, n);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );

    if (target != null && target >= 1 && (total == null || target <= total)) {
      await _controller.goToPage(pageNumber: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final narration = ref.watch(narrationControllerProvider);
    final isThisNarration = narration.book?.id == widget.book.id;

    return Scaffold(
      appBar: AppBar(
        title: (_showSearch && _searcher != null)
            ? TextField(
                key: const ValueKey('reader-search-input'),
                controller: _searchCtrl,
                autofocus: true,
                style: context.sans(14),
                decoration: InputDecoration(
                  hintText: l.libSearchInBook,
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _searcher?.resetTextSearch();
                          },
                        )
                      : null,
                ),
                onChanged: (v) => _searcher?.startTextSearch(v, caseInsensitive: true),
              )
            : Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_showSearch && _searcher != null) ...[
            if (_searcher!.hasMatches) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_searcher!.currentIndex != null ? _searcher!.currentIndex! + 1 : 0}/${_searcher!.matches.length}',
                    style: context.sans(12, color: p.muted, weight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('reader-search-prev'),
                tooltip: l.libPrevMatch,
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: _searcher!.goToPrevMatch,
              ),
              IconButton(
                key: const ValueKey('reader-search-next'),
                tooltip: l.libNextMatch,
                icon: const Icon(Icons.arrow_downward_rounded),
                onPressed: _searcher!.goToNextMatch,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _showSearch = false;
                  _searchCtrl.clear();
                  _searcher?.resetTextSearch();
                });
              },
            ),
          ] else ...[
            if (_searcher != null)
              IconButton(
                key: const ValueKey('reader-search-toggle'),
                tooltip: l.search,
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() => _showSearch = true),
              ),
            IconButton(
              tooltip: l.libZoomIn,
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: () => _controller.zoomUp(),
            ),
            IconButton(
              tooltip: l.libZoomOut,
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: () => _controller.zoomDown(),
            ),
            TextButton(
              key: const ValueKey('reader-jump-page-btn'),
              onPressed: _jumpToPageDialog,
              child: Text(
                '$_currentPage${_controller.isReady ? ' / ${_controller.pageCount}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.maroon),
                    const SizedBox(height: 12),
                    Text(
                      l.isEn ? 'Could not open book' : 'መጽሐፉን መክፈት አልተቻለም',
                      style: context.serif(18, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: context.sans(12, color: context.palette.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.retry),
                      onPressed: () => setState(() => _pdf = _loadPdf()),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(l.isEn ? 'Loading book...' : 'መጽሐፉ እየተከፈተ ነው...', style: context.sans(13)),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: PdfViewer.data(
                  snap.data!,
                  sourceName: 'library-book-${widget.book.id}',
                  controller: _controller,
                  params: PdfViewerParams(
                    backgroundColor: context.palette.fill,
                    calculateInitialPageNumber: (_, _) => _currentPage,
                    onPageChanged: _onPageChanged,
                    onViewerReady: (document, controller) {
                      if (!mounted) return;
                      _searcher?.removeListener(_onSearcherChanged);
                      _searcher?.dispose();
                      setState(() {
                        _searcher = PdfTextSearcher(controller)..addListener(_onSearcherChanged);
                      });
                    },
                    pagePaintCallbacks: [
                      if (_searcher != null) _searcher!.pageTextMatchPaintCallback,
                    ],
                    textSelectionParams: const PdfTextSelectionParams(enabled: false),
                  ),
                ),
              ),
              // Optional Narration bar inside the reader
              if (widget.book.hasNarration)
                _ReaderNarrationBar(
                  book: widget.book,
                  isActive: isThisNarration,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderNarrationBar extends ConsumerWidget {
  const _ReaderNarrationBar({required this.book, required this.isActive});
  final Book book;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final narration = ref.watch(narrationControllerProvider);
    final ctrl = ref.read(narrationControllerProvider.notifier);

    final isPlaying = isActive && narration.isPlaying;
    final pos = isActive ? narration.position : Duration(milliseconds: book.progress?.audioPositionMs ?? 0);
    final dur = isActive && narration.duration > Duration.zero
        ? narration.duration
        : Duration(seconds: book.narrationDuration ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.headphones_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l.libNarration}: ${book.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.sans(12, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '-10s',
              icon: const Icon(Icons.replay_10_rounded, size: 20),
              onPressed: isActive ? () => ctrl.skip(const Duration(seconds: -10)) : null,
            ),
            IconButton.filled(
              key: const ValueKey('reader-narration-play-pause'),
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: () {
                if (isPlaying) {
                  ctrl.pause();
                } else {
                  ctrl.playBook(book, initialPosition: pos);
                }
              },
            ),
            IconButton(
              tooltip: '+30s',
              icon: const Icon(Icons.forward_30_rounded, size: 20),
              onPressed: isActive ? () => ctrl.skip(const Duration(seconds: 30)) : null,
            ),
            TextButton(
              onPressed: isActive
                  ? () {
                      final speeds = [0.75, 1.0, 1.25, 1.5];
                      final next = speeds[(speeds.indexOf(narration.speed) + 1) % speeds.length];
                      ctrl.setSpeed(next);
                    }
                  : null,
              child: Text('${narration.speed}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ]),
          if (dur > Duration.zero) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                max: dur.inMilliseconds.toDouble(),
                onChanged: isActive ? (v) => ctrl.seek(Duration(milliseconds: v.round())) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(Formatters.duration(pos), style: context.sans(10, color: p.subtle)),
                Text(Formatters.duration(dur), style: context.sans(10, color: p.subtle)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

enum LibraryShortcut { discover, favorites, downloads, reading }

/// The redesigned Education Library:
/// - Editorial Ethiopian Orthodox Church digital & physical library experience
/// - Brand colors: Deep burgundy (#650D20), Warm cream (#FFF8E9), Muted gold (#C6A044)
/// - 4 Category Shortcuts: Discover (አስስ), Favorites (የተወደዱ), Downloads (የወረዱ), Reading (በማንበብ ላይ)
/// - Continue Reading horizontal shelf with real saved reading progress
/// - Explore Books two-column responsive grid with dominant book covers & independent favorite action
/// - Dedicated BookDetailScreen navigation
/// - Physical book circulation & borrowing request flow
class LibraryBooksScreen extends ConsumerStatefulWidget {
  const LibraryBooksScreen({
    super.key,
    this.domain = 'timhirt',
    this.borrowingsRoute = '/edu/borrowings',
    this.fromAdmin = false,
  });

  final String domain;
  final String borrowingsRoute;
  final bool fromAdmin;

  @override
  ConsumerState<LibraryBooksScreen> createState() => _LibraryBooksScreenState();
}

class _LibraryBooksScreenState extends ConsumerState<LibraryBooksScreen> {
  LibraryShortcut _activeShortcut = LibraryShortcut.discover;
  String _kind = 'digital'; // 'all' | 'digital' | 'physical' | 'mine'
  String _q = '';
  final _searchCtrl = TextEditingController();
  int? _selectedCategoryId;
  bool _favoritesOnly = false;
  String? _language;
  bool _availableOnly = false;
  bool _isGridView = true;

  bool _hasActiveFilters() =>
      _selectedCategoryId != null ||
      _language != null ||
      _availableOnly ||
      _favoritesOnly ||
      _kind == 'physical';

  int _activeFilterCount() {
    var c = 0;
    if (_selectedCategoryId != null) c++;
    if (_language != null) c++;
    if (_availableOnly) c++;
    if (_favoritesOnly) c++;
    if (_kind == 'physical') c++;
    return c;
  }

  late final Future<List<LibraryCategory>> _categories =
      ref.read(libraryRepositoryProvider).categories(domain: widget.domain);

  final _discoverCtrl = PagedListController<Book>();
  final _favoritesCtrl = PagedListController<Book>();
  final _downloadsCtrl = PagedListController<Book>();
  final _readingCtrl = PagedListController<Book>();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshActive() {
    switch (_activeShortcut) {
      case LibraryShortcut.discover:
        _discoverCtrl.refresh();
        break;
      case LibraryShortcut.favorites:
        _favoritesCtrl.refresh();
        break;
      case LibraryShortcut.downloads:
        _downloadsCtrl.refresh();
        break;
      case LibraryShortcut.reading:
        _readingCtrl.refresh();
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final canCirculate = user?.can('library.circulate') == true || user?.isAdmin == true;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (canPop) {
          Navigator.of(context).pop();
        } else if (widget.fromAdmin) {
          context.go('/edu/admin');
        } else if (widget.domain == 'timhirt') {
          context.go('/edu');
        } else {
          context.go('/home');
        }
      },
      child: PatternScaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Compact Editorial Header
              _buildHeader(context, p, l, canPop, canCirculate),

              // 2. Integrated Search Bar (Jiji style with filter button & badge)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: _buildSearchBar(context, p, l),
              ),

              // Active filter chips (if any)
              if (_hasActiveFilters())
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _buildActiveFilterChips(context, p, l),
                ),

              // 3. Four Category Shortcuts directly below header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildCategoryShortcuts(context, p, l),
              ),

              const SizedBox(height: 6),

              // 4. Main Body Content based on active shortcut
              Expanded(
                child: switch (_activeShortcut) {
                  LibraryShortcut.discover => _buildDiscoverView(context, p, l, canCirculate),
                  LibraryShortcut.favorites => _buildFavoritesView(context, p, l),
                  LibraryShortcut.downloads => _buildDownloadsView(context, p, l),
                  LibraryShortcut.reading => _buildReadingView(context, p, l),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Palette p, AppLocalizations l, bool canPop, bool canCirculate) {
    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final isTabRoot = currentPath == '/edu/library';
    final showBack = widget.fromAdmin || (canPop && !isTabRoot);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (canPop) {
                  Navigator.of(context).pop();
                } else if (widget.fromAdmin) {
                  context.go('/edu/admin');
                } else if (widget.domain == 'timhirt') {
                  context.go('/edu');
                } else {
                  context.go('/home');
                }
              },
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.isEn ? 'My Library' : 'የእኔ ቤተ-መጻሕፍት',
                  style: context.serif(20, weight: FontWeight.w700),
                ),
                Text(
                  l.isEn ? 'Discover books. Continue your journey.' : 'መጻሕፍትን ይፈልጉ። ንባብዎን ይቀጥሉ።',
                  style: context.sans(11.5, color: p.muted),
                ),
              ],
            ),
          ),
          if (widget.fromAdmin && canCirculate) ...[
            IconButton(
              tooltip: l.isEn ? 'Book Catalog Administration' : 'የካታሎግ አስተዳደር',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push('/edu/admin/catalog'),
            ),
          ],
          IconButton(
            tooltip: l.myBorrowings,
            icon: const Icon(Icons.menu_book_rounded, color: AppColors.goldDark),
            onPressed: () => context.push(widget.borrowingsRoute),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, Palette p, AppLocalizations l) {
    final filterCount = _activeFilterCount();
    return Row(
      children: [
        Expanded(
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
                      hintText: l.isEn ? 'Search books, authors...' : 'መጻሕፍትን፣ ደራሲያንን ይፈልጉ...',
                      hintStyle: context.sans(13, color: p.subtle),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: context.sans(13, color: p.text),
                    onChanged: (v) {
                      setState(() => _q = v.trim());
                      _refreshActive();
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
                      _refreshActive();
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showFilterBottomSheet(context, l),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: filterCount > 0 ? AppColors.maroon.withValues(alpha: 0.1) : p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: filterCount > 0 ? AppColors.maroon : p.border.withValues(alpha: 0.8),
                width: filterCount > 0 ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: filterCount > 0 ? AppColors.maroon : p.muted,
                ),
                if (filterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.maroon,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$filterCount',
                      style: context.sans(10, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips(BuildContext context, Palette p, AppLocalizations l) {
    return FutureBuilder<List<LibraryCategory>>(
      future: _categories,
      builder: (ctx, snap) {
        final allCats = snap.data ?? const <LibraryCategory>[];
        String? catName;
        if (_selectedCategoryId != null) {
          if (_selectedCategoryId == -1) {
            catName = l.isEn ? 'Unclassified' : 'ያልተመደበ';
          } else {
            final found = allCats.where((c) => c.id == _selectedCategoryId).firstOrNull;
            catName = found?.name;
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_selectedCategoryId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(catName ?? '${l.itemCategory}: $_selectedCategoryId', style: context.sans(11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _selectedCategoryId = null);
                      _refreshActive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_kind == 'physical')
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(l.libPhysical, style: context.sans(11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _kind = 'digital');
                      _refreshActive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_language != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text('${l.isEn ? "Lang:" : "ቋንቋ:"} $_language', style: context.sans(11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _language = null);
                      _refreshActive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_availableOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(l.isEn ? 'Available Only' : 'የሚገኙ ብቻ', style: context.sans(11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _availableOnly = false);
                      _refreshActive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_favoritesOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(l.libFavorites, style: context.sans(11)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _favoritesOnly = false);
                      _refreshActive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ActionChip(
                label: Text(l.isEn ? 'Clear all' : 'ሁሉንም አፅዳ', style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _language = null;
                    _availableOnly = false;
                    _favoritesOnly = false;
                    _kind = 'digital';
                  });
                  _refreshActive();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryShortcuts(BuildContext context, Palette p, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ShortcutPill(
            key: const ValueKey('library-shortcut-discover'),
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: l.isEn ? 'Discover' : 'አስስ',
            isSelected: _activeShortcut == LibraryShortcut.discover,
            onTap: () => setState(() => _activeShortcut = LibraryShortcut.discover),
          ),
          const SizedBox(width: 4),
          _ShortcutPill(
            key: const ValueKey('library-shortcut-favorites'),
            icon: Icons.favorite_border_rounded,
            activeIcon: Icons.favorite_rounded,
            label: l.libFavorites,
            isSelected: _activeShortcut == LibraryShortcut.favorites,
            onTap: () {
              setState(() => _activeShortcut = LibraryShortcut.favorites);
              _favoritesCtrl.refresh();
            },
          ),
          const SizedBox(width: 4),
          _ShortcutPill(
            key: const ValueKey('library-shortcut-downloads'),
            icon: Icons.download_outlined,
            activeIcon: Icons.download_done_rounded,
            label: l.libDownloaded,
            isSelected: _activeShortcut == LibraryShortcut.downloads,
            onTap: () {
              setState(() => _activeShortcut = LibraryShortcut.downloads);
              _downloadsCtrl.refresh();
            },
          ),
          const SizedBox(width: 4),
          _ShortcutPill(
            key: const ValueKey('library-shortcut-reading'),
            icon: Icons.bookmark_border_rounded,
            activeIcon: Icons.bookmark_added_rounded,
            label: l.isEn ? 'Reading' : 'በማንበብ ላይ',
            isSelected: _activeShortcut == LibraryShortcut.reading,
            onTap: () {
              setState(() => _activeShortcut = LibraryShortcut.reading);
              _readingCtrl.refresh();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterBottomSheet(BuildContext context, AppLocalizations l) async {
    final isEn = l.isEn;
    final allCats = await _categories;

    var tempCategoryId = _selectedCategoryId;
    var tempKind = _kind;
    var tempLang = _language;
    var tempAvailable = _availableOnly;
    var tempFavorites = _favoritesOnly;

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Filter Books' : 'የመጽሐፍ ማጣሪያዎች',
                      style: context.serif(18, weight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempCategoryId = null;
                          tempKind = 'digital';
                          tempLang = null;
                          tempAvailable = false;
                          tempFavorites = false;
                        });
                      },
                      child: Text(isEn ? 'Reset' : 'እንደነበር መልስ', style: TextStyle(color: AppColors.maroon)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Format: Digital vs Physical
                Text(isEn ? 'Format / Catalog' : 'የመጽሐፍ ዓይነት', style: context.sans(12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isEn ? 'Digital Books' : 'ዲጂታል (PDF)'),
                      selected: tempKind == 'digital',
                      onSelected: (_) => setSheetState(() => tempKind = 'digital'),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Physical Books' : 'የታተሙ መጻሕፍት'),
                      selected: tempKind == 'physical',
                      onSelected: (_) => setSheetState(() => tempKind = 'physical'),
                    ),
                    ChoiceChip(
                      label: Text(l.all),
                      selected: tempKind == 'all',
                      onSelected: (_) => setSheetState(() => tempKind = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category Chips
                Text(l.itemCategory, style: context.sans(12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(l.all),
                      selected: tempCategoryId == null,
                      onSelected: (_) => setSheetState(() => tempCategoryId = null),
                    ),
                    for (final c in allCats)
                      ChoiceChip(
                        label: Text(Localizations.localeOf(context).languageCode == 'en' && c.nameEn != null ? c.nameEn! : c.name),
                        selected: tempCategoryId == c.id,
                        onSelected: (_) => setSheetState(() => tempCategoryId = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Language
                Text(isEn ? 'Language' : 'ቋንቋ', style: context.sans(12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(l.all),
                      selected: tempLang == null,
                      onSelected: (_) => setSheetState(() => tempLang = null),
                    ),
                    ChoiceChip(
                      label: const Text('አማርኛ'),
                      selected: tempLang == 'am',
                      onSelected: (_) => setSheetState(() => tempLang = 'am'),
                    ),
                    ChoiceChip(
                      label: const Text('ግዕዝ'),
                      selected: tempLang == 'gez',
                      onSelected: (_) => setSheetState(() => tempLang = 'gez'),
                    ),
                    ChoiceChip(
                      label: const Text('English'),
                      selected: tempLang == 'en',
                      onSelected: (_) => setSheetState(() => tempLang = 'en'),
                    ),
                    ChoiceChip(
                      label: const Text('Afaan Oromoo'),
                      selected: tempLang == 'om',
                      onSelected: (_) => setSheetState(() => tempLang = 'om'),
                    ),
                    ChoiceChip(
                      label: const Text('ትግርኛ'),
                      selected: tempLang == 'ti',
                      onSelected: (_) => setSheetState(() => tempLang = 'ti'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Availability & Favorites Switches
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isEn ? 'Available Copies Only' : 'የሚገኙ ቅጂዎች ብቻ'),
                  subtitle: Text(isEn ? 'Hide borrowed or checked-out physical copies' : 'የተዋሱ ወይም ያልተገኙ መጻሕፍትን ደብቅ', style: context.sans(11)),
                  value: tempAvailable,
                  onChanged: (v) => setSheetState(() => tempAvailable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.libFavorites),
                  value: tempFavorites,
                  onChanged: (v) => setSheetState(() => tempFavorites = v),
                ),
                const SizedBox(height: 16),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedCategoryId = tempCategoryId;
                        _kind = tempKind;
                        _language = tempLang;
                        _availableOnly = tempAvailable;
                        _favoritesOnly = tempFavorites;
                      });
                      _refreshActive();
                    },
                    child: Text(isEn ? 'Apply Filters' : 'ማጣሪያዎችን ተግብር'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Shortcut 1: Discover ----
  Widget _buildDiscoverView(BuildContext context, Palette p, AppLocalizations l, bool canCirculate) {
    return Column(
      children: [
        // Circulation desk banner if physical
        if (_kind == 'physical' && canCirculate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TrackTile(
              key: const ValueKey('library-circulation-banner-tile'),
              title: l.libCirculation,
              subtitle: l.libCheckout,
              leading: const ListThumb(icon: Icons.swap_horiz_rounded, active: true),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/edu/circulation'),
            ),
          ),

        // Sub-kind selector row: All, Digital books, Books to borrow, Mine
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: Text(l.isEn ? 'All Books' : 'ሁሉም መጻሕፍት'),
                selected: _kind == 'all',
                onSelected: (_) => setState(() {
                  _kind = 'all';
                  _discoverCtrl.refresh();
                }),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text(l.libDigital),
                selected: _kind == 'digital',
                onSelected: (_) => setState(() {
                  _kind = 'digital';
                  _discoverCtrl.refresh();
                }),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text(l.libPhysical),
                selected: _kind == 'physical',
                onSelected: (_) => setState(() {
                  _kind = 'physical';
                  _discoverCtrl.refresh();
                }),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text(l.libMine),
                selected: _kind == 'mine',
                onSelected: (_) => setState(() => _kind = 'mine'),
              ),
            ],
          ),
        ),

        // Category Browsing Bar (Categories visible, organized, and discoverable)
        if (_kind != 'mine')
          _buildCategoryBrowserBar(context, p, l),

        // Content
        Expanded(
          child: _kind == 'mine'
              ? _Mine(borrowingsRoute: widget.borrowingsRoute)
              : _buildDiscoverCatalog(context, p, l),
        ),
      ],
    );
  }

  Widget _buildCategoryBrowserBar(BuildContext context, Palette p, AppLocalizations l) {
    return FutureBuilder<List<LibraryCategory>>(
      future: _categories,
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        if (cats.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 38,
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // "All Categories" chip
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      Icons.auto_stories_rounded,
                      size: 15,
                      color: _selectedCategoryId == null ? Colors.white : AppColors.goldDark,
                    ),
                    label: Text(
                      l.isEn ? 'All Categories' : 'ሁሉም ምድቦች',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedCategoryId == null ? Colors.white : p.text,
                      ),
                    ),
                    selected: _selectedCategoryId == null,
                    selectedColor: const Color(0xFF650D20),
                    checkmarkColor: Colors.white,
                    backgroundColor: p.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _selectedCategoryId == null ? const Color(0xFF650D20) : p.border.withValues(alpha: 0.8),
                      ),
                    ),
                    onSelected: (_) => setState(() {
                      _selectedCategoryId = null;
                      _discoverCtrl.refresh();
                    }),
                  ),
                ),

                // Real categories chips
                ...cats.map((c) {
                  final isSelected = _selectedCategoryId == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: isSelected
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : p.text,
                            ),
                          ),
                          if (c.booksCount > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : p.muted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${c.booksCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : p.subtle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF650D20),
                      checkmarkColor: Colors.white,
                      backgroundColor: p.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF650D20) : p.border.withValues(alpha: 0.8),
                        ),
                      ),
                      onSelected: (_) => setState(() {
                        _selectedCategoryId = isSelected ? null : c.id;
                        _discoverCtrl.refresh();
                      }),
                    ),
                  );
                }),

                // "Unclassified" chip (ያልተመደበ)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: _selectedCategoryId == -1 ? Colors.white : p.muted,
                    ),
                    label: Text(
                      l.isEn ? 'Unclassified' : 'ያልተመደበ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedCategoryId == -1 ? FontWeight.bold : FontWeight.normal,
                        color: _selectedCategoryId == -1 ? Colors.white : p.muted,
                      ),
                    ),
                    selected: _selectedCategoryId == -1,
                    selectedColor: const Color(0xFF650D20),
                    checkmarkColor: Colors.white,
                    backgroundColor: p.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _selectedCategoryId == -1 ? const Color(0xFF650D20) : p.border.withValues(alpha: 0.8),
                      ),
                    ),
                    onSelected: (_) => setState(() {
                      _selectedCategoryId = _selectedCategoryId == -1 ? null : -1;
                      _discoverCtrl.refresh();
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverCatalog(BuildContext context, Palette p, AppLocalizations l) {
    return PagedListView<Book>(
      key: ValueKey('discover-$_kind-$_q-$_selectedCategoryId-$_favoritesOnly-$_isGridView'),
      controller: _discoverCtrl,
      emptyMessage: l.libNoBooks,
      emptyIcon: _kind == 'physical' ? Icons.menu_book_outlined : Icons.auto_stories_outlined,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Continue Reading Shelf (only when not searching and on digital/all)
          if (_q.isEmpty && _selectedCategoryId == null && !_favoritesOnly && (_kind == 'digital' || _kind == 'all'))
            _ContinueReadingShelf(
              domain: widget.domain,
              onSeeAll: () => setState(() => _activeShortcut = LibraryShortcut.reading),
              onChanged: _refreshActive,
            ),

          // Explore Section Title & Grid/List view toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.isEn ? 'Explore Books' : 'መጻሕፍትን ያስሱ',
                      style: context.serif(16, weight: FontWeight.w700),
                    ),
                    Text(
                      _kind == 'physical'
                          ? (l.isEn ? 'Physical library books' : 'የታተሙ የቤተ-መጻሕፍት መጻሕፍት')
                          : (l.isEn ? 'Curated reading & theology' : 'የስነ-መለኮትና የንባብ መጻሕፍት'),
                      style: context.sans(11, color: p.muted),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded, size: 20),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),
        ],
      ),
      fetch: (page) => ref.read(libraryRepositoryProvider).books(
            domain: widget.domain,
            kind: _kind == 'all' ? null : _kind,
            q: _q.isEmpty ? null : _q,
            categoryId: _selectedCategoryId,
            favoritesOnly: _favoritesOnly ? true : null,
            page: page,
          ),
      itemBuilder: (context, b, _) {
        return BookCard(book: b, onChanged: _refreshActive);
      },
    );
  }

  // ---- Shortcut 2: Favorites ----
  Widget _buildFavoritesView(BuildContext context, Palette p, AppLocalizations l) {
    return PagedListView<Book>(
      key: const ValueKey('favorites-shelf-list'),
      controller: _favoritesCtrl,
      emptyMessage: l.isEn ? 'No favorite books yet' : 'ምንም የተወደዱ መጻሕፍት የሉም',
      emptyIcon: Icons.favorite_border_rounded,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.libFavorites, style: context.serif(17, weight: FontWeight.w700)),
            Text(
              l.isEn ? 'Your saved books for quick access' : 'ለቀጣይ ንባብ ያስቀመጧቸው መጻሕፍት',
              style: context.sans(11.5, color: p.muted),
            ),
          ],
        ),
      ),
      fetch: (page) => ref.read(libraryRepositoryProvider).books(
            domain: widget.domain,
            favoritesOnly: true,
            page: page,
          ),
      itemBuilder: (context, b, _) => BookCard(book: b, onChanged: _refreshActive),
    );
  }

  // ---- Shortcut 3: Downloads ----
  Widget _buildDownloadsView(BuildContext context, Palette p, AppLocalizations l) {
    return PagedListView<Book>(
      key: const ValueKey('downloads-shelf-list'),
      controller: _downloadsCtrl,
      emptyMessage: l.isEn ? 'No downloaded books' : 'ምንም የወረዱ መጻሕፍት የሉም',
      emptyIcon: Icons.download_done_rounded,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.libDownloaded, style: context.serif(17, weight: FontWeight.w700)),
            Text(
              l.isEn ? 'Available offline anytime on your device' : 'ያለ ኢንተርኔት ከመሣሪያዎ ላይ የሚያነቧቸው',
              style: context.sans(11.5, color: p.muted),
            ),
          ],
        ),
      ),
      fetch: (page) async {
        final downloadedIds = await BookVault.listDownloadedIds();
        if (downloadedIds.isEmpty) {
          return const Paged<Book>(items: [], page: 1, pages: 1, total: 0);
        }
        final res = await ref.read(libraryRepositoryProvider).books(
              domain: widget.domain,
              kind: 'digital',
              page: page,
            );
        final downloaded = res.items.where((b) => downloadedIds.contains(b.id)).toList();
        return Paged<Book>(items: downloaded, page: res.page, pages: res.pages, total: downloaded.length);
      },
      itemBuilder: (context, b, _) => BookCard(book: b, onChanged: _refreshActive),
    );
  }

  // ---- Shortcut 4: Reading in Progress ----
  Widget _buildReadingView(BuildContext context, Palette p, AppLocalizations l) {
    return PagedListView<Book>(
      key: const ValueKey('reading-shelf-list'),
      controller: _readingCtrl,
      emptyMessage: l.isEn ? 'No books in progress' : 'ምንም የተጀመረ ንባብ የለም',
      emptyIcon: Icons.auto_stories_outlined,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.isEn ? 'Continue Reading' : 'በማንበብ ላይ', style: context.serif(17, weight: FontWeight.w700)),
            Text(
              l.isEn ? 'Books with saved reading history' : 'የንባብ ደረጃቸው የተቀመጠላቸው መጻሕፍት',
              style: context.sans(11.5, color: p.muted),
            ),
          ],
        ),
      ),
      fetch: (page) async {
        final res = await ref.read(libraryRepositoryProvider).books(
              domain: widget.domain,
              kind: 'digital',
              page: page,
            );
        final inProgress = res.items.where((b) => b.progress != null && (b.progress?.page ?? 0) > 0).toList();
        return Paged<Book>(items: inProgress, page: res.page, pages: res.pages, total: inProgress.length);
      },
      itemBuilder: (context, b, _) => BookCard(book: b, onChanged: _refreshActive),
    );
  }
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF650D20) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFFC6A044), width: 1.0)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 19,
                color: isSelected ? const Color(0xFFFFF8E9) : context.palette.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.sans(
                  10.5,
                  weight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFFFF8E9) : context.palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal shelf for books with saved reading progress
class _ContinueReadingShelf extends ConsumerStatefulWidget {
  const _ContinueReadingShelf({
    required this.domain,
    required this.onSeeAll,
    required this.onChanged,
  });

  final String domain;
  final VoidCallback onSeeAll;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ContinueReadingShelf> createState() => _ContinueReadingShelfState();
}

class _ContinueReadingShelfState extends ConsumerState<_ContinueReadingShelf> {
  late Future<List<Book>> _future = _load();

  Future<List<Book>> _load() async {
    try {
      final res = await ref.read(libraryRepositoryProvider).books(
            domain: widget.domain,
            kind: 'digital',
          );
      return res.items.where((b) => b.progress != null && (b.progress?.page ?? 0) > 0).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return FutureBuilder<List<Book>>(
      future: _future,
      builder: (context, snap) {
        final books = snap.data ?? [];
        if (books.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFC6A044).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: AppColors.goldDark, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l.isEn ? 'Continue Reading' : 'ንባብዎን ይቀጥሉ',
                        style: context.serif(15, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onSeeAll,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(
                      l.isEn ? 'See All' : 'ሁሉንም እይ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF650D20)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final b = books[i];
                    return _ContinueReadingCard(
                      book: b,
                      onChanged: () {
                        setState(() => _future = _load());
                        widget.onChanged();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.book, required this.onChanged});
  final Book book;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final prog = book.progress;

    return InkWell(
      onTap: () async {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => BookDetailScreen(book: book, onBookChanged: onChanged),
          ),
        );
        onChanged();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 135,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: BookCover.fromBook(
                book,
                width: 90,
                height: 110,
                borderRadius: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.serif(12, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              prog?.pageCount != null ? 'Page ${prog!.page} of ${prog.pageCount}' : 'Page ${prog?.page ?? 1}',
              style: context.sans(10, color: AppColors.goldDark, weight: FontWeight.w600),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF650D20),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () async {
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
                  );
                  onChanged();
                },
                child: Text(
                  l.isEn ? 'Continue' : 'ቀጥል',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upgraded Book Card with BookCover, opening BookDetailScreen on tap
class BookCard extends ConsumerStatefulWidget {
  const BookCard({super.key, required this.book, required this.onChanged});
  final Book book;
  final VoidCallback onChanged;
  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _downloaded = false;
  double? _progress;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.book.isDigital) {
      BookVault.has(widget.book.id).then((v) => mounted ? setState(() => _downloaded = v) : null);
    }
  }

  Future<void> _toggleFavorite() async {
    final favCtrl = ref.read(bookFavoritesProvider.notifier);
    final current = favCtrl.isFavorite(widget.book.id, widget.book.isFavorite);
    try {
      await favCtrl.toggle(widget.book.id, currentState: current);
      if (mounted) widget.onChanged();
    } catch (_) {}
  }

  void _openDetail() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          book: widget.book,
          onBookChanged: widget.onChanged,
        ),
      ),
    ).then((_) {
      if (mounted) {
        if (widget.book.isDigital) {
          BookVault.has(widget.book.id).then((v) => mounted ? setState(() => _downloaded = v) : null);
        }
        widget.onChanged();
      }
    });
  }

  Future<void> _download() async {
    final b = widget.book;
    if (b.fileUrl == null || b.fileUrl!.isEmpty) {
      if (mounted) {
        showSnack(context, context.l10n.isEn ? 'Book file is not available' : 'የመጽሐፉ ፋይል አልተገኘም');
      }
      return;
    }
    setState(() => _progress = 0);
    try {
      final pdf = await ref.read(libraryRepositoryProvider).downloadBook(b, onProgress: (r, t) {
        if (t > 0 && mounted) setState(() => _progress = r / t);
      });
      await BookVault.save(b.id, pdf);
      if (mounted) setState(() => _downloaded = true);
      await _open();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _open() async {
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: widget.book)),
    );
    final still = await BookVault.has(widget.book.id);
    if (mounted && still != _downloaded) setState(() => _downloaded = still);
    widget.onChanged();
  }

  Future<void> _remove() async {
    await BookVault.remove(widget.book.id);
    if (mounted) setState(() => _downloaded = false);
    widget.onChanged();
  }

  Future<void> _playNarration() async {
    final narrationCtrl = ref.read(narrationControllerProvider.notifier);
    await narrationCtrl.playBook(widget.book);
  }

  Future<void> _request() async {
    if (_isSubmitting) return;
    final l = context.l10n;
    final note = TextEditingController();
    DateTime? needed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.libRequestTitle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.book.title, style: context.sans(14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: l.libRequestNote)),
            const SizedBox(height: 10),
            DateTimeField(label: l.libNeededOn, value: needed, withTime: false, clearable: true, onChanged: (d) => setS(() => needed = d)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(key: const ValueKey('book-request-send'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.libRequest)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      final r = await runWithProgress(
        context,
        () => ref.read(libraryRepositoryProvider).request(
          widget.book.id,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          neededOn: needed == null ? null : Formatters.isoDate(needed!),
        ),
        success: l.libRequestSent,
      );
      if (r != null && mounted) widget.onChanged();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final b = widget.book;
    ref.watch(bookFavoritesProvider);
    final isFav = ref.read(bookFavoritesProvider.notifier).isFavorite(b.id, b.isFavorite);

    final Widget action;
    if (b.isDigital) {
      if (b.fileUrl == null || b.fileUrl!.isEmpty) {
        action = Pill(
          l.isEn ? 'File not uploaded' : 'ፋይል አልተጫነም',
          color: p.muted,
        );
      } else {
        action = _progress != null
            ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(value: _progress, strokeWidth: 3))
            : _downloaded
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: l.libDeleteDownload, icon: const Icon(Icons.delete_outline_rounded), onPressed: _remove),
                    FilledButton.tonal(key: ValueKey('book-open-${b.id}'), onPressed: _open, child: Text(l.libRead)),
                  ])
                : FilledButton.icon(
                    key: ValueKey('book-download-${b.id}'),
                    onPressed: _download,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(l.libDownload),
                  );
      }
    } else if (b.myRequest != null) {
      final status = b.myRequest!;
      if (status == 'issued' || status == 'borrowed' || status == 'active') {
        action = Pill(l.isEn ? 'Borrowed' : 'ተወስዷል', color: const Color(0xFF1F5F8B));
      } else {
        action = Pill(bookRequestStatusLabel(l, status), color: bookRequestStatusColor(status));
      }
    } else if (b.effectiveAvailable <= 0 && (b.available ?? 0) <= 0) {
      action = OutlinedButton(
        onPressed: null,
        child: Text(l.libNoneAvailable),
      );
    } else {
      action = FilledButton(
        key: ValueKey('book-request-${b.id}'),
        onPressed: _isSubmitting ? null : _request,
        child: _isSubmitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l.libRequest),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: AppCard(
        onTap: _openDetail,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Book Cover
            SizedBox(
              width: 76,
              height: 108,
              child: BookCover.fromBook(
                b,
                borderRadius: 8,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title, style: context.serif(15, weight: FontWeight.w700)),
                            if (b.author != null)
                              Text(b.author!, style: context.sans(12, color: AppColors.goldDark, weight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('book-fav-btn-${b.id}'),
                        tooltip: isFav ? l.libRemoveFromFavorites : l.libAddToFavorites,
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFF650D20) : p.subtle,
                          size: 22,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Category & Format Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (b.categoryName != null || b.category != null)
                              ? const Color(0xFF650D20).withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: (b.categoryName != null || b.category != null)
                                ? const Color(0xFF650D20).withValues(alpha: 0.25)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          b.categoryName ?? b.category ?? (l.isEn ? 'Unclassified' : 'ያልተመደበ'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: (b.categoryName != null || b.category != null)
                                ? const Color(0xFF650D20)
                                : p.muted,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.isDigital
                              ? Colors.blue.withValues(alpha: 0.09)
                              : Colors.teal.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              b.isDigital ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                              size: 11,
                              color: b.isDigital ? Colors.blue : Colors.teal,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              b.isDigital ? 'PDF' : (l.isEn ? 'Physical' : 'ህትመት'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: b.isDigital ? Colors.blue : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      b.code,
                      if (b.isDigital && b.fileSize != null) Formatters.fileSize(b.fileSize!),
                      if (b.isDigital && _downloaded) l.libDownloaded,
                      if (b.isDigital && isFav && !_downloaded) l.libDownloadToReadOffline,
                      if (!b.isDigital)
                        b.effectiveTotal > 0
                            ? l.libCopiesAvailable(b.effectiveAvailable, b.effectiveTotal)
                            : (b.available ?? 0) > 0
                                ? l.libAvailable('${b.available}')
                                : l.libNoneAvailable,
                    ].join(' · '),
                    style: context.sans(11, color: p.subtle),
                  ),
                  if (b.progress != null && b.progress!.page > 0) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.bookmark_added_rounded, size: 14, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        b.progress!.pageCount != null
                            ? l.libProgress(b.progress!.page, b.progress!.pageCount!)
                            : 'Page ${b.progress!.page}',
                        style: context.sans(11, color: AppColors.goldDark, weight: FontWeight.w600),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (b.hasNarration)
                        OutlinedButton.icon(
                          key: ValueKey('book-narration-btn-${b.id}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _playNarration,
                          icon: const Icon(Icons.headphones_rounded, size: 16, color: AppColors.gold),
                          label: Text(l.libListenNarration, style: const TextStyle(fontSize: 12)),
                        )
                      else
                        const SizedBox.shrink(),
                      action,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MineTab { requests, continueReading, downloaded, favorites }

class _Mine extends ConsumerStatefulWidget {
  const _Mine({required this.borrowingsRoute});
  final String borrowingsRoute;
  @override
  ConsumerState<_Mine> createState() => _MineState();
}

class _MineState extends ConsumerState<_Mine> {
  _MineTab _activeTab = _MineTab.requests;
  final _ctrl = PagedListController<BookRequest>();
  final _bookCtrl = PagedListController<Book>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);

    final chipRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            key: const ValueKey('mine-chip-requests'),
            label: Text(l.isEn ? 'Borrowings & Requests' : 'ውሰትና ጥያቄዎች'),
            selected: _activeTab == _MineTab.requests,
            onSelected: (_) => setState(() => _activeTab = _MineTab.requests),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const ValueKey('mine-chip-continue'),
            avatar: const Icon(Icons.bookmark_added_rounded, size: 16, color: AppColors.goldDark),
            label: Text(l.isEn ? 'Continue Reading' : 'ንባብ ይቀጥሉ'),
            selected: _activeTab == _MineTab.continueReading,
            onSelected: (_) => setState(() {
              _activeTab = _MineTab.continueReading;
              _bookCtrl.refresh();
            }),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const ValueKey('mine-chip-downloaded'),
            avatar: const Icon(Icons.download_done_rounded, size: 16, color: AppColors.success),
            label: Text(l.libDownloaded),
            selected: _activeTab == _MineTab.downloaded,
            onSelected: (_) => setState(() {
              _activeTab = _MineTab.downloaded;
              _bookCtrl.refresh();
            }),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const ValueKey('mine-chip-favorites'),
            avatar: const Icon(Icons.favorite_rounded, size: 16, color: AppColors.goldDark),
            label: Text(l.libFavorites),
            selected: _activeTab == _MineTab.favorites,
            onSelected: (_) => setState(() {
              _activeTab = _MineTab.favorites;
              _bookCtrl.refresh();
            }),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chipRow,
        Expanded(
          child: switch (_activeTab) {
            _MineTab.requests => PagedListView<BookRequest>(
                controller: _ctrl,
                emptyMessage: l.libNoRequests,
                emptyIcon: Icons.outbox_outlined,
                header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TrackTile(
                    key: const ValueKey('library-my-borrowings'),
                    title: l.myBorrowings,
                    subtitle: l.eduBorrowingsSub,
                    leading: const ListThumb(icon: Icons.menu_book_rounded, active: true),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(widget.borrowingsRoute),
                  ),
                  SectionHeader(title: l.libMyRequests),
                ]),
                fetch: (page) => ref.read(libraryRepositoryProvider).myRequests(page: page),
                itemBuilder: (context, r, _) => TrackTile(
                  title: r.bookTitle,
                  subtitle: [bookRequestStatusLabel(l, r.status), if (r.createdAt != null) f.date(r.createdAt), ?r.reviewNote].join(' · '),
                  leading: ListThumb(icon: Icons.menu_book_outlined, imageUrl: r.bookCoverUrl),
                  trailing: r.isOpen
                      ? IconButton(
                          tooltip: l.libCancelRequest,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () async {
                            if (!await showConfirm(context, '${l.libCancelRequest}?') || !context.mounted) return;
                            final x = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).cancel(r.id));
                            if (x != null) await _ctrl.refresh();
                          },
                        )
                      : Icon(Icons.circle, size: 10, color: bookRequestStatusColor(r.status)),
                  onTap: r.borrowingId != null ? () => context.push('${widget.borrowingsRoute}/${r.borrowingId}') : null,
                ),
              ),
            _MineTab.continueReading => PagedListView<Book>(
                key: const ValueKey('mine-continue-reading-list'),
                controller: _bookCtrl,
                emptyMessage: l.isEn ? 'No books in progress' : 'ምንም የተጀመረ ንባብ የለም',
                emptyIcon: Icons.auto_stories_outlined,
                fetch: (page) async {
                  final res = await ref.read(libraryRepositoryProvider).books(
                        domain: 'timhirt',
                        kind: 'digital',
                        page: page,
                      );
                  final inProgress = res.items.where((b) => b.progress != null && (b.progress?.page ?? 0) > 0).toList();
                  return Paged<Book>(items: inProgress, page: res.page, pages: res.pages, total: inProgress.length);
                },
                itemBuilder: (context, b, _) => BookCard(book: b, onChanged: () => _bookCtrl.refresh()),
              ),
            _MineTab.downloaded => PagedListView<Book>(
                key: const ValueKey('mine-downloaded-list'),
                controller: _bookCtrl,
                emptyMessage: l.isEn ? 'No downloaded books' : 'ምንም የወረዱ መጻሕፍት የሉም',
                emptyIcon: Icons.download_done_rounded,
                fetch: (page) async {
                  final downloadedIds = await BookVault.listDownloadedIds();
                  if (downloadedIds.isEmpty) {
                    return const Paged<Book>(items: [], page: 1, pages: 1, total: 0);
                  }
                  final res = await ref.read(libraryRepositoryProvider).books(
                        domain: 'timhirt',
                        kind: 'digital',
                        page: page,
                      );
                  final downloaded = res.items.where((b) => downloadedIds.contains(b.id)).toList();
                  return Paged<Book>(items: downloaded, page: res.page, pages: res.pages, total: downloaded.length);
                },
                itemBuilder: (context, b, _) => BookCard(book: b, onChanged: () => _bookCtrl.refresh()),
              ),
            _MineTab.favorites => PagedListView<Book>(
                key: const ValueKey('mine-favorites-list'),
                controller: _bookCtrl,
                emptyMessage: l.isEn ? 'No favorite books yet' : 'ምንም ተወዳጅ መጻሕፍት የሉም',
                emptyIcon: Icons.favorite_border_rounded,
                fetch: (page) => ref.read(libraryRepositoryProvider).books(
                      domain: 'timhirt',
                      favoritesOnly: true,
                      page: page,
                    ),
                itemBuilder: (context, b, _) => BookCard(book: b, onChanged: () => _bookCtrl.refresh()),
              ),
          },
        ),
      ],
    );
  }
}

