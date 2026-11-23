import 'json.dart';

class Program {
  const Program({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.location,
    required this.startsAt,
    required this.endsAt,
    this.requiresRegistration = false,
    this.requiresAttendance = true,
    this.capacity,
    this.audience = 'participants',
    this.status = 'published',
    this.participantCount = 0,
    this.myParticipation,
    this.myAttendance,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 1,
    this.reminderTitle,
    this.reminderBody,
    this.pageId,
    this.permission,
    this.eventType,
    this.category,
    this.recurrence = 'once',
    this.monthlyRule,
    this.recurrenceUntil,
    this.nextOccurrence,
    this.upcomingOccurrences = const [],
    this.memberGroups = const [],
    this.ethiopianDays = const [],
    this.isAdditional = false,
    this.countsForSelection = true,
    this.hasEndTime = true,
    this.isMandatoryReminder = false,
    this.onTimeMinutes,
    this.lateMinutes,
    this.reminderOffsets = defaultReminderOffsets,
    this.myReminderOffsets,
    this.reminderIntervalDays,
    this.reminderIntervalStart,
    this.classIds = const [],
    this.ordinalWeeks = const [],
    this.recurringWeekdays = const [],
    this.isEducation = false,
    this.scheduleId,
  });

  /// Every-N-days reminder (15 by policy) from [reminderIntervalStart]; null = off.
  final int? reminderIntervalDays;
  final DateTime? reminderIntervalStart;

  /// The reminder choices (minutes before the start): 2 days, 1 day, 6 hours, 1 hour.
  static const reminderChoices = [2880, 1440, 360, 60];
  static const defaultReminderOffsets = [1440, 60];

  final int id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? location;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool requiresRegistration;
  final bool requiresAttendance;
  final int? capacity;
  final String audience;
  final String status;
  final int participantCount;
  final String? myParticipation; // invited | registered
  final String? myAttendance; // present | late | absent | excused
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final String? reminderTitle;
  final String? reminderBody;
  final int? pageId;

  /// The signed-in user's absence-permission state (program detail only).
  final ProgramPermission? permission;

  /// Special events only: wedding | holiday | memorial | celebration | other.
  final String? eventType;

  final ProgramCategory? category;

  /// once (one day) | weekly | monthly.
  final String recurrence;

  /// Monthly programs: day_of_month (same date) | nth_weekday (e.g. 2nd Sunday).
  final String? monthlyRule;

  /// Last day a recurring program repeats (null = no end).
  final DateTime? recurrenceUntil;

  /// The next occurrence that has not ended (null when the series is over).
  final Occurrence? nextOccurrence;

  /// A few upcoming occurrences — local alarms are scheduled from these.
  final List<Occurrence> upcomingOccurrences;

  /// Member groups expected at the program (children / youth_adult / married); empty = everyone.
  final List<String> memberGroups;

  /// recurrence = ethiopian_days: the days of every Ethiopian month (e.g. ሰርክ 1, 10, 19).
  final List<int> ethiopianDays;

  /// An additional (extra) session; whether it counts in holiday selections by default.
  final bool isAdditional;
  final bool countsForSelection;

  /// false: the program has no end time (it runs until the end of its day).
  final bool hasEndTime;

  /// Whether reminders are enforced administratively for this program.
  final bool isMandatoryReminder;

  /// Education program linkage: classes served by this program.
  final List<int> classIds;
  final List<int> ordinalWeeks;
  final List<int> recurringWeekdays;
  final bool isEducation;
  final int? scheduleId;

  /// Attendance window of this program (null = the general rule): on time up to
  /// [onTimeMinutes] after the start, then late for [lateMinutes] more.
  final int? onTimeMinutes;
  final int? lateMinutes;

  /// Reminders the program sends before each occurrence (minutes before the start).
  final List<int> reminderOffsets;

  /// The member's own reminder choice for this program (null = the program's reminders).
  final List<int>? myReminderOffsets;

  /// The alarms this phone sets for the program.
  List<int> get effectiveReminderOffsets {
    if (isMandatoryReminder) {
      final offsets = (myReminderOffsets != null && myReminderOffsets!.isNotEmpty)
          ? myReminderOffsets!
          : (reminderOffsets.isNotEmpty ? reminderOffsets : defaultReminderOffsets);
      return offsets;
    }
    return !reminderEnabled && myReminderOffsets == null
        ? const []
        : (myReminderOffsets ?? reminderOffsets);
  }

  bool get isRecurring => recurrence != 'once';

  /// When to show the program: its next occurrence, else the (first) date.
  DateTime get displayStart => nextOccurrence?.startsAt ?? startsAt;
  DateTime get displayEnd => nextOccurrence?.endsAt ?? endsAt;

  /// General programs are for everyone; special events are for invited people only.
  bool get isSpecial => audience == 'participants';

  bool get isPast => nextOccurrence == null ? endsAt.isBefore(DateTime.now()) : false;
  bool get isFull => capacity != null && participantCount >= capacity! && myParticipation == null;

  factory Program.fromJson(Json j) {
    final r = asJson(j['reminder']);
    return Program(
      id: asIntOr(j['id']),
      title: asStr(j['title']) ?? '',
      description: asStr(j['description']),
      imageUrl: asStr(j['image_url']),
      location: asStr(j['location']),
      startsAt: asDate(j['starts_at']) ?? DateTime.now(),
      endsAt: asDate(j['ends_at']) ?? DateTime.now(),
      requiresRegistration: asBool(j['requires_registration']),
      requiresAttendance: asBool(j['requires_attendance']),
      capacity: asInt(j['capacity']),
      audience: asStr(j['audience']) ?? 'all',
      status: asStr(j['status']) ?? 'published',
      participantCount: asIntOr(j['participant_count']),
      myParticipation: asStr(j['my_participation']),
      myAttendance: asStr(j['my_attendance']),
      reminderEnabled: r.isEmpty || asBool(r['enabled']),
      reminderDaysBefore: asIntOr(r['days_before'], 1),
      reminderTitle: asStr(r['title']),
      reminderBody: asStr(r['body']),
      pageId: asInt(j['page_id']),
      permission: j['permission'] is Map ? ProgramPermission.fromJson(asJson(j['permission'])) : null,
      eventType: asStr(j['event_type']),
      category: j['category'] is Map ? ProgramCategory.fromJson(asJson(j['category'])) : null,
      recurrence: asStr(j['recurrence']) ?? 'once',
      ethiopianDays: asValues(j['ethiopian_days'], (e) => asIntOr(e)),
      isAdditional: asBool(j['is_additional']),
      countsForSelection: j['counts_for_selection'] == null || asBool(j['counts_for_selection']),
      hasEndTime: j['has_end_time'] == null || asBool(j['has_end_time']),
      isMandatoryReminder: asBool(j['is_mandatory_reminder']) || asBool(j['reminders_enforce']) || asBool(r['is_mandatory_reminder']) || asBool(r['enforce']),
      monthlyRule: asStr(j['monthly_rule']),
      recurrenceUntil: asDate(j['recurrence_until']),
      nextOccurrence: j['next_occurrence'] is Map ? Occurrence.fromJson(asJson(j['next_occurrence'])) : null,
      upcomingOccurrences: asJsonList(j['upcoming_occurrences']).map(Occurrence.fromJson).toList(),
      memberGroups: asValues(j['member_groups'], (e) => '$e'),
      onTimeMinutes: asInt(asJson(j['attendance_window'])['on_time_minutes']),
      lateMinutes: asInt(asJson(j['attendance_window'])['late_minutes']),
      reminderOffsets: r['offsets'] is List ? asValues(r['offsets'], (e) => asIntOr(e)) : defaultReminderOffsets,
      myReminderOffsets: j['my_reminder_offsets'] is List ? asValues(j['my_reminder_offsets'], (e) => asIntOr(e)) : null,
      reminderIntervalDays: asInt(r['interval_days']),
      reminderIntervalStart: asDate(r['interval_start']),
      classIds: asValues(j['class_ids'], (e) => asIntOr(e)),
      ordinalWeeks: asValues(j['ordinal_weeks'], (e) => asIntOr(e)),
      recurringWeekdays: asValues(j['recurring_weekdays'], (e) => asIntOr(e)),
      isEducation: asBool(j['is_education']),
      scheduleId: asInt(j['schedule_id']),
    );
  }
}

/// One dated instance of a (possibly recurring) program.
class Occurrence {
  const Occurrence({required this.date, required this.startsAt, required this.endsAt});
  final String date; // YYYY-MM-DD (local)
  final DateTime startsAt;
  final DateTime endsAt;

  factory Occurrence.fromJson(Json j) => Occurrence(
        date: asStr(j['date']) ?? '',
        startsAt: asDate(j['starts_at']) ?? DateTime.now(),
        endsAt: asDate(j['ends_at']) ?? DateTime.now(),
      );
}

/// Configurable program category (General, Education, Mezmur …).
class ProgramCategory {
  const ProgramCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.color,
    this.isActive = true,
    this.isEducation = false,
    this.displayOrder = 0,
    this.reminderOffsets,
    this.reminderIntervalDays,
  });
  final int id;
  final String name;
  final String? nameEn;
  final String? color; // #RRGGBB
  final bool isActive;
  final bool isEducation;
  final int displayOrder;
  /// Reminder rules of this program type: what new programs of the type start with (null = general defaults).
  final List<int>? reminderOffsets;
  final int? reminderIntervalDays;

  String label(String languageCode) => languageCode == 'en' && (nameEn?.isNotEmpty ?? false) ? nameEn! : name;

  factory ProgramCategory.fromJson(Json j) => ProgramCategory(
        id: asIntOr(j['id']),
        name: asStr(j['name']) ?? '',
        nameEn: asStr(j['name_en']),
        color: asStr(j['color']),
        isActive: j['is_active'] == null || asBool(j['is_active']),
        isEducation: asBool(j['is_education']) ||
            (asStr(j['name'])?.contains('ትምህርት') ?? false) ||
            (asStr(j['name_en'])?.toLowerCase().contains('education') ?? false),
        displayOrder: asIntOr(j['display_order']),
        reminderOffsets: j['reminder_offsets'] is List ? asValues(j['reminder_offsets'], (e) => asIntOr(e)) : null,
        reminderIntervalDays: asInt(j['reminder_interval_days']),
      );
}

/// Attendance statistics (always computed by the server).
class AttendanceStats {
  const AttendanceStats({this.total = 0, this.attended = 0, this.late = 0, this.excused = 0, this.absent = 0, this.percentage, this.upcoming = 0});
  final int total;
  final int attended;
  final int late;
  final int excused;
  final int absent;
  final double? percentage;
  final int upcoming;

  factory AttendanceStats.fromJson(Json j) => AttendanceStats(
        total: asIntOr(j['total_programs']),
        attended: asIntOr(j['attended']),
        late: asIntOr(j['late']),
        excused: asIntOr(j['excused']),
        absent: asIntOr(j['absent']),
        percentage: j['percentage'] == null ? null : asDouble(j['percentage']),
        upcoming: asIntOr(j['upcoming']),
      );
}

/// One program occurrence on a member's calendar.
class CalendarEntry {
  const CalendarEntry({
    required this.programId,
    required this.title,
    this.location,
    this.category,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.attendedAt,
    this.signatureStatus,
    this.recorderName,
    this.signatureId,
    this.elapsedSeconds,
    this.notes,
  });
  final int programId;
  final String title;
  final String? location;
  final ProgramCategory? category;
  final String date;
  final DateTime startsAt;
  final DateTime endsAt;

  /// present | late | excused | absent | today | upcoming | suspended
  final String status;
  final DateTime? attendedAt;
  final String? signatureStatus;
  final String? recorderName;
  final int? signatureId;
  final int? elapsedSeconds;
  final String? notes;

  factory CalendarEntry.fromJson(Json j) => CalendarEntry(
        programId: asIntOr(j['program_id']),
        title: asStr(j['title']) ?? '',
        location: asStr(j['location']),
        category: j['category'] is Map ? ProgramCategory.fromJson(asJson(j['category'])) : null,
        date: asStr(j['date']) ?? '',
        startsAt: asDate(j['starts_at']) ?? DateTime.now(),
        endsAt: asDate(j['ends_at']) ?? DateTime.now(),
        status: asStr(j['status']) ?? 'upcoming',
        attendedAt: asDate(j['attended_at']),
        signatureStatus: asStr(j['signature_status']),
        recorderName: asStr(j['recorder_name']),
        signatureId: asInt(j['signature_id']),
        elapsedSeconds: asInt(j['elapsed_seconds']),
        notes: asStr(j['notes']),
      );
}

class AttendanceCalendar {
  const AttendanceCalendar({required this.days, required this.stats});

  /// date (YYYY-MM-DD) → the day's colour state and its occurrences.
  final Map<String, ({String state, List<CalendarEntry> entries})> days;
  final AttendanceStats stats;

  factory AttendanceCalendar.fromJson(Json j) => AttendanceCalendar(
        days: {
          for (final d in asJsonList(j['days']))
            asStr(d['date']) ?? '': (state: asStr(d['state']) ?? 'upcoming', entries: asJsonList(d['occurrences']).map(CalendarEntry.fromJson).toList()),
        },
        stats: AttendanceStats.fromJson(asJson(j['stats'])),
      );
}

/// Absence permission for one program: status, deadline and the user's quota usage.
class ProgramPermission {
  const ProgramPermission({
    this.enabled = true,
    this.status,
    this.reason,
    this.reviewNote,
    this.deadlineAt,
    this.canRequest = false,
    this.blockedReason,
    this.canCancel = false,
    this.monthUsed = 0,
    this.monthlyLimit,
    this.quarterUsed = 0,
    this.quarterlyLimit,
  });

  final bool enabled;
  final String? status; // pending | approved | rejected
  final String? reason;
  final String? reviewNote;
  final DateTime? deadlineAt;
  final bool canRequest;
  final String? blockedReason;
  final bool canCancel;
  final int monthUsed;
  final int? monthlyLimit;
  final int quarterUsed;
  final int? quarterlyLimit;

  factory ProgramPermission.fromJson(Json j) => ProgramPermission(
        enabled: j['enabled'] == null || asBool(j['enabled']),
        status: asStr(j['status']),
        reason: asStr(j['reason']),
        reviewNote: asStr(j['review_note']),
        deadlineAt: asDate(j['deadline_at']),
        canRequest: asBool(j['can_request']),
        blockedReason: asStr(j['blocked_reason']),
        canCancel: asBool(j['can_cancel']),
        monthUsed: asIntOr(j['month_used']),
        monthlyLimit: asInt(j['monthly_limit']),
        quarterUsed: asIntOr(j['quarter_used']),
        quarterlyLimit: asInt(j['quarterly_limit']),
      );
}

/// Admin view of one permission request.
class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.status,
    this.reason,
    this.reviewNote,
    this.createdAt,
    required this.userId,
    required this.fullName,
    this.phone,
    required this.programId,
    required this.programTitle,
    this.startsAt,
    this.monthUsed = 0,
    this.quarterUsed = 0,
    this.cancelReason,
    this.cancelledByName,
    this.cancelledAt,
  });

  final int id;
  final String status;
  final String? reason;
  final String? reviewNote;
  /// An approval cancelled by an administrator because it was given by mistake.
  final String? cancelReason;
  final String? cancelledByName;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final int userId;
  final String fullName;
  final String? phone;
  final int programId;
  final String programTitle;
  final DateTime? startsAt;
  final int monthUsed;
  final int quarterUsed;

  factory PermissionRequest.fromJson(Json j) => PermissionRequest(
        id: asIntOr(j['id']),
        status: asStr(j['status']) ?? 'pending',
        reason: asStr(j['reason']),
        reviewNote: asStr(j['review_note']),
        createdAt: asDate(j['created_at']),
        userId: asIntOr(j['user_id']),
        fullName: asStr(j['full_name']) ?? '',
        phone: asStr(j['phone']),
        programId: asIntOr(j['program_id']),
        programTitle: asStr(j['program_title']) ?? '',
        startsAt: asDate(j['starts_at']),
        monthUsed: asIntOr(j['month_used']),
        quarterUsed: asIntOr(j['quarter_used']),
        cancelReason: asStr(j['cancel_reason']),
        cancelledByName: asStr(j['cancelled_by_name']),
        cancelledAt: asDate(j['cancelled_at']),
      );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.status,
    this.attendedAt,
    required this.programId,
    required this.programTitle,
    this.startsAt,
    this.location,
    this.memberName,
    this.calendarDate,
    this.signatureIndicator,
    this.actualTime,
    this.signatureUrl,
  });
  final int id;
  final String status;
  final DateTime? attendedAt;
  final int programId;
  final String programTitle;
  final DateTime? startsAt;
  final String? location;
  final String? memberName;
  final String? calendarDate;
  final String? signatureIndicator;
  final String? actualTime;
  final String? signatureUrl;

  factory AttendanceRecord.fromJson(Json j) => AttendanceRecord(
        id: asIntOr(j['id']),
        status: asStr(j['status']) ?? 'present',
        attendedAt: asDate(j['attended_at']),
        programId: asIntOr(j['program_id']),
        programTitle: asStr(j['program_title']) ?? asStr(j['program_name']) ?? '',
        startsAt: asDate(j['starts_at']),
        location: asStr(j['location']),
        memberName: asStr(j['member_name']),
        calendarDate: asStr(j['calendar_date']),
        signatureIndicator: asStr(j['signature_indicator']) ?? asStr(j['signature_status']),
        actualTime: asStr(j['actual_time']),
        signatureUrl: asStr(j['signature_url']),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.entityType,
    this.entityId,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String? entityType;
  final int? entityId;
  final Json data;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: asIntOr(j['id']),
        type: asStr(j['type']) ?? 'system',
        title: asStr(j['title']) ?? '',
        body: asStr(j['body']) ?? '',
        entityType: asStr(j['entity_type']),
        entityId: asInt(j['entity_id']),
        data: j['data'] is Map ? asJson(j['data']) : const {},
        isRead: asBool(j['is_read']),
        createdAt: asDate(j['created_at']),
      );

  AppNotification markRead() =>
      AppNotification(id: id, type: type, title: title, body: body, entityType: entityType, entityId: entityId, data: data, isRead: true, createdAt: createdAt);
}

class Reminder {
  const Reminder({
    required this.clientUuid,
    this.serverId,
    this.programId,
    this.borrowingId,
    required this.title,
    this.note,
    required this.remindAt,
    this.repeat = 'none',
    this.isEnabled = true,
    this.updatedAt,
    this.deleted = false,
    required this.notificationId,
  });

  final String clientUuid;
  final int? serverId;
  final int? programId;
  final int? borrowingId;
  final String title;
  final String? note;
  final DateTime remindAt;
  final String repeat;
  final bool isEnabled;
  final DateTime? updatedAt;
  final bool deleted;
  final int notificationId;

  Reminder copyWith({String? title, String? note, DateTime? remindAt, String? repeat, bool? isEnabled, DateTime? updatedAt, int? serverId, bool? deleted}) =>
      Reminder(
        clientUuid: clientUuid,
        serverId: serverId ?? this.serverId,
        programId: programId,
        borrowingId: borrowingId,
        title: title ?? this.title,
        note: note ?? this.note,
        remindAt: remindAt ?? this.remindAt,
        repeat: repeat ?? this.repeat,
        isEnabled: isEnabled ?? this.isEnabled,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        notificationId: notificationId,
      );

  Map<String, Object?> toRow() => {
        'client_uuid': clientUuid,
        'server_id': serverId,
        'program_id': programId,
        'borrowing_id': borrowingId,
        'title': title,
        'note': note,
        'remind_at': remindAt.toUtc().toIso8601String(),
        'repeat': repeat,
        'is_enabled': isEnabled ? 1 : 0,
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'deleted': deleted ? 1 : 0,
        'notification_id': notificationId,
      };

  factory Reminder.fromRow(Map<String, Object?> r) => Reminder(
        clientUuid: r['client_uuid'] as String,
        serverId: r['server_id'] as int?,
        programId: r['program_id'] as int?,
        borrowingId: r['borrowing_id'] as int?,
        title: r['title'] as String,
        note: r['note'] as String?,
        remindAt: DateTime.parse(r['remind_at'] as String).toLocal(),
        repeat: r['repeat'] as String,
        isEnabled: r['is_enabled'] == 1,
        updatedAt: DateTime.tryParse('${r['updated_at']}')?.toLocal(),
        deleted: r['deleted'] == 1,
        notificationId: r['notification_id'] as int,
      );

  /// Payload for the backend (create / update / sync).
  Json toApi() => {
        'client_uuid': clientUuid,
        'program_id': ?programId,
        'borrowing_id': ?borrowingId,
        'title': title,
        'note': note,
        'remind_at': remindAt.toUtc().toIso8601String(),
        'repeat': repeat,
        'is_enabled': isEnabled,
      };
}

class BorrowingItemRef {
  const BorrowingItemRef({required this.id, required this.name, this.code, this.imageUrl});
  final int id;
  final String name;
  final String? code;
  final String? imageUrl;
}

class Borrowing {
  const Borrowing({
    required this.id,
    required this.item,
    required this.quantity,
    this.borrowedOn,
    this.dueOn,
    required this.status,
    required this.deadlineState,
    this.daysRemaining,
    this.daysOverdue,
    this.returnedOn,
    this.returnedQuantity = 0,
    this.returnCondition,
    this.fineAmount = 0,
    this.fineCurrency = 'ETB',
    this.fineStatus = 'none',
    this.fineOverridden = false,
    this.fineOverrideReason,
    this.signed = false,
    this.signedAt,
    this.notes,
    this.userId,
    this.userName,
    this.userPhone,
    this.batchId,
    this.issuedByName,
    this.returnedToName,
    this.returnNotes,
  });

  final int id;
  final BorrowingItemRef item;
  final int quantity;
  final String? borrowedOn;
  final String? dueOn;
  final String status;
  final String deadlineState; // ok | due_soon | due_today | overdue | returned | lost | partially_returned
  final int? daysRemaining;
  final int? daysOverdue;
  final String? returnedOn;
  final int returnedQuantity;
  final String? returnCondition;
  final double fineAmount;
  final String fineCurrency;
  final String fineStatus;
  final bool fineOverridden;
  final String? fineOverrideReason;
  final bool signed;
  final DateTime? signedAt;
  final String? notes;
  final int? userId;
  final String? userName;
  final String? userPhone;
  final int? batchId;
  final String? issuedByName;
  final String? returnedToName;
  final String? returnNotes;

  bool get isOpen => status == 'active' || status == 'partially_returned';
  int get outstanding => quantity - returnedQuantity;

  factory Borrowing.fromJson(Json j) {
    final item = asJson(j['item']);
    final fine = asJson(j['fine']);
    final user = asJson(j['user']);
    return Borrowing(
      id: asIntOr(j['id']),
      item: BorrowingItemRef(id: asIntOr(item['id']), name: asStr(item['name']) ?? '', code: asStr(item['code']), imageUrl: asStr(item['image_url'])),
      quantity: asIntOr(j['quantity'], 1),
      borrowedOn: asStr(j['borrowed_on']),
      dueOn: asStr(j['due_on']),
      status: asStr(j['status']) ?? 'active',
      deadlineState: asStr(j['deadline_state']) ?? 'ok',
      daysRemaining: asInt(j['days_remaining']),
      daysOverdue: asInt(j['days_overdue']),
      returnedOn: asStr(j['returned_on']),
      returnedQuantity: asIntOr(j['returned_quantity']),
      returnCondition: asStr(j['return_condition']),
      fineAmount: asDouble(fine['amount']),
      fineCurrency: asStr(fine['currency']) ?? 'ETB',
      fineStatus: asStr(fine['status']) ?? 'none',
      fineOverridden: asBool(fine['overridden']),
      fineOverrideReason: asStr(fine['override_reason']),
      signed: asBool(j['signed']),
      signedAt: asDate(j['signed_at']),
      notes: asStr(j['notes']),
      userId: asInt(user['id']),
      userName: asStr(user['full_name']),
      userPhone: asStr(user['phone']),
      batchId: asInt(j['batch_id']),
      issuedByName: asStr(j['issued_by_name']),
      returnedToName: asStr(j['returned_to_name']),
      returnNotes: asStr(j['return_notes']),
    );
  }
}
