import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/library.dart';

/// Premium Ethiopian Orthodox Church editorial book cover with:
/// - Real cover image loaded via [CachedNetworkImage] with fade-in and subtle 3D book spine
/// - High-fidelity authentic liturgical fallback when [coverUrl] is null or fails:
///   deep burgundy (#650D20) leather gradient, double gold filigree frame (#C6A044),
///   gold Orthodox church cross emblem, serif title typography in warm cream, and gold author/category caption
/// - Spine crease shadow on left edge for physical book realism
/// - Subtle elevation drop shadow
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.coverUrl,
    this.author,
    this.category,
    this.isDigital = true,
    this.width,
    this.height,
    this.aspectRatio = 1 / 1.45,
    this.borderRadius = 8.0,
    this.showBadge = true,
    this.hasNarration = false,
    this.progressFraction,
    this.heroTag,
  });

  factory BookCover.fromBook(
    Book book, {
    Key? key,
    double? width,
    double? height,
    double aspectRatio = 1 / 1.45,
    double borderRadius = 8.0,
    bool showBadge = true,
    String? heroTag,
  }) {
    double? progress;
    if (book.progress != null && book.progress!.page > 0) {
      final total = book.progress!.pageCount;
      if (total != null && total > 0) {
        progress = (book.progress!.page / total).clamp(0.0, 1.0);
      }
    }
    return BookCover(
      key: key,
      title: book.title,
      coverUrl: book.coverUrl,
      author: book.author,
      category: book.categoryName ?? book.category,
      isDigital: book.isDigital,
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      borderRadius: borderRadius,
      showBadge: showBadge,
      hasNarration: book.hasNarration,
      progressFraction: progress,
      heroTag: heroTag,
    );
  }

  final String title;
  final String? coverUrl;
  final String? author;
  final String? category;
  final bool isDigital;
  final double? width;
  final double? height;
  final double aspectRatio;
  final double borderRadius;
  final bool showBadge;
  final bool hasNarration;
  final double? progressFraction;
  final String? heroTag;

  static const Color burgundyDeep = Color(0xFF650D20);
  static const Color burgundyDark = Color(0xFF4A0816);
  static const Color burgundyShadow = Color(0xFF2E050D);
  static const Color goldAccent = Color(0xFFC6A044);
  static const Color goldLight = Color(0xFFDFBF6B);
  static const Color warmCream = Color(0xFFFFF8E9);

  @override
  Widget build(BuildContext context) {
    Widget cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
          BoxShadow(
            color: burgundyDeep.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background / Image layer
              if (coverUrl != null && coverUrl!.trim().isNotEmpty)
                CachedNetworkImage(
                  imageUrl: coverUrl!.trim(),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 250),
                  placeholder: (_, _) => _LiturgicalFallbackCover(
                    title: title,
                    author: author,
                    category: category,
                    isDigital: isDigital,
                  ),
                  errorWidget: (_, _, _) => _LiturgicalFallbackCover(
                    title: title,
                    author: author,
                    category: category,
                    isDigital: isDigital,
                  ),
                )
              else
                _LiturgicalFallbackCover(
                  title: title,
                  author: author,
                  category: category,
                  isDigital: isDigital,
                ),

              // 2. Realistic book spine shadow & crease on left edge
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Subtle book spine highlight line
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                width: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),

              // 4. Subtle top sheen gradient
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.22),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Badges (Narration or Digital / Physical indicator)
              if (showBadge) ...[
                if (hasNarration)
                  Positioned(
                    top: 6,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: goldAccent.withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones_rounded, size: 10, color: goldLight),
                          SizedBox(width: 3),
                          Text(
                            'AUDIO',
                            style: TextStyle(
                              color: goldLight,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              // 6. Reading progress bar overlay if book is in progress
              if (progressFraction != null && progressFraction! > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 4,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressFraction!.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [goldAccent, goldLight],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(tag: heroTag!, child: cover);
    }
    return cover;
  }
}

/// Authentic Ethiopian Orthodox Church liturgical book cover fallback.
class _LiturgicalFallbackCover extends StatelessWidget {
  const _LiturgicalFallbackCover({
    required this.title,
    this.author,
    this.category,
    this.isDigital = true,
  });

  final String title;
  final String? author;
  final String? category;
  final bool isDigital;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BookCover.burgundyDeep,
            BookCover.burgundyDark,
            BookCover.burgundyShadow,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle Ethiopian background texture/cross motif
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'assets/images/education_pattern.png',
                repeat: ImageRepeat.repeat,
                scale: 3.0,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Double Gold Filigree Border
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: BookCover.goldAccent.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: BookCover.goldAccent.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Corner ornaments
                      Positioned(
                        top: 1,
                        left: 1,
                        child: Text('✦', style: TextStyle(color: BookCover.goldAccent.withValues(alpha: 0.6), fontSize: 7)),
                      ),
                      Positioned(
                        top: 1,
                        right: 1,
                        child: Text('✦', style: TextStyle(color: BookCover.goldAccent.withValues(alpha: 0.6), fontSize: 7)),
                      ),
                      Positioned(
                        bottom: 1,
                        left: 1,
                        child: Text('✦', style: TextStyle(color: BookCover.goldAccent.withValues(alpha: 0.6), fontSize: 7)),
                      ),
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Text('✦', style: TextStyle(color: BookCover.goldAccent.withValues(alpha: 0.6), fontSize: 7)),
                      ),

                      // Cover Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Top: Gold Orthodox Cross Motif
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.church_rounded,
                                  color: BookCover.goldAccent.withValues(alpha: 0.9),
                                  size: 18,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 24,
                                  height: 1,
                                  color: BookCover.goldAccent.withValues(alpha: 0.5),
                                ),
                              ],
                            ),

                            // Center: Book Title in Ge'ez/Amharic serif typography
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    title,
                                    maxLines: 4,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.serif(
                                      12,
                                      weight: FontWeight.w700,
                                      color: BookCover.warmCream,
                                    ).copyWith(
                                      height: 1.25,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Bottom: Author or Category in gold caption
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 1,
                                  color: BookCover.goldAccent.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (author != null && author!.isNotEmpty)
                                      ? author!
                                      : (category != null && category!.isNotEmpty)
                                          ? category!
                                          : (isDigital ? 'ዲጂታል መጽሐፍ' : 'የታተመ መጽሐፍ'),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.sans(
                                    8.5,
                                    weight: FontWeight.w600,
                                    color: BookCover.goldLight.withValues(alpha: 0.9),
                                  ).copyWith(
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
