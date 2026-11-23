import 'report_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/member_groups.dart';
import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import 'admin_widgets.dart';
import 'org_admin.dart' show departmentName;
import '../members/member_form.dart' show memberGroupLabel;
import '../guidance/contextual_help_sheet.dart';

// =============================================================================
// Reports
// =============================================================================
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _days = 30;

  Json get _range => {
        'from': DateTime.now().subtract(Duration(days: _days)).toUtc().toIso8601String(),
        'to': DateTime.now().toUtc().toIso8601String(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    final reports = [
      ('users', l.reportUsers, Icons.people_alt_outlined),
      ('mezmurs', l.reportMezmurs, Icons.library_music_outlined),
      ('attendance', l.reportAttendance, Icons.how_to_reg_outlined),
      ('borrowings', l.reportBorrowings, Icons.inventory_2_outlined),
      ('notifications', l.reportNotifications, Icons.notifications_none_rounded),
      if (me.can(Perm.auditLogsView)) ('admin-activity', l.reportAdminActivity, Icons.admin_panel_settings_outlined),
    ];
    return DefaultTabController(
      length: reports.length,
      child: AdminScaffold(
        title: l.reports,
        // Export the report of the selected tab with the period on screen.
        actions: [
          const ContextualHelpButton(screenRoute: '/admin/reports'),
          Builder(builder: (ctx) {
            final tab = DefaultTabController.of(ctx);
            return AnimatedBuilder(
              animation: tab,
              builder: (_, _) => ReportExportButton(kind: reports[tab.index].$1, filters: () => _range),
            );
          }),
        ],
        bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final r in reports) Tab(text: r.$2)]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 7, label: Text(l.last7Days)),
                ButtonSegment(value: 30, label: Text(l.last30Days)),
                ButtonSegment(value: 90, label: Text(l.last90Days)),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final r in reports)
                FutureBuilder<Json>(
                  key: ValueKey('${r.$1}$_days'),
                  future: repo.report(r.$1, filter: _range),
                  builder: (context, snap) {
                    if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() {}));
                    if (!snap.hasData) return const LoadingView();
                    return _ReportView(name: r.$1, data: snap.data!);
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.name, required this.data});
  final String name;
  final Json data;

  Widget _ranked(BuildContext context, String title, List<Json> rows, String Function(Json) label, int Function(Json) count) {
    final max = rows.fold<int>(1, (m, r) => count(r) > m ? count(r) : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title: title),
      if (rows.isEmpty) EmptyView(message: context.l10n.noResults, icon: Icons.insights_outlined),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(flex: 3, child: Text(label(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(13))),
            Expanded(
              flex: 2,
              child: Stack(children: [
                Container(height: 18, decoration: BoxDecoration(color: context.palette.fill, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: count(r) / max,
                  child: Container(height: 18, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4))),
                ),
              ]),
            ),
            SizedBox(width: 44, child: Text('${count(r)}', textAlign: TextAlign.end, style: context.sans(12, weight: FontWeight.w600))),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final children = <Widget>[];
    switch (name) {
      case 'users':
        final byStatus = asJson(data['by_status']);
        children.addAll([
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              StatTile(label: l.statusActive, value: '${asIntOr(byStatus['active'])}'),
              StatTile(label: l.statusDisabled, value: '${asIntOr(byStatus['disabled'])}'),
              StatTile(label: l.distinctLogins, value: '${asIntOr(data['distinct_logins'])}'),
            ],
          ),
          _ranked(context, l.registrationsPerDay, asJsonList(data['registrations_per_day']), (r) => '${r['day']}', (r) => asIntOr(r['count'])),
        ]);
      case 'mezmurs':
        String title(Json r) => '${r['title']}';
        int c(Json r) => asIntOr(r['count']);
        children.addAll([
          _ranked(context, l.topViewed, asJsonList(data['top_viewed']), title, c),
          _ranked(context, l.topPlayed, asJsonList(data['top_played']), title, c),
          _ranked(context, l.topFavorited, asJsonList(data['top_favorited']), title, c),
          _ranked(context, l.topDownloaded, asJsonList(data['top_downloaded']), title, c),
          _ranked(context, l.topSearches, asJsonList(data['top_searches']), (r) => '${r['q']}', c),
        ]);
      case 'attendance':
        children.add(SectionHeader(title: l.reportAttendance));
        for (final p in asJsonList(data['programs'])) {
          children.add(TrackTile(
            title: '${p['title']}',
            subtitle: f.date(asDate(p['starts_at'])),
            leading: const ListThumb(icon: Icons.event_rounded),
            trailing: Pill(l.attendedOf(asIntOr(p['attended']), asIntOr(p['participants']))),
          ));
        }
      case 'borrowings':
        final byStatus = asJson(data['by_status']);
        final fines = asJson(data['fines']);
        children.addAll([
          SectionHeader(title: l.byStatus),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final e in byStatus.entries) Pill('${e.key}: ${e.value}')]),
          _ranked(context, l.byItem, asJsonList(data['by_item']), (r) => '${r['name']} (${r['code']})', (r) => asIntOr(r['borrowings'])),
          SectionHeader(title: l.fines),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in fines.entries) Pill('${e.key}: ${f.money(asDouble(asJson(e.value)['total']), 'ETB')} (${asIntOr(asJson(e.value)['count'])})'),
          ]),
          SectionHeader(title: l.overdueBorrowings),
          for (final o in asJsonList(data['overdue']))
            TrackTile(
              title: '${o['full_name']} — ${o['item_name']}',
              subtitle: '${o['phone']} · ${l.dueOn}: ${f.shortDate(Formatters.parseDateOnly(asStr(o['due_on'])))}',
              leading: const ListThumb(icon: Icons.warning_amber_rounded, active: true),
              onTap: () => context.push('/admin/borrowings/${o['id']}'),
            ),
        ]);
      case 'notifications':
        children.addAll([
          _ranked(context, l.notifications, asJsonList(data['by_type']), (r) => '${r['type']} · ${r['delivery_status']}', (r) => asIntOr(r['count'])),
          _ranked(context, l.sender, asJsonList(data['by_sender']), (r) => '${r['sender_name']}', (r) => asIntOr(r['broadcasts'])),
        ]);
      case 'admin-activity':
        children.add(_ranked(context, l.reportAdminActivity, asJsonList(data['actions']), (r) => '${r['actor_name']} · ${r['action']}', (r) => asIntOr(r['count'])));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: children);
  }
}

// =============================================================================
// Logs
// =============================================================================
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});
  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _action = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.auditLogs,
      actions: [
        const ContextualHelpButton(screenRoute: '/admin/audit'),
        ReportExportButton(kind: 'audit-logs', filters: () => {'action': _action.isEmpty ? null : _action}),
      ],
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: SearchBox(hint: l.action, onChanged: (v) => setState(() => _action = v))),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_action),
            fetch: (page) => ref.read(adminRepositoryProvider).auditLogs(filter: {'action': _action.isEmpty ? null : _action}, page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, e, _) => TrackTile(
              title: '${e['action']}',
              subtitle: [
                '${e['actor_name'] ?? '—'}',
                if (e['entity_type'] != null) '${e['entity_type']} #${e['entity_id'] ?? ''}',
                f.dateTime(asDate(e['created_at'])),
              ].join(' · '),
              leading: ListThumb(icon: '${e['action']}'.contains('denied') ? Icons.block_rounded : Icons.fact_check_outlined, active: '${e['action']}'.contains('denied')),
              onTap: () => showInfo(context, _pretty(e), title: '${e['action']}', selectable: true),
            ),
          ),
        ),
      ]),
    );
  }

  String _pretty(Json e) {
    final meta = asJson(e['metadata']);
    return [
      '${e['actor_name'] ?? '—'}',
      if (e['ip'] != null) 'IP: ${e['ip']}',
      if (e['entity_type'] != null) '${e['entity_type']} #${e['entity_id'] ?? ''}',
      for (final m in meta.entries) '${m.key}: ${m.value}',
    ].join('\n');
  }
}

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key, this.initialFilter});
  final Map<String, dynamic>? initialFilter;
  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String? _module;
  String? _action;
  String _q = '';
  DateTime? _from;
  DateTime? _to;
  int? _quickDays;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter?['from'] != null) {
      _from = DateTime.tryParse('${widget.initialFilter!['from']}');
    }
    if (widget.initialFilter?['to'] != null) {
      _to = DateTime.tryParse('${widget.initialFilter!['to']}');
    }
  }

  static const _modules = [
    (null, 'ሁሉም (All)'),
    ('mezmur', 'መዝሙር (Mezmur)'),
    ('library', 'ቤተ-መጻሕፍት (Library)'),
    ('education', 'ትምህርት (Education)'),
    ('programs', 'መርሐ-ግብር (Programs)'),
    ('attendance', 'አቴንዳንስ (Attendance)'),
  ];

  static const _allActions = [
    'login', 'register', 'mezmur_view', 'mezmur_search', 'audio_play',
    'favorite_add', 'book_read', 'book_download', 'borrow', 'return',
    'lesson_view', 'material_open', 'quiz_attempt', 'magazine_view',
    'program_register', 'attendance',
  ];

  List<String> get _currentActions => switch (_module) {
        'mezmur' => const ['mezmur_view', 'mezmur_search', 'audio_play', 'audio_complete', 'favorite_add', 'favorite_remove', 'download'],
        'library' => const ['book_read', 'book_download', 'borrow', 'return'],
        'education' => const ['lesson_view', 'material_open', 'quiz_attempt', 'magazine_view'],
        'programs' => const ['program_view', 'program_register', 'program_unregister', 'reminder_create'],
        'attendance' => const ['attendance'],
        _ => _allActions,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final filter = {
      ...?widget.initialFilter,
      if (_module != null) 'module': _module,
      if (_action != null) 'action': _action,
      if (_q.trim().isNotEmpty) 'q': _q.trim(),
      if (_from != null) 'from': _from!.toIso8601String(),
      if (_to != null) 'to': _to!.toIso8601String(),
    };
    return AdminScaffold(
      title: l.activityLogs,
      actions: [ReportExportButton(kind: 'activity-logs', filters: () => filter)],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBox(
            hint: 'በስም ወይም ስልክ ፈልግ...',
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        // Module filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            for (final m in _modules)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(m.$2),
                  selected: _module == m.$1,
                  onSelected: (_) => setState(() {
                    _module = m.$1;
                    _action = null;
                  }),
                ),
              ),
          ]),
        ),
        // Action filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(children: [
            ChoiceChip(
              label: Text(l.all),
              selected: _action == null,
              onSelected: (_) => setState(() => _action = null),
            ),
            for (final a in _currentActions)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(activityLabel(l, a)),
                  selected: _action == a,
                  onSelected: (_) => setState(() => _action = a),
                ),
              ),
          ]),
        ),
        // Date range filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(children: [
            ChoiceChip(
              avatar: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(_quickDays == -1 && _from != null && _to != null
                  ? '${f.shortDate(_from)} – ${f.shortDate(_to)}'
                  : (isEn ? 'Date Range' : 'የቀን ክልል')),
              selected: _from != null || _to != null,
              onSelected: (_) async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now.add(const Duration(days: 365)),
                  initialDateRange: _from != null && _to != null
                      ? DateTimeRange(start: _from!, end: _to!)
                      : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
                );
                if (picked != null) {
                  setState(() {
                    _from = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
                    _to = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                    _quickDays = -1;
                  });
                }
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.all),
              selected: _from == null && _to == null,
              onSelected: (_) => setState(() {
                _from = null;
                _to = null;
                _quickDays = null;
              }),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(isEn ? 'Today' : 'ዛሬ'),
              selected: _quickDays == 0,
              onSelected: (_) {
                final now = DateTime.now();
                setState(() {
                  _from = DateTime(now.year, now.month, now.day, 0, 0, 0);
                  _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  _quickDays = 0;
                });
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.last7Days),
              selected: _quickDays == 7,
              onSelected: (_) {
                final now = DateTime.now();
                setState(() {
                  _from = now.subtract(const Duration(days: 7));
                  _to = now;
                  _quickDays = 7;
                });
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.last30Days),
              selected: _quickDays == 30,
              onSelected: (_) {
                final now = DateTime.now();
                setState(() {
                  _from = now.subtract(const Duration(days: 30));
                  _to = now;
                  _quickDays = 30;
                });
              },
            ),
            if (_from != null || _to != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: isEn ? 'Clear date filter' : 'የቀን ማጣሪያ አጥፋ',
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => setState(() {
                  _from = null;
                  _to = null;
                  _quickDays = null;
                }),
              ),
            ],
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(filter.toString()),
            fetch: (page) => ref.read(adminRepositoryProvider).activityLogs(filter: filter, page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, e, _) {
              final meta = asJson(e['metadata']);
              final subject = activitySubject(l, e);
              return TrackTile(
                title: '${e['user_name'] ?? '—'} — ${activityLabel(l, '${e['action']}')}',
                subtitle: [
                  ?subject,
                  if (meta['q'] != null) l.searchedFor('${meta['q']}', asIntOr(meta['results'])),
                  f.dateTime(asDate(e['occurred_at'])),
                ].join(' · '),
                leading: ListThumb(icon: switch ('${e['entity_type']}') {
                  'mezmur' => Icons.music_note_rounded,
                  'program' => Icons.event_rounded,
                  'category' => Icons.category_rounded,
                  'book' || 'digital_book' || 'physical_book' || 'item' => Icons.menu_book_rounded,
                  'edu_lesson' || 'lesson' => Icons.school_rounded,
                  'edu_material' || 'material' => Icons.description_rounded,
                  'edu_quiz' || 'quiz' => Icons.quiz_rounded,
                  'edu_magazine' || 'magazine' => Icons.auto_stories_rounded,
                  'edu_course' || 'course' => Icons.auto_stories_outlined,
                  'edu_class' || 'class' => Icons.class_outlined,
                  'borrowing' => Icons.assignment_return_rounded,
                  'attendance' => Icons.how_to_reg_rounded,
                  _ => meta['q'] != null ? Icons.search_rounded : Icons.timeline_rounded,
                }),
                onTap: () => _activityDetails(context, e),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Administrators & roles (hierarchy enforced by the API; UI shows only what is manageable)
// =============================================================================
class AdminsScreen extends ConsumerStatefulWidget {
  const AdminsScreen({super.key});
  @override
  ConsumerState<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends ConsumerState<AdminsScreen> {
  final _ctrl = PagedListController<AdminAccount>();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    return AdminScaffold(
      title: l.admins,
      fab: me.can(Perm.adminsManage)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/admins/new').then((_) => _ctrl.refresh()),
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: Text(l.newAdmin),
            )
          : null,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: PagedListView<AdminAccount>(
            key: ValueKey(_q),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).admins(q: _q.isEmpty ? null : _q, page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, a, _) => TrackTile(
              title: a.fullName,
              subtitle: [a.phone, a.roleName ?? '', if (a.status == 'disabled') l.statusDisabled].join(' · '),
              leading: ListThumb(icon: Icons.admin_panel_settings_outlined, active: a.manageable),
              trailing: a.manageable ? null : Icon(Icons.lock_outline_rounded, size: 16, color: context.palette.faint),
              onTap: () => context.push('/admin/admins/${a.id}').then((_) => _ctrl.refresh()),
            ),
          ),
        ),
      ]),
    );
  }
}

class AdminEditorScreen extends ConsumerStatefulWidget {
  const AdminEditorScreen({super.key, this.adminId});
  final int? adminId;
  @override
  ConsumerState<AdminEditorScreen> createState() => _AdminEditorScreenState();
}

class _AdminEditorScreenState extends ConsumerState<AdminEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  int? _roleId;
  String _status = 'active';
  String _group = 'youth_adult';
  final _extra = <String>{};
  final _revoked = <String>{};
  // New administrator = an existing member (never a new account).
  int? _memberId;
  String? _memberName;
  AdminAccount? _admin;
  List<RoleModel> _roles = const [];
  List<PermissionDef> _catalog = const [];
  bool _loading = true;
  Object? _error;

  bool get _isNew => widget.adminId == null;
  bool get _editable => _isNew || (_admin?.manageable ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final results = await Future.wait([repo.roles(), repo.permissionCatalog(), if (!_isNew) repo.admin(widget.adminId!)]);
      _roles = results[0] as List<RoleModel>;
      _catalog = results[1] as List<PermissionDef>;
      if (!_isNew) {
        final a = _admin = results[2] as AdminAccount;
        _name.text = a.fullName;
        _phone.text = a.phone;
        _email.text = a.email ?? '';
        _roleId = a.roleId;
        _status = a.status;
        _group = a.memberGroup;
        _extra
          ..clear()
          ..addAll(a.extraPermissions);
        _revoked
          ..clear()
          ..addAll(a.revokedPermissions);
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Someone not allowed to manage this account may still set their OWN member group.
  bool get _self => !_isNew && _admin?.id == ref.read(currentUserProvider)?.id;

  Future<void> _save() async {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    if (!_editable && _self) {
      try {
        _admin = await repo.updateAdmin(_admin!.id, {'member_group': _group});
        if (mounted) showSnack(context, l.saved);
        setState(() => _error = null);
      } catch (e) {
        setState(() => _error = e);
      }
      return;
    }
    if (!_form.currentState!.validate() || _roleId == null) return;
    final role = _roles.where((r) => r.id == _roleId).firstOrNull;
    if (_isNew) {
      if (_memberId == null) {
        setState(() => _error = const ApiException(code: 'ADMIN_FROM_MEMBER_ONLY'));
        return;
      }
      try {
        await repo.createAdmin({'user_id': _memberId, 'role_id': _roleId, 'permissions': _extra.toList()});
        if (!mounted) return;
        showSnack(context, l.adminCreated);
        context.pop();
      } catch (e) {
        setState(() => _error = e);
      }
      return;
    }
    final body = {
      'member_group': _group,
      'full_name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'role_id': _roleId,
      'permissions': _extra.toList(),
      // Role permissions switched off for this person only (reversible).
      'revoked_permissions': _revoked.where((k) => role?.permissions.contains(k) ?? false).toList(),
      if (!_isNew) 'status': _status,
    };
    try {
      if (_isNew) {
        final r = await repo.createAdmin(body);
        if (!mounted) return;
        if (r.tempPassword != null) await showTempPassword(context, r.tempPassword!);
        if (mounted) {
          showSnack(context, l.adminCreated);
          context.pop();
        }
      } else {
        _admin = await repo.updateAdmin(_admin!.id, body);
        if (mounted) showSnack(context, l.saved);
        setState(() => _error = null);
      }
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final me = ref.watch(currentUserProvider)!;
    final role = _roles.where((r) => r.id == _roleId).firstOrNull;
    return AdminScaffold(
      title: _isNew ? l.newAdmin : l.admins,
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                if (!_editable) Padding(padding: const EdgeInsets.only(bottom: 12), child: Pill(l.notManageable, icon: Icons.lock_outline_rounded)),
                if (_isNew) ...[
                  // Administrators are chosen from the existing members; they keep their account,
                  // member ID and history and set an administrator password at their next sign-in.
                  Text(l.adminFromMemberHint, style: context.sans(12, color: context.palette.muted)),
                  const SizedBox(height: 8),
                  ListTile(
                    key: const ValueKey('admin-pick-member'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_search_rounded),
                    title: Text(_memberName ?? l.adminPickMember),
                    subtitle: _memberId == null ? null : Text('#$_memberId'),
                    trailing: TextButton(
                      onPressed: () async {
                        final sel = await pickUsers(context, multiple: false, title: l.adminPickMember);
                        if (sel == null || sel.ids.isEmpty || !mounted) return;
                        final id = sel.ids.first;
                        setState(() {
                          _memberId = id;
                          _memberName = sel.names[id] ?? '#$id';
                          _error = null;
                        });
                      },
                      child: Text(l.select),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  TextFormField(controller: _name, enabled: _editable, validator: (s) => v.text(s, min: 2, max: 150), decoration: InputDecoration(labelText: l.fullName)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phone, enabled: _editable, validator: v.phone, decoration: InputDecoration(labelText: l.phone, errorText: serverFieldError(l, _error, 'phone'))),
                  const SizedBox(height: 12),
                  TextFormField(controller: _email, enabled: _editable, validator: (s) => v.email(s, optional: true), decoration: InputDecoration(labelText: l.emailOptional)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _roleId,
                  decoration: InputDecoration(labelText: l.role),
                  items: [
                    for (final r in _roles)
                      DropdownMenuItem(value: r.id, enabled: r.assignable || r.id == _roleId, child: Text('${r.name} (${l.level} ${r.level})')),
                  ],
                  validator: (x) => x == null ? l.vRequired : null,
                  onChanged: _editable ? (x) => setState(() => _roleId = x) : null,
                ),
                const SizedBox(height: 12),
                // Administrators attend programs like members, by their member type (a new
                // administrator keeps the type they already have as a member).
                if (!_isNew) ...[
                  Text(l.memberGroup, style: context.sans(12, color: context.palette.muted, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(key: const ValueKey('admin-member-group'), spacing: 8, runSpacing: 6, children: [
                    for (final g in {...MemberGroups.keys().where((k) => k != 'children'), _group})
                      ChoiceChip(
                        label: Text(memberGroupLabel(l, g)),
                        selected: _group == g,
                        onSelected: (_editable || _self) ? (_) => setState(() => _group = g) : null,
                      ),
                  ]),
                ],
                if (_admin?.memberId != null) MemberIdBadge(_admin!.memberId!),
                if (!_isNew) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [ButtonSegment(value: 'active', label: Text(l.statusActive)), ButtonSegment(value: 'disabled', label: Text(l.statusDisabled))],
                    selected: {_status},
                    onSelectionChanged: _editable ? (s) => setState(() => _status = s.first) : null,
                  ),
                ],
                if (role != null) ...[
                  SectionHeader(title: l.rolePermissions),
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l.rolePermissionsRevokeHint, style: context.sans(12, color: context.palette.muted))),
                  // Each role permission can be reversed for this one person (and given back).
                  SettingsGroup(children: [
                    for (final p in role.permissions)
                      CheckboxListTile(
                        key: ValueKey('role-perm-$p'),
                        dense: true,
                        title: Text(permissionLabel(l, p)),
                        subtitle: Text(_revoked.contains(p) ? '${l.permissionRevoked} · $p' : p, style: context.sans(11, color: _revoked.contains(p) ? AppColors.danger : context.palette.subtle)),
                        value: !_revoked.contains(p),
                        onChanged: _editable && !_isNew && (_catalog.where((c) => c.key == p).firstOrNull?.grantable ?? false)
                            ? (x) => setState(() => x == true ? _revoked.remove(p) : _revoked.add(p))
                            : null,
                      ),
                  ]),
                ],
                SectionHeader(title: l.extraPermissions),
                SettingsGroup(children: [
                  for (final p in _catalog.where((p) => !(role?.permissions.contains(p.key) ?? false)))
                    CheckboxListTile(
                      dense: true,
                      title: Text(permissionLabel(l, p.key)),
                      subtitle: Text(p.key, style: context.sans(11, color: context.palette.subtle)),
                      value: _extra.contains(p.key),
                      // Only permissions the current admin holds can be granted (server enforces this too).
                      onChanged: _editable && p.grantable ? (x) => setState(() => x == true ? _extra.add(p.key) : _extra.remove(p.key)) : null,
                    ),
                ]),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
                const SizedBox(height: 16),
                if ((_editable || _self) && me.can(Perm.adminsManage)) FilledButton(key: const ValueKey('admin-save'), onPressed: _save, child: Text(l.save)),
                if (!_isNew && _editable && me.can(Perm.adminsManage))
                  TextButton(
                    onPressed: () async {
                      final r = await runWithProgress(context, () => ref.read(adminRepositoryProvider).resetAdminPassword(_admin!.id));
                      if (r != null && context.mounted) await showTempPassword(context, r.password, viaTelegram: r.viaTelegram);
                    },
                    child: Text(l.resetUserPassword),
                  ),
                // Back to a plain member account (member data, payments, attendance… are kept).
                if (!_isNew && _editable && !_self && me.can(Perm.adminsManage))
                  TextButton(
                    key: const ValueKey('admin-demote'),
                    onPressed: () async {
                      if (!await showConfirm(context, l.demoteConfirm(_admin!.fullName), destructive: true) || !context.mounted) return;
                      final reason = await promptText(context, title: l.demoteToMember, label: l.reason);
                      if (reason == null || !context.mounted) return;
                      final x = await runWithProgress(context, () => ref.read(adminRepositoryProvider).demoteAdmin(_admin!.id, reason: reason.trim().isEmpty ? null : reason.trim()), success: l.demoted);
                      if (x != null && context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(l.demoteToMember, style: const TextStyle(color: AppColors.danger)),
                  ),
              ]),
            ),
    );
  }
}

final _rolesProvider = FutureProvider.autoDispose<List<RoleModel>>((ref) => ref.watch(adminRepositoryProvider).roles());
final _catalogProvider = FutureProvider.autoDispose<List<PermissionDef>>((ref) => ref.watch(adminRepositoryProvider).permissionCatalog());

final _roleDepartmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).departments());

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [RoleModel? role]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: _RoleEditor(existing: role)),
    );
    if (saved == true) ref.invalidate(_rolesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    return AdminScaffold(
      title: l.roles,
      fab: me.can(Perm.adminsManage) ? FloatingActionButton.extended(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add_rounded), label: Text(l.newRole)) : null,
      body: AsyncView(
        value: ref.watch(_rolesProvider),
        onRetry: () => ref.invalidate(_rolesProvider),
        data: (roles) => ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
          for (final r in roles)
            TrackTile(
              title: r.name,
              subtitle: [
                '${l.level} ${r.level}',
                '${r.permissions.length} ${l.permissions}',
                if (r.inUse > 0) l.roleInUse('${r.inUse}'),
                if (!r.isActive) l.inactive,
              ].join(' · '),
              leading: ListThumb(icon: Icons.badge_outlined, active: r.assignable),
              trailing: r.assignable ? null : Icon(Icons.lock_outline_rounded, size: 16, color: context.palette.faint),
              onTap: r.assignable && me.can(Perm.adminsManage) ? () => _edit(context, ref, r) : null,
            ),
        ]),
      ),
    );
  }
}

class _RoleEditor extends ConsumerStatefulWidget {
  const _RoleEditor({this.existing});
  final RoleModel? existing;
  @override
  ConsumerState<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends ConsumerState<_RoleEditor> {
  final _form = GlobalKey<FormState>();
  late final _slug = TextEditingController(text: widget.existing?.slug);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _level = TextEditingController(text: '${widget.existing?.level ?? 5}');
  late final _perms = {...?widget.existing?.permissions};
  late bool _active = widget.existing?.isActive ?? true;
  late int? _department = widget.existing?.departmentId;
  final _reason = TextEditingController();
  Object? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(adminRepositoryProvider);
    try {
      final reason = _reason.text.trim().isEmpty ? null : _reason.text.trim();
      if (widget.existing == null) {
        await repo.createRole({
          'slug': _slug.text.trim(),
          'name': _name.text.trim(),
          'level': int.parse(_level.text),
          'permissions': _perms.toList(),
          'is_active': _active,
          'department_id': _department,
          'reason': ?reason,
        });
      } else {
        await repo.updateRole(widget.existing!.id, {
          'name': _name.text.trim(),
          'level': int.parse(_level.text),
          'permissions': _perms.toList(),
          'is_active': _active,
          'department_id': _department,
          'reason': ?reason,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final catalog = ref.watch(_catalogProvider).value ?? const [];
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text(widget.existing == null ? l.newRole : l.roles, style: context.serif(19)),
          const SizedBox(height: 12),
          if (widget.existing == null)
            TextFormField(
              controller: _slug,
              validator: (s) => RegExp(r'^[a-z0-9_]{2,64}$').hasMatch(s?.trim() ?? '') ? null : l.vInvalidValue,
              decoration: InputDecoration(labelText: l.roleSlug),
            ),
          const SizedBox(height: 12),
          TextFormField(controller: _name, validator: (s) => v.text(s, max: 120), decoration: InputDecoration(labelText: l.roleName)),
          const SizedBox(height: 12),
          TextFormField(controller: _level, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, min: 1, max: 999), decoration: InputDecoration(labelText: l.level)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _department,
            decoration: InputDecoration(labelText: l.roleDepartment),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l.noDepartment)),
              for (final d in ref.watch(_roleDepartmentsProvider).value ?? const <Json>[])
                DropdownMenuItem<int?>(value: asIntOr(d['id']), child: Text(departmentName(context, d), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (x) => setState(() => _department = x),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.roleActive),
            subtitle: Text(l.roleActiveHint),
            value: _active,
            onChanged: widget.existing?.isSystem ?? false ? null : (x) => setState(() => _active = x),
          ),
          // Permissions grouped by module.
          for (final group in {for (final p in catalog) p.group}) ...[
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(permissionGroupLabel(l, group), style: context.sans(13, weight: FontWeight.w700, color: AppColors.goldDark))),
            for (final p in catalog.where((p) => p.group == group))
              CheckboxListTile(
                dense: true,
                title: Text(permissionLabel(l, p.key)),
                value: _perms.contains(p.key),
                onChanged: p.grantable ? (x) => setState(() => x == true ? _perms.add(p.key) : _perms.remove(p.key)) : null,
              ),
          ],
          TextField(controller: _reason, decoration: InputDecoration(labelText: l.reason)),
          if (_error != null) Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 10),
          Row(children: [
            if (widget.existing != null && !widget.existing!.isSystem)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () async {
                  if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                  try {
                    await ref.read(adminRepositoryProvider).deleteRole(widget.existing!.id);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    setState(() => _error = e);
                  }
                },
              ),
            Expanded(child: FilledButton(onPressed: _save, child: Text(l.save))),
          ]),
        ]),
      ),
    );
  }
}

// =============================================================================
// System settings (settings.manage)
// =============================================================================
final _settingsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).settings());

class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AdminScaffold(
      title: l.systemSettings,
      body: AsyncView(
        value: ref.watch(_settingsProvider),
        onRetry: () => ref.invalidate(_settingsProvider),
        data: (s) => _SettingsForm(settings: s, onSaved: () => ref.invalidate(_settingsProvider)),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.onSaved});
  final Json settings;
  final VoidCallback onSaved;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final Json _borrow = asJson(widget.settings['borrowing.reminders']);
  late final Json _program = asJson(widget.settings['programs.reminder_defaults']);
  late final Json _retention = asJson(widget.settings['notifications.retention_days']);
  late final _daysBefore = TextEditingController(text: '${_borrow['days_before'] ?? 3}');
  late final _repeat = TextEditingController(text: '${_borrow['overdue_repeat_days'] ?? 7}');
  late final _loan = TextEditingController(text: '${_borrow['default_loan_days'] ?? 14}');
  late bool _progEnabled = _program['enabled'] != false;
  late final _progDays = TextEditingController(text: '${_program['days_before'] ?? 1}');
  late final _keep = TextEditingController(text: '${_retention['days'] ?? 365}');

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(adminRepositoryProvider);
    await runWithProgress(context, () async {
      await repo.saveSetting('borrowing.reminders', {
        'days_before': int.parse(_daysBefore.text),
        'overdue_repeat_days': int.parse(_repeat.text),
        'default_loan_days': int.parse(_loan.text),
      });
      await repo.saveSetting('programs.reminder_defaults', {'enabled': _progEnabled, 'days_before': int.parse(_progDays.text)});
      await repo.saveSetting('notifications.retention_days', {'days': int.parse(_keep.text)});
      widget.onSaved();
    }, success: context.l10n.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        SectionHeader(title: l.borrowingReminders),
        TextFormField(controller: _daysBefore, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 14), decoration: InputDecoration(labelText: l.borrowingDaysBefore)),
        const SizedBox(height: 12),
        TextFormField(controller: _repeat, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, min: 1, max: 60), decoration: InputDecoration(labelText: l.overdueRepeatDays)),
        const SizedBox(height: 12),
        TextFormField(controller: _loan, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, min: 1, max: 365), decoration: InputDecoration(labelText: l.defaultLoanDays)),
        SectionHeader(title: l.programReminderDefault),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.reminderEnabled), value: _progEnabled, onChanged: (x) => setState(() => _progEnabled = x)),
        TextFormField(controller: _progDays, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 30), decoration: InputDecoration(labelText: l.reminderDaysBefore)),
        SectionHeader(title: l.notifications),
        TextFormField(controller: _keep, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, min: 30, max: 3650), decoration: InputDecoration(labelText: l.notificationRetention)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ]),
    );
  }
}

/// "Mezmur: <title>" — what an activity was about, when it concerns a Mezmur / program / category.
String? activitySubject(AppLocalizations l, Json e) {
  final type = asStr(e['entity_type']);
  if (type == null) return null;
  final title = asStr(e['entity_title']) ?? '#${e['entity_id'] ?? ''}';
  final kind = switch (type) {
    'mezmur' => l.entityMezmur,
    'program' => l.entityProgram,
    'category' => l.entityCategory,
    'book' || 'digital_book' || 'physical_book' || 'item' => 'መጽሐፍ',
    'edu_lesson' || 'lesson' => 'ትምህርት',
    'edu_material' || 'material' => 'ማቴሪያል',
    'edu_quiz' || 'quiz' => 'ፈተና',
    'edu_magazine' || 'magazine' => 'ሰሌዳ መጽሔት',
    'edu_course' || 'course' => 'ኮርስ',
    'edu_class' || 'class' => 'ክፍል',
    'borrowing' => 'ብድር',
    'attendance' => 'አቴንዳንስ',
    _ => type,
  };
  return '$kind: $title';
}

void _activityDetails(BuildContext context, Json e) {
  final l = context.l10n;
  final f = Formatters(l, Localizations.localeOf(context).languageCode);
  final meta = asJson(e['metadata']);
  final lines = <(String, String)>[
    (l.fullName, '${e['user_name'] ?? '—'}'),
    if (e['user_phone'] != null) (l.phone, '${e['user_phone']}'),
    (l.activityDetails, activityLabel(l, '${e['action']}')),
    if (activitySubject(l, e) != null) ('', activitySubject(l, e)!),
    if (meta['q'] != null) ('', l.searchedFor('${meta['q']}', asIntOr(meta['results']))),
    for (final entry in meta.entries)
      if (entry.key != 'q' && entry.key != 'results') (entry.key, '${entry.value}'),
    ('', f.dateTime(asDate(e['occurred_at']))),
  ];
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
        Text(l.activityDetails, style: ctx.serif(19)),
        const SizedBox(height: 10),
        for (final (k, v) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: k.isEmpty
                ? SelectableText(v, style: ctx.sans(14))
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 110, child: Text(k, style: ctx.sans(12, color: ctx.palette.muted))),
                    Expanded(child: SelectableText(v, style: ctx.sans(14))),
                  ]),
          ),
      ]),
    ),
  );
}
