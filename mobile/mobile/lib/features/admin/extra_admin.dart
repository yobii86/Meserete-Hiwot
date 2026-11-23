import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/network/api_client.dart' show Paged;
import '../../core/network/api_exception.dart';
import '../../services/offline_pack.dart';
import '../../widgets/ethiopian_date_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/activity.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../members/profile_changes.dart' show ChangeLine, ProfileHistoryScreen;
import 'admin_widgets.dart';
import 'report_export.dart';

// =============================================================================
// Name / phone change requests (users.view to see, users.update to decide)
// =============================================================================
class ChangeRequestsScreen extends ConsumerStatefulWidget {
  const ChangeRequestsScreen({super.key});
  @override
  ConsumerState<ChangeRequestsScreen> createState() => _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends ConsumerState<ChangeRequestsScreen> {
  final _ctrl = PagedListController<ProfileChangeRequest>();
  String _status = 'pending';

  Future<void> _decide(ProfileChangeRequest r, bool approve) async {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    if (approve) {
      final note = await promptText(context, title: l.approve, label: l.approveNote, maxLines: 2);
      if (note == null || !mounted) return;
      await runWithProgress(context, () => repo.approveChange(r.id, note: note.trim().isEmpty ? null : note.trim()), success: l.approved);
    } else {
      // Declining always gives the member a reason.
      final reason = await promptText(context, title: l.reject, label: l.declineReason, maxLines: 2, required: true);
      if (reason == null || reason.trim().isEmpty || !mounted) return;
      await runWithProgress(context, () => repo.rejectChange(r.id, reason: reason.trim()), success: l.rejected);
    }
    await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.changeRequests,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'pending', label: Text(l.pendingStatus)),
              ButtonSegment(value: 'approved', label: Text(l.approved)),
              ButtonSegment(value: 'rejected', label: Text(l.rejected)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: PagedListView<ProfileChangeRequest>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).changeRequests(status: _status, page: page),
            emptyMessage: l.noChangeRequests,
            emptyIcon: Icons.fact_check_outlined,
            separator: const SizedBox(height: 10),
            itemBuilder: (context, r, _) => AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(r.userName ?? r.oldFullName, style: context.serif(16))),
                  Text(f.relative(r.createdAt), style: context.sans(11, color: context.palette.subtle)),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileHistoryScreen(userId: r.userId, name: r.userName ?? r.oldFullName))),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: Text(l.changeHistory),
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in r.changes) ChangeLine(change: c),
                if (r.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r.note}”', style: context.sans(12, color: context.palette.muted).copyWith(fontStyle: FontStyle.italic))),
                if (r.reason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.reason!, style: context.sans(12, color: context.palette.muted))),
                if (r.reviewedByName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('— ${r.reviewedByName}', style: context.sans(11, color: context.palette.subtle))),
                if (r.status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: Text(l.reject))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => _decide(r, true), child: Text(l.approve))),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Attendance module: pick a program (today/upcoming first) → roster.
// Only administrators with attendance.manage record attendance; users never self-register it.
// =============================================================================
class AttendanceHomeScreen extends ConsumerStatefulWidget {
  const AttendanceHomeScreen({super.key});
  @override
  ConsumerState<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends ConsumerState<AttendanceHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  bool _past = false;

  // History / Overview State
  final _recordsCtrl = PagedListController<Json>();
  String _q = '';
  String _statusFilter = 'all'; // 'all', 'present', 'absent', 'excused'
  DateTime? _filterDate;
  String _datePreset = 'all'; // 'all', 'today', 'week', 'month', 'custom'
  Json? _overview;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final String? dateParam = _filterDate?.toIso8601String().substring(0, 10);
      final ov = await ref.read(adminRepositoryProvider).adminAttendanceOverview(
        date: dateParam,
        status: _statusFilter != 'all' ? _statusFilter : null,
        q: _q.isNotEmpty ? _q : null,
      );
      if (mounted) setState(() => _overview = ov);
    } catch (_) {
      if (mounted) setState(() => _overview = null);
    }
  }

  void _applyDateFilter(String preset) async {
    DateTime? d;
    final now = DateTime.now();
    if (preset == 'today') {
      d = DateTime(now.year, now.month, now.day);
    } else if (preset == 'custom') {
      final picked = await showEthiopianDatePicker(
        context: context,
        initialDate: _filterDate ?? now,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked == null || !mounted) return;
      d = picked;
    }
    setState(() {
      _datePreset = preset;
      _filterDate = d;
    });
    _recordsCtrl.refresh();
    _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider);
    final p = context.palette;

    return AdminScaffold(
      title: l.attendance,
      actions: [
        ReportExportButton(
          kind: 'attendance',
          label: l.attendance,
          filters: () => {
            if (_filterDate != null) 'date': _filterDate!.toIso8601String().substring(0, 10),
            if (_statusFilter != 'all') 'status': _statusFilter,
            if (_q.isNotEmpty) 'q': _q,
          },
        ),
        IconButton(tooltip: l.permissionRequests, icon: const Icon(Icons.edit_calendar_outlined), onPressed: () => context.push('/admin/permissions')),
        if (me?.canAny([Perm.attendanceCorrectionRequest, Perm.attendanceCorrectionApprove]) ?? false)
          IconButton(tooltip: l.attCorrections, icon: const Icon(Icons.rule_rounded), onPressed: () => context.push('/admin/attendance/corrections')),
        if (me?.can(Perm.attendanceOverride) ?? false)
          IconButton(key: const ValueKey('att-conflicts'), tooltip: l.attConflicts, icon: const Icon(Icons.cloud_sync_outlined), onPressed: () => context.push('/admin/attendance/conflicts')),
        if (me?.can(Perm.attendanceConfigure) ?? false)
          IconButton(tooltip: l.attSignaturePolicy, icon: const Icon(Icons.draw_outlined), onPressed: () => context.push('/admin/attendance/rules')),
        const ContextualHelpButton(screenRoute: '/admin/attendance'),
      ],
      body: Column(children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.maroon,
          indicatorColor: AppColors.maroon,
          tabs: [
            Tab(text: l.isEn ? 'Overview & History' : 'አጠቃላይ መረጃ እና ታሪክ', icon: const Icon(Icons.history_rounded, size: 20)),
            Tab(text: l.isEn ? 'Take Attendance' : 'መገኘት መመዝገቢያ', icon: const Icon(Icons.how_to_reg_rounded, size: 20)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 0: Complete Attendance Management & History
              _buildHistoryTab(l, f, p),

              // TAB 1: Take Attendance Roster (Existing Quick Taker workflow)
              _buildTakeAttendanceTab(l, f, p),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHistoryTab(AppLocalizations l, Formatters f, Palette p) {
    final String? dateParam = _filterDate?.toIso8601String().substring(0, 10);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        _recordsCtrl.refresh();
        await _loadOverview();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 1. Search Box
          SearchBox(
            hint: l.isEn ? 'Search by name, member ID, phone, program...' : 'በስም፣ አባል መለያ፣ ስልክ፣ ፕሮግራም ይፈልጉ...',
            onChanged: (v) {
              setState(() => _q = v.trim());
              _recordsCtrl.refresh();
              _loadOverview();
            },
          ),
          const SizedBox(height: 10),

          // 2. Date presets and Calendar Picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              FilterChip(
                selected: _datePreset == 'all',
                label: Text(l.isEn ? 'All Dates' : 'ሁሉም ቀናት'),
                onSelected: (_) => _applyDateFilter('all'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                selected: _datePreset == 'today',
                label: Text(l.attendanceToday),
                onSelected: (_) => _applyDateFilter('today'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                selected: _datePreset == 'custom',
                label: Text(
                  _filterDate != null
                      ? '${_filterDate!.year}-${_filterDate!.month.toString().padLeft(2, "0")}-${_filterDate!.day.toString().padLeft(2, "0")}'
                      : (l.isEn ? 'Pick Date' : 'ቀን ይምረጡ'),
                ),
                avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                onSelected: (_) => _applyDateFilter('custom'),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // 3. Status Filters
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'all', label: Text(l.isEn ? 'All' : 'ሁሉም')),
              ButtonSegment(value: 'present', label: Text(l.isEn ? 'Present' : 'የተገኙ')),
              ButtonSegment(value: 'absent', label: Text(l.isEn ? 'Absent' : 'ያልተገኙ')),
              ButtonSegment(value: 'excused', label: Text(l.isEn ? 'Excused' : 'ፈቃድ')),
            ],
            selected: {_statusFilter},
            onSelectionChanged: (s) {
              setState(() => _statusFilter = s.first);
              _recordsCtrl.refresh();
              _loadOverview();
            },
          ),
          const SizedBox(height: 14),

          // 4. Overview Metrics Cards
          if (_overview != null) _buildOverviewMetrics(l, p),
          const SizedBox(height: 16),

          // 5. Section Header for Records List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.isEn ? 'Attendance Records' : 'የተመዘገቡ መዝገቦች',
                style: context.serif(15, weight: FontWeight.w700),
              ),
              if (_overview != null)
                Text(
                  '${_overview!['total_records'] ?? 0} ${l.isEn ? "records" : "መዝገቦች"}',
                  style: context.sans(12, color: p.muted),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 6. Paginated Records
          PagedListView<Json>(
            key: ValueKey('$_q-$_datePreset-${_filterDate?.toIso8601String()}-$_statusFilter'),
            controller: _recordsCtrl,
            fetch: (page) => ref.read(adminRepositoryProvider).adminAttendanceRecords(
              date: dateParam,
              status: _statusFilter != 'all' ? _statusFilter : null,
              q: _q.isNotEmpty ? _q : null,
              page: page,
            ),
            emptyMessage: l.isEn ? 'No attendance records match your criteria' : 'ምንም ዓይነት የመገኘት መዝገብ አልተገኘም',
            emptyIcon: Icons.event_note_outlined,
            itemBuilder: (context, r, _) => _buildRecordTile(context, r, l, f, p),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics(AppLocalizations l, Palette p) {
    final ov = _overview!;
    final total = asIntOr(ov['total_records']);
    final present = asIntOr(ov['present']);
    final absent = asIntOr(ov['absent']);
    final excused = asIntOr(ov['excused']);
    final rate = ov['attendance_rate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricCol(l.isEn ? 'Total' : 'አጠቃላይ', '$total', AppColors.maroon),
              _metricCol(l.isEn ? 'Present' : 'የተገኙ', '$present', AppColors.success),
              _metricCol(l.isEn ? 'Absent' : 'ያልተገኙ', '$absent', AppColors.danger),
              _metricCol(l.isEn ? 'Excused' : 'ፈቃድ', '$excused', Colors.orange),
              _metricCol(l.isEn ? 'Rate' : 'መቶኛ', '$rate%', AppColors.goldDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRecordTile(BuildContext context, Json r, AppLocalizations l, Formatters f, Palette p) {
    final status = asStr(r['status']) ?? 'unmarked';
    final hasSig = r['has_signature'] == true;
    final via = asStr(r['via']) ?? 'manual';
    final attendedAt = asStr(r['attended_at']);

    Color statusColor = AppColors.danger;
    String statusText = l.isEn ? 'Absent' : 'ያልተገኘ';
    if (status == 'present') {
      statusColor = AppColors.success;
      statusText = l.isEn ? 'Present' : 'የተገኘ';
    } else if (status == 'excused') {
      statusColor = Colors.orange;
      statusText = l.isEn ? 'Excused' : 'ፈቃድ';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => _openRecordDetail(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asStr(r['user_name']) ?? '#${r['user_id']}',
                    style: context.serif(15, weight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (asStr(r['member_id']) != null) ...[
                  Text(r['member_id']!, style: context.sans(11, color: p.muted, weight: FontWeight.w600)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    '${r['program_title'] ?? ""} · ${r['occurrence_date'] ?? ""}',
                    style: context.sans(12, color: p.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(via == 'qr' ? Icons.qr_code_scanner_rounded : Icons.edit_note_rounded, size: 14, color: p.subtle),
                const SizedBox(width: 4),
                Text(via.toUpperCase(), style: context.sans(11, color: p.subtle)),
                if (hasSig) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.draw_rounded, size: 14, color: AppColors.maroon),
                  const SizedBox(width: 2),
                  Text(l.isEn ? 'Signed' : 'የፈረመ', style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600)),
                ],
                const Spacer(),
                if (attendedAt != null)
                  Text(attendedAt.length >= 16 ? attendedAt.substring(11, 16) : attendedAt, style: context.sans(11, color: p.subtle)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _openRecordDetail(Json r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AttendanceRecordDetailSheet(record: r),
    );
  }

  Widget _buildTakeAttendanceTab(AppLocalizations l, Formatters f, Palette p) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: false, label: Text(l.attendanceToday)), ButtonSegment(value: true, label: Text(l.attendanceRecent))],
          selected: {_past},
          onSelectionChanged: (s) => setState(() => _past = s.first),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Expanded(child: Text(l.attendanceOnlyAdmins, style: context.sans(12, color: p.muted))),
        ]),
      ),
      Expanded(
        child: PagedListView<Program>(
          key: ValueKey(_past),
          fetch: (page) async {
            try {
              return await ref.read(adminRepositoryProvider).takeablePrograms(scope: _past ? 'past' : 'upcoming', page: page);
            } on ApiException catch (e) {
              if (!e.isNetwork || page > 1) rethrow;
              final saved = await ref.read(offlinePackProvider).programs();
              final items = [
                for (final pr in saved)
                  Program.fromJson({...pr, 'starts_at': asJsonList(pr['occurrences']).firstOrNull?['starts_at'], 'ends_at': asJsonList(pr['occurrences']).firstOrNull?['ends_at']}),
              ];
              return Paged(items: items, page: 1, pages: 1, total: items.length, meta: const {'offline': true});
            }
          },
          emptyMessage: l.noPrograms,
          emptyIcon: Icons.event_busy_outlined,
          itemBuilder: (context, pr, _) => TrackTile(
            title: pr.title,
            subtitle: '${f.dateTime(pr.startsAt)} · ${l.participantsCount(pr.participantCount)}',
            leading: ListThumb(icon: Icons.how_to_reg_rounded, imageUrl: pr.imageUrl, active: !_past),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/admin/programs/${pr.id}/attendance${pr.participantCount == 0 ? '?source=all' : ''}'),
          ),
        ),
      ),
    ]);
  }
}

class _AttendanceRecordDetailSheet extends ConsumerWidget {
  const _AttendanceRecordDetailSheet({required this.record});
  final Json record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final r = record;
    final status = asStr(r['status']) ?? 'unmarked';
    final hasSig = r['has_signature'] == true;
    final sigUrl = asStr(r['signature_url']);
    final token = ref.read(secureStoreProvider).accessToken;

    Color statusColor = AppColors.danger;
    String statusText = l.isEn ? 'Absent' : 'ያልተገኘ';
    if (status == 'present') {
      statusColor = AppColors.success;
      statusText = l.isEn ? 'Present' : 'የተገኘ';
    } else if (status == 'excused') {
      statusColor = Colors.orange;
      statusText = l.isEn ? 'Excused' : 'ፈቃድ';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.isEn ? 'Attendance Details' : 'የመገኘት ዝርዝር መረጃ',
                    style: context.serif(18, weight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 6),

              // Member Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: asStr(r['user_photo']) != null ? NetworkImage(r['user_photo']!) : null,
                    child: asStr(r['user_photo']) == null ? const Icon(Icons.person_rounded) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStr(r['user_name']) ?? '',
                          style: context.serif(16, weight: FontWeight.w700),
                        ),
                        if (asStr(r['member_id']) != null)
                          Text(
                            'ID: ${r['member_id']}',
                            style: context.sans(12, color: p.muted),
                          ),
                        if (asStr(r['phone']) != null)
                          Text(
                            r['phone']!,
                            style: context.sans(12, color: p.muted),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detail List Items
              _detailRow(l.isEn ? 'Program / Event' : 'ፕሮግራም / ተግባር', '${r['program_title'] ?? ""}'),
              _detailRow(l.isEn ? 'Date' : 'ቀን', '${r['occurrence_date'] ?? ""}'),
              if (asStr(r['attended_at']) != null)
                _detailRow(l.isEn ? 'Captured At' : 'የተመዘገበበት ሰዓት', '${r['attended_at']}'),
              if (asStr(r['recorder_name']) != null)
                _detailRow(l.isEn ? 'Recorded By' : 'መዝጋቢ', '${r['recorder_name']}'),
              _detailRow(l.isEn ? 'Method' : 'ዘዴ', (asStr(r['via']) ?? 'manual').toUpperCase()),
              if (asStr(r['notes']) != null && asStr(r['notes'])!.isNotEmpty)
                _detailRow(l.isEn ? 'Notes' : 'ማስታወሻ', r['notes']!),

              // Digital Signature Preview
              if (hasSig && sigUrl != null) ...[
                const SizedBox(height: 14),
                Text(
                  l.isEn ? 'Member Digital Signature' : 'የአባሉ ዲጂታል ፊርማ',
                  style: context.sans(13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.border),
                  ),
                  child: Image.network(
                    '${AppConfig.apiBaseUrl}$sigUrl',
                    headers: token != null ? {'Authorization': 'Bearer $token'} : null,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        l.isEn ? 'Signature preview unavailable' : 'ፊርማውን ማሳየት አልተቻለም',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Absence permission requests (attendance.manage): review + policy (deadline, quotas, weight).
// =============================================================================
class PermissionRequestsScreen extends ConsumerStatefulWidget {
  const PermissionRequestsScreen({super.key});
  @override
  ConsumerState<PermissionRequestsScreen> createState() => _PermissionRequestsScreenState();
}

class _PermissionRequestsScreenState extends ConsumerState<PermissionRequestsScreen> {
  final _ctrl = PagedListController<PermissionRequest>();
  String _status = 'pending';

  Future<void> _decide(PermissionRequest r, bool approve) async {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    final note = await promptText(context, title: approve ? l.approve : l.reject, label: l.overrideReason, maxLines: 2);
    if (note == null || !mounted) return;
    await runWithProgress(context, () => repo.reviewPermission(r.id, approve: approve, note: note.trim().isEmpty ? null : note.trim()),
        success: approve ? l.approved : l.rejected);
    await _ctrl.refresh();
  }

  /// Undo an approval given by mistake (reason required; the member is told).
  Future<void> _cancelExcuse(PermissionRequest r) async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.permissionCancelExcuse, label: l.overrideReason, hint: l.permissionCancelExcuseHint, maxLines: 2, required: true);
    if (reason == null || reason.length < 3 || !mounted) return;
    await runWithProgress(context, () => ref.read(adminRepositoryProvider).cancelApprovedPermission(r.id, reason), success: l.permissionCancelled);
    await _ctrl.refresh();
  }

  Future<void> _policy() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _PermissionPolicyEditor()),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final p = context.palette;
    return AdminScaffold(
      title: l.permissionRequests,
      actions: [IconButton(tooltip: l.permissionPolicy, icon: const Icon(Icons.tune_rounded), onPressed: _policy)],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'pending', label: Text(l.pendingStatus)),
              ButtonSegment(value: 'approved', label: Text(l.approved)),
              ButtonSegment(value: 'rejected', label: Text(l.rejected)),
              ButtonSegment(value: 'cancelled', label: Text(l.permissionCancelled)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: PagedListView<PermissionRequest>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).permissionRequests(status: _status, page: page),
            emptyMessage: l.noPermissionRequests,
            emptyIcon: Icons.edit_calendar_outlined,
            separator: const SizedBox(height: 10),
            itemBuilder: (context, r, _) => AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(r.fullName, style: context.serif(16))),
                  if (r.createdAt != null) Text(f.relative(r.createdAt!), style: context.sans(11, color: p.subtle)),
                ]),
                const SizedBox(height: 4),
                Text([r.programTitle, if (r.startsAt != null) f.dateTime(r.startsAt!)].join(' · '), style: context.sans(13, color: p.text)),
                if (r.reason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.reason!, style: context.sans(13, color: p.muted))),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.permissionUsage(r.monthUsed, r.quarterUsed), style: context.sans(11, color: p.subtle)),
                ),
                if (r.reviewNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('— ${r.reviewNote!}', style: context.sans(11, color: p.subtle))),
                if (r.status == 'cancelled' && r.cancelReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.permissionCancelledBy(r.cancelledByName ?? '—', r.cancelReason!), style: context.sans(11, color: AppColors.danger)),
                  ),
                if (r.status != 'cancelled') const SizedBox(height: 10),
                // An approval given by mistake is cancelled (not turned into a rejection).
                if (r.status == 'approved')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _cancelExcuse(r),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: Text(l.permissionCancelExcuse),
                  )
                else if (r.status != 'cancelled')
                  Row(children: [
                    if (r.status != 'rejected') Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: Text(l.reject))),
                    if (r.status == 'pending') const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => _decide(r, true), child: Text(l.approve))),
                  ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PermissionPolicyEditor extends ConsumerStatefulWidget {
  const _PermissionPolicyEditor();
  @override
  ConsumerState<_PermissionPolicyEditor> createState() => _PermissionPolicyEditorState();
}

class _PermissionPolicyEditorState extends ConsumerState<_PermissionPolicyEditor> {
  final _form = GlobalKey<FormState>();
  final _hours = TextEditingController();
  final _month = TextEditingController();
  final _quarter = TextEditingController();
  final _weight = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_hours, _month, _quarter, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final j = await ref.read(adminRepositoryProvider).permissionPolicy();
      if (!mounted) return;
      setState(() {
        _enabled = j['enabled'] != false;
        _hours.text = '${asIntOr(j['deadline_hours'], 24)}';
        _month.text = asInt(j['monthly_limit'])?.toString() ?? '';
        _quarter.text = asInt(j['quarterly_limit'])?.toString() ?? '';
        _weight.text = '${j['weight'] ?? 0.5}';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  /// Empty is allowed (= unlimited); otherwise a whole number in range.
  String? _optionalInt(String? s, int max) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return (v == null || v < 0 || v > max) ? '0 – $max' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    int? opt(TextEditingController c) => c.text.trim().isEmpty ? null : int.parse(c.text.trim());
    try {
      await ref.read(adminRepositoryProvider).savePermissionPolicy({
        'enabled': _enabled,
        'deadline_hours': int.parse(_hours.text.trim()),
        'monthly_limit': opt(_month),
        'quarterly_limit': opt(_quarter),
        'weight': double.parse(_weight.text.trim()),
      });
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) return const SizedBox(height: 200, child: LoadingView());
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
          Text(l.permissionPolicy, style: context.serif(19)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.permissionsEnabled), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
          TextFormField(
            controller: _hours,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.permissionDeadlineHours),
            validator: (s) => (s ?? '').trim().isEmpty ? '0 – 1440' : _optionalInt(s, 1440),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _month, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.permissionMonthlyLimit), validator: (s) => _optionalInt(s, 100)),
          const SizedBox(height: 12),
          TextFormField(controller: _quarter, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.permissionQuarterlyLimit), validator: (s) => _optionalInt(s, 300)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.permissionWeight, helperText: l.permissionWeightHint, helperMaxLines: 2),
            validator: (s) {
              final v = double.tryParse((s ?? '').trim());
              return (v == null || v < 0 || v > 1) ? '0 – 1' : null;
            },
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

// =============================================================================
// App versions (releases.manage): publish APKs for the download page / force update.
// =============================================================================
final _releasesProvider = FutureProvider.autoDispose<List<AppRelease>>((ref) => ref.watch(adminRepositoryProvider).releases());

String downloadPageUrl() => '${Uri.parse(AppConfig.apiBaseUrl).origin}/download';

class ReleasesScreen extends ConsumerWidget {
  const ReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.releases,
      actions: [
        IconButton(
          tooltip: l.openDownloadPage,
          icon: const Icon(Icons.open_in_browser_rounded),
          onPressed: () => launchUrl(Uri.parse(downloadPageUrl()), mode: LaunchMode.externalApplication),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _PublishSheet()),
          );
          if (ok == true) ref.invalidate(_releasesProvider);
        },
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(l.newRelease),
      ),
      body: AsyncView(
        value: ref.watch(_releasesProvider),
        onRetry: () => ref.invalidate(_releasesProvider),
        data: (list) => list.isEmpty
            ? EmptyView(message: l.noResults, icon: Icons.system_update_outlined)
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                for (final r in list)
                  TrackTile(
                    title: 'v${r.versionName} (${r.versionCode})',
                    subtitle: [
                      f.date(r.createdAt),
                      Formatters.fileSize(r.fileSize),
                      l.downloadsCount(r.downloadCount),
                      if (r.isMandatory) l.mandatoryUpdate.split(' (').first,
                      if (!r.isPublished) l.statusDraft,
                    ].join(' · '),
                    leading: ListThumb(icon: Icons.android_rounded, active: r.isMandatory),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final repo = ref.read(adminRepositoryProvider);
                        switch (v) {
                          case 'mandatory':
                            await runWithProgress(context, () => repo.updateRelease(r.id, {'is_mandatory': !r.isMandatory}), success: l.saved);
                          case 'publish':
                            await runWithProgress(context, () => repo.updateRelease(r.id, {'is_published': !r.isPublished}), success: l.saved);
                          case 'delete':
                            if (await showConfirm(context, l.deleteConfirm, destructive: true) && context.mounted) {
                              await runWithProgress(context, () => repo.deleteRelease(r.id), success: l.deleted);
                            }
                        }
                        ref.invalidate(_releasesProvider);
                      },
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem(value: 'mandatory', checked: r.isMandatory, child: Text(l.mandatoryUpdate.split(' (').first)),
                        PopupMenuItem(value: 'publish', child: Text(r.isPublished ? l.unpublish : l.publish)),
                        PopupMenuItem(value: 'delete', child: Text(l.delete, style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                    onTap: r.releaseNotes == null ? null : () => showInfo(context, r.releaseNotes!, title: 'v${r.versionName}'),
                  ),
              ]),
      ),
    );
  }
}

class _PublishSheet extends ConsumerStatefulWidget {
  const _PublishSheet();
  @override
  ConsumerState<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends ConsumerState<_PublishSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _notes = TextEditingController();
  final _minCode = TextEditingController();
  bool _mandatory = false;
  String? _path;
  String? _fileName;
  double? _progress;
  Object? _error;

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    setState(() {
      _path = files.first.path;
      _fileName = files.first.name;
    });
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_path == null) {
      showSnack(context, l.chooseApk);
      return;
    }
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).publishRelease(
            filePath: _path!,
            versionName: _name.text.trim(),
            versionCode: int.parse(_code.text.trim()),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            mandatory: _mandatory,
            minSupportedCode: int.tryParse(_minCode.text.trim()),
            onProgress: (p) => setState(() => _progress = p),
          );
      if (mounted) {
        showSnack(context, l.uploadDone);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text(l.newRelease, style: context.serif(19)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _progress != null ? null : _pick, icon: const Icon(Icons.attach_file_rounded), label: Text(_fileName ?? l.chooseApk)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            validator: (s) => RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.]+)?$').hasMatch(s?.trim() ?? '') ? null : l.vInvalidVersion,
            decoration: InputDecoration(labelText: l.versionName),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            validator: (s) => v.intRange(s, min: 1, max: 2100000000),
            decoration: InputDecoration(labelText: l.versionCode, errorText: serverFieldError(l, _error, 'version_code')),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.releaseNotes, alignLabelWithHint: true)),
          const SizedBox(height: 12),
          TextFormField(controller: _minCode, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 2100000000, optional: true), decoration: InputDecoration(labelText: l.minSupportedCode)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.mandatoryUpdate), value: _mandatory, onChanged: (x) => setState(() => _mandatory = x)),
          if (_progress != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: LinearProgressIndicator(value: _progress)),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          FilledButton(onPressed: _progress != null ? null : _submit, child: Text(l.publish)),
        ]),
      ),
    );
  }
}
