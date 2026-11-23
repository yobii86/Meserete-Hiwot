import '../../widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/admin.dart';
import 'admin_widgets.dart' show UserSelection;

import 'admin_home.dart';
import 'choir_admin.dart';
import 'content_admin.dart';
import 'extra_admin.dart';
import 'import_admin.dart';
import 'org_admin.dart';
import 'library_admin.dart';
import 'library_requests_admin.dart';
import '../library/circulation_screen.dart';
import 'programs_admin.dart';
import 'selections_admin.dart';
import 'stage_admin.dart';
import 'wedding_admin.dart';
import 'supervision_admin.dart';
import 'system_console.dart';
import 'users_admin.dart';
import 'member_id_admin.dart';
import 'notification_admin.dart';
import 'diagnostics_admin_screen.dart';
import '../guidance/admin_guidance_screen.dart';
import '../chat/chat_screens.dart';
import 'receipt_review_screen.dart';
import 'attendance_management_screen.dart';
import 'media_migration_screen.dart';
import 'contribution_details_screen.dart';
import '../programs/calendar/unified_calendar_screen.dart';

int _id(GoRouterState s) => int.parse(s.pathParameters['id']!);
int? _optId(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '');

/// Admin & system routes. They sit on the root navigator (full-screen, no bottom bar).
/// Access is additionally checked in the router redirect and — authoritatively — by the API.
List<RouteBase> adminRoutes(GlobalKey<NavigatorState> root) => [
      GoRoute(
        path: '/admin',
        parentNavigatorKey: root,
        builder: (_, s) => AdminHomeScreen(initialScope: s.uri.queryParameters['module']),
        routes: [
          GoRoute(path: 'users', builder: (_, _) => const UsersAdminScreen()),
          GoRoute(path: 'users/:id', builder: (_, s) => SecureScreen(child: UserDetailAdminScreen(userId: _id(s)))),
          GoRoute(path: 'mezmurs', builder: (_, _) => const MezmursAdminScreen()),
          GoRoute(
            path: 'mezmurs/edit/:id',
            builder: (_, s) => MezmurEditorScreen(mezmurId: _optId(s), initialCategoryId: int.tryParse(s.uri.queryParameters['category'] ?? '')),
          ),
          GoRoute(path: 'categories', builder: (_, _) => const CategoriesAdminScreen()),
          GoRoute(path: 'ads', builder: (_, _) => const AdsAdminScreen()),
          GoRoute(path: 'pages', builder: (_, _) => const PagesAdminScreen()),
          GoRoute(path: 'pages/edit/:id', builder: (_, s) => PageEditorScreen(pageId: _optId(s))),
          GoRoute(path: 'programs', builder: (_, _) => const ProgramsAdminScreen()),
          GoRoute(path: 'programs/calendar', builder: (_, _) => const UnifiedCalendarScreen()),
          GoRoute(path: 'programs/edit/:id', builder: (_, s) => ProgramEditorScreen(programId: _optId(s))),
          GoRoute(path: 'programs/:id/participants', builder: (_, s) => ParticipantsScreen(programId: _id(s))),
          GoRoute(path: 'programs/:id/attendance', builder: (_, s) => AttendanceRosterScreen(programId: _id(s), initialSource: s.uri.queryParameters['source'])),
          GoRoute(path: 'attendance', builder: (_, _) => const AttendanceManagementScreen()),
          GoRoute(path: 'permissions', builder: (_, _) => const PermissionRequestsScreen()),
          GoRoute(path: 'import', builder: (_, _) => const ImportScreen()),
          GoRoute(path: 'departments', builder: (_, _) => const DepartmentsScreen()),
          GoRoute(
            path: 'payments',
            builder: (_, s) => ContributionDetailsAdminScreen(
              initialPeriod: s.uri.queryParameters['period'],
            ),
          ),
          GoRoute(
            path: 'contributions',
            builder: (_, s) => ContributionDetailsAdminScreen(
              initialPeriod: s.uri.queryParameters['period'],
            ),
          ),
          GoRoute(
            path: 'receipt-review',
            builder: (_, s) => ReceiptReviewAdminScreen(
              initialReceiptId: int.tryParse(s.uri.queryParameters['id'] ?? ''),
            ),
          ),
          GoRoute(path: 'selections', builder: (_, _) => const SelectionsScreen()),
          GoRoute(path: 'member-ids', builder: (_, _) => const MemberIdFormatScreen()),
          GoRoute(path: 'member-groups', builder: (_, _) => const MemberGroupsScreen()),
          GoRoute(path: 'weddings', builder: (_, _) => const WeddingsScreen()),
          GoRoute(path: 'property-requests', builder: (_, _) => const PropertyRequestsScreen()),
          GoRoute(path: 'attendance/corrections', builder: (_, _) => const AttendanceCorrectionsScreen()),
          GoRoute(path: 'attendance/rules', builder: (_, _) => const AttendanceSignaturePolicyScreen()),
          GoRoute(path: 'attendance/conflicts', builder: (_, _) => const AttendanceConflictsScreen()),
          GoRoute(path: 'library-requests', builder: (_, _) => const LibraryRequestsAdminScreen()),
          GoRoute(path: 'library/circulation', builder: (_, s) => LibraryCirculationScreen(initialCopyCode: s.uri.queryParameters['code'])),
          GoRoute(path: 'borrowings/direct-policy', builder: (_, _) => const DirectBorrowingPolicyScreen()),
          GoRoute(path: 'program-categories', builder: (_, _) => const ProgramCategoriesAdminScreen()),
          GoRoute(path: 'change-requests', builder: (_, _) => const ChangeRequestsScreen()),
          GoRoute(path: 'releases', builder: (_, _) => const ReleasesScreen()),
          GoRoute(
            path: 'notify',
            builder: (_, s) => SendNotificationScreen(initialTarget: s.extra is BulkTarget ? s.extra as BulkTarget : null, resend: s.extra is Map<String, dynamic> ? s.extra as Map<String, dynamic> : null),
          ),
          GoRoute(path: 'notify/:id', builder: (_, s) => BroadcastDetailScreen(broadcastId: _id(s))),
          GoRoute(path: 'notification-health', builder: (_, _) => const NotificationHealthScreen()),
          GoRoute(path: 'items', builder: (_, _) => const ItemsAdminScreen()),
          GoRoute(path: 'borrowings', builder: (_, s) => BorrowingsAdminScreen(initialFilter: s.extra as Map<String, dynamic>?)),
          GoRoute(path: 'borrowings/new', builder: (_, _) => const IssueBorrowingScreen()),
          GoRoute(path: 'borrowings/bulk', builder: (_, s) => BulkBorrowingScreen(initial: s.extra as UserSelection?)),
          GoRoute(path: 'borrowings/:id', builder: (_, s) => BorrowingAdminDetailScreen(borrowingId: _id(s))),
          GoRoute(path: 'fines', builder: (_, _) => const FinesAdminScreen()),
          GoRoute(path: 'reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(path: 'audit', builder: (_, _) => const AuditLogScreen()),
          GoRoute(path: 'activity', builder: (_, s) => ActivityLogScreen(initialFilter: s.extra as Map<String, dynamic>?)),
          GoRoute(path: 'diagnostics', builder: (_, _) => const DiagnosticsAdminScreen()),
          GoRoute(path: 'media-migration', builder: (_, _) => const MediaMigrationAdminScreen()),
          GoRoute(path: 'admins', builder: (_, _) => const AdminsScreen()),
          GoRoute(path: 'admins/:id', builder: (_, s) => AdminEditorScreen(adminId: _optId(s))),
          GoRoute(path: 'roles', builder: (_, _) => const RolesScreen()),
          GoRoute(path: 'settings', builder: (_, _) => const SystemSettingsScreen()),
          GoRoute(path: 'guidance', builder: (_, _) => const AdminGuidanceScreen()),
          GoRoute(
            path: 'chat',
            builder: (_, _) => const ChatListScreen(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => DepartmentChatScreen(departmentId: _id(s))),
              GoRoute(path: ':id/private', builder: (_, s) => ChatThreadsScreen(departmentId: _id(s))),
              GoRoute(
                path: ':id/user/:uid',
                builder: (_, s) => ConversationScreen(departmentId: _id(s), thread: 'user:${s.pathParameters['uid']}', peerName: s.uri.queryParameters['name']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/system', parentNavigatorKey: root, builder: (_, _) => const SystemConsoleScreen()),
    ];
