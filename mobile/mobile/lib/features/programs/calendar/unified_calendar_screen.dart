import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/activity.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../admin/programs_admin.dart' show createProgram;
import '../../guidance/contextual_help_sheet.dart';
import '../../settings/attendance_calendar.dart' show attendanceStyle, attendanceStateLabel, programCategoriesProvider;
import '../program_text.dart';

enum CalendarViewMode { yearly, monthly, weekly, daily, agenda }

class CalendarOccurrence {
  CalendarOccurrence({
    required this.programId,
    required this.title,
    this.location,
    this.category,
    this.audience,
    this.recurrence = 'once',
    this.status = 'published',
    this.hasEndTime = true,
    this.isEducation = false,
    this.classes = const [],
    this.requiresAttendance = false,
    this.myAttendance,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    this.ethiopianDateString,
    required this.ethYear,
    required this.ethMonth,
    required this.ethDay,
    this.rescheduled = false,
    this.cancelled = false,
    this.suspended = false,
  });

  final int programId;
  final String title;
  final String? location;
  final ProgramCategory? category;
  final String? audience;
  final String recurrence;
  final String status;
  final bool hasEndTime;
  final bool isEducation;
  final List<Json> classes;
  final bool requiresAttendance;
  final String? myAttendance;
  final String date; // YYYY-MM-DD
  final DateTime startsAt;
  final DateTime endsAt;
  final String? ethiopianDateString;
  final int ethYear;
  final int ethMonth;
  final int ethDay;
  final bool rescheduled;
  final bool cancelled;
  final bool suspended;

  factory CalendarOccurrence.fromJson(Json j) {
    final eth = asJson(j['ethiopian']);
    final cat = j['category'] is Map ? ProgramCategory.fromJson(asJson(j['category'])) : null;
    final starts = asDate(j['starts_at']) ?? DateTime.now();
    final ends = asDate(j['ends_at']) ?? starts;
    final ed = EthiopianDate.fromGregorian(starts.toLocal());

    return CalendarOccurrence(
      programId: asIntOr(j['program_id']),
      title: asStr(j['title']) ?? '',
      location: asStr(j['location']),
      category: cat,
      audience: asStr(j['audience']),
      recurrence: asStr(j['recurrence']) ?? 'once',
      status: asStr(j['status']) ?? 'published',
      hasEndTime: j['has_end_time'] == null || asBool(j['has_end_time']),
      isEducation: asBool(j['is_education']),
      classes: asJsonList(j['classes']),
      requiresAttendance: asBool(j['requires_attendance']),
      myAttendance: asStr(j['my_attendance']),
      date: asStr(j['date']) ?? starts.toLocal().toIso8601String().substring(0, 10),
      startsAt: starts,
      endsAt: ends,
      ethiopianDateString: asStr(j['ethiopian_date']),
      ethYear: asInt(eth['year']) ?? ed.year,
      ethMonth: asInt(eth['month']) ?? ed.month,
      ethDay: asInt(eth['day']) ?? ed.day,
      rescheduled: asBool(j['rescheduled']),
      cancelled: asBool(j['cancelled']),
      suspended: asBool(j['suspended']),
    );
  }

  bool overlapsWith(CalendarOccurrence other) {
    if (programId == other.programId) return false;
    if (date != other.date) return false;
    return startsAt.isBefore(other.endsAt) && endsAt.isAfter(other.startsAt);
  }

  Json toJson() => {
        'program_id': programId,
        'title': title,
        'location': location,
        'category': category != null
            ? {'id': category!.id, 'name': category!.name, 'name_en': category!.nameEn, 'color': category!.color}
            : null,
        'audience': audience,
        'recurrence': recurrence,
        'status': status,
        'has_end_time': hasEndTime,
        'is_education': isEducation,
        'classes': classes,
        'requires_attendance': requiresAttendance,
        'my_attendance': myAttendance,
        'date': date,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'ethiopian_date': ethiopianDateString,
        'ethiopian': {'year': ethYear, 'month': ethMonth, 'day': ethDay},
        'rescheduled': rescheduled,
        'cancelled': cancelled,
      };
}

/// Unified Yearly Calendar screen for Meserete Hiwot.
/// Displays all program categories on a single shared Ethiopian calendar.
class UnifiedCalendarScreen extends ConsumerStatefulWidget {
  const UnifiedCalendarScreen({super.key, this.initialEthYear, this.initialEthMonth});

  final int? initialEthYear;
  final int? initialEthMonth;

  @override
  ConsumerState<UnifiedCalendarScreen> createState() => _UnifiedCalendarScreenState();
}

class _UnifiedCalendarScreenState extends ConsumerState<UnifiedCalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.yearly;
  late int _selectedYear;
  late int _selectedMonth;
  late EthiopianDate _selectedDate;
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _showSearch = false;

  bool _loading = false;
  String? _lastSyncedTime;
  List<CalendarOccurrence> _occurrences = [];

  @override
  void initState() {
    super.initState();
    final todayEth = EthiopianDate.fromGregorian(DateTime.now());
    _selectedYear = widget.initialEthYear ?? todayEth.year;
    _selectedMonth = widget.initialEthMonth ?? todayEth.month;
    _selectedDate = todayEth;
    _loadEvents();
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final cacheKey = 'cal:eth_$_selectedYear:${_selectedCategoryId ?? 'all'}';
    final localDb = ref.read(localDbProvider);

    // Load from cache first if not forcing refresh
    if (!forceRefresh) {
      try {
        final cached = await localDb.getCache(cacheKey);
        if (cached is List && cached.isNotEmpty && mounted) {
          final items = cached.map((e) => CalendarOccurrence.fromJson(asJson(e))).toList();
          final meta = await localDb.getCache('$cacheKey:meta');
          setState(() {
            _occurrences = items;
            if (meta is Map && meta['synced_at'] != null) {
              _lastSyncedTime = meta['synced_at'].toString();
            }
          });
        }
      } catch (_) {}
    }

    try {
      // Calculate Gregorian bounds for the Ethiopian year _selectedYear
      // Ethiopian year starts at Meskerem 1 and ends at Pagume 5 (or 6 in leap years)
      final startEth = EthiopianDate(_selectedYear, 1, 1);
      final lastDayPagume = EthiopianDate.daysInMonth(_selectedYear, 13);
      final endEth = EthiopianDate(_selectedYear, 13, lastDayPagume);

      final fromDate = startEth.toGregorian();
      final toDate = endEth.toGregorian();
      final fromStr = fromDate.toIso8601String().substring(0, 10);
      final toStr = toDate.toIso8601String().substring(0, 10);

      final repo = ref.read(programRepositoryProvider);
      final raw = await repo.calendar(from: fromStr, to: toStr, categoryId: _selectedCategoryId);
      if (!mounted) return;

      final items = raw.map(CalendarOccurrence.fromJson).toList();
      final nowFormatted = Formatters(context.l10n, Localizations.localeOf(context).languageCode).dateTime(DateTime.now());

      setState(() {
        _occurrences = items;
        _lastSyncedTime = nowFormatted;
        _loading = false;
      });

      // Save to offline cache
      unawaited(localDb.putCache(cacheKey, items.map((e) => e.toJson()).toList()));
      unawaited(localDb.putCache('$cacheKey:meta', {'synced_at': nowFormatted}));
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (_occurrences.isEmpty) {
          showErrorSnack(context, e);
        }
      }
    }
  }

  Future<void> _openCreateProgramForDate(EthiopianDate ed) async {
    final greg = ed.toGregorian();
    final created = await createProgram(context, initialDate: greg);
    if (created != null && mounted) {
      _loadEvents(forceRefresh: true);
    }
  }

  void _previousYear() {
    setState(() {
      _selectedYear--;
      _selectedDate = EthiopianDate(_selectedYear, _selectedMonth, 1);
    });
    _loadEvents();
  }

  void _nextYear() {
    setState(() {
      _selectedYear++;
      _selectedDate = EthiopianDate(_selectedYear, _selectedMonth, 1);
    });
    _loadEvents();
  }

  void _jumpToToday() {
    final todayEth = EthiopianDate.fromGregorian(DateTime.now());
    setState(() {
      _selectedYear = todayEth.year;
      _selectedMonth = todayEth.month;
      _selectedDate = todayEth;
    });
    _loadEvents();
  }

  List<CalendarOccurrence> get _filteredOccurrences {
    return _occurrences.where((o) {
      if (_selectedCategoryId != null && o.category?.id != _selectedCategoryId) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = o.title.toLowerCase().contains(q);
        final matchLoc = (o.location ?? '').toLowerCase().contains(q);
        if (!matchTitle && !matchLoc) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.programs),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            tooltip: 'ፈልግ (Search)',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: l.today,
            onPressed: _jumpToToday,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'አድስ (Refresh)',
            onPressed: () => _loadEvents(forceRefresh: true),
          ),
          const ContextualHelpButton(screenRoute: '/programs'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'መርሐግብር ፍጠር (New Program)',
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        onPressed: () => _openCreateProgramForDate(_selectedDate),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Year navigation bar & synced indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'ቀደምት ዓመት',
                    onPressed: _previousYear,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${ethiopicNumeral(_selectedYear)} ዓ.ም · $_selectedYear E.C.',
                          style: context.sans(17, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                        Text(
                          'የኢትዮጵያ ዘመን አቆጣጠር (Ethiopian Calendar)',
                          style: context.sans(11, color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'ቀጣይ ዓመት',
                    onPressed: _nextYear,
                  ),
                ],
              ),
            ),

            // Mode Selector: Yearly, Monthly, Weekly, Daily, Agenda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: CalendarViewMode.yearly, label: Text('ዓመታዊ')),
                    ButtonSegment(value: CalendarViewMode.monthly, label: Text('ወርሃዊ')),
                    ButtonSegment(value: CalendarViewMode.weekly, label: Text('ሳምንት')),
                    ButtonSegment(value: CalendarViewMode.daily, label: Text('ዕለታዊ')),
                    ButtonSegment(value: CalendarViewMode.agenda, label: Text('አጀንዳ')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) => setState(() => _viewMode = s.first),
                ),
              ),
            ),

            // Category filter chips & search box
            _buildFilters(l, lang),

            // Last synced status banner if available
            if (_lastSyncedTime != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      'የመጨረሻ ማመሳሰል: $_lastSyncedTime',
                      style: context.sans(11, color: context.palette.muted),
                    ),
                  ],
                ),
              ),

            if (_loading) const LinearProgressIndicator(),

            // Main calendar view body
            Expanded(
              child: _buildCurrentView(f, l, lang),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l, String lang) {
    return Column(
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ፕሮግራም ወይም ቦታ ፈልግ... (Search program or venue)',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (q) => setState(() => _searchQuery = q.trim()),
            ),
          ),
        // Category horizontal filter chips
        Consumer(builder: (context, ref, _) {
          final cats = ref.watch(programCategoriesProvider).value ?? const [];
          if (cats.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l.allCategories),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                      _loadEvents();
                    },
                  ),
                ),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(radius: 4, backgroundColor: hexColor(c.color)),
                      label: Text(c.label(lang)),
                      selected: _selectedCategoryId == c.id,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = c.id);
                        _loadEvents();
                      },
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCurrentView(Formatters f, AppLocalizations l, String lang) {
    switch (_viewMode) {
      case CalendarViewMode.yearly:
        return _buildYearlyView(f, l);
      case CalendarViewMode.monthly:
        return _buildMonthlyView(f, l, lang);
      case CalendarViewMode.weekly:
        return _buildWeeklyView(f, l);
      case CalendarViewMode.daily:
        return _buildDailyView(f, l);
      case CalendarViewMode.agenda:
        return _buildAgendaView(f, l);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. YEARLY VIEW (All 12 Ethiopian Months + Pagume)
  // ---------------------------------------------------------------------------
  Widget _buildYearlyView(Formatters f, AppLocalizations l) {
    return RefreshIndicator(
      onRefresh: () => _loadEvents(forceRefresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.82,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 13, // 12 months + Pagume
        itemBuilder: (context, idx) {
          final monthIndex = idx + 1;
          final monthName = f.monthName(monthIndex);
          final daysInThisMonth = EthiopianDate.daysInMonth(_selectedYear, monthIndex);
          final monthOccurrences = _filteredOccurrences.where((o) => o.ethMonth == monthIndex).toList();

          final isCurrentMonth = _selectedYear == EthiopianDate.fromGregorian(DateTime.now()).year &&
              monthIndex == EthiopianDate.fromGregorian(DateTime.now()).month;

          // Gregorian approximate range
          final startGreg = EthiopianDate(_selectedYear, monthIndex, 1).toGregorian();
          final endGreg = EthiopianDate(_selectedYear, monthIndex, daysInThisMonth).toGregorian();
          final gregSpan = '${startGreg.month}/${startGreg.day} - ${endGreg.month}/${endGreg.day}';

          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _selectedMonth = monthIndex;
                _viewMode = CalendarViewMode.monthly;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isCurrentMonth ? AppColors.gold.withValues(alpha: 0.12) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrentMonth ? AppColors.gold : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  width: isCurrentMonth ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          monthName,
                          style: context.sans(12, weight: FontWeight.w700, color: isCurrentMonth ? AppColors.maroon : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (monthOccurrences.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.maroon,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${monthOccurrences.length}',
                            style: context.sans(10, weight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  Text(gregSpan, style: context.sans(9, color: context.palette.muted)),
                  const Divider(height: 6),
                  Expanded(
                    child: _buildMiniMonthGrid(monthIndex, daysInThisMonth, monthOccurrences),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniMonthGrid(int month, int totalDays, List<CalendarOccurrence> occs) {
    final eventDays = occs.map((o) => o.ethDay).toSet();
    final today = EthiopianDate.fromGregorian(DateTime.now());
    final isThisMonth = _selectedYear == today.year && month == today.month;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: totalDays,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, dIdx) {
        final day = dIdx + 1;
        final hasEvent = eventDays.contains(day);
        final isToday = isThisMonth && today.day == day;

        return Container(
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.maroon
                : (hasEvent ? AppColors.gold.withValues(alpha: 0.3) : Colors.transparent),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 8,
              fontWeight: (hasEvent || isToday) ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.white : (hasEvent ? AppColors.maroon : null),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MONTHLY VIEW
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyView(Formatters f, AppLocalizations l, String lang) {
    final monthName = f.monthName(_selectedMonth);
    final daysInMonth = EthiopianDate.daysInMonth(_selectedYear, _selectedMonth);
    final startGreg = EthiopianDate(_selectedYear, _selectedMonth, 1).toGregorian();
    final endGreg = EthiopianDate(_selectedYear, _selectedMonth, daysInMonth).toGregorian();
    final gregRange = '${f.gregorianDate(startGreg)} – ${f.gregorianDate(endGreg)}';

    final monthEvents = _filteredOccurrences.where((o) => o.ethMonth == _selectedMonth).toList();
    final selectedDayEvents = monthEvents.where((o) => o.ethDay == _selectedDate.day).toList();

    return Column(
      children: [
        // Month navigation chevrons & title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth > 1) {
                      _selectedMonth--;
                    } else {
                      _selectedMonth = 13;
                      _selectedYear--;
                    }
                    _selectedDate = EthiopianDate(_selectedYear, _selectedMonth, 1);
                  });
                  _loadEvents();
                },
              ),
              Column(
                children: [
                  Text(
                    '$monthName $_selectedYear ዓ.ም',
                    style: context.sans(16, weight: FontWeight.w700, color: AppColors.maroon),
                  ),
                  Text(gregRange, style: context.sans(11, color: context.palette.muted)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth < 13) {
                      _selectedMonth++;
                    } else {
                      _selectedMonth = 1;
                      _selectedYear++;
                    }
                    _selectedDate = EthiopianDate(_selectedYear, _selectedMonth, 1);
                  });
                  _loadEvents();
                },
              ),
            ],
          ),
        ),

        // Weekday header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final wd in ['እሑድ', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'])
                Expanded(
                  child: Center(
                    child: Text(wd, style: context.sans(11, weight: FontWeight.w600, color: context.palette.muted)),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 8),

        // Month Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildMonthCalendarGrid(daysInMonth, monthEvents),
        ),

        const Divider(height: 12),

        // Selected Day Title & Events
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'የ$monthName ${_selectedDate.day} ፕሮግራሞች (${selectedDayEvents.length})',
                style: context.sans(13, weight: FontWeight.w700),
              ),
              Text(
                f.gregorianDate(_selectedDate.toGregorian()),
                style: context.sans(11, color: context.palette.muted),
              ),
            ],
          ),
        ),

        Expanded(
          child: selectedDayEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 40, color: AppColors.muted),
                      const SizedBox(height: 6),
                      Text('በዚህ ቀን የተመዘገበ ፕሮግራም የለም', style: context.sans(13, color: context.palette.muted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: selectedDayEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) => _buildOccurrenceCard(selectedDayEvents[idx], f, l, lang),
                ),
        ),
      ],
    );
  }

  Widget _buildMonthCalendarGrid(int totalDays, List<CalendarOccurrence> events) {
    // Determine weekday offset for the 1st of the month
    final firstDayGreg = EthiopianDate(_selectedYear, _selectedMonth, 1).toGregorian();
    final firstWeekday = firstDayGreg.weekday % 7; // Sunday=0, Monday=1, ...
    final today = EthiopianDate.fromGregorian(DateTime.now());

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var d = 1; d <= totalDays; d++) {
      final dayNum = d;
      final dayEvents = events.where((e) => e.ethDay == dayNum).toList();
      final isSelected = _selectedDate.year == _selectedYear && _selectedDate.month == _selectedMonth && _selectedDate.day == dayNum;
      final isToday = today.year == _selectedYear && today.month == _selectedMonth && today.day == dayNum;

      cells.add(
        InkWell(
          onTap: () {
            if (_selectedDate == EthiopianDate(_selectedYear, _selectedMonth, dayNum)) {
              _openCreateProgramForDate(_selectedDate);
            } else {
              setState(() => _selectedDate = EthiopianDate(_selectedYear, _selectedMonth, dayNum));
            }
          },
          onLongPress: () => _openCreateProgramForDate(EthiopianDate(_selectedYear, _selectedMonth, dayNum)),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.maroon
                  : (isToday ? AppColors.gold.withValues(alpha: 0.2) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected ? Border.all(color: AppColors.maroon, width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (isSelected || isToday || dayEvents.isNotEmpty) ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : (isToday ? AppColors.maroon : null),
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final e in dayEvents.take(3))
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : (e.category?.color != null ? hexColor(e.category!.color) : AppColors.gold),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.25,
      children: cells,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. WEEKLY VIEW
  // ---------------------------------------------------------------------------
  Widget _buildWeeklyView(Formatters f, AppLocalizations l) {
    // Current week anchored on _selectedDate
    final curGreg = _selectedDate.toGregorian();
    final weekStartGreg = curGreg.subtract(Duration(days: curGreg.weekday % 7)); // Sunday
    final weekDays = List.generate(7, (i) => weekStartGreg.add(Duration(days: i)));

    return Column(
      children: [
        // Week Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              for (final g in weekDays) ...[
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final ed = EthiopianDate.fromGregorian(g);
                      if (_selectedDate == ed) {
                        _openCreateProgramForDate(ed);
                      } else {
                        setState(() {
                          _selectedYear = ed.year;
                          _selectedMonth = ed.month;
                          _selectedDate = ed;
                        });
                      }
                    },
                    onLongPress: () => _openCreateProgramForDate(EthiopianDate.fromGregorian(g)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: EthiopianDate.fromGregorian(g) == _selectedDate
                            ? AppColors.maroon
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ['እሑድ', 'ሰኞ', 'ማክ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ'][g.weekday % 7],
                            style: context.sans(
                              10,
                              color: EthiopianDate.fromGregorian(g) == _selectedDate ? Colors.white : context.palette.muted,
                            ),
                          ),
                          Text(
                            '${EthiopianDate.fromGregorian(g).day}',
                            style: context.sans(
                              13,
                              weight: FontWeight.bold,
                              color: EthiopianDate.fromGregorian(g) == _selectedDate ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Day Events
        Expanded(
          child: _buildDailyView(f, l),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DAILY VIEW
  // ---------------------------------------------------------------------------
  Widget _buildDailyView(Formatters f, AppLocalizations l) {
    final lang = Localizations.localeOf(context).languageCode;
    final dayOccs = _filteredOccurrences
        .where((o) => o.ethYear == _selectedDate.year && o.ethMonth == _selectedDate.month && o.ethDay == _selectedDate.day)
        .toList();

    final gregDate = _selectedDate.toGregorian();
    final ethFormatted = '${f.monthName(_selectedDate.month)} ${_selectedDate.day}፣ ${_selectedDate.year} ዓ.ም';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.maroon.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f.weekday(gregDate)}፣ $ethFormatted',
                style: context.sans(16, weight: FontWeight.w800, color: AppColors.maroon),
              ),
              const SizedBox(height: 2),
              Text(
                'Gregorian: ${f.gregorianDate(gregDate)}',
                style: context.sans(11, color: context.palette.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: dayOccs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy_outlined, size: 48, color: AppColors.muted),
                      const SizedBox(height: 8),
                      Text('በዚህ ዕለት የተያዘ ፕሮግራም የለም', style: context.sans(14, color: context.palette.muted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayOccs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) => _buildOccurrenceCard(dayOccs[idx], f, l, lang),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. AGENDA VIEW (Chronological list grouped by Ethiopian date)
  // ---------------------------------------------------------------------------
  Widget _buildAgendaView(Formatters f, AppLocalizations l) {
    final lang = Localizations.localeOf(context).languageCode;
    final sorted = [..._filteredOccurrences]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(l.noPrograms, style: context.sans(14, color: context.palette.muted)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildAttendanceLegend(context, l),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: sorted.length,
            itemBuilder: (context, idx) {
              final occ = sorted[idx];
              final prevOcc = idx > 0 ? sorted[idx - 1] : null;
              final showDateHeader = prevOcc == null || prevOcc.date != occ.date;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) ...[
              if (idx > 0) const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.maroon),
                  const SizedBox(width: 6),
                  Text(
                    '${f.monthName(occ.ethMonth)} ${occ.ethDay}፣ ${occ.ethYear} ዓ.ም',
                    style: context.sans(14, weight: FontWeight.w700, color: AppColors.maroon),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${f.gregorianDate(occ.startsAt)})',
                    style: context.sans(11, color: context.palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            _buildOccurrenceCard(occ, f, l, lang),
            const SizedBox(height: 8),
          ],
        );
      },
    ),
  ),
],
);
  }

  Widget _buildAttendanceLegend(BuildContext context, AppLocalizations l) {
    final isEn = l.isEn;
    final items = [
      ('present', isEn ? 'Present' : 'የተገኙ', const Color(0xFF2E7D32), Icons.check_circle_rounded),
      ('absent', isEn ? 'Absent' : 'ያልተገኙ', const Color(0xFFC62828), Icons.cancel_rounded),
      ('excused', isEn ? 'Excused' : 'ፈቃድ', const Color(0xFF1976D2), Icons.verified_user_rounded),
      ('suspended', isEn ? 'Suspended' : 'የተቋረጠ', const Color(0xFFE65100), Icons.pause_circle_filled_rounded),
      ('pending', isEn ? 'Pending' : 'ያልተመዘገበ', const Color(0xFF8E601C), Icons.hourglass_top_rounded),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: context.palette.muted),
              const SizedBox(width: 6),
              Text(
                isEn ? 'Personal Attendance Status' : 'የግል መገኘት ሁኔታ መፍቻ',
                style: context.sans(11, weight: FontWeight.w700, color: context.palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final (_, label, color, icon) in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: context.sans(11, weight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Card for an individual occurrence
  Widget _buildOccurrenceCard(CalendarOccurrence occ, Formatters f, AppLocalizations l, String lang) {
    final catColor = occ.category?.color != null ? hexColor(occ.category!.color) : AppColors.maroon;
    final isPast = occ.endsAt.isBefore(DateTime.now());
    final effectiveStatus = occ.suspended
        ? 'suspended'
        : occ.cancelled
            ? 'cancelled'
            : (occ.myAttendance != null && occ.myAttendance!.isNotEmpty)
                ? occ.myAttendance!
                : (occ.requiresAttendance ? (isPast ? 'absent' : 'pending') : null);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      child: InkWell(
        onTap: () => context.push('/programs/${occ.programId}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: catColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          occ.title,
                          style: context.sans(15, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                occ.category?.label(lang) ?? l.programs,
                                style: context.sans(11, weight: FontWeight.w600, color: catColor),
                              ),
                            ),
                            if (occ.isEducation) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('የትምህርት ክፍል', style: context.sans(11, weight: FontWeight.w600, color: AppColors.maroon)),
                              ),
                            ],
                            if (_occurrences.any((o) => o.overlapsWith(occ))) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade800),
                                    const SizedBox(width: 3),
                                    Text(
                                      lang == 'en' ? 'Time Overlap' : 'የሰዓት መደራረብ አለ',
                                      style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (effectiveStatus != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: attendanceStyle(effectiveStatus).color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: attendanceStyle(effectiveStatus).color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(attendanceStyle(effectiveStatus).icon, size: 14, color: attendanceStyle(effectiveStatus).color),
                          const SizedBox(width: 4),
                          Text(
                            attendanceStateLabel(l, effectiveStatus),
                            style: context.sans(11.5, weight: FontWeight.w700, color: attendanceStyle(effectiveStatus).color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    occ.hasEndTime ? '${f.time(occ.startsAt)} – ${f.time(occ.endsAt)}' : f.time(occ.startsAt),
                    style: context.sans(12, color: context.palette.muted),
                  ),
                  if (occ.location != null && occ.location!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        occ.location!,
                        style: context.sans(12, color: context.palette.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (occ.classes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final c in occ.classes)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(asStr(c['name']) ?? 'Class', style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
              // Administrative occurrence actions (Direct Take Attendance & Program Edit)
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Builder(builder: (ctx) {
                    final now = DateTime.now();
                    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    final dateStr = occ.date.length >= 10 ? occ.date.substring(0, 10) : occ.date;
                    final isPast = dateStr.compareTo(todayStr) < 0;

                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: BorderSide(color: isPast ? Colors.grey.shade400 : const Color(0xFFC6A044)),
                      ),
                      icon: Icon(
                        isPast ? Icons.visibility_outlined : Icons.people_outline_rounded,
                        size: 16,
                        color: isPast ? Colors.grey.shade700 : const Color(0xFF650D20),
                      ),
                      label: Text(
                        isPast
                            ? (lang == 'en' ? 'View Roster' : 'መዝገብ እይ')
                            : (lang == 'en' ? 'Take Attendance' : 'አቴንዳንስ ውሰድ'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPast ? Colors.grey.shade700 : const Color(0xFF650D20),
                        ),
                      ),
                      onPressed: () {
                        context.push('/admin/programs/${occ.programId}/attendance?date=$dateStr');
                      },
                    );
                  }),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text(lang == 'en' ? 'Edit' : 'አርትዕ', style: const TextStyle(fontSize: 12)),
                    onPressed: () => context.push('/admin/programs/edit/${occ.programId}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
