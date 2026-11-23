import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../services/local_notifications.dart';
import '../../services/reminder_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import 'account_screens.dart' show showReminderEditor;

/// Screen for managing all scheduled reminders (Task 6).
/// Supports local notifications, Ethiopian calendar display, filtering, snoozing, and editing.
class RemindersManagementScreen extends ConsumerStatefulWidget {
  const RemindersManagementScreen({super.key});

  @override
  ConsumerState<RemindersManagementScreen> createState() => _RemindersManagementScreenState();
}

class _RemindersManagementScreenState extends ConsumerState<RemindersManagementScreen> {
  int _tabIndex = 0; // 0: All, 1: Programs, 2: Education / Library, 3: Personal
  bool _notificationsOk = true;
  bool _exactAlarmsOk = true;
  bool _fullScreenOk = true;
  bool _batteryOk = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final notifs = await ref.read(localNotificationsProvider).notificationsEnabled();
      bool exact = true;
      bool fullScreen = true;
      bool battery = true;
      try {
        const channel = MethodChannel('mezmur/settings');
        exact = await channel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
        battery = await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
      } catch (_) {}
      try {
        const alarmChan = MethodChannel('mezmur/alarm');
        fullScreen = await alarmChan.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _notificationsOk = notifs;
          _exactAlarmsOk = exact;
          _fullScreenOk = fullScreen;
          _batteryOk = battery;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reminders = ref.watch(remindersProvider);
    final isEn = l.isEn;

    final filtered = reminders.where((r) {
      if (_tabIndex == 1) return r.programId != null;
      if (_tabIndex == 2) return r.borrowingId != null;
      if (_tabIndex == 3) return r.programId == null && r.borrowingId == null;
      return true;
    }).toList();

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Reminders' : 'ማስታወሻዎች'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_on_rounded),
            tooltip: isEn ? 'Test Real Alarm (3s)' : 'የእውነተኛ ማንቂያ ሙከራ (3 ሰከንድ)',
            onPressed: () async {
              try {
                const channel = MethodChannel('mezmur/alarm');
                await channel.invokeMethod('testAlarm', {'delaySeconds': 3});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEn
                          ? 'Alarm scheduled in 3s! Lock phone or switch apps to test full screen alarm.'
                          : 'ማንቂያው በ3 ሰከንድ ውስጥ ይጮኻል! ሙሉ ገጹን ለማየት ስልኩን ቆልፈው ይሞክሩ።'),
                      backgroundColor: AppColors.maroon,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_alert_rounded),
        label: Text(isEn ? 'New Reminder' : 'አዲስ ማስታወሻ'),
        onPressed: () => showReminderEditor(context, ref),
      ),
      body: Column(
        children: [
          if (!_notificationsOk || !_exactAlarmsOk || !_fullScreenOk || !_batteryOk)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C1619),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Alarm Reliability Notice' : 'የማንቂያዎች አስተማማኝነት ማሳሰቢያ',
                        style: context.sans(14, weight: FontWeight.bold, color: AppColors.gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!_notificationsOk) ...[
                    Text(
                      isEn
                          ? '• Notifications are disabled. Alarms cannot display or alert when locked.'
                          : '• ማሳወቂያዎች ተዘግተዋል። ስልኩ ሲቆለፍ ማንቂያዎች አይጮኹም።',
                      style: context.sans(12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!_exactAlarmsOk) ...[
                    Text(
                      isEn
                          ? '• Exact Alarm permission is missing. Clock-like precision requires this permission.'
                          : '• ትክክለኛ ሰዓት የማንቂያ ፈቃድ አልተሰጠም። በደቂቃው እንዲጮኽ ፈቃድ ያስፈልጋል።',
                      style: context.sans(12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!_fullScreenOk) ...[
                    Text(
                      isEn
                          ? '• Full Screen Intent permission is needed to show full alarm screen on lockscreen.'
                          : '• ስልኩ ሲቆለፍ ሙሉ ገጽ ማንቂያ ለማሳየት የሙሉ ገጽ ፈቃድ ያስፈልጋል።',
                      style: context.sans(12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!_batteryOk) ...[
                    Text(
                      isEn
                          ? '• Battery optimization is active and may kill background alarms.'
                          : '• የባትሪ ቆጣቢ ዘዴ ማንቂያዎችን ከበስተጀርባ ሊያጠፋቸው ይችላል።',
                      style: context.sans(12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (!_notificationsOk)
                        ActionChip(
                          avatar: const Icon(Icons.notifications_active_rounded, size: 16),
                          label: Text(isEn ? 'Enable Notifications' : 'ማሳወቂያ ፍቀድ'),
                          onPressed: () async {
                            const MethodChannel('mezmur/settings').invokeMethod('openNotificationSettings');
                            await Future.delayed(const Duration(seconds: 1));
                            _checkPermissions();
                          },
                        ),
                      if (!_exactAlarmsOk)
                        ActionChip(
                          avatar: const Icon(Icons.alarm_add_rounded, size: 16),
                          label: Text(isEn ? 'Grant Exact Alarm' : 'የማንቂያ ፈቃድ'),
                          onPressed: () async {
                            const MethodChannel('mezmur/settings').invokeMethod('openExactAlarmSettings');
                            await Future.delayed(const Duration(seconds: 1));
                            _checkPermissions();
                          },
                        ),
                      if (!_fullScreenOk)
                        ActionChip(
                          avatar: const Icon(Icons.fullscreen_rounded, size: 16),
                          label: Text(isEn ? 'Full Screen Alarm' : 'የሙሉ ገጽ ፈቃድ'),
                          onPressed: () async {
                            const MethodChannel('mezmur/alarm').invokeMethod('openFullScreenIntentSettings');
                            await Future.delayed(const Duration(seconds: 1));
                            _checkPermissions();
                          },
                        ),
                      if (!_batteryOk)
                        ActionChip(
                          avatar: const Icon(Icons.battery_saver_rounded, size: 16),
                          label: Text(isEn ? 'Unrestrict Battery' : 'ባትሪ አታቆጥብ'),
                          onPressed: () async {
                            const MethodChannel('mezmur/settings').invokeMethod('requestIgnoreBatteryOptimizations');
                            await Future.delayed(const Duration(seconds: 1));
                            _checkPermissions();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(0, isEn ? 'All' : 'ሁሉም', reminders.length),
                  const SizedBox(width: 8),
                  _filterChip(1, isEn ? 'Programs' : 'መርሐግብራት', reminders.where((r) => r.programId != null).length),
                  const SizedBox(width: 8),
                  _filterChip(2, isEn ? 'Education / Library' : 'ትምህርት / ቤተ መጻሕፍት', reminders.where((r) => r.borrowingId != null).length),
                  const SizedBox(width: 8),
                  _filterChip(3, isEn ? 'Personal' : 'የግል', reminders.where((r) => r.programId == null && r.borrowingId == null).length),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: filtered.isEmpty
                ? EmptyView(
                    icon: Icons.alarm_off_rounded,
                    message: isEn
                        ? 'No reminders found in this category'
                        : 'በዚህ ምድብ ውስጥ ምንም ማስታወሻዎች አልተገኙም',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _ReminderCard(
                        reminder: item,
                        onEdit: () => showReminderEditor(context, ref, existing: item),
                        onDelete: () async {
                          if (!await showConfirm(
                            context,
                            isEn ? 'Delete this reminder?' : 'ይህን ማስታወሻ መሰረዝ ይፈልጋሉ?',
                            destructive: true,
                          )) {
                            return;
                          }
                          await ref.read(remindersProvider.notifier).delete(item);
                          if (context.mounted) {
                            showSnack(context, isEn ? 'Reminder deleted' : 'ማስታወሻው ተሰርዟል');
                          }
                        },
                        onToggle: (enabled) async {
                          await ref.read(remindersProvider.notifier).update(item, isEnabled: enabled);
                        },
                        onSnooze: (duration) async {
                          final newTime = DateTime.now().add(duration);
                          await ref.read(remindersProvider.notifier).update(
                            item,
                            remindAt: newTime,
                            isEnabled: true,
                          );
                          if (context.mounted) {
                            showSnack(
                              context,
                              isEn
                                  ? 'Snoozed for ${duration.inMinutes} minutes'
                                  : 'ለ${duration.inMinutes} ደቂቃዎች ተራዝሟል',
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label, int count) {
    final selected = _tabIndex == index;
    final p = context.palette;
    return ChoiceChip(
      selected: selected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.black : p.primary,
      ),
      selectedColor: AppColors.gold,
      backgroundColor: p.card,
      onSelected: (_) => setState(() => _tabIndex = index),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onSnooze,
  });

  final Reminder reminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final void Function(Duration duration) onSnooze;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = l.isEn;
    final isPast = reminder.remindAt.isBefore(DateTime.now());

    String categoryLabel;
    IconData categoryIcon;
    if (reminder.programId != null) {
      categoryLabel = isEn ? 'Program' : 'መርሐግብር';
      categoryIcon = Icons.event_rounded;
    } else if (reminder.borrowingId != null) {
      categoryLabel = isEn ? 'Library / Borrowing' : 'ቤተ መጻሕፍት';
      categoryIcon = Icons.book_rounded;
    } else {
      categoryLabel = isEn ? 'Personal' : 'የግል';
      categoryIcon = Icons.person_rounded;
    }

    String repeatLabel;
    switch (reminder.repeat) {
      case 'daily':
        repeatLabel = isEn ? 'Daily' : 'በየቀኑ';
        break;
      case 'weekly':
        repeatLabel = isEn ? 'Weekly' : 'በየሳምንቱ';
        break;
      case 'monthly':
        repeatLabel = isEn ? 'Monthly' : 'በየወሩ';
        break;
      default:
        repeatLabel = isEn ? 'Once' : 'አንድ ጊዜ';
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: reminder.isEnabled
                      ? (isPast ? p.pill : AppColors.gold.withValues(alpha: 0.2))
                      : p.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  reminder.isEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                  size: 20,
                  color: reminder.isEnabled
                      ? (isPast ? p.muted : AppColors.goldDark)
                      : p.faint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: context.serif(15, color: reminder.isEnabled ? p.primary : p.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(categoryIcon, size: 12, color: p.muted),
                        const SizedBox(width: 4),
                        Text(categoryLabel, style: context.sans(11, color: p.muted)),
                        const SizedBox(width: 8),
                        Text('•', style: context.sans(11, color: p.muted)),
                        const SizedBox(width: 8),
                        Text(repeatLabel, style: context.sans(11, color: p.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: reminder.isEnabled,
                activeThumbColor: AppColors.gold,
                onChanged: onToggle,
              ),
            ],
          ),
          if (reminder.note != null && reminder.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reminder.note!,
              style: context.sans(12.5, color: p.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: isPast ? AppColors.warning : AppColors.goldDark,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.dateTime(reminder.remindAt),
                  style: context.sans(
                    12.5,
                    weight: FontWeight.w600,
                    color: isPast ? AppColors.warning : p.primary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) {
                  if (action == 'edit') {
                    onEdit();
                  } else if (action == 'snooze_15') {
                    onSnooze(const Duration(minutes: 15));
                  } else if (action == 'snooze_60') {
                    onSnooze(const Duration(hours: 1));
                  } else if (action == 'snooze_1day') {
                    onSnooze(const Duration(days: 1));
                  } else if (action == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Edit' : 'አስተካክል'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'snooze_15',
                    child: Row(
                      children: [
                        const Icon(Icons.snooze_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Snooze 15 min' : 'ለ15 ደቂቃ አራዝም'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'snooze_60',
                    child: Row(
                      children: [
                        const Icon(Icons.snooze_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Snooze 1 hour' : 'ለ1 ሰዓት አራዝም'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'snooze_1day',
                    child: Row(
                      children: [
                        const Icon(Icons.snooze_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Snooze 1 day' : 'ለ1 ቀን አራዝም'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Delete' : 'ሰርዝ', style: const TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
