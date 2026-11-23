import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/chrome.dart' show EduIcon;
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../models/library.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../admin/edit_mode.dart' show EditModeToggle, EditModeBanner, EditOverlay;
import 'content_admin.dart' show showEduCategoryEditor;
import '../../auth/session.dart';
import '../../guidance/contextual_help_sheet.dart';
import '../../library/book_cover.dart';
import '../../library/book_detail_screen.dart';
import '../edu_screens.dart' show eduOverviewProvider;
import '../edu_formatters.dart';
import 'edu_widgets.dart';
import 'magazine_screens.dart';

/// Everything the ትምህርት home shows, in one request (persisted with keepAlive for instant 0ms back-navigation).
final eduDashboardProvider = FutureProvider<Json>((ref) {
  ref.keepAlive();
  return ref.watch(eduRepositoryProvider).dashboard();
});

final eduHomeBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  try {
    final res = await ref.watch(libraryRepositoryProvider).books(domain: 'timhirt', kind: 'digital');
    return res.items.take(6).toList();
  } catch (_) {
    return const [];
  }
});

// =============================================================================
// ትምህርት home
// =============================================================================
class EduHomeScreen extends ConsumerWidget {
  const EduHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(eduDashboardProvider);
      ref.invalidate(eduOverviewProvider);
      ref.invalidate(eduHomeBooksProvider);
      ref.invalidate(latestMagazineProvider);
    }

    final dashAsync = ref.watch(eduDashboardProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/hub');
      },
      child: PatternScaffold(
        body: RefreshIndicator(
          color: const Color(0xFFC6A044),
          onRefresh: () async => refresh(),
          child: dashAsync.when(
            data: (d) => _HomeBody(data: d, refresh: refresh),
            loading: () => const _HomeSkeletonLoading(),
            error: (err, _) => _HomeErrorView(onRetry: refresh, error: err),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data, required this.refresh});
  final Json data;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = context.findAncestorStateOfType<ConsumerState>()?.ref.watch(currentUserProvider);
    final featured = asJsonList(data['featured']);
    final cont = data['continue'] is Map ? asJson(data['continue']) : null;
    final student = data['student'] is Map ? asJson(data['student']) : null;
    final classes = asJsonList(data['classes']);
    final open = asIntOr(data['open_registration']);
    final isAdminUser = user != null && (user.isAdmin || user.can(Perm.educationManage) || user.can(Perm.educationContent));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Compact Editorial Header
        const _Header(),

        // 2. Student Welcome and Identity Card with Ethiopian Church Cross
        _StudentWelcomeCard(student: student),

        // Admin & Teacher Curriculum Explorer (State F from UI/UX Architecture)
        if (isAdminUser) const _AdminCurriculumExplorerCard(),

        // Unenrolled Orientation Card (when student has no active class enrollment and is not admin)
        if (classes.isEmpty && student == null && !isAdminUser) ...[
          const SizedBox(height: 8),
          _UnenrolledStudentOrientationCard(onRefresh: refresh),
        ],

        // 3. Learning Progress Card (Overall Progress) - shown when enrolled or admin
        if (classes.isNotEmpty || student != null || isAdminUser) ...[
          _OverallProgressCard(student: student, classes: classes),
        ],

        // 4. Featured lesson carousel (when available)
        if (featured.isNotEmpty) ...[
          const SizedBox(height: 10),
          FeaturedCarousel(items: featured),
        ],

        // 5. My Subjects (assigned class curriculum or category grid)
        const SizedBox(height: 12),
        _MySubjectsGrid(
          categories: asJsonList(data['categories']),
          mySubjects: asJsonList(data['my_subjects']),
        ),

        // 6. Continue Learning section
        const SizedBox(height: 14),
        _ContinueLearningSection(cont: cont),

        // 7. Discover Books (horizontal shelf with authentic BookCovers)
        const SizedBox(height: 14),
        const _HomeBooksPreview(),

        // 8. My Classes preview
        const SizedBox(height: 14),
        _HomeClassesPreview(classes: classes, student: student, open: open),

        // 9. Quick shortcuts for Assignments & Class stream
        const SizedBox(height: 14),
        _QuickShortcuts(l: l),

        // 10. This week: quizzes and assignments due
        if (student != null) ...[
          const SizedBox(height: 14),
          _ThisWeek(student: student),
        ],

        // 11. Seleda Magazine banner
        const SizedBox(height: 14),
        const SeledaMagazineBanner(),

        // 12. Administrative access banner at bottom (only for authorized users)
        const SizedBox(height: 14),
        const EditModeBanner(module: 'edu'),
        const _AdminBanner(),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 1. Header (Education Module Header - Second Row)
// -----------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF650D20);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Education module icon
          const EduIcon(size: 38),
          const SizedBox(width: 10),

          // 3. Education title & 4. Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.isEn ? 'Education' : 'የትምህርት ክፍል',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: context.serif(
                    20,
                    color: headingColor,
                    height: 1.15,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.isEn ? 'Sunday School Learning' : 'ሰንበት ትምህርት ቤት',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.sans(11.5, color: p.muted),
                ),
              ],
            ),
          ),

          // 5. Education-specific actions — only if they genuinely belong to this module.
          const SizedBox(width: 8),
          const EditModeToggle(module: 'edu'),
          const ContextualHelpButton(screenRoute: '/edu'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Student Welcome and Identity Card
// -----------------------------------------------------------------------------
class _StudentWelcomeCard extends ConsumerWidget {
  const _StudentWelcomeCard({this.student});
  final Json? student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final name = user?.fullName.split(' ').firstOrNull ?? user?.fullName ?? '';
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5DAC6),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF650D20).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFFC6A044), width: 1.2),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF650D20),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isNotEmpty
                      ? (isEn ? 'Welcome back, $name' : 'ሰላም እንደምን ኖረሃል፣ $name')
                      : (isEn ? 'Welcome back, student' : 'ሰላም እንደምን ኖረሃል'),
                  style: context.serif(
                    15.5,
                    weight: FontWeight.w700,
                    color: const Color(0xFF231F20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.isAdmin == true
                      ? (isEn ? 'System Administrator / Curriculum Manager' : 'ሥርዓተ-ትምህርት አስተዳዳሪ')
                      : student != null
                          ? (isEn ? 'Enrolled Student' : 'መደበኛ ተማሪ')
                          : (isEn ? 'Guest / Awaiting Class Assignment' : 'የክፍል ምደባ በመጠባበቅ ላይ'),
                  style: context.sans(
                    11.5,
                    color: const Color(0xFF766E65),
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC6A044).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.church_rounded,
              color: Color(0xFFC6A044),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Admin & Teacher Curriculum Management Card (State F)
// -----------------------------------------------------------------------------
class _AdminCurriculumExplorerCard extends StatelessWidget {
  const _AdminCurriculumExplorerCard();

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC6A044), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF650D20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF650D20), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Curriculum Explorer & Management' : 'የሥርዓተ-ትምህርት ማስተዳደሪያ እና አሰሳ',
                      style: context.serif(14.5, weight: FontWeight.w700, color: const Color(0xFF650D20)),
                    ),
                    Text(
                      isEn ? 'Browse Grades 1 to 12 curricula, courses and lessons' : 'ከ1ኛ እስከ 12ኛ ክፍል ያሉትን ይዘቶች ያስሱ',
                      style: context.sans(11, color: const Color(0xFF766E65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var g = 1; g <= 12; g++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => context.push('/edu/subject/1/grade/$g'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: g == 7 ? const Color(0xFF650D20) : const Color(0xFFFFF8E9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: g == 7 ? const Color(0xFF650D20) : const Color(0xFFC6A044).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          isEn ? 'Grade $g' : '$gኛ ክፍል',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: g == 7 ? Colors.white : const Color(0xFF650D20),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    side: const BorderSide(color: Color(0xFFC6A044)),
                  ),
                  icon: const Icon(Icons.auto_stories_rounded, size: 15, color: Color(0xFF650D20)),
                  label: Text(
                    isEn ? 'Curriculum' : 'ይዘቶችና ምዕራፎች',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF650D20)),
                  ),
                  onPressed: () => context.push('/edu/content'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    side: const BorderSide(color: Color(0xFFC6A044)),
                  ),
                  icon: const Icon(Icons.groups_rounded, size: 15, color: Color(0xFF650D20)),
                  label: Text(
                    isEn ? 'Classes' : 'ክፍሎችን አስተዳድር',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF650D20)),
                  ),
                  onPressed: () => context.push('/edu/manage'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    side: const BorderSide(color: Color(0xFFC6A044)),
                  ),
                  icon: const Icon(Icons.quiz_rounded, size: 15, color: Color(0xFF650D20)),
                  label: Text(
                    isEn ? 'Quizzes' : 'ፈተናዎች ማዕከል',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF650D20)),
                  ),
                  onPressed: () => context.push('/edu/admin/quizzes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Unenrolled Student Orientation Card
// -----------------------------------------------------------------------------
class _UnenrolledStudentOrientationCard extends StatelessWidget {
  const _UnenrolledStudentOrientationCard({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final p = context.palette;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.maroon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.maroon, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'Welcome to Sunday School!' : 'እንኳን ወደ ሰንበት ትምህርት ቤት በደህና መጡ!',
                  style: context.serif(15.5, weight: FontWeight.w700, color: AppColors.maroon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'You do not have an active class enrollment assigned for the current academic year. Please contact the Sunday School administrator or your teacher to be assigned to your grade curriculum.'
                : 'በአሁኑ የትምህርት ዘመን እስካሁን የክፍል ምደባ አልተሰጠዎትም። በክፍልዎ ሥርዓተ-ትምህርት እንዲመደቡ እባክዎ የሰንበት ት/ቤቱን የትምህርት ክፍል አስተዳዳሪ ወይም መምህርዎን ያነጋግሩ።',
            style: context.sans(13, color: const Color(0xFF4A4540), height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'While awaiting class enrollment, you can read public publications, access the Seleda magazine, and explore the library books below.'
                : 'የክፍል ምደባዎን እስከሚያገኙ ድረስ ከታች ያሉትን የሰሌዳ መጽሔት፣ የቤተ-መጻሕፍት መጻሕፍት እና አጠቃላይ መንፈሳዊ ይዘቶችን መመልከት ይችላሉ።',
            style: context.sans(12.5, color: p.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(isEn ? 'Check Status' : 'ምደባን አድስ'),
                  onPressed: onRefresh,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: Text(isEn ? 'Read Magazine' : 'መጽሔት አንብብ'),
                  onPressed: () => context.push('/edu/magazines'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Learning Progress Card (Overall Progress)
// -----------------------------------------------------------------------------
class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({this.student, required this.classes});
  final Json? student;
  final List<Json> classes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    final overall = student?['overall_progress'] is Map ? asJson(student!['overall_progress']) : null;
    final pct = asIntOr(overall?['percent']);
    final completedCourses = asIntOr(overall?['completed_courses']);
    final totalCourses = asInt(overall?['total_courses']) ?? (classes.isNotEmpty ? classes.length : 0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/edu/progress'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF650D20),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF650D20).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFFFFF8E9),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEn ? 'Overall Progress' : 'የትምህርት እድገት',
                    style: context.serif(15, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completedCourses / $totalCourses',
                  style: context.serif(15, weight: FontWeight.w800, color: const Color(0xFF650D20)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct > 0 ? (pct / 100).clamp(0.0, 1.0) : 0.0,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE5DAC6).withValues(alpha: 0.5),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC6A044)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$pct%',
                  style: context.sans(
                    12,
                    weight: FontWeight.w700,
                    color: const Color(0xFFC6A044),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. My Subjects (2x2 Grid)
// -----------------------------------------------------------------------------
class _MySubjectsGrid extends StatelessWidget {
  const _MySubjectsGrid({this.categories = const [], this.mySubjects = const []});
  final List<Json> categories;
  final List<Json> mySubjects;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    final displaySubjects = mySubjects.isNotEmpty
        ? mySubjects
        : (categories.isNotEmpty ? categories : const <Json>[]);

    if (displaySubjects.isNotEmpty) {
      final isFallback = mySubjects.isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EduSectionHeader(
            title: isFallback
                ? (isEn ? 'Curriculum Subjects' : 'የሥርዓተ-ትምህርት ዓይነቶች')
                : (isEn ? 'My Enrolled Subjects' : 'የክፍሌ የትምህርት ዓይነቶች'),
            subtitle: isFallback
                ? (isEn ? 'Select a subject to explore Grade 1 to 12 lessons' : 'ከ1ኛ እስከ 12ኛ ክፍል ያሉትን ይዘቶች ይመልከቱ')
                : (isEn ? 'Learning materials for your active grade' : 'ለተመደቡበት ክፍል የተዘጋጁ ትምህርቶች'),
            actionLabel: l.seeAll,
            onAction: () => context.go('/edu/classes'),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displaySubjects.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
            ),
            itemBuilder: (context, index) {
              final s = displaySubjects[index];
              final titleAm = asStr(s['name']) ?? '';
              final titleEn = asStr(s['name_en']) ?? asStr(s['code']) ?? '';
              final subjectId = asIntOr(s['id']);
              final grade = asInt(s['assigned_grade'] ?? s['grade']);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (grade != null) {
                    context.push('/edu/subject/$subjectId/grade/$grade');
                  } else {
                    context.push('/edu/subject/$subjectId/grades');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5DAC6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF650D20).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.6)),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF650D20), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              titleAm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.serif(12, weight: FontWeight.w700),
                            ),
                            Text(
                              titleEn.isNotEmpty ? titleEn : '$gradeኛ ክፍል',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(10, color: const Color(0xFF766E65)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DAC6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF650D20).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined, color: Color(0xFF650D20), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'No Enrolled Class Curriculum' : 'ምንም የተመደበ የክፍል ትምህርት የለም',
                      style: context.serif(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'You are not enrolled in an active class. Browse classes to join your grade curriculum.'
                          : 'በአሁኑ ጊዜ በተመዘገበ ንቁ ክፍል ውስጥ አልተመደቡም። የክፍልዎን ትምህርት ለመከታተል ክፍሎችን ይመልከቱ።',
                      style: context.sans(11.5, color: const Color(0xFF766E65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF650D20),
                side: const BorderSide(color: Color(0xFF650D20)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.class_outlined, size: 18),
              label: Text(isEn ? 'View Available Classes' : 'የክፍል ዝርዝር ይመልከቱ'),
              onPressed: () => context.go('/edu/classes'),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Continue Learning Section
// -----------------------------------------------------------------------------
class _ContinueLearningSection extends StatelessWidget {
  const _ContinueLearningSection({this.cont});
  final Json? cont;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Continue Learning' : 'ቀጣይ ትምህርት',
          style: context.serif(16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (cont != null)
          ContinueLearningCard(data: cont!)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DAC6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF650D20).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF650D20),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isEn ? 'No courses are currently assigned.' : 'ምንም ትምህርት አልተመደበም',
                  textAlign: TextAlign.center,
                  style: context.serif(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  isEn ? 'Please check with your teacher or explore lessons.' : 'እባክዎ ከአስተማሪዎ ጋር ይጠይቁ ወይም ትምህርቶችን ይመልከቱ',
                  textAlign: TextAlign.center,
                  style: context.sans(11.5, color: p.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: Text(isEn ? 'Explore Lessons' : 'ትምህርቶችን አስስ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF650D20),
                    side: const BorderSide(color: Color(0xFF650D20)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.go('/edu/classes'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 6. Discover Books (My Library Shelf with Authentic BookCovers)
// -----------------------------------------------------------------------------
class _HomeBooksPreview extends ConsumerWidget {
  const _HomeBooksPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final booksAsync = ref.watch(eduHomeBooksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EduSectionHeader(
          title: l.isEn ? 'Discover Books' : 'የቤተ-መጻሕፍት ምርጦች',
          subtitle: l.isEn ? 'Spiritual books from My Library' : 'መንፈሳዊ መጻሕፍትን ከመተግበሪያው ላይ ያንብቡ',
          actionLabel: l.seeAll,
          onAction: () => context.go('/edu/library'),
        ),
        const SizedBox(height: 8),
        booksAsync.when(
          data: (books) {
            if (books.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final b = books[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => BookDetailScreen(book: b)),
                      );
                    },
                    child: Container(
                      width: 110,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: BookCover.fromBook(
                              b,
                              width: 86,
                              height: 114,
                              borderRadius: 6,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.serif(11.5, weight: FontWeight.w700),
                          ),
                          if (b.author != null && b.author!.isNotEmpty)
                            Text(
                              b.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(9.5, color: p.muted),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC6A044))),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 7. My Classes Preview
// -----------------------------------------------------------------------------
class _HomeClassesPreview extends StatelessWidget {
  const _HomeClassesPreview({
    required this.classes,
    this.student,
    this.open = 0,
  });
  final List<Json> classes;
  final Json? student;
  final int open;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EduSectionHeader(
          title: l.myClasses,
          subtitle: l.isEn ? 'Your enrolled classes and grade' : 'የተመዘገቡባቸው ክፍሎች እና ደረጃ',
          actionLabel: l.seeAll,
          onAction: () => context.go('/edu/classes'),
        ),
        const SizedBox(height: 8),
        if (classes.isEmpty)
          AppCard(
            onTap: () => context.go('/edu/classes'),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF650D20).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.5), width: 1.2),
                  ),
                  child: const Icon(Icons.school_outlined, color: Color(0xFF650D20), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.isEn ? 'Explore Classes & Curriculum' : 'ክፍሎችንና ካሪኩለሙን ይመልከቱ',
                        style: context.serif(14, weight: FontWeight.w700, color: const Color(0xFF650D20)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open > 0 ? l.elNotEnrolledOpen(open) : l.elNotEnrolledNoOpen,
                        style: context.sans(11.5, color: p.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFC6A044)),
              ],
            ),
          )
        else
          for (final c in classes.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => context.push('/edu/class/${c['id']}'),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF650D20).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF650D20), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eduClassName(c),
                            style: context.serif(14, weight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (eduClassSubtitle(c, l).isNotEmpty)
                            Text(
                              eduClassSubtitle(c, l),
                              style: context.sans(11, color: p.muted),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFC6A044)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 8. Quick Shortcuts (Assignments & Class Stream)
// -----------------------------------------------------------------------------
class _QuickShortcuts extends StatelessWidget {
  const _QuickShortcuts({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            onTap: () => context.push('/edu/assignments'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF650D20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_outlined, color: Color(0xFF650D20), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.elAssignments, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(l.isEn ? 'Homework & tasks' : 'ሥራዎችና ፈተናዎች', style: context.sans(10.5, color: context.palette.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppCard(
            onTap: () => context.push('/edu/announcements'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6A044).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_outlined, color: Color(0xFFC6A044), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.elClassFeed, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(l.isEn ? 'Teacher updates' : 'የአስተማሪ መልእክቶች', style: context.sans(10.5, color: context.palette.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 9. This Week (Quizzes and Assignments)
// -----------------------------------------------------------------------------
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.student});
  final Json student;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final quizzes = asJsonList(student['quizzes']);
    final due = asJsonList(student['assignments_due']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EduSectionHeader(
          title: l.elThisWeek,
          subtitle: l.isEn ? 'Pending quizzes and submissions' : 'የሳምንቱ ፈተናዎች እና የቤት ሥራዎች',
        ),
        if (quizzes.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF650D20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF650D20), Color(0xFF450915)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFC6A044).withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF450915).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/edu/quiz/${quizzes.first['id']}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC6A044).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l.isEn ? 'WEEKLY ASSESSMENT' : 'ሳምንታዊ ፈተና',
                                style: context.sans(
                                  10.5,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFFFFF8E9),
                                ),
                              ),
                            ),
                            Text(
                              l.elWeeklyQuizzes,
                              style: context.serif(18, weight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.elQuizzesWaiting(quizzes.length),
                              style: context.sans(12.5, color: const Color(0xFFFFF8E9)),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC6A044),
                                foregroundColor: const Color(0xFF450915),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => context.push('/edu/quiz/${quizzes.first['id']}'),
                              child: Text(
                                l.elTakePart,
                                style: context.sans(12.5, weight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6A044).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Color(0xFFFFF8E9),
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final q in quizzes.skip(1).take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizCard(quiz: q, compact: true),
            ),
        ],
        for (final a in due.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => context.push('/edu/class/${a['class_id']}?tab=assignments'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: asBool(a['overdue']) ? AppColors.danger : const Color(0xFFC6A044),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStr(a['title']) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(14, weight: FontWeight.w600),
                        ),
                        Text(
                          [
                            asStr(a['course_name']) ?? '',
                            if (asDate(a['due_at']) != null)
                              (asBool(a['overdue'])
                                  ? l.elOverdue
                                  : l.elDue(f.date(asDate(a['due_at']), withWeekday: true))),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(12, color: asBool(a['overdue']) ? AppColors.danger : p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ],
              ),
            ),
          ),
        if (quizzes.isEmpty && due.isEmpty)
          EduEmptyCard(
            icon: Icons.event_available_rounded,
            message: l.elNothingThisWeek,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 10. Admin Banner
// -----------------------------------------------------------------------------
class _AdminBanner extends ConsumerWidget {
  const _AdminBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final canAdmin =
        session is SignedIn &&
        (session.user.can(Perm.educationManage) ||
            session.user.can(Perm.educationContent) ||
            session.user.isSuperAdmin);
    if (!canAdmin) return const SizedBox.shrink();

    final l = context.l10n;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/edu/admin'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6A044).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFFC6A044),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.isEn ? 'Education Admin Panel' : 'የትምህርት ክፍል አስተዳደር',
                        style: context.serif(14, color: p.primary),
                      ),
                      Text(
                        l.isEn
                            ? 'Academics, classes, authoring, reviews & library'
                            : 'አካዳሚክ፣ ክፍሎች፣ ይዘት ማዘጋጀት፣ ግምገማ እና ቤተ መጻሕፍት',
                        style: context.sans(11.5, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 11. Loading Skeleton View
// -----------------------------------------------------------------------------
class _HomeSkeletonLoading extends StatelessWidget {
  const _HomeSkeletonLoading();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;

    Widget shimmerBox({double? width, required double height, double radius = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: p.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            shimmerBox(width: 40, height: 40, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shimmerBox(width: 140, height: 18),
                  const SizedBox(height: 6),
                  shimmerBox(width: 90, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        shimmerBox(height: 72, radius: 16),
        const SizedBox(height: 14),
        shimmerBox(height: 68, radius: 16),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.1,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => shimmerBox(height: 60, radius: 14)),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF650D20),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.isEn ? 'Loading your education data...' : 'በመጫን ላይ...',
                style: context.sans(12.5, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 12. Error View (Matching Reference Cloud Illustration)
// -----------------------------------------------------------------------------
class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.onRetry, required this.error});
  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFF650D20).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: Color(0xFF650D20),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEn ? 'Something went wrong' : 'መረጃው መጫን አልተቻለም',
              textAlign: TextAlign.center,
              style: context.serif(18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isEn ? 'Please check your connection and try again.' : 'እባክዎ የኢንተርኔት  ግንኙነት ያረጋግጡና እንደገና ይሞክሩ',
              textAlign: TextAlign.center,
              style: context.sans(12.5, color: p.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isEn ? 'Try Again' : 'እንደገና ሞክር'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF650D20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Canonical Categories (Used in Class Curriculum and full category views)
// -----------------------------------------------------------------------------
class _CanonicalCategoryItem {
  const _CanonicalCategoryItem({
    required this.order,
    required this.id,
    required this.name,
    required this.nameEn,
    required this.desc,
    required this.icon,
  });

  final int order;
  final int id;
  final String name;
  final String nameEn;
  final String desc;
  final IconData icon;
}

const canonicalCategoriesList = [
  _CanonicalCategoryItem(
    order: 1,
    id: 1,
    name: 'ትምህርተ ሃይማኖት',
    nameEn: 'Theology & Doctrine',
    desc: 'የኦርቶዶክስ ተዋሕዶ ሃይማኖት መሠረተ እምነትና ዶግማ',
    icon: Icons.church_rounded,
  ),
  _CanonicalCategoryItem(
    order: 2,
    id: 4,
    name: 'የመጽሐፍ ቅዱስ ጥናት',
    nameEn: 'Bible Study',
    desc: 'የብሉይና የሐዲስ ኪዳን መጻሕፍት ጥናትና ትርጓሜ',
    icon: Icons.menu_book_rounded,
  ),
  _CanonicalCategoryItem(
    order: 3,
    id: 5,
    name: 'ክርስቲያናዊ ሥነምግባር',
    nameEn: 'Christian Ethics',
    desc: 'የክርስቲያን አኗኗር፣ ምግባርና ማኅበራዊ ሕይወት',
    icon: Icons.favorite_rounded,
  ),
  _CanonicalCategoryItem(
    order: 4,
    id: 6,
    name: 'ሥርዓተ ቤተ ክርስቲያን',
    nameEn: 'Church Order & Rites',
    desc: 'የቤተ ክርስቲያን ሥርዓት፣ አምልኮና ሰባቱ ምሥጢራት',
    icon: Icons.account_balance_rounded,
  ),
  _CanonicalCategoryItem(
    order: 5,
    id: 3,
    name: 'የቤተክርስትያን ታሪክ',
    nameEn: 'Church History',
    desc: 'የኢትዮጵያና የዓለም አብያተ ክርስቲያናት ታሪክ',
    icon: Icons.history_edu_rounded,
  ),
  _CanonicalCategoryItem(
    order: 6,
    id: 7,
    name: 'ልሳነ ግእዝ',
    nameEn: 'Geez Language',
    desc: 'የግእዝ ቋንቋ ሰዋስው፣ ንባብና የዜማ ምልክቶች',
    icon: Icons.translate_rounded,
  ),
  _CanonicalCategoryItem(
    order: 7,
    id: 8,
    name: 'ዜማ',
    nameEn: 'Zema (Sacred Chants)',
    desc: 'የቅዱስ ያሬድ ዜማ፣ ጾመ ድጓ፣ ዝማሬና ማሕሌት',
    icon: Icons.music_note_rounded,
  ),
];

const canonicalSubjectsList = canonicalCategoriesList;

class CanonicalCategoriesSection extends StatelessWidget {
  const CanonicalCategoriesSection({
    super.key,
    this.apiCategories = const [],
    required this.refresh,
  });
  final List<Json> apiCategories;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EduSectionHeader(
          title: isEn ? 'Class Curriculum Subjects' : 'የክፍልዎ የትምህርት ዓይነቶች',
          subtitle: isEn
              ? 'Subjects assigned to your active class curriculum'
              : 'በክፍልዎ ሥርዓተ-ትምህርት የተመደቡ የትምህርት ዓይነቶች',
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: canonicalCategoriesList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final spec = canonicalCategoriesList[index];
            final apiMatch = apiCategories.firstWhere(
              (s) =>
                  asIntOr(s['sort_order']) == spec.order ||
                  asStr(s['name'])?.trim() == spec.name.trim() ||
                  asIntOr(s['id']) == spec.id,
              orElse: () => <String, dynamic>{},
            );
            final realId = asInt(apiMatch['id']) ?? spec.id;
            final displayName = asStr(apiMatch['name']) ?? spec.name;
            final displayDesc = asStr(apiMatch['description']) ?? spec.desc;

            final card = AppCard(
              onTap: () {
                context.push('/edu/learn/category/$realId');
              },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 14,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${spec.order}',
                      style: context.serif(
                        17,
                        weight: FontWeight.w800,
                        color: AppColors.maroon,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: context.serif(
                                  15.5,
                                  weight: FontWeight.w700,
                                  color: AppColors.maroon,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isEn ? '12 Grades' : '12 ክፍሎች',
                                style: context.sans(
                                  10.5,
                                  weight: FontWeight.w600,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                ],
              ),
            );

            return EditOverlay(
              permission: Perm.educationContent,
              onEdit: () async {
                final saved = await showEduCategoryEditor(
                  context,
                  category: apiMatch.isNotEmpty ? apiMatch : {'id': realId, 'name': displayName},
                );
                if (saved == true && context.mounted) {
                  refresh();
                }
              },
              child: card,
            );
          },
        ),
      ],
    );
  }
}

