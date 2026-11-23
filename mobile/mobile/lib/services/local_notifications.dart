import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
// latest_all includes alias zones such as Africa/Addis_Ababa (the reduced 'latest' set does not,
// which crashed start-up on Ethiopian phones and stopped push registration).
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';

/// Android notification channels (ids are also used by the backend's FCM payloads).
abstract final class Channels {
  static const defaultId = 'default';
  static const reminders = 'reminders';
  static const programs = 'programs';
  static const borrowing = 'borrowing';
  static const chat = 'chat';
  static const sinksar = 'sinksar';

  /// Program alarms: alarm sound, vibration, full screen on the lock screen, Snooze / Dismiss.
  static const alarms = 'program_alarms';
}

/// Snooze / Dismiss on a program or reminder alarm. Runs in the background too (app closed),
/// so the alarm comes back after [LocalNotifications.snoozeMinutes] without any server.
@pragma('vm:entry-point')
Future<void> onAlarmAction(NotificationResponse r) async {
  if (r.id == null) return;
  if (r.actionId == 'snooze') {
    await LocalNotifications.snoozeAlarm(r.id!, r.payload);
  } else if (r.actionId == 'dismiss') {
    await LocalNotifications.dismissAlarm(r.id!);
  }
}

/// Device-level notifications: personal reminders (scheduled locally, work offline)
/// and foreground display of push messages. Taps are emitted as deep-link payloads.
class LocalNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? _launchPayload;
  bool _ready = false;

  Stream<String> get taps => _taps.stream;

  /// Payload of the notification that launched the app (consumed once).
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  Future<void> init({required String channelName, required String remindersName, required String programsName, required String borrowingName, String? chatName}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(await _localLocation());
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == 'snooze') {
          unawaited(onAlarmAction(r));
          return;
        }
        if (r.actionId == 'dismiss') {
          if (r.id != null) unawaited(LocalNotifications.dismissAlarm(r.id!));
          return;
        }
        if (r.payload != null) _taps.add(r.payload!);
      },
      onDidReceiveBackgroundNotificationResponse: onAlarmAction,
    );
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Re-create the alarm channel so Android updates to the dedicated bundled raw/alarm sound
      try {
        await android.deleteNotificationChannel(channelId: Channels.alarms);
      } catch (_) {}

      for (final c in [
        AndroidNotificationChannel(Channels.defaultId, channelName, importance: Importance.defaultImportance),
        AndroidNotificationChannel(Channels.reminders, remindersName, importance: Importance.high),
        AndroidNotificationChannel(Channels.programs, programsName, importance: Importance.high),
        AndroidNotificationChannel(Channels.borrowing, borrowingName, importance: Importance.high),
        AndroidNotificationChannel(Channels.chat, chatName ?? 'Chat', importance: Importance.high),
        AndroidNotificationChannel(
          Channels.sinksar,
          'የዕለቱ ስንክሳር (Daily Synaxarium)',
          description: 'Daily Synaxarium commemorations & fasting information',
          importance: Importance.high,
          enableVibration: true,
        ),
        // Dedicated alarm: bundled resonant alarm tone on the alarm stream (rings in silent / DND
        // modes the way the clock app does), vibration, maximum importance.
        AndroidNotificationChannel(
          Channels.alarms,
          programsName,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      ]) {
        await android.createNotificationChannel(c);
      }
    }
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _launchPayload = launch!.notificationResponse?.payload;
    _ready = true;
  }

  /// The phone's time zone; never throws (unknown names fall back to East Africa Time, then UTC).
  static Future<tz.Location> _localLocation() async {
    String? name;
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    for (final candidate in [?name, 'Africa/Addis_Ababa', 'Africa/Nairobi']) {
      try {
        return tz.getLocation(candidate);
      } catch (_) {}
    }
    return tz.UTC;
  }

  /// Whether the phone currently allows this app's notifications.
  Future<bool> notificationsEnabled() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final opts = await ios?.checkPermissions();
    return opts?.isEnabled ?? true;
  }

  Future<bool> requestPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  NotificationDetails _details(String channel, String channelName, {String? tag}) => NotificationDetails(
        android: AndroidNotificationDetails(channel, channelName, importance: Importance.high, priority: Priority.high, color: const Color(0xFF6E1423), tag: tag),
        iOS: const DarwinNotificationDetails(),
      );

  /// Program and personal reminder alarm: alarm category, full screen over the lock screen, insistent sound until handled,
  /// Snooze and Dismiss buttons, app colour and icon.
  static NotificationDetails alarmDetails(String channelName, {required String snooze, required String dismiss}) => NotificationDetails(
        android: AndroidNotificationDetails(
          Channels.alarms,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: const RawResourceAndroidNotificationSound('alarm'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
          // FLAG_INSISTENT (4): the sound repeats until the alarm is opened, snoozed or dismissed.
          additionalFlags: Int32List.fromList([4]),
          color: const Color(0xFF6E1423),
          visibility: NotificationVisibility.public,
          autoCancel: false,
          actions: [
            AndroidNotificationAction('snooze', snooze, showsUserInterface: false, cancelNotification: true),
            AndroidNotificationAction('dismiss', dismiss, showsUserInterface: false, cancelNotification: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
      );

  static const snoozeMinutes = 10;
  static const _snoozeBase = 0x7F000000;

  /// Dismiss and clear saved alarm metadata.
  static Future<void> dismissAlarm(int id) async {
    try {
      const nativeAlarm = MethodChannel('mezmur/alarm');
      await nativeAlarm.invokeMethod('stopAlarm');
      await nativeAlarm.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_text:$id');
    } catch (_) {}
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: id);
  }

  /// Re-ring an alarm [snoozeMinutes] later (its text and labels were saved when it was set).
  static Future<void> snoozeAlarm(int id, String? payload) async {
    try {
      const nativeAlarm = MethodChannel('mezmur/alarm');
      await nativeAlarm.invokeMethod('snoozeAlarm', {
        'id': id,
        'payload': payload ?? 'alarm:0',
        'title': 'የመርሐ ግብር ማንቂያ',
        'body': '',
      });
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('alarm_text:$id');
    if (saved == null) return;
    final j = jsonDecode(saved) as Map<String, dynamic>;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(await _localLocation());
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
    final snoozeId = _snoozeBase + (id & 0xFFFFF);
    await prefs.setString('alarm_text:$snoozeId', saved);
    await plugin.zonedSchedule(
      id: snoozeId,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: snoozeMinutes)),
      notificationDetails: alarmDetails('${j['channel']}', snooze: '${j['snooze']}', dismiss: '${j['dismiss']}'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: '${j['title']}',
      body: '${j['body']}',
      payload: payload,
    );
  }

  /// Tray tag of an in-app notification (the server tags its pushes the same way).
  static String messageTag(int notificationId) => 'n$notificationId';

  Future<void> show({required int id, required String title, required String body, String channel = Channels.defaultId, String channelName = 'Notifications', String? payload, String? tag}) async {
    if (!_ready) return;
    await plugin.show(id: tag != null ? 0 : id, title: title, body: body, notificationDetails: _details(channel, channelName, tag: tag), payload: payload);
  }

  /// A notification was read inside the app: remove it from the phone's notification tray.
  Future<void> dismissMessage(int notificationId) async {
    if (!_ready) return;
    try {
      await plugin.cancel(id: 0, tag: messageTag(notificationId));
    } catch (_) {}
  }

  /// The notification list was viewed inside the app: remove every message notification from the
  /// tray (reminders, program alarms and the media player controls stay).
  Future<void> dismissAllMessages() async {
    if (!_ready) return;
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      for (final n in await android.getActiveNotifications()) {
        final tag = n.tag;
        if (tag != null && RegExp(r'^n\d+$').hasMatch(tag)) await plugin.cancel(id: n.id ?? 0, tag: tag);
      }
    } catch (_) {}
  }

  /// Schedule (or re-schedule) a reminder alarm. Uses native exact alarm scheduling, full-screen
  /// intent on lock screen, insistent ringing on the alarm stream, and Stop / Snooze actions.
  Future<void> schedule(Reminder r, {required String channelName, bool asAlarm = true}) async {
    if (!_ready) return;
    await cancel(r.notificationId);
    if (!r.isEnabled || r.deleted) return;
    var when = tz.TZDateTime.from(r.remindAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (r.repeat == 'none' && when.isBefore(now)) return;
    while (r.repeat != 'none' && when.isBefore(now)) {
      when = when.add(r.repeat == 'daily' ? const Duration(days: 1) : const Duration(days: 7));
    }
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? true;

    final details = asAlarm
        ? alarmDetails(channelName, snooze: 'አሸልብ', dismiss: 'አቁም')
        : _details(Channels.reminders, channelName);

    if (asAlarm) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'alarm_text:${r.notificationId}',
          jsonEncode({
            'title': r.title,
            'body': r.note ?? '',
            'channel': channelName,
            'snooze': 'አሸልብ',
            'dismiss': 'አቁም',
          }),
        );
      } catch (_) {}
    }

    try {
      await plugin.zonedSchedule(
        id: r.notificationId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.note,
        payload: 'alarm:reminder:${r.notificationId}',
        matchDateTimeComponents: switch (r.repeat) {
          'daily' => DateTimeComponents.time,
          'weekly' => DateTimeComponents.dayOfWeekAndTime,
          _ => null,
        },
      );
    } catch (e) {
      debugPrint('schedule reminder failed: $e');
    }
  }

  /// Program alarms use ids above every personal reminder id (those are < 2^30):
  /// base + programId × slots + slot, one slot per (upcoming occurrence, reminder offset).
  static const _programAlarmBase = 1 << 30;
  static const _slots = 24;
  static const _maxOccurrences = 6;

  /// Alarm ids of a program's reminders (exposed for tests).
  static int programAlarmId(int programId, int slot) => _programAlarmBase + programId * _slots + slot;

  /// Alarms before each upcoming occurrence of the programs the user is expected at, at the
  /// program's reminder times (2 days / 1 day / 6 hours / 1 hour before) or the times the member
  /// chose for that program. They are set on the phone itself — exact (USE_EXACT_ALARM), so they
  /// ring on time with the app closed, offline, and without any server job — and restored after a
  /// reboot by the plugin's boot receiver. Programs no longer listed lose theirs.
  /// [describe] gives the text for an offset (e.g. "in 1 hour").
  Future<int> syncProgramAlarms(List<Program> programs, {required String title, required String channelName, required String Function(int offset) describe, String snooze = 'Snooze', String dismiss = 'Dismiss', DateTime? now}) async {
    if (!_ready) return 0;
    final wanted = <int>{};
    final prefs = await SharedPreferences.getInstance();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final current = now == null ? tz.TZDateTime.now(tz.local) : tz.TZDateTime.from(now, tz.local);
    for (final p in programs) {
      if (p.status != 'published') continue;
      for (final (slot, alarm) in programAlarms(p, current).indexed) {
        final id = programAlarmId(p.id, slot);
        wanted.add(id);
        final body = [p.title, describe(alarm.offset), if (p.location != null) p.location!].join(' · ');
        try {
          // Native Android exact alarm with WakeLock & Looping AlarmService
          const nativeAlarm = MethodChannel('mezmur/alarm');
          await nativeAlarm.invokeMethod('scheduleAlarm', {
            'id': id,
            'timestampMs': alarm.at.millisecondsSinceEpoch,
            'programId': p.id,
            'title': title,
            'body': body,
            'payload': 'alarm:${p.id}',
          });
        } catch (_) {}

        try {
          // Kept on the phone so Snooze can re-ring it without the app or a connection.
          await prefs.setString('alarm_text:$id', jsonEncode({'title': title, 'body': body, 'channel': channelName, 'snooze': snooze, 'dismiss': dismiss}));
          await plugin.zonedSchedule(
            id: id,
            scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
            notificationDetails: alarmDetails(channelName, snooze: snooze, dismiss: dismiss),
            androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: 'alarm:${p.id}',
          );
        } catch (e) {
          debugPrint('schedule program alarm failed: $e');
        }
      }
    }
    for (final r in await plugin.pendingNotificationRequests()) {
      // Snoozed alarms (their own id range) ring once more and are left alone.
      if (r.id >= _programAlarmBase && r.id < _snoozeBase && !wanted.contains(r.id)) {
        try {
          const nativeAlarm = MethodChannel('mezmur/alarm');
          await nativeAlarm.invokeMethod('cancelAlarm', {'id': r.id});
        } catch (_) {}
        await plugin.cancel(id: r.id);
        await prefs.remove('alarm_text:${r.id}');
      }
    }
    return wanted.length;
  }

  /// The alarms for [p]: each reminder offset before each upcoming occurrence (the server sends
  /// the next few; a one-day program without them uses its start time), still in the future.
  static List<({DateTime at, int offset})> programAlarms(Program p, DateTime now) {
    final starts = p.upcomingOccurrences.isNotEmpty ? p.upcomingOccurrences.map((o) => o.startsAt).take(_maxOccurrences) : [p.startsAt];
    final out = <({DateTime at, int offset})>[];
    for (final s in starts) {
      for (final o in p.effectiveReminderOffsets) {
        final at = s.subtract(Duration(minutes: o));
        if (at.isAfter(now)) out.add((at: at, offset: o));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.take(_slots).toList();
  }

  /// When the alarms for [p] ring.
  static List<DateTime> programAlarmTimes(Program p, DateTime now) => programAlarms(p, now).map((a) => a.at).toList();

  /// Daily optional Sinksar local notification scheduled at a designated morning hour.
  Future<void> scheduleDailySinksarNotification({
    required bool enabled,
    required String title,
    required String body,
    String payload = 'sinksar',
    int hour = 6,
    int minute = 30,
  }) async {
    const int sinksNotificationId = 0x53494E; // 'SIN'
    await cancel(sinksNotificationId);
    if (!enabled || !_ready) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await plugin.zonedSchedule(
        id: sinksNotificationId,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            Channels.sinksar,
            'የዕለቱ ስንክሳር (Daily Synaxarium)',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            color: Color(0xFF6E1423),
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('schedule daily sinksar notification failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (_ready) {
      await plugin.cancel(id: id);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_text:$id');
      } catch (_) {}
    }
  }

  Future<void> cancelAll() async {
    if (_ready) await plugin.cancelAll();
  }
}

final localNotificationsProvider = Provider<LocalNotifications>((ref) => LocalNotifications());
