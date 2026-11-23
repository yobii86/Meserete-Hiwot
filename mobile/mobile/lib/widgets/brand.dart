import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/user.dart';

/// The design's repeating motif watermark background.
class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.20 : 0.45,
            child: Image.asset(
              'assets/images/general_pattern.png',
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
              filterQuality: FilterQuality.medium,
              scale: 2.2,
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// The modules with dedicated full-bleed atmospheric cover backgrounds.
enum ModuleBackgroundKind { education, mezmur, general }

ModuleBackgroundKind moduleKindOf(String path) {
  if (path.startsWith('/edu')) return ModuleBackgroundKind.education;
  if (path.startsWith('/home') ||
      path.startsWith('/library') ||
      path.startsWith('/player')) {
    return ModuleBackgroundKind.mezmur;
  }
  return ModuleBackgroundKind.general;
}

/// Helper to resolve module kind based on current path and active shell section.
ModuleBackgroundKind moduleKindFor(String path, dynamic section) {
  if (path.startsWith('/edu')) return ModuleBackgroundKind.education;
  if (path.startsWith('/home') ||
      path.startsWith('/library') ||
      path.startsWith('/player')) {
    return ModuleBackgroundKind.mezmur;
  }
  final s = section.toString();
  if (s.contains('education')) return ModuleBackgroundKind.education;
  if (s.contains('mezmur')) return ModuleBackgroundKind.mezmur;
  return ModuleBackgroundKind.general;
}

/// Inherited scope so nested screens inside an Education or Mezmur wrapper automatically know they sit
/// over a module background image.
class ModuleBackgroundScope extends InheritedWidget {
  const ModuleBackgroundScope({
    super.key,
    required this.kind,
    required super.child,
  });

  final ModuleBackgroundKind kind;

  static ModuleBackgroundKind? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ModuleBackgroundScope>()
        ?.kind;
  }

  @override
  bool updateShouldNotify(ModuleBackgroundScope oldWidget) =>
      kind != oldWidget.kind;
}

/// Full-bleed atmospheric pattern tile background wrapper for Education and Mezmur modules.
class ModuleBackgroundWrapper extends StatelessWidget {
  const ModuleBackgroundWrapper({
    super.key,
    required this.kind,
    required this.child,
  });

  final ModuleBackgroundKind? kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kind == null) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdu = kind == ModuleBackgroundKind.education;
    final String asset = switch (kind!) {
      ModuleBackgroundKind.education => 'assets/images/education_pattern.png',
      ModuleBackgroundKind.mezmur => 'assets/images/mezmur_pattern.png',
      ModuleBackgroundKind.general => 'assets/images/general_pattern.png',
    };
    final bgColor = isEdu
        ? (isDark ? const Color(0xFF1A1113) : const Color(0xFFFFFFFF))
        : (isDark ? const Color(0xFF1A1113) : const Color(0xFFFBF9F5));
    final patternOpacity = isEdu
        ? (isDark ? 0.08 : 0.04)
        : (isDark ? 0.20 : 0.45);

    return ModuleBackgroundScope(
      kind: kind!,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bgColor),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: patternOpacity,
                child: Image.asset(
                  asset,
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment.topLeft,
                  filterQuality: FilterQuality.medium,
                  scale: 2.2,
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// Scaffold body with the pattern behind scrolling content (as in every design screen).
/// When wrapped in a [ModuleBackgroundWrapper], the scaffold background is made transparent
/// so child routes inherit the full-bleed atmospheric cover background automatically.
class PatternScaffold extends StatelessWidget {
  const PatternScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final module = ModuleBackgroundScope.of(context);
    final effectiveKind = module ?? ModuleBackgroundKind.general;
    final scaffold = Scaffold(
      backgroundColor:
          backgroundColor ?? (module != null ? Colors.transparent : null),
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          if (module == null)
            const Positioned.fill(
              child: IgnorePointer(child: PatternBackground()),
            ),
          Positioned.fill(child: body),
        ],
      ),
    );

    if (module == null) {
      return ModuleBackgroundWrapper(kind: effectiveKind, child: scaffold);
    }
    return scaffold;
  }
}

/// Circular church seal with the design's 2px gold ring.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 46, this.ring = true});
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: ring
            ? const [BoxShadow(color: AppColors.gold, spreadRadius: 2)]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpg',
          fit: BoxFit.cover,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

/// 44px round action (search, back) — blush fill with a hairline border.
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.onImage = false,
    this.badge,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool onImage;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final btn = Material(
      color: onImage ? Colors.white.withValues(alpha: 0.92) : p.fill,
      shape: CircleBorder(
        side: onImage ? BorderSide.none : BorderSide(color: p.border),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 20,
            color: onImage ? AppColors.maroon : p.primary,
          ),
        ),
      ),
    );
    final withBadge = (badge ?? 0) > 0
        ? Badge(
            label: Text(badge! > 99 ? '99+' : '$badge'),
            backgroundColor: AppColors.gold,
            child: btn,
          )
        : btn;
    return tooltip == null
        ? withBadge
        : Tooltip(message: tooltip!, child: withBadge);
  }
}

/// "ምድቦች ......... ፯ ምድቦች" section header from the home design.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.trailingWidget,
    this.padding = const EdgeInsets.fromLTRB(2, 22, 2, 12),
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final Widget? trailingWidget;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: context
                  .serif(15, weight: FontWeight.w600, color: p.text)
                  .copyWith(letterSpacing: 0.3),
            ),
          ),
          if (trailingWidget != null)
            trailingWidget!
          else if (trailing != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  trailing!,
                  style: context.sans(12, color: AppColors.goldMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Network (or local file) image with the brand placeholder: a maroon gradient with the seal.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.url,
    this.localPath,
    this.radius = 0,
    this.placeholderIcon,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final String? localPath;
  final double radius;
  final IconData? placeholderIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (localPath != null && File(localPath!).existsSync()) {
      child = Image.file(
        File(localPath!),
        fit: fit,
        errorBuilder: (_, _, _) => const _Placeholder(),
      );
    } else if (url != null && url!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => _Placeholder(icon: placeholderIcon),
        errorWidget: (_, _, _) => _Placeholder(icon: placeholderIcon),
      );
    } else {
      child = _Placeholder(icon: placeholderIcon);
    }
    return radius > 0
        ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child)
        : child;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon});
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.maroon, AppColors.maroonDark],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Opacity(opacity: 0.5, child: PatternBackground()),
          Center(
            child: icon != null
                ? Icon(icon, color: AppColors.goldLight, size: 30)
                : LayoutBuilder(
                    builder: (_, c) => Opacity(
                      opacity: 0.85,
                      child: AppLogo(
                        size: (c.biggest.shortestSide * 0.42)
                            .clamp(20, 90)
                            .toDouble(),
                        ring: false,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The maroon identity card from the settings screen.
class MaroonCard extends StatelessWidget {
  const MaroonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.maroon,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: AppColors.maroon.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.maroon.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// White rounded card with the design's hairline border and soft maroon shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isEdu =
        ModuleBackgroundScope.of(context) == ModuleBackgroundKind.education;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isEdu
        ? (isDark ? const Color(0xFF241A1C) : Colors.white)
        : p.card;
    final borderColor = isEdu
        ? (isDark
              ? AppColors.eduGold.withValues(alpha: 0.3)
              : AppColors.eduGold.withValues(alpha: 0.45))
        : p.border;
    final shadowColor = isEdu
        ? AppColors.eduBurgundy.withValues(alpha: 0.05)
        : AppColors.maroon.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Rounded label pill ("የቅድስት ሥላሴ" chip on the player, status chips).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.background, this.icon});
  final String text;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? p.pill,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color ?? p.accentText),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.sans(
                11,
                weight: FontWeight.w600,
                color: color ?? p.accentText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member ID ("መ/ሕ/ወ/17") as a small badge under a name.
class MemberIdBadge extends StatelessWidget {
  const MemberIdBadge(this.memberId, {super.key});
  final String memberId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pill(memberId, icon: Icons.badge_outlined),
    ),
  );
}

/// Track row from the category/search designs: square thumb, serif title, subtitle, trailing.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.active = false,
    this.selected = false,
    this.elevated = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool selected;

  /// A card with a soft shadow (Mezmur rows) instead of a flat row.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tile = Material(
      color: active || selected
          ? p.fill
          : (elevated ? p.card : Colors.transparent),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.serif(
                        15,
                        weight: FontWeight.w600,
                        color: active ? p.primary : p.text,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(12, color: p.muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
    if (!elevated) return tile;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.35
                  : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: tile,
    );
  }
}

/// Square thumb used in lists: cream with a gold icon, or maroon when active.
class ListThumb extends StatelessWidget {
  const ListThumb({
    super.key,
    required this.icon,
    this.active = false,
    this.size = 44,
    this.imageUrl,
  });
  final IconData icon;
  final bool active;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (imageUrl != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CoverImage(url: imageUrl, radius: 12, placeholderIcon: icon),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? AppColors.maroon : p.pill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 19,
        color: active ? AppColors.goldLight : AppColors.goldDark,
      ),
    );
  }
}

/// Grouped settings list ("መተግበሪያ", "ውርዶች", "ስለ" in the design).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
            child: Text(
              title!,
              style: context
                  .sans(12, weight: FontWeight.w600, color: p.accentText)
                  .copyWith(letterSpacing: 0.4),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          // Its own (transparent) surface: list rows draw their tap ripples here, not on the page
          // under the card colour, where they were invisible.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: 1, color: p.divider),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    this.switchValue,
    this.onSwitch,
    this.danger = false,
  });
  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: switchValue != null ? () => onSwitch?.call(!switchValue!) : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: danger ? AppColors.danger : p.primary,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.sans(
                    14,
                    color: danger ? AppColors.danger : p.text,
                  ),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.sans(13, color: p.muted),
                    ),
                  ),
                ),
              if (switchValue != null)
                Switch(value: switchValue!, onChanged: onSwitch)
              else if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: p.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Serif page title used at the top of tab screens ("ፈልግ", "ማስተካከያ").
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.trailing, this.leading});
  final String text;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(child: Text(text, style: context.serif(22))),
        ?trailing,
      ],
    );
  }
}

/// A member's photo (or their initial), used wherever a person is shown.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 22});
  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: p.pill,
      foregroundImage: url != null ? CachedNetworkImageProvider(url) : null,
      child: Text(
        user.fullName.isEmpty ? '?' : user.fullName.characters.first,
        style: context.serif(radius * 0.75),
      ),
    );
  }
}
