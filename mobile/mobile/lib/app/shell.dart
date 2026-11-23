import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/member_groups.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/player/mini_player.dart';
import '../features/auth/session.dart';
import '../widgets/brand.dart';
import '../widgets/states.dart';
import 'chrome.dart';

/// The app frame used everywhere after sign-in: the shared top bar (logo, search, notifications,
/// theme) and module-specific bottom navigation bars for Education and Mezmur.
/// The global Hub has no persistent bottom navigation bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell, required this.location});

  final StatefulNavigationShell shell;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Last place visited in the Home tab (kept while another tab is open).
  String _homeLocation = '/hub';

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    if (shell.currentIndex == 0) _homeLocation = widget.location;
    final section = homeSectionOf(_homeLocation);
    final online = ref.watch(isOnlineProvider);

    // Member types (with administrator-created ones) for labels and pickers across the app.
    ref.watch(memberGroupsProvider);

    final p = context.palette;
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // While typing, the bottom bar and mini player would sit on top of the keyboard — hide both.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    // The Mezmur section has its own 5 tabs; ትምህርት has its own 5 tabs; the hub has no bottom bar.
    final nav = NavLayout(
      section: section,
      branch: shell.currentIndex,
      location: widget.location,
    );
    final onHomePage = !nav.showsBottomBar;
    final mezmur = nav.hasCategories;
    final homeLabel = switch (section) {
      HomeSection.education => l.hubEducation,
      HomeSection.mezmur => l.hubMezmur,
      HomeSection.hub => l.navHome,
    };

    final currentPath = GoRouterState.of(context).uri.path;
    final atHubRoot = shell.currentIndex == 0 && currentPath == '/hub';
    return PopScope(
      canPop: atHubRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final loc = GoRouterState.of(context).uri.path;

        // If the user is on another shell branch, return to Home branch.
        if (shell.currentIndex != 0) {
          shell.goBranch(0);
        } else if (NavLayout.eduTabs.skip(1).contains(loc) ||
            (loc.startsWith('/edu') && loc != '/edu')) {
          // A subpage of Education goes back to Education home first.
          context.go('/edu');
        } else if (loc.startsWith('/home') &&
            loc != '/home') {
          // A subpage of Mezmur goes back to Mezmur home first.
          context.go('/home');
        } else if (loc != '/hub') {
          // If inside a module home, return to the module selector hub.
          context.go('/hub');
        }
      },
      child: Scaffold(
        // Pages inside the shell have their own Scaffold and
        // handle keyboard insets themselves.
        resizeToAvoidBottomInset: false,
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: const AppNavigationDrawer(),

        body: Column(
          children: [
            // Shared application top bar.
            SafeArea(bottom: false, child: AppTopBar(section: section)),

            // Offline status banner.
            if (!online) const OfflineBanner(),

            // Current shell page with inherited module background styling.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ModuleBackgroundWrapper(
                  kind: moduleKindFor(widget.location, section),
                  child: shell,
                ),
              ),
            ),

            // Mini player, hidden while the keyboard is open.
            if (!typing) const MiniPlayer(),
          ],
        ),

        // Module-specific bottom navigation bar:
        // Rendered for Education and Mezmur, but strictly hidden on the global Hub.
        bottomNavigationBar: typing || onHomePage
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: nav.isEducation
                          ? (isDark
                                ? AppColors.eduGold.withValues(alpha: 0.25)
                                : AppColors.eduGold.withValues(alpha: 0.35))
                          : p.border,
                    ),
                  ),
                ),
                child: NavigationBarTheme(
                  data: nav.isEducation
                      ? NavigationBarThemeData(
                          backgroundColor: isDark
                              ? const Color(0xFF241A1C)
                              : AppColors.eduCream,
                          indicatorColor: AppColors.eduGold.withValues(
                            alpha: 0.24,
                          ),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return IconThemeData(
                                color: isDark
                                    ? AppColors.eduGoldLight
                                    : AppColors.eduBurgundy,
                              );
                            }
                            return IconThemeData(
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.eduBurgundy.withValues(
                                      alpha: 0.55,
                                    ),
                            );
                          }),
                          labelTextStyle: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.eduGoldLight
                                    : AppColors.eduBurgundy,
                              );
                            }
                            return TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.eduBurgundy.withValues(
                                      alpha: 0.55,
                                    ),
                            );
                          }),
                        )
                      : Theme.of(context).navigationBarTheme,
                  child: NavigationBar(
                    selectedIndex: nav.selectedIndex,
                    onDestinationSelected: (i) {
                      final b = nav.branchFor(i);
                      if (b == null) {
                        context.go(nav.routeFor(i)!);
                        return;
                      }
                      shell.goBranch(
                        b,
                        initialLocation: b == shell.currentIndex,
                      );
                    },
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    indicatorColor: nav.isEducation
                        ? AppColors.eduGold.withValues(alpha: 0.24)
                        : AppColors.gold.withValues(alpha: 0.22),
                    destinations: nav.isEducation
                        // ትምህርት: Home · Class · My Library · Progress · Settings.
                        ? [
                            NavigationDestination(
                              key: const ValueKey('edu-tab-home'),
                              icon: const Icon(Icons.home_outlined),
                              selectedIcon: const Icon(Icons.home_rounded),
                              label: l.navHome,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-classes'),
                              icon: const Icon(Icons.school_outlined),
                              selectedIcon: const Icon(Icons.school_rounded),
                              label: l.elClass,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-books'),
                              icon: const Icon(Icons.menu_book_outlined),
                              selectedIcon: const Icon(Icons.menu_book_rounded),
                              label: l.navMyLibrary,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-progress'),
                              icon: const Icon(Icons.insights_outlined),
                              selectedIcon: const Icon(Icons.insights_rounded),
                              label: l.elTabProgress,
                            ),
                            NavigationDestination(
                              key: const ValueKey('edu-tab-settings'),
                              icon: const Icon(Icons.settings_outlined),
                              selectedIcon: const Icon(Icons.settings_rounded),
                              label: l.navSettings,
                            ),
                          ]
                        : [
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-home'),
                              icon: HomeTabIcon(section: section),
                              selectedIcon: HomeTabIcon(
                                section: section,
                                selected: true,
                              ),
                              label: homeLabel,
                            ),
                            if (mezmur)
                              NavigationDestination(
                                key: const ValueKey('mezmur-tab-categories'),
                                icon: const Icon(Icons.grid_view_outlined),
                                selectedIcon: const Icon(
                                  Icons.grid_view_rounded,
                                ),
                                label: l.categories,
                              ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-library'),
                              icon: const Icon(Icons.local_library_outlined),
                              selectedIcon: const Icon(
                                Icons.local_library_rounded,
                              ),
                              label: l.navLibrary,
                            ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-programs'),
                              icon: const Icon(Icons.event_note_outlined),
                              selectedIcon: const Icon(
                                Icons.event_note_rounded,
                              ),
                              label: l.navPrograms,
                            ),
                            NavigationDestination(
                              key: const ValueKey('mezmur-tab-settings'),
                              icon: const Icon(Icons.settings_outlined),
                              selectedIcon: const Icon(Icons.settings_rounded),
                              label: l.navSettings,
                            ),
                          ],
                  ),
                ),
              ),
      ),
    );
  }
}

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: p.card,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF650D20),
                border: Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5)),
              ),
              child: Row(
                children: [
                  const AppLogo(size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.appName,
                          style: context.serif(16, color: Colors.white, weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.fullName ?? (l.isEn ? 'Welcome' : 'እንኳን ደህና መጡ'),
                          style: context.sans(12.5, color: AppColors.goldLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined, color: Color(0xFF650D20)),
                    title: Text(l.navHome, style: context.sans(14, weight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/hub');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_outlined, color: Color(0xFF650D20)),
                    title: Text(l.hubEducation, style: context.sans(14, weight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/edu');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_music_outlined, color: Color(0xFF650D20)),
                    title: Text(l.hubMezmur, style: context.sans(14, weight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/home');
                    },
                  ),
                  if (user != null && user.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF650D20)),
                      title: Text(l.adminPanel, style: context.sans(14, weight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/admin');
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFF650D20)),
                    title: Text(l.settings, style: context.sans(14, weight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF650D20)),
                    title: Text(l.aboutApp, style: context.sans(14, weight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings/about');
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      l.isEn ? 'Theme Selection' : 'የገጽታ ምርጫ',
                      style: context.sans(12, color: p.muted, weight: FontWeight.w700),
                    ),
                  ),
                  SwitchListTile(
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.gold),
                    title: Text(isDark ? (l.isEn ? 'Dark Theme' : 'ጨለማ ገጽታ') : (l.isEn ? 'Light Theme' : 'ብርሃን ገጽታ'), style: context.sans(13.5)),
                    value: isDark,
                    onChanged: (_) => ThemeToggleButton.toggle(ref, context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}