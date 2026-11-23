import '../core/network/api_client.dart';
import '../models/json.dart';

/// Department administration stage: department administrators, attendance rules / closure /
/// corrections / occurrence changes, property requests, direct borrowing, holiday selections and
/// wedding ceremony services.
class StageRepository {
  StageRepository(this._api);
  final ApiClient _api;

  // ---- department administrators (member accounts with admin roles) ----
  Future<List<Json>> departmentAdmins(int departmentId) => _api.get('/departments/$departmentId/admins', parse: asJsonList);
  Future<List<Json>> allDepartmentAdmins() => _api.get('/departments/admins', parse: asJsonList);
  Future<Json> adminRolesOf(int userId) => _api.get('/departments/admins/of-user/$userId', parse: asJson);
  Future<Json> setDepartmentAdminRoles(int departmentId, int userId, List<int> roleIds, {String? reason}) =>
      _api.put('/departments/$departmentId/admins/$userId', body: {'role_ids': roleIds, 'reason': ?reason}, parse: asJson);
  Future<Json> setExtraPermissions(int userId, List<String> permissions, {String? reason, List<String>? revoked}) =>
      _api.put('/departments/admins/of-user/$userId/permissions', body: {'permissions': permissions, 'reason': ?reason, 'revoked_permissions': ?revoked}, parse: asJson);

  // ---- member types (built-in + administrator-created) ----
  Future<List<Json>> memberGroups({bool all = false}) => _api.get('/member-groups', query: {'all': all ? 'true' : null}, parse: asJsonList);
  Future<Json> createMemberGroup(Json body) => _api.post('/member-groups', body: body, parse: asJson);
  Future<Json> updateMemberGroup(String key, Json body) => _api.patch('/member-groups/$key', body: body, parse: asJson);
  Future<void> deleteMemberGroup(String key) => _api.delete<void>('/member-groups/$key');

  // ---- attendance ----
  /// Step 1 of taking attendance: identify a member (QR [uuid] or a manual pick [userId]) and check
  /// they may be recorded at this program / date. Writes nothing.
  Future<Json> checkAttendance(int programId, {String? uuid, int? userId, String? date}) =>
      _api.get('/programs/$programId/attendance/check', query: {'uuid': uuid, 'user_id': userId?.toString(), 'date': date}, parse: asJson);
  Future<List<Json>> attendanceTakers(int programId) => _api.get('/programs/$programId/attendance-takers', parse: asJsonList);
  Future<List<Json>> setAttendanceTakers(int programId, List<int> userIds) =>
      _api.put('/programs/$programId/attendance-takers', body: {'user_ids': userIds}, parse: asJsonList);
  /// What an internal page's button can open (program, mezmur, category, class, course, assignment, page).
  Future<List<Json>> pageLinkTargets(String type, {String? q}) => _api.get('/pages/link-targets', query: {'type': type, 'q': q}, parse: asJsonList);
  /// Which member groups do not sign attendance (HR, attendance.configure).
  Future<Json> signaturePolicy() => _api.get('/attendance/signature-policy', parse: asJson);
  Future<Json> saveSignaturePolicy(List<String> exemptGroups) => _api.put('/attendance/signature-policy', body: {'exempt_groups': exemptGroups}, parse: asJson);

  /// The occurrence's attendance session: scheduled start / end, when it becomes available (15 min
  /// before), its one taker, Start / End state and what the caller may do (server time included).
  Future<Json> attendanceSession(int programId, String? date) => _api.get('/programs/$programId/attendance/session', query: {'date': date}, parse: asJson);
  Future<Json> startAttendanceSession(int programId, String? date) => _api.post('/programs/$programId/attendance/session/start', body: {'date': ?date}, parse: asJson);
  Future<Json> endAttendanceSession(int programId, String? date) => _api.post('/programs/$programId/attendance/session/end', body: {'date': ?date}, parse: asJson);

  /// HR (attendance.assign): the taker of one occurrence; a substitute while it runs needs a reason.
  Future<Json> assignSessionTaker(int programId, String? date, int userId, {String? reason}) =>
      _api.put('/programs/$programId/attendance/session/taker', body: {'date': ?date, 'user_id': userId, 'reason': ?reason}, parse: asJson);

  /// Offline attendance the server could not apply as captured (HR review queue).
  Future<Paged<Json>> attendanceConflicts({String? status, int? programId, String? batchId, int page = 1}) =>
      _api.getPage('/attendance/sync-conflicts', (j) => j, page: page, query: {'status': status, 'program_id': programId, 'batch_id': batchId});
  Future<Paged<Json>> attendanceConflictBatches({String? status, int? programId, int page = 1}) =>
      _api.getPage('/attendance/sync-conflicts/batches', (j) => j, page: page, query: {'status': status, 'program_id': programId});
  Future<Json> resolveAttendanceConflict(int id, {required String decision, required String note}) =>
      _api.post('/attendance/sync-conflicts/$id/resolve', body: {'decision': decision, 'note': note}, parse: asJson);
  Future<Json> bulkResolveAttendanceConflicts({String? batchId, List<int>? conflictIds, required String decision, required String note}) =>
      _api.post('/attendance/sync-conflicts/bulk-resolve', body: {'batch_id': ?batchId, 'conflict_ids': ?conflictIds, 'decision': decision, 'note': note}, parse: asJson);
  Future<List<int>> attendanceConflictSignature(int id) => _api.bytes('/attendance/sync-conflicts/$id/signature');
  Future<List<int>> attendanceSignature(int attendanceId) => _api.bytes('/programs/attendance/signatures/$attendanceId');

  Future<Json> requestCorrection(int programId, int userId, {String? date, String? requestedStatus, String? attendedAt, required String reason}) =>
      _api.post('/programs/$programId/attendance/$userId/corrections', body: {'date': ?date, 'requested_status': requestedStatus, 'attended_at': ?attendedAt, 'reason': reason}, parse: asJson);
  Future<Paged<Json>> corrections({String? status, int page = 1}) => _api.getPage('/attendance/corrections', (j) => j, page: page, query: {'status': status});
  Future<Json> reviewCorrection(int id, {required String decision, String? note}) =>
      _api.post('/attendance/corrections/$id/review', body: {'decision': decision, 'note': ?note}, parse: asJson);
  Future<List<Json>> setOccurrence(int programId, String date, Json body) => _api.put('/programs/$programId/occurrences/$date', body: body, parse: asJsonList);

  // ---- property requests ----
  Future<Paged<Json>> propertyRequests({String? status, int? departmentId, String? q, int page = 1}) =>
      _api.getPage('/property-requests', (j) => j, page: page, query: {'status': status, 'department_id': departmentId, 'q': q});
  Future<Json> propertyRequest(int id) => _api.get('/property-requests/$id', parse: asJson);
  Future<Json> createPropertyRequest(Json body) => _api.post('/property-requests', body: body, parse: asJson);
  Future<Json> propertyAction(int id, String action, {String? note}) => _api.post('/property-requests/$id/$action', body: {'note': ?note}, parse: asJson);
  Future<Json> issueProperty(int id, {int? quantity, String? note}) => _api.post('/property-requests/$id/issue', body: {'quantity': ?quantity, 'note': ?note}, parse: asJson);
  Future<Json> returnProperty(int id, {int? quantity, String? condition, String? note}) =>
      _api.post('/property-requests/$id/return', body: {'quantity': ?quantity, 'condition': ?condition, 'note': ?note}, parse: asJson);

  // ---- direct borrowing ----
  Future<Json> directPolicy() => _api.get('/borrowings/direct-policy', parse: asJson);
  Future<Json> saveDirectPolicy(Json body) => _api.put('/borrowings/direct-policy', body: body, parse: asJson);
  Future<Json> approveBorrowing(int id) => _api.post('/borrowings/$id/approve', parse: asJson);
  Future<Json> rejectBorrowing(int id, String reason) => _api.post('/borrowings/$id/reject', body: {'reason': reason}, parse: asJson);
  Future<Json> renewBorrowing(int id, String dueOn, {String? reason}) => _api.post('/borrowings/$id/renew', body: {'due_on': dueOn, 'reason': ?reason}, parse: asJson);

  // ---- holiday selections ----
  Future<Json> selectionOptions() => _api.get('/selections/options', parse: asJson);
  Future<Paged<Json>> selections({String? status, int page = 1}) => _api.getPage('/selections', (j) => j, page: page, query: {'status': status});
  Future<Json> selection(int id) => _api.get('/selections/$id', parse: asJson);
  Future<Json> createSelection(Json body) => _api.post('/selections', body: body, parse: asJson);
  Future<Json> updateSelection(int id, Json body) => _api.patch('/selections/$id', body: body, parse: asJson);
  Future<Json> selectionStatus(int id, String status, {String? reason}) => _api.post('/selections/$id/status', body: {'status': status, 'reason': ?reason}, parse: asJson);
  Future<Json> computeSelection(int id) => _api.post('/selections/$id/compute', parse: asJson);
  Future<Paged<Json>> selectionResults(int id, {String? result, bool missing = false, String? q, int page = 1, int limit = 20}) =>
      _api.getPage('/selections/$id/results', (j) => j, page: page, limit: limit, query: {'result': result, 'missing': missing ? 'true' : null, 'q': q});
  Future<Json> selectionResult(int id, int userId) => _api.get('/selections/$id/results/$userId', parse: asJson);
  Future<Json> overrideResult(int id, int userId, {required String decision, required String reason}) =>
      _api.put('/selections/$id/results/$userId/override', body: {'decision': decision, 'reason': reason}, parse: asJson);
  Future<List<Json>> selectionReviews(int id) => _api.get('/selections/$id/reviews', parse: asJsonList);
  Future<List<Json>> submitSelectionReview(int id, Json body) => _api.post('/selections/$id/reviews', body: body, parse: asJsonList);
  Future<Json> setRequiredReviewers(int id, List<String> departments) => _api.put('/selections/$id/required-reviewers', body: {'departments': departments}, parse: asJson);
  Future<Json> assignServiceCategories(int id, List<Json> assignments) => _api.post('/selections/$id/categories/assign', body: {'assignments': assignments}, parse: asJson);
  Future<Json> rankedServiceCategories(int id) => _api.get('/selections/$id/ranked-categories', parse: asJson);
  Future<Json> publishSelection(int id) => _api.post('/selections/$id/publish', parse: asJson);
  Future<Json> submitSelectionFeedback(int id, String comments) => _api.post('/selections/$id/feedback', body: {'comments': comments}, parse: asJson);

  Future<List<Json>> selectionFeedback(int id) => _api.get('/selections/$id/feedback', parse: asJsonList);

  // ---- wedding ceremony services ----
  Future<Paged<Json>> weddings({String scope = 'upcoming', int page = 1}) => _api.getPage('/weddings', (j) => j, page: page, query: {'scope': scope});
  Future<Json> wedding(int id) => _api.get('/weddings/$id', parse: asJson);
  Future<Json> createWedding(Json body) => _api.post('/weddings', body: body, parse: asJson);
  Future<Json> updateWedding(int id, Json body) => _api.patch('/weddings/$id', body: body, parse: asJson);
  Future<Paged<Json>> weddingCandidates(int id, {String? q, String? group, bool hideChosen = false, int page = 1}) =>
      _api.getPage('/weddings/$id/candidates', (j) => j, page: page, limit: 30, query: {'q': q, 'member_group': ?group, if (hideChosen) 'selected': 'false'});
  /// Eligible members for a service that is being created (no id yet).
  Future<Paged<Json>> weddingEligible({String? q, String? group, int page = 1}) =>
      _api.getPage('/weddings/eligible', (j) => j, page: page, limit: 30, query: {'q': q, 'member_group': ?group});
  Future<Json> selectWeddingMembers(int id, List<int> userIds, {String? note}) => _api.post('/weddings/$id/members', body: {'user_ids': userIds, 'note': ?note}, parse: asJson);
  Future<Json> setWeddingMember(int id, int userId, String status, {String? note}) =>
      _api.patch('/weddings/$id/members/$userId', body: {'status': status, 'note': ?note}, parse: asJson);
  Future<Json> announceWedding(int id, {String? title, String? body}) =>
      _api.post('/weddings/$id/announce', body: {'title': ?title, 'body': ?body}, parse: asJson);
}

/// Department chat and member-ID settings (member IDs / chat stage).
class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Json>> overview() => _api.get('/chat', parse: asJsonList);
  Future<Json> messages(int departmentId, {String thread = 'group', int? before, int? after}) =>
      _api.get('/chat/$departmentId/messages', query: {'thread': thread, 'before': before, 'after': after}, parse: asJson);
  Future<Json> sendText(int departmentId, String thread, String body) =>
      _api.post('/chat/$departmentId/messages', body: {'thread': thread, 'body': body}, parse: asJson);
  Future<Json> sendMeeting(int departmentId, String thread, {required String url, String? note, DateTime? at}) => _api.post('/chat/$departmentId/messages',
      body: {'thread': thread, 'kind': 'meeting', 'meeting_url': url, if (note != null && note.isNotEmpty) 'body': note, if (at != null) 'meeting_at': at.toUtc().toIso8601String()}, parse: asJson);
  Future<Json> sendFile(int departmentId, String thread, String filePath, {String? caption, String? filename, void Function(double)? onProgress}) =>
      _api.upload('/chat/$departmentId/messages', filePath: filePath, filename: filename, fields: {'thread': thread, if (caption != null && caption.isNotEmpty) 'body': caption}, parse: asJson, onProgress: onProgress);
  Future<void> delete(int departmentId, int messageId) => _api.delete<void>('/chat/$departmentId/messages/$messageId');
  Future<void> markRead(int departmentId, String thread, int lastId) => _api.post<void>('/chat/$departmentId/read', body: {'thread': thread, 'last_id': lastId});
  Future<List<Json>> threads(int departmentId) => _api.get('/chat/$departmentId/threads', parse: asJsonList);
  Future<List<Json>> contacts(int departmentId, {String? q}) => _api.get('/chat/$departmentId/contacts', query: {'q': q}, parse: asJsonList);
  /// An attachment's bytes (private: sent with the session's token). [url] is `/chat/messages/<id>/file`.
  Future<List<int>> attachment(String url) => _api.bytes(url);

  // ---- member IDs ----
  Future<Json> memberIdFormat() => _api.get('/member-ids/format', parse: asJson);
  Future<Json> saveMemberIdFormat(Json body) => _api.put('/member-ids/format', body: body, parse: asJson);
}
