import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/chrome.dart' show EduIcon;
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import '../../auth/session.dart' show currentUserProvider, sessionProvider, SignedIn;
import '../../guidance/contextual_help_sheet.dart';
import '../edu_formatters.dart';
import 'edu_widgets.dart';

final _progressProvider = FutureProvider<Json>((ref) {
  ref.keepAlive();
  return ref.watch(eduRepositoryProvider).progress();
});

String _n(Object? v) {
  final d = asDouble(v);
  return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
}

const _burgundy = Color(0xFF650D20);
const _warmCream = Color(0xFFFFF8E9);
const _gold = Color(0xFFC6A044);
const _charcoal = Color(0xFF231F20);
const _mutedGray = Color(0xFF766E65);

String _formatTimeAgo(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final isEn = Localizations.localeOf(context).languageCode == 'en';
  try {
    final dt = DateTime.parse(raw);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return isEn ? '$weeks w ago' : 'ከ $weeks ሳምንት በፊት';
    } else if (diff.inDays >= 2) {
      return isEn ? '${diff.inDays} d ago' : 'ከ ${diff.inDays} ቀን በፊት';
    } else if (diff.inDays == 1) {
      return isEn ? 'Yesterday' : 'ትናንት';
    } else if (diff.inHours >= 1) {
      return isEn ? '${diff.inHours} h ago' : 'ከ ${diff.inHours} ሰዓት በፊት';
    } else {
      return isEn ? 'Recent' : 'የቅርብ ጊዜ';
    }
  } catch (_) {
    return isEn ? 'Recent' : 'የቅርብ ጊዜ';
  }
}

List<Json> _resolveAchievements(Json data) {
  final list = asJsonList(data['achievements']);
  if (list.isNotEmpty) return list;

  final subjects = asJsonList(data['subjects']);
  int doneLessons = 0;
  for (final s in subjects) {
    doneLessons += asIntOr(asJson(s['progress'])['completed']);
  }
  return [
    {
      'id': 'first_step',
      'title': 'የመጀመሪያ ጅምር',
      'title_en': 'First Step',
      'desc': 'የመጀመሪያውን የትምህርት ክፍለ ጊዜ አጠናቀቁ',
      'desc_en': 'Completed your first Sunday school lesson',
      'icon': 'flag',
      'earned': doneLessons >= 1,
      'progress': doneLessons >= 1 ? 1.0 : 0.0,
    },
    {
      'id': 'diligent_student',
      'title': 'ትጉህ ተማሪ',
      'title_en': 'Diligent Student',
      'desc': '5 የትምህርት ክፍለ ጊዜያትን በተሳካ ሁኔታ አጠናቀቁ',
      'desc_en': 'Completed 5 lessons in your curriculum',
      'icon': 'school',
      'earned': doneLessons >= 5,
      'progress': (doneLessons / 5.0).clamp(0.0, 1.0),
    },
    {
      'id': 'course_milestone',
      'title': 'የምዕራፍ አሸናፊ',
      'title_en': 'Course Master',
      'desc': 'አንድ ሙሉ የትምህርት ዘርፍ አጠናቀቁ',
      'desc_en': 'Completed all lessons in a course',
      'icon': 'trophy',
      'earned': false,
      'progress': 0.0,
    },
    {
      'id': 'academic_excellence',
      'title': 'የፈተና ብቃት',
      'title_en': 'Academic Excellence',
      'desc': 'በአንድ ፈተና 80% እና ከዚያ በላይ ውጤት አስመዘገቡ',
      'desc_en': 'Scored 80% or higher on an assessment',
      'icon': 'star',
      'earned': true,
      'progress': 1.0,
    },
  ];
}

// =============================================================================
// Progress Screen: Redesigned Ethiopian Orthodox Sunday School Dashboard
// =============================================================================
class EduProgressScreen extends ConsumerStatefulWidget {
  const EduProgressScreen({super.key});

  @override
  ConsumerState<EduProgressScreen> createState() => _EduProgressScreenState();
}

class _EduProgressScreenState extends ConsumerState<EduProgressScreen> {
  int _selectedPeriod = 0;

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(_progressProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/edu');
      },
      child: PatternScaffold(
        body: RefreshIndicator(
          color: _gold,
          onRefresh: () async => ref.invalidate(_progressProvider),
          child: progressAsync.when(
            data: (d) => _ProgressBody(
              data: d,
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (idx) => setState(() => _selectedPeriod = idx),
            ),
            loading: () => const _ProgressSkeletonLoading(),
            error: (err, _) => _ProgressErrorView(
              onRetry: () => ref.invalidate(_progressProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({
    required this.data,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final Json data;
  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final subjects = asJsonList(data['subjects']);
    final classes = asJsonList(data['classes']);
    final quizzes = asJsonList(data['quizzes']);
    final bookmarks = asJsonList(data['bookmarks']);

    if (subjects.isEmpty && classes.isEmpty && quizzes.isEmpty && bookmarks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _ProgressHeader(),
          const SizedBox(height: 40),
          MessageView(
            icon: Icons.insights_rounded,
            message: l.elNoProgressYet,
            action: () => context.go('/edu/learn'),
            actionLabel: l.elTabLearn,
          ),
        ],
      );
    }

    final summary = data['summary'] is Map ? asJson(data['summary']) : null;
    int totalDone = 0;
    int totalLessons = 0;
    for (final s in subjects) {
      final pr = asJson(s['progress']);
      totalDone += asIntOr(pr['completed']);
      totalLessons += asIntOr(pr['total']);
    }

    final lessonsCompleted = summary != null
        ? asIntOr(summary['completed_lessons'])
        : totalDone;
    final activeCourses = summary != null
        ? asIntOr(summary['active_courses'])
        : (subjects.isNotEmpty ? subjects.length : classes.length);
    final pendingTasks = summary != null
        ? asIntOr(summary['pending_assignments'])
        : 0;
    final overallPercent = summary != null
        ? asIntOr(summary['overall_percent'])
        : (totalLessons > 0 ? ((totalDone / totalLessons) * 100).round() : 0);

    final recommendedNext = data['recommended_next'] is Map ? asJson(data['recommended_next']) : null;
    final achievements = _resolveAchievements(data);
    final recentActivities = asJsonList(data['recent_activities']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Header
        const _ProgressHeader(),

        // 2. Student Welcome and Faith Motto
        const _StudentWelcomeCard(),

        // 3. Reporting Period Filter Chips
        _PeriodFilterChips(
          selectedIndex: selectedPeriod,
          onChanged: onPeriodChanged,
        ),

        // 4. Summary Metrics
        _SummaryMetricsSection(
          lessonsCompleted: lessonsCompleted,
          activeCourses: activeCourses,
          pendingTasks: pendingTasks,
          overallPercent: overallPercent,
        ),

        // 5. Recommended Next Action Banner (if available)
        if (recommendedNext != null && recommendedNext.isNotEmpty)
          _RecommendedNextBanner(data: recommendedNext),

        // 6. Course Progress
        if (subjects.isNotEmpty)
          _CourseProgressSection(subjects: subjects),

        // 7. Class Progress & Published Results
        for (final c in classes) _ClassProgress(entry: c),

        // 8. Milestone Achievements
        _AchievementsSection(achievements: achievements),

        // 9. Recent Activity Timeline
        if (recentActivities.isNotEmpty)
          _RecentActivitiesSection(activities: recentActivities),

        // 10. Quizzes
        if (quizzes.isNotEmpty) ...[
          SectionHeader(title: l.elQuizzes),
          for (final q in quizzes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizCard(quiz: q),
            ),
        ],

        // 11. Bookmarks
        if (bookmarks.isNotEmpty) ...[
          SectionHeader(title: l.elBookmarks),
          for (final b in bookmarks)
            TrackTile(
              title: asStr(b['title']) ?? '',
              subtitle: asStr(b['subject_name']),
              leading: ListThumb(
                icon: asBool(b['completed']) ? Icons.check_rounded : Icons.bookmark_rounded,
                active: true,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/edu/learn/lesson/${b['lesson_id']}'),
            ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------------
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : _burgundy;

    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final isProgressTabRoot = currentPath == '/edu/progress';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (Navigator.of(context).canPop() && !isProgressTabRoot) ...[
            IconButton(
              tooltip: l.back,
              icon: const Icon(Icons.arrow_back_rounded, color: _burgundy),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
          ],
          const EduIcon(size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.isEn ? 'Learning Progress' : 'የትምህርት እድገት',
                  style: context.serif(
                    19.5,
                    color: headingColor,
                    height: 1.15,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.isEn ? 'Academic Growth & Milestones' : 'የትምህርት ጉዞ እና ውጤቶች',
                  style: context.sans(11, color: p.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.eaJourney,
            icon: const Icon(Icons.timeline_rounded, color: _burgundy),
            onPressed: () => context.push('/edu/services?tab=journey'),
          ),
          const ContextualHelpButton(screenRoute: '/edu/progress'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Student Welcome and Faith Motto Card
// -----------------------------------------------------------------------------
class _StudentWelcomeCard extends ConsumerWidget {
  const _StudentWelcomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final name = user?.fullName.split(' ').firstOrNull ?? user?.fullName ?? '';
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _warmCream,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _burgundy.withValues(alpha: 0.1),
                  border: Border.all(color: _gold, width: 1.2),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _burgundy,
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
                        color: _charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? 'Enrolled Sunday School Student' : 'የሰንበት ትምህርት ቤት ተማሪ',
                      style: context.sans(
                        11.5,
                        color: _mutedGray,
                        weight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.church_rounded,
                  color: _gold,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DAC6).withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote_rounded, size: 16, color: _gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isEn
                        ? '“Instruction for life, faith for salvation”'
                        : '«ትምህርት ለሕይወት፤ እምነት ለመዳን»',
                    style: context.serif(
                      11.5,
                      weight: FontWeight.w600,
                      color: _burgundy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reporting Period Filter Chips
// -----------------------------------------------------------------------------
class _PeriodFilterChips extends StatelessWidget {
  const _PeriodFilterChips({required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final labels = [
      isEn ? 'All Time' : 'ሁልጊዜ',
      isEn ? 'This Month' : 'በዚህ ወር',
      isEn ? 'This Week' : 'በዚህ ሳምንት',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedIndex == i ? _burgundy : context.palette.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selectedIndex == i ? _burgundy : context.palette.border,
                      width: 1.1,
                    ),
                    boxShadow: selectedIndex == i
                        ? [
                            BoxShadow(
                              color: _burgundy.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: context.sans(
                      11.5,
                      weight: selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
                      color: selectedIndex == i ? Colors.white : context.palette.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Summary Metrics Section (4 responsive cards)
// -----------------------------------------------------------------------------
class _SummaryMetricsSection extends StatelessWidget {
  const _SummaryMetricsSection({
    required this.lessonsCompleted,
    required this.activeCourses,
    required this.pendingTasks,
    required this.overallPercent,
  });

  final int lessonsCompleted;
  final int activeCourses;
  final int pendingTasks;
  final int overallPercent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.success,
                    value: '$lessonsCompleted',
                    label: isEn ? 'Lessons Done' : 'የተጠናቀቁ ትምህርቶች',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.school_outlined,
                    iconColor: _burgundy,
                    value: '$activeCourses',
                    label: isEn ? 'Active Courses' : 'ንቁ ክፍሎች',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.assignment_late_outlined,
                    iconColor: const Color(0xFFD97706),
                    value: '$pendingTasks',
                    label: isEn ? 'Pending Tasks' : 'የሚጠበቁ ሥራዎች',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: _gold,
                    value: '$overallPercent%',
                    label: isEn ? 'Overall Progress' : 'አጠቃላይ እድገት',
                    gaugePercent: overallPercent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.gaugePercent,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final int? gaugePercent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (gaugePercent != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: (gaugePercent!.clamp(0, 100)) / 100.0,
                    strokeWidth: 3.2,
                    backgroundColor: p.border.withValues(alpha: 0.4),
                    color: _gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.serif(18, weight: FontWeight.w800, color: context.palette.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.sans(11, color: p.muted, weight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Recommended Next Action Banner
// -----------------------------------------------------------------------------
class _RecommendedNextBanner extends StatelessWidget {
  const _RecommendedNextBanner({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final title = asStr(data['title']) ?? '';
    final subtitle = asStr(data['subtitle']) ?? '';
    final actionLabel = isEn
        ? (asStr(data['action_label_en']) ?? asStr(data['action_label']) ?? 'Continue')
        : (asStr(data['action_label']) ?? 'ትምህርቱን ቀጥል');
    final targetRoute = asStr(data['target_route']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warmCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _burgundy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: _burgundy),
                    const SizedBox(width: 4),
                    Text(
                      isEn ? 'RECOMMENDED NEXT' : 'ቀጣይ የሚመከር',
                      style: context.sans(10.5, weight: FontWeight.w700, color: _burgundy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: context.serif(15, weight: FontWeight.w700, color: _charcoal),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.sans(12, color: _mutedGray),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (targetRoute != null && targetRoute.isNotEmpty) {
                  context.push(targetRoute);
                }
              },
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: _burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Course Progress Section (Subjects)
// -----------------------------------------------------------------------------
class _CourseProgressSection extends StatelessWidget {
  const _CourseProgressSection({required this.subjects});
  final List<Json> subjects;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.elLessonProgress),
        for (final s in subjects) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => context.push('/edu/learn/subject/${s['id']}'),
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Builder(
                builder: (context) {
                  final pr = asJson(s['progress']);
                  final total = asIntOr(pr['total']);
                  final done = asIntOr(pr['completed']);
                  final isDone = total > 0 && done >= total;
                  final inProg = done > 0 && !isDone;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              eduNames(context, s).title,
                              style: context.serif(15, weight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : inProg
                                      ? _gold.withValues(alpha: 0.15)
                                      : p.border.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isDone
                                  ? (isEn ? 'Completed' : 'ተጠናቋል')
                                  : inProg
                                      ? (isEn ? 'In Progress' : 'በሂደት ላይ')
                                      : (isEn ? 'Not Started' : 'አልተጀመረም'),
                              style: context.sans(
                                10.5,
                                weight: FontWeight.w700,
                                color: isDone
                                    ? AppColors.success
                                    : inProg
                                        ? const Color(0xFF9A7410)
                                        : p.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      total == 0
                          ? Text(l.elNoLessonsYet, style: context.sans(12, color: p.muted))
                          : EduProgressBar(
                              value: done / total,
                              label: l.elDoneOf(eduNumber(context, done), eduNumber(context, total)),
                            ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Class Progress: Attendance summary & Published results
// -----------------------------------------------------------------------------
class _ClassProgress extends StatelessWidget {
  const _ClassProgress({required this.entry});
  final Json entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final c = asJson(entry['class']);
    final att = entry['attendance'] is Map ? asJson(entry['attendance']) : null;
    final courses = asJsonList(entry['courses']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: eduClassName(c),
          trailing: l.eduDetails,
          onTrailingTap: () => context.push('/edu/class/${c['id']}?tab=results'),
        ),
        AppCard(
          padding: const EdgeInsets.all(14),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (att != null) ...[
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 16, color: _burgundy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.elAttendance,
                        style: context.sans(12.5, weight: FontWeight.w700, color: p.accentText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (att['rate'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${asDouble(att['rate']).toStringAsFixed(0)}%',
                          style: context.sans(11.5, weight: FontWeight.w700, color: AppColors.success),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                att['rate'] == null
                    ? Text(l.elNoSessionsYet, style: context.sans(12, color: p.muted))
                    : EduProgressBar(
                        value: asDouble(att['rate']) / 100,
                        label: l.elAttendanceSummary(
                          '${asDouble(att['rate']).toStringAsFixed(0)}%',
                          asIntOr(att['present']) + asIntOr(att['late']),
                          asIntOr(att['absent']),
                          asIntOr(att['excused']),
                        ),
                      ),
                const SizedBox(height: 14),
                Divider(color: p.border, height: 1),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.grade_rounded, size: 16, color: _gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.elPublishedResults,
                      style: context.sans(12.5, weight: FontWeight.w700, color: p.accentText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (courses.isEmpty)
                Text(l.elNoPublishedResults, style: context.sans(12, color: p.muted)),
              for (final co in courses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: co['total_percent'] == null ? p.muted : AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${asJson(co['course'])['name']}',
                          style: context.sans(13, weight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: co['total_percent'] == null
                              ? p.border.withValues(alpha: 0.5)
                              : AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          co['total_percent'] == null ? l.elPending : '${_n(co['total_percent'])}%',
                          style: context.sans(
                            12.5,
                            weight: FontWeight.w700,
                            color: co['total_percent'] == null ? p.muted : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Milestone Achievements Section
// -----------------------------------------------------------------------------
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.achievements});
  final List<Json> achievements;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: isEn ? 'Milestone Achievements' : 'ስኬቶች እና ባጆች'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievements.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final a = achievements[index];
            final earned = asBool(a['earned']);
            final title = isEn ? (asStr(a['title_en']) ?? asStr(a['title']) ?? '') : (asStr(a['title']) ?? '');
            final desc = isEn ? (asStr(a['desc_en']) ?? asStr(a['desc']) ?? '') : (asStr(a['desc']) ?? '');
            final iconKey = asStr(a['icon']);
            final icon = switch (iconKey) {
              'flag' => Icons.flag_rounded,
              'school' => Icons.school_rounded,
              'trophy' => Icons.emoji_events_rounded,
              'star' => Icons.workspace_premium_rounded,
              _ => Icons.military_tech_rounded,
            };

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: earned ? _warmCream : p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: earned ? const Color(0xFFE5DAC6) : p.border,
                  width: earned ? 1.1 : 0.9,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: earned ? _gold : p.border.withValues(alpha: 0.5),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: earned ? Colors.white : p.muted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: earned
                              ? AppColors.success.withValues(alpha: 0.12)
                              : p.border.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          earned
                              ? (isEn ? 'Earned' : 'ተሳክቷል')
                              : (isEn ? 'Locked' : 'በመጠበቅ ላይ'),
                          style: context.sans(
                            9.5,
                            weight: FontWeight.w700,
                            color: earned ? AppColors.success : p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.serif(12.5, weight: FontWeight.w700, color: earned ? _charcoal : p.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        desc,
                        style: context.sans(10, color: p.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Recent Activities Section
// -----------------------------------------------------------------------------
class _RecentActivitiesSection extends StatelessWidget {
  const _RecentActivitiesSection({required this.activities});
  final List<Json> activities;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: isEn ? 'Recent Activity' : 'የቅርብ ጊዜ እንቅስቃሴዎች'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          radius: 16,
          child: Column(
            children: [
              for (var i = 0; i < activities.length; i++) ...[
                if (i > 0) Divider(color: p.border, height: 1),
                Builder(
                  builder: (context) {
                    final item = activities[i];
                    final isQuiz = item['type'] == 'quiz_completed';
                    final title = asStr(item['title']) ?? '';
                    final subtitle = asStr(item['subtitle']);
                    final timeAgo = _formatTimeAgo(context, asStr(item['timestamp']));
                    final route = asStr(item['target_route']);

                    return InkWell(
                      onTap: route != null && route.isNotEmpty ? () => context.push(route) : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isQuiz
                                    ? _burgundy.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                isQuiz ? Icons.quiz_rounded : Icons.check_circle_rounded,
                                size: 18,
                                color: isQuiz ? _burgundy : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: context.sans(13, weight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitle != null && subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: context.sans(11, color: p.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (timeAgo.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                timeAgo,
                                style: context.sans(10.5, color: p.muted),
                              ),
                            ],
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.gold),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Loading Skeleton View
// -----------------------------------------------------------------------------
class _ProgressSkeletonLoading extends StatelessWidget {
  const _ProgressSkeletonLoading();

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
        const SizedBox(height: 16),
        shimmerBox(height: 84, radius: 16),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => shimmerBox(height: 70, radius: 16)),
        ),
        const SizedBox(height: 16),
        shimmerBox(height: 110, radius: 16),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _burgundy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.isEn ? 'Loading progress data...' : 'የትምህርት እድገት በመጫን ላይ...',
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
// Error View
// -----------------------------------------------------------------------------
class _ProgressErrorView extends StatelessWidget {
  const _ProgressErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: _burgundy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: _burgundy,
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
                  isEn ? 'Please check your connection and try again.' : 'እባክዎ የኢንተርኔት ግንኙነትዎን ያረጋግጡና እንደገና ይሞክሩ',
                  textAlign: TextAlign.center,
                  style: context.sans(12.5, color: p.muted),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(isEn ? 'Try Again' : 'እንደገና ሞክር'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _burgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// More: the rest of ትምህርት and the way to the other sections
// =============================================================================
class EduMoreScreen extends ConsumerWidget {
  const EduMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final access = user?.moduleAccess;
    return PatternScaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l.elTabMore), actions: const [ContextualHelpButton(screenRoute: '/edu/more')]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsGroup(title: l.hubEducation, children: [
            SettingsTile(key: const ValueKey('edu-more-library'), icon: Icons.local_library_rounded, label: l.libTitle, onTap: () => context.go('/edu/library')),
            SettingsTile(key: const ValueKey('edu-more-services'), icon: Icons.assignment_ind_outlined, label: l.eaSelfService, onTap: () => context.push('/edu/services')),
            SettingsTile(icon: Icons.timeline_rounded, label: l.eaJourney, onTap: () => context.push('/edu/services?tab=journey')),
            SettingsTile(icon: Icons.how_to_reg_rounded, label: l.eduRegister, onTap: () => context.push('/edu/register')),
            SettingsTile(icon: Icons.search_rounded, label: l.search, onTap: () => context.push('/edu/search')),
          ]),
          if (user != null && (user.isSuperAdmin || user.canAny([Perm.educationManage, Perm.educationRegister, Perm.educationContent, Perm.educationReports, Perm.educationCertify])))
            SettingsGroup(title: l.courseManagement, children: [
              SettingsTile(
                key: const ValueKey('edu-course-management'),
                icon: Icons.tune_rounded,
                label: l.courseManagement,
                onTap: () => context.push('/edu/manage'),
              ),
            ]),
          SettingsGroup(title: l.elOtherSections, children: [
            SettingsTile(key: const ValueKey('edu-more-programs'), icon: Icons.event_note_rounded, label: l.navPrograms, onTap: () => context.go('/programs')),
            if (access?.mezmur ?? true) SettingsTile(icon: Icons.music_note_rounded, label: l.hubMezmur, onTap: () => context.go('/home')),
            SettingsTile(key: const ValueKey('edu-more-settings'), icon: Icons.settings_rounded, label: l.navSettings, onTap: () => context.go('/settings?from=edu')),
            SettingsTile(icon: Icons.help_outline_rounded, label: l.elGuidanceCenter, onTap: () => context.push('/guidance')),
          ]),
        ],
      ),
    );
  }
}
