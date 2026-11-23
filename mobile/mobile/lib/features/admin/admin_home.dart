import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/user.dart' show AppUser;
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import 'admin_widgets.dart';
import 'org_admin.dart' show departmentName;
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';

final _permissionSummaryProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).permissionSummary());

final dashboardProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).dashboard());

enum AdminScope { shared, mezmur, education }

class _Module {
  const _Module(
    this.label,
    this.icon,
    this.route,
    this.permissions, {
    this.scope = AdminScope.shared,
    this.children = const [],
  });
  final String label;
  final IconData icon;
  final String route;
  final List<String> permissions; // any of
  final AdminScope scope;
  final List<_Module> children;

  bool visibleTo(AppUser? u, {String? activeScope, String? query}) {
    if (u == null) return false;
    if (activeScope != null && activeScope.isNotEmpty && activeScope != 'all') {
      if (activeScope == 'mezmur' && scope == AdminScope.education) return false;
      if (activeScope == 'education' && scope == AdminScope.mezmur) return false;
      if (activeScope == 'shared' && scope != AdminScope.shared) return false;
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      final matchSelf = label.toLowerCase().contains(q) || route.toLowerCase().contains(q);
      final matchChild = children.any((c) => c.label.toLowerCase().contains(q) || c.route.toLowerCase().contains(q));
      if (!matchSelf && !matchChild) return false;
    }
    return u.canAny(permissions);
  }
}

/// Admin home: organized shared administration, Mezmur administration, and Education administration.
/// Module-aware card visibility and real-time search.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key, this.initialScope});
  final String? initialScope;

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  late String _scope;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    // Group definitions with explicit administrative scope
    final rawGroups = <(String, AdminScope, List<_Module>)>[
      // 1. User Management (Shared)
      (
        l.adminGroupUsers,
        AdminScope.shared,
        [
          _Module(l.users, Icons.people_alt_outlined, '/admin/users', [Perm.usersView], scope: AdminScope.shared),
          _Module(l.midTitle, Icons.badge_outlined, '/admin/member-ids', [Perm.memberIdConfigure], scope: AdminScope.shared),
          _Module(l.mgTitle, Icons.groups_2_outlined, '/admin/member-groups', [Perm.memberGroupsManage], scope: AdminScope.shared),
          _Module(l.changeRequests, Icons.fact_check_outlined, '/admin/change-requests', [Perm.usersUpdate], scope: AdminScope.shared),
        ],
      ),
      // 2. Member & Activity Management (Shared)
      (
        l.adminGroupMemberServices,
        AdminScope.shared,
        [
          _Module(l.monthlyPayments, Icons.payments_outlined, '/admin/payments', [Perm.paymentsManage, Perm.paymentsView], scope: AdminScope.shared),
          _Module(l.attendance, Icons.how_to_reg_outlined, '/admin/attendance', [Perm.attendanceManage, Perm.attendanceView, Perm.attendanceCorrectionApprove, Perm.attendanceConfigure], scope: AdminScope.shared),
          _Module(l.fines, Icons.request_quote_outlined, '/admin/fines', [Perm.finesManage, Perm.borrowingManage], scope: AdminScope.shared),
          _Module(l.sendNotification, Icons.send_outlined, '/admin/notify', [Perm.notificationsSend], scope: AdminScope.shared),
          _Module(l.notificationHealth, Icons.monitor_heart_outlined, '/admin/notification-health', [Perm.notificationsSend, Perm.settingsManage], scope: AdminScope.shared),
        ],
      ),
      // 3. Department Management (Shared)
      (
        l.adminGroupDepartmentsMgmt,
        AdminScope.shared,
        [
          _Module(l.departments, Icons.account_tree_outlined, '/admin/departments', [Perm.departmentsManage, Perm.hrManage, Perm.adminsView], scope: AdminScope.shared),
          _Module(l.chatTitle, Icons.forum_outlined, '/admin/chat', [Perm.chatSupervise, Perm.departmentsManage, Perm.adminsView], scope: AdminScope.shared),
        ],
      ),
      // 4. Property Management (General borrowing & assets) (Shared)
      (
        l.adminGroupProperties,
        AdminScope.shared,
        [
          _Module(l.items, Icons.inventory_2_outlined, '/admin/items', [Perm.itemsManage], scope: AdminScope.shared),
          _Module(l.borrowing, Icons.swap_horiz_rounded, '/admin/borrowings', [Perm.borrowingManage], scope: AdminScope.shared),
          _Module(l.propRequests, Icons.inventory_outlined, '/admin/property-requests', [Perm.propertyRequest, Perm.propertyReview], scope: AdminScope.shared),
        ],
      ),
      // 5. Education Administration (Education Scoped)
      (
        isEn ? 'Education Management' : 'የትምህርት አስተዳደር',
        AdminScope.education,
        [
          _Module(l.eduManageCourses, Icons.menu_book_rounded, '/edu/courses', [Perm.educationManage, Perm.educationRegister], scope: AdminScope.education),
          _Module(
            l.eduManageLibrary,
            Icons.local_library_outlined,
            '/admin/library-requests',
            [Perm.borrowingManage, Perm.itemsManage, Perm.libraryCirculate],
            scope: AdminScope.education,
            children: [
              _Module(l.libCirculation, Icons.swap_horiz_rounded, '/admin/library/circulation', [Perm.libraryCirculate, Perm.borrowingManage], scope: AdminScope.education),
              _Module(l.libRequests, Icons.outbox_outlined, '/admin/library-requests', [Perm.borrowingManage], scope: AdminScope.education),
              _Module(l.libBooks, Icons.menu_book_outlined, '/edu/library', [Perm.itemsManage, Perm.borrowingManage, Perm.educationManage], scope: AdminScope.education),
            ],
          ),
          _Module(l.eduManageClasses, Icons.school_outlined, '/edu/manage', [Perm.educationManage], scope: AdminScope.education),
          _Module(l.elContentTitle, Icons.auto_stories_outlined, '/edu/content', [Perm.educationContent, Perm.educationManage], scope: AdminScope.education),
          _Module(l.regTitle, Icons.how_to_reg_rounded, '/edu/registrations', [Perm.educationRegister, Perm.educationManage], scope: AdminScope.education),
          _Module(
            isEn ? 'Attendance Dashboard' : 'የተማሪዎች ክትትል ዳሽቦርድ',
            Icons.fact_check_outlined,
            '/edu/admin/attendance',
            [Perm.educationAttendanceView, Perm.educationManage, Perm.educationView, Perm.educationReports],
            scope: AdminScope.education,
          ),
          _Module(isEn ? 'Scores & Activity' : 'ውጤት እና እንቅስቃሴ', Icons.analytics_outlined, '/edu/admin/scores', [Perm.educationManage, Perm.educationReports], scope: AdminScope.education),
        ],
      ),
      // 6. Mezmur Administration (Mezmur Scoped)
      (
        isEn ? 'Mezmur Management' : 'የመዝሙር አስተዳደር',
        AdminScope.mezmur,
        [
          _Module(
            l.serviceManagement,
            Icons.volunteer_activism_outlined,
            '/admin/selections',
            [Perm.selectionView, Perm.selectionConfigure, Perm.selectionExams, Perm.selectionReview, Perm.selectionFinalize, Perm.choirManage, Perm.educationManage, Perm.paymentsManage],
            scope: AdminScope.mezmur,
            children: [
              _Module(l.selTitle, Icons.how_to_vote_outlined, '/admin/selections', [Perm.selectionView, Perm.selectionConfigure, Perm.selectionExams, Perm.selectionReview, Perm.selectionFinalize], scope: AdminScope.mezmur),
              _Module(l.wedTitle, Icons.favorite_outline_rounded, '/admin/weddings', [Perm.choirManage], scope: AdminScope.mezmur),
            ],
          ),
          _Module(l.categories, Icons.category_outlined, '/admin/categories', [Perm.categoriesManage], scope: AdminScope.mezmur),
          _Module(l.mezmurs, Icons.library_music_outlined, '/admin/mezmurs', [Perm.mezmursView, Perm.mezmursCreate, Perm.mezmursUpdate], scope: AdminScope.mezmur),
          _Module(l.bulkImport, Icons.upload_file_rounded, '/admin/import', [Perm.mezmursCreate, Perm.categoriesManage, Perm.usersCreate], scope: AdminScope.mezmur),
        ],
      ),
      // 7. Promotion Management (Mezmur Scoped)
      (
        l.adminGroupPromotion,
        AdminScope.mezmur,
        [
          _Module(l.programCategories, Icons.label_outline_rounded, '/admin/program-categories', [Perm.programCategoriesManage], scope: AdminScope.mezmur),
          _Module(l.programs, Icons.event_outlined, '/admin/programs', [Perm.programsManage, Perm.attendanceManage, Perm.attendanceView], scope: AdminScope.mezmur),
          _Module(l.advertisements, Icons.campaign_outlined, '/admin/ads', [Perm.adsManage], scope: AdminScope.mezmur),
          _Module(l.pages, Icons.article_outlined, '/admin/pages', [Perm.pagesManage], scope: AdminScope.mezmur),
        ],
      ),
      // 8. Projects & Task Management (Shared)
      (
        l.adminGroupProjects,
        AdminScope.shared,
        [
          _Module(l.projectManagement, Icons.task_alt_rounded, '/projects', [Perm.projectsManage, Perm.projectsView, Perm.projectsExpensesApprove, Perm.projectsReports, Perm.projectsAllDepartments], scope: AdminScope.shared),
          _Module(l.pmMyTasks, Icons.checklist_rounded, '/projects/my-tasks', [Perm.projectsManage, Perm.projectsView], scope: AdminScope.shared),
          _Module(l.pmApprovals, Icons.account_balance_wallet_outlined, '/projects/approvals', [Perm.projectsExpensesApprove], scope: AdminScope.shared),
        ],
      ),
      // 9. Administration & Settings (Shared)
      (
        l.adminGroupAdministration,
        AdminScope.shared,
        [
          _Module(l.admins, Icons.admin_panel_settings_outlined, '/admin/admins', [Perm.adminsView], scope: AdminScope.shared),
          _Module(l.roles, Icons.badge_outlined, '/admin/roles', [Perm.adminsView], scope: AdminScope.shared),
          _Module(l.systemSettings, Icons.tune_rounded, '/admin/settings', [Perm.settingsManage], scope: AdminScope.shared),
          _Module(l.releases, Icons.system_update_outlined, '/admin/releases', [Perm.releasesManage], scope: AdminScope.shared),
          _Module(isEn ? 'In-App Guidance' : 'የመተግበሪያ መመሪያ', Icons.help_center_outlined, '/admin/guidance', [Perm.guidanceManage], scope: AdminScope.shared),
        ],
      ),
      // 10. Reports & Audit (Shared)
      (
        l.adminGroupReports,
        AdminScope.shared,
        [
          _Module(l.reports, Icons.insights_outlined, '/admin/reports', [Perm.reportsView], scope: AdminScope.shared),
          _Module(l.auditLogs, Icons.fact_check_outlined, '/admin/audit', [Perm.auditLogsView], scope: AdminScope.shared),
          _Module(l.activityLogs, Icons.timeline_outlined, '/admin/activity', [Perm.activityLogsView], scope: AdminScope.shared),
          _Module(isEn ? 'Diagnostic Reports' : 'የስርዓት ስህተት ሪፖርቶች', Icons.bug_report_outlined, '/admin/diagnostics', [Perm.adminsView, Perm.settingsManage, Perm.reportsView], scope: AdminScope.shared),
          _Module(isEn ? 'Media Migration & Storage' : 'የሚዲያ ፋይሎች ዝውውር', Icons.perm_media_outlined, '/admin/media-migration', [Perm.adminsView, Perm.settingsManage, Perm.reportsView], scope: AdminScope.shared),
        ],
      ),
    ];

    final filteredGroups = rawGroups
        .map((g) => (g.$1, g.$3.where((m) => m.visibleTo(user, activeScope: _scope, query: _search)).toList()))
        .where((g) => g.$2.isNotEmpty)
        .toList();

    if (user.can(Perm.reportsView)) ref.watch(dashboardProvider);
    if (user.can(Perm.attendanceManage)) ref.watch(_permissionSummaryProvider);

    return AdminScaffold(
      title: l.adminPanel,
      actions: const [ContextualHelpButton(screenRoute: '/admin')],
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(_permissionSummaryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MaroonCard(
                child: Row(
                  children: [
                    const AppLogo(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName, style: context.serif(16, color: Colors.white)),
                          if (user.adminDepartments.isNotEmpty)
                            Text(user.adminDepartments.map((d) => departmentName(context, d)).join(' · '), style: context.sans(12, color: AppColors.goldLight))
                          else if (user.roleName != null)
                            Text(user.roleName!, style: context.sans(12, color: AppColors.goldLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search Box for Admin Tools
              SearchBox(
                key: const ValueKey('admin.home.search_box'),
                hint: isEn ? 'Search administrative tools...' : 'የአስተዳዳሪ መሣሪያዎችን ፈልግ...',
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              // Scope Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  key: const ValueKey('admin.home.scope_filter'),
                  children: [
                    _ScopeFilterChip(
                      label: isEn ? 'All' : 'ሁሉም',
                      selected: _scope == 'all',
                      onSelected: () => setState(() => _scope = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _ScopeFilterChip(
                      label: isEn ? 'Shared' : 'የጋራ',
                      selected: _scope == 'shared',
                      onSelected: () => setState(() => _scope = 'shared'),
                    ),
                    const SizedBox(width: 6),
                    _ScopeFilterChip(
                      label: isEn ? 'Mezmur' : 'መዝሙር',
                      selected: _scope == 'mezmur',
                      color: AppColors.maroon,
                      onSelected: () => setState(() => _scope = 'mezmur'),
                    ),
                    const SizedBox(width: 6),
                    _ScopeFilterChip(
                      label: isEn ? 'Education' : 'ትምህርት',
                      selected: _scope == 'education',
                      color: const Color(0xFF1F5F8B),
                      onSelected: () => setState(() => _scope = 'education'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (user.can(Perm.attendanceManage)) const _AdminAlerts(),
              if (user.can(Perm.reportsView)) const _Dashboard(),
              if (filteredGroups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      isEn ? 'No administrative tools match your search.' : 'ምንም የተገኘ የአስተዳዳሪ መሣሪያ የለም።',
                      style: context.sans(14, color: context.palette.muted),
                    ),
                  ),
                )
              else
                for (final (title, modules) in filteredGroups) ...[
                  SectionHeader(title: title),
                  _ModuleGrid(modules: modules),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeFilterChip extends StatelessWidget {
  const _ScopeFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.gold;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: activeColor.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? (color ?? Theme.of(context).colorScheme.primary) : null,
      ),
    );
  }
}

class _ModuleGrid extends ConsumerWidget {
  const _ModuleGrid({required this.modules});
  final List<_Module> modules;

  /// A module with sub-modules opens a small chooser (only the permitted ones; one → straight there).
  static void _open(BuildContext context, WidgetRef ref, _Module m) {
    if (m.children.isEmpty) {
      context.push(m.route);
      return;
    }
    final user = ProviderScope.containerOf(context).read(currentUserProvider);
    final subs = m.children.where((c) => c.visibleTo(user)).toList();
    if (subs.length == 1) {
      context.push(subs.first.route);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text(m.label, style: ctx.serif(18))),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 20),
                    tooltip: 'Help',
                    onPressed: () {
                      Navigator.pop(ctx);
                      showContextualHelp(context, ref, screenRoute: m.route, title: m.label);
                    },
                  ),
                ],
              ),
            ),
            for (final c in subs)
              ListTile(
                key: ValueKey('admin-sub-${c.route}'),
                leading: Icon(c.icon, color: AppColors.goldDark),
                title: Text(c.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      tooltip: 'Help',
                      onPressed: () {
                        Navigator.pop(ctx);
                        showContextualHelp(context, ref, screenRoute: c.route, title: c.label);
                      },
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(c.route);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.count(
    crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.95,
    children: [
      for (final m in modules)
        AppCard(
          key: TourKeys.moduleKeys[m.route] ?? ValueKey('admin-module-${m.route}'),
          onTap: () => _open(context, ref, m),
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // Fixed-ratio cell: shrink (never overflow) with a large text scale or a long label.
              LayoutBuilder(
                builder: (context, c) => Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: c.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: context.palette.pill, borderRadius: BorderRadius.circular(12)),
                            child: Icon(m.icon, color: AppColors.goldDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.sans(12, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showContextualHelp(context, ref, screenRoute: m.route, title: m.label),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.help_outline_rounded, size: 16, color: context.palette.muted.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Admin notifications: who asked permission to miss an event (latest pending requests).
class _AdminAlerts extends ConsumerWidget {
  const _AdminAlerts();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final async = ref.watch(_permissionSummaryProvider);
    final d = async.value;
    if (d == null) return const SizedBox.shrink();
    final pending = asIntOr(d['pending']);
    final latest = asJsonList(d['latest']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.adminAlerts, trailing: pending > 0 ? l.pendingCount(pending) : null, onTrailingTap: () => context.push('/admin/permissions')),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: latest.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(l.noAdminAlerts, style: context.sans(13, color: context.palette.muted)),
                )
              : Column(
                  children: [
                    for (final r in latest)
                      ListTile(
                        leading: const Icon(Icons.edit_calendar_rounded, color: AppColors.gold),
                        title: Text(l.permissionAsked(asStr(r['full_name']) ?? '—', asStr(r['program_title']) ?? '—'), style: context.sans(13, weight: FontWeight.w600)),
                        subtitle: Text([if (asStr(r['reason']) != null) asStr(r['reason'])!, f.relative(asDate(r['created_at']))].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => context.push('/admin/permissions'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AsyncView(
      value: ref.watch(dashboardProvider),
      onRetry: () => ref.invalidate(dashboardProvider),
      loading: const LoadingView(padding: EdgeInsets.all(24)),
      data: (d) {
        final t = asJson(d['totals']);
        final tiles = [
          (l.totalUsers, '${asIntOr(t['users'])}', Icons.people_alt_outlined, false, '/admin/users'),
          (l.activeUsers, '${asIntOr(t['active_users_30d'])}', Icons.bolt_outlined, false, null),
          (l.newUsers, '${asIntOr(t['new_users_30d'])}', Icons.person_add_alt_outlined, false, null),
          (l.totalMezmurs, '${asIntOr(t['mezmurs'])}', Icons.library_music_outlined, false, '/admin/mezmurs'),
          (l.totalCategories, '${asIntOr(t['categories'])}', Icons.category_outlined, false, '/admin/categories'),
          (l.upcomingProgramsStat, '${asIntOr(t['upcoming_programs'])}', Icons.event_outlined, false, '/admin/programs'),
          (l.attendance30, '${asIntOr(t['attendance_30d'])}', Icons.how_to_reg_outlined, false, null),
          (l.activeBorrowings, '${asIntOr(t['active_borrowings'])}', Icons.swap_horiz_rounded, false, '/admin/borrowings'),
          (l.overdueBorrowings, '${asIntOr(t['overdue_borrowings'])}', Icons.warning_amber_rounded, asIntOr(t['overdue_borrowings']) > 0, '/admin/borrowings'),
          (l.pendingFines, f.money(asDouble(t['pending_fines']), 'ETB'), Icons.payments_outlined, false, '/admin/fines'),
        ];
        final signups = asJsonList(d['signups_30d']);
        final maxSignup = signups.fold<int>(1, (m, s) => asIntOr(s['count']) > m ? asIntOr(s['count']) : m);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l.dashboard),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [for (final t in tiles) StatTile(label: t.$1, value: t.$2, icon: t.$3, highlight: t.$4, onTap: t.$5 == null ? null : () => context.push(t.$5!))],
            ),
            if (signups.isNotEmpty) ...[
              SectionHeader(title: l.signups30),
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                child: SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final s in signups)
                        Expanded(
                          child: Tooltip(
                            message: '${s['day']}: ${s['count']}',
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              height: 6 + 80 * asIntOr(s['count']) / maxSignup,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            // One card: member activity and sent notifications, newest first.
            if (asJsonList(d['recent_activity']).isNotEmpty || asJsonList(d['recent_notifications']).isNotEmpty) ...[
              SectionHeader(title: l.recentActivityAndNotifications),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Builder(
                  builder: (context) {
                    final entries = <({DateTime? at, Widget tile})>[
                      for (final a in asJsonList(d['recent_activity']).take(5))
                        (
                          at: asDate(a['occurred_at']),
                          tile: ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline_rounded, color: AppColors.gold, size: 22),
                            title: Text(
                              '${a['user_name']} — ${activityLabel(l, '${a['action']}')}',
                              style: context.sans(13, weight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(f.relative(asDate(a['occurred_at'])), style: context.sans(11, color: context.palette.muted)),
                            onTap: () => context.push('/admin/activity'),
                          ),
                        ),
                      for (final n in asJsonList(d['recent_notifications']).take(5))
                        (
                          at: asDate(n['created_at']),
                          tile: ListTile(
                            dense: true,
                            leading: const Icon(Icons.campaign_outlined, color: AppColors.gold, size: 22),
                            title: Text(
                              '${n['title']}',
                              style: context.sans(13, weight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${n['sender_name'] ?? ''} · ${n['recipient_count']}',
                              style: context.sans(11, color: context.palette.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(f.relative(asDate(n['created_at'])), style: context.sans(11, color: context.palette.muted)),
                            onTap: () => context.push('/admin/notify/${n['id']}'),
                          ),
                        ),
                    ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
                    return Column(mainAxisSize: MainAxisSize.min, children: [for (final e in entries.take(6)) e.tile]);
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
