import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/json.dart';
import '../../models/activity.dart';
import '../../models/content.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../services/preferences_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/ethiopian_date_picker.dart';
import '../../widgets/states.dart';
import '../auth/auth_screens.dart' show PrimaryButton;
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';

export '../auth/auth_screens.dart' show ChangePasswordScreen;

/// Standard sub-page scaffold: pattern background, back button and serif title.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.body, this.actions, this.fab});
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: fab,
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider)!;
    _name = TextEditingController(text: u.fullName);
    _phone = TextEditingController(text: u.phone);
    _email = TextEditingController(text: u.email ?? '');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final before = ref.read(currentUserProvider)!;
      final u = await ref
          .read(accountRepositoryProvider)
          .updateProfile(fullName: _name.text.trim(), phone: _phone.text.trim(), email: _email.text.trim().isEmpty ? null : _email.text.trim());
      ref.read(sessionProvider.notifier).updateUser(u);
      if (!mounted) return;
      // Name/phone changes of regular users wait for admin approval — keep showing current values.
      final pending = u.pendingChange != null && (u.fullName != _name.text.trim() || u.phone != before.phone);
      _name.text = u.fullName;
      _phone.text = u.phone;
      showSnack(context, pending ? context.l10n.profileChangeSubmitted : context.l10n.profileSaved);
    } catch (e) {
      setState(() => _error = e);
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo() async {
    final l = context.l10n;
    final user = ref.read(currentUserProvider)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.changePhoto), onTap: () => Navigator.pop(ctx, 'pick')),
            if (user.avatarUrl != null)
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l.removePhoto), onTap: () => Navigator.pop(ctx, 'remove')),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(accountRepositoryProvider);
    if (action == 'remove') {
      await runWithProgress(context, () async {
        await repo.removeAvatar();
        await ref.read(sessionProvider.notifier).refreshUser();
      });
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (file == null || !mounted) return;
    await runWithProgress(context, () async {
      final u = await repo.uploadAvatar(file.path);
      ref.read(sessionProvider.notifier).updateUser(u);
    }, success: l.profileSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    String? server(String f) => serverFieldError(l, _error, f);
    // Only administrators may change profile details; regular users see them read-only.
    if (!user.isAccountAdmin) return _ReadOnlyProfile(user: user);
    return SubPage(
      title: l.editProfile,
      actions: const [
        ContextualHelpButton(screenRoute: '/settings/profile'),
      ],
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: GestureDetector(
              onTap: _photo,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: context.palette.pill,
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null ? Text(user.fullName.characters.first, style: context.serif(32)) : null,
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.gold,
                      child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (user.pendingChange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.profileChangePending(user.pendingChange!.describe()), style: context.sans(13))),
                    TextButton(
                      onPressed: () => runWithProgress(context, () async {
                        final u = await ref.read(accountRepositoryProvider).cancelChangeRequest();
                        ref.read(sessionProvider.notifier).updateUser(u);
                      }),
                      child: Text(l.cancelRequest),
                    ),
                  ],
                ),
              ),
            ),
          if (!user.isAccountAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(l.profileApprovalNote, style: context.sans(12, color: context.palette.muted)),
            ),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    validator: (s) => v.text(s, min: 2, max: 150),
                    decoration: InputDecoration(labelText: l.fullName, errorText: server('full_name')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: v.phone,
                    decoration: InputDecoration(labelText: l.phone, errorText: server('phone')),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (s) => v.email(s, optional: true),
                    decoration: InputDecoration(labelText: l.emailOptional, errorText: server('email')),
                  ),
                  if (_error != null && serverFieldError(l, _error, 'phone') == null && serverFieldError(l, _error, 'email') == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(errorText(l, _error!), style: context.sans(13, color: AppColors.danger)),
                    ),
                  const SizedBox(height: 18),
                  PrimaryButton(label: l.save, busy: _busy, onPressed: _save),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyProfile extends StatelessWidget {
  const _ReadOnlyProfile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SubPage(
      title: l.myProfile,
      actions: const [
        ContextualHelpButton(screenRoute: '/settings/profile'),
      ],
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: context.palette.pill,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null ? Text(user.fullName.characters.first, style: context.serif(32)) : null,
          ),
        ),
        const SizedBox(height: 20),
        SettingsGroup(children: [
          SettingsTile(icon: Icons.person_outline_rounded, label: l.fullName, value: user.fullName),
          SettingsTile(icon: Icons.phone_outlined, label: l.phone, value: user.phone),
          if (user.email != null && user.email!.isNotEmpty) SettingsTile(icon: Icons.email_outlined, label: l.emailOptional, value: user.email),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(child: Text(l.profileLockedNote, style: context.sans(13, color: context.palette.muted))),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
final _categoryTreeProvider = FutureProvider.autoDispose<List<CategoryNode>>((ref) => ref.watch(contentRepositoryProvider).categoryTree());

class PreferredCategoriesScreen extends ConsumerWidget {
  const PreferredCategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prefs = ref.watch(preferencesProvider);
    final tree = ref.watch(_categoryTreeProvider);
    return SubPage(
      title: l.preferredCategories,
      body: AsyncView(
        value: tree,
        onRetry: () => ref.invalidate(_categoryTreeProvider),
        data: (roots) {
          final all = roots.expand((c) => c.flatten()).toList();
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(l.preferredCategoriesHint, style: context.sans(13, color: context.palette.muted)),
              const SizedBox(height: 12),
              SettingsGroup(
                children: [
                  for (final c in all)
                    CheckboxListTile(
                      value: prefs.preferredCategoryIds.contains(c.id),
                      title: Padding(
                        padding: EdgeInsets.only(left: c.depth * 16.0),
                        child: Text(c.name),
                      ),
                      onChanged: (v) => ref
                          .read(preferencesProvider.notifier)
                          .update((p) {
                            final ids = {...p.preferredCategoryIds};
                            v == true ? ids.add(c.id) : ids.remove(c.id);
                            return p.copyWith(preferredCategoryIds: ids.toList());
                          })
                          .catchError((Object e) {
                            if (context.mounted) showErrorSnack(context, e);
                          }),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
String attendanceLabel(BuildContext context, String status) {
  final l = context.l10n;
  return switch (status) {
    'present' => l.attPresent,
    'late' => l.attLate,
    'absent' => l.attAbsent,
    'excused' => l.attExcused,
    _ => l.unmarked,
  };
}

Color attendanceColor(String status) => switch (status) {
  'present' => AppColors.success,
  'late' => AppColors.warning,
  'absent' => AppColors.danger,
  _ => AppColors.goldDark,
};

class MyAttendanceScreen extends ConsumerWidget {
  const MyAttendanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(programRepositoryProvider);
    // Weighted rate from the server (approved permissions count partially, per admin setting).
    final rate = ValueNotifier<String?>(null);
    return SubPage(
      title: l.myAttendance,
      body: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: rate,
            builder: (context, r, _) => r == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
                    child: Pill(l.attendanceRate(r), icon: Icons.insights_rounded),
                  ),
          ),
          Expanded(
            child: PagedListView<AttendanceRecord>(
              fetch: (page) async {
                final res = await repo.myAttendance(page: page);
                final v = asJson(res.meta['summary'])['rate'];
                if (page == 1 && v is num) rate.value = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
                return res;
              },
              emptyMessage: l.noAttendance,
              emptyIcon: Icons.how_to_reg_outlined,
              itemBuilder: (context, a, _) {
                final dateText = a.calendarDate ?? f.date(a.startsAt);
                final timeText = a.actualTime != null ? ' · ${a.actualTime}' : '';
                final sigLabel = switch (a.signatureIndicator) {
                  'signed' => l.isEn ? 'Signed' : 'ተፈርሟል',
                  'missing' => l.isEn ? 'Signature Missing' : 'ያልተፈረመ',
                  'exempt' => l.isEn ? 'Exempt' : 'ነፃ',
                  _ => null,
                };
                final sigColor = switch (a.signatureIndicator) {
                  'signed' => AppColors.success,
                  'missing' => AppColors.danger,
                  _ => AppColors.gold,
                };
                return TrackTile(
                  title: a.programTitle,
                  subtitle: '$dateText$timeText${a.location != null ? ' · ${a.location}' : ''}',
                  leading: ListThumb(icon: a.status == 'absent' ? Icons.event_busy_rounded : Icons.event_available_rounded),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sigLabel != null) ...[
                        Pill(sigLabel, color: sigColor),
                        const SizedBox(width: 6),
                      ],
                      Pill(attendanceLabel(context, a.status), color: attendanceColor(a.status)),
                    ],
                  ),
                  onTap: () => _showAttendanceDetails(context, a, l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDetails(BuildContext context, AttendanceRecord a, AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      a.programTitle,
                      style: context.serif(18, weight: FontWeight.w700),
                    ),
                  ),
                  Pill(attendanceLabel(context, a.status), color: attendanceColor(a.status)),
                ],
              ),
              const SizedBox(height: 16),
              if (a.calendarDate != null)
                _infoRow(ctx, l.isEn ? 'Calendar Date' : 'የቀን መቁጠሪያ ቀን', a.calendarDate!),
              if (a.attendedAt != null)
                _infoRow(ctx, l.isEn ? 'Recorded At' : 'የተመዘገበበት ሰዓት', '${a.attendedAt}'),
              if (a.actualTime != null)
                _infoRow(ctx, l.isEn ? 'Actual Time' : 'ትክክለኛ ሰዓት', a.actualTime!),
              if (a.memberName != null && a.memberName!.isNotEmpty)
                _infoRow(ctx, l.isEn ? 'Member Name' : 'የአባል ስም', a.memberName!),
              if (a.signatureIndicator != null)
                _infoRow(
                  ctx,
                  l.isEn ? 'Signature' : 'ፊርማ',
                  switch (a.signatureIndicator) {
                    'signed' => l.isEn ? 'Signed' : 'ተፈርሟል',
                    'missing' => l.isEn ? 'Signature Missing' : 'ያልተፈረመ',
                    'exempt' => l.isEn ? 'Exempt' : 'ነፃ',
                    _ => a.signatureIndicator!,
                  },
                ),
              if (a.location != null && a.location!.isNotEmpty)
                _infoRow(ctx, l.isEn ? 'Location' : 'ቦታ', a.location!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(l.isEn ? 'View Program Details' : 'የፕሮግራሙን ዝርዝር ይመልከቱ'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/programs/${a.programId}');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ctx.sans(13, color: ctx.palette.muted)),
          Text(value, style: ctx.sans(13, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Create/edit a personal reminder (bottom sheet). Used for borrowed items (program reminders are
/// chosen on each program instead).
Future<void> showReminderEditor(
  BuildContext context,
  WidgetRef ref, {
  Reminder? existing,
  int? programId,
  int? borrowingId,
  String? defaultTitle,
  DateTime? defaultTime,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _ReminderEditor(existing: existing, programId: programId, borrowingId: borrowingId, defaultTitle: defaultTitle, defaultTime: defaultTime),
    ),
  );
}

class _ReminderEditor extends ConsumerStatefulWidget {
  const _ReminderEditor({this.existing, this.programId, this.borrowingId, this.defaultTitle, this.defaultTime});
  final Reminder? existing;
  final int? programId;
  final int? borrowingId;
  final String? defaultTitle;
  final DateTime? defaultTime;
  @override
  ConsumerState<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends ConsumerState<_ReminderEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _at;
  late String _repeat;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.defaultTitle ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final def = widget.defaultTime;
    _at = e?.remindAt ?? (def != null && def.isAfter(DateTime.now()) ? def : DateTime.now().add(const Duration(hours: 1)));
    _repeat = e?.repeat ?? 'none';
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final d = await showEthiopianDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute);
      _dateError = null;
    });
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t == null || !mounted) return;
    setState(() {
      _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute);
      _dateError = null;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_repeat == 'none' && _at.isBefore(DateTime.now())) {
      setState(() => _dateError = l.vReminderInPast);
      return;
    }
    final ctrl = ref.read(remindersProvider.notifier);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (widget.existing == null) {
      await ctrl.create(title: _title.text.trim(), note: note, remindAt: _at, repeat: _repeat, programId: widget.programId, borrowingId: widget.borrowingId);
    } else {
      await ctrl.update(widget.existing!, title: _title.text.trim(), note: note, remindAt: _at, repeat: _repeat);
    }
    if (mounted) {
      Navigator.pop(context);
      showSnack(context, l.reminderSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? l.newReminder : l.editReminder, style: context.serif(19)),
              const SizedBox(height: 12),
              // Date, time and repeat come first and are tap-only, so they are reachable without the keyboard.
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, color: AppColors.gold),
                    label: Text(f.date(_at)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, color: AppColors.gold),
                    label: Text(f.time(_at)),
                  ),
                ),
              ]),
              if (_dateError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_dateError!, style: const TextStyle(color: AppColors.danger))),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'none', label: Text(l.repeatNone)),
                  ButtonSegment(value: 'daily', label: Text(l.repeatDaily)),
                  ButtonSegment(value: 'weekly', label: Text(l.repeatWeekly)),
                ],
                selected: {_repeat},
                onSelectionChanged: (s) => setState(() => _repeat = s.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                validator: (s) => v.text(s, max: 255),
                decoration: InputDecoration(labelText: l.reminderTitle),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                validator: (s) => v.text(s, max: 500, optional: true),
                decoration: InputDecoration(labelText: l.reminderNote),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (widget.existing != null)
                    IconButton(
                      tooltip: l.delete,
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      onPressed: () async {
                        await ref.read(remindersProvider.notifier).delete(widget.existing!);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  Expanded(
                    child: FilledButton(onPressed: _save, child: Text(l.save)),
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

// ---------------------------------------------------------------------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SubPage(
      title: l.aboutApp,
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Center(child: AppLogo(size: 120)),
          const SizedBox(height: 18),
          Text(l.appName, textAlign: TextAlign.center, style: context.serif(24)),
          Text(
            l.schoolName,
            textAlign: TextAlign.center,
            style: context.sans(13, color: context.palette.muted),
          ),
          Text(
            l.churchName,
            textAlign: TextAlign.center,
            style: context.sans(12, color: AppColors.goldDark),
          ),
          const SizedBox(height: 22),
          Text(l.aboutBody, style: context.sans(15, height: 1.75)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Deadline chip text/colour shared by user and admin borrowing screens.
({String text, Color color}) deadlineInfo(BuildContext context, Borrowing b) {
  final l = context.l10n;
  switch (b.status) {
    case 'returned':
      return (text: l.bStatusReturned, color: AppColors.success);
    case 'lost':
      return (text: l.bStatusLost, color: AppColors.danger);
    case 'pending_approval':
      return (text: l.bStatusPending, color: AppColors.goldDark);
    case 'rejected':
      return (text: l.rejected, color: AppColors.danger);
  }
  switch (b.deadlineState) {
    case 'overdue':
      return (text: l.overdueDays(b.daysOverdue ?? 0), color: AppColors.danger);
    case 'due_today':
      return (text: l.dueToday, color: AppColors.warning);
    case 'due_soon':
      return (text: l.daysRemaining(b.daysRemaining ?? 0), color: AppColors.warning);
    default:
      return (text: b.status == 'partially_returned' ? l.bStatusPartial : l.daysRemaining(b.daysRemaining ?? 0), color: AppColors.goldDark);
  }
}

String fineStatusLabel(BuildContext context, String s) {
  final l = context.l10n;
  return switch (s) {
    'pending' => l.finePending,
    'paid' => l.finePaid,
    'waived' => l.fineWaived,
    _ => l.fineNone,
  };
}

class MyBorrowingsScreen extends ConsumerWidget {
  const MyBorrowingsScreen({super.key, this.domain, this.detailBase = '/settings/borrowings'});

  /// mezmur | timhirt — which library this list shows.
  final String? domain;
  final String detailBase;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(borrowingRepositoryProvider);
    return SubPage(
      title: l.myBorrowings,
      body: PagedListView<Borrowing>(
        fetch: (page) => repo.mine(page: page, domain: domain),
        emptyMessage: l.noBorrowings,
        emptyIcon: Icons.inventory_2_outlined,
        itemBuilder: (context, b, _) {
          final d = deadlineInfo(context, b);
          return TrackTile(
            title: '${b.item.name} × ${b.quantity}',
            subtitle: '${l.dueOn}: ${f.date(Formatters.parseDateOnly(b.dueOn))}',
            leading: ListThumb(icon: Icons.inventory_2_outlined, imageUrl: b.item.imageUrl),
            trailing: Pill(d.text, color: d.color),
            onTap: () => context.push('$detailBase/${b.id}'),
          );
        },
      ),
    );
  }
}

final _myBorrowingProvider = FutureProvider.autoDispose.family<Borrowing, int>((ref, id) => ref.watch(borrowingRepositoryProvider).mineOne(id));
final _signatureProvider = FutureProvider.autoDispose.family<Uint8List?, int>((ref, id) async {
  try {
    return Uint8List.fromList(await ref.watch(borrowingRepositoryProvider).signature(id));
  } catch (_) {
    return null;
  }
});

class MyBorrowingDetailScreen extends ConsumerWidget {
  const MyBorrowingDetailScreen({super.key, required this.borrowingId});
  final int borrowingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SubPage(
      title: l.details,
      body: AsyncView(
        value: ref.watch(_myBorrowingProvider(borrowingId)),
        onRetry: () => ref.invalidate(_myBorrowingProvider(borrowingId)),
        data: (b) {
          final reminder = ref.watch(remindersProvider).where((r) => r.borrowingId == b.id).firstOrNull;
          final due = Formatters.parseDateOnly(b.dueOn);
          return BorrowingDetailBody(
            borrowing: b,
            signature: b.signed ? ref.watch(_signatureProvider(borrowingId)).value : null,
            actions: [
              if (b.isOpen)
                OutlinedButton.icon(
                  icon: Icon(reminder != null ? Icons.alarm_on_rounded : Icons.alarm_add_rounded),
                  label: Text(
                    reminder != null
                        ? '${l.reminders}: ${Formatters(l, Localizations.localeOf(context).languageCode).dateTime(reminder.remindAt)}'
                        : l.setReminder,
                  ),
                  onPressed: () => showReminderEditor(
                    context,
                    ref,
                    existing: reminder,
                    borrowingId: b.id,
                    defaultTitle: l.reminderReturnItem(b.item.name),
                    // Default: the day before it is due, at 09:00.
                    defaultTime: due == null ? null : DateTime(due.year, due.month, due.day - 1, 9),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Read-only borrowing details (shared with the admin detail screen).
class BorrowingDetailBody extends StatelessWidget {
  const BorrowingDetailBody({super.key, required this.borrowing, this.signature, this.admin = false, this.actions = const []});
  final Borrowing borrowing;
  final Uint8List? signature;
  final bool admin;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final b = borrowing;
    final d = deadlineInfo(context, b);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CoverImage(url: b.item.imageUrl, radius: 14, placeholderIcon: Icons.inventory_2_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.item.name, style: context.serif(17)),
                    if (b.item.code != null) Text(b.item.code!, style: context.sans(12, color: context.palette.muted)),
                    const SizedBox(height: 6),
                    Pill(d.text, color: d.color),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsGroup(
          children: [
            if (admin && b.userName != null) SettingsTile(icon: Icons.person_outline_rounded, label: l.borrower, value: '${b.userName}\n${b.userPhone ?? ''}'),
            SettingsTile(
              icon: Icons.numbers_rounded,
              label: l.quantity,
              value: b.returnedQuantity > 0 ? '${b.returnedQuantity}/${b.quantity}' : '${b.quantity}',
            ),
            SettingsTile(icon: Icons.event_rounded, label: l.borrowedOn, value: f.date(Formatters.parseDateOnly(b.borrowedOn))),
            SettingsTile(icon: Icons.event_available_rounded, label: l.dueOn, value: f.date(Formatters.parseDateOnly(b.dueOn))),
            if (b.returnedOn != null)
              SettingsTile(icon: Icons.assignment_turned_in_outlined, label: l.returnedOn, value: f.date(Formatters.parseDateOnly(b.returnedOn))),
            if (b.returnCondition != null) SettingsTile(icon: Icons.fact_check_outlined, label: l.returnCondition, value: b.returnCondition),
            if (admin && b.returnNotes != null) SettingsTile(icon: Icons.notes_rounded, label: l.returnNotes, value: b.returnNotes),
            SettingsTile(
              icon: Icons.payments_outlined,
              label: l.fine,
              value: b.fineAmount > 0
                  ? '${f.money(b.fineAmount, b.fineCurrency)} · ${fineStatusLabel(context, b.fineStatus)}${b.fineOverridden ? ' · ${l.fineOverridden}' : ''}'
                  : l.fineNone,
            ),
            if (admin && b.issuedByName != null) SettingsTile(icon: Icons.badge_outlined, label: l.issuedBy, value: b.issuedByName),
            if (admin && b.returnedToName != null) SettingsTile(icon: Icons.badge_outlined, label: l.returnedTo, value: b.returnedToName),
            if (b.notes != null) SettingsTile(icon: Icons.notes_rounded, label: l.notes, value: b.notes),
          ],
        ),
        SettingsGroup(
          title: l.signature,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: b.signed
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (signature != null)
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.palette.border),
                            ),
                            child: Image.memory(signature!, fit: BoxFit.contain),
                          ),
                        const SizedBox(height: 6),
                        Text('${l.signedAt}: ${f.dateTime(b.signedAt)}', style: context.sans(12, color: context.palette.muted)),
                      ],
                    )
                  : Text(l.notSigned, style: context.sans(13, color: context.palette.muted)),
            ),
          ],
        ),
        if (actions.isNotEmpty) ...[const SizedBox(height: 18), ...actions],
      ],
    );
  }
}
