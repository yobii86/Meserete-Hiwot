import 'dart:convert';

import '../core/network/api_client.dart';
import '../core/storage/local_prefs.dart';
import '../models/activity.dart';
import '../models/json.dart';
import '../models/user.dart';

/// Programs, registration and the signed-in user's attendance.
class ProgramRepository {
  ProgramRepository(this._api);
  final ApiClient _api;

  Future<Paged<Program>> list({String scope = 'upcoming', bool mine = false, String? q, int? categoryId, int page = 1, int? limit}) => _api.getPage('/programs', Program.fromJson,
      page: page, limit: limit, query: {'scope': mine ? 'all' : scope, 'mine': mine ? 'true' : null, 'q': q, 'category_id': categoryId});

  Future<Program> get(int id) => _api.get('/programs/$id', parse: (d) => Program.fromJson(asJson(d)));

  Future<Program> requestPermission(int id, {String? reason}) =>
      _api.post('/programs/$id/permission', body: {'reason': ?reason}, parse: (d) => Program.fromJson(asJson(d)));

  /// The member's own reminders for a program (minutes before; null = the program's reminders).
  Future<Program> setMyReminders(int id, List<int>? offsets) =>
      _api.put('/programs/$id/my-reminders', body: {'offsets': offsets}, parse: (d) => Program.fromJson(asJson(d)));

  Future<Program> cancelPermission(int id) => _api.delete('/programs/$id/permission', parse: (d) => Program.fromJson(asJson(d)));

  Future<Paged<AttendanceRecord>> myAttendance({int page = 1}) => _api.getPage('/attendance/me', AttendanceRecord.fromJson, page: page);

  /// My attendance at one program: every date (recurring programs) and the totals.
  Future<Json> myProgramAttendance(int id) => _api.get('/programs/$id/my-attendance', parse: asJson);

  /// Program categories (filters, calendar, statistics).
  Future<List<ProgramCategory>> categories() => _api.get('/programs/categories', parse: (d) => asJsonList(d).map(ProgramCategory.fromJson).toList());

  /// Unified yearly/monthly/weekly/daily/agenda calendar between two dates (YYYY-MM-DD).
  Future<List<Json>> calendar({required String from, required String to, int? categoryId}) =>
      _api.get('/programs/calendar', query: {'from': from, 'to': to, 'category_id': categoryId}, parse: asJsonList);

  /// My attendance calendar between two dates (YYYY-MM-DD): one entry per day with programs.
  Future<AttendanceCalendar> myCalendar({required String from, required String to, int? categoryId}) =>
      _api.get('/attendance/me/calendar', query: {'from': from, 'to': to, 'category_id': categoryId}, parse: (d) => AttendanceCalendar.fromJson(asJson(d)));

  /// Member's own yearly summary & 13 Ethiopian months breakdown.
  Future<Json> myYearlySummary({int? year}) =>
      _api.get('/attendance/my-yearly-summary', query: {'year': year}, parse: asJson);

  /// The same calendar for another member (attendance admins).
  Future<AttendanceCalendar> userCalendar(int userId, {required String from, required String to, int? categoryId}) =>
      _api.get('/attendance/users/$userId/calendar', query: {'from': from, 'to': to, 'category_id': categoryId}, parse: (d) => AttendanceCalendar.fromJson(asJson(d)));
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<Paged<AppNotification>> list({bool unreadOnly = false, int page = 1}) =>
      _api.getPage('/notifications', AppNotification.fromJson, page: page, query: {'unread': unreadOnly ? 'true' : null});

  Future<int> unreadCount() => _api.get('/notifications/unread-count', parse: (d) => asIntOr(asJson(d)['unread']));

  Future<void> markRead(int id) => _api.post<void>('/notifications/$id/read');

  Future<void> markAllRead() => _api.post<void>('/notifications/read-all');
}

class BorrowingRepository {
  BorrowingRepository(this._api);
  final ApiClient _api;

  Future<Paged<Borrowing>> mine({String? status, String? domain, int page = 1}) =>
      _api.getPage('/borrowings/me', Borrowing.fromJson, page: page, query: {'status': status, 'domain': domain});

  Future<Borrowing> mineOne(int id) => _api.get('/borrowings/me/$id', parse: (d) => Borrowing.fromJson(asJson(d)));

  Future<List<int>> signature(int id) => _api.bytes('/borrowings/$id/signature');
}

/// Profile, server-side preferences (cached for offline) and FCM tokens.
class AccountRepository {
  AccountRepository(this._api, this._prefs);
  final ApiClient _api;
  final LocalPrefs _prefs;

  // ---- sign-in sessions ("delete" = revoke the session; the account is never touched) ----
  Future<List<Json>> sessions() => _api.get('/me/sessions', parse: asJsonList);
  Future<void> revokeSession(String id) => _api.delete<void>('/me/sessions/$id');
  Future<int> revokeOtherSessions() => _api.post('/me/sessions/revoke-others', parse: (d) => asIntOr(asJson(d)['revoked']));
  Future<void> revokeAllSessions() => _api.post<void>('/me/sessions/revoke-all');

  // ---- notification preferences: per topic, push / email (enforced by the server) ----
  Future<Json> notificationPreferences() => _api.get('/me/notification-preferences', parse: asJson);
  Future<Json> updateNotificationPreferences(Json body) => _api.put('/me/notification-preferences', body: body, parse: asJson);

  Future<AppUser> updateProfile({String? fullName, String? phone, String? email}) => _api.patch('/me',
      body: {'full_name': ?fullName, 'phone': ?phone, 'email': email},
      parse: (d) => AppUser.fromJson(asJson(d)));

  Future<AppUser> uploadAvatar(String path) => _api.upload('/me/avatar', filePath: path, parse: (d) => AppUser.fromJson(asJson(d)));

  Future<void> removeAvatar() => _api.delete<void>('/me/avatar');

  /// Ask an administrator to change my details (only what differs is sent on).
  Future<ProfileChangeRequest> requestProfileChange(Json body) => _api.post('/me/change-request', body: body, parse: (d) => ProfileChangeRequest.fromJson(asJson(d)));
  Future<List<ProfileChangeRequest>> myChangeRequests() => _api.get('/me/change-requests', parse: (d) => asList(d, ProfileChangeRequest.fromJson));
  Future<AppUser> cancelChangeRequest() => _api.delete('/me/change-request', parse: (d) => AppUser.fromJson(asJson(d)));

  /// One-time deep link (`https://t.me/<bot>?start=<token>`) that binds this account to Telegram.
  Future<String> telegramLink() => _api.post('/me/telegram/link', parse: (d) => asStr(asJson(d)['url']) ?? '');

  Future<AppUser> telegramUnlink() => _api.delete('/me/telegram', parse: (d) => AppUser.fromJson(asJson(d)));

  Future<Json> telegramStatus() => _api.get('/me/telegram/status', parse: asJson);

  /// Version check used for optional / forced updates.
  Future<Json> versionCheck(int versionCode) => _api.get('/app/version', query: {'platform': 'android', 'version_code': versionCode}, parse: asJson);

  UserPreferences? cachedPreferences() {
    final s = _prefs.cachedPreferences;
    return s == null ? null : UserPreferences.fromJson(asJson(jsonDecode(s)));
  }

  Future<UserPreferences> preferences() async {
    final p = await _api.get('/me/preferences', parse: (d) => UserPreferences.fromJson(asJson(d)));
    await _prefs.setCachedPreferences(jsonEncode(p.toJson()));
    return p;
  }

  Future<UserPreferences> savePreferences(UserPreferences p) async {
    final body = p.toJson()..remove('updated_at');
    final saved = await _api.put('/me/preferences', body: body, parse: (d) => UserPreferences.fromJson(asJson(d)));
    await _prefs.setCachedPreferences(jsonEncode(saved.toJson()));
    return saved;
  }

  Future<void> cachePreferences(UserPreferences p) => _prefs.setCachedPreferences(jsonEncode(p.toJson()));


  Future<void> registerFcmToken(String token, String platform) =>
      _api.post<void>('/me/fcm-tokens', body: {'token': token, 'platform': platform});

  Future<void> removeFcmToken(String token) => _api.delete<void>('/me/fcm-tokens', body: {'token': token});
}
