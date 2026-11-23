import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/webp_pdf_viewer.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import 'edu_widgets.dart';

/// The latest published issue of ሰሌዳ መጽሔት for the Education Home banner.
final latestMagazineProvider = FutureProvider.autoDispose<Json?>((ref) async {
  try {
    final m = await ref.watch(eduRepositoryProvider).latestMagazine();
    if (m != null && m['issue_number'] != null) return m;
    return null;
  } catch (_) {
    return null;
  }
});

/// All published issues of ሰሌዳ መጽሔት.
final magazinesListProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(eduRepositoryProvider).magazines());

/// One magazine issue detail with linked quizzes.
final magazineDetailProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(eduRepositoryProvider).magazineDetail(id));

String _resolveMediaUrl(String? url, String baseUrl) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final baseUri = Uri.parse(baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
  final path = url.startsWith('/') ? url : '/$url';
  return '$origin$path';
}

// =============================================================================
// Featured Banner on Education Home
// =============================================================================
class SeledaMagazineBanner extends ConsumerWidget {
  const SeledaMagazineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLatest = ref.watch(latestMagazineProvider);

    return asyncLatest.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (m) {
        final isEn = Localizations.localeOf(context).languageCode != 'am';
        if (m == null || m['issue_number'] == null) {
          return Container(
            margin: const EdgeInsets.only(top: 14, bottom: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A101D), Color(0xFF28070E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/edu/magazines'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Seleda Magazine' : 'ሰሌዳ መጽሔት',
                              style: context.serif(16, weight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn ? 'Browse issues, articles & quizzes' : 'እትሞችን፣ ጽሑፎችንና ተዛማጅ ጥያቄዎችን ይመልከቱ',
                              style: context.sans(12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.goldLight, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final title = isEn ? (asStr(m['title_en']) ?? asStr(m['title']) ?? '') : (asStr(m['title']) ?? asStr(m['title_en']) ?? '');
        final issueNumber = asStr(m['issue_number']) ?? '';
        final period = asStr(m['period_info']) ?? '';
        final description = asStr(m['description']) ?? '';
        final pdfUrl = asStr(m['pdf_url']);
        final quizzes = asJsonList(m['quizzes']);
        final quizCount = quizzes.length;

        final baseUrl = ref.watch(eduRepositoryProvider).api.dio.options.baseUrl;
        final coverUrl = _resolveMediaUrl(asStr(m['cover_url']), baseUrl);

        return Container(
          margin: const EdgeInsets.only(top: 14, bottom: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A101D), Color(0xFF28070E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/edu/magazine/${m['id']}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          !isEn ? 'ሰሌዳ መጽሔት' : 'SELEDA MAGAZINE',
                          style: context.sans(11, color: AppColors.goldLight, weight: FontWeight.w700),
                        ),
                      ]),
                    ),
                    const Spacer(),
                    if (issueNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          !isEn ? 'እትም $issueNumber' : 'Issue $issueNumber',
                          style: context.sans(11.5, color: Colors.white70, weight: FontWeight.w600),
                        ),
                      ),
                    const Spacer(),
                    InkWell(
                      onTap: () => context.push('/edu/magazines'),
                      child: Row(
                        children: [
                          Text(
                            !isEn ? 'ሁሉም እትሞች' : 'All Issues',
                            style: context.sans(11.5, color: AppColors.goldLight, weight: FontWeight.w600),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.goldLight, size: 16),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          coverUrl,
                          width: 72,
                          height: 98,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _coverFallback(context),
                        ),
                      )
                    else
                      _coverFallback(context),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.serif(17, color: Colors.white, weight: FontWeight.w600),
                        ),
                        if (period.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(period, style: context.sans(12.5, color: AppColors.goldLight)),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.sans(12, color: Colors.white70, height: 1.35),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    if (pdfUrl != null && pdfUrl.isNotEmpty)
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF28070E),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EduMagazinePdfReaderScreen(
                                title: title,
                                pdfUrl: _resolveMediaUrl(pdfUrl, baseUrl),
                                magazineId: asInt(m['id']),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.auto_stories_rounded, size: 18),
                          label: Text(
                            !isEn ? 'መጽሔቱን አንብብ' : 'Read Issue',
                            style: context.sans(13, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (quizCount > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.goldLight, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            if (quizCount == 1) {
                              context.push('/edu/quiz/${quizzes.first['id']}');
                            } else {
                              context.push('/edu/magazine/${m['id']}');
                            }
                          },
                          icon: const Icon(Icons.quiz_outlined, size: 18, color: AppColors.goldLight),
                          label: Text(
                            !isEn ? 'ጥያቄዎችን መልስ' : 'Take Quiz',
                            style: context.sans(13, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _coverFallback(BuildContext context) {
    return Container(
      width: 72,
      height: 98,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 36),
      ),
    );
  }
}

// =============================================================================
// All Issues Archive Screen
// =============================================================================
class EduMagazinesListScreen extends ConsumerWidget {
  const EduMagazinesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final baseUrl = ref.watch(apiClientProvider).dio.options.baseUrl;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(!isEn ? 'ሰሌዳ መጽሔት' : 'Seleda Magazine'),
      ),
      body: AsyncView(
        value: ref.watch(magazinesListProvider),
        onRetry: () => ref.invalidate(magazinesListProvider),
        data: (issues) {
          if (issues.isEmpty) {
            return Center(
              child: EduEmptyCard(
                icon: Icons.menu_book_rounded,
                message: !isEn ? 'እስካሁን የታተመ የመጽሔት እትም የለም' : 'No published magazine issues available yet',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: issues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = issues[i];
              final title = isEn ? (asStr(m['title_en']) ?? asStr(m['title']) ?? '') : (asStr(m['title']) ?? asStr(m['title_en']) ?? '');
              final issueNumber = asStr(m['issue_number']) ?? '';
              final period = asStr(m['period_info']) ?? '';
              final coverUrl = _resolveMediaUrl(asStr(m['cover_url']), baseUrl);
              final pdfUrl = asStr(m['pdf_url']) ?? '';

              return AppCard(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.push('/edu/magazine/${m['id']}'),
                  child: Row(children: [
                    if (coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          coverUrl,
                          width: 56,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _miniCoverFallback(),
                        ),
                      )
                    else
                      _miniCoverFallback(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (issueNumber.isNotEmpty)
                          Text(
                            !isEn ? 'እትም $issueNumber' : 'Issue $issueNumber',
                            style: context.sans(11.5, color: AppColors.maroon, weight: FontWeight.w700),
                          ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.serif(15, weight: FontWeight.w600),
                        ),
                        if (period.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(period, style: context.sans(12, color: context.palette.muted)),
                          ),
                      ]),
                    ),
                    if (pdfUrl.isNotEmpty)
                      IconButton(
                        tooltip: !isEn ? 'አንብብ' : 'Read Issue',
                        icon: const Icon(Icons.auto_stories_rounded, color: AppColors.maroon, size: 22),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EduMagazinePdfReaderScreen(
                              title: title,
                              pdfUrl: _resolveMediaUrl(pdfUrl, baseUrl),
                              magazineId: asInt(m['id']),
                            ),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniCoverFallback() {
    return Container(
      width: 56,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.maroon.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.maroon, size: 28),
      ),
    );
  }
}

// =============================================================================
// Magazine Issue Detail Screen (with PDF & Linked Quizzes)
// =============================================================================
class EduMagazineDetailScreen extends ConsumerWidget {
  const EduMagazineDetailScreen({super.key, required this.magazineId});
  final int magazineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final baseUrl = ref.watch(apiClientProvider).dio.options.baseUrl;
    final magAsync = ref.watch(magazineDetailProvider(magazineId));
    final mVal = magAsync.asData?.value;
    final issueNum = asStr(mVal?['issue_number']) ?? '';

    return PatternScaffold(
      appBar: AppBar(
        title: Text(issueNum.isNotEmpty ? (!isEn ? 'እትም $issueNum' : 'Issue $issueNum') : (!isEn ? 'ሰሌዳ መጽሔት' : 'Seleda Magazine')),
      ),
      body: AsyncView(
        value: magAsync,
        onRetry: () => ref.invalidate(magazineDetailProvider(magazineId)),
        data: (m) {
          final title = isEn ? (asStr(m['title_en']) ?? asStr(m['title']) ?? '') : (asStr(m['title']) ?? asStr(m['title_en']) ?? '');
          final issueNumber = asStr(m['issue_number']) ?? '';
          final period = asStr(m['period_info']) ?? '';
          final description = asStr(m['description']) ?? '';
          final pdfUrl = asStr(m['pdf_url']);
          final quizzes = asJsonList(m['quizzes']);
          final coverUrl = _resolveMediaUrl(asStr(m['cover_url']), baseUrl);

          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                MaroonCard(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          coverUrl,
                          width: 84,
                          height: 114,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _detailCoverFallback(),
                        ),
                      )
                    else
                      _detailCoverFallback(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (issueNumber.isNotEmpty)
                          Text(
                            !isEn ? 'ሰሌዳ መጽሔት · እትም $issueNumber' : 'Seleda Magazine · Issue $issueNumber',
                            style: context.sans(12, color: AppColors.goldLight, weight: FontWeight.w700),
                          ),
                        const SizedBox(height: 4),
                        Text(title, style: context.serif(18, color: Colors.white, weight: FontWeight.w600)),
                        if (period.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(period, style: context.sans(13, color: Colors.white70)),
                        ],
                      ]),
                    ),
                  ]),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SectionHeader(title: !isEn ? 'ስለ እትሙ' : 'About this Issue'),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(description, style: context.sans(13.5, height: 1.6)),
                  ),
                ],
                const SizedBox(height: 14),
                if (pdfUrl != null && pdfUrl.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EduMagazinePdfReaderScreen(
                          title: title,
                          pdfUrl: _resolveMediaUrl(pdfUrl, baseUrl),
                          magazineId: asInt(m['id']),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: Text(!isEn ? 'መጽሔቱን አንብብ (PDF)' : 'Read Magazine (PDF)', style: context.serif(15, weight: FontWeight.w600)),
                  ),
                const SizedBox(height: 20),
                SectionHeader(title: !isEn ? 'የእትሙ ፈተናዎች እና ጥያቄዎች' : 'Issue Quizzes & Tests'),
                if (quizzes.isEmpty)
                  EduEmptyCard(
                    icon: Icons.quiz_outlined,
                    message: !isEn ? 'ለዚህ እትም የተዘጋጀ ፈተና የለም' : 'No quizzes linked to this issue yet',
                  )
                else
                  for (final q in quizzes) ...[
                    _MagazineQuizCard(quiz: q),
                    const SizedBox(height: 10),
                  ],
              ],
            );
        },
      ),
    );
  }

  Widget _detailCoverFallback() {
    return Container(
      width: 84,
      height: 114,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.goldLight, size: 40),
      ),
    );
  }
}

String _n(dynamic v) {
  if (v == null) return '';
  final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
}

class _MagazineQuizCard extends StatelessWidget {
  const _MagazineQuizCard({required this.quiz});
  final Json quiz;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode != 'am';
    final title = isEn ? (asStr(quiz['title_en']) ?? asStr(quiz['title']) ?? '') : (asStr(quiz['title']) ?? asStr(quiz['title_en']) ?? '');
    final limit = asInt(quiz['time_limit_minutes']);
    final left = asIntOr(quiz['attempts_left']);
    final maxAttempts = asIntOr(quiz['max_attempts']);
    final resume = asInt(quiz['in_progress_attempt_id']);
    final score = quiz['my_score'];
    final maxScore = quiz['my_max_score'];
    final needsGrading = asBool(quiz['needs_grading']);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.assignment_outlined, color: AppColors.gold, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: context.serif(15, weight: FontWeight.w600)),
          ),
          if (score != null)
            Text('${_n(score)}/${_n(maxScore)}', style: context.serif(16, color: AppColors.maroon, weight: FontWeight.w700))
          else if (needsGrading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(!isEn ? 'እየታረመ ነው' : 'Grading', style: context.sans(11, color: AppColors.goldDark, weight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (limit != null)
            Text('⏱️ ${limit}m', style: context.sans(12, color: context.palette.muted)),
          Text('🔄 $left/$maxAttempts ${!isEn ? 'ቀሪ ሙከራዎች' : 'attempts left'}', style: context.sans(12, color: context.palette.muted)),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: resume != null
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black87),
                  onPressed: () => context.push('/edu/attempt/$resume'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(!isEn ? 'ፈተናውን ቀጥል' : 'Resume Quiz'),
                )
              : left > 0
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                      onPressed: () => context.push('/edu/quiz/${quiz['id']}'),
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                      label: Text(!isEn ? 'ፈተናውን ጀምር' : 'Start Quiz'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.push('/edu/quiz/${quiz['id']}'),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(!isEn ? 'ውጤት ተመልከት' : 'View Results'),
                    ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Magazine PDF In-App Reader (WebP Multi-Page Rendering + Fallback)
// =============================================================================
class EduMagazinePdfReaderScreen extends ConsumerWidget {
  const EduMagazinePdfReaderScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.magazineId,
  });

  final String title;
  final String pdfUrl;
  final int? magazineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WebpPdfViewer(
      title: title,
      documentType: 'magazine',
      documentId: magazineId,
      pdfUrl: pdfUrl,
    );
  }
}

