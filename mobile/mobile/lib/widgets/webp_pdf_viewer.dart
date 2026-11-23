import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Representation of a single pre-rendered WebP document page.
class WebpDocumentPage {
  const WebpDocumentPage({
    required this.id,
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.url,
  });

  factory WebpDocumentPage.fromJson(Map<String, dynamic> json) {
    return WebpDocumentPage(
      id: json['id'] as int? ?? 0,
      pageNumber: json['page_number'] as int? ?? 1,
      width: json['width'] as int? ?? 1200,
      height: json['height'] as int? ?? 1600,
      fileSize: json['file_size'] as int? ?? 0,
      url: json['url'] as String? ?? '',
    );
  }

  final int id;
  final int pageNumber;
  final int width;
  final int height;
  final int fileSize;
  final String url;

  double get aspectRatio => (width > 0 && height > 0) ? width / height : (1 / 1.414);
}

/// Dedicated, high-performance in-app PDF document viewer using server-rendered WebP pages.
/// Displays multi-page PDF documents smoothly with pinch-to-zoom, page navigation,
/// scrubber slider, fit-width/fit-page toggles, and seamless fallback to pdfrx.
class WebpPdfViewer extends ConsumerStatefulWidget {
  const WebpPdfViewer({
    super.key,
    required this.title,
    this.documentType,
    this.documentId,
    this.pdfUrl,
    this.pdfBytes,
    this.initialPage = 1,
    this.onPageChanged,
  });

  final String title;
  final String? documentType; // 'item', 'magazine', etc.
  final int? documentId;
  final String? pdfUrl;
  final Uint8List? pdfBytes;
  final int initialPage;
  final void Function(int currentPage, int totalPages)? onPageChanged;

  @override
  ConsumerState<WebpPdfViewer> createState() => _WebpPdfViewerState();
}

class _WebpPdfViewerState extends ConsumerState<WebpPdfViewer> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final TransformationController _transformController = TransformationController();

  List<WebpDocumentPage> _pages = [];
  bool _isLoading = true;
  bool _useFallbackPdfrx = false;
  String? _errorMessage;

  int _currentPage = 1;
  bool _isContinuous = true; // true = continuous vertical scroll, false = page flip
  bool _isFullscreen = false;
  bool _showThumbnails = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadPages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    if (widget.documentType == null || widget.documentId == null) {
      if (widget.pdfBytes != null || widget.pdfUrl != null) {
        setState(() {
          _useFallbackPdfrx = true;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get<Map<String, dynamic>>(
        '/pdf/document/${widget.documentType}/${widget.documentId}/pages',
        parse: (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      final rawPages = (res['pages'] as List<dynamic>?) ?? [];
      final pages = rawPages
          .map((p) => WebpDocumentPage.fromJson(p as Map<String, dynamic>))
          .toList();

      if (pages.isEmpty) {
        setState(() {
          _useFallbackPdfrx = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _pages = pages;
        _isLoading = false;
        _useFallbackPdfrx = false;
      });

      if (widget.initialPage > 1 && widget.initialPage <= pages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToPage(widget.initialPage, animate: false);
        });
      }
    } catch (e) {
      if (widget.pdfBytes != null || widget.pdfUrl != null) {
        setState(() {
          _useFallbackPdfrx = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_pages.isEmpty || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final curScroll = _scrollController.offset.clamp(0.0, maxScroll);
    final ratio = maxScroll > 0 ? (curScroll / maxScroll) : 0.0;
    final pageIndex = (ratio * (_pages.length - 1)).round() + 1;
    final newPage = pageIndex.clamp(1, _pages.length);
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      widget.onPageChanged?.call(_currentPage, _pages.length);
    }
  }

  void _jumpToPage(int page, {bool animate = true}) {
    if (page < 1 || page > _pages.length) return;
    setState(() => _currentPage = page);
    widget.onPageChanged?.call(_currentPage, _pages.length);

    if (_isContinuous && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = (_pages.length > 1) ? ((page - 1) / (_pages.length - 1)) * maxScroll : 0.0;
      if (animate) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }
    } else if (!_isContinuous && _pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(page - 1);
      }
    }
  }

  Future<void> _showJumpDialog() async {
    final l = context.l10n;
    final ctrl = TextEditingController(text: '$_currentPage');

    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: Text(l.isEn ? 'Jump to Page' : 'ወደ ገጽ ይሂዱ', style: context.serif(18, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.isEn ? 'Enter page number (1 – ${_pages.length}):' : 'የገጽ ቁጥር ያስገቡ (1 – ${_pages.length})፡',
              style: context.sans(13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '1 - ${_pages.length}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.find_in_page_outlined, color: AppColors.maroon),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel, style: const TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, val);
            },
            child: Text(l.ok),
          ),
        ],
      ),
    );

    if (target != null && target >= 1 && target <= _pages.length) {
      _jumpToPage(target);
    }
  }

  void _zoomTo(double targetScale) {
    targetScale = targetScale.clamp(1.0, 4.5);
    final matrix = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
    setState(() {
      _transformController.value = matrix;
      _currentScale = targetScale;
    });
  }

  void _zoomIn() {
    _zoomTo((_currentScale * 1.25).clamp(1.0, 4.5));
  }

  void _zoomOut() {
    _zoomTo((_currentScale / 1.25).clamp(1.0, 4.5));
  }

  void _resetZoom() {
    _zoomTo(1.0);
  }

  void _fitWidth() {
    _zoomTo(1.6);
  }

  void _handleDoubleTap() {
    if (_currentScale > 1.2) {
      _resetZoom();
    } else {
      _zoomTo(2.4);
    }
  }

  Map<String, String> _buildAuthHeaders() {
    final token = ref.read(secureStoreProvider).accessToken;
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (_useFallbackPdfrx) {
      return _buildPdfrxFallback();
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: _isFullscreen ? null : AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.goldLight),
              const SizedBox(height: 20),
              Text(
                l.isEn ? 'Optimizing & loading document pages...' : 'ገጾችን በማዘጋጀት እና በመጫን ላይ...',
                style: context.sans(14, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 52),
                const SizedBox(height: 16),
                Text(
                  l.isEn ? 'Failed to load document' : 'ሰነዱን መክፈት አልተቻለም',
                  style: context.serif(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: context.sans(13, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadPages,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.isEn ? 'Retry' : 'እንደገና ሞክር'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: _isFullscreen ? null : _buildAppBar(l),
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 4.5,
              onInteractionUpdate: (details) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                if ((scale - _currentScale).abs() > 0.05) {
                  setState(() => _currentScale = scale);
                }
              },
              onInteractionEnd: (_) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                setState(() => _currentScale = scale);
              },
              child: _isContinuous ? _buildContinuousList() : _buildPageView(),
            ),
          ),
          Positioned(
            top: _isFullscreen ? 36 : 14,
            left: 14,
            child: _buildZoomToolbar(),
          ),
          Positioned(
            top: _isFullscreen ? 36 : 14,
            right: 14,
            child: _buildPageBadge(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(l),
          ),
          if (_showThumbnails) _buildThumbnailStrip(),
        ],
      ),
    );
  }

  Widget _buildZoomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Zoom Out (-)',
            onPressed: _currentScale > 1.0 ? _zoomOut : null,
          ),
          InkWell(
            onTap: _resetZoom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '${(_currentScale * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Zoom In (+)',
            onPressed: _currentScale < 4.5 ? _zoomIn : null,
          ),
          Container(
            height: 14,
            width: 1,
            color: Colors.white24,
            margin: const EdgeInsets.symmetric(horizontal: 3),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Reset (100%)',
            onPressed: _resetZoom,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Fit Width',
            onPressed: _fitWidth,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l) {
    return AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: AppColors.maroon,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        IconButton(
          tooltip: l.isEn ? 'Jump to Page' : 'ወደ ገጽ ይሂዱ',
          icon: const Icon(Icons.find_in_page_outlined),
          onPressed: _showJumpDialog,
        ),
        IconButton(
          tooltip: _isContinuous
              ? (l.isEn ? 'Page Flip Mode' : 'ገጽ በገጽ ገልብጥ')
              : (l.isEn ? 'Continuous Scroll Mode' : 'ቀጣይ ማሸብለል'),
          icon: Icon(_isContinuous ? Icons.view_carousel_outlined : Icons.view_day_outlined),
          onPressed: () {
            setState(() {
              _isContinuous = !_isContinuous;
              _transformController.value = Matrix4.identity();
              _currentScale = 1.0;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _jumpToPage(_currentPage, animate: false);
            });
          },
        ),
        IconButton(
          tooltip: l.isEn ? 'Thumbnails' : 'አነስተኛ ገጾች',
          icon: Icon(_showThumbnails ? Icons.grid_view_rounded : Icons.grid_view_outlined),
          onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
        ),
        IconButton(
          tooltip: l.isEn ? 'Full Screen' : 'ሙሉ ገጽ',
          icon: const Icon(Icons.fullscreen_rounded),
          onPressed: () => setState(() => _isFullscreen = true),
        ),
      ],
    );
  }

  Widget _buildContinuousList() {
    return ListView.builder(
      controller: _scrollController,
      physics: _currentScale > 1.05 ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 12,
        bottom: 80,
        left: MediaQuery.of(context).size.width > 600 ? 40 : 8,
        right: MediaQuery.of(context).size.width > 600 ? 40 : 8,
      ),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        final page = _pages[index];
        return _buildPageCard(page);
      },
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: _currentScale > 1.05 ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      itemCount: _pages.length,
      onPageChanged: (idx) {
        setState(() => _currentPage = idx + 1);
        widget.onPageChanged?.call(_currentPage, _pages.length);
      },
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: _buildPageCard(page),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageCard(WebpDocumentPage page) {
    final headers = _buildAuthHeaders();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AspectRatio(
          aspectRatio: page.aspectRatio,
          child: CachedNetworkImage(
            imageUrl: page.url,
            httpHeaders: headers,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (context, url) => Container(
              color: const Color(0xFF2C2C2C),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldLight),
                    ),
                    const SizedBox(height: 8),
                    Text('ገጽ ${page.pageNumber}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF2C2C2C),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 36),
                    const SizedBox(height: 6),
                    Text('ገጽ ${page.pageNumber} አልተጫነም', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        '$_currentPage / ${_pages.length}',
        style: const TextStyle(
          color: AppColors.goldLight,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l) {
    if (_isFullscreen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.small(
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          onPressed: () => setState(() => _isFullscreen = false),
          child: const Icon(Icons.fullscreen_exit_rounded),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
              onPressed: _currentPage > 1 ? () => _jumpToPage(_currentPage - 1) : null,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.gold,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppColors.goldLight,
                  overlayColor: AppColors.gold.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _currentPage.toDouble().clamp(1.0, _pages.length.toDouble()),
                  min: 1.0,
                  max: _pages.length.toDouble(),
                  divisions: _pages.length > 1 ? _pages.length - 1 : 1,
                  onChanged: (val) {
                    _jumpToPage(val.round());
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              onPressed: _currentPage < _pages.length ? () => _jumpToPage(_currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _isFullscreen ? 0 : 54,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F).withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            final page = _pages[index];
            final isSelected = page.pageNumber == _currentPage;

            return GestureDetector(
              onTap: () {
                _jumpToPage(page.pageNumber);
                setState(() => _showThumbnails = false);
              },
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? AppColors.goldLight : Colors.white24,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: page.url,
                        httpHeaders: _buildAuthHeaders(),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: Colors.white12),
                        errorWidget: (_, _, _) => Container(color: Colors.white12),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          color: Colors.black.withValues(alpha: 0.85),
                          child: Text(
                            '${page.pageNumber}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfrxFallback() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
      ),
      body: widget.pdfBytes != null
          ? PdfViewer.data(widget.pdfBytes!, sourceName: widget.title, params: const PdfViewerParams())
          : (widget.pdfUrl != null
              ? PdfViewer.uri(Uri.parse(widget.pdfUrl!), params: const PdfViewerParams())
              : const Center(child: Text('No PDF available'))),
    );
  }
}
