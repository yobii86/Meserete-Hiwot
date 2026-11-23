import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography follows the design: Noto Serif Ethiopic for headings/titles,
/// Noto Sans Ethiopic for body text. Line heights are generous for Ge'ez script.
abstract final class AppFonts {
  static const sans = 'NotoSansEthiopic';
  static const serif = 'NotoSerifEthiopic';
}

extension AppTextX on BuildContext {
  /// Serif display/title style (headings, card titles, song titles).
  TextStyle serif(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1.3}) => TextStyle(
        fontFamily: AppFonts.serif,
        fontSize: size,
        fontWeight: weight,
        color: color ?? palette.primary,
        height: height,
      );

  /// Sans body style.
  TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color, double height = 1.45}) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? palette.text,
        height: height,
      );

  /// Monospace style for IDs, diagnostics, tokens, and technical references.
  TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color? color, double height = 1.3}) => TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        fontWeight: weight,
        color: color ?? palette.text,
        height: height,
      );
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, Palette.light);
  static ThemeData dark() => _build(Brightness.dark, Palette.dark);

  static ThemeData _build(Brightness brightness, Palette p) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: AppColors.gold,
      onSecondary: Colors.white,
      tertiary: AppColors.goldLight,
      onTertiary: AppColors.maroonDeep,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.darkBg : AppColors.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.fill,
      surfaceContainerHigh: p.fill,
      surfaceContainer: p.card,
      surfaceContainerLow: p.card,
      surfaceContainerLowest: p.card,
      outline: p.border,
      outlineVariant: p.divider,
      primaryContainer: p.pill,
      onPrimaryContainer: p.primary,
      secondaryContainer: p.pill,
      onSecondaryContainer: p.primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(bodyColor: p.text, displayColor: p.primary, fontFamily: AppFonts.sans);

    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: TextStyle(fontFamily: AppFonts.serif, fontSize: 22, fontWeight: FontWeight.w700, color: p.primary, height: 1.3),
        titleLarge: TextStyle(fontFamily: AppFonts.serif, fontSize: 19, fontWeight: FontWeight.w700, color: p.primary, height: 1.3),
        titleMedium: TextStyle(fontFamily: AppFonts.serif, fontSize: 15, fontWeight: FontWeight.w600, color: p.text, height: 1.35),
        bodyLarge: TextStyle(fontFamily: AppFonts.sans, fontSize: 15, color: p.text, height: 1.5),
        bodyMedium: TextStyle(fontFamily: AppFonts.sans, fontSize: 14, color: p.text, height: 1.5),
        bodySmall: TextStyle(fontFamily: AppFonts.sans, fontSize: 12, color: p.muted, height: 1.45),
        labelLarge: const TextStyle(fontFamily: AppFonts.sans, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.primary,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: AppFonts.serif, fontSize: 20, fontWeight: FontWeight.w700, color: p.primary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.pill,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? p.primary : p.subtle,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? p.primary : p.subtle),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: p.border, width: 1.5),
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: TextStyle(color: p.muted, fontSize: 14),
        floatingLabelStyle: TextStyle(color: p.accentText, fontSize: 14),
        hintStyle: TextStyle(color: p.subtle, fontSize: 14),
        helperMaxLines: 2,
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : (isDark ? AppColors.darkBorder : AppColors.switchOff),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent),
        side: BorderSide(color: p.faint, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.pill,
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: AppFonts.sans, fontSize: 13, color: p.primary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.pill : p.card),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.muted),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: AppFonts.sans, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        titleTextStyle: TextStyle(fontFamily: AppFonts.sans, fontSize: 14, color: p.text),
        subtitleTextStyle: TextStyle(fontFamily: AppFonts.sans, fontSize: 12, color: p.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.maroon,
        contentTextStyle: const TextStyle(fontFamily: AppFonts.sans, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(fontFamily: AppFonts.serif, fontSize: 18, fontWeight: FontWeight.w700, color: p.primary),
        contentTextStyle: TextStyle(fontFamily: AppFonts.sans, fontSize: 14, color: p.text, height: 1.55),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: p.divider),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.divider,
        thumbColor: AppColors.gold,
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.subtle,
        indicatorColor: AppColors.gold,
        labelStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14),
        dividerColor: p.divider,
      ),
    );
  }
}
