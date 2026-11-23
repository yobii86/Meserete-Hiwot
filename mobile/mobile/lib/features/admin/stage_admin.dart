import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../members/member_form.dart' show memberGroupLabel;
import 'admin_widgets.dart';
import 'org_admin.dart' show departmentName;
import '../../core/member_groups.dart';

final _departmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).departments());
final _rolesProvider = FutureProvider.autoDispose<List<RoleModel>>((ref) => ref.watch(adminRepositoryProvider).roles());
final _catalogProvider = FutureProvider.autoDispose<List<PermissionDef>>((ref) => ref.watch(adminRepositoryProvider).permissionCatalog());

String attendanceStatusLabel(AppLocalizations l, String? s) => switch (s) {
      'present' => l.attPresent,
      'late' => l.attLate,
      'excused' => l.attExcused,
      'absent' => l.attAbsent,
      'unmarked' => l.attUnmarked,
      _ => l.comment,
    };

// =============================================================================
// Department administrators
// =============================================================================

/// Administrators of one department: members given one or more admin roles (Super Admin only).
class DepartmentAdminsScreen extends ConsumerStatefulWidget {
  const DepartmentAdminsScreen({super.key, required this.department});
  final Json department;
  @override
  ConsumerState<DepartmentAdminsScreen> createState() => _DepartmentAdminsScreenState();
}

class _DepartmentAdminsScreenState extends ConsumerState<DepartmentAdminsScreen> {
  late Future<List<Json>> _future = _load();
  int get _id => asIntOr(widget.department['id']);
  Future<List<Json>> _load() => ref.read(stageRepositoryProvider).departmentAdmins(_id);
  void _reload() => setState(() => _future = _load());

  Future<void> _edit(int userId, String name, Set<int> current) async {
    final l = context.l10n;
    final roles = await ref.read(_rolesProvider.future);
    if (!mounted) return;
    final sel = {...current};
    final reason = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SafeArea(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text(name, style: ctx.serif(18)),
              Text(l.deptAdminRolesHint, style: ctx.sans(12, color: ctx.palette.muted)),
              const SizedBox(height: 8),
              // The department's own roles first.
              for (final r in [...roles.where((r) => r.departmentId == _id), ...roles.where((r) => r.departmentId != _id)])
                if (r.assignable || sel.contains(r.id))
                  CheckboxListTile(
                    dense: true,
                    value: sel.contains(r.id),
                    title: Text(r.name),
                    subtitle: Text('${r.permissions.length} ${l.permissions}${r.isActive ? '' : ' · ${l.inactive}'}'),
                    onChanged: r.assignable ? (v) => setS(() => v == true ? sel.add(r.id) : sel.remove(r.id)) : null,
                  ),
              TextField(controller: reason, decoration: InputDecoration(labelText: l.reason)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).setDepartmentAdminRoles(_id, userId, sel.toList(), reason: reason.text.trim().isEmpty ? null : reason.text.trim()),
      success: l.saved,
    );
    if (r != null) _reload();
  }

  Future<void> _add() async {
    final l = context.l10n;
    final picked = await pickUsers(context, multiple: false, title: l.deptAddAdmin);
    if (picked == null || picked.ids.isEmpty || !mounted) return;
    await _edit(picked.ids.first, picked.names.values.firstOrNull ?? '', {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final manage = me.can(Perm.adminsManage);
    return AdminScaffold(
      title: '${l.deptAdmins} · ${departmentName(context, widget.department)}',
      fab: manage ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(l.deptAddAdmin)) : null,
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final admins = snap.data!;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            Text(l.deptAdminsHint, style: context.sans(12, color: context.palette.muted)),
            const SizedBox(height: 8),
            if (admins.isEmpty) EmptyView(message: l.deptNoAdmins, icon: Icons.admin_panel_settings_outlined),
            for (final a in admins)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TrackTile(
                  title: '${a['full_name']}${a['member_id'] != null ? ' · ${a['member_id']}' : ''}',
                  subtitle: asJsonList(a['roles']).map((r) => '${r['name']}${r['is_active'] == false ? ' (${l.inactive})' : ''}').join(', '),
                  leading: const ListThumb(icon: Icons.admin_panel_settings_outlined, active: true),
                  onTap: manage
                      ? () => _edit(asIntOr(a['user_id']), '${a['full_name']}', asJsonList(a['roles']).map((r) => asIntOr(r['id'])).toSet())
                      : null,
                  trailing: manage
                      ? IconButton(
                          tooltip: l.deptExtraPermissions,
                          icon: const Icon(Icons.key_rounded),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExtraPermissionsScreen(userId: asIntOr(a['user_id']), name: '${a['full_name']}'))),
                        )
                      : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Individual permissions of a department administrator on top of their roles.
class ExtraPermissionsScreen extends ConsumerStatefulWidget {
  const ExtraPermissionsScreen({super.key, required this.userId, required this.name});
  final int userId;
  final String name;
  @override
  ConsumerState<ExtraPermissionsScreen> createState() => _ExtraPermissionsScreenState();
}

class _ExtraPermissionsScreenState extends ConsumerState<ExtraPermissionsScreen> {
  Set<String>? _sel;
  // Permissions of their department roles, and those reversed for this one person.
  Set<String> _fromRoles = {};
  final Set<String> _revoked = {};
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(stageRepositoryProvider).adminRolesOf(widget.userId).then((d) {
      if (!mounted) return;
      setState(() {
        _sel = asValues(d['extra_permissions'], (e) => '$e').toSet();
        _fromRoles = asValues(d['role_permissions'], (e) => '$e').toSet();
        _revoked.addAll(asValues(d['revoked_permissions'], (e) => '$e'));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = ref.watch(_catalogProvider).value ?? const <PermissionDef>[];
    return AdminScaffold(
      title: '${l.deptExtraPermissions} · ${widget.name}',
      body: _sel == null
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
              if (_fromRoles.isNotEmpty) ...[
                SectionHeader(title: l.rolePermissions),
                Text(l.rolePermissionsRevokeHint, style: context.sans(12, color: context.palette.muted)),
                for (final p in catalog.where((c) => _fromRoles.contains(c.key)))
                  CheckboxListTile(
                    dense: true,
                    title: Text(permissionLabel(l, p.key)),
                    subtitle: Text(_revoked.contains(p.key) ? '${l.permissionRevoked} · ${p.key}' : p.key, style: context.sans(10, color: _revoked.contains(p.key) ? AppColors.danger : context.palette.faint)),
                    value: !_revoked.contains(p.key),
                    onChanged: p.grantable ? (v) => setState(() => v == true ? _revoked.remove(p.key) : _revoked.add(p.key)) : null,
                  ),
                SectionHeader(title: l.deptExtraPermissions),
              ],
              Text(l.deptExtraPermissionsHint, style: context.sans(12, color: context.palette.muted)),
              for (final p in catalog.where((c) => !_fromRoles.contains(c.key)))
                CheckboxListTile(
                  dense: true,
                  title: Text(permissionLabel(l, p.key)),
                  subtitle: Text(p.key, style: context.sans(10, color: context.palette.faint)),
                  value: _sel!.contains(p.key),
                  onChanged: p.grantable ? (v) => setState(() => v == true ? _sel!.add(p.key) : _sel!.remove(p.key)) : null,
                ),
              TextField(controller: _reason, decoration: InputDecoration(labelText: l.reason)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final r = await runWithProgress(
                    context,
                    () => ref.read(stageRepositoryProvider).setExtraPermissions(widget.userId, _sel!.toList(), reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(), revoked: _revoked.toList()),
                    success: l.saved,
                  );
                  if (r != null && context.mounted) Navigator.pop(context);
                },
                child: Text(l.save),
              ),
            ]),
    );
  }
}

// =============================================================================
// Attendance: signature policy, offline conflicts and correction requests
// =============================================================================

/// HR (attendance.configure): member groups that do not sign when recorded present. Everyone else
/// signs on the taker's phone before the mark is saved.
class AttendanceSignaturePolicyScreen extends ConsumerStatefulWidget {
  const AttendanceSignaturePolicyScreen({super.key});
  @override
  ConsumerState<AttendanceSignaturePolicyScreen> createState() => _AttendanceSignaturePolicyScreenState();
}

class _AttendanceSignaturePolicyScreenState extends ConsumerState<AttendanceSignaturePolicyScreen> {
  Set<String>? _exempt;

  @override
  void initState() {
    super.initState();
    ref.read(stageRepositoryProvider).signaturePolicy().then((r) {
      if (mounted) setState(() => _exempt = asValues(r['exempt_groups'], (e) => '$e').toSet());
    }, onError: (_) {
      if (mounted) setState(() => _exempt = <String>{});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final can = ref.watch(currentUserProvider)?.can(Perm.attendanceConfigure) ?? false;
    final exempt = _exempt;
    return AdminScaffold(
      title: l.attSignaturePolicy,
      body: exempt == null
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Text(l.attSignaturePolicyHint, style: context.sans(12, color: context.palette.muted)),
              const SizedBox(height: 12),
              for (final g in MemberGroups.keys())
                CheckboxListTile(
                  key: ValueKey('sig-exempt-$g'),
                  title: Text(memberGroupLabel(l, g)),
                  subtitle: Text(exempt.contains(g) ? l.attSignatureExempt : l.attSignatureRequiredShort),
                  value: exempt.contains(g),
                  onChanged: can ? (v) => setState(() => v == true ? exempt.add(g) : exempt.remove(g)) : null,
                ),
              const SizedBox(height: 12),
              if (can)
                FilledButton(
                  onPressed: () => runWithProgress(context, () => ref.read(stageRepositoryProvider).saveSignaturePolicy(exempt.toList()), success: l.saved),
                  child: Text(l.save),
                ),
            ]),
    );
  }
}

/// HR review of offline attendance the server could not apply as captured (another taker took the
/// session meanwhile, captured after End, unsigned from an old app…). Nothing is dropped: each is
/// accepted (recorded as captured, with its signature) or rejected, always with a note, and audited.
class AttendanceConflictsScreen extends ConsumerStatefulWidget {
  const AttendanceConflictsScreen({super.key});
  @override
  ConsumerState<AttendanceConflictsScreen> createState() => _AttendanceConflictsScreenState();
}

class _AttendanceConflictsScreenState extends ConsumerState<AttendanceConflictsScreen> {
  final _ctrl = PagedListController<Json>();
  final _batchesCtrl = PagedListController<Json>();
  String _status = 'open';
  String? _batchId;
  bool _viewBatches = true;

  Future<void> _resolve(Json c, String decision) async {
    final l = context.l10n;
    final note = await promptText(context, title: decision == 'accept' ? l.attConflictAccept : l.attConflictReject, label: l.attDecisionNote, maxLines: 2, required: true);
    if (note == null || note.trim().isEmpty || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).resolveAttendanceConflict(asIntOr(c['id']), decision: decision, note: note.trim()), success: l.saved);
    if (r != null) {
      await _ctrl.refresh();
      await _batchesCtrl.refresh();
    }
  }

  Future<void> _resolveBatch(Json b, String decision) async {
    final l = context.l10n;
    final batchId = asStr(b['batch_id']);
    if (batchId == null) return;
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final actionTitle = decision == 'accept'
        ? (isAm ? 'ቡድኑን ተቀበል' : 'Accept Batch')
        : (isAm ? 'ቡድኑን አትቀበል' : 'Reject Batch');
    final note = await promptText(context, title: actionTitle, label: l.attDecisionNote, maxLines: 2, required: true);
    if (note == null || note.trim().isEmpty || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).bulkResolveAttendanceConflicts(batchId: batchId, decision: decision, note: note.trim()), success: l.saved);
    if (r != null) {
      await _batchesCtrl.refresh();
      await _ctrl.refresh();
    }
  }

  Future<void> _signature(Json c) async {
    final bytes = await runWithProgress(context, () => ref.read(stageRepositoryProvider).attendanceConflictSignature(asIntOr(c['id'])));
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c['full_name'] ?? ''}'),
        content: Container(color: Colors.white, padding: const EdgeInsets.all(8), child: Image.memory(Uint8List.fromList(bytes))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.close))],
      ),
    );
  }

  String _kind(AppLocalizations l, String? k) => switch (k) {
        'session_start' => l.attStart,
        'session_end' => l.attEnd,
        _ => l.attConflictRecord,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final canResolve = ref.watch(currentUserProvider)?.can(Perm.attendanceOverride) ?? false;
    return AdminScaffold(
      title: l.attConflicts,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(isAm ? 'በቡድን' : 'Batches'), icon: const Icon(Icons.folder_outlined, size: 16)),
                  ButtonSegment(value: false, label: Text(isAm ? 'ነጠላ' : 'Individual'), icon: const Icon(Icons.list_outlined, size: 16)),
                ],
                selected: {_viewBatches},
                onSelectionChanged: (s) => setState(() {
                  _viewBatches = s.first;
                  if (_viewBatches) {
                    _batchId = null;
                    if (_status == 'accepted' || _status == 'rejected') _status = 'resolved';
                  } else {
                    if (_status == 'resolved') _status = 'open';
                  }
                }),
              ),
              const SizedBox(width: 8),
              for (final s in _viewBatches ? const ['open', 'resolved'] : const ['open', 'accepted', 'rejected'])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(switch (s) { 'accepted' => l.approved, 'rejected' => l.rejected, 'resolved' => (isAm ? 'የተገመገሙ' : 'Resolved'), _ => l.pending }),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
                ),
            ]),
          ),
        ),
        if (_batchId != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: p.muted.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.filter_alt, size: 16, color: p.muted),
              const SizedBox(width: 6),
              Expanded(child: Text('${isAm ? "የተመረጠ ቡድን" : "Selected batch"}: ${_batchId!.length > 8 ? _batchId!.substring(0, 8) : _batchId}...', style: context.sans(12, color: p.text))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _batchId = null), tooltip: isAm ? 'ሁሉንም አሳይ' : 'Show all'),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(l.attConflictsHint, style: context.sans(12, color: p.muted)),
        ),
        Expanded(
          child: _viewBatches
              ? PagedListView<Json>(
                  key: ValueKey('batches-$_status'),
                  controller: _batchesCtrl,
                  fetch: (page) => ref.read(stageRepositoryProvider).attendanceConflictBatches(status: _status, page: page),
                  emptyMessage: l.attConflictsEmpty,
                  emptyIcon: Icons.cloud_done_outlined,
                  separator: const SizedBox(height: 8),
                  itemBuilder: (context, b, _) {
                    final total = asIntOr(b['total_conflicts'], 0);
                    final open = asIntOr(b['open_count'], 0);
                    final accepted = asIntOr(b['accepted_count'], 0);
                    final rejected = asIntOr(b['rejected_count'], 0);
                    return AppCard(
                      key: ValueKey('batch-${b['batch_id']}'),
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text('${b['program_title'] ?? ''}', style: context.serif(15, color: p.text)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: open > 0 ? AppColors.warning.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              open > 0 ? (isAm ? '$open ክፍት' : '$open open') : (isAm ? 'የተገመገመ' : 'Resolved'),
                              style: context.sans(11, weight: FontWeight.w600, color: open > 0 ? AppColors.warning : AppColors.success),
                            ),
                          ),
                        ]),
                        Text(
                          [
                            if (asStr(b['occurrence_date']) != null) f.date(Formatters.parseDateOnly(asStr(b['occurrence_date']))),
                            isAm ? '$total አባላት' : '$total members',
                          ].join(' · '),
                          style: context.sans(12, color: p.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          errorText(l, ApiException(code: asStr(b['primary_code']) ?? ApiException.unknown)),
                          style: context.sans(12, color: AppColors.danger),
                        ),
                        Text('${l.attSubmittedBy}: ${b['submitted_by_name'] ?? '—'}', style: context.sans(11, color: p.muted)),
                        if (accepted > 0 || rejected > 0)
                          Text(
                            isAm ? 'ውጤት: $accepted ተቀባይነት አግኝቷል · $rejected አልተቀበለም' : 'Status: $accepted accepted · $rejected rejected',
                            style: context.sans(11, color: p.muted),
                          ),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _batchId = asStr(b['batch_id']);
                              _viewBatches = false;
                            }),
                            icon: const Icon(Icons.people_alt_outlined, size: 18),
                            label: Text(isAm ? 'አባላትን አሳይ' : 'Inspect members'),
                          ),
                          const Spacer(),
                          if (open > 0 && canResolve) ...[
                            TextButton(
                              onPressed: () => _resolveBatch(b, 'reject'),
                              child: Text(isAm ? 'ሁሉንም አትቀበል' : 'Reject all', style: const TextStyle(color: AppColors.danger)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _resolveBatch(b, 'accept'),
                              child: Text(isAm ? 'ሁሉንም ተቀበል' : 'Accept all'),
                            ),
                          ],
                        ]),
                      ]),
                    );
                  },
                )
              : PagedListView<Json>(
                  key: ValueKey('conflicts-$_status-$_batchId'),
                  controller: _ctrl,
                  fetch: (page) => ref.read(stageRepositoryProvider).attendanceConflicts(status: _status, batchId: _batchId, page: page),
                  emptyMessage: l.attConflictsEmpty,
                  emptyIcon: Icons.cloud_done_outlined,
                  separator: const SizedBox(height: 8),
                  itemBuilder: (context, c, _) {
                    final captured = DateTime.tryParse(asStr(c['captured_at']) ?? '')?.toLocal();
                    final payload = asJson(c['payload']);
                    return AppCard(
                      key: ValueKey('conflict-${c['id']}'),
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['full_name'] == null ? _kind(l, asStr(c['kind'])) : '${c['full_name']}', style: context.serif(15, color: p.text)),
                        Text(
                          [
                            '${c['program_title'] ?? ''}',
                            if (asStr(c['occurrence_date']) != null) f.date(Formatters.parseDateOnly(asStr(c['occurrence_date']))),
                          ].join(' · '),
                          style: context.sans(12, color: p.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            _kind(l, asStr(c['kind'])),
                            if (asStr(payload['status']) != null) attendanceStatusLabel(l, asStr(payload['status'])),
                            if (captured != null) l.attCapturedAt(f.dateTime(captured)),
                          ].join(' · '),
                          style: context.sans(13, weight: FontWeight.w600),
                        ),
                        Text(errorText(l, ApiException(code: asStr(c['code']) ?? ApiException.unknown)), style: context.sans(12, color: AppColors.danger)),
                        Text('${l.attSubmittedBy}: ${c['submitted_by_name'] ?? '—'}', style: context.sans(11, color: p.muted)),
                        if (c['status'] != 'open') Text('${c['resolved_by_name'] ?? ''} · ${c['resolution_note'] ?? ''}', style: context.sans(11, color: p.muted)),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (c['has_signature'] == true) TextButton.icon(onPressed: () => _signature(c), icon: const Icon(Icons.draw_rounded, size: 18), label: Text(l.attSigned)),
                          const Spacer(),
                          if (c['status'] == 'open' && canResolve) ...[
                            TextButton(onPressed: () => _resolve(c, 'reject'), child: Text(l.attConflictReject, style: const TextStyle(color: AppColors.danger))),
                            const SizedBox(width: 8),
                            FilledButton(onPressed: () => _resolve(c, 'accept'), child: Text(l.attConflictAccept)),
                          ],
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// Comments and correction requests; reviewers approve (applies the status) or reject.
class AttendanceCorrectionsScreen extends ConsumerStatefulWidget {
  const AttendanceCorrectionsScreen({super.key});
  @override
  ConsumerState<AttendanceCorrectionsScreen> createState() => _AttendanceCorrectionsScreenState();
}

class _AttendanceCorrectionsScreenState extends ConsumerState<AttendanceCorrectionsScreen> {
  final _ctrl = PagedListController<Json>();
  String _status = 'pending';

  Future<void> _review(Json c, String decision) async {
    final l = context.l10n;
    final note = await promptText(context, title: decision == 'approve' ? l.approve : l.reject, label: l.notes, maxLines: 2);
    if (note == null || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).reviewCorrection(asIntOr(c['id']), decision: decision, note: note.trim().isEmpty ? null : note.trim()), success: l.saved);
    if (r != null) await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final canReview = ref.watch(currentUserProvider)?.can(Perm.attendanceCorrectionApprove) ?? false;
    return AdminScaffold(
      title: l.attCorrections,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            for (final s in const ['pending', 'approved', 'rejected'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(switch (s) { 'approved' => l.approved, 'rejected' => l.rejected, _ => l.pending }),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(stageRepositoryProvider).corrections(status: _status, page: page),
            emptyMessage: l.noResults,
            emptyIcon: Icons.rule_rounded,
            separator: const SizedBox(height: 8),
            itemBuilder: (context, c, _) => AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['full_name']}', style: context.serif(15, color: p.text)),
                Text('${c['program_title']} · ${f.date(Formatters.parseDateOnly(asStr(c['occurrence_date'])))}', style: context.sans(12, color: p.muted)),
                const SizedBox(height: 6),
                Text(
                  c['requested_status'] == null
                      ? '${l.comment} · ${attendanceStatusLabel(l, asStr(c['original_status']))}'
                      : '${attendanceStatusLabel(l, asStr(c['original_status']))} → ${attendanceStatusLabel(l, asStr(c['requested_status']))}',
                  style: context.sans(13, weight: FontWeight.w600),
                ),
                Text('${c['reason']}', style: context.sans(13)),
                Text('${l.requestedBy}: ${c['requested_by_name'] ?? '—'}', style: context.sans(11, color: p.muted)),
                if (c['status'] != 'pending')
                  Text('${c['reviewed_by_name'] ?? ''} · ${c['review_note'] ?? ''} → ${attendanceStatusLabel(l, asStr(c['final_status']))}', style: context.sans(11, color: p.muted)),
                if (c['status'] == 'pending' && canReview)
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => _review(c, 'reject'), child: Text(l.reject, style: const TextStyle(color: AppColors.danger))),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _review(c, 'approve'), child: Text(l.approve)),
                  ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Comment / correction request for one member at one occurrence (never changes attendance
/// directly). Returns true when sent.
Future<bool> requestAttendanceCorrection(BuildContext context, WidgetRef ref, {required int programId, required int userId, required String name, String? date}) async {
  final l = context.l10n;
  String? requested;
  TimeOfDay? arrived;
  final reason = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text(name, style: ctx.serif(18)),
            Text(l.attCorrectionHint, style: ctx.sans(12, color: ctx.palette.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in const [null, 'present', 'excused', 'absent'])
                ChoiceChip(label: Text(s == null ? l.comment : attendanceStatusLabel(l, s)), selected: requested == s, onSelected: (_) => setS(() => requested = s)),
            ]),
            // Attended: when the member actually arrived (counted from the session's start).
            if (requested == 'present' && date != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(l.attArrivedAt),
                subtitle: Text(arrived == null ? l.optional : arrived!.format(ctx)),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: arrived ?? TimeOfDay.now());
                  if (t != null) setS(() => arrived = t);
                },
              ),
            const SizedBox(height: 10),
            TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: l.reason)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => reason.text.trim().length >= 3 ? Navigator.pop(ctx, true) : null, child: Text(l.send)),
          ]),
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final r = await runWithProgress(
    context,
    () => ref.read(stageRepositoryProvider).requestCorrection(
          programId,
          userId,
          date: date,
          requestedStatus: requested,
          attendedAt: requested == 'present' && arrived != null && date != null
              ? (() {
                  final d = Formatters.parseDateOnly(date)!;
                  return DateTime(d.year, d.month, d.day, arrived!.hour, arrived!.minute).toUtc().toIso8601String();
                })()
              : null,
          reason: reason.text.trim(),
        ),
    success: l.attCorrectionSent,
  );
  return r != null;
}

// =============================================================================
// Property: department requests and direct-borrowing rules
// =============================================================================

String propertyStatusText(AppLocalizations l, String? s) => switch (s) {
      'draft' => l.propDraft,
      'submitted' => l.propSubmitted,
      'under_review' => l.propUnderReview,
      'approved' => l.approved,
      'rejected' => l.rejected,
      'issued' => l.propIssued,
      'partially_issued' => l.propPartiallyIssued,
      'returned' => l.propReturned,
      'cancelled' => l.selStatusCancelled,
      _ => s ?? '',
    };

Color propertyStatusColor(String? s) => switch (s) {
      'approved' || 'issued' || 'returned' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      _ => AppColors.goldDark,
    };

class PropertyRequestsScreen extends ConsumerStatefulWidget {
  const PropertyRequestsScreen({super.key});
  @override
  ConsumerState<PropertyRequestsScreen> createState() => _PropertyRequestsScreenState();
}

class _PropertyRequestsScreenState extends ConsumerState<PropertyRequestsScreen> {
  final _ctrl = PagedListController<Json>();
  String? _status;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider)!;
    return AdminScaffold(
      title: l.propRequests,
      fab: me.can(Perm.propertyRequest)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: Text(l.propNew),
              onPressed: () async {
                final r = await Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => const PropertyRequestEditor()));
                if (r != null) await _ctrl.refresh();
              },
            )
          : null,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final s in const [null, 'submitted', 'under_review', 'approved', 'partially_issued', 'issued', 'returned', 'rejected'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(s == null ? l.all : propertyStatusText(l, s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey('$_status|$_q'),
            controller: _ctrl,
            fetch: (page) => ref.read(stageRepositoryProvider).propertyRequests(status: _status, q: _q.isEmpty ? null : _q, page: page),
            emptyMessage: l.propNone,
            emptyIcon: Icons.inventory_outlined,
            separator: const SizedBox(height: 8),
            itemBuilder: (context, r, _) => TrackTile(
              title: '${r['item_name'] ?? '—'}${r['quantity'] != null ? ' × ${r['quantity']}' : ''}',
              subtitle: [departmentName(context, asJson(r['department'])), f.date(asDate(r['created_at']))].join(' · '),
              leading: const ListThumb(icon: Icons.inventory_outlined),
              trailing: Pill(propertyStatusText(l, asStr(r['status'])), color: propertyStatusColor(asStr(r['status']))),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PropertyRequestDetail(id: asIntOr(r['id']))));
                await _ctrl.refresh();
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class PropertyRequestEditor extends ConsumerStatefulWidget {
  const PropertyRequestEditor({super.key});
  @override
  ConsumerState<PropertyRequestEditor> createState() => _PropertyRequestEditorState();
}

class _PropertyRequestEditorState extends ConsumerState<PropertyRequestEditor> {
  int? _dept;
  ItemModel? _item;
  final _itemName = TextEditingController();
  final _qty = TextEditingController();
  final _purpose = TextEditingController();
  DateTime? _needed;
  DateTime? _returnOn;

  Future<void> _pickItem() async {
    final l = context.l10n;
    final page = await runWithProgress(context, () => ref.read(adminRepositoryProvider).items());
    if (page == null || !mounted) return;
    final picked = await showModalBottomSheet<ItemModel>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final i in page.items)
            ListTile(title: Text(i.name), subtitle: Text('${i.code} · ${l.availableCount('${i.available}')}'), onTap: () => Navigator.pop(ctx, i)),
        ]),
      ),
    );
    if (picked != null) setState(() => _item = picked);
  }

  Future<void> _save(bool draft) async {
    final l = context.l10n;
    if (_dept == null || _purpose.text.trim().length < 3 || (_item == null && _itemName.text.trim().isEmpty)) return showSnack(context, l.vRequired);
    final body = {
      'department_id': _dept,
      if (_item != null) 'item_id': _item!.id,
      if (_item == null) 'item_name': _itemName.text.trim(),
      if (_qty.text.trim().isNotEmpty) 'quantity': int.tryParse(_qty.text.trim()),
      'purpose': _purpose.text.trim(),
      if (_needed != null) 'needed_on': Formatters.isoDate(_needed!),
      if (_returnOn != null) 'return_on': Formatters.isoDate(_returnOn!),
      'draft': draft,
    };
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).createPropertyRequest(body), success: l.saved);
    if (r != null && mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final all = ref.watch(_departmentsProvider).value ?? const <Json>[];
    // Department administrators request for their own departments; admin accounts for any.
    final mine = me.isMemberStaff ? all.where((d) => me.adminDepartments.any((x) => asIntOr(x['id']) == asIntOr(d['id']))).toList() : all;
    if (_dept == null && mine.length == 1) _dept = asIntOr(mine.first['id']);
    return AdminScaffold(
      title: l.propNew,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _dept,
          decoration: InputDecoration(labelText: l.department),
          items: [for (final d in mine) DropdownMenuItem(value: asIntOr(d['id']), child: Text(departmentName(context, d), overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _dept = v),
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(_item?.name ?? l.propPickItem),
          subtitle: _item == null ? Text(l.propPickItemHint) : Text(l.availableCount('${_item!.available}')),
          trailing: _item == null ? const Icon(Icons.chevron_right_rounded) : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _item = null)),
          onTap: _pickItem,
        ),
        if (_item == null) TextField(controller: _itemName, decoration: InputDecoration(labelText: l.propItemName)),
        const SizedBox(height: 10),
        TextField(controller: _qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.propQuantityOptional)),
        const SizedBox(height: 10),
        TextField(controller: _purpose, maxLines: 3, decoration: InputDecoration(labelText: l.propPurpose)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DateTimeField(label: l.propNeededOn, value: _needed, withTime: false, clearable: true, onChanged: (d) => setState(() => _needed = d))),
          const SizedBox(width: 8),
          Expanded(child: DateTimeField(label: l.propReturnOn, value: _returnOn, withTime: false, clearable: true, onChanged: (d) => setState(() => _returnOn = d))),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _save(true), child: Text(l.propSaveDraft))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => _save(false), child: Text(l.send))),
        ]),
      ]),
    );
  }
}

class PropertyRequestDetail extends ConsumerStatefulWidget {
  const PropertyRequestDetail({super.key, required this.id});
  final int id;
  @override
  ConsumerState<PropertyRequestDetail> createState() => _PropertyRequestDetailState();
}

class _PropertyRequestDetailState extends ConsumerState<PropertyRequestDetail> {
  late Future<Json> _future = ref.read(stageRepositoryProvider).propertyRequest(widget.id);
  void _reload() => setState(() => _future = ref.read(stageRepositoryProvider).propertyRequest(widget.id));

  Future<void> _act(String action, {bool note = false, bool noteRequired = false}) async {
    final l = context.l10n;
    String? text;
    if (note) {
      text = await promptText(context, title: propertyStatusText(l, action), label: noteRequired ? l.reason : l.notes, maxLines: 2);
      if (text == null || (noteRequired && text.trim().length < 3) || !mounted) return;
    }
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).propertyAction(widget.id, action, note: text?.trim().isEmpty ?? true ? null : text!.trim()), success: l.saved);
    if (r != null) _reload();
  }

  Future<void> _issue(Json r, {required bool back}) async {
    final l = context.l10n;
    final qty = await promptText(context, title: back ? l.propReturn : l.propIssue, label: l.quantity, initial: '');
    if (qty == null || !mounted) return;
    final n = int.tryParse(qty.trim());
    final repo = ref.read(stageRepositoryProvider);
    final out = await runWithProgress(context, () => back ? repo.returnProperty(widget.id, quantity: n) : repo.issueProperty(widget.id, quantity: n), success: l.saved);
    if (out != null) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider)!;
    final reviewer = me.can(Perm.propertyReview);
    return AdminScaffold(
      title: l.propRequests,
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final r = snap.data!;
          final s = asStr(r['status']);
          final item = asJson(r['item']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${r['item_name'] ?? '—'}', style: context.serif(18, color: p.text))),
                  Pill(propertyStatusText(l, s), color: propertyStatusColor(s)),
                ]),
                const SizedBox(height: 6),
                Text(departmentName(context, asJson(r['department'])), style: context.sans(13)),
                if (r['quantity'] != null) Text('${l.quantity}: ${r['quantity']} · ${l.propIssued}: ${r['issued_quantity']} · ${l.propReturned}: ${r['returned_quantity']}', style: context.sans(13)),
                if (item.isNotEmpty) Text(l.availableCount('${asIntOr(item['available_quantity'])}'), style: context.sans(12, color: p.muted)),
                const SizedBox(height: 6),
                Text('${r['purpose']}', style: context.sans(13)),
                if (r['needed_on'] != null) Text('${l.propNeededOn}: ${f.date(Formatters.parseDateOnly(asStr(r['needed_on'])))}', style: context.sans(12, color: p.muted)),
                if (r['return_on'] != null) Text('${l.propReturnOn}: ${f.date(Formatters.parseDateOnly(asStr(r['return_on'])))}', style: context.sans(12, color: p.muted)),
                if (r['review_note'] != null) Text('${l.notes}: ${r['review_note']}', style: context.sans(12, color: p.muted)),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (s == 'draft') FilledButton(onPressed: () => _act('submit'), child: Text(l.send)),
              if (reviewer && s == 'submitted') OutlinedButton(onPressed: () => _act('review'), child: Text(l.propUnderReview)),
              if (reviewer && (s == 'submitted' || s == 'under_review')) FilledButton(onPressed: () => _act('approve', note: true), child: Text(l.approve)),
              if (reviewer && (s == 'submitted' || s == 'under_review'))
                OutlinedButton(onPressed: () => _act('reject', note: true, noteRequired: true), child: Text(l.reject, style: const TextStyle(color: AppColors.danger))),
              if (reviewer && (s == 'approved' || s == 'partially_issued')) FilledButton(onPressed: () => _issue(r, back: false), child: Text(l.propIssue)),
              if (reviewer && (s == 'issued' || s == 'partially_issued')) OutlinedButton(onPressed: () => _issue(r, back: true), child: Text(l.propReturn)),
              if (['draft', 'submitted', 'under_review', 'approved'].contains(s)) TextButton(onPressed: () => _act('cancel'), child: Text(l.cancel)),
            ]),
            SectionHeader(title: l.history),
            for (final e in asJsonList(r['events']))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, size: 18),
                title: Text('${propertyStatusText(l, asStr(e['to_status']))}${e['quantity'] != null ? ' · ${e['quantity']}' : ''}'),
                subtitle: Text([f.dateTime(asDate(e['created_at'])), if (e['actor_name'] != null) '${e['actor_name']}', if (e['note'] != null) '${e['note']}'].join(' · ')),
              ),
          ]);
        },
      ),
    );
  }
}

/// Which members can borrow directly and whether approval is needed (borrowing.configure).
class DirectBorrowingPolicyScreen extends ConsumerStatefulWidget {
  const DirectBorrowingPolicyScreen({super.key});
  @override
  ConsumerState<DirectBorrowingPolicyScreen> createState() => _DirectBorrowingPolicyScreenState();
}

class _DirectBorrowingPolicyScreenState extends ConsumerState<DirectBorrowingPolicyScreen> {
  Set<String> _groups = {};
  bool _approval = false;
  final _maxQty = TextEditingController();
  final _maxDays = TextEditingController();
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    ref.read(stageRepositoryProvider).directPolicy().then((p) {
      _groups = asValues(p['member_groups'], (e) => '$e').toSet();
      _approval = p['approval_required'] == true;
      _maxQty.text = p['max_quantity'] == null ? '' : '${p['max_quantity']}';
      _maxDays.text = p['max_days'] == null ? '' : '${p['max_days']}';
      if (mounted) setState(() => _loading = false);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final can = ref.watch(currentUserProvider)?.can(Perm.borrowingConfigure) ?? false;
    return AdminScaffold(
      title: l.borrowDirectPolicy,
      body: _error != null
          ? Center(child: Text(errorText(l, _error!)))
          : _loading
              ? const LoadingView()
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                  Text(l.borrowDirectPolicyHint, style: context.sans(12, color: context.palette.muted)),
                  const SizedBox(height: 10),
                  Text(l.memberGroup, style: context.sans(13, weight: FontWeight.w600)),
                  Wrap(spacing: 6, children: [
                    for (final g in {...MemberGroups.keys(), ..._groups})
                      FilterChip(label: Text(memberGroupLabel(l, g)), selected: _groups.contains(g), onSelected: can ? (v) => setState(() => v ? _groups.add(g) : _groups.remove(g)) : null),
                  ]),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.borrowApprovalRequired), subtitle: Text(l.borrowApprovalHint), value: _approval, onChanged: can ? (v) => setState(() => _approval = v) : null),
                  TextField(controller: _maxQty, enabled: can, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.borrowMaxQuantity, helperText: l.borrowPerItemHint)),
                  const SizedBox(height: 10),
                  TextField(controller: _maxDays, enabled: can, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.borrowMaxDays, helperText: l.borrowPerItemHint)),
                  const SizedBox(height: 16),
                  if (can)
                    FilledButton(
                      onPressed: () => runWithProgress(
                        context,
                        () => ref.read(stageRepositoryProvider).saveDirectPolicy({
                          'member_groups': _groups.toList(),
                          'approval_required': _approval,
                          'max_quantity': int.tryParse(_maxQty.text.trim()),
                          'max_days': int.tryParse(_maxDays.text.trim()),
                        }),
                        success: l.saved,
                      ),
                      child: Text(l.save),
                    ),
                ]),
    );
  }
}

// =============================================================================
// Program occurrences: cancel / reschedule / restore one date
// =============================================================================
class ProgramOccurrencesScreen extends ConsumerStatefulWidget {
  const ProgramOccurrencesScreen({super.key, required this.programId});
  final int programId;
  @override
  ConsumerState<ProgramOccurrencesScreen> createState() => _ProgramOccurrencesScreenState();
}

class _ProgramOccurrencesScreenState extends ConsumerState<ProgramOccurrencesScreen> {
  late Future<List<Json>> _future = _load();

  Future<List<Json>> _load() {
    final now = DateTime.now();
    return ref.read(adminRepositoryProvider).occurrences(
          widget.programId,
          from: Formatters.isoDate(now.subtract(const Duration(days: 30))),
          to: Formatters.isoDate(now.add(const Duration(days: 120))),
        );
  }

  Future<void> _change(Json o) async {
    final l = context.l10n;
    final date = asStr(o['date'])!;
    final cancelled = o['cancelled'] == true;
    final suspended = o['suspended'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!cancelled && !suspended) ListTile(leading: const Icon(Icons.pause_circle_outline_rounded, color: Colors.orange), title: Text(l.isEn ? 'Suspend Occurrence' : 'የዕለቱን ፕሮግራም አግድ'), onTap: () => Navigator.pop(ctx, 'suspended')),
          if (!cancelled && !suspended) ListTile(leading: const Icon(Icons.event_busy_rounded, color: AppColors.danger), title: Text(l.occCancel), onTap: () => Navigator.pop(ctx, 'cancelled')),
          if (!cancelled && !suspended) ListTile(leading: const Icon(Icons.schedule_rounded), title: Text(l.occReschedule), onTap: () => Navigator.pop(ctx, 'rescheduled')),
          if (cancelled || suspended || o['rescheduled'] == true) ListTile(leading: const Icon(Icons.restore_rounded), title: Text(l.occRestore), onTap: () => Navigator.pop(ctx, 'restore')),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    DateTime? start;
    DateTime? end;
    if (action == 'rescheduled') {
      start = asDate(o['starts_at'])?.toLocal();
      end = asDate(o['ends_at'])?.toLocal();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(l.occReschedule),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DateTimeField(label: l.startsAt, value: start, onChanged: (d) => setS(() => start = d)),
              const SizedBox(height: 8),
              DateTimeField(label: l.endsAt, value: end, onChanged: (d) => setS(() => end = d)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
            ],
          ),
        ),
      );
      if (ok != true || start == null || end == null || !mounted) return;
    }
    String? reason;
    if (action != 'restore') {
      final title = action == 'cancelled'
          ? l.occCancel
          : (action == 'suspended'
              ? (l.isEn ? 'Suspend Occurrence' : 'የዕለቱን ፕሮግራም አግድ')
              : l.occReschedule);
      reason = await promptText(context, title: title, label: l.reason, maxLines: 2, required: true);
      if (reason == null || reason.trim().isEmpty || !mounted) return;
    }
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).setOccurrence(widget.programId, date, {
        'action': action,
        if (start != null) 'starts_at': start!.toUtc().toIso8601String(),
        if (end != null) 'ends_at': end!.toUtc().toIso8601String(),
        'reason': ?reason?.trim(),
      }),
      success: l.saved,
    );
    if (r != null) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.manageOccurrences,
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
          if (!snap.hasData) return const LoadingView();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Text(l.occHint, style: context.sans(12, color: p.muted)),
            const SizedBox(height: 8),
            for (final o in snap.data!) ...[
              () {
                final isCancelled = o['cancelled'] == true;
                final isSuspended = o['suspended'] == true || asStr(o['status']) == 'suspended';
                final isRescheduled = o['rescheduled'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCancelled
                        ? Icons.event_busy_rounded
                        : (isSuspended
                            ? Icons.pause_circle_outline_rounded
                            : (isRescheduled ? Icons.schedule_rounded : Icons.event_rounded)),
                    color: isCancelled
                        ? AppColors.danger
                        : (isSuspended ? Colors.orange : null),
                  ),
                  title: Text(
                    f.date(Formatters.parseDateOnly(asStr(o['date'])), withWeekday: true),
                    style: TextStyle(
                      decoration: (isCancelled || isSuspended) ? TextDecoration.lineThrough : null,
                      color: isSuspended ? Colors.orange.shade800 : null,
                    ),
                  ),
                  subtitle: Text([
                    if (isSuspended) (l.isEn ? 'Suspended' : 'የታገደ'),
                    if (isCancelled) l.occCancelled,
                    if (isRescheduled) '→ ${f.dateTime(asDate(o['starts_at']))}',
                    if (asStr(o['reason']) != null) '${o['reason']}',
                    if (o['closed'] == true && !isCancelled && !isSuspended) l.attClosed,
                  ].join(' · ')),
                  trailing: const Icon(Icons.more_vert_rounded),
                  onTap: () => _change(o),
                );
              }(),
            ],
          ]);
        },
      ),
    );
  }
}
