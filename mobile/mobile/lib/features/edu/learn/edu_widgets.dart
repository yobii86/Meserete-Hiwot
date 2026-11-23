import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../services/file_opening_service.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/file_preview.dart';
import '../../admin/edit_mode.dart';
import '../../auth/session.dart';
import 'content_admin.dart' show showEduCategoryEditor;
import 'edu_home.dart' show eduDashboardProvider;
import 'learn_screens.dart' show eduCategoriesProvider;

// =============================================================================
// Text helpers
// =============================================================================

/// The Amharic name with the English one under it ("የቤተ ክርስቲያን ታሪክ" / "Church History"), as in
/// the design. In English the order is reversed when an English name exists.
({String title, String? subtitle}) eduNames(
  BuildContext context,
  Json j, {
  String key = 'name',
}) {
  final am = asStr(j[key]) ?? '';
  final en = asStr(j['${key}_en']);
  final english = Localizations.localeOf(context).languageCode == 'en';
  if (en == null || en.isEmpty || en == am) return (title: am, subtitle: null);
  return english ? (title: en, subtitle: am) : (title: am, subtitle: en);
}

/// "፩" in Amharic, "1" in English.
String eduNumber(BuildContext context, int n) =>
    Localizations.localeOf(context).languageCode == 'am'
    ? ethiopicNumeral(n)
    : '$n';

/// Icon of a category until an administrator uploads its illustration.
IconData categoryIcon(String? key) => switch (key) {
  'bible' => Icons.menu_book_rounded,
  'church' => Icons.church_rounded,
  'censer' => Icons.local_fire_department_rounded,
  'saint' => Icons.portrait_rounded,
  'language' => Icons.translate_rounded,
  'doctrine' => Icons.auto_stories_rounded,
  'ethics' => Icons.volunteer_activism_rounded,
  'music' => Icons.music_note_rounded,
  _ => Icons.school_rounded,
};

const categoryIconKeys = [
  'bible',
  'church',
  'censer',
  'saint',
  'doctrine',
  'ethics',
  'language',
  'music',
  'school',
];

// =============================================================================
// Progress
// =============================================================================

/// Gold progress bar on a soft track (the design's "45% Completed" bar), from real counts only.
class EduProgressBar extends StatelessWidget {
  const EduProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.onDark = false,
    this.label,
    this.showPercentage = false,
  });
  final double value;
  final double height;
  final bool onDark;
  final String? label;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = value.clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: onDark ? Colors.white.withValues(alpha: 0.18) : (p.border),
          ),
          FractionallySizedBox(
            widthFactor: v,
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.eduGoldLight,
                    AppColors.eduGold,
                    AppColors.goldDark,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: label,
      value: '${(v * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null || showPercentage)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (label != null)
                    Expanded(
                      child: Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(
                          11.5,
                          weight: FontWeight.w600,
                          color: onDark ? Colors.white70 : p.muted,
                        ),
                      ),
                    ),
                  if (showPercentage)
                    Text(
                      '${(v * 100).round()}%',
                      style: context.sans(
                        11.5,
                        weight: FontWeight.w700,
                        color: onDark
                            ? AppColors.eduGoldLight
                            : AppColors.eduBurgundy,
                      ),
                    ),
                ],
              ),
            ),
          bar,
        ],
      ),
    );
  }
}

// =============================================================================
// Category card (2-column grid on the home and Learn pages)
// =============================================================================
class CategoryCard extends ConsumerWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});
  final Json category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final names = eduNames(context, category);
    final lessons = asIntOr(category['lesson_count']);
    final courses = asIntOr(category['course_count']);
    final image = asStr(category['image_url']);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF241A1C) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.eduBurgundy;

    final card = Semantics(
      button: true,
      label: names.title,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.eduGold.withValues(alpha: isDark ? 0.35 : 0.48),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.eduBurgundy.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.eduBurgundy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.eduGold.withValues(alpha: 0.35),
                            width: 0.9,
                          ),
                        ),
                        child: image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CoverImage(
                                  url: image,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                categoryIcon(asStr(category['icon_key'])),
                                color: AppColors.eduBurgundy,
                                size: 20,
                              ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.eduGold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.eduGold.withValues(alpha: 0.38),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_stories_rounded,
                              size: 11,
                              color: AppColors.goldDark,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lessons > 0
                                  ? '$lessons'
                                  : (courses > 0 ? '$courses' : '0'),
                              style: context.sans(
                                10,
                                weight: FontWeight.w700,
                                color: AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            names.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.serif(
                              13,
                              weight: FontWeight.w700,
                              color: titleColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (names.subtitle != null) ...[
                          const SizedBox(height: 1),
                          Flexible(
                            child: Text(
                              names.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(10.5, color: p.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    lessons > 0
                        ? l.elLessonCount(lessons)
                        : (courses > 0 ? '$courses courses' : l.elNoLessonsYet),
                    style: context.sans(10.5, color: p.subtle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return EditOverlay(
      permission: Perm.educationContent,
      left: 6,
      top: 6,
      onEdit: () async {
        final saved = await showEduCategoryEditor(context, category: category);
        if (saved == true) {
          ref.invalidate(eduCategoriesProvider);
          ref.invalidate(eduDashboardProvider);
          ref.read(contentRevisionProvider.notifier).bump();
        }
      },
      child: card,
    );
  }
}

/// Responsive grid of category cards (2 columns on phones, more on tablets / web).
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.categories, this.max});
  final List<Json> categories;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final items = max == null ? categories : categories.take(max!).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          // Taller with larger system text, so names and counts keep fitting.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: MediaQuery.textScalerOf(
              context,
            ).scale(152).clamp(152.0, 260.0),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => CategoryCard(
            category: items[i],
            onTap: () => context.push('/edu/learn/category/${items[i]['id']}'),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Featured banner (administrator-chosen subject / lesson / class)
// =============================================================================
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.items});
  final List<Json> items;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      children: [
        SizedBox(
          // Taller with larger system text, so the title and the button keep fitting without overlap.
          height: MediaQuery.textScalerOf(
            context,
          ).scale(186).clamp(186.0, 300.0),
          child: PageView.builder(
            controller: _page,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FeaturedCard(item: items[i]),
            ),
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.eduGold
                          : AppColors.eduGold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.item});
  final Json item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = asJson(item['target']);
    final route = asStr(target['route']);
    final progress = asJson(target['progress']);
    final position = asInt(target['position']);
    final total = asInt(target['total']) ?? asInt(progress['total']);
    final started = asIntOr(progress['completed']) > 0;
    final image = asStr(item['image_url']);
    // "Lesson 1 of 12" for a lesson, "3 of 12 done" for a subject — real counts only.
    final where = position != null && total != null && total > 0
        ? l.elPositionOf(
            eduNumber(context, position),
            eduNumber(context, total),
          )
        : (total != null && total > 0
              ? (started
                    ? l.elDoneOf(
                        eduNumber(context, asIntOr(progress['completed'])),
                        eduNumber(context, total),
                      )
                    : l.elLessonCount(total))
              : null);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.eduBurgundy, AppColors.eduBurgundyDark],
        ),
        border: Border.all(
          color: AppColors.eduGold.withValues(alpha: 0.45),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundyDark.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: route == null ? null : () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.eduGold.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.eduGoldLight.withValues(
                              alpha: 0.4,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          l.elFeaturedLabel,
                          style: context.sans(
                            10,
                            weight: FontWeight.w700,
                            color: AppColors.eduGoldLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                asStr(item['title']) ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.serif(
                                  15.5,
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (asStr(item['subtitle']) != null) ...[
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  asStr(item['subtitle'])!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.sans(
                                    11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.eduGold,
                              foregroundColor: AppColors.eduBurgundyDark,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: route == null
                                ? null
                                : () => context.push(route),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                            ),
                            label: Text(
                              started ? l.elContinue : l.elStart,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (where != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                where,
                                style: context.sans(
                                  11,
                                  color: AppColors.eduGoldLight,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.eduGold.withValues(alpha: 0.4),
                        width: 1.1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: image != null
                          ? CoverImage(url: image, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(
                                Icons.auto_stories_rounded,
                                size: 44,
                                color: AppColors.eduGoldLight,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Continue learning
// =============================================================================
class ContinueLearningCard extends StatelessWidget {
  const ContinueLearningCard({super.key, required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final progress = asJson(data['progress']);
    final total = asIntOr(progress['total']);
    final done = asIntOr(progress['completed']);
    final names = eduNames(context, {
      'name': data['subject_name'],
      'name_en': data['subject_name_en'],
    });
    final coverUrl = asStr(data['cover_url']);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/edu/learn/lesson/${data['lesson_id']}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF650D20).withValues(alpha: 0.08),
                          border: Border.all(color: const Color(0xFFC6A044).withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.auto_stories_rounded,
                                  color: Color(0xFF650D20),
                                  size: 26,
                                ),
                              )
                            : const Icon(
                                Icons.auto_stories_rounded,
                                color: Color(0xFF650D20),
                                size: 26,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            asStr(data['lesson_title']) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.serif(14.5, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            names.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.sans(11.5, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF650D20),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF650D20).withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            l.isEn ? 'Continue' : 'ቀጥል',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (done / total).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: p.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC6A044)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.elPercentDone((done * 100 / total).floor()),
                        style: context.sans(11, color: const Color(0xFFC6A044), weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Lesson row (subject page): number / check / lock, title, status, minutes
// =============================================================================
class LessonTile extends ConsumerWidget {
  const LessonTile({
    super.key,
    required this.lesson,
    required this.number,
    this.onTap,
    this.editing = false,
  });
  final Json lesson;
  final int number;
  final VoidCallback? onTap;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final completed = asBool(lesson['completed']);
    final opened = asBool(lesson['opened']);
    final locked = asBool(lesson['locked']);
    final status = asStr(lesson['status']) ?? 'published';
    final minutes = asInt(lesson['est_minutes']);
    final lessonId = asIntOr(lesson['id']);

    final session = ref.watch(sessionProvider);
    final canBypass =
        (session is SignedIn &&
            (session.user.can(Perm.educationContent) ||
                session.user.can(Perm.educationManage) ||
                session.user.isSuperAdmin)) ||
        editing;

    void showLockedDialog() {
      final requiresQuiz = asBool(lesson['requires_quiz']);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.lock_rounded,
            size: 40,
            color: AppColors.goldDark,
          ),
          title: Text(l.elLocked, textAlign: TextAlign.center),
          content: Text(
            requiresQuiz
                ? (l.isEn
                      ? 'This lesson is locked. Complete the previous lesson and pass the required quiz to unlock it.'
                      : 'ይህ ትምህርት የተቆለፈ ነው፦ ለመክፈት ቀዳሚውን ትምህርት ማጠናቀቅ እና አስፈላጊውን ፈተና ማለፍ ይኖርብዎታል።')
                : l.errLessonLocked,
            textAlign: TextAlign.center,
            style: ctx.sans(14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.ok),
            ),
          ],
        ),
      );
    }

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: locked
            ? p.fill
            : (completed
                  ? AppColors.success.withValues(alpha: 0.15)
                  : (opened
                        ? AppColors.eduBurgundy.withValues(alpha: 0.12)
                        : p.pill)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: locked
              ? p.border
              : (completed
                    ? AppColors.success.withValues(alpha: 0.4)
                    : (opened
                          ? AppColors.eduBurgundy.withValues(alpha: 0.4)
                          : AppColors.eduGold.withValues(alpha: 0.35))),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: locked
          ? Icon(Icons.lock_rounded, size: 20, color: p.faint)
          : completed
          ? const Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: AppColors.success,
            )
          : (opened
                ? const Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: AppColors.eduBurgundy,
                  )
                : Text(
                    eduNumber(context, number),
                    style: context.serif(
                      16,
                      weight: FontWeight.w700,
                      color: AppColors.goldDark,
                    ),
                  )),
    );
    final tile = Opacity(
      opacity: locked ? 0.72 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: locked ? p.fill.withValues(alpha: 0.6) : p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: completed
                  ? AppColors.success.withValues(alpha: 0.25)
                  : (locked
                        ? p.border
                        : AppColors.eduGold.withValues(alpha: 0.4)),
              width: 1.2,
            ),
            boxShadow: locked
                ? null
                : [
                    BoxShadow(
                      color: AppColors.eduBurgundy.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: (locked && !canBypass) ? showLockedDialog : onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asStr(lesson['title']) ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.serif(14.5, height: 1.3),
                          ),
                          if (asStr(lesson['summary']) != null)
                            Text(
                              asStr(lesson['summary'])!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(12, color: p.muted),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (editing && status != 'published')
                                Pill(
                                  status == 'draft'
                                      ? l.elStatusDraft
                                      : l.elStatusArchived,
                                  color: AppColors.warning,
                                  background: AppColors.warning.withValues(
                                    alpha: 0.12,
                                  ),
                                )
                              else if (completed)
                                Pill(
                                  l.elCompleted,
                                  icon: Icons.check_rounded,
                                  color: AppColors.success,
                                  background: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                )
                              else if (locked)
                                Pill(
                                  l.elLocked,
                                  icon: Icons.lock_rounded,
                                  color: p.muted,
                                  background: p.fillStrong,
                                )
                              else if (opened)
                                Pill(l.elInProgress),
                              if (minutes != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: p.subtle,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      l.elMinutes(minutes),
                                      style: context.sans(
                                        11.5,
                                        color: p.subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              if (asIntOr(lesson['material_count']) > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.attach_file_rounded,
                                      size: 13,
                                      color: p.subtle,
                                    ),
                                    Text(
                                      '${asIntOr(lesson['material_count'])}',
                                      style: context.sans(
                                        11.5,
                                        color: p.subtle,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!locked || canBypass)
                      Icon(Icons.chevron_right_rounded, color: p.faint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return EditOverlay(
      permission: Perm.educationContent,
      isTeacherOwner: editing,
      onEdit: () =>
          openAdminEditor(context, ref, '/edu/content/lesson/$lessonId'),
      child: tile,
    );
  }
}

// =============================================================================
// Quiz card (home "This week", subject / class pages)
// =============================================================================
class QuizCard extends StatelessWidget {
  const QuizCard({super.key, required this.quiz, this.compact = false});
  final Json quiz;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final closes = asDate(quiz['closes_at']);
    final availability = asStr(quiz['availability']);
    final inProgress = asInt(quiz['in_progress_attempt_id']) != null;
    final left = asIntOr(quiz['attempts_left']);
    final score = quiz['my_score'];
    final status = switch (availability) {
      'upcoming' => l.elQuizUpcoming,
      'closed' => l.elQuizClosed,
      _ =>
        inProgress
            ? l.elQuizInProgress
            : (left > 0 ? l.elQuizOpen : l.elQuizDone),
    };
    return AppCard(
      onTap: () => context.push('/edu/quiz/${quiz['id']}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.pill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: AppColors.maroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asStr(quiz['title']) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.serif(14.5),
                ),
                Text(
                  asStr(quiz['course_name']) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.sans(12, color: p.muted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Pill(status),
                    if (closes != null && availability != 'closed')
                      Pill(
                        l.elDue(f.date(closes, withWeekday: true)),
                        icon: Icons.schedule_rounded,
                      ),
                    if (score != null)
                      Pill(
                        l.elQuizScore(
                          '${_n(score)}/${_n(quiz['my_max_score'])}',
                        ),
                        color: AppColors.success,
                        background: AppColors.success.withValues(alpha: 0.12),
                      ),
                    if (asBool(quiz['score_hidden']))
                      Pill(l.elScorePending, icon: Icons.hourglass_top_rounded),
                    if (asBool(quiz['official']) && !compact)
                      Pill(l.elOfficialQuiz, icon: Icons.verified_outlined),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.faint),
        ],
      ),
    );
  }

  static String _n(Object? v) {
    final d = asDouble(v);
    return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
  }
}

// =============================================================================
// Empty state with an action (new students, nothing this week…)
// =============================================================================
class EduEmptyCard extends StatelessWidget {
  const EduEmptyCard({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldDark, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.sans(13, color: p.muted, height: 1.5),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Lesson text: simple formatting (no HTML — nothing can be injected)
//   "# Heading", "## Smaller heading", "> Quote / scripture", "- item" (or "• item"),
//   a blank line starts a new paragraph.
// =============================================================================
enum LessonBlockType { heading, subheading, quote, bullet, paragraph }

class LessonBlock {
  const LessonBlock(this.type, this.text);
  final LessonBlockType type;
  final String text;
}

List<LessonBlock> parseLessonBody(String? body) {
  if (body == null || body.trim().isEmpty) return const [];
  final out = <LessonBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isNotEmpty) {
      out.add(LessonBlock(LessonBlockType.paragraph, para.join(' ')));
    }
    para.clear();
  }

  for (final raw in body.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      out.add(
        LessonBlock(LessonBlockType.subheading, line.substring(3).trim()),
      );
    } else if (line.startsWith('# ')) {
      flush();
      out.add(LessonBlock(LessonBlockType.heading, line.substring(2).trim()));
    } else if (line.startsWith('> ')) {
      flush();
      out.add(LessonBlock(LessonBlockType.quote, line.substring(2).trim()));
    } else if (line.startsWith('- ') ||
        line.startsWith('• ') ||
        line.startsWith('* ')) {
      flush();
      out.add(LessonBlock(LessonBlockType.bullet, line.substring(2).trim()));
    } else {
      para.add(line);
    }
  }
  flush();
  return out;
}

class LessonBody extends StatelessWidget {
  const LessonBody({super.key, required this.body, this.scale = 1});
  final String? body;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final blocks = parseLessonBody(body);
    final firstParagraph = blocks.indexWhere(
      (b) => b.type == LessonBlockType.paragraph,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in blocks.indexed)
          switch (b.type) {
            LessonBlockType.heading => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                b.text,
                style: context.serif(19 * scale, color: p.primary),
              ),
            ),
            LessonBlockType.subheading => Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                b.text,
                style: context.serif(16 * scale, color: p.text),
              ),
            ),
            LessonBlockType.quote => Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                b.text,
                style: context
                    .serif(
                      15 * scale,
                      weight: FontWeight.w500,
                      color: p.text,
                      height: 1.6,
                    )
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            LessonBlockType.bullet => Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8 * scale),
                    child: const Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.text,
                      style: context.serif(
                        15 * scale,
                        weight: FontWeight.w400,
                        height: 1.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            LessonBlockType.paragraph => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: i == firstParagraph
                  ? _DropCap(text: b.text, scale: scale)
                  : Text(
                      b.text,
                      style: context.serif(
                        15 * scale,
                        weight: FontWeight.w400,
                        height: 1.75,
                      ),
                    ),
            ),
          },
      ],
    );
  }
}

/// The first paragraph opens with a large maroon letter, as in the design's lesson page.
class _DropCap extends StatelessWidget {
  const _DropCap({required this.text, required this.scale});
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final first = String.fromCharCodes(text.runes.take(1));
    final rest = String.fromCharCodes(text.runes.skip(1));
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: first,
            style: context.serif(
              30 * scale,
              color: AppColors.maroon,
              height: 1,
            ),
          ),
          TextSpan(
            text: rest,
            style: context.serif(
              15 * scale,
              weight: FontWeight.w400,
              height: 1.75,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Materials
// =============================================================================
IconData materialIcon(Json m) {
  if (m['kind'] == 'video_link') return Icons.ondemand_video_rounded;
  if (m['kind'] == 'link') return Icons.link_rounded;
  return switch (fileKindOf(asStr(m['name']) ?? '', asStr(m['mime']))) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'image' => Icons.image_rounded,
    'audio' => Icons.headphones_rounded,
    'video' => Icons.movie_rounded,
    _ => Icons.insert_drive_file_rounded,
  };
}

/// Open a lesson material: a link in the browser / YouTube app; a file is downloaded with the
/// Unified material opener: files download and open via [FileOpeningService] with caching,
/// offline support, and in-app preview; external links open via launcher.
Future<void> openMaterial(BuildContext context, WidgetRef ref, Json m) async {
  final l = context.l10n;
  if (m['kind'] != 'file') {
    final url = Uri.tryParse(asStr(m['url']) ?? '');
    if (url == null || !(url.scheme == 'https' || url.scheme == 'http')) {
      return showSnack(context, l.elBadLink);
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
    return;
  }
  final id = asIntOr(m['id']);
  final name = asStr(m['name']) ?? asStr(m['title']) ?? 'file';
  final mime = asStr(m['mime']);
  await ref.read(fileOpeningServiceProvider).openFile(
    context,
    source: '/edu/materials/$id/file',
    filename: name,
    mime: mime,
  );
}

class MaterialTile extends ConsumerWidget {
  const MaterialTile({super.key, required this.material, this.trailing});
  final Json material;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final size = asInt(material['size']);
    final kind = asStr(material['kind']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => openMaterial(context, ref, material),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(materialIcon(material), color: AppColors.maroon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asStr(material['title']) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(14, weight: FontWeight.w600),
                  ),
                  Text(
                    kind == 'file'
                        ? [
                            if (asStr(material['name']) != null)
                              asStr(material['name'])!,
                            if (size != null) _size(size),
                          ].join(' · ')
                        : (kind == 'video_link' ? l.elVideoLink : l.elWebLink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.sans(11.5, color: p.muted),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  kind == 'file'
                      ? Icons.download_rounded
                      : Icons.open_in_new_rounded,
                  color: p.faint,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  static String _size(int b) => b >= 1048576
      ? '${(b / 1048576).toStringAsFixed(1)} MB'
      : '${(b / 1024).ceil()} KB';
}

// =============================================================================
// Section Header
// =============================================================================
class EduSectionHeader extends StatelessWidget {
  const EduSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: context.serif(
                          17,
                          weight: FontWeight.w700,
                          color: p.primary,
                        ),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.eduGold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.eduGold.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: context.sans(
                            11,
                            weight: FontWeight.w700,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.sans(12, color: p.muted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.goldDark,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: context.sans(12.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Course & Lesson Hero Header
// =============================================================================
class EduHeroHeader extends StatelessWidget {
  const EduHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.categoryName,
    this.progressValue,
    this.progressLabel,
    this.badges = const [],
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? categoryName;
  final double? progressValue;
  final String? progressLabel;
  final List<Widget> badges;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.eduBurgundy,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.eduBurgundy, AppColors.eduBurgundyDark],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundyDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.08,
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 180,
                  color: AppColors.eduGoldLight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.eduGold.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.eduGoldLight.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        categoryName!,
                        style: context.sans(
                          11.5,
                          weight: FontWeight.w700,
                          color: AppColors.eduGoldLight,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.serif(
                      22,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.sans(
                        13,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 6, children: badges),
                  ],
                  if (progressValue != null) ...[
                    const SizedBox(height: 14),
                    EduProgressBar(
                      value: progressValue!,
                      height: 7,
                      onDark: true,
                      label: progressLabel,
                      showPercentage: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Quiz Result Hero Card
// =============================================================================
class EduResultHeroCard extends StatelessWidget {
  const EduResultHeroCard({
    super.key,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.passed,
    this.quizTitle,
    this.timeSpentText,
    this.onReview,
    this.onRetake,
  });

  final double score;
  final double maxScore;
  final double percentage;
  final bool passed;
  final String? quizTitle;
  final String? timeSpentText;
  final VoidCallback? onReview;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final resultTitle = passed
        ? (isEn ? 'Congratulations! You Passed' : 'እንኳን ደስ አለዎት! ፈተናውን አልፈዋል')
        : (isEn ? 'Needs More Study' : 'ተጨማሪ ጥናት ያስፈልጋል');
    final resultSubtitle = passed
        ? (isEn
              ? 'You demonstrated a solid understanding of the material.'
              : 'የትምህርቱን ጽንሰ-ሐሳብ በሚገባ ተረድተውታል።')
        : (isEn
              ? 'Review the lessons and try again to improve your score.'
              : 'ትምህርቱን ደግመው በማንበብ ውጤትዎን ያሻሽሉ።');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.eduBurgundy,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: passed
              ? const [AppColors.eduBurgundy, AppColors.eduBurgundyDark]
              : const [Color(0xFF5A1D28), Color(0xFF381017)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.eduGold.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundyDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                passed
                    ? Icons.emoji_events_rounded
                    : Icons.auto_stories_rounded,
                size: 160,
                color: AppColors.eduGoldLight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: passed
                        ? AppColors.eduGold.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: passed ? AppColors.eduGoldLight : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                    color: passed ? AppColors.eduGoldLight : Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  resultTitle,
                  textAlign: TextAlign.center,
                  style: context.serif(
                    20,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resultSubtitle,
                  textAlign: TextAlign.center,
                  style: context.sans(
                    12.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.eduGold.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: isEn ? 'SCORE' : 'ውጤት',
                        value: '${_fmt(score)} / ${_fmt(maxScore)}',
                      ),
                      Container(height: 28, width: 1, color: Colors.white12),
                      _StatColumn(
                        label: isEn ? 'ACCURACY' : 'ትክክለኛነት',
                        value: '${percentage.round()}%',
                        valueColor: passed
                            ? AppColors.eduGoldLight
                            : Colors.white,
                      ),
                      if (timeSpentText != null) ...[
                        Container(height: 28, width: 1, color: Colors.white12),
                        _StatColumn(
                          label: isEn ? 'TIME' : 'የፈጀው ጊዜ',
                          value: timeSpentText!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onReview != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReview,
                          icon: const Icon(Icons.rule_folder_rounded, size: 18),
                          label: Text(isEn ? 'Review Answers' : 'መልሶችን ይከልሱ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: AppColors.eduGoldLight,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (onReview != null && onRetake != null)
                      const SizedBox(width: 10),
                    if (onRetake != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onRetake,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(isEn ? 'Retake Quiz' : 'እንደገና ይፈተኑ'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.eduGold,
                            foregroundColor: AppColors.eduBurgundyDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.sans(
            10,
            weight: FontWeight.w700,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.sans(
            16,
            weight: FontWeight.w700,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Scripture / Quote Callout (Ethiopian Orthodox Educational Style)
// =============================================================================
class ScriptureCallout extends StatelessWidget {
  const ScriptureCallout({
    super.key,
    required this.verse,
    this.reference,
    this.onTap,
  });

  final String verse;
  final String? reference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceHigh : AppColors.eduCream,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: AppColors.eduGold, width: 4),
          top: BorderSide(
            color: AppColors.eduGold.withValues(alpha: 0.25),
            width: 0.8,
          ),
          right: BorderSide(
            color: AppColors.eduGold.withValues(alpha: 0.25),
            width: 0.8,
          ),
          bottom: BorderSide(
            color: AppColors.eduGold.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundy.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.church_rounded,
                      size: 16,
                      color: AppColors.goldDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'የእግዚአብሔር ቃል / Scripture',
                      style: context.sans(
                        11,
                        weight: FontWeight.w700,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '« $verse »',
                  style: context
                      .serif(
                        14.5,
                        weight: FontWeight.w500,
                        color: p.text,
                        height: 1.6,
                      )
                      .copyWith(fontStyle: FontStyle.italic),
                ),
                if (reference != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— $reference',
                      style: context.serif(
                        12.5,
                        weight: FontWeight.w700,
                        color: AppColors.eduBurgundy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Timetable Schedule Row (for My Classes & Timetable)
// =============================================================================
class TimetableScheduleRow extends StatelessWidget {
  const TimetableScheduleRow({
    super.key,
    required this.time,
    required this.title,
    this.instructor,
    this.room,
    this.status = 'upcoming',
    this.onTap,
  });

  final String time;
  final String title;
  final String? instructor;
  final String? room;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLive = status == 'live' || status == 'in_session';
    final isDone = status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive
                ? AppColors.eduGold
                : (isDone
                      ? p.border
                      : AppColors.eduGold.withValues(alpha: 0.35)),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.eduBurgundy.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isLive
                          ? AppColors.eduBurgundy
                          : (isDone
                                ? p.fill
                                : AppColors.eduGold.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLive
                              ? Icons.sensors_rounded
                              : (isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded),
                          size: 16,
                          color: isLive
                              ? AppColors.eduGoldLight
                              : (isDone ? p.muted : AppColors.goldDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          textAlign: TextAlign.center,
                          style: context.sans(
                            10.5,
                            weight: FontWeight.w700,
                            color: isLive
                                ? Colors.white
                                : (isDone ? p.muted : p.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.serif(
                            14.5,
                            weight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (instructor != null) ...[
                              Icon(
                                Icons.person_outline_rounded,
                                size: 13,
                                color: p.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  instructor!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.sans(11.5, color: p.muted),
                                ),
                              ),
                            ],
                            if (room != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: p.pill,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: p.border,
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  room!,
                                  style: context.sans(
                                    10.5,
                                    weight: FontWeight.w600,
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Edu Skeleton Loader
// =============================================================================
class EduSkeletonLoader extends StatelessWidget {
  const EduSkeletonLoader({super.key, this.itemCount = 3, this.height = 76});
  final int itemCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: p.fill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 140,
                        decoration: BoxDecoration(
                          color: p.fill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Edu Error & Retry Card
// =============================================================================
class EduErrorStateCard extends StatelessWidget {
  const EduErrorStateCard({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.eduGold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              color: AppColors.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.sans(13.5, color: p.text, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l.retry),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.goldDark,
                side: const BorderSide(color: AppColors.eduGold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
