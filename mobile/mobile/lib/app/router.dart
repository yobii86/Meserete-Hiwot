import '../widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/sessions_screen.dart';
import 'deep_links.dart';
import '../features/settings/notification_settings_screen.dart';
import '../features/admin/admin_routes.dart';
import '../features/admin/library_requests_admin.dart';
import '../features/auth/auth_screens.dart';
import '../features/auth/session.dart';
import '../features/auth/system_login_screen.dart';
import '../features/support/report_problem_screen.dart';
import '../features/edu/edu_academics.dart';
import '../features/edu/edu_admin_panel.dart';
import '../features/edu/edu_assign.dart';
import '../features/edu/edu_manage.dart';
import '../features/edu/edu_registration.dart';
import '../features/edu/edu_screens.dart';
import '../features/edu/edu_scores_screen.dart';
import '../features/edu/learn/content_admin.dart';
import '../features/edu/learn/edu_home.dart';
import '../features/edu/learn/learn_screens.dart';
import '../features/edu/learn/magazine_admin.dart';
import '../features/edu/learn/magazine_screens.dart';
import '../features/edu/learn/materials_admin.dart';
import '../features/edu/learn/progression_settings.dart';
import '../features/edu/learn/progress_more.dart';
import '../features/edu/learn/quizzes_admin.dart';
import '../features/edu/learn/quiz_screens.dart';
import '../features/edu/admin/admin_grades_screen.dart';
import '../features/edu/admin/edu_attendance_dashboard_screen.dart';
import '../features/edu/admin/edu_book_catalog_screen.dart';
import '../features/edu/announcements/announcements_screens.dart';
import '../features/edu/assignments/assignments_screens.dart';
import '../features/edu/learn/grade_content_screen.dart';
import '../features/edu/learn/subject_grades_screen.dart';
import '../features/home/home_screen.dart';
import '../features/hub/hub_screen.dart';
import '../features/library/books_screen.dart';
import '../features/library/circulation_screen.dart';
import '../features/library/library_screen.dart';
import '../features/mezmurs/category_screen.dart';
import '../features/mezmurs/mezmur_screen.dart';
import '../features/mezmurs/search_screen.dart';
import '../features/mezmurs/widgets.dart' show MezmurListScreen;
import '../features/notifications/notifications_screen.dart';
import '../features/pages/internal_page_screen.dart';
import '../features/player/now_playing_screen.dart';
import '../features/programs/alarm_screen.dart';
import '../features/programs/program_detail_screen.dart';
import '../features/programs/programs_screen.dart';
import '../features/programs/calendar/unified_calendar_screen.dart';
import '../features/sinksar/sinksar_screen.dart';
import '../features/settings/account_screens.dart';
import '../features/settings/attendance_calendar.dart';
import '../features/settings/my_data_screen.dart';
import '../features/settings/reminders_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/update/force_update_screen.dart';
import '../models/admin.dart';
import '../services/update_service.dart';
import 'shell.dart';
import '../features/mezmurs/categories_screen.dart';
import '../features/chat/chat_screens.dart';
import '../features/projects/project_routes.dart';
import '../features/guidance/guidance_center_screen.dart';
import '../widgets/brand.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showModuleDisabledSnackbar() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ይህ ክፍል ለጊዜው ተዘግቷል', style: TextStyle(fontFamily: 'NotoSansEthiopic')),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF6E1423),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(updateProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/login', '/register', '/forgot', '/system-login'};

/// While a new PIN must be set: stay on the change page (and only that page) until it is done.
/// Returning null there is what prevents the /change-password ⇄ /hub redirect loop.
String? forcedPinRedirect(String loc) => loc == '/change-password' ? null : '/change-password';

int _id(GoRouterState s, [String name = 'id']) => int.tryParse(s.pathParameters[name] ?? '') ?? 0;

/// Content routes shared by several tabs. A category keeps the app bars; a Mezmur opens its
/// full-screen player page — the same page the mini player opens — on the root navigator.
List<RouteBase> _contentRoutes() => [
      GoRoute(path: 'category/:id', builder: (_, s) => CategoryScreen(categoryId: _id(s))),
      GoRoute(
        path: 'mezmur/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, s) => MaterialPage(
          key: s.pageKey,
          child: ModuleBackgroundWrapper(
            kind: ModuleBackgroundKind.mezmur,
            child: MezmurScreen(mezmurId: _id(s)),
          ),
        ),
      ),
    ];

/// Shared web links (https://host/m/12 …) → the app page they stand for.
String? _shareRedirect(String path) {
  final m = RegExp(r'^/(m|p|c|pg)/(\d+)/?$').firstMatch(path);
  if (m == null) return null;
  final id = m.group(2);
  return switch (m.group(1)) {
    'm' => '/home/mezmur/$id',
    'p' => '/programs/$id',
    'c' => '/home/category/$id',
    _ => '/home/page/$id',
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);
  // A link opened while signed out is remembered and opened right after sign-in.
  String? pendingLink;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    errorBuilder: (context, state) => const HubScreen(),
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final shared = _shareRedirect(state.uri.path);
      if (shared != null) return shared;
      final loc = state.matchedLocation;
      // An unsupported app version is blocked until it is updated from the download page.
      final forced = ref.read(updateProvider)?.force ?? false;
      if (forced) return loc == '/update' ? null : '/update';
      if (loc == '/update') return '/splash';
      if (session is SessionUnknown) {
        if (loc != '/splash' && !_publicRoutes.contains(loc) && loc != '/home' && loc != '/hub') pendingLink = state.uri.toString();
        return loc == '/splash' ? null : '/splash';
      }
      if (session is SignedOut || session is SessionUnknown) {
        if (!_publicRoutes.contains(loc) && loc != '/splash' && loc != '/home' && loc != '/hub') pendingLink = state.uri.toString();
      }
      if (session is SignedOut) return _publicRoutes.contains(loc) ? null : '/login';
      final signed = session as SignedIn;
      if (signed.user.mustChangePassword) return forcedPinRedirect(loc);
      // Module access resolution
      final access = signed.user.moduleAccess;

      // Deep link to disabled module redirects to active module with Amharic snackbar
      if (loc.startsWith('/edu') && !access.education) {
        showModuleDisabledSnackbar();
        return access.mezmur ? '/home' : '/hub';
      }
      if ((loc.startsWith('/home') || loc == '/player') && !access.mezmur) {
        showModuleDisabledSnackbar();
        return access.education ? '/edu' : '/hub';
      }

      // The forced change is done: leave the change-password page (it used to stay there and
      // ask again, as if the new password had not been accepted).
      if (loc == '/splash' || _publicRoutes.contains(loc) || loc == '/change-password') {
        final target = pendingLink;
        pendingLink = null;
        if (target != null) {
          if (target.startsWith('/edu') && !access.education) {
            showModuleDisabledSnackbar();
            return access.mezmur ? '/home' : '/hub';
          }
          if ((target.startsWith('/home') || target.startsWith('/player')) && !access.mezmur) {
            showModuleDisabledSnackbar();
            return access.education ? '/edu' : '/hub';
          }
          return target;
        }
        // If only one module is enabled, open it directly without showing a module-selection page
        if (access.onlyMezmur) return '/home';
        if (access.onlyEducation) return '/edu';
        return '/hub'; // the super-app home
      }

      // If user navigates directly to /hub when only one module is enabled:
      if (loc == '/hub') {
        if (access.onlyMezmur) return '/home';
        if (access.onlyEducation) return '/edu';
      }

      // An HR-assigned attendance taker may hold no admin permission: the attendance pages stay
      // open to them (the server decides who records which session).
      final takerPage = loc == '/admin/attendance' || RegExp(r'^/admin/programs/\d+/attendance$').hasMatch(loc);
      if (loc.startsWith('/admin') && !signed.user.isAdmin && !takerPage) return '/hub';
      if (loc.startsWith('/system') && !signed.isSystem) return '/hub';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/hub'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      // Share-link paths; the redirect above maps them to the real pages.
      for (final k in ['m', 'p', 'c', 'pg']) GoRoute(path: '/$k/:id', redirect: (_, s) => _shareRedirect(s.uri.path) ?? '/home'),
      // Links from emails / notifications (https://…/open/{type}/{id} or mezmurzelideta://open/o/{type}/{id}):
      // the same screen a tapped push notification opens.
      for (final prefix in ['/o', '/open'])
        GoRoute(path: '$prefix/:type/:id', redirect: (_, s) => routeForEntity(s.pathParameters['type'], int.tryParse(s.pathParameters['id'] ?? '')).replaceFirst(RegExp(r'/0$'), '')),
      GoRoute(path: '/update', builder: (_, _) => const ForceUpdateScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/system-login', builder: (_, _) => const SystemLoginScreen()),
      GoRoute(path: '/change-password', builder: (_, _) => const ChangePasswordScreen(forced: true)),
      GoRoute(
        path: '/player',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => const MaterialPage(
          fullscreenDialog: true,
          child: ModuleBackgroundWrapper(
            kind: ModuleBackgroundKind.mezmur,
            child: NowPlayingScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/alarm/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, s) {
          final id = _id(s);
          final type = s.uri.queryParameters['type'] ?? (id >= (1 << 30) ? 'program' : 'reminder');
          return MaterialPage(
            fullscreenDialog: true,
            child: AlarmScreen(
              programId: type == 'program' ? id : null,
              reminderId: type == 'reminder' ? id : null,
              title: s.uri.queryParameters['title'],
              note: s.uri.queryParameters['note'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/sinksar',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SinksarScreen(),
      ),
      GoRoute(
        path: '/sinksar/:date',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => SinksarScreen(initialDate: s.pathParameters['date']),
      ),
      GoRoute(
        path: '/support/report-problem',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => ReportProblemScreen(
          initialModule: s.uri.queryParameters['module'],
          initialScreen: s.uri.queryParameters['screen'],
          initialErrorMessage: s.uri.queryParameters['error'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell, location: state.uri.path),
        branches: [
          // Home: the hub (ትምህርት and መዝሙር cards), both sections, and the notifications list.
          StatefulShellBranch(routes: [
            GoRoute(path: '/hub', builder: (_, _) => const HubScreen()),
            GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
            GoRoute(
              path: '/edu',
              builder: (_, _) => const EduHomeScreen(),
              routes: [
                // ትምህርት tabs: Home (/edu) · Learn · Classes · Progress · More.
                GoRoute(path: 'learn', builder: (_, _) => const EduLearnScreen()),
                GoRoute(path: 'learn/category/:id', builder: (_, s) => EduCategoryScreen(categoryId: _id(s))),
                GoRoute(path: 'learn/subject/:id', builder: (_, s) => EduSubjectScreen(subjectId: _id(s))),
                GoRoute(path: 'learn/lesson/:id', builder: (_, s) => EduLessonScreen(lessonId: _id(s))),
                GoRoute(path: 'category/:id', redirect: (_, s) => '/edu/learn/category/${s.pathParameters['id']}'),
                GoRoute(path: 'category/:id/grades', redirect: (_, s) => '/edu/learn/category/${s.pathParameters['id']}'),
                GoRoute(path: 'subject/:id/grades', builder: (_, s) => EduSubjectGradesScreen(subjectId: _id(s))),
                GoRoute(path: 'subject/:id/grade/:grade', builder: (_, s) => EduGradeContentScreen(subjectId: _id(s), gradeNumber: _id(s, 'grade'))),
                GoRoute(path: 'classes', builder: (_, _) => const EduClassesScreen()),
                GoRoute(path: 'progress', builder: (_, _) => const EduProgressScreen()),
                GoRoute(path: 'more', builder: (_, _) => const EduMoreScreen()),
                GoRoute(path: 'search', builder: (_, _) => const EduSearchScreen()),
                // Quizzes: students take them; teachers edit, see results and grade written answers.
                GoRoute(
                  path: 'quiz/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduQuizScreen(quizId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'attempt/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAttemptScreen(attemptId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'quiz-edit/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduQuizEditorScreen(quizId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'quiz-results/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduQuizResultsScreen(quizId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'quiz-attempt/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduTeacherAttemptScreen(attemptId: _id(s)),
                  ),
                ),
                // ሰሌዳ መጽሔት (Seleda Magazine)
                GoRoute(path: 'magazines', builder: (_, _) => const EduMagazinesListScreen()),
                GoRoute(path: 'magazines/:id', redirect: (_, s) => '/edu/magazine/${s.pathParameters['id']}'),
                GoRoute(
                  path: 'magazine/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduMagazineDetailScreen(magazineId: _id(s)),
                  ),
                ),
                // Assignments and Classroom workflow (Feature D)
                GoRoute(
                  path: 'assignments',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAssignmentsScreen(
                      courseId: int.tryParse(s.uri.queryParameters['course_id'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'assignment/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAssignmentDetailScreen(id: _id(s)),
                  ),
                ),
                // Teacher Announcements (Feature E)
                GoRoute(
                  path: 'announcements',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAnnouncementsScreen(
                      courseId: int.tryParse(s.uri.queryParameters['course_id'] ?? ''),
                      classId: int.tryParse(s.uri.queryParameters['class_id'] ?? ''),
                    ),
                  ),
                ),
                // Canonical Admin Grades CRUD (Feature C)
                GoRoute(
                  path: 'admin/grades',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAdminGradesScreen(),
                  ),
                ),
                // Learning content (categories, curriculum, featured): full-screen pages over the tabs.
                GoRoute(
                  path: 'content',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduContentScreen(initialTab: s.uri.queryParameters['tab']),
                  ),
                ),
                GoRoute(
                  path: 'content/units-lessons',
                  parentNavigatorKey: rootNavigatorKey,
                  redirect: (_, _) => '/edu/content',
                ),
                GoRoute(
                  path: 'content/materials',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduMaterialsAdminScreen(
                      initialSubjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'content/category/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  redirect: (_, _) => '/edu/content',
                ),
                GoRoute(
                  path: 'content/category/new',
                  parentNavigatorKey: rootNavigatorKey,
                  redirect: (_, _) => '/edu/content',
                ),
                GoRoute(
                  path: 'content/subject/new',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: SubjectFormScreen(
                      initialCategoryId: int.tryParse(s.uri.queryParameters['category'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'content/subject/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) {
                    final id = int.tryParse(s.pathParameters['id'] ?? '');
                    if (id == null) {
                      return ModuleBackgroundWrapper(
                        kind: ModuleBackgroundKind.education,
                        child: SubjectFormScreen(
                          initialCategoryId: int.tryParse(s.uri.queryParameters['category'] ?? ''),
                        ),
                      );
                    }
                    return ModuleBackgroundWrapper(
                      kind: ModuleBackgroundKind.education,
                      child: EduSubjectEditorScreen(subjectId: id),
                    );
                  },
                ),
                GoRoute(
                  path: 'content/subject/:id/new-lesson',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduLessonEditorScreen(subjectId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'content/unit/new',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduUnitEditorScreen(
                      subjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'content/unit/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) {
                    final id = int.tryParse(s.pathParameters['id'] ?? '');
                    return ModuleBackgroundWrapper(
                      kind: ModuleBackgroundKind.education,
                      child: EduUnitEditorScreen(
                        unitId: id,
                        subjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'content/lesson/new',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduLessonEditorScreen(
                      subjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                      unitId: int.tryParse(s.uri.queryParameters['unit_id'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'content/lesson/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) {
                    final id = int.tryParse(s.pathParameters['id'] ?? '');
                    if (id == null) {
                      return ModuleBackgroundWrapper(
                        kind: ModuleBackgroundKind.education,
                        child: EduLessonEditorScreen(
                          subjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                          unitId: int.tryParse(s.uri.queryParameters['unit_id'] ?? ''),
                        ),
                      );
                    }
                    return ModuleBackgroundWrapper(
                      kind: ModuleBackgroundKind.education,
                      child: EduLessonEditorScreen(lessonId: id),
                    );
                  },
                ),
                GoRoute(path: 'register', builder: (_, _) => const EduRegisterScreen()),
                GoRoute(path: 'class/:id', builder: (_, s) => EduClassScreen(classId: _id(s), initialTab: s.uri.queryParameters['tab'])),
                GoRoute(path: 'course/:id', builder: (_, s) => EduCourseScreen(courseId: _id(s), initialTab: s.uri.queryParameters['tab'])),
                // Requests, complaints and the academic journey (the signed-in student).
                GoRoute(path: 'services', builder: (_, s) => EduSelfServiceScreen(initialTab: s.uri.queryParameters['tab'])),
                GoRoute(path: 'complaint/:id', builder: (_, s) => EduComplaintScreen(id: _id(s))),
                // Education administrators (the server refuses anyone else).
                GoRoute(
                  path: 'admin',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAdminPanelScreen(),
                  ),
                ),
                GoRoute(
                  path: 'review',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduReviewScreen(initialTab: s.uri.queryParameters['tab']),
                  ),
                ),
                GoRoute(
                  path: 'review/assessment/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduMarksReviewScreen(assessmentId: _id(s)),
                  ),
                ),
                GoRoute(
                  path: 'review/complaint/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduComplaintScreen(id: _id(s), admin: true),
                  ),
                ),
                GoRoute(
                  path: 'my-scores',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduStudentScoresView(),
                  ),
                ),
                GoRoute(
                  path: 'admin/scores',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduScoresScreen(),
                  ),
                ),
                GoRoute(
                  path: 'admin/attendance',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAttendanceDashboardScreen(),
                  ),
                ),
                GoRoute(
                  path: 'admin/catalog',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduBookCatalogScreen(),
                  ),
                ),
                GoRoute(
                  path: 'admin/quizzes',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduQuizzesAdminScreen(
                      initialSubjectId: int.tryParse(s.uri.queryParameters['subject_id'] ?? ''),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'admin/magazines',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduMagazinesAdminScreen(),
                  ),
                ),
                GoRoute(
                  path: 'admin/progression-settings',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduProgressionSettingsScreen(),
                  ),
                ),
                GoRoute(path: 'journey/:id', builder: (_, s) => EduStudentJourneyScreen(userId: _id(s))),
                GoRoute(path: 'attendance/:id', builder: (_, s) => EduAttendanceScreen(classId: _id(s))),
                GoRoute(
                  path: 'borrowings',
                  builder: (_, _) => const MyBorrowingsScreen(domain: 'timhirt', detailBase: '/edu/borrowings'),
                  routes: [GoRoute(path: ':id', builder: (_, s) => MyBorrowingDetailScreen(borrowingId: _id(s)))],
                ),
                // The education library: digital books (PDF downloads), printed books to request and
                // the member's requests / borrowings. It replaces "My Library" in the ትምህርት tab bar.
                GoRoute(path: 'library', builder: (_, _) => const LibraryBooksScreen(domain: 'timhirt', borrowingsRoute: '/edu/borrowings')),
                GoRoute(
                  path: 'circulation',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: LibraryCirculationScreen(initialCopyCode: s.uri.queryParameters['code']),
                  ),
                ),
                GoRoute(
                  path: 'library-requests',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: LibraryRequestsAdminScreen(),
                  ),
                ),
                // Course management and student registration are opened from Settings (and the admin
                // panel): full-screen pages over the tabs.
                GoRoute(
                  path: 'calendar',
                  parentNavigatorKey: rootNavigatorKey,
                  redirect: (_, _) => '/edu',
                ),
                GoRoute(
                  path: 'manage',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduManageScreen(),
                  ),
                ),
                GoRoute(
                  path: 'manage/class/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduClassEditorScreen(classId: int.tryParse(s.pathParameters['id'] ?? '')),
                  ),
                ),
                GoRoute(
                  path: 'manage/class/:id/assign',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, s) => ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduAssignStudentsScreen(
                      classId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
                      className: s.uri.queryParameters['name'],
                    ),
                  ),
                ),
                GoRoute(
                  path: 'registrations',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduRegistrationScreen(),
                  ),
                ),
                GoRoute(
                  path: 'courses',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const ModuleBackgroundWrapper(
                    kind: ModuleBackgroundKind.education,
                    child: EduCoursesScreen(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const HomeScreen(),
              routes: [
                ..._contentRoutes(),
                GoRoute(path: 'search', builder: (_, _) => const SearchScreen()),
                GoRoute(path: 'categories', builder: (_, _) => const MezmurCategoriesScreen()),
                GoRoute(path: 'mezmurs', builder: (_, s) => MezmurListScreen(sort: s.uri.queryParameters['sort'] == 'popular' ? 'popular' : 'recent')),
                GoRoute(path: 'page/:id', builder: (_, s) => InternalPageScreen(pageId: _id(s))),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/library',
              builder: (_, s) => LibraryScreen(initialTab: s.uri.queryParameters['tab'] == 'downloads' ? 1 : 0),
              routes: _contentRoutes(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/programs',
              builder: (_, _) => const ProgramsScreen(),
              routes: [
                GoRoute(path: 'calendar', builder: (_, _) => const UnifiedCalendarScreen()),
                GoRoute(path: ':id', builder: (_, s) => ProgramDetailScreen(programId: _id(s))),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, s) => SettingsScreen(from: s.uri.queryParameters['from']),
              routes: [
                // User data: ID, member card, attendance calendar, choir, payments, borrowed items.
                GoRoute(path: 'me', builder: (_, _) => const SecureScreen(child: MyDataScreen())),
                GoRoute(path: 'payments', builder: (_, _) => const MyPaymentsScreen()),
                GoRoute(path: 'profile', builder: (_, _) => const SecureScreen(child: ProfileScreen())),
                GoRoute(path: 'password', builder: (_, _) => const ChangePasswordScreen()),
                GoRoute(path: 'sessions', builder: (_, _) => const SessionsScreen()),
                GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
                GoRoute(path: 'downloads', builder: (_, _) => const DownloadSettingsScreen()),
                GoRoute(path: 'categories', builder: (_, _) => const PreferredCategoriesScreen()),
                GoRoute(path: 'attendance', builder: (_, _) => const AttendanceCalendarScreen()),
                // Department chat: list → group room → private conversations.
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
                GoRoute(
                  path: 'reminders',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const RemindersManagementScreen(),
                ),
                GoRoute(
                  path: 'guidance',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const GuidanceCenterScreen(),
                ),
                GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                GoRoute(
                  path: 'borrowings',
                  builder: (_, _) => const MyBorrowingsScreen(domain: 'mezmur'),
                  routes: [GoRoute(path: ':id', builder: (_, s) => MyBorrowingDetailScreen(borrowingId: _id(s)))],
                ),
              ],
            ),
          ]),
        ],
      ),
      // A notification about a book request: the librarian's queue, or the member's library ("Mine").
      GoRoute(
        path: '/library-request/:id',
        redirect: (_, _) {
          final session = ref.read(sessionProvider);
          final librarian = session is SignedIn && session.user.can(Perm.borrowingManage);
          return librarian ? '/admin/library-requests' : '/edu/library';
        },
      ),
      // Old links to ስለ እኔ open the user-data page.
      GoRoute(path: '/me', redirect: (_, _) => '/settings/me', routes: [GoRoute(path: 'payments', redirect: (_, _) => '/settings/payments')]),
      GoRoute(path: '/chat', redirect: (_, _) => '/settings/chat'),
      GoRoute(path: '/chat/:id', redirect: (_, s) => '/settings/chat/${s.pathParameters['id']}'),
      GoRoute(
        path: '/guidance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const GuidanceCenterScreen(),
      ),
      // Direct navigation aliases for guidance targets and deep links
      GoRoute(path: '/about', redirect: (_, _) => '/settings/about'),
      GoRoute(path: '/offline-status', redirect: (_, _) => '/hub'),
      GoRoute(path: '/library/books', redirect: (_, _) => '/edu/library'),
      GoRoute(path: '/edu/results', redirect: (_, _) => '/edu/progress'),
      GoRoute(path: '/edu/retakes', redirect: (_, _) => '/edu/services'),
      GoRoute(path: '/edu/exams', redirect: (_, _) => '/edu'),
      GoRoute(path: '/edu/certificates', redirect: (_, _) => '/edu'),
      GoRoute(path: '/admin/edu/certificates', redirect: (_, _) => '/edu/manage'),
      GoRoute(path: '/admin/edu/assignments', redirect: (_, _) => '/edu/assignments'),
      GoRoute(path: '/admin/edu/classes', redirect: (_, _) => '/edu/manage'),
      GoRoute(path: '/admin/edu/academic-years', redirect: (_, _) => '/edu/manage'),
      GoRoute(path: '/admin/edu/programs', redirect: (_, _) => '/admin/programs'),
      GoRoute(path: '/admin/selections/intervals', redirect: (_, _) => '/admin/selections'),
      GoRoute(path: '/admin/edu/scores', redirect: (_, _) => '/edu/admin/scores'),
      GoRoute(path: '/admin/edu/attendance', redirect: (_, _) => '/edu/admin/attendance'),
      GoRoute(path: '/admin/edu/magazines', redirect: (_, _) => '/edu/admin/magazines'),
      GoRoute(path: '/admin/catalog', redirect: (_, _) => '/edu/admin/catalog'),
      GoRoute(path: '/admin/edu/catalog', redirect: (_, _) => '/edu/admin/catalog'),
      GoRoute(path: '/edu/library', redirect: (_, _) => '/edu/admin/catalog'),
      ...adminRoutes(rootNavigatorKey),
      ...projectRoutes(rootNavigatorKey),
    ],
  );
});
