import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mezmur_zelideta/app/chrome.dart';
import 'package:mezmur_zelideta/app/shell.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/sync_status.dart';
import 'package:mezmur_zelideta/services/unread_service.dart';
import 'package:mezmur_zelideta/widgets/brand.dart';

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      try {
        loader.addFont(rootBundle.load(f));
      } catch (_) {}
    }
    await loader.load();
  }

  await family('NotoSansEthiopic', [
    'assets/fonts/NotoSansEthiopic-400.ttf',
    'assets/fonts/NotoSansEthiopic-600.ttf',
  ]);
  await family('NotoSerifEthiopic', [
    'assets/fonts/NotoSerifEthiopic-600.ttf',
    'assets/fonts/NotoSerifEthiopic-700.ttf',
  ]);
  try {
    await family('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  } catch (_) {}
}

class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() => const SyncStatus();
}

class _FakeSessionController extends SessionController {
  @override
  SessionState build() {
    return SignedIn(
      AppUser.fromJson({
        'id': 1,
        'full_name': 'Abebe Bikila',
        'phone': '0911000000',
        'role': 'member',
        'roles': ['member', 'student'],
        'permissions': ['edu.access'],
        'status': 'active',
      }),
    );
  }
}

class _FakeUnreadNotifier extends UnreadCount {
  @override
  int build() => 3;
}

final Map<String, dynamic> _mockDashboardData = {
  'student': {
    'id': 1,
    'full_name': 'Abebe Bikila',
    'enrolled_classes': 1,
    'completed_lessons': 14,
    'overall_progress': 42,
    'quiz_average': 88,
  },
  'featured': [
    {
      'id': 101,
      'title': 'The Holy Trinity in Orthodox Doctrine',
      'subject_name': 'Theology',
      'lesson_number': 3,
      'duration_minutes': 25,
    }
  ],
  'continue': {
    'id': 201,
    'title': 'Nicene Creed — Part 2',
    'subject_name': 'Theology & Doctrine',
    'lesson_number': 4,
    'progress_percent': 65,
  },
  'categories': [
    {'id': 1, 'name': 'ትምህርተ ሃይማኖት', 'name_en': 'Theology & Doctrine', 'sort_order': 1},
    {'id': 4, 'name': 'የመጽሐፍ ቅዱስ ጥናት', 'name_en': 'Bible Study', 'sort_order': 2},
  ],
  'classes': [
    {
      'id': 1,
      'name': 'Grade 7 Sunday School',
      'academic_year': '2019 ዓ.ም',
      'grade': '7ኛ ክፍል',
      'teacher_name': 'Dn. Yohannes',
    }
  ],
  'open_registration': 0,
};

GoRouter _buildRouter(GlobalKey boundaryKey) => GoRouter(
      initialLocation: '/edu',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => RepaintBoundary(
            key: boundaryKey,
            child: AppShell(
              shell: navigationShell,
              location: state.uri.path,
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/edu',
                  builder: (_, _) => const EduHomeScreen(),
                ),
                GoRoute(path: '/edu/classes', builder: (_, _) => const Scaffold(body: Center(child: Text('Classes')))),
                GoRoute(path: '/edu/library', builder: (_, _) => const Scaffold(body: Center(child: Text('Library')))),
                GoRoute(path: '/edu/progress', builder: (_, _) => const Scaffold(body: Center(child: Text('Progress')))),
                GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Center(child: Text('Settings')))),
                GoRoute(path: '/hub', builder: (_, _) => const Scaffold(body: Center(child: Text('Hub')))),
                GoRoute(path: '/edu/search', builder: (_, _) => const Scaffold(body: Center(child: Text('Search')))),
                GoRoute(path: '/notifications', builder: (_, _) => const Scaffold(body: Center(child: Text('Notifications')))),
              ],
            ),
          ],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture exact Education home page two-row header and layout screenshot', (tester) async {
    await tester.runAsync(_loadFonts);

    final boundaryKey = GlobalKey();
    final router = _buildRouter(boundaryKey);

    // Standard phone dimensions (390 x 844 dp)
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          syncStatusProvider.overrideWith(_FakeSyncStatusNotifier.new),
          sessionProvider.overrideWith(_FakeSessionController.new),
          unreadCountProvider.overrideWith(_FakeUnreadNotifier.new),
          eduDashboardProvider.overrideWith((ref) => Future.value(_mockDashboardData)),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify Row 1: AppTopBar elements
    expect(find.byType(AppTopBar), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byKey(const ValueKey('edu-back-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('edu-search')), findsOneWidget);

    // Verify Row 2: Education Module Header elements
    expect(find.text('Education'), findsWidgets); // Single line Education title
    expect(find.text('Sunday School Learning'), findsOneWidget);
    expect(find.byType(EduIcon), findsWidgets);

    // Verify Bottom Navigation Bar has 5 destinations
    expect(find.byType(NavigationBar), findsOneWidget);

    // Capture screenshot
    await tester.runAsync(() async {
      final boundary = tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final outDir = Directory(r'C:\Users\HP\.gemini\antigravity-ide\brain\3adbc350-4fcf-4904-aa26-1a9273a3b823');
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }
      final outFile = File(r'C:\Users\HP\.gemini\antigravity-ide\brain\3adbc350-4fcf-4904-aa26-1a9273a3b823\education_home_header_screenshot.png');
      outFile.writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('SCREENSHOT_SAVED: ${outFile.path} (${bytes.length} bytes)');
    });
  });
}
