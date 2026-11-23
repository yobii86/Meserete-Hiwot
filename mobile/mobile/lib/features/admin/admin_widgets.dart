import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/network/api_exception.dart';
import '../../services/offline_pack.dart';
import '../../core/l10n/l10n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/library.dart';
import '../../models/user.dart';
import '../../core/providers.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/ethiopian_date_picker.dart';
import '../../widgets/states.dart';
import 'member_filters.dart';

export 'audio_picker.dart' show pickAudioPath;

/// Admin page scaffold (same identity as the user app, optimised for management).
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({super.key, required this.title, required this.body, this.actions, this.fab, this.bottom});
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    return PatternScaffold(
        appBar: AppBar(title: Text(title), actions: actions, bottom: bottom),
        floatingActionButton: fab,
        body: Column(
          children: [
            if (!online) const OfflineBanner(),
            Expanded(child: body),
          ],
        ),
    );
  }
}

/// Search field with debounce, used above admin lists.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onChanged, this.hint});
  final ValueChanged<String> onChanged;
  final String? hint;
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: (v) {
          _t?.cancel();
          _t = Timer(const Duration(milliseconds: 350), () => widget.onChanged(v.trim()));
        },
        decoration: InputDecoration(
          hintText: widget.hint ?? context.l10n.search,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: context.palette.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: context.palette.border)),
        ),
      );
}

/// Date + time picker field (values are local DateTimes).
class DateTimeField extends StatelessWidget {
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged, this.withTime = true, this.errorText, this.clearable = false, this.pastOnly = false});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;
  final String? errorText;
  final bool clearable;

  /// Dates that cannot be in the future (birth, baptism, borrowed on…). Everything else —
  /// program dates, deadlines, due dates, meetings — may be (it used to be capped at today).
  final bool pastOnly;

  Future<void> _pick(BuildContext context) async {
    final base = value ?? DateTime.now();
    final last = pastOnly ? DateTime.now() : DateTime(DateTime.now().year + 20, 12, 31);
    final d = await showEthiopianDatePicker(context: context, initialDate: base.isAfter(last) ? last : base, firstDate: DateTime(1900), lastDate: last);
    if (d == null || !context.mounted) return;
    if (!withTime) return onChanged(DateTime(d.year, d.month, d.day));
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return;
    onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final f = Formatters(context.l10n, Localizations.localeOf(context).languageCode);
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: clearable && value != null ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => onChanged(null)) : const Icon(Icons.event_rounded, color: AppColors.gold),
        ),
        child: Text(value == null ? '—' : (withTime ? f.dateTime(value) : f.date(value)), style: context.sans(14)),
      ),
    );
  }
}

/// Pick an image (gallery) or an audio file and return its local path.
Future<String?> pickImagePath() async => (await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 88))?.path;


/// Image preview + upload/remove buttons for an entity that already exists.
class ImageUploadTile extends StatelessWidget {
  const ImageUploadTile({super.key, required this.label, this.url, required this.onUpload, this.onRemove, this.enabled = true});
  final String label;
  final String? url;
  final Future<void> Function(String path) onUpload;
  final Future<void> Function()? onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        SizedBox(width: 72, height: 72, child: CoverImage(url: url, radius: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.sans(14, weight: FontWeight.w600)),
            if (!enabled) Text(l.saveFirstToUpload, style: context.sans(12, color: context.palette.muted)),
            Wrap(spacing: 4, children: [
              TextButton.icon(
                onPressed: !enabled
                    ? null
                    : () async {
                        final path = await pickImagePath();
                        if (path != null && context.mounted) await runWithProgress(context, () => onUpload(path), success: l.uploadDone);
                      },
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(l.uploadImage),
              ),
              if (url != null && onRemove != null)
                TextButton(onPressed: () => runWithProgress(context, onRemove!), child: Text(l.removeImage, style: const TextStyle(color: AppColors.danger))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// User selection (single / multiple / all-matching-filter) for bulk actions.
// ---------------------------------------------------------------------------
class UserSelection {
  const UserSelection({this.ids = const {}, this.allMatching = false, this.filter = const {}, this.total = 0, this.names = const {}});
  final Set<int> ids;
  final bool allMatching;
  final Json filter;
  final int total;
  final Map<int, String> names;

  int get count => allMatching ? total : ids.length;
  bool get isEmpty => count == 0;

  BulkTarget toTarget() {
    if (!allMatching) return BulkTarget.users(ids.toList());
    final f = Map<String, dynamic>.from(filter)..removeWhere((k, v) => v == null || v == '');
    return f.isEmpty ? const BulkTarget.everyone() : BulkTarget.filter(f);
  }
}

/// Full-screen user picker with search + status filter, "select all visible" and
/// "select all matching" (resolved by the server, not by paging through every user).
Future<UserSelection?> pickUsers(BuildContext context, {bool multiple = true, String? title}) {
  return Navigator.of(context).push<UserSelection>(MaterialPageRoute(builder: (_) => _UserPicker(multiple: multiple, title: title)));
}

class _UserPicker extends ConsumerStatefulWidget {
  const _UserPicker({required this.multiple, this.title});
  final bool multiple;
  final String? title;
  @override
  ConsumerState<_UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends ConsumerState<_UserPicker> {
  final _ctrl = PagedListController<AppUser>();
  final _selected = <int, String>{};
  String _q = '';
  bool _allMatching = false;
  int _total = 0;
  MemberFilter _more = const MemberFilter();

  Json get _filter => {'q': _q.isEmpty ? null : _q, 'status': 'active', ..._more.toQuery()};

  /// The same selection as a bulk-target filter (typed values).
  Json get _targetFilter => {if (_q.isNotEmpty) 'q': _q, 'status': 'active', ..._more.toBody()};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    final count = _allMatching ? _total : _selected.length;
    return AdminScaffold(
      title: widget.title ?? (widget.multiple ? l.selectUsers : l.selectUser),
      actions: [
        if (widget.multiple)
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() {
                if (v == 'visible') {
                  _allMatching = false;
                  for (final u in _ctrl.items) {
                    _selected[u.id] = u.fullName;
                  }
                } else if (v == 'matching') {
                  _allMatching = true;
                } else {
                  _allMatching = false;
                  _selected.clear();
                }
              });
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'visible', child: Text(l.selectAll)),
              PopupMenuItem(value: 'matching', child: Text(l.selectAllMatching)),
              PopupMenuItem(value: 'clear', child: Text(l.clearSelection)),
            ],
          ),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBox(onChanged: (v) {
            setState(() {
              _q = v;
              _allMatching = false;
            });
          }),
        ),
        // Same categorized filters as the users list (no "can sign in": only active accounts here).
        MemberFilterBar(
          filter: _more,
          showLoginFilter: false,
          onChanged: (f) => setState(() {
            _more = f;
            _allMatching = false;
          }),
        ),
        if (widget.multiple)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(children: [
              Expanded(child: Text(_allMatching ? l.allMatchingSelected(_total) : l.selectedCount(count), style: context.sans(13, weight: FontWeight.w600, color: AppColors.goldDark))),
            ]),
          ),
        Expanded(
          child: PagedListView<AppUser>(
            key: ValueKey('$_q|${_more.hashCode}'),
            controller: _ctrl,
            // Offline (borrowing / attendance desks): the member list kept on the phone.
            fetch: (page) => _offlineFallback(page, () => repo.users(filter: _filter, page: page), () async {
              final rows = await ref.read(offlinePackProvider).searchMembers(_q, limit: 200);
              return rows.map(AppUser.fromJson).toList();
            }),
            onPageLoaded: (p) => setState(() => _total = p.total),
            emptyMessage: l.noResults,
            itemBuilder: (context, u, _) {
              final sel = _allMatching || _selected.containsKey(u.id);
              return TrackTile(
                title: u.fullName,
                subtitle: [if (u.memberId != null) u.memberId!, u.phone].join(' · '),
                selected: sel,
                leading: widget.multiple
                    ? Checkbox(
                        value: sel,
                        onChanged: _allMatching
                            ? null
                            : (v) => setState(() => v == true ? _selected[u.id] = u.fullName : _selected.remove(u.id)),
                      )
                    : const ListThumb(icon: Icons.person_outline_rounded),
                onTap: () {
                  if (!widget.multiple) {
                    Navigator.pop(context, UserSelection(ids: {u.id}, names: {u.id: u.fullName}, total: 1));
                    return;
                  }
                  if (_allMatching) return;
                  setState(() => sel ? _selected.remove(u.id) : _selected[u.id] = u.fullName);
                },
              );
            },
          ),
        ),
        if (widget.multiple)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(context, UserSelection(ids: _selected.keys.toSet(), names: Map.of(_selected), allMatching: _allMatching, filter: _targetFilter, total: _total)),
                child: Text('${l.select} ($count)'),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Item picker (available items) used by the borrowing flows.
Future<ItemModel?> pickItem(BuildContext context) =>
    Navigator.of(context).push<ItemModel>(MaterialPageRoute(builder: (_) => const _ItemPicker()));

class _ItemPicker extends ConsumerStatefulWidget {
  const _ItemPicker();
  @override
  ConsumerState<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends ConsumerState<_ItemPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    return AdminScaffold(
      title: l.selectItem,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: PagedListView<ItemModel>(
            key: ValueKey(_q),
            // Offline: the lendable items kept on the phone (offline pack).
            fetch: (page) => _offlineFallback(page, () => repo.items(q: _q.isEmpty ? null : _q, availableOnly: true, page: page), () async {
              final q = _q.trim().toLowerCase();
              return [
                for (final i in await ref.read(offlinePackProvider).items())
                  if (asIntOr(i['available_quantity']) > 0 && (q.isEmpty || '${i['name']} ${i['code']}'.toLowerCase().contains(q))) ItemModel.fromJson(i),
              ];
            }),
            emptyMessage: l.noResults,
            itemBuilder: (context, it, _) => TrackTile(
              title: it.name,
              subtitle: '${it.code} · ${l.availableOf(it.available, it.quantity)}',
              leading: ListThumb(icon: Icons.inventory_2_outlined, imageUrl: it.imageUrl),
              onTap: () => Navigator.pop(context, it),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<ItemModel?> pickBook(BuildContext context) =>
    Navigator.of(context).push<ItemModel>(MaterialPageRoute(builder: (_) => const _BookPicker()));

class _BookPicker extends ConsumerStatefulWidget {
  const _BookPicker();
  @override
  ConsumerState<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends ConsumerState<_BookPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(libraryRepositoryProvider);
    final isEn = l.isEn;
    return AdminScaffold(
      title: isEn ? 'Select Physical Book' : 'የቤተ-መጻሕፍት መጽሐፍ ይምረጡ',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBox(
            hint: isEn ? 'Search books by title, author, or code...' : 'መጽሐፍ በርእስ፣ ደራሲ ወይም መለያ ፈልግ...',
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: PagedListView<Book>(
            key: ValueKey(_q),
            fetch: (page) => repo.books(q: _q.isEmpty ? null : _q, kind: 'physical', page: page),
            emptyMessage: l.noResults,
            emptyIcon: Icons.menu_book_rounded,
            itemBuilder: (context, b, _) {
              final avail = b.available ?? b.copiesAvailable ?? 0;
              final total = b.quantity ?? b.copiesTotal ?? 0;
              return TrackTile(
                title: b.title,
                subtitle: [
                  if (b.author != null && b.author!.isNotEmpty) b.author!,
                  '${b.code} · ${l.availableOf(avail, total)}',
                ].join(' · '),
                leading: ListThumb(icon: Icons.menu_book_rounded, imageUrl: b.coverUrl),
                onTap: () {
                  final it = ItemModel(
                    id: b.id,
                    name: b.title,
                    code: b.code,
                    author: b.author,
                    subtitle: b.subtitle,
                    categoryName: b.categoryName,
                    imageUrl: b.coverUrl,
                    available: avail,
                    quantity: total,
                    domain: 'library',
                  );
                  Navigator.pop(context, it);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Signature capture on the admin's screen. Returns a PNG data URL, or null if cancelled/skipped.
Future<String?> captureSignature(BuildContext context, {required String name, bool allowSkip = false}) {
  return Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _SignaturePad(name: name, allowSkip: allowSkip)));
}

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({required this.name, required this.allowSkip});
  final String name;
  final bool allowSkip;
  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final _ctrl = SignatureController(penStrokeWidth: 3, penColor: const Color(0xFF1A1113), exportBackgroundColor: Colors.white);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_ctrl.isEmpty) {
      showSnack(context, context.l10n.signHere);
      return;
    }
    final png = await _ctrl.toPngBytes(width: 900, height: 360);
    if (png == null || !mounted) return;
    Navigator.pop(context, 'data:image/png;base64,${base64Encode(png)}');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.signFor(widget.name))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.signatureRequiredHint, style: context.sans(13, color: context.palette.muted)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.gold, width: 1.5)),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Signature(controller: _ctrl, backgroundColor: Colors.white),
                  Positioned(left: 16, bottom: 12, child: IgnorePointer(child: Text(l.signHere, style: context.sans(12, color: AppColors.faint)))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // Wraps on narrow phones / large text instead of overflowing.
            Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(key: const ValueKey('signature-clear'), onPressed: _ctrl.clear, child: Text(l.clearSignature)),
                if (widget.allowSkip) TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(l.skipSignature)),
              ]),
              FilledButton(key: const ValueKey('signature-confirm'), onPressed: _done, child: Text(l.confirm)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Shows a one-time temporary password with a copy button (and notes Telegram delivery).
Future<void> showTempPassword(BuildContext context, String password, {bool viaTelegram = false}) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(l.tempPasswordTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: ctx.palette.fill, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.palette.border)),
          child: Row(children: [
            Expanded(child: SelectableText(password, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1))),
            IconButton(
              tooltip: l.copy,
              icon: const Icon(Icons.copy_rounded, color: AppColors.gold),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: password));
                if (ctx.mounted) showSnack(ctx, l.copied);
              },
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(l.tempPasswordBody('').trim(), style: ctx.sans(13, color: ctx.palette.muted)),
        if (viaTelegram) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.send_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Expanded(child: Text(l.tempPasswordSentTelegram, style: ctx.sans(12, color: AppColors.goldDark))),
          ]),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: password));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(l.copy),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
      ],
    ),
  );
}

/// Localised label for a permission key (falls back to the key).
String permissionLabel(AppLocalizations l, String key) => switch (key) {
      'users.view' => l.perm_users_view,
      'users.create' => l.perm_users_create,
      'users.update' => l.perm_users_update,
      'users.disable' => l.perm_users_disable,
      'users.reset_device' => l.perm_users_reset_device,
      'mezmurs.view' => l.perm_mezmurs_view,
      'mezmurs.create' => l.perm_mezmurs_create,
      'mezmurs.update' => l.perm_mezmurs_update,
      'mezmurs.delete' => l.perm_mezmurs_delete,
      'categories.manage' => l.perm_categories_manage,
      'ads.manage' => l.perm_ads_manage,
      'pages.manage' => l.perm_pages_manage,
      'programs.manage' => l.perm_programs_manage,
      'attendance.manage' => l.perm_attendance_manage,
      'notifications.send' => l.perm_notifications_send,
      'notifications.send_all' => l.perm_notifications_send_all,
      'borrowing.manage' => l.perm_borrowing_manage,
      'items.manage' => l.perm_items_manage,
      'fines.manage' => l.perm_fines_manage,
      'reports.view' => l.perm_reports_view,
      'audit_logs.view' => l.perm_audit_logs_view,
      'activity_logs.view' => l.perm_activity_logs_view,
      'admins.view' => l.perm_admins_view,
      'admins.manage' => l.perm_admins_manage,
      'settings.manage' => l.perm_settings_manage,
      'releases.manage' => l.perm_releases_manage,
      'departments.manage' => l.perm_departments_manage,
      'hr.manage' => l.perm_hr_manage,
      'payments.manage' => l.perm_payments_manage,
      'education.manage' => l.perm_education_manage,
      'education.register' => l.perm_education_register,
      'education.content' => l.perm_education_content,
      'program_categories.manage' => l.perm_program_categories_manage,
      'attendance.reports' => l.perm_attendance_reports,
      'choir.manage' => l.perm_choir_manage,
      'payments.configure' => l.perm_payments_configure,
      'attendance.view' => l.perm_attendance_view,
      'attendance.close' => l.perm_attendance_close,
      'attendance.correction.request' => l.perm_attendance_correction_request,
      'attendance.correction.approve' => l.perm_attendance_correction_approve,
      'attendance.override' => l.perm_attendance_override,
      'attendance.configure' => l.perm_attendance_configure,
      'attendance.assign' => l.perm_attendance_assign,
      'payments.view' => l.perm_payments_view,
      'property.request' => l.perm_property_request,
      'property.review' => l.perm_property_review,
      'borrowing.approve' => l.perm_borrowing_approve,
      'borrowing.configure' => l.perm_borrowing_configure,
      'selection.view' => l.perm_selection_view,
      'selection.configure' => l.perm_selection_configure,
      'selection.exams' => l.perm_selection_exams,
      'selection.review' => l.perm_selection_review,
      'selection.finalize' => l.perm_selection_finalize,
      'projects.view' => l.perm_projects_view,
      'projects.manage' => l.perm_projects_manage,
      'projects.expenses.approve' => l.perm_projects_expenses_approve,
      'projects.reports' => l.perm_projects_reports,
      'projects.all_departments' => l.perm_projects_all_departments,
      _ => key,
    };

/// Module name of a permission group.
String permissionGroupLabel(AppLocalizations l, String group) => switch (group) {
      'users' => l.users,
      'mezmurs' => l.mezmurs,
      'content' => l.pgContent,
      'programs' => l.pgPrograms,
      'notifications' => l.pgNotifications,
      'library' => l.borrowing,
      'property' => l.propRequests,
      'reports' => l.reports,
      'admins' => l.admins,
      'system' => l.pgSystem,
      'hr' => l.pgHr,
      'payments' => l.monthlyPayments,
      'education' => l.eduManage,
      'choir' => l.pgChoir,
      'projects' => l.projectManagement,
      _ => group,
    };

/// Localised label for a user activity action.
String activityLabel(AppLocalizations l, String action) => switch (action) {
      'register' => l.act_register,
      'login' => l.act_login,
      'login_failed' => l.act_login_failed,
      'logout' => l.act_logout,
      'password_change' => l.act_password_change,
      'password_reset' => l.act_password_reset,
      'profile_update' => l.act_profile_update,
      'device_change' => l.act_device_change,
      'mezmur_view' => l.act_mezmur_view,
      'mezmur_search' => l.act_mezmur_search,
      'audio_play' => l.act_audio_play,
      'audio_complete' => l.act_audio_complete,
      'favorite_add' => l.act_favorite_add,
      'favorite_remove' => l.act_favorite_remove,
      'download' => l.act_download,
      'download_remove' => l.act_download_remove,
      'offline_access' => l.act_offline_access,
      'program_view' => l.act_program_view,
      'program_register' => l.act_program_register,
      'program_unregister' => l.act_program_unregister,
      'reminder_create' => l.act_reminder_create,
      'reminder_update' => l.act_reminder_update,
      'reminder_delete' => l.act_reminder_delete,
      'notification_open' => l.act_notification_open,
      'attendance' => l.act_attendance,
      'borrow' => l.act_borrow,
      'return' => l.act_return,
      'page_view' => l.act_page_view,
      'book_read' => 'መጽሐፍ ማንበብ (Book Read)',
      'book_download' => 'መጽሐፍ ማውረድ (Book Download)',
      'lesson_view' => 'ትምህርት መክፈት (Lesson View)',
      'material_open' => 'ማቴሪያል ማውረድ (Material Open)',
      'quiz_attempt' => 'ፈተና መውሰድ (Quiz Attempt)',
      'magazine_view' => 'ሰሌዳ መጽሔት ማንበብ (Magazine View)',
      _ => action,
    };

/// Stat tile used on the dashboard and reports.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.highlight = false, this.onTap});
  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) Icon(icon, size: 20, color: highlight ? AppColors.danger : AppColors.gold),
      const SizedBox(height: 6),
      Text(value, style: context.serif(22, color: highlight ? AppColors.danger : p.primary)),
      Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.sans(12, color: p.muted)),
    ]);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      // Grid cells have a fixed height: a two-line (Amharic) label or a large text scale must shrink
      // the tile's content to fit instead of overflowing it.
      child: LayoutBuilder(
        builder: (context, c) => c.hasBoundedHeight
            ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: SizedBox(width: c.maxWidth, child: content))
            : content,
      ),
    );
  }
}

/// Shortcut used by list screens: fetch a page from a repository call.
typedef PageFetcher<T> = Future<Paged<T>> Function(int page);


/// A list page from the server, or — on a network failure, first page only — the copy kept on the
/// phone (SQLite offline pack), so staff desks keep working offline.
Future<Paged<T>> _offlineFallback<T>(int page, Future<Paged<T>> Function() online, Future<List<T>> Function() offline) async {
  try {
    return await online();
  } on ApiException catch (e) {
    if (!e.isNetwork || page > 1) rethrow;
    final items = await offline();
    if (items.isEmpty) rethrow;
    return Paged(items: items, page: 1, pages: 1, total: items.length, meta: const {'offline': true});
  }
}
