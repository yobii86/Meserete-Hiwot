import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../members/department_participation.dart' show ethPeriod, periodLabel;
import 'receipt_review_screen.dart';
import 'report_export.dart';

/// Dedicated Financial Management & User-Level Contribution Details Screen.
/// Provides comprehensive KPI summary cards, multi-criteria filters,
/// month-based ordering (paid, partial, pending, unpaid), and detailed user payment profiles.
class ContributionDetailsAdminScreen extends ConsumerStatefulWidget {
  const ContributionDetailsAdminScreen({super.key, this.initialPeriod});
  final String? initialPeriod;

  @override
  ConsumerState<ContributionDetailsAdminScreen> createState() => _ContributionDetailsAdminScreenState();
}

class _ContributionDetailsAdminScreenState extends ConsumerState<ContributionDetailsAdminScreen> {
  late String _period;
  late int _year;
  late int _month;

  String? _status; // null/all, paid, partial, pending, unpaid
  String? _memberGroup; // null/all, youth_adult, choir, etc.
  String? _memberType; // null/all, worker, student
  String _q = '';
  int? _paidMonths;
  int? _unpaidMonths;

  final _ctrl = PagedListController<Json>();
  Json _summary = const {};
  bool _loadingSummary = false;

  bool _showYearAnalytics = true;
  Json _yearSummary = const {};
  bool _loadingYearSummary = false;

  static const _ethMonthsAm = [
    'መስከረም', 'ጥቅምት', 'ሕዳር', 'ታኅሣሥ',
    'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ',
    'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜን'
  ];

  static const _ethMonthsEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas',
    'Tir', 'Yakatit', 'Megabit', 'Miyazya',
    'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Puagme'
  ];

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod ?? ethPeriod(DateTime.now());
    _parsePeriod();
    _showYearAnalytics = widget.initialPeriod == null;
    _loadSummary();
    _loadYearSummary();
  }

  void _parsePeriod() {
    final parts = _period.split('-');
    if (parts.length == 2) {
      _year = int.tryParse(parts[0]) ?? 2019;
      _month = int.tryParse(parts[1]) ?? 1;
    } else {
      _year = 2019;
      _month = 1;
    }
  }

  void _setPeriod(int year, int month) {
    setState(() {
      _year = year;
      _month = month.clamp(1, 13);
      _period = '$_year-${_month.toString().padLeft(2, '0')}';
    });
    _loadSummary();
    _ctrl.refresh();
  }

  void _setYear(int year) {
    setState(() {
      _year = year;
      _period = '$_year-${_month.toString().padLeft(2, '0')}';
    });
    _loadYearSummary();
    _loadSummary();
    _ctrl.refresh();
  }

  Future<void> _loadYearSummary() async {
    setState(() => _loadingYearSummary = true);
    try {
      final repo = ref.read(orgRepositoryProvider);
      final s = await repo.paymentsYearlySummary(
        year: _year,
        memberGroup: _memberGroup,
        memberType: _memberType,
      );
      if (mounted) setState(() => _yearSummary = s);
    } catch (_) {
      // non-blocking
    } finally {
      if (mounted) setState(() => _loadingYearSummary = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final repo = ref.read(orgRepositoryProvider);
      final s = await repo.paymentsSummary(
        period: _period,
        memberGroup: _memberGroup,
        memberType: _memberType,
      );
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      // Summary load failure is non-blocking
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  String _monthName(int m, bool isEn) {
    if (m < 1 || m > 13) return '$m';
    return isEn ? _ethMonthsEn[m - 1] : _ethMonthsAm[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = l.isEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Monthly Contribution Details' : 'የወርሃዊ መዋጮ ዝርዝር አስተዳደር',
          style: context.serif(18, weight: FontWeight.w700),
        ),
        actions: [
          ReportExportButton(
            kind: 'contributions',
            filters: () => {'period': _period},
          ),
          IconButton(
            tooltip: isEn ? 'Review Receipts' : 'ደረሰኞችን ገምግም',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReceiptReviewAdminScreen()),
            ),
          ),
          IconButton(
            tooltip: isEn ? 'Filter Options' : 'የማጣሪያ አማራጮች',
            icon: Badge(
              isLabelVisible: _hasActiveFilters(),
              label: Text('${_activeFilterCount()}'),
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _openFilterSheet(context),
          ),
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_showYearAnalytics) {
                _loadYearSummary();
              } else {
                _loadSummary();
                _ctrl.refresh();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(isEn ? 'Year Analytics' : 'ዓመታዊ ትንተና'),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(isEn ? 'Month Details (${_monthName(_month, isEn)})' : 'የወር ዝርዝር (${_monthName(_month, isEn)})'),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                ),
              ],
              selected: {_showYearAnalytics},
              onSelectionChanged: (s) {
                setState(() => _showYearAnalytics = s.first);
                if (_showYearAnalytics && _yearSummary.isEmpty) _loadYearSummary();
              },
            ),
          ),
          if (_showYearAnalytics)
            Expanded(child: _buildYearAnalyticsView(context, f, isEn))
          else ...[
            // 1. Period & Month Navigation Header
            _buildPeriodSelector(context, isEn),

            // 2. Financial KPI Summary Cards
            _buildSummaryCards(context, f, isEn),

            // 3. Search & Active Filters Bar
            _buildSearchAndChipsBar(context, isEn),

            // 4. Detailed User List with Month-based Payment Ordering
            Expanded(
              child: PagedListView<Json>(
                key: ValueKey('$_period-$_status-$_memberGroup-$_memberType-$_q-$_paidMonths-$_unpaidMonths'),
                controller: _ctrl,
                fetch: (page) => ref.read(orgRepositoryProvider).detailedPayments(
                  period: _period,
                  status: _status,
                  memberGroup: _memberGroup,
                  memberType: _memberType,
                  paidMonths: _paidMonths,
                  unpaidMonths: _unpaidMonths,
                  q: _q.isEmpty ? null : _q,
                  page: page,
                  limit: 50,
                ),
                emptyMessage: isEn ? 'No users found matching current filters' : 'በተመረጡት ማጣሪያዎች የተገኘ አባል የለም',
                itemBuilder: (ctx, user, _) => _buildUserCard(ctx, user, f, isEn),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() =>
      (_status != null && _status != 'all') ||
      (_memberGroup != null && _memberGroup != 'all') ||
      (_memberType != null && _memberType != 'all') ||
      _paidMonths != null ||
      _unpaidMonths != null;

  int _activeFilterCount() {
    var c = 0;
    if (_status != null && _status != 'all') c++;
    if (_memberGroup != null && _memberGroup != 'all') c++;
    if (_memberType != null && _memberType != 'all') c++;
    if (_paidMonths != null) c++;
    if (_unpaidMonths != null) c++;
    return c;
  }

  Widget _buildYearAnalyticsView(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;
    final totalExpected = asDouble(_yearSummary['total_expected_amount'], 0);
    final totalCollected = asDouble(_yearSummary['total_collected_amount'], 0);
    final outstanding = asDouble(_yearSummary['outstanding_amount'], 0);
    final pct = asDouble(_yearSummary['collection_percentage'], 0);
    final expectedUsers = asIntOr(_yearSummary['total_expected_users'], 0);
    final months = asJsonList(_yearSummary['months']);

    return RefreshIndicator(
      color: AppColors.maroon,
      onRefresh: () async {
        await _loadYearSummary();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          // Year Switcher Header
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
                      '$_year ${isEn ? 'E.C. Annual Overview' : 'ዓ.ም. ዓመታዊ የመዋጮ ማጠቃለያ'}',
                      style: context.serif(16, weight: FontWeight.w700, color: AppColors.maroon),
                    ),
                    Text(
                      isEn ? 'Click any month card to view its member list' : 'የአባላቱን ዝርዝር ለማየት ወሩን ይጫኑ',
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

          // Year Summary KPI Card
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
                      isEn ? '$_year Annual Collection' : 'የ$_year ዓመታዊ አጠቃላይ ገቢ',
                      style: context.serif(15, weight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pct >= 80 ? AppColors.success : (pct >= 50 ? AppColors.gold : AppColors.maroon),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pct%',
                        style: context.sans(12, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation(pct >= 80 ? AppColors.success : AppColors.maroon),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Collected' : 'የተሰበሰበ', style: context.sans(11, color: p.muted)),
                          Text(f.money(totalCollected, 'ETB'), style: context.sans(14, weight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Expected' : 'የሚጠበቅ', style: context.sans(11, color: p.muted)),
                          Text(f.money(totalExpected, 'ETB'), style: context.sans(14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEn ? 'Outstanding' : 'ቀሪ', style: context.sans(11, color: p.muted)),
                          Text(f.money(outstanding, 'ETB'), style: context.sans(14, weight: FontWeight.w700, color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 13 Months Grid / Cards
          Text(
            isEn ? 'Month-by-Month Analytics ($expectedUsers Active Members)' : 'የወር በወር ትንተና ($expectedUsers ንቁ አባላት)',
            style: context.serif(15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          if (_loadingYearSummary && months.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ...List.generate(13, (idx) {
              final m = idx + 1;
              final mData = months.firstWhere(
                (item) => asIntOr(item['month']) == m,
                orElse: () => <String, dynamic>{
                  'month': m,
                  'month_name_am': _ethMonthsAm[idx],
                  'month_name_en': _ethMonthsEn[idx],
                  'total_expected_amount': 0,
                  'total_collected_amount': 0,
                  'collection_percentage': 0,
                  'paid_users': 0,
                  'partially_paid_users': 0,
                  'unpaid_users': 0,
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

    final expected = asDouble(data['total_expected_amount'], 0);
    final collected = asDouble(data['total_collected_amount'], 0);
    final pct = asDouble(data['collection_percentage'], 0);
    final paid = asIntOr(data['paid_users'], 0);
    final partial = asIntOr(data['partially_paid_users'], 0);
    final unpaid = asIntOr(data['unpaid_users'], 0);

    final isSelectedMonth = _month == m;

    return Card(
      elevation: isSelectedMonth ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelectedMonth ? AppColors.maroon : p.muted.withValues(alpha: 0.18),
          width: isSelectedMonth ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _setPeriod(_year, m);
          setState(() => _showYearAnalytics = false);
        },
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
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$m',
                          style: context.sans(12, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        monthName,
                        style: context.serif(15, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$pct%',
                        style: context.sans(13, weight: FontWeight.w700, color: pct >= 80 ? AppColors.success : (pct >= 50 ? AppColors.gold : AppColors.maroon)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation(pct >= 80 ? AppColors.success : (pct >= 50 ? AppColors.gold : AppColors.maroon)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${f.money(collected, 'ETB')} / ${f.money(expected, 'ETB')}',
                    style: context.sans(12, weight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      _miniPill(context, label: isEn ? 'Paid: $paid' : 'የከፈሉ፡ $paid', color: AppColors.success),
                      if (partial > 0) ...[
                        const SizedBox(width: 4),
                        _miniPill(context, label: isEn ? 'Part: $partial' : 'ከፊል፡ $partial', color: AppColors.gold),
                      ],
                      const SizedBox(width: 4),
                      _miniPill(context, label: isEn ? 'Unpaid: $unpaid' : 'ያልከፈሉ፡ $unpaid', color: p.muted),
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

  Widget _miniPill(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.sans(10, weight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, bool isEn) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(bottom: BorderSide(color: p.muted.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: isEn ? 'Year Analytics Overview' : 'ዓመታዊ ትንተና ማጠቃለያ',
            icon: const Icon(Icons.analytics_outlined, color: AppColors.maroon, size: 22),
            onPressed: () => setState(() => _showYearAnalytics = true),
          ),
          // Previous Month button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () {
              if (_month > 1) {
                _setPeriod(_year, _month - 1);
              } else {
                _setPeriod(_year - 1, 12);
              }
            },
          ),
          // Month & Year Selector
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickEthiopianPeriod(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_monthName(_month, isEn)} $_year',
                          style: context.serif(16, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.maroon),
                      ],
                    ),
                    Text(
                      isEn
                          ? 'Showing payments from Meskerem through ${_monthName(_month, isEn)}'
                          : 'ከመስከረም እስከ ${_monthName(_month, isEn)} ያሉ ክፍያዎችን ያሳያል',
                      style: context.sans(11, color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Next Month button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () {
              if (_month < 13) {
                _setPeriod(_year, _month + 1);
              } else {
                _setPeriod(_year + 1, 1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, Formatters f, bool isEn) {
    final p = context.palette;
    final totalExpected = asDouble(_summary['total_expected_amount'], 0);
    final totalCollected = asDouble(_summary['total_collected_amount'], 0);
    final outstanding = asDouble(_summary['outstanding_amount'], 0);
    final pct = asDouble(_summary['collection_percentage'], 0);

    final totalUsers = asIntOr(_summary['total_expected_users'], 0);
    final paidUsers = asIntOr(_summary['paid_users'], 0);
    final partialUsers = asIntOr(_summary['partially_paid_users'], 0);
    final pendingUsers = asIntOr(_summary['pending_users'], 0);
    final unpaidUsers = asIntOr(_summary['unpaid_users'], 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.maroon.withValues(alpha: 0.04),
        border: Border(bottom: BorderSide(color: p.muted.withValues(alpha: 0.12))),
      ),
      child: Column(
        children: [
          if (_loadingSummary)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          // Money KPIs
          Row(
            children: [
              _kpiBox(
                context,
                title: isEn ? 'Expected' : 'የሚጠበቅ ድምር',
                value: f.money(totalExpected, 'ETB'),
                color: p.text,
              ),
              const SizedBox(width: 8),
              _kpiBox(
                context,
                title: isEn ? 'Collected' : 'የተሰበሰበ',
                value: f.money(totalCollected, 'ETB'),
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _kpiBox(
                context,
                title: isEn ? 'Outstanding' : 'ያልተከፈለ ቀሪ',
                value: f.money(outstanding, 'ETB'),
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              _kpiBox(
                context,
                title: isEn ? 'Collection' : 'የክንውን %',
                value: '${pct.toStringAsFixed(1)}%',
                color: pct >= 80 ? AppColors.success : (pct >= 50 ? AppColors.gold : AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // User Count Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _userBadge(context, label: isEn ? 'Expected' : 'ተከፋይ', count: totalUsers, color: p.muted),
              _userBadge(context, label: isEn ? 'Fully Paid' : 'ሙሉ የከፈሉ', count: paidUsers, color: AppColors.success),
              _userBadge(context, label: isEn ? 'Partial' : 'ከፊል የከፈሉ', count: partialUsers, color: Colors.orange.shade800),
              _userBadge(context, label: isEn ? 'Pending' : 'በግምገማ ላይ', count: pendingUsers, color: Colors.purple.shade700),
              _userBadge(context, label: isEn ? 'Unpaid' : 'ያልከፈሉ', count: unpaidUsers, color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiBox(BuildContext context, {required String title, required String value, required Color color}) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.muted.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(title, style: context.sans(10, color: p.muted, weight: FontWeight.w600), maxLines: 1),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: context.serif(13, weight: FontWeight.w700, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userBadge(BuildContext context, {required String label, required int count, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: context.sans(11, weight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildSearchAndChipsBar(BuildContext context, bool isEn) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search by name or Member ID...' : 'በስም ወይም በአባል መለያ ፈልግ...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: context.sans(13),
                    onChanged: (v) {
                      setState(() => _q = v.trim());
                      _ctrl.refresh();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: isEn ? 'Status Ordering Filter' : 'የክፍያ ሁኔታ ማጣሪያ',
                icon: Icon(
                  Icons.sort_rounded,
                  color: _status != null ? AppColors.maroon : p.muted,
                ),
                initialValue: _status ?? 'all',
                onSelected: (val) {
                  setState(() => _status = val == 'all' ? null : val);
                  _ctrl.refresh();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'all', child: Text(isEn ? 'All Users (Ordered)' : 'ሁሉም አባላት (በቅደም ተከተል)')),
                  PopupMenuItem(value: 'paid', child: Text(isEn ? '1. Paid Through Month' : '1. እስከዚህ ወር ሙሉ የከፈሉ')),
                  PopupMenuItem(value: 'partial', child: Text(isEn ? '2. Outstanding / Partial' : '2. ቀሪ ክፍያ ያለባቸው (ከፊል)')),
                  PopupMenuItem(value: 'pending', child: Text(isEn ? '3. Pending Receipts' : '3. በማረጋገጥ ላይ ያሉ ደረሰኞች')),
                  PopupMenuItem(value: 'unpaid', child: Text(isEn ? '4. No Payments Recorded' : '4. ምንም ክፍያ ያልተመዘገበላቸው')),
                ],
              ),
            ],
          ),
          if (_hasActiveFilters())
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_status != null)
                      _filterChip(
                        context,
                        label: 'ሁኔታ: $_status',
                        onDeleted: () {
                          setState(() => _status = null);
                          _ctrl.refresh();
                        },
                      ),
                    if (_memberGroup != null)
                      _filterChip(
                        context,
                        label: 'ቡድን: $_memberGroup',
                        onDeleted: () {
                          setState(() => _memberGroup = null);
                          _ctrl.refresh();
                        },
                      ),
                    if (_memberType != null)
                      _filterChip(
                        context,
                        label: 'አይነት: $_memberType',
                        onDeleted: () {
                          setState(() => _memberType = null);
                          _ctrl.refresh();
                        },
                      ),
                    ActionChip(
                      label: Text(isEn ? 'Clear All' : 'ሁሉንም አፅዳ', style: context.sans(11, color: AppColors.maroon)),
                      onPressed: () {
                        setState(() {
                          _status = null;
                          _memberGroup = null;
                          _memberType = null;
                          _paidMonths = null;
                          _unpaidMonths = null;
                        });
                        _ctrl.refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, {required String label, required VoidCallback onDeleted}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: context.sans(11)),
        deleteIcon: const Icon(Icons.close_rounded, size: 14),
        onDeleted: onDeleted,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Json user, Formatters f, bool isEn) {
    final p = context.palette;
    final fullName = asStr(user['full_name']) ?? '';
    final memberId = asStr(user['member_id']) ?? '';
    final memberType = asStr(user['member_type']) ?? 'worker';
    final memberGroup = asStr(user['member_group']) ?? '';
    final status = asStr(user['status']) ?? 'unpaid';
    final monthsPaid = asIntOr(user['months_paid'], 0);
    final totalPaid = asDouble(user['total_paid'], 0);
    final outstanding = asDouble(user['outstanding'], 0);
    final reqRate = asDouble(user['monthly_required'], 0);
    final hasPending = asBool(user['has_pending_receipt']);
    final latestDate = asStr(user['latest_payment_date']);
    final latestMethod = asStr(user['latest_payment_method']);
    final priority = asIntOr(user['priority'], 4);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'paid':
        statusColor = AppColors.success;
        statusLabel = isEn ? 'Paid Through Month' : 'ሙሉ የተከፈለ';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'partial':
        statusColor = Colors.orange.shade800;
        statusLabel = isEn ? 'Partial Payment' : 'ከፊል የተከፈለ';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'pending':
        statusColor = Colors.purple.shade700;
        statusLabel = isEn ? 'Pending Verification' : 'ደረሰኝ በግምገማ ላይ';
        statusIcon = Icons.receipt_long_rounded;
        break;
      default:
        statusColor = AppColors.danger;
        statusLabel = isEn ? 'Unpaid' : 'ያልተከፈለ';
        statusIcon = Icons.cancel_rounded;
        break;
    }

    final paidList = asValues(user['paid_months_list'], (e) => asIntOr(e, 0)).toSet();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: priority == 1
              ? AppColors.success.withValues(alpha: 0.3)
              : (priority == 2 ? Colors.orange.withValues(alpha: 0.3) : p.muted.withValues(alpha: 0.2)),
          width: priority <= 2 ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showUserDetailSheet(context, user, f, isEn),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(statusIcon, size: 20, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: context.sans(14, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (memberId.isNotEmpty)
                              Text(
                                memberId,
                                style: context.sans(11, weight: FontWeight.w600, color: AppColors.maroon),
                              ),
                            if (memberId.isNotEmpty) const Text(' · ', style: TextStyle(color: Colors.grey)),
                            Text(
                              memberType == 'worker' ? (isEn ? 'Worker' : 'ሰራተኛ') : (isEn ? 'Student' : 'ተማሪ'),
                              style: context.sans(11, color: p.muted),
                            ),
                            if (memberGroup.isNotEmpty) ...[
                              const Text(' · ', style: TextStyle(color: Colors.grey)),
                              Text(memberGroup, style: context.sans(11, color: p.muted)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: context.sans(11, weight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Month payment dots indicator
              Row(
                children: [
                  Text(
                    isEn ? 'Months:' : 'የወራት ሁኔታ፡',
                    style: context.sans(11, color: p.muted, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var m = 1; m <= _month; m++)
                          Tooltip(
                            message: '${_monthName(m, isEn)}: ${paidList.contains(m) ? "ተከፍሏል" : "ቀሪ"}',
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: paidList.contains(m) ? AppColors.success : AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: paidList.contains(m) ? AppColors.success : AppColors.danger,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$m',
                                  style: context.sans(
                                    9,
                                    weight: FontWeight.w700,
                                    color: paidList.contains(m) ? Colors.white : AppColors.danger,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Financial figures row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Monthly Rate' : 'ወርሃዊ መዋጮ',
                        style: context.sans(10, color: p.muted),
                      ),
                      Text(
                        f.money(reqRate, 'ETB'),
                        style: context.sans(12, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Paid / Months' : 'የተከፈለ / ወራት',
                        style: context.sans(10, color: p.muted),
                      ),
                      Text(
                        '${f.money(totalPaid, 'ETB')} ($monthsPaid/$_month)',
                        style: context.sans(12, weight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isEn ? 'Outstanding' : 'ቀሪ ያልተከፈለ',
                        style: context.sans(10, color: p.muted),
                      ),
                      Text(
                        f.money(outstanding, 'ETB'),
                        style: context.sans(
                          12,
                          weight: FontWeight.w700,
                          color: outstanding > 0 ? AppColors.danger : p.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Action buttons & quick links
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (latestDate != null)
                    Text(
                      '${isEn ? "Latest:" : "የመጨረሻ:"} $latestDate ${latestMethod != null ? "($latestMethod)" : ""}',
                      style: context.sans(10, color: p.muted),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      if (hasPending)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.purple.shade50,
                          ),
                          onPressed: () => _openPendingReceipt(context, user),
                          child: Text(
                            isEn ? 'Verify Receipt' : 'ደረሰኝ መርምር',
                            style: context.sans(11, weight: FontWeight.w700, color: Colors.purple.shade800),
                          ),
                        ),
                      const SizedBox(width: 6),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.maroon.withValues(alpha: 0.08),
                        ),
                        onPressed: () => _recordCashPayment(context, user),
                        child: Text(
                          isEn ? 'Record Cash' : 'ክፍያ መዝግብ',
                          style: context.sans(11, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                      ),
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

  void _openFilterSheet(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEn ? 'Filter Contributions' : 'የመዋጮ ማጣሪያዎች',
                  style: context.serif(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 14),

                // Member Type Filter
                Text(isEn ? 'Member Type' : 'የአባል አይነት', style: context.sans(12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isEn ? 'All' : 'ሁሉም'),
                      selected: _memberType == null,
                      onSelected: (_) => setSheetState(() => _memberType = null),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Worker' : 'ሰራተኛ'),
                      selected: _memberType == 'worker',
                      onSelected: (_) => setSheetState(() => _memberType = 'worker'),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Student' : 'ተማሪ'),
                      selected: _memberType == 'student',
                      onSelected: (_) => setSheetState(() => _memberType = 'student'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Payment Status Filter
                Text(isEn ? 'Payment Status' : 'የክፍያ ሁኔታ', style: context.sans(12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(isEn ? 'All' : 'ሁሉም'),
                      selected: _status == null,
                      onSelected: (_) => setSheetState(() => _status = null),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Paid' : 'ሙሉ የከፈሉ'),
                      selected: _status == 'paid',
                      onSelected: (_) => setSheetState(() => _status = 'paid'),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Partial' : 'ከፊል የከፈሉ'),
                      selected: _status == 'partial',
                      onSelected: (_) => setSheetState(() => _status = 'partial'),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Pending' : 'ደረሰኝ በግምገማ ላይ'),
                      selected: _status == 'pending',
                      onSelected: (_) => setSheetState(() => _status = 'pending'),
                    ),
                    ChoiceChip(
                      label: Text(isEn ? 'Unpaid' : 'ያልከፈሉ'),
                      selected: _status == 'unpaid',
                      onSelected: (_) => setSheetState(() => _status = 'unpaid'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {});
                      _loadSummary();
                      _ctrl.refresh();
                    },
                    child: Text(isEn ? 'Apply Filters' : 'ማጣሪያዎችን ተግብር'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickEthiopianPeriod(BuildContext context) {
    final isEn = context.l10n.isEn;
    var tempYear = _year;
    var tempMonth = _month;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Select Ethiopian Year & Month' : 'የኢትዮጵያ ዓመተ ምሕረትና ወር ይምረጡ',
                  style: context.serif(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: tempYear,
                        decoration: InputDecoration(
                          labelText: isEn ? 'Year' : 'ዓመተ ምሕረት',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          for (var y = _year - 3; y <= _year + 2; y++)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => tempYear = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        initialValue: tempMonth,
                        decoration: InputDecoration(
                          labelText: isEn ? 'Month' : 'ወር',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          for (var m = 1; m <= 13; m++)
                            DropdownMenuItem(value: m, child: Text(_monthName(m, isEn))),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => tempMonth = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setPeriod(tempYear, tempMonth);
                    },
                    child: Text(isEn ? 'Select Period' : 'ጊዜውን ምረጥ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetailSheet(BuildContext context, Json user, Formatters f, bool isEn) {
    final userId = asIntOr(user['user_id']);
    final fullName = asStr(user['full_name']) ?? '';
    final memberId = asStr(user['member_id']) ?? '';
    final memberType = asStr(user['member_type']) ?? 'worker';
    final repo = ref.read(orgRepositoryProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => FutureBuilder<Json>(
          future: repo.memberPayments(userId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: ErrorView(error: snap.error!));
            }
            final data = snap.data ?? const {};
            final months = asJsonList(data['months']);
            final payments = asJsonList(data['payments']);
            final totalPaid = asDouble(data['total_paid'], 0);
            final p = context.palette;

            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.maroon.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded, color: AppColors.maroon, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName, style: context.serif(17, weight: FontWeight.w700)),
                          Text('$memberId · ${memberType == "worker" ? "ሰራተኛ" : "ተማሪ"}', style: context.sans(12, color: p.muted)),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _recordCashPayment(context, user);
                      },
                      child: Text(isEn ? 'Record Cash' : 'ክፍያ መዝግብ'),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Summary figures
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.muted.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(isEn ? 'Total Paid' : 'አጠቃላይ የተከፈለ', style: context.sans(11, color: p.muted)),
                          const SizedBox(height: 2),
                          Text(f.money(totalPaid, 'ETB'), style: context.serif(14, weight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(isEn ? 'Paid Months' : 'የተከፈሉ ወራት', style: context.sans(11, color: p.muted)),
                          const SizedBox(height: 2),
                          Text('${asIntOr(data['paid_count'])}', style: context.serif(14, weight: FontWeight.w700)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(isEn ? 'Unpaid Months' : 'ያልተከፈሉ ወራት', style: context.sans(11, color: p.muted)),
                          const SizedBox(height: 2),
                          Text('${asIntOr(data['unpaid_count'])}', style: context.serif(14, weight: FontWeight.w700, color: AppColors.danger)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Month-by-month history
                Text(
                  isEn ? 'Month-by-Month Payment History' : 'የወራት ክፍያ ዝርዝር ታሪክ',
                  style: context.sans(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                for (final m in months) _buildMonthRow(context, m, f, isEn),

                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    isEn ? 'Payment Transactions' : 'የተፈጸሙ የክፍያ ዝርዝሮች',
                    style: context.sans(14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final pm in payments) _buildPaymentRow(context, pm, f, isEn),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthRow(BuildContext context, Json m, Formatters f, bool isEn) {
    final p = context.palette;
    final period = asStr(m['period']) ?? '';
    final status = asStr(m['status']) ?? 'unpaid';
    final required = asDouble(m['required'], 0);
    final paid = asDouble(m['paid'], 0);
    final paidOn = asStr(m['paid_on']);

    Color stColor;
    String stText;

    switch (status) {
      case 'paid':
        stColor = AppColors.success;
        stText = isEn ? 'Paid' : 'ተከፍሏል';
        break;
      case 'late':
        stColor = Colors.orange.shade800;
        stText = isEn ? 'Paid (Late)' : 'ዘግይቶ ተከፍሏል';
        break;
      case 'due':
        stColor = AppColors.gold;
        stText = isEn ? 'Due' : 'ክፍያ ይጠበቃል';
        break;
      case 'exempt':
        stColor = p.muted;
        stText = isEn ? 'Exempt' : 'ነፃ';
        break;
      default:
        stColor = AppColors.danger;
        stText = isEn ? 'Unpaid' : 'ያልተከፈለ';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.muted.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: stColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(periodLabel(context, period), style: context.sans(13, weight: FontWeight.w600)),
                  if (paidOn != null && paidOn.isNotEmpty)
                    Text(paidOn, style: context.sans(10, color: p.muted)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(
                f.money(status == 'paid' || status == 'late' ? paid : required, 'ETB'),
                style: context.sans(12, weight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(stText, style: context.sans(10, weight: FontWeight.w700, color: stColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(BuildContext context, Json pm, Formatters f, bool isEn) {
    final p = context.palette;
    final amount = asDouble(pm['amount'], 0);
    final currency = asStr(pm['currency']) ?? 'ETB';
    final method = asStr(pm['method']) ?? 'cash';
    final date = asStr(pm['paid_on']) ?? '';
    final refNo = asStr(pm['reference']);
    final receiptPath = asStr(pm['receipt_path']);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.muted.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.money(amount, currency), style: context.serif(13, weight: FontWeight.w700, color: AppColors.maroon)),
              Text('$date · $method ${refNo != null ? "· $refNo" : ""}', style: context.sans(10, color: p.muted)),
            ],
          ),
          if (receiptPath != null && receiptPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.receipt_rounded, size: 20, color: AppColors.maroon),
              tooltip: isEn ? 'View Receipt' : 'ደረሰኝ ተመልከት',
              onPressed: () {
                // View receipt preview
              },
            ),
        ],
      ),
    );
  }

  Future<void> _recordCashPayment(BuildContext context, Json user) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final userId = asIntOr(user['user_id']);
    final fullName = asStr(user['full_name']) ?? '';
    final reqRate = asDouble(user['monthly_required'], 0);

    var period = _period;
    var months = 1;
    var method = 'cash';
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEn ? 'Record Payment for $fullName' : 'ለ $fullName ክፍያ መዝግብ',
                    style: context.serif(16, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (reqRate > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${isEn ? "Expected Amount:" : "የሚጠበቅ ድምር፡"} ${(reqRate * months).toStringAsFixed(0)} ETB ($months x ${reqRate.toStringAsFixed(0)})',
                        style: ctx.sans(12, color: AppColors.maroon, weight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: months,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Months' : 'የወራት ብዛት',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem(value: m, child: Text('$m ወር')),
                          ],
                          onChanged: (v) => setSheetState(() => months = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Method' : 'የክፍያ ዘዴ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('ጥሬ ገንዘብ (Cash)')),
                            DropdownMenuItem(value: 'bank', child: Text('ባንክ (Bank)')),
                            DropdownMenuItem(value: 'telebirr', child: Text('ቴሌብር (telebirr)')),
                          ],
                          onChanged: (v) => setSheetState(() => method = v ?? 'cash'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: refCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Reference No. (Optional)' : 'የማረጋገጫ ቁጥር (አማራጭ)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Note (Optional)' : 'ማስታወሻ (አማራጭ)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
                      onPressed: submitting
                          ? null
                          : () async {
                              setSheetState(() => submitting = true);
                              try {
                                final repo = ref.read(orgRepositoryProvider);
                                await repo.recordPayment({
                                  'user_id': userId,
                                  'period': period,
                                  'months': months,
                                  'method': method,
                                  if (refCtrl.text.trim().isNotEmpty) 'reference': refCtrl.text.trim(),
                                  if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                                });
                                if (ctx.mounted) {
                                  Navigator.pop(ctx, true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isEn ? 'Payment recorded successfully' : 'ክፍያው በተሳካ ሁኔታ ተመዝግቧል')),
                                  );
                                  _loadSummary();
                                  _ctrl.refresh();
                                }
                              } catch (e) {
                                if (ctx.mounted) showErrorSnack(ctx, e);
                              } finally {
                                if (ctx.mounted) setSheetState(() => submitting = false);
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEn ? 'Confirm Payment Recording' : 'ክፍያውን መዝግብ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPendingReceipt(BuildContext context, Json user) {
    final pendingReceipt = asJson(user['pending_receipt']);
    if (pendingReceipt.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewAdminScreen(
          initialReceiptId: asInt(pendingReceipt['id']),
        ),
      ),
    ).then((_) {
      _loadSummary();
      _ctrl.refresh();
    });
  }
}

