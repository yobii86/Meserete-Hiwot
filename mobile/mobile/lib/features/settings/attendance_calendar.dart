import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';

/// Colour, icon and text colour of a calendar state. The colour is never the only signal: every
/// state also has an icon and a label (legend + day sheet).
({Color color, Color onColor, IconData icon}) attendanceStyle(String state) => switch (state) {
      'present' => (color: const Color(0xFF2E7D32), onColor: Colors.white, icon: Icons.check_rounded),
      'late' => (color: const Color(0xFFC0CA33), onColor: const Color(0xFF212121), icon: Icons.schedule_rounded),
      'excused' => (color: const Color(0xFFFDD835), onColor: const Color(0xFF212121), icon: Icons.verified_user_outlined),
      'absent' => (color: const Color(0xFFC62828), onColor: Colors.white, icon: Icons.close_rounded),
      'suspended' => (color: const Color(0xFFF57C00), onColor: Colors.white, icon: Icons.pause_circle_outline_rounded),
      'cancelled' => (color: const Color(0xFF757575), onColor: Colors.white, icon: Icons.block_rounded),
      'pending' => (color: const Color(0xFF8E601C), onColor: Colors.white, icon: Icons.hourglass_top_rounded),
      'upcoming' || 'today' => (color: AppColors.gold, onColor: const Color(0xFF212121), icon: Icons.event_rounded),
      _ => (color: Colors.white, onColor: const Color(0xFF424242), icon: Icons.remove_rounded),
    };

String attendanceStateLabel(AppLocalizations l, String state) => switch (state) {
      'present' => l.attPresent,
      'late' => l.attLate,
      'excused' => l.attExcused,
      'absent' => l.attAbsent,
      'suspended' => (l.isEn ? 'Suspended' : 'የተቋረጠ'),
      'cancelled' => (l.isEn ? 'Cancelled' : 'የተሰረዘ'),
      'pending' => (l.isEn ? 'Pending / Not recorded' : 'ያልተመዘገበ'),
      'upcoming' || 'today' => l.calendarUpcoming,
      _ => l.calendarNoProgram,
    };

/// My attendance: calendar by Ethiopian month, per program category, with statistics.
class AttendanceCalendarScreen extends ConsumerWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(programRepositoryProvider);
    return PatternScaffold(
      appBar: AppBar(
        title: Text(context.l10n.myAttendance),
        actions: const [
          ContextualHelpButton(screenRoute: '/attendance'),
        ],
      ),
      body: AttendanceCalendarView(fetch: (from, to, cat) => repo.myCalendar(from: from, to: to, categoryId: cat)),
    );
  }
}

final programCategoriesProvider = FutureProvider.autoDispose<List<ProgramCategory>>((ref) => ref.watch(programRepositoryProvider).categories());

typedef CalendarFetch = Future<AttendanceCalendar> Function(String from, String to, int? categoryId);

class AttendanceCalendarView extends ConsumerStatefulWidget {
  const AttendanceCalendarView({super.key, required this.fetch, this.showCategories = true});
  final CalendarFetch fetch;

  /// Off for calendars that are not about programs (e.g. class sessions).
  final bool showCategories;

  @override
  ConsumerState<AttendanceCalendarView> createState() => _AttendanceCalendarViewState();
}

class _AttendanceCalendarViewState extends ConsumerState<AttendanceCalendarView> {
  late EthiopianDate _month; // day = 1
  int? _category;
  AttendanceCalendar? _data;
  Object? _error;
  bool _loading = true;
  bool _isListView = false;
  String _listStatusFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final today = EthiopianDate.fromGregorian(DateTime.now());
    _month = EthiopianDate(today.year, today.month, 1);
    _load();
  }

  int get _days => EthiopianDate.daysInMonth(_month.year, _month.month);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = Formatters.isoDate(_month.toGregorian());
      final to = Formatters.isoDate(EthiopianDate(_month.year, _month.month, _days).toGregorian());
      final d = await widget.fetch(from, to, _category);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    var y = _month.year;
    var m = _month.month + months;
    if (m < 1) {
      m = 13;
      y--;
    } else if (m > 13) {
      m = 1;
      y++;
    }
    _month = EthiopianDate(y, m, 1);
    _load();
  }

  List<CalendarEntry> _getAllMonthEntries() {
    if (_data == null) return [];
    final all = <CalendarEntry>[];
    for (final day in _data!.days.values) {
      all.addAll(day.entries);
    }
    all.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return all.where((e) {
      if (_listStatusFilter != 'all' && e.status != _listStatusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchNotes = e.notes?.toLowerCase().contains(q) ?? false;
        final matchCat = e.category?.name.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchNotes && !matchCat) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildAttendanceSummaryHeader(BuildContext context, bool isEn, AppLocalizations l) {
    if (_data == null) return const SizedBox.shrink();
    final stats = _data!.stats;
    final present = stats.attended + stats.late;
    final absent = stats.absent;
    final excused = stats.excused;
    final rate = stats.percentage?.round() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              context,
              title: isEn ? 'Attended' : 'የተገኙ',
              value: '$present',
              color: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              context,
              title: isEn ? 'Rate' : 'የመገኘት ምጣኔ',
              value: '$rate%',
              color: rate >= 80 ? AppColors.goldDark : (rate >= 50 ? AppColors.maroon : AppColors.danger),
              icon: Icons.pie_chart_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              context,
              title: isEn ? 'Excused' : 'ፈቃድ',
              value: '$excused',
              color: const Color(0xFFC0CA33),
              icon: Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              context,
              title: isEn ? 'Absent' : 'የቀሩ',
              value: '$absent',
              color: AppColors.danger,
              icon: Icons.cancel_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: context.serif(15, weight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(10.5, color: p.muted, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    final cats = widget.showCategories ? (ref.watch(programCategoriesProvider).value ?? const []) : const <ProgramCategory>[];
    final first = _month.toGregorian();
    final lead = first.weekday - 1; // Monday-first grid
    final todayIso = Formatters.isoDate(DateTime.now());

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 32), children: [
        // Category selector
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(l.allCategories), selected: _category == null, onSelected: (_) {
                _category = null;
                _load();
              }),
            ),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(c.label(lang)), selected: _category == c.id, onSelected: (_) {
                  _category = c.id;
                  _load();
                }),
              ),
          ]),
        ),
        const SizedBox(height: 10),

        // Attendance KPI Summary Header (Burgundy, Cream & Gold)
        _buildAttendanceSummaryHeader(context, isEn, l),

        // View Mode Toggle (Calendar vs Detailed List)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(isEn ? 'Calendar' : 'የቀን መቁጠሪያ'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text(isEn ? 'Detailed List' : 'ዝርዝር መረጃ'),
                ),
              ],
              selected: {_isListView},
              onSelectionChanged: (s) => setState(() => _isListView = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(context.sans(12.5, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Month Selector Bar
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: l.previousMonth, onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${f.monthName(_month.month)} ${_month.year} ዓ.ም',
                      textAlign: TextAlign.center,
                      style: context.serif(17, weight: FontWeight.w700, color: AppColors.maroon),
                    ),
                    Text(
                      f.gregorianDate(first),
                      style: context.sans(11, color: p.muted),
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: l.nextMonth, onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            if (! _isListView) ...[
              Row(children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        f.weekday(DateTime(2024, 1, 1 + i)).characters.take(lang == 'am' ? 2 : 3).toString(),
                        style: context.sans(11, color: p.muted, weight: FontWeight.w600),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              if (_loading && _data == null)
                const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
              else if (_error != null)
                ErrorView(error: _error!, onRetry: _load)
              else
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                    for (var day = 1; day <= _days; day++)
                      Builder(builder: (context) {
                        final g = EthiopianDate(_month.year, _month.month, day).toGregorian();
                        final iso = Formatters.isoDate(g);
                        final entry = _data?.days[iso];
                        final state = entry?.state ?? 'none';
                        final st = attendanceStyle(state);
                        return _DayCell(
                          day: day,
                          style: st,
                          isToday: iso == todayIso,
                          hasProgram: entry != null,
                          label: '${f.date(g)} · ${attendanceStateLabel(l, state)}',
                          onTap: entry == null ? null : () => _showDay(context, g, entry.entries),
                        );
                      }),
                  ],
                ),
            ] else ...[
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search records by program or notes...' : 'በመርሐ ግብር ወይም ማስታወሻ ፈልግ...',
                      hintStyle: context.sans(11.5, color: p.muted),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
              ),
              // Detailed List Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    for (final s in ['all', 'present', 'excused', 'absent', 'suspended'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(s == 'all' ? (isEn ? 'All' : 'ሁሉም') : attendanceStateLabel(l, s)),
                          selected: _listStatusFilter == s,
                          onSelected: (_) => setState(() => _listStatusFilter = s),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 16),
              if (_loading && _data == null)
                const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
              else if (_error != null)
                ErrorView(error: _error!, onRetry: _load)
              else
                Builder(builder: (context) {
                  final entries = _getAllMonthEntries();
                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isEn ? 'No attendance records found for this period.' : 'ለዚህ ወር ምንም የመገኘት መዝገብ አልተገኘም።',
                        textAlign: TextAlign.center,
                        style: context.sans(13, color: p.muted),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) => _buildDetailedEntryTile(ctx, entries[idx], f, l, lang, isEn),
                  );
                }),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        if (! _isListView) const _Legend(),
        if (_data != null) ...[
          const SizedBox(height: 12),
          AttendanceStatsCard(stats: _data!.stats),
        ],
      ]),
    );
  }

  Widget _buildDetailedEntryTile(BuildContext context, CalendarEntry e, Formatters f, AppLocalizations l, String lang, bool isEn) {
    final st = attendanceStyle(e.status);
    final p = context.palette;
    final startsAt = e.startsAt;
    final endsAt = e.endsAt;
    final attendedAt = e.attendedAt;
    final ethDate = EthiopianDate.fromGregorian(startsAt);

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final dayEntries = _data?.days[Formatters.isoDate(e.startsAt)]?.entries ?? [e];
          _showDay(context, e.startsAt, dayEntries);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: st.color.withValues(alpha: 0.15),
                child: Icon(st.icon, color: st.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: context.serif(14, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${ethDate.day}/${ethDate.month}/${ethDate.year} ዓ.ም (${f.date(startsAt, withWeekday: true)})',
                      style: context.sans(11.5, color: AppColors.goldDark, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Pill(
                attendanceStateLabel(l, e.status),
                color: e.status == 'excused' || e.status == 'late' ? const Color(0xFF6D6B00) : st.color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (e.category != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 13, color: AppColors.goldDark),
                    const SizedBox(width: 4),
                    Text(e.category!.label(lang), style: context.sans(11.5, color: p.muted)),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text('${f.time(startsAt)} – ${f.time(endsAt)}', style: context.sans(11.5, color: p.muted)),
                ],
              ),
              if (attendedAt != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('${isEn ? "Recorded" : "የተመዘገበበት"}: ${f.time(attendedAt)}', style: context.sans(11.5, color: Colors.green.shade800, weight: FontWeight.w600)),
                  ],
                ),
              if (e.location != null && e.location!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(e.location!, style: context.sans(11.5, color: p.muted)),
                  ],
                ),
            ],
          ),
          if (e.signatureStatus != null || e.recorderName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (e.signatureStatus == 'verified' || e.signatureId != null)
                  Pill(isEn ? 'Digital Signature Verified' : 'ዲጂታል ፊርማ ተረጋግጧል', icon: Icons.verified_rounded, color: Colors.green.shade800)
                else if (e.signatureStatus == 'exempt')
                  Pill(isEn ? 'Signature Exempt' : 'ከፊርማ ነፃ', icon: Icons.shield_outlined, color: Colors.blue.shade800),
                const Spacer(),
                if (e.recorderName != null)
                  Text(
                    '${isEn ? "Recorder" : "መዝጋቢ"}: ${e.recorderName}',
                    style: context.sans(11, color: p.muted, weight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  void _showDay(BuildContext context, DateTime day, List<CalendarEntry> entries) {
    final l = context.l10n;
    final isEn = l.isEn;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    final eth = EthiopianDate.fromGregorian(day);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.date(day, withWeekday: true), style: ctx.serif(17, weight: FontWeight.w700)),
                    Text('${eth.day}/${eth.month}/${eth.year} ዓ.ም', style: ctx.sans(12.5, color: AppColors.goldDark, weight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('${entries.length} ${isEn ? "events" : "መርሐ ግብሮች"}', style: ctx.sans(12, color: ctx.palette.muted)),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in entries)
            Builder(builder: (ctx) {
              final st = attendanceStyle(e.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.palette.fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ctx.palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: st.color, child: Icon(st.icon, color: st.onColor, size: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: ctx.serif(14.5, weight: FontWeight.w700)),
                              if (e.category != null)
                                Text(e.category!.label(lang), style: ctx.sans(11.5, color: ctx.palette.muted)),
                            ],
                          ),
                        ),
                        Pill(attendanceStateLabel(l, e.status), color: e.status == 'excused' || e.status == 'late' ? const Color(0xFF6D6B00) : st.color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text('${f.time(e.startsAt)} – ${f.time(e.endsAt)}', style: ctx.sans(11.5, color: ctx.palette.muted)),
                        if (e.attendedAt != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('${isEn ? "Recorded" : "የተመዘገበው"}: ${f.time(e.attendedAt!)}', style: ctx.sans(11.5, color: Colors.green.shade800, weight: FontWeight.w600)),
                        ],
                      ],
                    ),
                    if (e.location != null && e.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(e.location!, style: ctx.sans(11.5, color: ctx.palette.muted)),
                        ],
                      ),
                    ],
                    if (e.signatureStatus != null || e.recorderName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (e.signatureStatus == 'verified' || e.signatureId != null)
                            Pill(isEn ? 'Digital Signature Verified' : 'ዲጂታል ፊርማ ተረጋግጧል', icon: Icons.verified_rounded, color: Colors.green.shade800)
                          else if (e.signatureStatus == 'exempt')
                            Pill(isEn ? 'Signature Exempt' : 'ከፊርማ ነፃ', icon: Icons.shield_outlined, color: Colors.blue.shade800),
                          const Spacer(),
                          if (e.recorderName != null)
                            Text('${isEn ? "Recorder" : "መዝጋቢ"}: ${e.recorderName}', style: ctx.sans(11, color: ctx.palette.muted, weight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ]),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.style, required this.isToday, required this.hasProgram, required this.label, this.onTap});
  final int day;
  final ({Color color, Color onColor, IconData icon}) style;
  final bool isToday;
  final bool hasProgram;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: label,
      button: onTap != null,
      child: Material(
        color: style.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isToday ? AppColors.maroon : p.border, width: isToday ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Stack(children: [
            Center(child: Text('$day', style: TextStyle(color: style.onColor, fontWeight: FontWeight.w700, fontSize: 13))),
            if (hasProgram) Positioned(right: 2, bottom: 2, child: Icon(style.icon, size: 11, color: style.onColor)),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(spacing: 12, runSpacing: 6, children: [
      for (final s in ['none', 'upcoming', 'present', 'excused', 'absent', 'suspended'])
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: attendanceStyle(s).color, borderRadius: BorderRadius.circular(5), border: Border.all(color: context.palette.border)),
            child: Icon(attendanceStyle(s).icon, size: 12, color: attendanceStyle(s).onColor),
          ),
          const SizedBox(width: 5),
          Text(attendanceStateLabel(l, s), style: context.sans(12)),
        ]),
    ]);
  }
}

/// Totals for the selected period / category (numbers come from the server).
class AttendanceStatsCard extends StatelessWidget {
  const AttendanceStatsCard({super.key, required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pct = stats.percentage;
    Widget cell(String label, int n, String state) => Expanded(
          child: Column(children: [
            Text('$n', style: context.serif(18, color: state == 'none' ? null : attendanceStyle(state).color == Colors.white ? null : attendanceStyle(state).color)),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11, color: context.palette.muted)),
          ]),
        );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Text(l.attendanceStats, style: context.sans(14, weight: FontWeight.w700)),
          const Spacer(),
          if (pct != null) Pill(l.attendanceRate(pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1)), icon: Icons.insights_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          cell(l.totalPrograms, stats.total, 'none'),
          cell(l.attPresent, stats.attended, 'present'),
          cell(l.attExcused, stats.excused, 'excused'),
          cell(l.attAbsent, stats.absent, 'absent'),
        ]),
      ]),
    );
  }
}
