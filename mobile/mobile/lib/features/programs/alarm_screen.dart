import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../services/local_notifications.dart';
import '../../services/reminder_service.dart';
import 'program_detail_screen.dart' show programProvider;

/// Full-Screen Program & Reminder Alarm Screen
/// Triggered when an enabled alarm fires (or opened via notification action / full-screen intent).
/// Features Meserete Hiwot Orthodox brand styling, insistent alarm tone, Stop, and Snooze actions.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({
    super.key,
    this.programId,
    this.reminderId,
    this.title,
    this.note,
    this.slot,
  });

  final int? programId;
  final int? reminderId;
  final String? title;
  final String? note;
  final int? slot;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _turnScreenOnAndUnlock();
    _startAlarmSound();
  }

  Future<void> _turnScreenOnAndUnlock() async {
    try {
      const channel = MethodChannel('mezmur/settings');
      await channel.invokeMethod('turnScreenOnAndUnlock');
    } catch (_) {}
  }

  Future<void> _startAlarmSound() async {
    try {
      const nativeAlarm = MethodChannel('mezmur/alarm');
      final isRinging = await nativeAlarm.invokeMethod<bool>('isAlarmRinging') ?? false;
      if (isRinging) {
        // Native AlarmService is already playing high-priority looping audio on STREAM_ALARM with audio focus!
        return;
      }
    } catch (_) {}
    try {
      _player = AudioPlayer();
      await _player!.setLoopMode(LoopMode.one);
      // Play high-quality bundled church chime alarm
      await _player!.setAsset('assets/audio/alarm.wav').catchError((_) => null);
      await _player!.play();
    } catch (_) {
      // Platform notification handles native sound fallback
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      const nativeAlarm = MethodChannel('mezmur/alarm');
      await nativeAlarm.invokeMethod('stopAlarm');
    } catch (_) {}
    if (_player != null) {
      try {
        await _player!.stop();
        await _player!.dispose();
      } catch (_) {}
      _player = null;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopAlarmSound();
    super.dispose();
  }

  Future<void> _onStop() async {
    await _stopAlarmSound();
    final notif = ref.read(localNotificationsProvider);
    if (widget.programId != null) {
      final notifId = LocalNotifications.programAlarmId(widget.programId!, widget.slot ?? 0);
      await notif.cancel(notifId);
    } else if (widget.reminderId != null) {
      await notif.cancel(widget.reminderId!);
    }
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else if (widget.programId != null) {
        context.go('/programs/${widget.programId}');
      } else {
        context.go('/settings/reminders');
      }
    }
  }

  Future<void> _onSnooze() async {
    await _stopAlarmSound();
    if (widget.programId != null) {
      final notifId = LocalNotifications.programAlarmId(widget.programId!, widget.slot ?? 0);
      await LocalNotifications.snoozeAlarm(notifId, 'alarm:${widget.programId}');
    } else if (widget.reminderId != null) {
      await LocalNotifications.snoozeAlarm(widget.reminderId!, 'alarm:reminder:${widget.reminderId}');
    }
    if (mounted) {
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.isEn ? 'Alarm snoozed for 10 minutes' : 'ማንቂያው ለ10 ደቂቃ አሸልቧል'),
          backgroundColor: AppColors.goldDark,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/hub');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.programId != null) {
      final programAsync = ref.watch(programProvider(widget.programId!));
      return Scaffold(
        backgroundColor: const Color(0xFF140D0E),
        body: SafeArea(
          child: programAsync.when(
            data: (program) => _buildProgramAlarmBody(context, program),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error: (err, _) => _buildFallbackBody(context, err),
          ),
        ),
      );
    }

    // Personal Reminder Alarm
    final reminders = ref.watch(remindersProvider);
    final reminder = widget.reminderId != null
        ? reminders.where((r) => r.notificationId == widget.reminderId).firstOrNull
        : null;

    final displayTitle = widget.title ?? reminder?.title ?? (context.l10n.isEn ? 'Reminder Alarm' : 'የማስታወሻ ማንቂያ');
    final displayNote = widget.note ?? reminder?.note;
    final displayTime = reminder?.remindAt ?? DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF140D0E),
      body: SafeArea(
        child: _buildReminderAlarmBody(context, displayTitle, displayNote, displayTime),
      ),
    );
  }

  Widget _buildReminderAlarmBody(BuildContext context, String title, String? note, DateTime time) {
    final l = context.l10n;
    final fmt = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = l.localeName.startsWith('en');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Pulsing Alarm Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: AppColors.gold,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isEn ? 'MESERETE HIWOT' : 'መሠረተ ሕይወት',
            style: context.serif(18, weight: FontWeight.bold, color: AppColors.gold),
          ),
          const SizedBox(height: 4),
          Text(
            isEn ? 'REMINDER ALARM' : 'የማስታወሻ ማንቂያ',
            style: context.sans(14, weight: FontWeight.w700, color: AppColors.goldLight),
          ),
          const SizedBox(height: 12),
          // Reminder Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.serif(24, weight: FontWeight.bold, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              textAlign: TextAlign.center,
              style: context.sans(14, color: AppColors.cream),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // Date & Time Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF221619),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      fmt.date(time, withWeekday: true),
                      style: context.sans(14, color: AppColors.cream, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      fmt.time(time),
                      style: context.sans(16, color: Colors.white, weight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Stop and Snooze Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFF2C1E21),
                    ),
                    onPressed: _onSnooze,
                    icon: const Icon(Icons.snooze_rounded, size: 24),
                    label: Text(
                      isEn ? 'Snooze (10m)' : 'አሸልብ (10 ደቂቃ)',
                      style: context.sans(15, weight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _onStop,
                    icon: const Icon(Icons.alarm_off_rounded, size: 24),
                    label: Text(
                      isEn ? 'Stop' : 'አቁም',
                      style: context.sans(16, weight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _stopAlarmSound();
              context.go('/settings/reminders');
            },
            icon: const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.goldLight),
            label: Text(
              isEn ? 'View Reminders' : 'ማስታወሻዎችን ተመልከት',
              style: context.sans(14, color: AppColors.goldLight, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgramAlarmBody(BuildContext context, Program program) {
    final l = context.l10n;
    final fmt = Formatters(l, Localizations.localeOf(context).languageCode);
    final isEn = l.localeName.startsWith('en');

    final nextStart = program.upcomingOccurrences.isNotEmpty
        ? program.upcomingOccurrences.first.startsAt
        : program.startsAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.maroon.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: AppColors.gold,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isEn ? 'MESERETE HIWOT' : 'መሠረተ ሕይወት',
            style: context.serif(18, weight: FontWeight.bold, color: AppColors.gold),
          ),
          const SizedBox(height: 4),
          Text(
            isEn ? 'PROGRAM REMINDER ALARM' : 'የመርሐ ግብር ማንቂያ',
            style: context.sans(14, weight: FontWeight.w700, color: AppColors.goldLight),
          ),
          const SizedBox(height: 8),
          Text(
            program.title,
            textAlign: TextAlign.center,
            style: context.serif(24, weight: FontWeight.bold, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF221619),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      fmt.date(nextStart, withWeekday: true),
                      style: context.sans(14, color: AppColors.cream, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      fmt.time(nextStart),
                      style: context.sans(16, color: Colors.white, weight: FontWeight.bold),
                    ),
                  ],
                ),
                if (program.location != null && program.location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 16, color: AppColors.goldLight),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          program.location!,
                          style: context.sans(13, color: AppColors.faint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFF2C1E21),
                    ),
                    onPressed: _onSnooze,
                    icon: const Icon(Icons.snooze_rounded, size: 24),
                    label: Text(
                      isEn ? 'Snooze (10m)' : 'አሸልብ (10 ደቂቃ)',
                      style: context.sans(15, weight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _onStop,
                    icon: const Icon(Icons.alarm_off_rounded, size: 24),
                    label: Text(
                      isEn ? 'Stop' : 'አቁም',
                      style: context.sans(16, weight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _stopAlarmSound();
              if (widget.programId != null) {
                context.go('/programs/${widget.programId}');
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.goldLight),
            label: Text(
              isEn ? 'View Program Details' : 'የመርሐ ግብሩን ሙሉ ዝርዝር ተመልከት',
              style: context.sans(14, color: AppColors.goldLight, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFallbackBody(BuildContext context, Object error) {
    final l = context.l10n;
    final isEn = l.localeName.startsWith('en');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy_rounded, size: 64, color: AppColors.gold),
          const SizedBox(height: 16),
          Text(
            isEn ? 'Program Alarm' : 'የመርሐ ግብር ማንቂያ',
            style: context.serif(22, weight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'This scheduled alarm was triggered, but the program details are currently unavailable offline or may have been modified.'
                : 'ይህ ማንቂያ በሰዓቱ ደርሷል፤ ነገር ግን የመርሐ ግብሩ ዝርዝር ከመስመር ውጭ አልተገኘም ወይም ተቀይሯል።',
            textAlign: TextAlign.center,
            style: context.sans(14, color: AppColors.faint),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
              onPressed: _onStop,
              icon: const Icon(Icons.close_rounded),
              label: Text(isEn ? 'Dismiss' : 'ዝጋ', style: context.sans(16, weight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
