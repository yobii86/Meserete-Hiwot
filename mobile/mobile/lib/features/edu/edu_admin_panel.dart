import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/chrome.dart' show EduIcon;
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart' show Perm;
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../auth/session.dart' show currentUserProvider;
import '../guidance/contextual_help_sheet.dart';

/// Structured Education Admin Panel (Task 7).
/// Accessible only to authorized administrators/teachers.
class EduAdminPanelScreen extends ConsumerWidget {
  const EduAdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = l.isEn;
    final user = ref.watch(currentUserProvider);

    final isAuthorized = user != null &&
        (user.isSuperAdmin ||
            user.canAny([
              Perm.educationManage,
              Perm.educationView,
              Perm.educationClasses,
              Perm.educationCurriculum,
              Perm.educationLessons,
              Perm.educationMaterials,
              Perm.educationQuizzes,
              Perm.educationExams,
              Perm.educationAssessments,
              Perm.educationMarks,
              Perm.educationAttendanceView,
              Perm.educationSettings,
              Perm.educationRegister,
              Perm.educationContent,
              Perm.educationReports,
              Perm.educationCertify,
              Perm.borrowingManage,
              Perm.libraryCirculate,
            ]));

    if (!isAuthorized) {
      return PatternScaffold(
        appBar: AppBar(title: Text(isEn ? 'Education Admin' : 'የትምህርት አስተዳደር')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              message: isEn
                  ? 'Access restricted. Administrator privileges required.'
                  : 'ይህን ገጽ ለማየት የአስተዳዳሪ ፈቃድ ያስፈልጋል።',
            ),
          ),
        ),
      );
    }

    final sections = <_AdminSection>[
      // 1. Education Management
      _AdminSection(
        title: isEn ? 'Education Management' : 'የትምህርት ይዘት አስተዳደር',
        subtitle: isEn
            ? 'Curriculum, categories, subjects, units, lessons and quizzes'
            : 'የትምህርት ዓይነቶች፣ ምድቦች፣ ምዕራፎች፣ ትምህርቶች እና ፈተናዎች',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF1F5F8B),
        cards: [
          _AdminCard(
            title: isEn ? 'Categories & Subjects' : 'ምድቦች እና የትምህርት ዓይነቶች',
            subtitle: isEn ? 'Organize educational departments' : 'የትምህርት ዘርፎችን ያደራጁ',
            icon: Icons.category_rounded,
            route: '/edu/content',
            permissions: const [Perm.educationCurriculum, Perm.educationContent, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Learning Materials' : 'የትምህርት ግብዓቶችና ሰነዶች',
            subtitle: isEn ? 'Manage PDF guides & multimedia' : 'የድምጽ፣ ምስልና የፒዲኤፍ ማጣቀሻዎች',
            icon: Icons.attach_file_rounded,
            route: '/edu/content/materials',
            permissions: const [Perm.educationMaterials, Perm.educationContent, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Quizzes & Assessments' : 'ፈተናዎች እና ጥያቄዎች',
            subtitle: isEn ? 'Questions, tests & grading criteria' : 'የክለሳ ጥያቄዎችና የማለፊያ መስፈርቶች',
            icon: Icons.quiz_rounded,
            route: '/edu/admin/quizzes',
            permissions: const [Perm.educationQuizzes, Perm.educationExams, Perm.educationContent, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'ሰሌዳ መጽሔት (Seleda Magazine)' : 'ሰሌዳ መጽሔት',
            subtitle: isEn ? 'Issues, publications & linked quizzes' : 'እትሞች፣ ጽሑፎች እና ተዛማጅ ፈተናዎች',
            icon: Icons.menu_book_rounded,
            route: '/edu/admin/magazines',
            permissions: const [Perm.educationContent, Perm.educationManage],
          ),
        ],
      ),

      // 2. Academic Administration
      _AdminSection(
        title: isEn ? 'Academic Administration' : 'አካዳሚክ አስተዳደር',
        subtitle: isEn
            ? 'Classes, teacher assignment, student enrollment and terms'
            : 'ክፍሎች፣ የአስተማሪዎች ምደባ፣ የተማሪዎች ምዝገባ እና የትምህርት ዘመን',
        icon: Icons.school_rounded,
        color: AppColors.maroon,
        cards: [
          _AdminCard(
            title: isEn ? 'Canonical Grades (1–12)' : 'ቀኖናዊ ክፍሎች (1–12)',
            subtitle: isEn ? 'Manage grades 1–12, names and status' : 'ከ1ኛ እስከ 12ኛ ክፍሎችን እና ሁኔታቸውን ያስተዳድሩ',
            icon: Icons.format_list_numbered_rounded,
            route: '/edu/admin/grades',
            permissions: const [Perm.educationClasses, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Classes & Students' : 'ክፍሎች እና የተማሪዎች ምደባ',
            subtitle: isEn ? 'Class batches & student assignment' : 'የክፍል አደረጃጀትና የተማሪዎች ምደባ',
            icon: Icons.groups_rounded,
            route: '/edu/manage',
            permissions: const [Perm.educationClasses, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Teacher Assignments' : 'የአስተማሪዎች ምደባ',
            subtitle: isEn ? 'Assign courses to instructors' : 'ለአስተማሪዎች የትምህርት ክፍለ ጊዜ መመደብ',
            icon: Icons.person_add_alt_1_rounded,
            route: '/edu/courses',
            permissions: const [Perm.educationClasses, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Registration Desk' : 'የምዝገባ ቢሮ',
            subtitle: isEn ? 'Process new and pending enrollments' : 'አዳዲስ ምዝገባዎችን ያረጋግጡና ይመዝግቡ',
            icon: Icons.how_to_reg_rounded,
            route: '/edu/registrations',
            permissions: const [Perm.educationRegister, Perm.educationManage],
          ),
        ],
      ),

      // 3. Assessment & Reports
      _AdminSection(
        title: isEn ? 'Assessment & Reports' : 'ውጤቶች እና ሪፖርቶች',
        subtitle: isEn
            ? 'Score publication, attendance tracking and student journeys'
            : 'የውጤት አሰጣጥ፣ የተማሪዎች ክትትል እና ሪፖርቶች',
        icon: Icons.analytics_rounded,
        color: AppColors.goldDark,
        cards: [
          _AdminCard(
            title: isEn ? 'Attendance Dashboard' : 'የተማሪዎች ክትትል ዳሽቦርድ',
            subtitle: isEn ? 'Student attendance profiles & program performance' : 'የተማሪዎች ክትትል ዝርዝርና የውጤት ትንተና',
            icon: Icons.fact_check_outlined,
            route: '/edu/admin/attendance',
            permissions: const [Perm.educationAttendanceView, Perm.educationManage, Perm.educationView, Perm.educationReports],
          ),
          _AdminCard(
            title: isEn ? 'Scores & Activity' : 'ውጤት እና እንቅስቃሴ',
            subtitle: isEn ? 'Performance analytics and ranks' : 'አጠቃላይ የውጤት ዝርዝር እና ትንተና',
            icon: Icons.bar_chart_rounded,
            route: '/edu/admin/scores',
            permissions: const [Perm.educationReports, Perm.educationMarks, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Marks Review' : 'የውጤት ማረጋገጫና ህትመት',
            subtitle: isEn ? 'Review & publish official marks' : 'ውጤቶችን መርምረው ለተማሪዎች ይፋ ያድርጉ',
            icon: Icons.fact_check_rounded,
            route: '/edu/review',
            permissions: const [Perm.educationMarks, Perm.educationAssessments, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Student Complaints & Inquiries' : 'የተማሪዎች ቅሬታዎችና ጥያቄዎች',
            subtitle: isEn ? 'Review grade & attendance appeals' : 'የውጤትና የፈተና አቤቱታዎችን ይመልከቱ',
            icon: Icons.feedback_outlined,
            route: '/edu/review?tab=complaints',
            permissions: const [Perm.educationView, Perm.educationManage],
          ),
        ],
      ),

      // 4. Library Management
      _AdminSection(
        title: isEn ? 'Library Management' : 'የቤተ-መጻሕፍት አስተዳደር',
        subtitle: isEn
            ? 'Education book circulation, catalog and digital copies'
            : 'የትምህርት መጻሕፍት ስርጭት፣ ካታሎግ እና ዲጂታል ቅጂዎች',
        icon: Icons.local_library_rounded,
        color: const Color(0xFFE65100),
        cards: [
          _AdminCard(
            title: isEn ? 'Book Catalog' : 'የመጻሕፍት ካታሎግ',
            subtitle: isEn ? 'Digital and reference books' : 'ዲጂታል እና ማጣቀሻ መጻሕፍት',
            icon: Icons.library_books_rounded,
            route: '/edu/admin/catalog',
            permissions: const [Perm.educationManage, Perm.itemsManage],
          ),
          _AdminCard(
            title: isEn ? 'Circulation & Loans' : 'የመጻሕፍት ውሰት እና ቅበላ',
            subtitle: isEn ? 'Track physical copies borrowed' : 'በተማሪዎች የተወሰዱ መጻሕፍትን ይከታተሉ',
            icon: Icons.swap_horiz_rounded,
            route: '/edu/circulation',
            permission: Perm.libraryCirculate,
          ),
          _AdminCard(
            title: isEn ? 'Book Requests' : 'የመጻሕፍት መጠየቂያዎች',
            subtitle: isEn ? 'Student reservation requests' : 'የተማሪዎች የውሰት ጥያቄዎችን ያጽድቁ',
            icon: Icons.outbox_rounded,
            route: '/edu/library-requests',
            permission: Perm.borrowingManage,
          ),
        ],
      ),

      // 5. Configuration and Administration
      _AdminSection(
        title: isEn ? 'Configuration & Progression' : 'ቅንብሮች እና የመማር ደንቦች',
        subtitle: isEn
            ? 'Progression rules, reminders and academic settings'
            : 'የቅደም-ተከተል መመሪያዎች፣ ማስታወሻዎችና ደንቦች',
        icon: Icons.tune_rounded,
        color: const Color(0xFF5D4037),
        cards: [
          _AdminCard(
            title: isEn ? 'Progression & Course Settings' : 'የመማር ቅደም-ተከተል ደንቦች',
            subtitle: isEn ? 'Configure sequential lesson unlocking' : 'ቅደም-ተከተላዊ የትምህርት መክፈቻ ደንቦችን ይቆጣጠሩ',
            icon: Icons.lock_open_rounded,
            route: '/edu/admin/progression-settings',
            permissions: const [Perm.educationSettings, Perm.educationManage],
          ),
          _AdminCard(
            title: isEn ? 'Reminders Management' : 'የማስታወሻዎች አስተዳደር',
            subtitle: isEn ? 'Set class and quiz reminders' : 'የትምህርት ክፍለ-ጊዜና የፈተና ማስታወሻዎች',
            icon: Icons.notifications_active_rounded,
            route: '/settings/reminders',
            permissions: const [],
          ),
        ],
      ),
    ];

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/edu');
        }
      },
      child: PatternScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/edu');
              }
            },
          ),
          title: Text(isEn ? 'Education Admin Panel' : 'የትምህርት አስተዳደር ፓነል'),
          actions: const [
            ContextualHelpButton(screenRoute: '/edu/admin'),
          ],
        ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // Banner introducing the organized panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1F5F8B),
                  AppColors.maroon,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                EduIcon(size: 42, dimmed: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Education Administration' : 'የትምህርት አስተዳደር ማዕከል',
                        style: context.serif(18, color: Colors.white, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEn
                            ? 'Manage courses, students, evaluations & materials'
                            : 'የትምህርት ክፍሎችን፣ ተማሪዎችን፣ ውጤቶችንና ግብዓቶችን በአንድ ቦታ ያስተዳድሩ',
                        style: context.sans(12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          for (final section in sections) ...[
            () {
              final visibleCards = section.cards.where((c) => c.allPermissions.isEmpty || user.isSuperAdmin || user.canAny(c.allPermissions)).toList();
              if (visibleCards.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeaderWidget(section: section),
                  const SizedBox(height: 8),
                  for (final card in visibleCards)
                    _AdminTileWidget(card: card),
                  const SizedBox(height: 18),
                ],
              );
            }(),
          ],
        ],
      ),
    ),
    );
  }
}

class _AdminSection {
  const _AdminSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_AdminCard> cards;
}

class _AdminCard {
  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.permission,
    this.permissions = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String? permission;
  final List<String> permissions;

  List<String> get allPermissions {
    if (permissions.isNotEmpty) return permissions;
    if (permission != null) return [permission!];
    return const [];
  }
}

class _SectionHeaderWidget extends StatelessWidget {
  const _SectionHeaderWidget({required this.section});
  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: section.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(section.icon, size: 18, color: section.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: context.serif(15.5, weight: FontWeight.w700, color: p.text),
              ),
              Text(
                section.subtitle,
                style: context.sans(11.5, color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminTileWidget extends StatelessWidget {
  const _AdminTileWidget({required this.card});
  final _AdminCard card;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(card.route),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Icon(card.icon, size: 22, color: AppColors.goldDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: context.sans(13.5, weight: FontWeight.w600, color: p.text),
                      ),
                      Text(
                        card.subtitle,
                        style: context.sans(11.5, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
