import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/preferences_service.dart';
import '../services/unread_service.dart';
import '../widgets/brand.dart';
import '../widgets/sync_indicator.dart';
import '../features/guidance/tour_engine.dart';

/// Which part of the Home tab the user is in: the hub (two cards), ትምህርት or መዝሙር.
enum HomeSection { hub, education, mezmur }

HomeSection homeSectionOf(String path) {
  if (path.startsWith('/edu')) return HomeSection.education;
  if (path.startsWith('/home')) return HomeSection.mezmur;
  return HomeSection.hub;
}

/// Icon of the Home tab: a house on the hub, a school cap in ትምህርት, the EOTC kebero in መዝሙር.
class HomeTabIcon extends StatelessWidget {
  const HomeTabIcon({super.key, required this.section, this.selected = false});
  final HomeSection section;
  final bool selected;

  @override
  Widget build(BuildContext context) => switch (section) {
    HomeSection.education => EduIcon(
      size: IconTheme.of(context).size ?? 24,
      dimmed: !selected,
    ),
    HomeSection.mezmur => KeberoIcon(filled: selected),
    HomeSection.hub => Icon(
      selected ? Icons.home_rounded : Icons.home_outlined,
    ),
  };
}

/// The ትምህርት icon: the lectern with the Ge'ez letters (assets/images/edu_icon*.png).
class EduIcon extends StatelessWidget {
  const EduIcon({super.key, this.size = 24, this.dimmed = false});
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dimmed ? 0.7 : 1,
    child: Image.asset(
      size > 64
          ? 'assets/images/edu_icon.png'
          : 'assets/images/edu_icon_small.png',
      width: size + 4,
      height: size + 4,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// The ከበሮ (EOTC church drum): a long barrel, wide head on the left and a smaller head on the
/// right, laced with leather thongs. Drawn so it can sit anywhere an [Icon] does.
class KeberoIcon extends StatelessWidget {
  const KeberoIcon({super.key, this.size, this.color, this.filled = false});
  final double? size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _KeberoPainter(color: c, filled: filled),
      ),
    );
  }
}

class _KeberoPainter extends CustomPainter {
  _KeberoPainter({required this.color, required this.filled});
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    // The kebero lies on its side: a long barrel, big head on the left, smaller head on the right,
    // a shoulder strap above, and leather lacing along the body.
    final bigH = h * 0.62;
    final smallH = h * 0.40;
    final cy = h * 0.58;
    final leftX = w * 0.14;
    final rightX = w * 0.88;
    final bigHead = Rect.fromCenter(
      center: Offset(leftX, cy),
      width: w * 0.16,
      height: bigH,
    );
    final smallHead = Rect.fromCenter(
      center: Offset(rightX, cy),
      width: w * 0.11,
      height: smallH,
    );

    final body = Path()
      ..moveTo(leftX, cy - bigH / 2)
      ..cubicTo(
        w * 0.40,
        cy - bigH / 2 - h * 0.06,
        w * 0.66,
        cy - smallH / 2 - h * 0.06,
        rightX,
        cy - smallH / 2,
      )
      ..lineTo(rightX, cy + smallH / 2)
      ..cubicTo(
        w * 0.66,
        cy + smallH / 2 + h * 0.06,
        w * 0.40,
        cy + bigH / 2 + h * 0.06,
        leftX,
        cy + bigH / 2,
      )
      ..close();

    final stroke = math.max(1.3, w * 0.065);
    final solid = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Lines that are cut out of the solid glyph (filled) or drawn (outline).
    final detail = filled
        ? (Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.045)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round)
        : (Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, w * 0.045)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);

    // Shoulder strap.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, cy - bigH / 2 + h * 0.02)
        ..quadraticBezierTo(
          w * 0.52,
          -h * 0.02,
          w * 0.80,
          cy - smallH / 2 + h * 0.01,
        ),
      line,
    );

    if (filled) {
      canvas.drawPath(body, solid);
      canvas.drawOval(bigHead, solid);
      canvas.drawOval(smallHead, solid);
    } else {
      canvas.drawPath(body, line);
    }

    // Lacing: V-shaped thongs between the two rims.
    final lace = Path();
    final n = w < 32 ? 3 : 5;
    for (var i = 0; i < n; i++) {
      final t0 = 0.24 + 0.56 * i / n;
      final t1 = 0.24 + 0.56 * (i + 0.5) / n;
      final t2 = 0.24 + 0.56 * (i + 1) / n;
      double halfAt(double x) {
        final t = ((x / w) - 0.14) / 0.74;
        return (bigH / 2) * (1 - t) +
            (smallH / 2) * t +
            h * 0.03 * math.sin(t * math.pi);
      }

      final x0 = w * t0, x1 = w * t1, x2 = w * t2;
      lace
        ..moveTo(x0, cy - halfAt(x0) + stroke * 1.2)
        ..lineTo(x1, cy + halfAt(x1) - stroke * 1.2)
        ..lineTo(x2, cy - halfAt(x2) + stroke * 1.2);
    }
    canvas.drawPath(lace, detail);

    // Heads: rims cut into the solid glyph, or drawn as rings.
    canvas.drawOval(bigHead.deflate(stroke * 0.9), detail);
    canvas.drawOval(smallHead.deflate(stroke * 0.8), detail);
    if (!filled) {
      canvas.drawOval(bigHead, line);
      canvas.drawOval(smallHead, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeberoPainter old) =>
      old.color != color || old.filled != filled;
}

/// Switch between light and dark theme (saved on the device and in the account preferences).
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.compact = false});
  final bool compact;

  static Future<void> toggle(WidgetRef ref, BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    await ref.read(appSettingsProvider.notifier).setDark(!dark);
    try {
      await ref
          .read(preferencesProvider.notifier)
          .update((x) => x.copyWith(theme: dark ? 'light' : 'dark'));
    } catch (_) {
      // Offline: the device setting already changed; the account follows on the next save.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;
    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => RotationTransition(
        turns: Tween(begin: 0.75, end: 1.0).animate(a),
        child: FadeTransition(opacity: a, child: c),
      ),
      child: Icon(
        dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        key: ValueKey(dark),
        color: dark ? AppColors.goldLight : null,
      ),
    );
    if (compact) {
      return IconButton(
        tooltip: l.themeToggle,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
        onPressed: () => toggle(ref, context),
        icon: icon,
      );
    }
    return CircleAction(
      icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      tooltip: l.themeToggle,
      onTap: () => toggle(ref, context),
    );
  }
}

/// The top bar shared by every tab: logo · (title) · search · notifications · theme (· settings).
/// Search follows the section: ትምህርት searches lessons and subjects, elsewhere Mezmurs. In ትምህርት
/// (whose bottom bar has no Settings tab) the Settings button is always shown, as on the hub.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key, this.section = HomeSection.hub});
  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final unread = ref.watch(unreadCountProvider);
    final inModule = section != HomeSection.hub;
    final isEdu = section == HomeSection.education;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moduleName = isEdu ? l.hubEducation : l.hubMezmur;
    final moduleColor = isEdu ? AppColors.eduBurgundy : AppColors.maroon;

    final topBarBg = isEdu
        ? (isDark ? const Color(0xFF241A1C) : Colors.white)
        : p.card;
    final topBarBorder = isEdu
        ? Border(
            bottom: BorderSide(
              color: isDark
                  ? AppColors.eduGold.withValues(alpha: 0.25)
                  : AppColors.eduGold.withValues(alpha: 0.35),
            ),
          )
        : Border(bottom: BorderSide(color: p.border));

    return Material(
      color: topBarBg,
      elevation: 0,
      child: Container(
        height: 54,
        decoration: BoxDecoration(border: topBarBorder),
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        child: Row(
          children: [
            // Logo & module return button
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.go('/hub'),
                child: Row(
                  children: [
                    const AppLogo(size: 36),
                    const SizedBox(width: 8),
                    if (inModule) ...[
                      Container(
                        key: const ValueKey('edu-back-button'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isEdu
                              ? (isDark
                                    ? AppColors.eduBurgundy.withValues(
                                        alpha: 0.35,
                                      )
                                    : AppColors.eduCream)
                              : moduleColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: isEdu
                              ? Border.all(
                                  color: AppColors.eduGold.withValues(
                                    alpha: 0.45,
                                  ),
                                  width: 1.0,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 12,
                              color: isEdu && isDark
                                  ? AppColors.goldLight
                                  : moduleColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              moduleName,
                              style: context.sans(
                                11,
                                weight: FontWeight.w700,
                                color: isEdu && isDark
                                    ? AppColors.goldLight
                                    : moduleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        l.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.serif(15, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SyncStatusIndicator(),
            if (section == HomeSection.education)
              IconButton(
                key: const ValueKey('edu-search'),
                tooltip: l.search,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.search_rounded, size: 20),
                onPressed: () => context.push('/edu/search'),
              )
            else
              IconButton(
                key: TourKeys.mezmurSearchBar,
                tooltip: l.search,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.search_rounded, size: 20),
                onPressed: () => context.push('/home/search'),
              ),
            IconButton(
              tooltip: l.navNotifications,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: AppColors.gold,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_none_rounded, size: 20),
              ),
            ),
            IconButton(
              key: const ValueKey('global-hamburger-menu'),
              tooltip: l.isEn ? 'Menu' : 'ምናሌ',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              icon: const Icon(Icons.menu_rounded, size: 24),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-bar layout. In the Mezmur section a "Categories" button sits after Home (index 1); the
/// hub keeps the four tabs. ትምህርት has its own four: Learn · Books · Progress · Settings —
/// Maps between bar indexes and shell branches.
class NavLayout {
  const NavLayout({
    required this.section,
    required this.branch,
    required this.location,
  });
  final HomeSection section;
  final int branch; // current shell branch (0 = Home)
  final String location;

  static const eduClasses = '/edu/classes';
  static const eduLibrary = '/edu/library';
  static const eduTabs = [
    '/edu',
    '/edu/classes',
    '/edu/library',
    '/edu/progress',
    '/settings?from=edu',
  ];

  bool get hasCategories => section == HomeSection.mezmur;
  bool get isEducation => section == HomeSection.education;
  bool get onCategories =>
      hasCategories && branch == 0 && location.startsWith('/home/categories');

  /// The ትምህርት tab a page belongs to (0: Learn, 1: Classes, 2: Books, 3: Progress, 4: Settings).
  int get eduIndex {
    if (branch == 3 || location.startsWith('/settings')) return 4;
    bool any(List<String> prefixes) => prefixes.any(location.startsWith);
    if (any(const ['/edu/progress', '/edu/quiz/', '/edu/attempt/'])) return 3;
    if (any(const ['/edu/library', '/edu/borrowings', '/library/books'])) {
      return 2;
    }
    if (any(const ['/edu/classes', '/edu/class/', '/edu/course/', '/edu/learn/lesson/'])) {
      return 1;
    }
    return 0;
  }

  int get selectedIndex {
    if (isEducation) return eduIndex;
    return onCategories
        ? 1
        : (hasCategories && branch > 0 ? branch + 1 : branch);
  }

  /// The hub (home page) has no bottom bar — its cards link to every section; the Mezmur and
  /// Education sections keep their respective bars.
  bool get showsBottomBar =>
      section != HomeSection.hub && !(branch == 0 && location == '/hub');

  /// Shell branch for a bar index (null = a page inside the Home branch: see [routeFor]).
  int? branchFor(int index) {
    if (isEducation) return null;
    if (!hasCategories) return index;
    if (index == 1) return null;
    return index == 0 ? 0 : index - 1;
  }

  /// The Home-branch page a bar index opens when [branchFor] is null.
  String? routeFor(int index) {
    if (branchFor(index) != null) return null;
    if (isEducation) return eduTabs[index.clamp(0, eduTabs.length - 1)];
    return '/home/categories';
  }
}
