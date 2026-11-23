import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/file_preview.dart';
import '../../widgets/states.dart';
import '../auth/session.dart' show currentUserProvider;
import 'admin_widgets.dart' show AdminScaffold;

@immutable
class DiagnosticsQuery {
  const DiagnosticsQuery({
    this.status = 'all',
    this.severity = 'all',
    this.module = 'all',
    this.search = '',
    this.page = 1,
    this.limit = 25,
  });

  final String status;
  final String severity;
  final String module;
  final String search;
  final int page;
  final int limit;

  Map<String, dynamic> toMap() => {
        if (status != 'all') 'status': status,
        if (severity != 'all') 'severity': severity,
        if (module != 'all') 'module': module,
        if (search.isNotEmpty) 'q': search,
        'page': page,
        'limit': limit,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosticsQuery &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          severity == other.severity &&
          module == other.module &&
          search == other.search &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(status, severity, module, search, page, limit);
}

final diagnosticReportsProvider = FutureProvider.autoDispose.family<Json, DiagnosticsQuery>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  return api.get<Json>(
    '/admin/diagnostics',
    query: query.toMap(),
    parse: asJson,
  );
});

class DiagnosticsAdminScreen extends ConsumerStatefulWidget {
  const DiagnosticsAdminScreen({super.key});

  @override
  ConsumerState<DiagnosticsAdminScreen> createState() => _DiagnosticsAdminScreenState();
}

class _DiagnosticsAdminScreenState extends ConsumerState<DiagnosticsAdminScreen> {
  String _status = 'all'; // all, new, investigating, resolved, dismissed
  String _severity = 'all'; // all, critical, error, warning, info
  String _module = 'all';
  String _search = '';
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();

  DiagnosticsQuery _buildQuery() {
    return DiagnosticsQuery(
      status: _status,
      severity: _severity,
      module: _module,
      search: _search,
      page: _page,
      limit: 25,
    );
  }

  void _refresh() {
    ref.invalidate(diagnosticReportsProvider(_buildQuery()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final user = ref.watch(currentUserProvider);
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final asyncData = ref.watch(diagnosticReportsProvider(_buildQuery()));

    return AdminScaffold(
      title: isEn ? 'Diagnostic & Error Reports' : 'የስርዓት ስህተት ሪፖርቶች',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: l.retry,
          onPressed: _refresh,
        ),
      ],
      body: asyncData.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          error: e,
          onRetry: _refresh,
          module: 'admin',
          screen: 'DiagnosticsAdminScreen',
        ),
        data: (json) {
          final summary = asJson(json['summary']);
          final list = asJsonList(json['data']);
          final meta = asJson(json['meta']);
          final totalPages = asInt(meta['pages']) ?? 1;

          return Column(
            children: [
              // Summary cards
              _buildSummaryHeader(summary, isEn),

              // Filter row
              _buildFilterRow(isEn),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: isEn ? 'Search report ID, screen, or message...' : 'የሪፖርት መለያ፣ ገጽ ወይም መልእክት ይፈልጉ...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _page = 1;
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _search = val.trim();
                      _page = 1;
                    });
                  },
                ),
              ),

              // Reports list
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          isEn ? 'No diagnostic reports found' : 'ምንም የሪፖርት መዝገብ አልተገኘም',
                          style: context.sans(14, color: context.palette.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = list[i];
                          return _ReportTile(
                            report: item,
                            isSuperAdmin: isSuperAdmin,
                            onUpdated: _refresh,
                          );
                        },
                      ),
              ),

              // Pagination controls
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isEn ? "Page" : "ገጽ"} $_page / $totalPages',
                        style: context.sans(12, color: context.palette.muted),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: _page < totalPages
                                ? () => setState(() => _page++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(Json summary, bool isEn) {
    final unresolved = asInt(summary['total_unresolved']) ?? 0;
    final byStatus = asJson(summary['by_status']);
    final newCount = asInt(byStatus['new']) ?? 0;
    final bySev = asJson(summary['by_severity']);
    final criticalCount = asInt(bySev['critical']) ?? 0;
    final errorCount = asInt(bySev['error']) ?? 0;
    final userReports = asInt(summary['user_reports_count']) ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatCard(
            title: isEn ? 'Unresolved' : 'ያልተፈቱ',
            value: '$unresolved',
            color: unresolved > 0 ? AppColors.danger : AppColors.success,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _StatCard(
            title: isEn ? 'New' : 'አዳዲስ',
            value: '$newCount',
            color: const Color(0xFF673AB7),
            icon: Icons.fiber_new_rounded,
          ),
          const SizedBox(width: 8),
          _StatCard(
            title: isEn ? 'Critical / Error' : 'አሳሳቢ ስህተቶች',
            value: '${criticalCount + errorCount}',
            color: Colors.deepOrange,
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(width: 8),
          _StatCard(
            title: isEn ? 'User Reports' : 'የተጠቃሚ ሪፖርቶች',
            value: '$userReports',
            color: AppColors.goldDark,
            icon: Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isEn) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Status filter
          DropdownButton<String>(
            value: _status,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'all', child: Text(isEn ? 'All Status' : 'ሁሉም ሁኔታ')),
              DropdownMenuItem(value: 'new', child: Text(isEn ? 'New' : 'አዲስ')),
              DropdownMenuItem(value: 'investigating', child: Text(isEn ? 'Investigating' : 'በምርመራ ላይ')),
              DropdownMenuItem(value: 'resolved', child: Text(isEn ? 'Resolved' : 'የተፈታ')),
              DropdownMenuItem(value: 'dismissed', child: Text(isEn ? 'Dismissed' : 'የተዘጋ')),
            ],
            onChanged: (val) {
              if (val != null) setState(() { _status = val; _page = 1; });
            },
          ),
          const SizedBox(width: 12),

          // Severity filter
          DropdownButton<String>(
            value: _severity,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'all', child: Text(isEn ? 'All Severity' : 'ሁሉም ደረጃ')),
              DropdownMenuItem(value: 'critical', child: Text(isEn ? 'Critical' : 'አሳሳቢ')),
              DropdownMenuItem(value: 'error', child: Text(isEn ? 'Error' : 'ስህተት')),
              DropdownMenuItem(value: 'warning', child: Text(isEn ? 'Warning' : 'ማስጠንቀቂያ')),
              DropdownMenuItem(value: 'info', child: Text(isEn ? 'Info' : 'መረጃ')),
            ],
            onChanged: (val) {
              if (val != null) setState(() { _severity = val; _page = 1; });
            },
          ),
          const SizedBox(width: 12),

          // Module filter
          DropdownButton<String>(
            value: _module,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'all', child: Text(isEn ? 'All Modules' : 'ሁሉም ክፍሎች')),
              const DropdownMenuItem(value: 'education', child: Text('Education')),
              const DropdownMenuItem(value: 'sinksar', child: Text('Sinksar')),
              const DropdownMenuItem(value: 'files', child: Text('Files')),
              const DropdownMenuItem(value: 'auth', child: Text('Auth')),
              const DropdownMenuItem(value: 'general', child: Text('General')),
            ],
            onChanged: (val) {
              if (val != null) setState(() { _module = val; _page = 1; });
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: context.serif(16, weight: FontWeight.bold, color: color)),
              Text(title, style: context.sans(11, color: context.palette.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends ConsumerWidget {
  const _ReportTile({
    required this.report,
    required this.isSuperAdmin,
    required this.onUpdated,
  });

  final Json report;
  final bool isSuperAdmin;
  final VoidCallback onUpdated;

  Color _severityColor(String sev) => switch (sev) {
    'critical' => Colors.red.shade700,
    'error' => Colors.deepOrange,
    'warning' => AppColors.goldDark,
    _ => Colors.blueGrey,
  };

  Color _statusColor(String status) => switch (status) {
    'new' => const Color(0xFF673AB7),
    'investigating' => Colors.orange.shade800,
    'resolved' => AppColors.success,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportId = asStr(report['report_id']) ?? 'REP';
    final module = asStr(report['module']) ?? 'general';
    final screen = asStr(report['screen']);
    final message = asStr(report['message']) ?? '';
    final severity = asStr(report['severity']) ?? 'error';
    final status = asStr(report['status']) ?? 'new';
    final occurrences = asInt(report['occurrences']) ?? 1;
    final hasScreenshot = report['has_screenshot'] == true;
    final isUserReport = report['is_user_report'] == true;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _openDetailsDialog(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Severity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _severityColor(severity).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _severityColor(severity)),
                ),
              ),
              const SizedBox(width: 6),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status)),
                ),
              ),
              if (isUserReport) ...[
                const SizedBox(width: 6),
                const Icon(Icons.person_pin_rounded, size: 16, color: AppColors.goldDark),
              ],
              if (hasScreenshot) ...[
                const SizedBox(width: 4),
                const Icon(Icons.image_outlined, size: 16, color: Colors.blueGrey),
              ],
              const Spacer(),
              Text(
                reportId,
                style: context.mono(11, color: context.palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.sans(13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$module${screen != null && screen.isNotEmpty ? " • $screen" : ""}',
                style: context.sans(11, color: context.palette.muted),
              ),
              const Spacer(),
              if (occurrences > 1)
                Text(
                  '$occurrences occurrences',
                  style: context.sans(11, color: AppColors.danger),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDetailsDialog(BuildContext context, WidgetRef ref) async {
    final id = asIntOr(report['id']);
    final api = ref.read(apiClientProvider);

    // Fetch complete report including authorized stack trace
    Json detail = report;
    try {
      detail = await api.get<Json>('/admin/diagnostics/$id', parse: asJson);
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ReportDetailDialog(
        report: detail,
        isSuperAdmin: isSuperAdmin,
        onUpdated: onUpdated,
      ),
    );
  }
}

class _ReportDetailDialog extends ConsumerStatefulWidget {
  const _ReportDetailDialog({
    required this.report,
    required this.isSuperAdmin,
    required this.onUpdated,
  });

  final Json report;
  final bool isSuperAdmin;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends ConsumerState<_ReportDetailDialog> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    final id = asIntOr(widget.report['id']);
    final note = _noteController.text.trim();

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch<void>(
        '/admin/diagnostics/$id',
        body: {
          'status': newStatus,
          if (note.isNotEmpty) 'note': note,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showSnack(context, 'Update failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final id = asIntOr(widget.report['id']);
    final reportId = asStr(widget.report['report_id']) ?? 'REP';
    final module = asStr(widget.report['module']) ?? 'general';
    final screen = asStr(widget.report['screen']) ?? 'N/A';
    final message = asStr(widget.report['message']) ?? '';
    final trace = asStr(widget.report['stack_trace']);
    final userDesc = asStr(widget.report['user_description']);
    final steps = asStr(widget.report['reproduce_steps']);
    final hasScreenshot = widget.report['has_screenshot'] == true;
    final status = asStr(widget.report['status']) ?? 'new';
    final statusNote = asStr(widget.report['status_note']);
    final occurrences = asInt(widget.report['occurrences']) ?? 1;
    final appVer = asStr(widget.report['app_version']) ?? '1.5.3';
    final platform = asStr(widget.report['platform']) ?? 'android';
    final endpoint = asStr(widget.report['endpoint']);
    final httpStatus = asInt(widget.report['http_status']);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$reportId ($module)',
                      style: context.serif(16, weight: FontWeight.bold, color: AppColors.maroon),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screen & Meta
                      Text('Screen: $screen • Platform: $platform • Version: $appVer', style: context.sans(12, color: context.palette.muted)),
                      if (occurrences > 1)
                        Text('Occurrences: $occurrences times', style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600)),
                      const SizedBox(height: 12),

                      // Error message
                      Text(isEn ? 'Safe Error Summary:' : 'የስህተት ማጠቃለያ፦', style: context.sans(12, weight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SelectableText(message, style: context.sans(13)),
                      const SizedBox(height: 12),

                      if (userDesc != null && userDesc.isNotEmpty) ...[
                        Text(isEn ? 'User Problem Description:' : 'የተጠቃሚው ማብራሪያ፦', style: context.sans(12, weight: FontWeight.bold, color: AppColors.maroon)),
                        const SizedBox(height: 4),
                        SelectableText(userDesc, style: context.sans(13)),
                        const SizedBox(height: 12),
                      ],

                      if (steps != null && steps.isNotEmpty) ...[
                        Text(isEn ? 'Steps to Reproduce:' : 'የመደገሚያ እርምጃዎች፦', style: context.sans(12, weight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SelectableText(steps, style: context.sans(13)),
                        const SizedBox(height: 12),
                      ],

                      if (endpoint != null && endpoint.isNotEmpty) ...[
                        Text('Endpoint: $endpoint (HTTP $httpStatus)', style: context.mono(11, color: context.palette.muted)),
                        const SizedBox(height: 12),
                      ],

                      // Screenshot action
                      if (hasScreenshot) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            openFilePreview(
                              context,
                              '',
                              name: 'screenshot_$id.jpg',
                            );
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: Text(isEn ? 'View User Screenshot' : 'የተጠቃሚውን የስክሪን ቅጂ ይመልከቱ'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Stack trace (Super Admin only)
                      if (trace != null && trace.isNotEmpty) ...[
                        Text(isEn ? 'Diagnostic Stack Trace:' : 'የስርዓት መመርመሪያ ዝርዝር (Stack Trace)፦', style: context.sans(12, weight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: context.palette.fill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            trace,
                            style: context.mono(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Audit note history
                      if (statusNote != null && statusNote.isNotEmpty) ...[
                        Text(isEn ? 'Audit & Status History:' : 'የሁኔታ ታሪክና ማስታወሻ፦', style: context.sans(12, weight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: context.palette.fill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(statusNote, style: context.sans(11)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Note entry for status change
                      TextField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: isEn ? 'Add audit resolution note (Optional)' : 'የመፍትሄ ወይም የሁኔታ ማስታወሻ ያክሉ (አማራጭ)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Status actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status != 'investigating')
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => _updateStatus('investigating'),
                      child: Text(isEn ? 'Mark Investigating' : 'በምርመራ ላይ'),
                    ),
                  if (status != 'resolved')
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: _isSaving ? null : () => _updateStatus('resolved'),
                      child: Text(isEn ? 'Mark Resolved' : 'ችግሩ ተፈትቷል'),
                    ),
                  if (status != 'dismissed')
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => _updateStatus('dismissed'),
                      child: Text(isEn ? 'Dismiss' : 'ዝጋ'),
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
