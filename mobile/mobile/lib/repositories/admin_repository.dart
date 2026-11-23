import '../core/network/api_client.dart';
import '../models/activity.dart';
import '../models/admin.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../models/user.dart';

/// Every administration endpoint. The backend enforces permissions on each call;
/// the app only hides what the admin cannot use.
class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  // ---------------------------------------------------------------- users
  Future<Paged<AppUser>> users({Json filter = const {}, int page = 1}) =>
      _api.getPage('/users', AppUser.fromJson, page: page, query: {...filter});

  /// A member: account + classification, the membership form and their departments.
  Future<({AppUser user, Json profile, List<Json> departments})> user(int id) => _api.get('/users/$id',
      parse: (d) => (user: AppUser.fromJson(asJson(d)), profile: asJson(asJson(d)['profile']), departments: asJsonList(asJson(d)['departments'])));

  Future<({AppUser user, String? tempPassword})> createUser(Json body) => _api.post('/users',
      body: body, parse: (d) => (user: AppUser.fromJson(asJson(asJson(d)['user'])), tempPassword: asStr(asJson(d)['temporary_password'])));

  Future<AppUser> updateUser(int id, Json body) => _api.patch('/users/$id', body: body, parse: (d) => AppUser.fromJson(asJson(d)));

  /// Update returning a temporary password when login was just allowed (e.g. a grown-up child).
  Future<({AppUser user, String? tempPassword})> updateMember(int id, Json body) =>
      _api.patch('/users/$id', body: body, parse: (d) => (user: AppUser.fromJson(asJson(d)), tempPassword: asStr(asJson(d)['temporary_password'])));
  Future<AppUser> setUserEnabled(int id, bool enabled) =>
      _api.post('/users/$id/${enabled ? 'enable' : 'disable'}', parse: (d) => AppUser.fromJson(asJson(d)));
  Future<void> deleteUser(int id) => _api.delete<void>('/users/$id');
  Future<({String password, bool viaTelegram})> resetUserPassword(int id) => _api.post('/users/$id/reset-password',
      parse: (d) => (password: asStr(asJson(d)['temporary_password']) ?? '', viaTelegram: asBool(asJson(d)['sent_via_telegram'])));

  Future<Paged<ProfileChangeRequest>> changeRequests({String status = 'pending', int page = 1}) =>
      _api.getPage('/users/change-requests', ProfileChangeRequest.fromJson, page: page, query: {'status': status});
  Future<bool> approveChange(int id, {String? note}) => _api.post('/users/change-requests/$id/approve', body: {'reason': ?note}, parse: (_) => true);
  Future<bool> rejectChange(int id, {required String reason}) => _api.post('/users/change-requests/$id/reject', body: {'reason': reason}, parse: (_) => true);
  Future<Paged<ProfileFieldChange>> profileHistory(int userId, {int page = 1}) => _api.getPage('/users/$userId/profile-history', ProfileFieldChange.fromJson, page: page);
  Future<void> resetDevice(int id, {String? reason}) => _api.post<void>('/users/$id/reset-device', body: {'reason': ?reason});
  Future<void> forceLogout(int id) => _api.post<void>('/users/$id/force-logout');

  Future<({Json current, List<Json> history})> deviceHistory(int id) => _api.get('/users/$id/devices',
      query: {'limit': 50}, parse: (d) => (current: asJson(asJson(d)['current']), history: asJsonList(asJson(d)['history'])));

  Future<int> previewTarget(BulkTarget t) => _api.post('/users/bulk/preview', body: t.toJson(), parse: (d) => asIntOr(asJson(d)['count']));

  // ---------------------------------------------------------------- mezmurs
  Future<Paged<MezmurSummary>> mezmurs({String? q, String? status, int? categoryId, int page = 1}) => _api.getPage(
      '/mezmurs/admin/list', MezmurSummary.fromJson,
      page: page, query: {'q': q, 'status': status, 'category_id': categoryId, 'sort': q == null ? 'recent' : null});
  Future<Mezmur> mezmur(int id) => _api.get('/mezmurs/admin/$id', parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<Mezmur> createMezmur(Json body) => _api.post('/mezmurs', body: body, parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<Mezmur> updateMezmur(int id, Json body) => _api.patch('/mezmurs/$id', body: body, parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<void> deleteMezmur(int id) => _api.delete<void>('/mezmurs/$id');
  Future<Mezmur> uploadAudio(int id, String path, {int? durationSec, void Function(double)? onProgress}) => _api.upload('/mezmurs/$id/audio',
      filePath: path, fields: {'duration_sec': ?durationSec?.toString()}, onProgress: onProgress, parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<void> removeAudio(int id) => _api.delete<void>('/mezmurs/$id/audio');
  Future<Mezmur> uploadCover(int id, String path) => _api.upload('/mezmurs/$id/cover', filePath: path, parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<void> removeCover(int id) => _api.delete<void>('/mezmurs/$id/cover');

  // ---------------------------------------------------------------- categories
  Future<List<CategoryNode>> categoryTree() =>
      _api.get('/categories', query: {'include_inactive': 'true'}, parse: (d) => (d as List).map((e) => CategoryNode.fromJson(asJson(e))).toList());
  Future<CategoryNode> createCategory(Json body) => _api.post('/categories', body: body, parse: (d) => CategoryNode.fromJson(asJson(d)));
  Future<CategoryNode> updateCategory(int id, Json body) => _api.patch('/categories/$id', body: body, parse: (d) => CategoryNode.fromJson(asJson(d)));
  Future<CategoryNode> setCategoryToday(int id, bool today) =>
      _api.put('/categories/$id/today', body: {'today': today}, parse: (d) => CategoryNode.fromJson(asJson(d)));
  Future<Mezmur> setMezmurToday(int id, bool today) => _api.put('/mezmurs/$id/today', body: {'today': today}, parse: (d) => Mezmur.fromJson(asJson(d)));
  Future<void> deleteCategory(int id) => _api.delete<void>('/categories/$id');
  Future<void> reorderCategories(List<({int id, int order})> items) =>
      _api.post<void>('/categories/reorder', body: {'items': items.map((e) => {'id': e.id, 'display_order': e.order}).toList()});
  Future<CategoryNode> uploadCategoryImage(int id, String path) =>
      _api.upload('/categories/$id/image', filePath: path, parse: (d) => CategoryNode.fromJson(asJson(d)));
  Future<void> removeCategoryImage(int id) => _api.delete<void>('/categories/$id/image');

  // ---------------------------------------------------------------- banners & pages
  Future<Paged<Json>> ads({int page = 1}) => _api.getPage('/advertisements/admin/list', (j) => j, page: page);
  Future<Json> createAd(Json body) => _api.post('/advertisements', body: body, parse: asJson);
  Future<Json> updateAd(int id, Json body) => _api.patch('/advertisements/$id', body: body, parse: asJson);
  Future<void> deleteAd(int id) => _api.delete<void>('/advertisements/$id');
  Future<Json> addAdFile(int id, String path, {String? title}) =>
      _api.upload('/advertisements/$id/attachments', filePath: path, fields: {'title': ?title}, parse: asJson);
  Future<Json> addAdLink(int id, {required String url, String? title}) => _api.post('/advertisements/$id/links', body: {'url': url, 'title': ?title}, parse: asJson);
  Future<Json> removeAdAttachment(int id, int attachmentId) => _api.delete('/advertisements/$id/attachments/$attachmentId', parse: asJson);
  Future<Json> uploadAdImage(int id, String path) => _api.upload('/advertisements/$id/image', filePath: path, parse: asJson);

  Future<Paged<Json>> pages({String? q, int page = 1}) => _api.getPage('/pages/admin/list', (j) => j, page: page, query: {'q': q});
  Future<PageContent> page(int id) => _api.get('/pages/admin/$id', parse: (d) => PageContent.fromJson(asJson(d)));
  Future<PageContent> createPage(Json body) => _api.post('/pages', body: body, parse: (d) => PageContent.fromJson(asJson(d)));
  Future<PageContent> updatePage(int id, Json body) => _api.patch('/pages/$id', body: body, parse: (d) => PageContent.fromJson(asJson(d)));
  Future<void> deletePage(int id) => _api.delete<void>('/pages/$id');
  Future<PageContent> uploadPageCover(int id, String path) => _api.upload('/pages/$id/cover', filePath: path, parse: (d) => PageContent.fromJson(asJson(d)));
  Future<PageContent> addPageImage(int id, String path) => _api.upload('/pages/$id/images', filePath: path, parse: (d) => PageContent.fromJson(asJson(d)));
  Future<void> removePageImage(int id, int imageId) => _api.delete<void>('/pages/$id/images/$imageId');

  // ---------------------------------------------------------------- programs & attendance
  Future<Paged<Program>> programs({String? q, String? status, int page = 1}) =>
      _api.getPage('/programs/admin/list', Program.fromJson, page: page, query: {'q': q, 'status': status});
  Future<Program> program(int id) => _api.get('/programs/admin/$id', parse: (d) => Program.fromJson(asJson(d)));
  /// Programs this attendance taker may open (assigned to them, or open to every taker).
  Future<Paged<Program>> takeablePrograms({String? q, String? scope, int page = 1}) =>
      _api.getPage('/programs/attendance/takeable', Program.fromJson, page: page, query: {'q': q, 'scope': scope});
  Future<Program> createProgram(Json body) => _api.post('/programs', body: body, parse: (d) => Program.fromJson(asJson(d)));
  Future<Program> updateProgram(int id, Json body) => _api.patch('/programs/$id', body: body, parse: (d) => Program.fromJson(asJson(d)));
  Future<void> deleteProgram(int id) => _api.delete<void>('/programs/$id');
  Future<Program> uploadProgramImage(int id, String path) => _api.upload('/programs/$id/image', filePath: path, parse: (d) => Program.fromJson(asJson(d)));
  Future<Paged<Json>> participants(int id, {String? q, int page = 1}) => _api.getPage('/programs/$id/participants', (j) => j, page: page, query: {'q': q});
  Future<Json> addParticipants(int id, BulkTarget t, {String status = 'invited', bool notify = true}) =>
      _api.post('/programs/$id/participants/bulk', body: {'target': t.toJson(), 'status': status, 'notify': notify}, parse: asJson);
  Future<void> removeParticipant(int id, int userId) => _api.delete<void>('/programs/$id/participants/$userId');
  /// Attendance of one occurrence ([date] YYYY-MM-DD; null = today's / the latest one).
  Future<Paged<Json>> roster(int id, {String source = 'participants', String? status, String? q, String? date, int page = 1}) =>
      _api.getPage('/programs/$id/attendance', (j) => j, page: page, query: {'source': source, 'status': status, 'q': q, 'date': date});
  Future<void> setAttendance(int id, int userId, String status, {String? notes, String? date}) =>
      _api.put<void>('/programs/$id/attendance/$userId', body: {'status': status, 'notes': ?notes, 'date': ?date});
  Future<void> removeAttendance(int id, int userId, {String? date}) => _api.delete<void>('/programs/$id/attendance/$userId', query: {'date': date});
  Future<Json> bulkAttendance(int id, BulkTarget t, String status, {String? date}) =>
      _api.post('/programs/$id/attendance/bulk', body: {'target': t.toJson(), 'status': status, 'date': ?date}, parse: asJson);
  Future<List<Json>> checkProgramOverlap(Json body) =>
      _api.post('/programs/check-overlap', body: body, parse: asJsonList);

  Future<Json> previewSchedule(Json body) =>
      _api.post('/programs/preview-schedule', body: body, parse: asJson);

  Future<List<Json>> occurrences(int id, {required String from, required String to}) =>
      _api.get('/programs/$id/occurrences', query: {'from': from, 'to': to}, parse: asJsonList);
  Future<Json> updateOccurrence(int id, String date, Json body) =>
      _api.put('/programs/$id/occurrences/$date', body: body, parse: asJson);

  // ---------------------------------------------------------------- admin attendance management
  Future<Json> adminAttendanceYearlySummary({
    int? year,
    String? memberGroup,
    String? memberType,
    int? categoryId,
    int? programId,
  }) =>
      _api.get('/programs/attendance/admin/yearly-summary', query: {
        'year': year,
        'member_group': memberGroup,
        'member_type': memberType,
        'category_id': categoryId,
        'program_id': programId,
      }, parse: asJson);

  Future<Json> adminAttendanceMonthlySummary({
    int? year,
    int? month,
    String? memberGroup,
    String? memberType,
    int? categoryId,
    int? programId,
  }) =>
      _api.get('/programs/attendance/admin/monthly-summary', query: {
        'year': year,
        'month': month,
        'member_group': memberGroup,
        'member_type': memberType,
        'category_id': categoryId,
        'program_id': programId,
      }, parse: asJson);

  Future<List<Json>> adminAttendanceByProgram({int? year}) =>
      _api.get('/programs/attendance/admin/by-program', query: {'year': year}, parse: asJsonList);

  Future<Json> adminAttendanceMemberProfile(int userId, {int? year}) =>
      _api.get('/programs/attendance/admin/member/$userId', query: {'year': year}, parse: asJson);

  Future<List<Json>> adminAttendanceSearchMembers(String query) =>
      _api.get('/programs/attendance/admin/members/search', query: {'q': query}, parse: asJsonList);

  Future<Json> adminAttendanceOverview({
    String? from,
    String? to,
    String? date,
    int? programId,
    int? categoryId,
    String? status,
    int? takerId,
    int? classId,
    String? q,
  }) =>
      _api.get('/programs/attendance/admin/overview', query: {
        'from': from,
        'to': to,
        'date': date,
        'program_id': programId,
        'category_id': categoryId,
        'status': status,
        'taker_id': takerId,
        'class_id': classId,
        'q': q,
      }, parse: asJson);

  Future<Paged<Json>> adminAttendanceRecords({
    String? from,
    String? to,
    String? date,
    int? programId,
    int? categoryId,
    String? status,
    int? takerId,
    int? classId,
    String? q,
    int page = 1,
    int limit = 25,
  }) =>
      _api.getPage(
        '/programs/attendance/admin/records',
        (j) => j,
        page: page,
        query: {
          'from': from,
          'to': to,
          'date': date,
          'program_id': programId,
          'category_id': categoryId,
          'status': status,
          'taker_id': takerId,
          'class_id': classId,
          'q': q,
          'limit': limit,
        },
      );

  Future<Json> adminAttendanceExport({
    String? from,
    String? to,
    String? date,
    int? programId,
    int? categoryId,
    String? status,
    int? takerId,
    int? classId,
    String? q,
  }) =>
      _api.get('/programs/attendance/admin/export', query: {
        'from': from,
        'to': to,
        'date': date,
        'program_id': programId,
        'category_id': categoryId,
        'status': status,
        'taker_id': takerId,
        'class_id': classId,
        'q': q,
      }, parse: asJson);

  // ---------------------------------------------------------------- program categories
  Future<List<ProgramCategory>> programCategories() => _api.get('/programs/categories/all', parse: (d) => asJsonList(d).map(ProgramCategory.fromJson).toList());
  Future<void> createProgramCategory(Json body) => _api.post<void>('/programs/categories', body: body);
  Future<void> updateProgramCategory(int id, Json body) => _api.patch<void>('/programs/categories/$id', body: body);
  Future<void> deleteProgramCategory(int id) => _api.delete<void>('/programs/categories/$id');

  // ---------------------------------------------------------------- notifications
  /// Sends a new notification; with [resendOf] it is a resend of that one (a NEW notification —
  /// the original and its history stay as they were).
  Future<Json> sendNotification({required String kind, required String title, required String body, required BulkTarget target, String? entityType, int? entityId, bool email = false, int? resendOf}) =>
      _api.post(resendOf == null ? '/admin/notifications/send' : '/admin/notifications/broadcasts/$resendOf/resend',
          body: {'kind': kind, 'title': title, 'body': body, 'target': target.toJson(), 'entity_type': ?entityType, 'entity_id': ?entityId, 'email': email}, parse: asJson);
  Future<Paged<Json>> broadcasts({int page = 1}) => _api.getPage('/admin/notifications/broadcasts', (j) => j, page: page);
  Future<Json> broadcast(int id) => _api.get('/admin/notifications/broadcasts/$id', parse: asJson);
  Future<Json> notificationHealth() => _api.get('/admin/notifications/health', parse: asJson);

  // Property categories and department-based item codes.
  Future<List<Json>> itemCategories({bool all = false}) => _api.get('/items/categories', query: {'all': all ? 'true' : null}, parse: asJsonList);
  Future<List<Json>> saveItemCategory(String? key, Json body) =>
      key == null ? _api.post('/items/categories', body: body, parse: asJsonList) : _api.patch('/items/categories/$key', body: body, parse: asJsonList);
  Future<List<Json>> deleteItemCategory(String key) => _api.delete('/items/categories/$key', parse: asJsonList);
  Future<String> nextItemCode({int? departmentId, String? category, String? name}) =>
      _api.get('/items/next-code', query: {'department_id': departmentId?.toString(), 'category': category, 'name': name}, parse: (d) => '${asJson(d)['code']}');

  // ---------------------------------------------------------------- library
  Future<Paged<ItemModel>> items({String? q, bool availableOnly = false, int page = 1}) =>
      _api.getPage('/items', ItemModel.fromJson, page: page, query: {'q': q, 'available': availableOnly ? 'true' : null});
  Future<ItemModel> item(int id) => _api.get('/items/$id', parse: (d) => ItemModel.fromJson(asJson(d)));
  Future<ItemModel> createItem(Json body) => _api.post('/items', body: body, parse: (d) => ItemModel.fromJson(asJson(d)));
  Future<ItemModel> updateItem(int id, Json body) => _api.patch('/items/$id', body: body, parse: (d) => ItemModel.fromJson(asJson(d)));
  Future<void> deleteItem(int id) => _api.delete<void>('/items/$id');
  Future<ItemModel> uploadItemImage(int id, String path) => _api.upload('/items/$id/image', filePath: path, parse: (d) => ItemModel.fromJson(asJson(d)));

  Future<Paged<Borrowing>> borrowings({Json filter = const {}, int page = 1}) =>
      _api.getPage('/borrowings', Borrowing.fromJson, page: page, query: {...filter});
  Future<Borrowing> borrowing(int id) => _api.get('/borrowings/$id', parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Borrowing> createBorrowing(Json body) => _api.post('/borrowings', body: body, parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Json> bulkBorrow(Json body) => _api.post('/borrowings/bulk', body: body, parse: asJson);
  Future<Borrowing> sign(int id, String dataUrl) => _api.post('/borrowings/$id/signature', body: {'signature': dataUrl}, parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Borrowing> returnItem(int id, Json body) => _api.post('/borrowings/$id/return', body: body, parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Borrowing> overrideFine(int id, double amount, String reason) =>
      _api.put('/borrowings/$id/fine', body: {'amount': amount, 'reason': reason}, parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Borrowing> clearFineOverride(int id) => _api.delete('/borrowings/$id/fine', parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<Borrowing> setFineStatus(int id, String status) =>
      _api.post('/borrowings/$id/fine/status', body: {'status': status}, parse: (d) => Borrowing.fromJson(asJson(d)));
  Future<List<int>> signatureBytes(int id) => _api.bytes('/borrowings/$id/signature');

  Future<List<Json>> returnConditions({bool all = false}) =>
      _api.get('/borrowings/return-conditions', query: {'all': all ? 'true' : null}, parse: asJsonList);
  Future<Json> saveReturnCondition(int? id, Json body) => id == null
      ? _api.post('/borrowings/return-conditions', body: body, parse: asJson)
      : _api.patch('/borrowings/return-conditions/$id', body: body, parse: asJson);

  Future<Json> finePolicy() => _api.get('/fines/policy', parse: asJson);
  Future<Json> saveFinePolicy(Json body) => _api.put('/fines/policy', body: body, parse: asJson);
  Future<Json> fineSummary() => _api.get('/fines/summary', parse: asJson);

  // ---------------------------------------------------------------- supervision
  Future<Json> dashboard() => _api.get('/reports/dashboard', parse: asJson);
  Future<Json> report(String name, {Json filter = const {}}) => _api.get('/reports/$name', query: {...filter}, parse: asJson);
  Future<Paged<Json>> auditLogs({Json filter = const {}, int page = 1}) => _api.getPage('/audit-logs', (j) => j, page: page, query: {...filter});
  Future<Paged<Json>> activityLogs({Json filter = const {}, int page = 1}) => _api.getPage('/activity-logs', (j) => j, page: page, query: {...filter});
  Future<Paged<PermissionRequest>> permissionRequests({String status = 'pending', int page = 1}) =>
      _api.getPage('/permissions', PermissionRequest.fromJson, page: page, query: {'status': status});
  Future<void> reviewPermission(int id, {required bool approve, String? note}) =>
      _api.patch<void>('/permissions/$id', body: {'status': approve ? 'approved' : 'rejected', 'note': ?note});
  /// Undo an approval given by mistake (the excused mark it created is removed; reason required).
  Future<void> cancelApprovedPermission(int id, String reason) => _api.post<void>('/permissions/$id/cancel', body: {'reason': reason});
  /// [format]: auto | txt | csv | tsv (pasted from a spreadsheet) | xlsx ([content] base64).
  Future<Json> runImport(String kind, String content, {required bool dryRun, String format = 'auto'}) =>
      _api.post('/import/$kind', body: {'content': content, 'dry_run': dryRun, 'format': format}, parse: asJson);
  Future<List<int>> importTemplateXlsx(String kind) => _api.bytes('/import/templates/$kind?format=xlsx');
  /// A report file (PDF / XLSX / CSV) from GET /reports/export/{kind}?format=…&filters.
  Future<List<int>> exportReport(String pathWithQuery) => _api.bytes(pathWithQuery);
  Future<List<Json>> itemHistory(int id) => _api.get('/items/$id/history', parse: asJsonList);
  Future<Json> permissionSummary() => _api.get('/permissions/summary', parse: asJson);
  Future<Json> permissionPolicy() => _api.get('/permissions/policy', parse: asJson);
  Future<Json> savePermissionPolicy(Json value) => _api.put('/permissions/policy', body: value, parse: asJson);

  Future<Json> settings() => _api.get('/settings', parse: asJson);
  Future<Json> saveSetting(String key, Json value) => _api.put('/settings/$key', body: value, parse: asJson);

  // ---------------------------------------------------------------- administrators
  Future<Paged<AdminAccount>> admins({String? q, int page = 1}) => _api.getPage('/admins', AdminAccount.fromJson, page: page, query: {'q': q});
  Future<AdminAccount> admin(int id) => _api.get('/admins/$id', parse: (d) => AdminAccount.fromJson(asJson(d)));
  Future<({AdminAccount admin, String? tempPassword})> createAdmin(Json body) => _api.post('/admins',
      body: body, parse: (d) => (admin: AdminAccount.fromJson(asJson(asJson(d)['admin'])), tempPassword: asStr(asJson(d)['temporary_password'])));
  /// A member becomes an administrator (keeps every member feature) / returns to member.
  Future<AdminAccount> promoteToAdmin(int userId, int roleId) => _api.post('/admins/promote', body: {'user_id': userId, 'role_id': roleId}, parse: (d) => AdminAccount.fromJson(asJson(d)));
  Future<bool> demoteAdmin(int id, {String? reason}) => _api.post('/admins/$id/demote', body: {'reason': ?reason}, parse: (_) => true);
  Future<AdminAccount> updateAdmin(int id, Json body) => _api.patch('/admins/$id', body: body, parse: (d) => AdminAccount.fromJson(asJson(d)));
  Future<({String password, bool viaTelegram})> resetAdminPassword(int id) => _api.post('/admins/$id/reset-password',
      parse: (d) => (password: asStr(asJson(d)['temporary_password']) ?? '', viaTelegram: asBool(asJson(d)['sent_via_telegram'])));

  // ---------------------------------------------------------------- app releases
  Future<List<AppRelease>> releases() => _api.get('/releases', parse: (d) => asList(d, AppRelease.fromJson));
  Future<AppRelease> publishRelease({required String filePath, required String versionName, required int versionCode, String? notes, bool mandatory = false, int? minSupportedCode, void Function(double)? onProgress}) =>
      _api.upload('/releases',
          filePath: filePath,
          filename: 'app.apk',
          fields: {
            'version_name': versionName,
            'version_code': '$versionCode',
            'release_notes': ?notes,
            'is_mandatory': '$mandatory',
            'min_supported_code': ?minSupportedCode?.toString(),
          },
          onProgress: onProgress,
          parse: (d) => AppRelease.fromJson(asJson(d)));
  Future<AppRelease> updateRelease(int id, Json body) => _api.patch('/releases/$id', body: body, parse: (d) => AppRelease.fromJson(asJson(d)));
  Future<void> deleteRelease(int id) => _api.delete<void>('/releases/$id');
  Future<List<RoleModel>> roles() => _api.get('/admins/roles', parse: (d) => asList(d, RoleModel.fromJson));
  Future<RoleModel> createRole(Json body) => _api.post('/admins/roles', body: body, parse: (d) => RoleModel.fromJson(asJson(d)));
  Future<RoleModel> updateRole(int id, Json body) => _api.patch('/admins/roles/$id', body: body, parse: (d) => RoleModel.fromJson(asJson(d)));
  Future<void> deleteRole(int id) => _api.delete<void>('/admins/roles/$id');
  Future<List<PermissionDef>> permissionCatalog() => _api.get('/admins/permissions', parse: (d) => asList(d, PermissionDef.fromJson));

  // ---------------------------------------------------------------- system authority
  Future<Json> systemOverview() => _api.get('/system/overview', parse: asJson);
  Future<Paged<Json>> systemAdmins({int page = 1}) => _api.getPage('/system/admins', (j) => j, page: page, limit: 50);
  Future<void> systemForceLogout(int id) => _api.post<void>('/system/admins/$id/force-logout');

  // ---------------------------------------------------------------- telegram diagnostic
  Future<Json> getTelegramStatus() => _api.get('/supervision/telegram/status', parse: asJson);
  Future<Json> testTelegramConnection() => _api.post('/supervision/telegram/test', parse: asJson);
}
