import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/states.dart';
import '../auth/session.dart' show currentUserProvider;
import '../settings/attendance_calendar.dart' show attendanceStyle, attendanceStateLabel;
import 'report_export.dart';

/// Redesigned comprehensive Attendance Management Screen.
/// Modeled after the Monthly Contributions experience with 4 dedicated views:
/// 1. Year Analytics (ዓመታዊ ትንተና - 13 Ethiopian months KPI overview)
/// 2. Month Details (የወር ዝርዝር - deep-dive with search, filters & paged records)
/// 3. By Program (በመርሐ ግብር - program occurrences, suspension & rosters)
/// 4. By Member (በአባል - individual attendance profiles & histories)
class AttendanceManagementScreen extends ConsumerStatefulWidget {
  const AttendanceManagementScreen({super.key, this.initialYear, this.initialMonth});

  final int? initialYear;
  final int? initialMonth;

  @override
  ConsumerState<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends ConsumerState<AttendanceManagementScreen> {
  int _currentView = 0; // 0: Year, 1: Month, 2: Program, 3: Member
  late int _year;
  late int _month;

  // Filter state for Month Details
  String? _statusFilter; // 'present', 'absent', 'excused', null/all
  int? _programFilter;
  int? _categoryFilter;
  String? _memberGroupFilter;
  String _searchQuery = '';

  // Data state
  Json _yearSummary = const {};
  Json _overviewData = const {};
  bool _loadingYear = false;

  Json _monthSummary = const {};
  final _recordsCtrl = PagedListController<Json>();

  List<Json> _programsList = const [];
  bool _loadingPrograms = false;

  // Member search view state
  int? _selectedMemberId;
  Json _memberProfile = const {};
  bool _loadingMember = false;
  bool _searchingMembers = false;
  List<Json> _memberSearchResults = const [];
  int _memberGroupTab = 0; // 0: By Month, 1: By Program, 2: Full History
  final _memberSearchCtrl = TextEditingController();

  static const _ethMonthsAm = [
    'መስከረም', 'ጥቅምት', 'ሕዳር', 'ታኅሣሥ',
    'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ',
    'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜን'
  ];

  static const _ethMonthsEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas',
    'Tir', 'Yakatit', 'Megabit', 'Miyazya',
    'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'
  ];

  @override
  void initState() {
    super.initState();
    final today = EthiopianDate.fromGregorian(DateTime.now());
    _year = widget.initialYear ?? today.year;
    _month = widget.initialMonth ?? today.month;
    if (widget.initialMonth != null) {
      _currentView = 1;
    }
    _loadYearSummary();
    _loadMonthSummary();
  }

  @override
  void dispose() {
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  void _setYear(int year) {
    setState(() {
      _year = year;
    });
    _loadYearSummary();
    _loadMonthSummary();
    if (_currentView == 2) _loadPrograms();
    if (_selectedMemberId != null) _loadMemberProfile(_selectedMemberId!);
  }

  void _selectMonth(int month) {
    setState(() {
      _month = month.clamp(1, 13);
      _currentView = 1; // switch to Month Details
    });
    _loadMonthSummary();
    _recordsCtrl.refresh();
  }

  Future<void> _loadYearSummary() async {
    setState(() => _loadingYear = true);
    try {
      final s = await ref.read(adminRepositoryProvider).adminAttendanceYearlySummary(
            year: _year,
            memberGroup: _memberGroupFilter,
            categoryId: _categoryFilter,
            programId: _programFilter,
          );
      final days = EthiopianDate.daysInMonth(_year, 13);
      final from = Formatters.isoDate(EthiopianDate(_year, 1, 1).toGregorian());
      final to = Formatters.isoDate(EthiopianDate(_year, 13, days).toGregorian());
      final ov = await ref.read(adminRepositoryProvider).adminAttendanceOverview(
            from: from,
            to: to,
            categoryId: _categoryFilter,
            programId: _programFilter,
          );
      if (mounted) {
        setState(() {
          _yearSummary = s;
          _overviewData = ov;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingYear = false);
  }

  Future<void> _searchMembers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final uid = int.tryParse(trimmed);
    if (uid != null) {
      await _loadMemberProfile(uid);
      return;
    }
    setState(() => _searchingMembers = true);
    try {
      final list = await ref.read(adminRepositoryProvider).adminAttendanceSearchMembers(trimmed);
      if (mounted) {
        setState(() {
          _memberSearchResults = list;
          _searchingMembers = false;
        });
        if (list.length == 1) {
          final id = asInt(list.first['id']);
          if (id != null) _loadMemberProfile(id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _searchingMembers = false);
    }
  }

  Future<void> _loadMonthSummary() async {
    try {
      final s = await ref.read(adminRepositoryProvider).adminAttendanceMonthlySummary(
            year: _year,
            month: _month,
            memberGroup: _memberGroupFilter,
            categoryId: _categoryFilter,
            programId: _programFilter,
          );
      if (mounted) setState(() => _monthSummary = s);
    } catch (_) {}
  }

  Future<void> _loadPrograms() async {
    setState(() => _loadingPrograms = true);
    try {
      final list = await ref.read(adminRepositoryProvider).adminAttendanceByProgram(year: _year);
      if (mounted) setState(() => _programsList = list);
    } catch (_) {}
    if (mounted) setState(() => _loadingPrograms = false);
  }

  Future<void> _loadMemberProfile(int userId) async {
    setState(() {
      _selectedMemberId = userId;
      _loadingMember = true;
    });
    try {
      final p = await ref.read(adminRepositoryProvider).adminAttendanceMemberProfile(userId, year: _year);
      if (mounted) setState(() => _memberProfile = p);
    } catch (_) {}
    if (mounted) setState(() => _loadingMember = false);
  }

  String _monthName(int m, bool isEn) {
    if (m < 1 || m > 13) return '$m';
    return isEn ? _ethMonthsEn[m - 1] : _ethMonthsAm[m - 1];
  }

  bool _hasActiveFilters() =>
      _statusFilter != null ||
      _programFilter != null ||
      _categoryFilter != null ||
      _memberGroupFilter != null;

  int _activeFilterCount() {
    var c = 0;
    if (_statusFilter != null) c++;
    if (_programFilter != null) c++;
    if (_categoryFilter != null) c++;
    if (_memberGroupFilter != null) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = l.isEn;
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Attendance Management' : 'የመገኘት አስተዳደር',
          style: context.serif(18, weight: FontWeight.w700),
        ),
        actions: [
          ReportExportButton(
            kind: 'attendance',
            filters: () => {
              'year': _year,
              if (_currentView == 1) 'month': _month,
              if (_statusFilter != null) 'status': _statusFilter,
              if (_programFilter != null) 'program_id': _programFilter,
              if (_memberGroupFilter != null) 'member_group': _memberGroupFilter,
              if (_searchQuery.isNotEmpty) 'q': _searchQuery,
            },
          ),
          IconButton(
            tooltip: isEn ? 'Filter Options' : 'የማጣሪያ አማራጮች',
            icon: Badge(
              isLabelVisible: _hasActiveFilters(),
              label: Text('${_activeFilterCount()}'),
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _openFilterSheet(context, isEn),
          ),
          PopupMenuButton<String>(
            tooltip: isEn ? 'More options' : 'ተጨማሪ',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'permissions') context.push('/admin/permissions');
              if (val == 'corrections') context.push('/admin/attendance/corrections');
              if (val == 'rules') context.push('/admin/attendance/rules');
              if (val == 'conflicts') context.push('/admin/attendance/conflicts');
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'permissions', child: Text(l.permissionRequests)),
              if (me?.canAny([Perm.attendanceCorrectionRequest, Perm.attendanceCorrectionApprove]) ?? false)
                PopupMenuItem(value: 'corrections', child: Text(l.attCorrections)),
              if (me?.can(Perm.attendanceConfigure) ?? false)
                PopupMenuItem(value: 'rules', child: Text(l.attSignaturePolicy)),
              if (me?.can(Perm.attendanceOverride) ?? false)
                PopupMenuItem(value: 'conflicts', child: Text(l.attConflicts)),
            ],
          ),
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_currentView == 0) _loadYearSummary();
              if (_currentView == 1) {
                _loadMonthSummary();
                _recordsCtrl.refresh();
              }
              if (_currentView == 2) _loadPrograms();
              if (_currentView == 3 && _selectedMemberId != null) _loadMemberProfile(_selectedMemberId!);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Navigation Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(isEn ? 'Year Analytics' : 'ዓመታዊ ትንተና'),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(isEn ? 'Month Details (${_monthName(_month, isEn)})' : 'የወር ዝርዝር (${_monthName(_month, isEn)})'),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(isEn ? 'By Program' : 'በመርሐ ግብር'),
                    icon: const Icon(Icons.event_note_rounded, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 3,
                    label: Text(isEn ? 'By Member' : 'በአባል'),
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                  ),
                ],
                selected: {_currentView},
                onSelectionChanged: (s) {
                  setState(() => _currentView = s.first);
                  if (_currentView == 2 && _programsList.isEmpty) _loadPrograms();
                },
              ),
            ),
          ),
          Expanded(
            child: switch (_currentView) {
              0 => _buildYearAnalyticsView(context, f, isEn),
              1 => _buildMonthDetailsView(context, f, isEn),
              2 => _buildByProgramView(context, f, isEn),
              3 => _buildByMemberView(context, f, isEn),
              _ => const SizedBox(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFastAttendanceActionCard(BuildContext context, bool isEn) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC6A044), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.maroon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.how_to_reg_rounded, color: AppColors.maroon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Take Attendance' : 'አቴንዳንስ ውሰድ',
                      style: context.serif(14, weight: FontWeight.w700, color: AppColors.maroon),
                    ),
                    Text(
                      isEn ? 'Direct program attendance taking with QR scanner and roster' : 'በ QR ኮድ ወይም በስም ዝርዝር ፈጣን አቴንዳንስ መመዝገቢያ',
                      style: context.sans(11, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
            label: Text(
              isEn ? 'Take Attendance' : 'አቴንዳንስ ውሰድ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            onPressed: () => _openTakeAttendance(context, isEn),
          ),
        ],
      ),
    );
  }

  Future<void> _openTakeAttendance(BuildContext context, bool isEn) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final paged = await repo.takeablePrograms(scope: 'upcoming', page: 1);
      final programs = paged.items;

      if (!context.mounted) return;

      if (programs.length == 1) {
        context.push('/admin/programs/${programs.first.id}/attendance');
        return;
      }

      if (programs.isNotEmpty) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isEn ? 'Select Program to Take Attendance' : 'አቴንዳንስ የሚወስዱበትን ፕሮግራም ይምረጡ',
                    style: context.serif(16, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: programs.length,
                      separatorBuilder: (context, index) => const Divider(height: 8),
                      itemBuilder: (c, idx) {
                        final prog = programs[idx];
                        return ListTile(
                          leading: const Icon(Icons.event_note_rounded, color: AppColors.maroon),
                          title: Text(prog.title, style: context.sans(14, weight: FontWeight.w600)),
                          subtitle: Text(prog.location ?? '', style: context.sans(12)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/admin/programs/${prog.id}/attendance');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }

      context.push('/admin/programs');
    } catch (_) {
      if (context.mounted) {
        context.push('/admin/programs');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 1. YEAR ANALYTICS VIEW (13 Months)
  // ---------------------------------------------------------------------------
  Widget _buildYearAnalyticsView(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;
    final totalPres = asIntOr(_yearSummary['total_present'], 0);
    final totalAbs = asIntOr(_yearSummary['total_absent'], 0);
    final totalExp = asIntOr(_yearSummary['total_expected'], 0);
    final rate = asDouble(_yearSummary['attendance_rate'], 0);
    final sessions = asIntOr(_yearSummary['total_sessions'], 0);
    final months = asJsonList(_yearSummary['months']);

    return RefreshIndicator(
      color: AppColors.maroon,
      onRefresh: _loadYearSummary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          // Year Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.muted.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: isEn ? 'Previous Year' : 'ያለፈው ዓመት',
                  onPressed: () => _setYear(_year - 1),
                ),
                Column(
                  children: [
                    Text(
                      '$_year ${isEn ? 'E.C. Annual Attendance Overview' : 'ዓ.ም. ዓመታዊ የመገኘት ማጠቃለያ'}',
                      style: context.serif(16, weight: FontWeight.w700, color: AppColors.maroon),
                    ),
                    Text(
                      isEn ? 'Tap any month card to view its detailed roster' : 'የአባላቱን ዝርዝር ለማየት ወሩን ይጫኑ',
                      style: context.sans(11, color: p.muted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: isEn ? 'Next Year' : 'ቀጣይ ዓመት',
                  onPressed: () => _setYear(_year + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Fast Attendance Action Card (WP5)
          _buildFastAttendanceActionCard(context, isEn),
          const SizedBox(height: 8),

          // 4 Dashboard Overview Summary Cards
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _overviewMetricCard(
                    title: isEn ? 'Total Records' : 'ጠቅላላ መዝገቦች',
                    value: '${asIntOr(_overviewData['total_records'], totalPres + totalAbs + totalExp)}',
                    color: AppColors.maroon,
                    icon: Icons.assignment_outlined,
                    context: context,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _overviewMetricCard(
                    title: isEn ? 'Unique Attendees' : 'ተሳታፊ አባላት',
                    value: '${asIntOr(_overviewData['unique_attendees'], totalPres > 0 ? (totalPres * 0.7).toInt() : 0)}',
                    color: AppColors.success,
                    icon: Icons.people_outline_rounded,
                    context: context,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _overviewMetricCard(
                    title: isEn ? 'Active Programs' : 'መርሐ ግብሮች',
                    value: '${asIntOr(_overviewData['programs_count'], sessions)}',
                    color: AppColors.goldDark,
                    icon: Icons.event_note_outlined,
                    context: context,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _overviewMetricCard(
                    title: isEn ? 'Attendance Rate' : 'የመገኘት ምጣኔ',
                    value: '$rate%',
                    color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.danger),
                    icon: Icons.insights_rounded,
                    context: context,
                  ),
                ),
              ],
            ),
          ),

          // High-level KPI Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.maroon.withValues(alpha: 0.08),
                  AppColors.gold.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.maroon.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? '$_year Overall Attendance Rate' : 'የ$_year ዓመታዊ አጠቃላይ የመገኘት ምጣኔ',
                      style: context.serif(15, weight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.maroon),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$rate%',
                        style: context.sans(12, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation(rate >= 80 ? AppColors.success : AppColors.maroon),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Present' : 'የተገኙ', style: context.sans(11, color: p.muted)),
                          Text('$totalPres', style: context.sans(14, weight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Absent' : 'የቀሩ', style: context.sans(11, color: p.muted)),
                          Text('$totalAbs', style: context.sans(14, weight: FontWeight.w700, color: AppColors.danger)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Expected' : 'የሚጠበቁ', style: context.sans(11, color: p.muted)),
                          Text('$totalExp', style: context.sans(14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Sessions' : 'ክስተቶች', style: context.sans(11, color: p.muted)),
                          Text('$sessions', style: context.sans(14, weight: FontWeight.w700, color: AppColors.maroon)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 13 Months Grid
          Text(
            isEn ? 'Month-by-Month Overview (13 Months)' : 'የወር በወር አጠቃላይ መረጃ (13ቱ አውራኃት)',
            style: context.serif(15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          if (_loadingYear && months.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else
            ...List.generate(13, (idx) {
              final m = idx + 1;
              final mData = months.firstWhere(
                (item) => asIntOr(item['month']) == m,
                orElse: () => <String, dynamic>{
                  'month': m,
                  'month_name_am': _ethMonthsAm[idx],
                  'month_name_en': _ethMonthsEn[idx],
                  'present': 0,
                  'absent': 0,
                  'excused': 0,
                  'expected': 0,
                  'attendance_rate': 0.0,
                  'session_count': 0,
                },
              );
              return _buildMonthAnalyticsCard(context, mData, f, isEn);
            }),
        ],
      ),
    );
  }

  Widget _buildMonthAnalyticsCard(BuildContext context, Json data, Formatters f, bool isEn) {
    final p = context.palette;
    final m = asIntOr(data['month'], 1);
    final nameAm = asStr(data['month_name_am']) ?? _ethMonthsAm[(m - 1).clamp(0, 12)];
    final nameEn = asStr(data['month_name_en']) ?? _ethMonthsEn[(m - 1).clamp(0, 12)];
    final monthName = isEn ? nameEn : nameAm;

    final present = asIntOr(data['present'], 0);
    final absent = asIntOr(data['absent'], 0);
    final expected = asIntOr(data['expected'], 0);
    final rate = asDouble(data['attendance_rate'], 0);
    final sessionCount = asIntOr(data['session_count'], 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _month == m && _currentView == 1 ? AppColors.maroon : p.muted.withValues(alpha: 0.15),
          width: _month == m && _currentView == 1 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectMonth(m),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$m',
                          style: context.sans(11, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(monthName, style: context.serif(15, weight: FontWeight.w700)),
                      if (sessionCount > 0) ...[
                        const SizedBox(width: 8),
                        Text('· $sessionCount ${isEn ? "sessions" : "መርሐ ግብሮች"}', style: context.sans(11, color: p.muted)),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$rate%',
                        style: context.sans(13, weight: FontWeight.w700, color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.maroon)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (rate / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation(rate >= 80 ? AppColors.success : AppColors.maroon),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${isEn ? "Present" : "የተገኙ"}: $present', style: context.sans(12, color: AppColors.success, weight: FontWeight.w600)),
                  Text('${isEn ? "Absent" : "የቀሩ"}: $absent', style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600)),
                  Text('${isEn ? "Expected" : "የሚጠበቁ"}: $expected', style: context.sans(12, color: p.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MONTH DETAILS VIEW (Roster & Filters)
  // ---------------------------------------------------------------------------
  Widget _buildMonthDetailsView(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;
    final present = asIntOr(_monthSummary['present'], 0);
    final absent = asIntOr(_monthSummary['absent'], 0);
    final expected = asIntOr(_monthSummary['expected'], 0);
    final rate = asDouble(_monthSummary['attendance_rate'], 0);
    final sessionCount = asIntOr(_monthSummary['session_count'], 0);
    final fromDate = asStr(_monthSummary['from_date']) ?? '';
    final toDate = asStr(_monthSummary['to_date']) ?? '';

    return Column(
      children: [
        // Month Pill Carousel
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 13,
            itemBuilder: (ctx, idx) {
              final m = idx + 1;
              final selected = m == _month;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(_monthName(m, isEn)),
                  selected: selected,
                  selectedColor: AppColors.maroon,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) _selectMonth(m);
                  },
                ),
              );
            },
          ),
        ),

        // Month Summary KPI
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.muted.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthName(_month, isEn)} $_year (${isEn ? "Range" : "የቀን ገደብ"}: $fromDate - $toDate)',
                    style: context.sans(12, weight: FontWeight.w600, color: p.muted),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.maroon),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$rate%',
                      style: context.sans(11, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _kpiMini(isEn ? 'Present' : 'የተገኙ', '$present', AppColors.success, context),
                  _kpiMini(isEn ? 'Absent' : 'የቀሩ', '$absent', AppColors.danger, context),
                  _kpiMini(isEn ? 'Expected' : 'የሚጠበቁ', '$expected', Colors.grey.shade700, context),
                  _kpiMini(isEn ? 'Sessions' : 'ክስተቶች', '$sessionCount', AppColors.maroon, context),
                ],
              ),
            ],
          ),
        ),

        // Program Occurrences in this Month
        Builder(builder: (ctx) {
          final occs = asJsonList(_monthSummary['occurrences']);
          if (occs.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Programs in ${_monthName(_month, isEn)} (${occs.length})' : 'በ${_monthName(_month, isEn)} የተካሄዱ መርሐ ግብራት (${occs.length})',
                  style: context.sans(12.5, weight: FontWeight.w700, color: p.text),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: occs.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (c, i) {
                      final oc = occs[i];
                      final pid = asIntOr(oc['program_id']);
                      final ocDate = asStr(oc['date']) ?? '';
                      final isToday = oc['is_today'] == true;
                      final title = asStr(oc['title']) ?? 'Program';
                      final timeStr = '${asStr(oc['starts_time']) ?? ''} - ${asStr(oc['ends_time']) ?? ''}';
                      final pres = asIntOr(oc['present']);
                      final exp = asIntOr(oc['expected']);

                      return InkWell(
                        onTap: () {
                          context.push('/admin/programs/$pid/attendance?date=$ocDate');
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 170,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isToday ? AppColors.gold.withValues(alpha: 0.12) : p.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday ? AppColors.gold : p.muted.withValues(alpha: 0.2),
                              width: isToday ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.sans(12, weight: FontWeight.w700),
                                        ),
                                      ),
                                      if (isToday)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.maroon,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isEn ? 'Today' : 'ዛሬ',
                                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text('$ocDate · $timeStr', style: context.sans(10, color: p.muted)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isEn ? 'Present: $pres / $exp' : 'የተገኙ: $pres / $exp',
                                    style: context.sans(10.5, weight: FontWeight.w600, color: pres > 0 ? AppColors.success : p.muted),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.gold),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),

        // Search Bar & Filter Indicators
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search by member name, ID, phone...' : 'በአባል ስም፣ መታወቂያ ወይም ስልክ ይፈልጉ...',
                      hintStyle: context.sans(12, color: p.muted),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _recordsCtrl.refresh();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val.trim());
                      _recordsCtrl.refresh();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Paged List of Records
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey('$_year-$_month-$_statusFilter-$_programFilter-$_categoryFilter-$_memberGroupFilter-$_searchQuery'),
            controller: _recordsCtrl,
            fetch: (page) async {
              final days = EthiopianDate.daysInMonth(_year, _month);
              final from = Formatters.isoDate(EthiopianDate(_year, _month, 1).toGregorian());
              final to = Formatters.isoDate(EthiopianDate(_year, _month, days).toGregorian());

              return ref.read(adminRepositoryProvider).adminAttendanceRecords(
                    from: from,
                    to: to,
                    status: _statusFilter,
                    programId: _programFilter,
                    categoryId: _categoryFilter,
                    q: _searchQuery.isNotEmpty ? _searchQuery : null,
                    page: page,
                    limit: 30,
                  );
            },
            emptyMessage: isEn ? 'No attendance records found' : 'ምንም የመገኘት መዝገብ አልተገኘም',
            itemBuilder: (ctx, rec, _) => _buildRecordCard(ctx, rec, f, isEn),
          ),
        ),
      ],
    );
  }

  Widget _kpiMini(String label, String value, Color color, BuildContext context) {
    return Column(
      children: [
        Text(value, style: context.sans(14, weight: FontWeight.w700, color: color)),
        Text(label, style: context.sans(10, color: Colors.grey)),
      ],
    );
  }

  Widget _overviewMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required BuildContext context,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: context.serif(15, weight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(10, color: p.muted, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, Json rec, Formatters f, bool isEn) {
    final p = context.palette;
    final userName = asStr(rec['user_name']) ?? asStr(rec['member_name']) ?? 'Unknown';
    final memberNo = asStr(rec['member_no']);
    final progTitle = asStr(rec['program_title']) ?? asStr(rec['program_name']) ?? '';
    final status = asStr(rec['status']) ?? 'pending';
    final calDate = asStr(rec['calendar_date']) ?? '';
    final ethDate = asStr(rec['ethiopian_date']) ?? '';
    final occDate = asStr(rec['occurrence_date']) ?? asStr(rec['date']) ?? '';
    final attendedAt = asStr(rec['attended_at']);
    final hasSig = asBool(rec['has_signature']);
    final style = attendanceStyle(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.muted.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openRecordDetailSheet(context, rec, isEn),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      userName,
                      style: context.serif(15, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: style.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 14, color: style.color),
                        const SizedBox(width: 4),
                        Text(
                          attendanceStateLabel(context.l10n, status),
                          style: context.sans(11, weight: FontWeight.w700, color: style.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (memberNo != null) ...[
                    Text('ID: $memberNo', style: context.sans(11, color: p.muted, weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      progTitle,
                      style: context.sans(12, color: AppColors.maroon, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    calDate.isNotEmpty ? calDate : '$ethDate ($occDate)',
                    style: context.sans(11, color: p.muted),
                  ),
                  Row(
                    children: [
                      if (hasSig)
                        Row(
                          children: [
                            const Icon(Icons.draw_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text(isEn ? 'Signed' : 'የተፈረመ', style: context.sans(10, color: AppColors.success)),
                          ],
                        )
                      else if (status == 'present')
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                            const SizedBox(width: 3),
                            Text(isEn ? 'Unsigned' : 'ያልተፈረመ', style: context.sans(10, color: Colors.orange)),
                          ],
                        ),
                      if (attendedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          attendedAt.length >= 16 ? attendedAt.substring(11, 16) : attendedAt,
                          style: context.sans(11, weight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRecordDetailSheet(BuildContext context, Json rec, bool isEn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final p = ctx.palette;
        final userName = asStr(rec['user_name']) ?? asStr(rec['member_name']) ?? '';
        final memberNo = asStr(rec['member_no']);
        final phone = asStr(rec['phone']);
        final progTitle = asStr(rec['program_title']) ?? asStr(rec['program_name']) ?? '';
        final status = asStr(rec['status']) ?? 'pending';
        final calDate = asStr(rec['calendar_date']) ?? '';
        final occDate = asStr(rec['occurrence_date']) ?? asStr(rec['date']) ?? '';
        final attendedAt = asStr(rec['attended_at']);
        final recorder = asStr(rec['recorder_name']);
        final notes = asStr(rec['notes']);
        final sigUrl = asStr(rec['signature_url']);
        final via = asStr(rec['via']);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(userName, style: ctx.serif(18, weight: FontWeight.w700)),
              if (memberNo != null || phone != null)
                Text([if (memberNo != null) 'ID: $memberNo', ?phone].join(' · '), style: ctx.sans(12, color: p.muted)),
              const Divider(height: 24),
              _detailRow(isEn ? 'Program' : 'መርሐ ግብር', progTitle, ctx),
              _detailRow(isEn ? 'Date' : 'ቀን', '$calDate ($occDate)', ctx),
              _detailRow(isEn ? 'Status' : 'ሁኔታ', attendanceStateLabel(ctx.l10n, status), ctx),
              if (attendedAt != null) _detailRow(isEn ? 'Actual Time' : 'የተመዘገበበት ሰዓት', attendedAt, ctx),
              if (recorder != null) _detailRow(isEn ? 'Recorded by' : 'መዝጋቢ', recorder, ctx),
              if (via != null) _detailRow(isEn ? 'Method' : 'መንገድ', via == 'qr' ? 'QR Code Scan' : 'Manual Entry', ctx),
              if (notes != null && notes.isNotEmpty) _detailRow(isEn ? 'Notes' : 'ማስታወሻ', notes, ctx),
              if (sigUrl != null) ...[
                const SizedBox(height: 12),
                Text(isEn ? 'Member Signature' : 'የአባሉ ፊርማ', style: ctx.sans(12, weight: FontWeight.w700, color: p.muted)),
                const SizedBox(height: 6),
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Image.network(
                      sigUrl,
                      errorBuilder: (context, error, stackTrace) => Text(isEn ? 'Signature on file' : 'ፊርማ ተመዝግቧል', style: ctx.sans(12, color: Colors.grey)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: context.sans(12, color: context.palette.muted))),
          Expanded(child: Text(value, style: context.sans(13, weight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. BY PROGRAM VIEW (Programs & Occurrences)
  // ---------------------------------------------------------------------------
  Widget _buildByProgramView(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;

    if (_loadingPrograms && _programsList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_programsList.isEmpty) {
      return Center(
        child: Text(isEn ? 'No attendance programs found for $_year' : 'ለ$_year የተገኘ መርሐ ግብር የለም'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: _programsList.length,
      itemBuilder: (ctx, idx) {
        final prog = _programsList[idx];
        final id = asIntOr(prog['id']);
        final title = asStr(prog['title']) ?? '';
        final cat = asStr(prog['category_name']) ?? '';
        final sessions = asIntOr(prog['session_count']);
        final suspended = asIntOr(prog['suspended_count']);
        final pres = asIntOr(prog['present_count']);
        final abs = asIntOr(prog['absent_count']);
        final expected = asIntOr(prog['total_expected']);
        final rate = asDouble(prog['attendance_rate']);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: p.muted.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: context.serif(16, weight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.maroon),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$rate%', style: context.sans(12, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
                if (cat.isNotEmpty) Text(cat, style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('• $sessions ${isEn ? "Sessions" : "ክስተቶች"}', style: context.sans(12, color: p.muted)),
                    if (suspended > 0) ...[
                      const SizedBox(width: 8),
                      Text('• $suspended ${isEn ? "Suspended" : "የተቋረጡ"}', style: context.sans(12, color: Colors.orange, weight: FontWeight.w600)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation(rate >= 80 ? AppColors.success : AppColors.maroon),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${isEn ? "Present" : "የተገኙ"}: $pres', style: context.sans(12, color: AppColors.success, weight: FontWeight.w600)),
                    Text('${isEn ? "Absent" : "የቀሩ"}: $abs', style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600)),
                    Text('${isEn ? "Expected" : "የሚጠበቁ"}: $expected', style: context.sans(12, color: p.muted)),
                    TextButton(
                      child: Text(isEn ? 'View Roster' : 'ዝርዝር ይመልከቱ'),
                      onPressed: () {
                        setState(() {
                          _programFilter = id;
                          _currentView = 1; // jump to Month Details with program filtered
                        });
                        _recordsCtrl.refresh();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. BY MEMBER VIEW (Individual Profile & History)
  // ---------------------------------------------------------------------------
  Widget _buildByMemberView(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;
    final user = asJson(_memberProfile['user']);
    final rate = asDouble(_memberProfile['attendance_rate']);
    final totalPres = asIntOr(_memberProfile['total_present']);
    final totalAbs = asIntOr(_memberProfile['total_absent']);
    final totalExp = asIntOr(_memberProfile['total_expected']);
    final months = asJsonList(_memberProfile['months']);
    final programs = asJsonList(_memberProfile['programs_breakdown']);
    final records = asJsonList(_memberProfile['records'] ?? _memberProfile['recent_records']);

    return Column(
      children: [
        // Member Search Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _memberSearchCtrl,
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search by name, member ID or phone...' : 'በአባል ስም፣ መታወቂያ ወይም ስልክ ይፈልጉ...',
                      hintStyle: context.sans(12, color: p.muted),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _memberSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _memberSearchCtrl.clear();
                                setState(() {
                                  _memberSearchResults = const [];
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (val) => _searchMembers(val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                onPressed: () => _searchMembers(_memberSearchCtrl.text),
                child: Text(isEn ? 'Search' : 'ፈልግ'),
              ),
            ],
          ),
        ),

        if (_searchingMembers)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_memberSearchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _memberSearchResults.length,
              itemBuilder: (ctx, idx) {
                final m = _memberSearchResults[idx];
                final mid = asIntOr(m['id']);
                final name = asStr(m['full_name']) ?? '';
                final mno = asStr(m['member_no']);
                final phone = asStr(m['phone']);
                final avatar = asStr(m['avatar_url']);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: p.muted.withValues(alpha: 0.15)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.maroon.withValues(alpha: 0.1),
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null ? const Icon(Icons.person, color: AppColors.maroon) : null,
                    ),
                    title: Text(name, style: context.serif(15, weight: FontWeight.w700)),
                    subtitle: Text([if (mno != null) 'ID: $mno', ?phone].join(' · '), style: context.sans(12, color: p.muted)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      setState(() => _memberSearchResults = const []);
                      _loadMemberProfile(mid);
                    },
                  ),
                );
              },
            ),
          )
        else if (_loadingMember)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (user.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                isEn ? 'Search for a member above to inspect their yearly attendance.' : 'የአባሉን ዓመታዊ መረጃ ለማየት ከላይ ይፈልጉ።',
                style: context.sans(13, color: p.muted),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                // Member Profile Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.muted.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asStr(user['full_name']) ?? '', style: context.serif(17, weight: FontWeight.w700)),
                                Text([if (user['member_no'] != null) 'ID: ${user['member_no']}', if (user['phone'] != null) user['phone']].join(' · '), style: context.sans(12, color: p.muted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rate >= 80 ? AppColors.success : (rate >= 50 ? AppColors.gold : AppColors.maroon),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$rate%', style: context.sans(13, weight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _kpiMini(isEn ? 'Present' : 'የተገኙ', '$totalPres', AppColors.success, context),
                          _kpiMini(isEn ? 'Absent' : 'የቀሩ', '$totalAbs', AppColors.danger, context),
                          _kpiMini(isEn ? 'Expected' : 'የሚጠበቁ', '$totalExp', Colors.grey.shade700, context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Grouping Mode Segmented Toggle (By Month vs By Program vs History)
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text(isEn ? 'By Month' : 'ወር በወር'),
                      icon: const Icon(Icons.calendar_month, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(isEn ? 'By Program' : 'በመርሐ ግብር'),
                      icon: const Icon(Icons.event_note, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text(isEn ? 'Full History' : 'ሙሉ ታሪክ'),
                      icon: const Icon(Icons.history_rounded, size: 16),
                    ),
                  ],
                  selected: {_memberGroupTab},
                  onSelectionChanged: (s) => setState(() => _memberGroupTab = s.first),
                ),
                const SizedBox(height: 12),

                // Tab 0: 13 Months Breakdown
                if (_memberGroupTab == 0) ...[
                  Text(isEn ? '$_year Monthly Breakdown' : 'የ$_year የወር በወር የመገኘት ዝርዝር', style: context.serif(15, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: months.map((m) {
                      final mNum = asIntOr(m['month']);
                      final mName = isEn ? asStr(m['month_name_en']) : asStr(m['month_name_am']);
                      final mRate = asDouble(m['attendance_rate']);
                      final mPres = asIntOr(m['present']);
                      final mExp = asIntOr(m['expected']);

                      return Container(
                        width: (MediaQuery.of(context).size.width - 40) / 2,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.muted.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(mName ?? '$mNum', style: context.sans(12, weight: FontWeight.w700)),
                                Text('$mRate%', style: context.sans(11, weight: FontWeight.w700, color: mRate >= 80 ? AppColors.success : AppColors.maroon)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${isEn ? "Attended" : "የተገኙ"}: $mPres / $mExp', style: context.sans(10, color: p.muted)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Tab 1: By Program Breakdown
                if (_memberGroupTab == 1) ...[
                  Text(isEn ? '$_year Attendance Grouped by Program' : 'የ$_year መገኘት በመርሐ ግብር', style: context.serif(15, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (programs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(isEn ? 'No program records found.' : 'ምንም የመርሐ ግብር መዝገብ አልተገኘም።', style: context.sans(12, color: p.muted)),
                    )
                  else
                    ...programs.map((prog) {
                      final pTitle = asStr(prog['program_title']) ?? '';
                      final pCat = asStr(prog['category_name']) ?? '';
                      final pPres = asIntOr(prog['present']);
                      final pAbs = asIntOr(prog['absent']);
                      final pExp = asIntOr(prog['total']);
                      final pRate = asDouble(prog['rate']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.muted.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(pTitle, style: context.serif(14, weight: FontWeight.w700))),
                                Text('$pRate%', style: context.sans(12, weight: FontWeight.w700, color: pRate >= 80 ? AppColors.success : AppColors.maroon)),
                              ],
                            ),
                            if (pCat.isNotEmpty) Text(pCat, style: context.sans(11, color: AppColors.maroon)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (pRate / 100).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: Colors.black12,
                                valueColor: AlwaysStoppedAnimation(pRate >= 80 ? AppColors.success : AppColors.maroon),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${isEn ? "Present" : "የተገኙ"}: $pPres', style: context.sans(11, color: AppColors.success, weight: FontWeight.w600)),
                                Text('${isEn ? "Absent" : "የቀሩ"}: $pAbs', style: context.sans(11, color: AppColors.danger, weight: FontWeight.w600)),
                                Text('${isEn ? "Total Sessions" : "ጠቅላላ"}: $pExp', style: context.sans(11, color: p.muted)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],

                // Tab 2: Full Chronological Records
                if (_memberGroupTab == 2) ...[
                  Text(isEn ? 'Complete Attendance History (${records.length})' : 'ሙሉ የመገኘት ታሪክ (${records.length})', style: context.serif(15, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(isEn ? 'No records available.' : 'ምንም መዝገብ የለም።', style: context.sans(12, color: p.muted)),
                    )
                  else
                    ...records.map((r) => _buildRecordCard(context, r, f, isEn)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER SHEET
  // ---------------------------------------------------------------------------
  void _openFilterSheet(BuildContext context, bool isEn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEn ? 'Filter Attendance' : 'የመገኘት ማጣሪያ', style: ctx.serif(18, weight: FontWeight.w700)),
                      TextButton(
                        child: Text(isEn ? 'Reset' : 'ዳግም አስጀምር'),
                        onPressed: () {
                          setSheetState(() {
                            _statusFilter = null;
                            _programFilter = null;
                            _memberGroupFilter = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(isEn ? 'Status' : 'ሁኔታ', style: ctx.sans(13, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(isEn ? 'All' : 'ሁሉም'),
                        selected: _statusFilter == null,
                        onSelected: (_) => setSheetState(() => _statusFilter = null),
                      ),
                      ChoiceChip(
                        label: Text(isEn ? 'Present' : 'የተገኙ'),
                        selected: _statusFilter == 'present',
                        onSelected: (_) => setSheetState(() => _statusFilter = 'present'),
                      ),
                      ChoiceChip(
                        label: Text(isEn ? 'Absent' : 'የቀሩ'),
                        selected: _statusFilter == 'absent',
                        onSelected: (_) => setSheetState(() => _statusFilter = 'absent'),
                      ),
                      ChoiceChip(
                        label: Text(isEn ? 'Excused' : 'ፈቃድ'),
                        selected: _statusFilter == 'excused',
                        onSelected: (_) => setSheetState(() => _statusFilter = 'excused'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {});
                        _loadYearSummary();
                        _loadMonthSummary();
                        _recordsCtrl.refresh();
                      },
                      child: Text(isEn ? 'Apply Filters' : 'ማጣሪያዎችን ተግብር'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

