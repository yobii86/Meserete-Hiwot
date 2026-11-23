import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mezmur_zelideta/app/chrome.dart';
import 'package:mezmur_zelideta/app/shell.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/services/sync_status.dart';

GoRouter _buildRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(
            shell: navigationShell,
            location: state.uri.path,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/hub', builder: (_, _) => const Text('Hub Page')),
                GoRoute(path: '/edu', builder: (_, _) => const Text('Edu Home Page')),
                GoRoute(path: '/edu/learn', builder: (_, _) => const Text('Edu Learn Page')),
                GoRoute(path: '/edu/classes', builder: (_, _) => const Text('Edu Classes Page')),
                GoRoute(path: '/edu/library', builder: (_, _) => const Text('Edu Books Page')),
                GoRoute(path: '/edu/progress', builder: (_, _) => const Text('Edu Progress Page')),
                GoRoute(path: '/edu/more', builder: (_, _) => const Text('Edu More Page')),
                GoRoute(path: '/home', builder: (_, _) => const Text('Mezmur Home Page')),
                GoRoute(path: '/home/categories', builder: (_, _) => const Text('Mezmur Categories Page')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/library', builder: (_, _) => const Text('My Library Page')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/programs', builder: (_, _) => const Text('Programs Page')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/settings', builder: (_, _) => const Text('Settings Page')),
              ],
            ),
          ],
        ),
      ],
    );

class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() => const SyncStatus();
}

Widget _buildApp(GoRouter router) => ProviderScope(
      overrides: [
        isOnlineProvider.overrideWithValue(true),
        syncStatusProvider.overrideWith(_FakeSyncStatusNotifier.new),
      ],
      child: MaterialApp.router(
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
    );

void main() {
  group('NavLayout module bottom bar logic', () {
    test('Hub has no bottom navigation bar', () {
      final nav = NavLayout(section: HomeSection.hub, branch: 0, location: '/hub');
      expect(nav.showsBottomBar, isFalse);
    });

    test('Education has bottom navigation bar with 5 destinations', () {
      final navHome = NavLayout(section: HomeSection.education, branch: 0, location: '/edu');
      expect(navHome.showsBottomBar, isTrue);
      expect(navHome.isEducation, isTrue);
      expect(navHome.selectedIndex, 0);

      final navClasses = NavLayout(section: HomeSection.education, branch: 0, location: '/edu/classes');
      expect(navClasses.selectedIndex, 1);

      final navBooks = NavLayout(section: HomeSection.education, branch: 0, location: '/edu/library');
      expect(navBooks.selectedIndex, 2);

      final navProgress = NavLayout(section: HomeSection.education, branch: 0, location: '/edu/progress');
      expect(navProgress.selectedIndex, 3);

      final navSettings = NavLayout(section: HomeSection.education, branch: 3, location: '/settings?from=edu');
      expect(navSettings.selectedIndex, 4);

      // Verify route mappings
      expect(navHome.routeFor(0), '/edu');
      expect(navHome.routeFor(1), '/edu/classes');
      expect(navHome.routeFor(2), '/edu/library');
      expect(navHome.routeFor(3), '/edu/progress');
      expect(navHome.routeFor(4), '/settings?from=edu');
    });

    test('Mezmur has bottom navigation bar with 5 destinations', () {
      final navHome = NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home');
      expect(navHome.showsBottomBar, isTrue);
      expect(navHome.hasCategories, isTrue);
      expect(navHome.selectedIndex, 0);

      final navCat = NavLayout(section: HomeSection.mezmur, branch: 0, location: '/home/categories');
      expect(navCat.onCategories, isTrue);
      expect(navCat.selectedIndex, 1);
      expect(navCat.routeFor(1), '/home/categories');

      final navLib = NavLayout(section: HomeSection.mezmur, branch: 1, location: '/library');
      expect(navLib.selectedIndex, 2);
      expect(navLib.branchFor(2), 1);

      final navProg = NavLayout(section: HomeSection.mezmur, branch: 2, location: '/programs');
      expect(navProg.selectedIndex, 3);
      expect(navProg.branchFor(3), 2);

      final navSettings = NavLayout(section: HomeSection.mezmur, branch: 3, location: '/settings');
      expect(navSettings.selectedIndex, 4);
      expect(navSettings.branchFor(4), 3);
    });
  });

  group('AppShell bottom navigation bar rendering', () {
    testWidgets('Hub screen renders NO bottom navigation bar', (tester) async {
      final router = _buildRouter('/hub');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Hub Page'), findsOneWidget);
      // NavigationBar must be absent on the Hub
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Education module renders Education bottom navigation bar with 5 tabs', (tester) async {
      final router = _buildRouter('/edu');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Edu Home Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('edu-tab-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('edu-tab-classes')), findsOneWidget);
      expect(find.byKey(const ValueKey('edu-tab-books')), findsOneWidget);
      expect(find.byKey(const ValueKey('edu-tab-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('edu-tab-settings')), findsOneWidget);

      // Tap on Class tab and verify navigation and persistence
      await tester.tap(find.byKey(const ValueKey('edu-tab-classes')));
      await tester.pumpAndSettle();
      expect(find.text('Edu Classes Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Tap on Books tab and verify navigation and persistence
      await tester.tap(find.byKey(const ValueKey('edu-tab-books')));
      await tester.pumpAndSettle();
      expect(find.text('Edu Books Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Tap on Progress tab and verify navigation and persistence
      await tester.tap(find.byKey(const ValueKey('edu-tab-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Edu Progress Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Mezmur module renders Mezmur bottom navigation bar with 5 tabs', (tester) async {
      final router = _buildRouter('/home');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Mezmur Home Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('mezmur-tab-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('mezmur-tab-categories')), findsOneWidget);
      expect(find.byKey(const ValueKey('mezmur-tab-library')), findsOneWidget);
      expect(find.byKey(const ValueKey('mezmur-tab-programs')), findsOneWidget);
      expect(find.byKey(const ValueKey('mezmur-tab-settings')), findsOneWidget);

      // Tap on Categories tab and verify navigation and persistence
      await tester.tap(find.byKey(const ValueKey('mezmur-tab-categories')));
      await tester.pumpAndSettle();
      expect(find.text('Mezmur Categories Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Tap on Library tab and verify branch navigation and persistence
      await tester.tap(find.byKey(const ValueKey('mezmur-tab-library')));
      await tester.pumpAndSettle();
      expect(find.text('My Library Page'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Returning to Hub removes the bottom navigation bar', (tester) async {
      final router = _buildRouter('/edu');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);

      // Navigate to Hub
      router.go('/hub');
      await tester.pumpAndSettle();

      expect(find.text('Hub Page'), findsOneWidget);
      // NavigationBar must now be absent
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Pressing back button on /edu transitions cleanly to /hub without duplicate key error', (tester) async {
      final router = _buildRouter('/edu');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Edu Home Page'), findsOneWidget);

      // Simulate Android back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Hub Page'), findsOneWidget);
    });

    testWidgets('Pressing back button on /home transitions cleanly to /hub', (tester) async {
      final router = _buildRouter('/home');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Mezmur Home Page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Hub Page'), findsOneWidget);
    });

    testWidgets('Pressing back button on /edu/library transitions back to /edu', (tester) async {
      final router = _buildRouter('/edu/library');
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Edu Books Page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Edu Home Page'), findsOneWidget);
    });
  });
}
