import 'package:flutter/material.dart';

/// Colour tokens taken from the imported Claude Design ("Mobile app with church patterns").
/// Maroon + gold on white, with a soft blush and cream for fills.
abstract final class AppColors {
  // Brand
  static const maroon = Color(0xFF650D20);
  static const maroonDark = Color(0xFF57101C);
  static const maroonDeep = Color(0xFF28080E); // hero gradients
  static const gold = Color(0xFFC6A044);
  static const goldDark = Color(0xFFB08A1E);
  static const goldMuted = Color(0xFFB09A4A);
  static const goldLight = Color(0xFFE8C368);

  // Education module tokens (Ethiopian Orthodox visual palette)
  static const eduBurgundy = maroon;
  static const eduBurgundyDark = maroonDark;
  static const eduBurgundyLight = Color(0xFF8C1D30);
  static const eduGold = gold;
  static const eduGoldLight = goldLight;
  static const eduGoldMuted = goldMuted;
  static const eduCream = Color(0xFFFFF8E9);
  static const eduParchment = Color(0xFFFFFFFF);

  // Fills
  static const cream = Color(0xFFF7E9D8); // selected nav pill, chips, track thumbs
  static const blush = Color(0xFFF9F1F2); // search field, pressed rows
  static const blushHover = Color(0xFFF3E3E6);
  static const canvas = Color(0xFFF5F2ED);
  static const surface = Color(0xFFFFFFFF);

  // Lines
  static const border = Color(0xFFEEE0E3);
  static const borderStrong = Color(0xFFE0C9CE);
  static const divider = Color(0xFFF0E4E6);
  static const dividerSoft = Color(0xFFF5EBEE);
  static const switchOff = Color(0xFFE8DDE0);

  // Text
  static const text = Color(0xFF3D2E31);
  static const muted = Color(0xFF8A7A7D);
  static const subtle = Color(0xFF9C8D90);
  static const faint = Color(0xFFB8A8AB);

  // Status
  static const success = Color(0xFF2E7D4F);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFB3261E);

  // Dark theme counterparts (same identity, reversed ground)
  static const darkBg = Color(0xFF1A1113);
  static const darkSurface = Color(0xFF241A1C);
  static const darkSurfaceHigh = Color(0xFF2F2225);
  static const darkBorder = Color(0xFF3F2E32);
  static const darkText = Color(0xFFF2E8E9);
  static const darkMuted = Color(0xFFB9A8AB);
  static const darkAccent = Color(0xFFE7A4B0); // maroon lifted for contrast on dark
  static const darkCream = Color(0xFF3A2A1C);
}

/// Theme-aware palette so widgets never hard-code light-only colours.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentText,
    required this.fill,
    required this.fillStrong,
    required this.pill,
    required this.card,
    required this.border,
    required this.divider,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.faint,
    required this.patternStroke,
    required this.patternDot,
  });

  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentText;
  final Color fill;
  final Color fillStrong;
  final Color pill;
  final Color card;
  final Color border;
  final Color divider;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color faint;
  final Color patternStroke;
  final Color patternDot;

  static const light = Palette(
    primary: AppColors.maroon,
    onPrimary: Colors.white,
    accent: AppColors.gold,
    accentText: AppColors.goldDark,
    fill: AppColors.blush,
    fillStrong: AppColors.blushHover,
    pill: AppColors.cream,
    card: AppColors.surface,
    border: AppColors.border,
    divider: AppColors.dividerSoft,
    text: AppColors.text,
    muted: AppColors.muted,
    subtle: AppColors.subtle,
    faint: AppColors.faint,
    patternStroke: Color(0x14650D20), // burgundy @ 8%
    patternDot: Color(0x38C6A044), // gold @ 22%
  );

  static const dark = Palette(
    primary: AppColors.darkAccent,
    onPrimary: AppColors.darkBg,
    accent: AppColors.gold,
    accentText: AppColors.goldLight,
    fill: AppColors.darkSurfaceHigh,
    fillStrong: Color(0xFF3A2A2E),
    pill: AppColors.darkCream,
    card: AppColors.darkSurface,
    border: AppColors.darkBorder,
    divider: AppColors.darkBorder,
    text: AppColors.darkText,
    muted: AppColors.darkMuted,
    subtle: Color(0xFF9E8D90),
    faint: Color(0xFF7A6A6D),
    patternStroke: Color(0x14E7A4B0),
    patternDot: Color(0x30C6A044),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
}
