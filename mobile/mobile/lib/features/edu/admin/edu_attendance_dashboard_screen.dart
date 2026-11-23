// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import '../../admin/report_export.dart';
import '../../guidance/contextual_help_sheet.dart';

/// Dedicated Education Admin Attendance Dashboard.
/// Features dual-perspective views:
/// 1. Student Attendance View (individual student full history across education programs)
/// 2. Program Attendance & Performance View (student performance table, comparisons & filters)
/// Integrated with 13-month Ethiopian Calendar navigation, visual analytics, and export.
class EduAttendanceDashboardScreen extends ConsumerStatefulWidget {
  const EduAttendanceDashboardScreen({super.key, this.initialStudentId});
  final int? initialStudentId;

  @override
  ConsumerState<EduAttendanceDashboardScreen> createState() => _EduAttendanceDashboardScreenState();
}

class _EduAttendanceDashboardScreenState extends ConsumerState<EduAttendanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _ethMonthsAm = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ',
    'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ',
    'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'
  ];

  static const _ethMonthsEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas',
    'Tir', 'Yekatit', 'Megabit', 'Miyazya',
    'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'
  ];

  // Theme Constants (Education Brand Identity)
  static const _burgundy = Color(0xFF650D20);
  static const _gold = Color(0xFFC6A044);
  static const _cream = Color(0xFFFFF8E9);

  // Filters State
  int _year = 2019;
  int? _selectedMonth; // null = all year, 1..13
  int? _academicYearId;
  int? _levelId;
  int? _classId;
  int? _courseId;
  int? _programId;
  String? _status; // null/all, present, absent, excused
  String _searchQuery = '';

  // Selected Student for Student Attendance View
  int? _selectedStudentId;
  Json? _selectedStudentProfile;
  bool _loadingStudentProfile = false;

  // Dashboard Data State
  Json _dashboardData = const {};
  bool _loading = false;
  String? _error;
  bool _showAnalytics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedStudentId = widget.initialStudentId;
    _loadDashboard();
    if (_selectedStudentId != null) {
      _loadStudentProfile(_selectedStudentId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(eduRepositoryProvider);
      final res = await repo.adminAttendanceDashboard(
        year: _year,
        month: _selectedMonth,
        academicYearId: _academicYearId,
        levelId: _levelId,
        classId: _classId,
        courseId: _courseId,
        programId: _programId,
        status: _status,
        q: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _dashboardData = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadStudentProfile(int studentId) async {
    setState(() => _loadingStudentProfile = true);
    try {
      final repo = ref.read(eduRepositoryProvider);
      final res = await repo.adminAttendanceStudentProfile(
        studentId,
        year: _year,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _selectedStudentId = studentId;
          _selectedStudentProfile = res;
          _loadingStudentProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStudentProfile = false);
    }
  }

  Json _exportFilters() => {
        'year': _year,
        if (_selectedMonth != null) 'month': _selectedMonth,
        if (_academicYearId != null) 'academic_year_id': _academicYearId,
        if (_levelId != null) 'level_id': _levelId,
        if (_classId != null) 'class_id': _classId,
        if (_courseId != null) 'course_id': _courseId,
        if (_programId != null) 'program_id': _programId,
        if (_status != null) 'status': _status,
        if (_searchQuery.isNotEmpty) 'q': _searchQuery,
        if (_selectedStudentId != null) 'user_id': _selectedStudentId,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Education Attendance Dashboard' : 'የትምህርት ክትትል ዳሽቦርድ'),
        backgroundColor: _burgundy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _showAnalytics
                ? (isEn ? 'Hide Analytics' : 'ትንታኔ ደብቅ')
                : (isEn ? 'Show Analytics' : 'ትንታኔ አሳይ'),
            icon: Icon(_showAnalytics ? Icons.analytics : Icons.analytics_outlined),
            onPressed: () => setState(() => _showAnalytics = !_showAnalytics),
          ),
          IconButton(
            tooltip: isEn ? 'Filter Options' : 'ማጣሪያዎች',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _openFilterBottomSheet,
          ),
          ReportExportButton(
            kind: 'attendance',
            label: isEn ? 'Education Attendance' : 'የትምህርት ክትትል ሪፖርት',
            filters: _exportFilters,
          ),
          const ContextualHelpButton(screenRoute: '/edu/admin'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: context.sans(14, weight: FontWeight.w700),
          tabs: [
            Tab(
              icon: const Icon(Icons.person_pin_rounded, size: 20),
              text: isEn ? 'Student Attendance' : 'የተማሪዎች ክትትል',
            ),
            Tab(
              icon: const Icon(Icons.assessment_rounded, size: 20),
              text: isEn ? 'Program Performance' : 'የመርሐግብር አፈጻጸም',
            ),
          ],
        ),
      ),
      body: _loading && _dashboardData.isEmpty
          ? const Center(child: LoadingView())
          : _error != null && _dashboardData.isEmpty
              ? Center(child: ErrorView(error: _error!, onRetry: _loadDashboard))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 1. Ethiopian Calendar Month Navigation Bar
                      _buildMonthNavigation(isEn),
                      const SizedBox(height: 12),

                      // 2. Dashboard Top KPI Cards
                      _buildKpiSummaryCards(isEn),
                      const SizedBox(height: 12),

                      // 3. Visual Analytics Section (Collapsible)
                      if (_showAnalytics) ...[
                        _buildVisualAnalyticsSection(isEn),
                        const SizedBox(height: 16),
                      ],

                      // 4. Primary Views Content (Tabbed)
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          return _tabController.index == 0
                              ? _buildStudentAttendanceView(isEn)
                              : _buildProgramPerformanceView(isEn);
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Ethiopian Calendar Month Navigation Bar
  // ---------------------------------------------------------------------------
  Widget _buildMonthNavigation(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Icon(Icons.calendar_month_rounded, size: 18, color: _burgundy),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Ethiopian Year:' : 'የኢትዮጵያ ዓመተ ምሕረት፦',
                style: context.sans(13, weight: FontWeight.w600, color: context.palette.muted),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _year,
                isDense: true,
                underline: const SizedBox(),
                style: context.sans(14, weight: FontWeight.w700, color: _burgundy),
                items: [2017, 2018, 2019, 2020].map((y) {
                  return DropdownMenuItem<int>(
                    value: y,
                    child: Text('$y ዓ.ም'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _year) {
                    setState(() => _year = val);
                    _loadDashboard();
                    if (_selectedStudentId != null) _loadStudentProfile(_selectedStudentId!);
                  }
                },
              ),
              const Spacer(),
              if (_selectedMonth != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedMonth = null);
                    _loadDashboard();
                    if (_selectedStudentId != null) _loadStudentProfile(_selectedStudentId!);
                  },
                  icon: const Icon(Icons.clear, size: 14),
                  label: Text(isEn ? 'All Months' : 'ሙሉ ዓመት'),
                  style: TextButton.styleFrom(
                    foregroundColor: _burgundy,
                    textStyle: context.sans(12, weight: FontWeight.w600),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(isEn ? 'All Months' : 'ሁሉም ወራት'),
                  selected: _selectedMonth == null,
                  selectedColor: _burgundy,
                  backgroundColor: _cream,
                  labelStyle: TextStyle(
                    color: _selectedMonth == null ? Colors.white : _burgundy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMonth = null);
                      _loadDashboard();
                      if (_selectedStudentId != null) _loadStudentProfile(_selectedStudentId!);
                    }
                  },
                ),
                const SizedBox(width: 6),
                for (int m = 1; m <= 13; m++) ...[
                  ChoiceChip(
                    label: Text(isEn ? _ethMonthsEn[m - 1] : _ethMonthsAm[m - 1]),
                    selected: _selectedMonth == m,
                    selectedColor: _burgundy,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: _selectedMonth == m ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: _selectedMonth == m ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedMonth = selected ? m : null);
                      _loadDashboard();
                      if (_selectedStudentId != null) _loadStudentProfile(_selectedStudentId!);
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Top KPI Summary Cards
  // ---------------------------------------------------------------------------
  Widget _buildKpiSummaryCards(bool isEn) {
    final kpi = (_dashboardData['kpi'] as Json?) ?? const {};
    final totalStudents = kpi['total_students'] ?? 0;
    final totalSessions = kpi['total_sessions'] ?? 0;
    final present = kpi['present'] ?? 0;
    final absent = kpi['absent'] ?? 0;
    final excused = kpi['excused'] ?? 0;
    final rate = (kpi['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final suspended = kpi['suspended_sessions'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: isEn ? 'Total Students' : 'ጠቅላላ ተማሪዎች',
              value: '$totalStudents',
              icon: Icons.groups_rounded,
              color: const Color(0xFF1E3A8A),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: isEn ? 'Program Sessions' : 'የመርሐግብር ክፍለ ጊዜ',
              value: '$totalSessions',
              icon: Icons.event_available_rounded,
              color: const Color(0xFF0D9488),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: isEn ? 'Present' : 'የተገኙ',
              value: '$present',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: isEn ? 'Absent' : 'የቀሩ',
              value: '$absent',
              icon: Icons.cancel_rounded,
              color: Colors.red.shade700,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: isEn ? 'Excused' : 'ፈቃድ',
              value: '$excused',
              icon: Icons.info_rounded,
              color: Colors.amber.shade800,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: isEn ? 'Overall Attendance' : 'አጠቃላይ የክትትል ምጣኔ',
              value: '$rate%',
              subtitle: suspended > 0 ? (isEn ? '$suspended Suspended' : '$suspended የተሰረዙ') : null,
              icon: Icons.speed_rounded,
              color: rate >= 80 ? AppColors.success : (rate >= 60 ? Colors.orange.shade800 : Colors.red.shade700),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    String? subtitle,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.sans(11, weight: FontWeight.w600, color: context.palette.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: context.sans(18, weight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.sans(10, weight: FontWeight.w600, color: Colors.orange.shade800),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Visual Analytics Section
  // ---------------------------------------------------------------------------
  Widget _buildVisualAnalyticsSection(bool isEn) {
    final analytics = (_dashboardData['analytics'] as Json?) ?? const {};
    final monthlyTrends = (analytics['monthly_trends'] as List?)?.cast<Json>() ?? const [];
    final byProgram = (analytics['by_program'] as List?)?.cast<Json>() ?? const [];
    final byClass = (analytics['by_class'] as List?)?.cast<Json>() ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: _burgundy, size: 20),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Attendance Visual Analytics' : 'የክትትል ትንታኔ እና አፈጻጸም',
                style: context.sans(15, weight: FontWeight.w700, color: _burgundy),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withOpacity(0.4)),
                ),
                child: Text(
                  '$_year ዓ.ም',
                  style: context.sans(11, weight: FontWeight.w700, color: _burgundy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 13-Month Trend Chart
          Text(
            isEn ? '13 Ethiopian Months Trend' : 'የ13ቱ የኢትዮጵያ ወራት የክትትል ሂደት',
            style: context.sans(12, weight: FontWeight.w700, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in monthlyTrends) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(m['rate'] as num?)?.toDouble() ?? 0}%',
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: (((m['rate'] as num?)?.toDouble() ?? 0) / 100 * 55).clamp(4.0, 55.0),
                            decoration: BoxDecoration(
                              color: _selectedMonth == m['month']
                                  ? _burgundy
                                  : (((m['rate'] as num?)?.toDouble() ?? 0) >= 80
                                      ? AppColors.success
                                      : (((m['rate'] as num?)?.toDouble() ?? 0) >= 50
                                          ? _gold
                                          : Colors.red.shade400)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEn ? '${m['month']}' : (m['month_name_am'] as String?)?.substring(0, 2) ?? '${m['month']}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: _selectedMonth == m['month'] ? FontWeight.w800 : FontWeight.w500,
                              color: _selectedMonth == m['month'] ? _burgundy : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Program and Class Comparisons (Two Columns on wide, Stacked on narrow)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              final colWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  // By Program
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Attendance by Program' : 'በመርሐግብር አፈጻጸም',
                          style: context.sans(12, weight: FontWeight.w700, color: const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        if (byProgram.isEmpty)
                          Text(isEn ? 'No program records' : 'ምንም የመርሐግብር መረጃ የለም',
                              style: context.sans(11, color: Colors.grey))
                        else
                          for (final p in byProgram.take(4)) ...[
                            _buildProgressBarRow(
                              label: (p['title'] as String?) ?? 'Program',
                              rate: (p['rate'] as num?)?.toDouble() ?? 0.0,
                              countLabel: '${p['present']}/${p['total']}',
                              barColor: _burgundy,
                            ),
                            const SizedBox(height: 6),
                          ],
                      ],
                    ),
                  ),

                  // By Class
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Attendance by Class' : 'በክፍል አፈጻጸም',
                          style: context.sans(12, weight: FontWeight.w700, color: const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        if (byClass.isEmpty)
                          Text(isEn ? 'No class records' : 'ምንም የክፍል መረጃ የለም',
                              style: context.sans(11, color: Colors.grey))
                        else
                          for (final c in byClass.take(4)) ...[
                            _buildProgressBarRow(
                              label: (c['name'] as String?) ?? 'Class',
                              rate: (c['rate'] as num?)?.toDouble() ?? 0.0,
                              countLabel: '${c['present']}/${c['total']}',
                              barColor: _gold,
                            ),
                            const SizedBox(height: 6),
                          ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarRow({
    required String label,
    required double rate,
    required String countLabel,
    required Color barColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: context.sans(11, weight: FontWeight.w600, color: const Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$countLabel ($rate%)',
              style: context.sans(11, weight: FontWeight.w700, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (rate / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4A. Student Attendance View
  // ---------------------------------------------------------------------------
  Widget _buildStudentAttendanceView(bool isEn) {
    final students = (_dashboardData['students_performance'] as List?)?.cast<Json>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Picker Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Select Student' : 'ተማሪ ይምረጡ',
                style: context.sans(13, weight: FontWeight.w700, color: _burgundy),
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                Text(isEn ? 'No enrolled students found for current filters.' : 'በተመረጡት ማጣሪያዎች ተማሪዎች አልተገኙም።',
                    style: context.sans(12, color: Colors.grey))
              else
                DropdownButtonFormField<int>(
                  value: _selectedStudentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    hintText: isEn ? 'Choose a student to inspect…' : 'ክትትላቸውን ለመመልከት ተማሪ ይምረጡ…',
                  ),
                  items: students.map((s) {
                    final name = (s['full_name'] as String?) ?? 'Student';
                    final cls = (s['class_name'] as String?) ?? '';
                    final rate = (s['rate'] as num?)?.toDouble() ?? 0.0;
                    return DropdownMenuItem<int>(
                      value: s['id'] as int?,
                      child: Text('$name · $cls ($rate%)'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      _loadStudentProfile(id);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Selected Student Details & History
        if (_loadingStudentProfile)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: LoadingView()))
        else if (_selectedStudentProfile != null) ...[
          _buildSelectedStudentSummaryCard(isEn),
          const SizedBox(height: 14),
          _buildStudentAttendanceChronologicalList(isEn),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: EmptyView(
                icon: Icons.person_search_rounded,
                message: isEn
                    ? 'Select a student above to inspect their complete attendance journey.'
                    : 'ሙሉ የክትትል ታሪካቸውን ለመመልከት ከላይ ተማሪ ይምረጡ።',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedStudentSummaryCard(bool isEn) {
    final profile = _selectedStudentProfile!;
    final s = (profile['student'] as Json?) ?? const {};
    final sum = (profile['summary'] as Json?) ?? const {};

    final fullName = (s['full_name'] as String?) ?? 'Student';
    final className = (s['class_name'] as String?) ?? '—';
    final gradeName = (s['grade_name'] as String?) ?? '—';
    final ayName = (s['academic_year_name'] as String?) ?? '—';
    final phone = (s['phone'] as String?) ?? '—';
    final memberNo = (s['member_no'] as String?) ?? '—';
    final photo = s['profile_image'] as String?;

    final totalPrograms = sum['total_scheduled_programs'] ?? 0;
    final present = sum['present_sessions'] ?? 0;
    final absent = sum['absent_sessions'] ?? 0;
    final excused = sum['excused_sessions'] ?? 0;
    final suspended = sum['suspended_sessions'] ?? 0;
    final rate = (sum['attendance_rate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _cream,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(
                        fullName.isNotEmpty ? fullName.substring(0, 1) : 'S',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _burgundy),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: context.sans(16, weight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$gradeName · $className ($ayName)',
                      style: context.sans(12, weight: FontWeight.w600, color: _burgundy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isEn ? 'ID:' : 'መለያ፦'} $memberNo · $phone',
                      style: context.sans(11, color: context.palette.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: rate >= 80 ? AppColors.success.withOpacity(0.12) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rate >= 80 ? AppColors.success : Colors.orange),
                ),
                child: Column(
                  children: [
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: rate >= 80 ? AppColors.success : Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      isEn ? 'Attendance' : 'ክትትል',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: rate >= 80 ? AppColors.success : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Student Summary Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric(isEn ? 'Programs' : 'መርሐግብራት', '$totalPrograms', Icons.event_note),
              _buildMiniMetric(isEn ? 'Present' : 'የተገኙ', '$present', Icons.check_circle, color: AppColors.success),
              _buildMiniMetric(isEn ? 'Absent' : 'የቀሩ', '$absent', Icons.cancel, color: Colors.red.shade700),
              _buildMiniMetric(isEn ? 'Excused' : 'ፈቃድ', '$excused', Icons.info, color: Colors.amber.shade800),
              if (suspended > 0)
                _buildMiniMetric(isEn ? 'Suspended' : 'የተሰረዙ', '$suspended', Icons.pause_circle, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, {Color? color}) {
    final c = color ?? _burgundy;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStudentAttendanceChronologicalList(bool isEn) {
    final records = (_selectedStudentProfile?['records'] as List?)?.cast<Json>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Chronological Attendance History' : 'የክትትል ዝርዝር ታሪክ (በቅደም ተከተል)',
              style: context.sans(14, weight: FontWeight.w700, color: _burgundy),
            ),
            Text(
              '${records.length} ${isEn ? 'records' : 'መዝገቦች'}',
              style: context.sans(12, color: context.palette.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(isEn ? 'No attendance records found.' : 'ምንም የክትትል መዝገብ አልተገኘም።'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final r = records[idx];
              return _buildAttendanceRecordCard(r, isEn);
            },
          ),
      ],
    );
  }

  Widget _buildAttendanceRecordCard(Json r, bool isEn) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final programTitle = (r['program_title'] as String?) ?? 'Program';
    final gregDate = (r['occurrence_date'] as String?) ?? '';
    final calendarDate = (r['calendar_date'] as String?) ?? '';
    final status = (r['status'] as String?) ?? 'present';
    final attendedAt = r['attended_at'] as String?;
    final hasSig = r['has_signature'] == true;
    final className = (r['class_name'] as String?) ?? '';
    final courseName = (r['course_name'] as String?) ?? '';

    final isPresent = status == 'present' || status == 'late';
    final isAbsent = status == 'absent';

    final statusColor = isPresent ? AppColors.success : (isAbsent ? Colors.red.shade700 : Colors.amber.shade800);
    final statusLabel = isPresent ? (isEn ? 'Present' : 'ተገኝቷል') : (isAbsent ? (isEn ? 'Absent' : 'ቀርቷል') : (isEn ? 'Excused' : 'ፈቃድ'));

    return InkWell(
      onTap: () => _openRecordDetailModal(id, isEn),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    programTitle,
                    style: context.sans(13, weight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$calendarDate ($gregDate)',
                  style: context.sans(11, color: Colors.grey.shade800),
                ),
                if (attendedAt != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    attendedAt.length >= 16 ? attendedAt.substring(11, 16) : attendedAt,
                    style: context.sans(11, color: Colors.grey.shade800),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (className.isNotEmpty || courseName.isNotEmpty) ...[
                  Icon(Icons.school_outlined, size: 13, color: _burgundy),
                  const SizedBox(width: 4),
                  Text(
                    '$className ${courseName.isNotEmpty ? '· $courseName' : ''}',
                    style: context.sans(11, weight: FontWeight.w600, color: _burgundy),
                  ),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                // Signature pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasSig ? AppColors.success.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasSig ? Icons.draw_rounded : Icons.edit_off_rounded,
                        size: 11,
                        color: hasSig ? AppColors.success : Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hasSig ? (isEn ? 'Signed' : 'ተፈርሟል') : (isEn ? 'No Sign' : 'ፊርማ የለም'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: hasSig ? AppColors.success : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4B. Program Attendance & Performance View
  // ---------------------------------------------------------------------------
  Widget _buildProgramPerformanceView(bool isEn) {
    final students = (_dashboardData['students_performance'] as List?)?.cast<Json>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Search & Filter Header
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: isEn ? 'Search student by name or ID…' : 'ተማሪ በስም ወይም መለያ ፈልግ…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
                onSubmitted: (_) => _loadDashboard(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.search, size: 16),
              label: Text(isEn ? 'Filter' : 'አጣራ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Performance Table Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Student Attendance Performance Table' : 'የተማሪዎች ክትትል አፈጻጸም ሠንጠረዥ',
                      style: context.sans(14, weight: FontWeight.w700, color: _burgundy),
                    ),
                    Text(
                      '${students.length} ${isEn ? 'Students' : 'ተማሪዎች'}',
                      style: context.sans(12, color: context.palette.muted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(isEn ? 'No student attendance records matching criteria.' : 'በተመረጡት መስፈርቶች የተማሪዎች መረጃ አልተገኘም።'),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowColor: WidgetStateProperty.all(_cream),
                    columns: [
                      DataColumn(label: Text(isEn ? 'Student' : 'ተማሪ', style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text(isEn ? 'Class' : 'ክፍል', style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text(isEn ? 'Present' : 'የተገኙ', style: const TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text(isEn ? 'Absent' : 'የቀሩ', style: const TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text(isEn ? 'Excused' : 'ፈቃድ', style: const TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text(isEn ? 'Attendance %' : 'ምጣኔ %', style: const TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text(isEn ? 'Action' : 'ዝርዝር', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: students.map((s) {
                      final uid = (s['id'] as num?)?.toInt() ?? 0;
                      final name = (s['full_name'] as String?) ?? 'Student';
                      final cls = (s['class_name'] as String?) ?? '—';
                      final pres = s['present'] ?? 0;
                      final abs = s['absent'] ?? 0;
                      final exc = s['excused'] ?? 0;
                      final rate = (s['rate'] as num?)?.toDouble() ?? 0.0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _cream,
                                  child: Text(name.isNotEmpty ? name.substring(0, 1) : 'S', style: const TextStyle(fontSize: 10, color: _burgundy)),
                                ),
                                const SizedBox(width: 8),
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(cls)),
                          DataCell(Text('$pres', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success))),
                          DataCell(Text('$abs', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700))),
                          DataCell(Text('$exc', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber.shade800))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rate >= 80 ? AppColors.success.withOpacity(0.12) : (rate >= 50 ? _gold.withOpacity(0.15) : Colors.red.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$rate%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: rate >= 80 ? AppColors.success : (rate >= 50 ? Colors.orange.shade900 : Colors.red.shade700),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: _burgundy),
                              tooltip: isEn ? 'View Student History' : 'የተማሪውን ታሪክ ይመልከቱ',
                              onPressed: () {
                                _loadStudentProfile(uid);
                                _tabController.animateTo(0);
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Detailed Attendance Record Modal
  // ---------------------------------------------------------------------------
  Future<void> _openRecordDetailModal(int attendanceId, bool isEn) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Json>(
          future: ref.read(eduRepositoryProvider).adminAttendanceRecordDetail(attendanceId),
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: LoadingView())
                  : snapshot.hasError
                      ? Center(child: Text('Error: ${snapshot.error}'))
                      : _buildRecordDetailSheetContent(snapshot.data ?? const {}, isEn),
            );
          },
        );
      },
    );
  }

  Widget _buildRecordDetailSheetContent(Json d, bool isEn) {
    final student = (d['student'] as Json?) ?? const {};
    final prog = (d['program'] as Json?) ?? const {};
    final edu = (d['education'] as Json?) ?? const {};
    final rec = (d['recorder'] as Json?) ?? const {};
    final sig = (d['signature'] as Json?) ?? const {};

    final studentName = (student['full_name'] as String?) ?? 'Student';
    final className = (student['class_name'] as String?) ?? '—';
    final progTitle = (prog['title'] as String?) ?? 'Program';
    final calendarDate = (d['calendar_date'] as String?) ?? '';
    final gregDate = (d['occurrence_date'] as String?) ?? '';
    final status = (d['status'] as String?) ?? 'present';
    final attendedAt = d['attended_at'] as String?;
    final notes = d['notes'] as String?;
    final recorderName = (rec['name'] as String?) ?? '—';
    final hasSig = sig['has_signature'] == true;
    final sigUrl = sig['signature_url'] as String?;

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Attendance Record Details' : 'የክትትል መዝገብ ዝርዝር',
              style: context.sans(16, weight: FontWeight.w800, color: _burgundy),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 10),

        // Student Info
        _buildDetailSection(
          title: isEn ? 'Student Information' : 'የተማሪ መረጃ',
          children: [
            _buildDetailRow(isEn ? 'Full Name:' : 'ሙሉ ስም፦', studentName),
            _buildDetailRow(isEn ? 'Class / Grade:' : 'ክፍል፦', '$className (${student['grade_name'] ?? '—'})'),
            _buildDetailRow(isEn ? 'Member ID / Phone:' : 'መለያ / ስልክ፦', '${student['member_no'] ?? '—'} · ${student['phone'] ?? '—'}'),
          ],
        ),
        const SizedBox(height: 14),

        // Program Info
        _buildDetailSection(
          title: isEn ? 'Program Details' : 'የመርሐግብር መረጃ',
          children: [
            _buildDetailRow(isEn ? 'Program Title:' : 'መርሐግብር፦', progTitle),
            _buildDetailRow(isEn ? 'Calendar Date:' : 'ቀን፦', '$calendarDate ($gregDate)'),
            if (attendedAt != null) _buildDetailRow(isEn ? 'Recorded Time:' : 'የተመዘገበበት ሰዓት፦', attendedAt),
            _buildDetailRow(isEn ? 'Status:' : 'ሁኔታ፦', status.toUpperCase()),
            _buildDetailRow(isEn ? 'Linked Course:' : 'የትምህርት ዓይነት፦', (edu['course_name'] as String?) ?? '—'),
            if (notes != null && notes.isNotEmpty) _buildDetailRow(isEn ? 'Notes:' : 'ማስታወሻ፦', notes),
          ],
        ),
        const SizedBox(height: 14),

        // Recorder & Signature
        _buildDetailSection(
          title: isEn ? 'Audit & Signature Verification' : 'የተቆጣጣሪ እና የፊርማ ማረጋገጫ',
          children: [
            _buildDetailRow(isEn ? 'Recorded By:' : 'መዝጋቢ፦', recorderName),
            _buildDetailRow(
              isEn ? 'Digital Signature:' : 'ዲጂታል ፊርማ፦',
              hasSig ? (isEn ? 'Verified & Signed' : 'የተረጋገጠና የተፈረመ') : (isEn ? 'No Signature Captured' : 'ፊርማ አልተያዘም'),
            ),
          ],
        ),
        if (hasSig && sigUrl != null) ...[
          const SizedBox(height: 12),
          Text(isEn ? 'Signature Preview:' : 'የፊርማ ቅድመ-ዕይታ፦', style: context.sans(12, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cream.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.sans(13, weight: FontWeight.w700, color: _burgundy)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Multi-Criteria Filter Bottom Sheet
  // ---------------------------------------------------------------------------
  void _openFilterBottomSheet() {
    final meta = (_dashboardData['filters_meta'] as Json?) ?? const {};
    final ayList = (meta['academic_years'] as List?)?.cast<Json>() ?? const [];
    final classList = (meta['classes'] as List?)?.cast<Json>() ?? const [];
    final progList = (meta['programs'] as List?)?.cast<Json>() ?? const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ማጣሪያዎች / Filters',
                        style: context.sans(16, weight: FontWeight.w800, color: _burgundy),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _academicYearId = null;
                            _classId = null;
                            _programId = null;
                            _status = null;
                          });
                        },
                        child: const Text('አጽዳ / Reset'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        // Academic Year
                        DropdownButtonFormField<int>(
                          value: _academicYearId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'የአካዳሚክ ዓመት / Academic Year'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('ሁሉም ዓመታት / All')),
                            ...ayList.map((ay) => DropdownMenuItem(value: ay['id'] as int?, child: Text(ay['name'] as String? ?? ''))),
                          ],
                          onChanged: (v) => setSheetState(() => _academicYearId = v),
                        ),
                        const SizedBox(height: 12),

                        // Class
                        DropdownButtonFormField<int>(
                          value: _classId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'ክፍል / Class'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('ሁሉም ክፍሎች / All')),
                            ...classList.map((c) => DropdownMenuItem(value: c['id'] as int?, child: Text(c['name'] as String? ?? ''))),
                          ],
                          onChanged: (v) => setSheetState(() => _classId = v),
                        ),
                        const SizedBox(height: 12),

                        // Program
                        DropdownButtonFormField<int>(
                          value: _programId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'መርሐግብር / Program'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('ሁሉም መርሐግብራት / All')),
                            ...progList.map((p) => DropdownMenuItem(value: p['id'] as int?, child: Text(p['title'] as String? ?? ''))),
                          ],
                          onChanged: (v) => setSheetState(() => _programId = v),
                        ),
                        const SizedBox(height: 12),

                        // Status
                        DropdownButtonFormField<String>(
                          value: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'የክትትል ሁኔታ / Attendance Status'),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('ሁሉም / All')),
                            DropdownMenuItem(value: 'present', child: Text('የተገኙ / Present')),
                            DropdownMenuItem(value: 'absent', child: Text('የቀሩ / Absent')),
                            DropdownMenuItem(value: 'excused', child: Text('ፈቃድ / Excused')),
                          ],
                          onChanged: (v) => setSheetState(() => _status = v),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _loadDashboard();
                      },
                      child: const Text('አጣራ / Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
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

