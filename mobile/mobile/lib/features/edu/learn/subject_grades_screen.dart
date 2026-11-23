import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import '../../auth/session.dart';

final subjectGradesProvider =
    FutureProvider.autoDispose.family<Json, int>((ref, subjectId) {
  return ref.watch(eduRepositoryProvider).subjectGrades(subjectId);
});

class EduSubjectGradesScreen extends ConsumerWidget {
  const EduSubjectGradesScreen({super.key, required this.subjectId});
  final int subjectId;

  static const _subjectIcons = <int, IconData>{
    1: Icons.church_rounded,
    2: Icons.church_rounded,
    3: Icons.history_edu_rounded,
    4: Icons.menu_book_rounded,
    5: Icons.favorite_rounded,
    6: Icons.account_balance_rounded,
    7: Icons.translate_rounded,
    8: Icons.music_note_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final asyncData = ref.watch(subjectGradesProvider(subjectId));

    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/edu');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: PatternScaffold(
        appBar: AppBar(
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l.isEn ? 'Back to subjects' : 'ወደ የትምህርት ዓይነቶች ተመለስ',
            onPressed: handleBack,
          ),
          title: Text(
            isEn ? 'Select Grade' : 'ክፍል ይምረጡ',
            style: context.serif(18, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
        body: AsyncView<Json>(
          value: asyncData,
          onRetry: () => ref.invalidate(subjectGradesProvider(subjectId)),
          data: (data) {
            final subject = data['subject'] is Map ? asJson(data['subject']) : <String, dynamic>{};
            final subjectName = asStr(subject['name']) ?? (isEn ? 'Subject' : 'የትምህርት ዓይነት');
            final subjectDesc = asStr(subject['description']);
            final grades = asJsonList(data['grades']);
            final assignedGrades = grades.where((g) => asBool(g['is_assigned']) == true).toList();
            final session = ref.watch(sessionProvider);
            final isStaff = session is SignedIn &&
                (session.user.can(Perm.educationManage) ||
                    session.user.can(Perm.educationContent) ||
                    session.user.isSuperAdmin);

            // Automatically navigate directly to student's enrolled grade learning materials
            if (!isStaff && assignedGrades.length == 1) {
              final gNum = asInt(assignedGrades.first['grade_number']) ??
                  asInt(assignedGrades.first['number']);
              if (gNum != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.pushReplacement('/edu/subject/$subjectId/grade/$gNum');
                  }
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: AppColors.maroon)),
                );
              }
            }

            final displayGrades = isStaff ? grades : (assignedGrades.isNotEmpty ? assignedGrades : grades);
            final icon = _subjectIcons[subjectId] ?? Icons.menu_book_rounded;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Header Hero Card (Church theme)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.maroon, AppColors.maroonDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.maroonDark.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.goldLight, width: 1.5),
                        ),
                        child: Icon(icon, color: AppColors.goldLight, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: context.serif(
                                19,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subjectDesc != null && subjectDesc.isNotEmpty
                                  ? subjectDesc
                                  : (isEn
                                      ? 'Choose a grade (1 to 12) to view lessons and materials'
                                      : 'ትምህርቶችንና ማጣቀሻዎችን ለማየት ከ1ኛ እስከ 12ኛ ክፍል ይምረጡ'),
                              style: context.sans(12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Section title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 18, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Grades (1 - 12)' : 'ክፍሎች (ከ1ኛ እስከ 12ኛ ክፍል)',
                        style: context.serif(15, weight: FontWeight.w700, color: AppColors.maroon),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Unassigned grade notice if student/admin has no assigned grades
                if (grades.every((g) => asBool(g['is_assigned']) != true)) ...[
                  Builder(
                    builder: (context) {
                      final session = ref.watch(sessionProvider);
                      final isAdmin = session is SignedIn &&
                          (session.user.can(Perm.educationManage) ||
                              session.user.can(Perm.educationContent) ||
                              session.user.isSuperAdmin);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.maroon.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.maroon, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.elNoAssignedGradeTitle,
                                    style: context.sans(13, weight: FontWeight.w700, color: AppColors.maroon),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l.elNoAssignedGradeDesc,
                                    style: context.sans(11.5, color: context.palette.muted),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l.elAdminPanelHint,
                                      style: context.sans(11.5, color: AppColors.goldDark, weight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                // 12 Grades Grid / List
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 600;
                    final crossAxisCount = isTablet ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: isTablet ? 1.4 : 1.25,
                      ),
                      itemCount: displayGrades.length,
                      itemBuilder: (context, index) {
                        final g = displayGrades[index];
                        final gradeNum = asInt(g['grade_number']) ?? asInt(g['number']) ?? (index + 1);
                        final gradeName = asStr(g['grade_name']) ?? asStr(g['name']) ?? '$gradeNumኛ ክፍል';
                        final hasContent = asBool(g['has_content']);
                        final coursesCount = asIntOr(g['courses_count']);
                        final lessonsCount = asIntOr(g['lessons_count']);
                        final materialsCount = asIntOr(g['materials_count']);
                        final quizzesCount = asIntOr(g['quizzes_count']);
                        final totalItems = coursesCount + lessonsCount + materialsCount + quizzesCount;

                        final canOpen = g['can_open'] == null ? true : asBool(g['can_open']);
                        final isAssigned = asBool(g['is_assigned']);

                        return AppCard(
                          onTap: () {
                            if (!canOpen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEn
                                      ? 'Access restricted: You are not enrolled in $gradeName.'
                                      : 'ይቅርታ፣ በ$gradeName አልተመደቡም።'),
                                  backgroundColor: AppColors.maroon,
                                ),
                              );
                              return;
                            }
                            context.push('/edu/subject/$subjectId/grade/$gradeNum');
                          },
                          padding: const EdgeInsets.all(12),
                          radius: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Grade circle badge
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: !canOpen
                                          ? context.palette.pill
                                          : hasContent
                                              ? AppColors.maroon.withValues(alpha: 0.1)
                                              : context.palette.pill,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isAssigned
                                            ? AppColors.gold
                                            : canOpen && hasContent
                                                ? AppColors.gold.withValues(alpha: 0.6)
                                                : context.palette.border,
                                        width: isAssigned ? 1.6 : 1.2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$gradeNum',
                                      style: context.serif(
                                        15,
                                        weight: FontWeight.w700,
                                        color: canOpen && hasContent
                                            ? AppColors.maroon
                                            : context.palette.muted,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    canOpen
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 14,
                                    color: canOpen && hasContent ? AppColors.gold : context.palette.subtle,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gradeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.serif(
                                      14.5,
                                      weight: FontWeight.w700,
                                      color: canOpen ? context.palette.text : context.palette.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (isAssigned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.gold,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isEn ? 'Enrolled' : 'የእርስዎ ክፍል',
                                        style: context.sans(
                                          10.5,
                                          weight: FontWeight.w700,
                                          color: AppColors.maroon,
                                        ),
                                      ),
                                    )
                                  else if (hasContent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: canOpen
                                            ? AppColors.gold.withValues(alpha: 0.15)
                                            : context.palette.pill,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.gold.withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isEn ? '$totalItems items' : '$totalItems ይዘቶች',
                                        style: context.sans(
                                          10.5,
                                          weight: FontWeight.w600,
                                          color: canOpen ? AppColors.maroon : context.palette.muted,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      isEn ? 'Empty' : 'ይዘት የለም',
                                      style: context.sans(11, color: context.palette.muted),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
