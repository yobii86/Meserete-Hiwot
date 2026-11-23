import 'json.dart';

/// A bulk selection sent to bulk endpoints. Exactly one of userIds / filter / all.
class BulkTarget {
  const BulkTarget.users(this.userIds)
      : filter = null,
        all = false,
        excludeIds = const [];
  const BulkTarget.filter(this.filter, {this.excludeIds = const []})
      : userIds = const [],
        all = false;
  const BulkTarget.everyone({this.excludeIds = const []})
      : userIds = const [],
        filter = null,
        all = true;

  final List<int> userIds;
  final Json? filter;
  final bool all;
  final List<int> excludeIds;

  Json toJson() => {
        if (userIds.isNotEmpty) 'user_ids': userIds,
        'filter': ?filter,
        if (all) 'all': true,
        if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds,
      };
}

class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    required this.code,
    this.category,
    this.categoryName,
    this.categoryNameEn,
    this.domain = 'mezmur',
    this.description,
    this.quantity = 0,
    this.available = 0,
    this.condition,
    this.status = 'active',
    this.imageUrl,
    this.location,
    this.notes,
    this.departmentId,
    this.departmentName,
    this.departmentNameEn,
    this.directBorrowable = false,
    this.maxQuantity,
    this.maxDays,
    this.renewable = false,
    this.author,
    this.subtitle,
    this.publisher,
    this.publicationYear,
    this.language,
    this.libraryCategoryId,
    this.categoryType,
    this.kind = 'physical',
    this.hasFile = false,
    this.downloads = 0,
  });

  final int id;
  final String name;
  final String code;

  /// Books: the author, printed (physical) or digital (a PDF), whether the PDF is uploaded.
  final String? author;
  final String? subtitle;
  final String? publisher;
  final int? publicationYear;
  final String? language;
  final int? libraryCategoryId;
  final String? categoryType;
  final String kind;
  final bool hasFile;
  final int downloads;

  /// Owning / responsible department; direct-borrowing settings of the item.
  final int? departmentId;
  final String? departmentName;
  final String? departmentNameEn;
  final bool directBorrowable;
  final int? maxQuantity;
  final int? maxDays;
  final bool renewable;
  /// Category key as stored (e.g. `instruments`); [categoryName] is its Amharic name.
  final String? category;
  final String? categoryName;
  final String? categoryNameEn;

  /// The category as shown: its Amharic name (English name in English), never the raw key.
  String? categoryLabel(String languageCode) =>
      languageCode == 'en' && (categoryNameEn?.isNotEmpty ?? false) ? categoryNameEn : (categoryName?.isNotEmpty ?? false ? categoryName : category);

  /// mezmur | timhirt — which library the item belongs to.
  final String domain;
  final String? description;
  final int quantity;
  final int available;
  final String? condition;
  final String status;
  final String? imageUrl;
  final String? location;
  final String? notes;

  factory ItemModel.fromJson(Json j) => ItemModel(
        id: asIntOr(j['id']),
        name: asStr(j['name']) ?? '',
        code: asStr(j['code']) ?? '',
        category: asStr(j['category']),
        categoryName: asStr(j['category_name']),
        categoryNameEn: asStr(j['category_name_en']),
        domain: asStr(j['domain']) ?? 'mezmur',
        description: asStr(j['description']),
        quantity: asIntOr(j['quantity']),
        available: asIntOr(j['available_quantity']),
        condition: asStr(j['condition']),
        status: asStr(j['status']) ?? 'active',
        imageUrl: asStr(j['image_url']),
        location: asStr(j['location']),
        notes: asStr(j['notes']),
        departmentId: asInt(j['department_id']),
        departmentName: asStr(j['department_name']),
        departmentNameEn: asStr(j['department_name_en']),
        directBorrowable: asBool(j['direct_borrowable']),
        maxQuantity: asInt(j['max_quantity']),
        maxDays: asInt(j['max_days']),
        renewable: asBool(j['renewable']),
        author: asStr(j['author']),
        subtitle: asStr(j['subtitle']),
        publisher: asStr(j['publisher']),
        publicationYear: asInt(j['publication_year']),
        language: asStr(j['language']),
        libraryCategoryId: asInt(j['library_category_id'] ?? j['category_id']),
        categoryType: asStr(j['category_type']),
        kind: asStr(j['kind']) ?? 'physical',
        hasFile: asBool(j['has_file']),
        downloads: asIntOr(j['downloads']),
      );
}

class RoleModel {
  const RoleModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.level,
    this.isSystem = false,
    this.permissions = const [],
    this.assignable = false,
    this.isActive = true,
    this.departmentId,
    this.inUse = 0,
  });
  final bool isActive;
  final int? departmentId;
  final int inUse;
  final int id;
  final String slug;
  final String name;
  final String? description;
  final int level;
  final bool isSystem;
  final List<String> permissions;
  final bool assignable;

  factory RoleModel.fromJson(Json j) => RoleModel(
        id: asIntOr(j['id']),
        slug: asStr(j['slug']) ?? '',
        name: asStr(j['name']) ?? '',
        description: asStr(j['description']),
        level: asIntOr(j['level']),
        isSystem: asBool(j['is_system']),
        permissions: (j['permissions'] as List? ?? const []).map((e) => '$e').toList(),
        assignable: asBool(j['assignable']),
        isActive: j['is_active'] == null || asBool(j['is_active']),
        departmentId: asInt(j['department_id']),
        inUse: asIntOr(j['in_use']),
      );
}

class PermissionDef {
  const PermissionDef({required this.key, required this.group, this.grantable = false});
  final String key;
  final String group;
  final bool grantable;
  factory PermissionDef.fromJson(Json j) =>
      PermissionDef(key: asStr(j['key']) ?? '', group: asStr(j['group_key']) ?? '', grantable: asBool(j['grantable']));
}

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.status = 'active',
    this.roleId,
    this.roleName,
    this.roleLevel,
    this.lastLoginAt,
    this.manageable = false,
    this.rolePermissions = const [],
    this.extraPermissions = const [],
    this.revokedPermissions = const [],
    this.memberGroup = 'youth_adult',
    this.memberId,
  });

  final int id;
  final String fullName;
  /// Administrators are members too: their group decides which programs they attend.
  final String memberGroup;
  final String? memberId;
  final String phone;
  final String? email;
  final String status;
  final int? roleId;
  final String? roleName;
  final int? roleLevel;
  final DateTime? lastLoginAt;
  final bool manageable;
  final List<String> rolePermissions;
  final List<String> extraPermissions;

  /// Role permissions taken away from this one administrator.
  final List<String> revokedPermissions;

  factory AdminAccount.fromJson(Json j) {
    final role = asJson(j['role']);
    return AdminAccount(
      id: asIntOr(j['id']),
      fullName: asStr(j['full_name']) ?? '',
      phone: asStr(j['phone']) ?? '',
      email: asStr(j['email']),
      status: asStr(j['status']) ?? 'active',
      roleId: asInt(role['id']),
      roleName: asStr(role['name']),
      roleLevel: asInt(role['level']),
      lastLoginAt: asDate(j['last_login_at']),
      manageable: asBool(j['manageable']),
      rolePermissions: (j['role_permissions'] as List? ?? const []).map((e) => '$e').toList(),
      extraPermissions: (j['extra_permissions'] as List? ?? const []).map((e) => '$e').toList(),
      revokedPermissions: (j['revoked_permissions'] as List? ?? const []).map((e) => '$e').toList(),
      memberGroup: asStr(j['member_group']) ?? 'youth_adult',
      memberId: asStr(j['member_id']),
    );
  }
}

/// Permission keys used for UI gating (mirrors the backend catalogue).
abstract final class Perm {
  static const usersView = 'users.view';
  static const usersCreate = 'users.create';
  static const usersUpdate = 'users.update';
  static const usersDisable = 'users.disable';
  static const usersResetDevice = 'users.reset_device';
  static const mezmursView = 'mezmurs.view';
  static const mezmursCreate = 'mezmurs.create';
  static const mezmursUpdate = 'mezmurs.update';
  static const mezmursDelete = 'mezmurs.delete';
  static const categoriesManage = 'categories.manage';
  static const adsManage = 'ads.manage';
  static const pagesManage = 'pages.manage';
  static const programsManage = 'programs.manage';
  static const attendanceManage = 'attendance.manage';
  static const notificationsSend = 'notifications.send';
  static const notificationsSendAll = 'notifications.send_all';
  static const borrowingManage = 'borrowing.manage';
  static const itemsManage = 'items.manage';
  static const finesManage = 'fines.manage';
  static const reportsView = 'reports.view';
  static const auditLogsView = 'audit_logs.view';
  static const activityLogsView = 'activity_logs.view';
  static const adminsView = 'admins.view';
  static const adminsManage = 'admins.manage';
  static const settingsManage = 'settings.manage';
  static const releasesManage = 'releases.manage';
  static const departmentsManage = 'departments.manage';
  static const hrManage = 'hr.manage';
  static const paymentsManage = 'payments.manage';
  static const educationManage = 'education.manage';
  static const educationView = 'education.view';
  static const educationClasses = 'education.classes';
  static const educationCurriculum = 'education.curriculum';
  static const educationLessons = 'education.lessons';
  static const educationMaterials = 'education.materials';
  static const educationMaterialsApprove = 'education.materials_approve';
  static const educationQuizzes = 'education.quizzes';
  static const educationExams = 'education.exams';
  static const educationAssessments = 'education.assessments';
  static const educationMarks = 'education.marks';
  static const educationAttendanceView = 'education.attendance_view';
  static const educationSettings = 'education.settings';
  static const educationRegister = 'education.register';
  /// Categories, curriculum (subjects, units, lessons, materials) and the featured banner.
  static const educationContent = 'education.content';
  static const programCategoriesManage = 'program_categories.manage';
  static const attendanceReports = 'attendance.reports';
  /// Wedding ceremony choir services (Hymns and Arts).
  static const choirManage = 'choir.manage';
  static const paymentsConfigure = 'payments.configure';
  static const attendanceView = 'attendance.view';
  static const attendanceClose = 'attendance.close';
  static const attendanceCorrectionRequest = 'attendance.correction.request';
  static const attendanceCorrectionApprove = 'attendance.correction.approve';
  static const attendanceOverride = 'attendance.override';
  static const attendanceConfigure = 'attendance.configure';
  static const attendanceAssign = 'attendance.assign';
  static const paymentsView = 'payments.view';
  static const propertyRequest = 'property.request';
  static const propertyReview = 'property.review';
  static const borrowingApprove = 'borrowing.approve';
  static const borrowingConfigure = 'borrowing.configure';
  static const selectionView = 'selection.view';
  static const selectionConfigure = 'selection.configure';
  static const selectionExams = 'selection.exams';
  static const selectionReview = 'selection.review';
  static const selectionFinalize = 'selection.finalize';

  static const memberIdConfigure = 'member_id.configure';
  static const memberGroupsManage = 'member_groups.manage';
  static const chatSupervise = 'chat.supervise';
  static const projectsView = 'projects.view';
  static const projectsManage = 'projects.manage';
  static const projectsExpensesApprove = 'projects.expenses.approve';
  static const projectsReports = 'projects.reports';
  static const projectsAllDepartments = 'projects.all_departments';
  static const guidanceManage = 'guidance.manage';
  static const libraryCirculate = 'library.circulate';
  static const educationReports = 'education.reports';
  static const educationCertify = 'education.certify';
}

class AppRelease {
  const AppRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    this.fileSize = 0,
    this.releaseNotes,
    this.minSupportedCode = 0,
    this.isMandatory = false,
    this.isPublished = true,
    this.downloadCount = 0,
    this.downloadUrl,
    this.createdAt,
  });

  final int id;
  final String versionName;
  final int versionCode;
  final int fileSize;
  final String? releaseNotes;
  final int minSupportedCode;
  final bool isMandatory;
  final bool isPublished;
  final int downloadCount;
  final String? downloadUrl;
  final DateTime? createdAt;

  factory AppRelease.fromJson(Json j) => AppRelease(
        id: asIntOr(j['id']),
        versionName: asStr(j['version_name']) ?? '',
        versionCode: asIntOr(j['version_code']),
        fileSize: asIntOr(j['file_size']),
        releaseNotes: asStr(j['release_notes']),
        minSupportedCode: asIntOr(j['min_supported_code']),
        isMandatory: asBool(j['is_mandatory']),
        isPublished: asBool(j['is_published']),
        downloadCount: asIntOr(j['download_count']),
        downloadUrl: asStr(j['download_url']),
        createdAt: asDate(j['created_at']),
      );
}
