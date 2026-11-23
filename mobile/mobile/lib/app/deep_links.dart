/// Where a notification about an entity should take the user.
String routeForEntity(
  String? type,
  int? id, {
  String? extra,
  Map<String, dynamic>? data,
}) {
  // If a direct internal route is provided in data, use it (with sanitation)
  if (data != null && data['route'] != null && '${data['route']}'.trim().isNotEmpty) {
    return sanitizeRoute('${data['route']}'.trim());
  }

  // Sinksar & Holy Days
  if (type == 'sinksar' || type == 'holy_day') {
    final date = (extra != null && extra.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(extra))
        ? extra
        : (data?['date'] != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('${data!['date']}'))
            ? '${data['date']}'
            : null;
    return date != null ? '/sinksar/$date' : '/sinksar';
  }

  // Handle quiz attempts / grading complete
  if (type == 'edu_grading' || type == 'edu_quiz_result' || type == 'edu_submission') {
    final attemptId = int.tryParse('${data?['attempt_id'] ?? ''}') ??
        (extra != null && extra.startsWith('attempt:') ? int.tryParse(extra.substring(8)) : null);
    if (attemptId != null && attemptId > 0) {
      return '/edu/attempt/$attemptId';
    }
    if (id != null && id > 0) {
      return '/edu/quiz/$id';
    }
    return '/edu/progress';
  }

  if (type == 'edu_quiz') {
    final attemptId = int.tryParse('${data?['attempt_id'] ?? ''}') ??
        (extra != null && extra.startsWith('attempt:') ? int.tryParse(extra.substring(8)) : null);
    if (attemptId != null && attemptId > 0) {
      return '/edu/attempt/$attemptId';
    }
    if (id != null && id > 0) {
      return '/edu/quiz/$id';
    }
    return '/edu';
  }

  // Learning Materials
  if (type == 'edu_material') {
    final lessonId = int.tryParse('${data?['lesson_id'] ?? ''}') ??
        (extra != null && extra.startsWith('lesson:') ? int.tryParse(extra.substring(7)) : null);
    if (lessonId != null && lessonId > 0) {
      return '/edu/learn/lesson/$lessonId';
    }
    return '/edu/content/materials';
  }

  if (id == null || id <= 0) {
    final r = switch (type) {
      'reminders' => '/programs',
      'program' || 'program_reminder' => '/programs',
      'alarm' || 'program_alarm' => '/programs',
      'attendance' || 'attendance_record' || 'attendance_request' || 'attendance_session' =>
        '/settings/attendance-calendar',
      'choir' => '/settings/me',
      'payment' || 'receipt' || 'payment_receipt' || 'contribution' => '/settings/payments',
      'contribution_receipt' => (data?['admin_review'] == false || data?['target'] == 'member')
          ? '/settings/payments'
          : '/admin/receipt-review',
      'sinksar' || 'holy_day' => '/sinksar',
      'edu' || 'education' => '/edu',
      'edu_magazine' || 'magazine' => '/edu/magazines',
      'edu_class' || 'edu_promotion' || 'edu_course' => '/edu/classes',
      'edu_assignment' => '/edu/assignments',
      'edu_announcement' => '/edu/announcements',
      'edu_score' || 'edu_grading' => '/edu/progress',
      'edu_certificate' => '/edu/more',
      'chat' || 'message' || 'department' => '/settings',
      'project' || 'task' || 'project_task' || 'project_expense' || 'project_suggestion' => '/projects',
      'borrowing' || 'borrowing_due' || 'borrowing_overdue' => '/settings/me',
      'library_request' => '/admin/library-requests',
      'permission_request' => '/admin/permissions',
      'property_request' => '/admin/property-requests',
      _ => '/notifications',
    };
    return sanitizeRoute(r);
  }

  final route = switch (type) {
    // Programs & Alarms
    'program' ||
    'program_reminder' ||
    'program_update' ||
    'program_cancellation' ||
    'attendance' ||
    'attendance_request' ||
    'attendance_status' ||
    'attendance_record' ||
    'attendance_session' =>
      '/programs/$id',

    'alarm' || 'program_alarm' => '/alarm/$id',

    // Mezmur
    'mezmur' || 'audio' || 'lyrics' => '/home/mezmur/$id',
    'category' => '/home/category/$id',
    'page' || 'advertisement' => '/home/page/$id',

    // Chat & Communications
    'chat' || 'department' || 'message' => '/settings/chat/$id',

    // Finance & Contributions
    'payment' || 'receipt' || 'payment_receipt' || 'contribution' => '/settings/payments',
    'contribution_receipt' => (data?['admin_review'] == false || data?['target'] == 'member')
        ? '/settings/payments'
        : '/admin/receipt-review?id=$id',

    // Projects & Tasks
    'project' => '/projects/$id',
    'project_task' || 'task' => '/projects/tasks/$id',
    'project_expense' => '/projects/approvals',
    'project_suggestion' => '/projects/suggestions/$id',

    // Library & Borrowing
    'borrowing' || 'borrowing_due' || 'borrowing_overdue' => '/settings/borrowings/$id',
    'library_request' => '/library-request/$id',

    // Education
    'edu_magazine' || 'magazine' => '/edu/magazine/$id',
    'edu_class' || 'edu_promotion' => '/edu/classes',
    'edu_lesson' => '/edu/learn/lesson/$id',
    'edu_quiz' || 'edu_submission' => '/edu/quiz/$id',
    'edu_assignment' => '/edu/assignment/$id',
    'edu_announcement' => '/edu/announcements',
    'edu_course' => '/edu/course/$id?tab=assessments',
    'edu_assessment' => '/edu/review/assessment/$id',
    'edu_grading' || 'edu_score' => '/edu/progress',
    'edu_certificate' => '/edu/more',

    // Sinksar & Holy Days
    'sinksar' || 'holy_day' => extra != null && extra.isNotEmpty ? '/sinksar/$extra' : '/sinksar',

    // Account & Administration
    'user' || 'choir' => '/settings/me',
    'permission_request' => '/admin/permissions',
    'property_request' => '/admin/property-requests',
    'notification' => '/notifications',

    _ => '/notifications',
  };

  return sanitizeRoute(route);
}

/// Fallback guards: never navigate to removed features (Academic Calendar, Units & Lessons).
String sanitizeRoute(String route) {
  final clean = route.startsWith('/') ? route : '/$route';
  final uri = Uri.tryParse(clean);
  final path = uri?.path ?? clean;
  if (path == '/edu/calendar' || path.startsWith('/edu/calendar/')) {
    return '/edu';
  }
  if (path == '/admin/edu/academic-years' || path.startsWith('/admin/edu/academic-years/')) {
    return '/edu/manage';
  }
  if (path == '/edu/content/units-lessons' || path.startsWith('/edu/content/units-lessons/')) {
    return '/edu/content';
  }
  return clean;
}

/// Parse any notification payload (local, push, deep link, typed payload).
/// Supports:
/// - `route:<internalRoute>`
/// - `n:<notificationId>|route:<internalRoute>`
/// - `n:<notificationId>|<type>:<id>`
/// - `n:<notificationId>|<type>:<id>|key:value|...`
/// - `n:<notificationId>|sinksar:<date>`
/// - `alarm:<programId>`
/// - `alarm:reminder:<reminderId>`
/// - `sinksar:<date>` or `sinksar`
/// - `<type>:<id>`
({String route, int? notificationId}) parsePayload(String payload) {
  final trimmed = payload.trim();
  if (trimmed.isEmpty) return (route: '/notifications', notificationId: null);

  // Direct internal route: route:/alarm/12
  if (trimmed.startsWith('route:')) {
    final r = trimmed.substring(6).trim();
    return (route: sanitizeRoute(r), notificationId: null);
  }

  // Push payload with prefix n:
  if (trimmed.startsWith('n:')) {
    final parts = trimmed.substring(2).split('|');
    final nid = int.tryParse(parts.first);
    if (parts.length <= 1 || parts[1].isEmpty) {
      return (route: '/notifications', notificationId: nid);
    }

    final entityPart = parts[1];
    if (entityPart.startsWith('route:')) {
      final r = entityPart.substring(6).trim();
      return (route: sanitizeRoute(r), notificationId: nid);
    }

    final entity = entityPart.split(':');
    final type = entity.isNotEmpty ? entity.first : null;
    final id = entity.length > 1 ? int.tryParse(entity[1]) : null;
    final extra = entity.length > 1 && id == null ? entity[1] : (entity.length > 2 ? entity[2] : null);

    // Extract any additional key-value parts in the payload
    final data = <String, dynamic>{};
    for (int i = 2; i < parts.length; i++) {
      final seg = parts[i];
      final col = seg.indexOf(':');
      if (col > 0) {
        data[seg.substring(0, col)] = seg.substring(col + 1);
      }
    }

    return (
      route: routeForEntity(type, id, extra: extra, data: data.isNotEmpty ? data : null),
      notificationId: nid
    );
  }

  // Program or Reminder Alarm direct payload
  if (trimmed.startsWith('alarm:')) {
    final rest = trimmed.substring(6);
    if (rest.startsWith('reminder:')) {
      final rid = int.tryParse(rest.substring(9));
      return (route: rid != null ? '/alarm/$rid?type=reminder' : '/settings/reminders', notificationId: null);
    }
    final pid = int.tryParse(rest);
    return (route: pid != null ? '/alarm/$pid' : '/programs', notificationId: null);
  }

  // Sinksar direct payload
  if (trimmed.startsWith('sinksar:')) {
    final d = trimmed.substring(8).trim();
    return (route: d.isNotEmpty ? '/sinksar/$d' : '/sinksar', notificationId: null);
  }
  if (trimmed == 'sinksar' || trimmed == 'holy_day') {
    return (route: '/sinksar', notificationId: null);
  }

  // Standard <type>:<id>
  final p = trimmed.split(':');
  final type = p.first;
  final id = p.length > 1 ? int.tryParse(p[1]) : null;
  final extra = p.length > 1 && id == null ? p[1] : (p.length > 2 ? p[2] : null);

  return (route: routeForEntity(type, id, extra: extra), notificationId: null);
}
