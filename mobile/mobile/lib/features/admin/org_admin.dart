import 'report_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/l10n/l10n.dart';
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
import '../hub/hub_screen.dart' show paymentMethodLabel;
import '../members/department_participation.dart' show ethPeriod, periodLabel, shiftPeriod;
import 'admin_widgets.dart';
import 'receipt_review_screen.dart';
import 'stage_admin.dart' show DepartmentAdminsScreen;

// =============================================================================
// Departments (departments.manage) + HR assignments (hr.manage)
// =============================================================================
final _departmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).departments());

/// A department's name in the app language (the 7 have Amharic and English names).
String departmentName(BuildContext context, Json d) =>
    Localizations.localeOf(context).languageCode == 'en' && (asStr(d['name_en'])?.isNotEmpty ?? false) ? d['name_en'] as String : '${d['name']}';

/// The 7 departments: leader, member count; HR opens one to manage its members.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    return AdminScaffold(
      title: l.departments,
      body: AsyncView(
        value: ref.watch(_departmentsProvider),
        onRetry: () => ref.invalidate(_departmentsProvider),
        data: (list) => list.isEmpty
            ? EmptyView(message: l.noDepartments, icon: Icons.account_tree_outlined)
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
                for (final d in list)
                  TrackTile(
                    title: departmentName(context, d),
                    subtitle: [
                      '${l.deptLeader}: ${asStr(asJson(d['leader'])['full_name']) ?? '—'}',
                      l.memberCount(asIntOr(d['member_count'])),
                    ].join(' · '),
                    leading: const ListThumb(icon: Icons.account_tree_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: me.can(Perm.hrManage)
                        ? () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DepartmentMembersScreen(department: d)));
                            ref.invalidate(_departmentsProvider);
                          }
                        : null,
                  ),
              ]),
      ),
    );
  }
}

/// HR: a department's members (added by multi-select) and its one leader. Children cannot be added.
class DepartmentMembersScreen extends ConsumerStatefulWidget {
  const DepartmentMembersScreen({super.key, required this.department});
  final Json department;
  @override
  ConsumerState<DepartmentMembersScreen> createState() => _DepartmentMembersScreenState();
}

class _DepartmentMembersScreenState extends ConsumerState<DepartmentMembersScreen> {
  final _ctrl = PagedListController<Json>();
  String _q = '';
  int get _id => asIntOr(widget.department['id']);

  Future<void> _addMembers() async {
    final l = context.l10n;
    final sel = await pickUsers(context, title: l.addMembers);
    if (sel == null || sel.ids.isEmpty || !mounted) return;
    await runWithProgress(context, () => ref.read(orgRepositoryProvider).addMembers(_id, memberIds: sel.ids.toList()), success: l.saved);
    await _ctrl.refresh();
  }

  Future<void> _pickLeader() async {
    final l = context.l10n;
    final sel = await pickUsers(context, multiple: false, title: l.chooseLeader);
    if (sel == null || sel.ids.isEmpty || !mounted) return;
    await runWithProgress(context, () => ref.read(orgRepositoryProvider).addMembers(_id, leaderId: sel.ids.first), success: l.saved);
    await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(orgRepositoryProvider);
    return AdminScaffold(
      title: departmentName(context, widget.department),
      actions: [
        if (ref.watch(currentUserProvider)?.can(Perm.adminsView) ?? false)
          IconButton(
            tooltip: l.deptAdmins,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DepartmentAdminsScreen(department: widget.department))),
          ),
        IconButton(tooltip: l.chooseLeader, icon: const Icon(Icons.workspace_premium_rounded), onPressed: _pickLeader),
      ],
      fab: FloatingActionButton.extended(onPressed: _addMembers, icon: const Icon(Icons.group_add_rounded), label: Text(l.addMembers)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l.leaderHint, style: context.sans(12, color: context.palette.muted)),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_q),
            controller: _ctrl,
            fetch: (page) => repo.departmentMembers(_id, q: _q.isEmpty ? null : _q, page: page),
            emptyMessage: l.noMembers,
            emptyIcon: Icons.groups_outlined,
            itemBuilder: (context, m, _) {
              final leader = m['role'] == 'leader';
              return TrackTile(
                title: '${m['full_name']}',
                subtitle: [if (m['member_id'] != null) '${m['member_id']}', if (m['phone'] != null) '${m['phone']}'].join(' · '),
                leading: ListThumb(icon: leader ? Icons.workspace_premium_rounded : Icons.person_rounded, active: leader),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Pill(leader ? l.deptLeader : l.deptMember, color: leader ? AppColors.goldDark : null),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      final uid = asIntOr(m['user_id']);
                      if (v == 'remove') {
                        if (!await showConfirm(context, l.removeMemberConfirm, destructive: true) || !context.mounted) return;
                        await runWithProgress(context, () => repo.unassign(_id, uid), success: l.saved);
                      } else {
                        await runWithProgress(context, () => repo.setRole(_id, uid, v), success: l.saved);
                      }
                      await _ctrl.refresh();
                    },
                    itemBuilder: (_) => [
                      if (!leader) PopupMenuItem(value: 'leader', child: Text(l.makeLeader)),
                      if (leader) PopupMenuItem(value: 'member', child: Text(l.makeMember)),
                      PopupMenuItem(value: 'remove', child: Text(l.remove)),
                    ],
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Payments (payments.manage)
// =============================================================================
class PaymentsAdminScreen extends ConsumerStatefulWidget {
  const PaymentsAdminScreen({super.key});
  @override
  ConsumerState<PaymentsAdminScreen> createState() => _PaymentsAdminScreenState();
}

/// Monthly contributions by Ethiopian month. The amount is the member's student / worker rate ×
/// the months covered (1-12) — it is never typed in.
class _PaymentsAdminScreenState extends ConsumerState<PaymentsAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);
  final _ctrl = PagedListController<Json>();
  final _receiptCtrl = PagedListController<Json>();
  String _receiptStatus = 'pending';
  String _period = ethPeriod(DateTime.now());
  String? _status;
  String _q = '';
  Json _meta = const {};

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _record(Json row) async {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    if (asStr(row['member_type']) == null) {
      // The rate depends on student / worker: set it on the member first.
      await showInfo(context, l.setMemberTypeFirst);
      return;
    }
    final reference = TextEditingController();
    var method = 'cash';
    var months = 1;
    final rate = asDouble(row['required'], -1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text('${row['full_name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              months == 1 ? periodLabel(ctx, _period) : '${periodLabel(ctx, _period)} – ${periodLabel(ctx, shiftPeriod(_period, months - 1))}',
              style: ctx.sans(13, color: ctx.palette.muted),
            ),
            DropdownButtonFormField<int>(
              initialValue: months,
              decoration: InputDecoration(labelText: l.paymentMonths),
              items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(l.monthsCount('$m')))],
              onChanged: (v) => setS(() => months = v ?? 1),
            ),
            const SizedBox(height: 10),
            // Computed from the member's rate — shown, not editable.
            Text(
              rate < 0 ? l.rateNotSet : '${l.amount}: ${f.money(rate * months, 'ETB')}  (${f.money(rate, 'ETB')} × $months)',
              style: ctx.sans(14, weight: FontWeight.w700, color: rate < 0 ? AppColors.danger : ctx.palette.text),
            ),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: InputDecoration(labelText: l.paymentMethod),
              items: [for (final m in ['cash', 'bank', 'telebirr', 'other']) DropdownMenuItem(value: m, child: Text(paymentMethodLabel(l, m)))],
              onChanged: (v) => setS(() => method = v ?? 'cash'),
            ),
            TextField(controller: reference, decoration: InputDecoration(labelText: l.paymentReference)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: rate < 0 ? null : () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final p = await runWithProgress(
      context,
      () => ref.read(orgRepositoryProvider).recordPayment({
        'user_id': asIntOr(row['user_id']),
        'period': _period,
        'months': months,
        'method': method,
        'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      }),
      success: l.saved,
    );
    if (p != null && mounted && await showConfirm(context, l.attachReceiptQ) && mounted) {
      final path = await pickImagePath();
      if (path != null && mounted) await runWithProgress(context, () => ref.read(orgRepositoryProvider).uploadReceipt(asIntOr(p['id']), path), success: l.uploadDone);
    }
    await _ctrl.refresh();
  }

  Future<void> _paid(Json row) async {
    final l = context.l10n;
    final pm = asJson(row['payment']);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (asStr(pm['status']) != 'verified')
            ListTile(leading: const Icon(Icons.verified_rounded, color: AppColors.success), title: Text(l.verifyPayment), onTap: () => Navigator.pop(ctx, 'verify')),
          if (asStr(pm['receipt_url']) != null) ListTile(leading: const Icon(Icons.receipt_long_rounded), title: Text(l.viewReceipt), onTap: () => Navigator.pop(ctx, 'view')),
          ListTile(leading: const Icon(Icons.add_a_photo_outlined), title: Text(l.attachReceipt), onTap: () => Navigator.pop(ctx, 'receipt')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), title: Text(l.deletePayment), onTap: () => Navigator.pop(ctx, 'delete')),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(orgRepositoryProvider);
    if (action == 'verify') {
      await runWithProgress(context, () => repo.verifyPayment(asIntOr(pm['id'])), success: l.saved);
    } else if (action == 'view') {
      await showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(asStr(pm['receipt_url'])!))));
    } else if (action == 'receipt') {
      final path = await pickImagePath();
      if (path != null && mounted) await runWithProgress(context, () => repo.uploadReceipt(asIntOr(pm['id']), path), success: l.uploadDone);
    } else if (await showConfirm(context, l.deleteConfirm, destructive: true) && mounted) {
      await runWithProgress(context, () => repo.deletePayment(asIntOr(pm['id'])), success: l.deleted);
    }
    await _ctrl.refresh();
  }

  Future<void> _approveReceipt(Json receipt) async {
    final l = context.l10n;
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final confirm = await showConfirm(
      context,
      isAm
          ? 'ይህንን የክፍያ ደረሰኝ ማጽደቅ ይፈልጋሉ? ክፍያው ተመዝግቦ የይሁንታ ማሳወቂያ ለአባሉ ይላካል።'
          : 'Approve this payment receipt? The payment will be created and confirmation sent to the member.',
    );
    if (!confirm || !mounted) return;
    final id = asIntOr(receipt['id']);
    await runWithProgress(
      context,
      () => ref.read(orgRepositoryProvider).approveReceipt(id),
      success: l.saved,
    );
    await _receiptCtrl.refresh();
    await _ctrl.refresh();
  }

  Future<void> _rejectReceipt(Json receipt) async {
    final l = context.l10n;
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reject),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAm ? 'እባክዎ ደረሰኙ ውድቅ የተደረገበትን ምክንያት ያስገቡ፡' : 'Please enter the reason for rejecting this receipt:',
                style: ctx.sans(13, color: ctx.palette.muted),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: reasonCtrl,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isAm ? 'ምክንያት' : 'Reason',
                  hintText: isAm ? 'ምክንያትዎን እዚህ ይጻፉ...' : 'Write reason here...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isAm ? 'ምክንያት ማስገባት ግዴታ ነው' : 'Reason is required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(l.reject),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final id = asIntOr(receipt['id']);
    await runWithProgress(
      context,
      () => ref.read(orgRepositoryProvider).rejectReceipt(id, reasonCtrl.text.trim()),
      success: l.saved,
    );
    await _receiptCtrl.refresh();
  }

  /// Payment settings (editable): currency, first month owed, grace days for "on time".
  Future<void> _settings() async {
    final l = context.l10n;
    final repo = ref.read(orgRepositoryProvider);
    final pol = await runWithProgress(context, () => repo.paymentPolicy());
    if (pol == null || !mounted) return;
    final currency = TextEditingController(text: asStr(pol['currency']) ?? 'ETB');
    final grace = TextEditingController(text: '${asIntOr(pol['grace_days'])}');
    String? start = asStr(pol['start_period']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(l.paymentSettings),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: currency, decoration: InputDecoration(labelText: l.currency)),
            TextField(controller: grace, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.graceDays, helperText: l.graceDaysHint, helperMaxLines: 3)),
            const SizedBox(height: 14),
            Align(alignment: AlignmentDirectional.centerStart, child: Text(l.paymentsStartFrom, style: ctx.sans(13, color: ctx.palette.muted))),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(start == null ? l.fromSignUp : periodLabel(ctx, start!), style: ctx.sans(15, weight: FontWeight.w600)),
            ),
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => setS(() => start = _period), child: Text(l.useSelectedMonth)),
              if (start != null) TextButton(onPressed: () => setS(() => start = null), child: Text(l.fromSignUp)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await runWithProgress(
      context,
      () => repo.savePaymentPolicy({'currency': currency.text.trim().isEmpty ? 'ETB' : currency.text.trim(), 'start_period': start, 'grace_days': int.tryParse(grace.text.trim()) ?? 0}),
      success: l.saved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    // Finance and Property see contributions read-only (payments.view); recording needs payments.manage.
    final canRecord = ref.watch(currentUserProvider)?.can(Perm.paymentsManage) ?? false;
    return AdminScaffold(
      title: l.monthlyPayments,
      actions: [
        IconButton(
          tooltip: l.isEn ? 'Review Receipts' : 'ደረሰኞችን ገምግም',
          icon: const Icon(Icons.mark_email_unread_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ReceiptReviewAdminScreen()),
          ),
        ),
        ReportExportButton(kind: 'contributions', filters: () => {'period': _period}),
        if (ref.watch(currentUserProvider)?.can(Perm.paymentsConfigure) ?? false) ...[
          IconButton(tooltip: l.paymentRates, icon: const Icon(Icons.price_change_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaymentRatesScreen()))),
          IconButton(tooltip: l.paymentSettings, icon: const Icon(Icons.tune_rounded), onPressed: _settings),
        ],
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        tabs: [
          Tab(text: l.monthlyPayments),
          Tab(text: isAm ? 'የደረሰኝ ማረጋገጫ' : 'Receipts Review'),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildContributionsTab(context, l, f, canRecord),
          _buildReceiptsTab(context, l, f, canRecord),
        ],
      ),
    );
  }

  Widget _buildContributionsTab(BuildContext context, AppLocalizations l, Formatters f, bool canRecord) {
    final repo = ref.read(orgRepositoryProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(children: [
          IconButton(tooltip: l.previousMonth, icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _period = shiftPeriod(_period, -1))),
          Expanded(child: Center(child: Text(periodLabel(context, _period), style: context.sans(16, weight: FontWeight.w700)))),
          IconButton(tooltip: l.nextMonth, icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => _period = shiftPeriod(_period, 1))),
        ]),
      ),
      if (_meta.isNotEmpty)
        Text(l.paymentsSummary(asIntOr(_meta['paid_count']), f.money(asDouble(_meta['total_amount']), 'ETB')), style: context.sans(12, color: context.palette.muted)),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          ChoiceChip(label: Text(l.all), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          const SizedBox(width: 6),
          ChoiceChip(label: Text(l.paid), selected: _status == 'paid', onSelected: (_) => setState(() => _status = 'paid')),
          const SizedBox(width: 6),
          ChoiceChip(label: Text(l.notPaid), selected: _status == 'unpaid', onSelected: (_) => setState(() => _status = 'unpaid')),
        ]),
      ),
      Expanded(
        child: PagedListView<Json>(
          key: ValueKey('$_period-$_status-$_q'),
          controller: _ctrl,
          fetch: (page) async {
            final r = await repo.payments(period: _period, status: _status, q: _q.isEmpty ? null : _q, page: page);
            if (page == 1 && mounted) WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _meta = r.meta));
            return r;
          },
          emptyMessage: l.noResults,
          itemBuilder: (context, row, _) {
            final pm = asJson(row['payment']);
            final paid = pm.isNotEmpty;
            final type = asStr(row['member_type']);
            return TrackTile(
              title: '${row['full_name']}',
              subtitle: [
                if (row['member_id'] != null) '${row['member_id']}',
                if (type != null) (type == 'worker' ? l.memberWorker : l.memberStudent) else l.memberTypeMissing,
                if (paid) f.money(asDouble(pm['amount']), asStr(pm['currency']) ?? 'ETB') else if (row['required'] != null) '${l.required}: ${f.money(asDouble(row['required']), 'ETB')}',
                if (paid && asIntOr(pm['months'], 1) > 1) '${periodLabel(context, '${pm['coverage_start']}')} – ${periodLabel(context, '${pm['coverage_end']}')}',
              ].join(' · '),
              leading: ListThumb(icon: paid ? Icons.check_circle_rounded : Icons.schedule_rounded, active: paid),
              trailing: paid
                  ? Pill(pm['status'] == 'verified' ? l.paymentVerified : l.paid, color: AppColors.success, icon: pm['status'] == 'verified' ? Icons.verified_rounded : null)
                  : canRecord
                      ? FilledButton.tonal(onPressed: () => _record(row), child: Text(l.recordPayment))
                      : Pill(l.notPaid, color: AppColors.danger),
              onTap: !canRecord ? null : (paid ? () => _paid(row) : () => _record(row)),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildReceiptsTab(BuildContext context, AppLocalizations l, Formatters f, bool canRecord) {
    final repo = ref.read(orgRepositoryProvider);
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            ChoiceChip(
              label: Text(l.all),
              selected: _receiptStatus == 'all',
              onSelected: (_) => setState(() => _receiptStatus = 'all'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(isAm ? 'በግምገማ ላይ' : 'Pending'),
              selected: _receiptStatus == 'pending',
              onSelected: (_) => setState(() => _receiptStatus = 'pending'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.approved),
              selected: _receiptStatus == 'approved',
              onSelected: (_) => setState(() => _receiptStatus = 'approved'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.rejected),
              selected: _receiptStatus == 'rejected',
              onSelected: (_) => setState(() => _receiptStatus = 'rejected'),
            ),
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey('receipts-$_receiptStatus'),
            controller: _receiptCtrl,
            fetch: (page) => repo.receiptList(status: _receiptStatus, page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, receipt, _) {
              final st = asStr(receipt['status']) ?? 'pending';
              final months = asIntOr(receipt['months'], 1);
              final amount = asDouble(receipt['amount']);
              final currency = asStr(receipt['currency']) ?? 'ETB';
              final startPeriod = asStr(receipt['start_period']);
              final endPeriod = asStr(receipt['end_period']);
              final memberName = asStr(receipt['user_name']) ?? asStr(receipt['full_name']) ?? 'Member';
              final memberId = asStr(receipt['member_id']);
              final reason = asStr(receipt['rejection_reason']);
              final receiptUrl = asStr(receipt['receipt_url']);

              final periodRange = startPeriod != null && endPeriod != null
                  ? (startPeriod == endPeriod
                      ? periodLabel(context, startPeriod)
                      : '${periodLabel(context, startPeriod)} – ${periodLabel(context, endPeriod)}')
                  : '$months ${isAm ? "ወራት" : "months"}';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: AppCard(
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
                                Text(memberName, style: context.sans(15, weight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  [?memberId, periodRange, f.money(amount, currency)].join(' · '),
                                  style: context.sans(12.5, color: context.palette.muted),
                                ),
                              ],
                            ),
                          ),
                          if (st == 'pending')
                            Pill(isAm ? 'በግምገማ ላይ' : 'Pending Review', color: AppColors.goldDark, icon: Icons.schedule_rounded)
                          else if (st == 'approved')
                            Pill(l.approved, color: AppColors.success, icon: Icons.verified_rounded)
                          else
                            Pill(l.rejected, color: AppColors.danger, icon: Icons.cancel_outlined),
                        ],
                      ),
                      if (asStr(receipt['note']) != null && asStr(receipt['note'])!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('${isAm ? "ማስታወሻ" : "Note"}: ${receipt['note']}', style: context.sans(12, color: context.palette.muted)),
                      ],
                      if (st == 'rejected' && reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${isAm ? "ምክንያት" : "Reason"}: $reason',
                                  style: context.sans(12, color: AppColors.danger, weight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (receiptUrl != null && receiptUrl.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.receipt_long_rounded, size: 16),
                              label: Text(l.viewReceipt),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(receiptUrl),
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (st == 'pending' && canRecord) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _rejectReceipt(receipt),
                              child: Text(l.reject),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _approveReceipt(receipt),
                              child: Text(l.approve),
                            ),
                          ],
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
    );
  }
}

/// Student / worker monthly rates with the date they take effect — editable. Recorded payments
/// keep the rate they were made at. High Admin only (payments.configure).
class PaymentRatesScreen extends ConsumerStatefulWidget {
  const PaymentRatesScreen({super.key});
  @override
  ConsumerState<PaymentRatesScreen> createState() => _PaymentRatesScreenState();
}

class _PaymentRatesScreenState extends ConsumerState<PaymentRatesScreen> {
  late Future<List<Json>> _rates = ref.read(orgRepositoryProvider).paymentRates();

  void _reload() => setState(() => _rates = ref.read(orgRepositoryProvider).paymentRates());

  Future<void> _edit([Json? existing]) async {
    final l = context.l10n;
    final amount = TextEditingController(text: existing == null ? '' : '${existing['monthly_amount']}');
    var type = asStr(existing?['member_type']) ?? 'student';
    DateTime from = Formatters.parseDateOnly(asStr(existing?['effective_from'])) ?? DateTime.now();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(existing == null ? l.addRate : l.editRate),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: [ButtonSegment(value: 'student', label: Text(l.memberStudent)), ButtonSegment(value: 'worker', label: Text(l.memberWorker))],
              selected: {type},
              onSelectionChanged: (x) => setS(() => type = x.first),
            ),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.monthlyAmountLabel)),
            const SizedBox(height: 10),
            DateTimeField(label: l.effectiveFrom, value: from, withTime: false, onChanged: (d) => setS(() => from = d ?? from)),
          ]),
          actions: [
            if (existing != null) TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: Text(l.delete, style: const TextStyle(color: AppColors.danger))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(orgRepositoryProvider);
    if (action == 'delete') {
      if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !mounted) return;
      await runWithProgress(context, () => repo.deletePaymentRate(asIntOr(existing!['id'])), success: l.deleted);
      _reload();
      return;
    }
    final value = double.tryParse(amount.text.trim());
    if (value == null) return;
    final body = {'member_type': type, 'monthly_amount': value, 'effective_from': Formatters.isoDate(from)};
    await runWithProgress(context, () => existing == null ? repo.addPaymentRate(body) : repo.updatePaymentRate(asIntOr(existing['id']), body), success: l.saved);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.paymentRates,
      fab: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: Text(l.addRate)),
      body: FutureBuilder<List<Json>>(
        future: _rates,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final rows = snap.data!;
          if (rows.isEmpty) return EmptyView(message: l.noRates, icon: Icons.price_change_outlined);
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
            for (final r in rows)
              TrackTile(
                title: '${r['member_type'] == 'worker' ? l.memberWorker : l.memberStudent} · ${f.money(asDouble(r['monthly_amount']), asStr(r['currency']) ?? 'ETB')}',
                subtitle: [l.effectiveFromDate(f.date(Formatters.parseDateOnly(asStr(r['effective_from'])))), if (asStr(r['created_by_name']) != null) '${r['created_by_name']}'].join(' · '),
                leading: ListThumb(icon: r['member_type'] == 'worker' ? Icons.work_outline_rounded : Icons.school_outlined),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: () => _edit(r),
              ),
          ]);
        },
      ),
    );
  }
}
