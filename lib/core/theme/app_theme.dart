import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_presets.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light([AppThemePreset preset = AppPresets.yinghua]) {
    final p = AppPalette.lightFor(preset);
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: p.brand,
      onPrimary: Colors.white,
      primaryContainer: p.brandSoft,
      onPrimaryContainer: p.brandPressed,
      secondary: p.gold,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFF3E1),
      onSecondaryContainer: const Color(0xFF7A4A00),
      error: const Color(0xFFD13B3B),
      onError: Colors.white,
      surface: p.bg,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surface,
      onSurfaceVariant: p.textSecondary,
      outline: const Color(0xFFE3E3E8),
      outlineVariant: const Color(0x14000000),
    );
    return _base(scheme, p);
  }

  static ThemeData dark([AppThemePreset preset = AppPresets.yinghua]) {
    final p = AppPalette.darkFor(preset);
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p.brand,
      onPrimary: const Color(0xFF141414),
      primaryContainer: p.brandSoftDark,
      onPrimaryContainer: const Color(0xFFFFD9D9),
      secondary: p.gold,
      onSecondary: const Color(0xFF2A1B00),
      secondaryContainer: const Color(0xFF3B2A12),
      onSecondaryContainer: const Color(0xFFFFDDA8),
      error: const Color(0xFFFF7B7B),
      onError: const Color(0xFF2A0606),
      surface: p.bg,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surface,
      onSurfaceVariant: p.textSecondary,
      outline: const Color(0xFF3A3A42),
      outlineVariant: const Color(0x14FFFFFF),
    );
    return _base(scheme, p);
  }

  static ThemeData _base(ColorScheme scheme, AppPalette p) {
    final isDark = p.isDark;
    final textTheme = TextTheme(
      displaySmall: AppText.display,
      headlineSmall: AppText.h1,
      headlineMedium: AppText.h2,
      titleLarge: AppText.title,
      titleMedium: AppText.titleSm,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.bodySm,
      labelMedium: AppText.caption,
      labelSmall: AppText.overline,
    ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[AppPaletteTheme(p)],
      fontFamilyFallback: const [
        'PingFang SC',
        'Noto Sans CJK SC',
        'Source Han Sans SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.title.copyWith(color: p.textPrimary),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        labelStyle: AppText.titleSm,
        unselectedLabelStyle: AppText.titleSm,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.brand, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 2),
        ),
        overlayColor: WidgetStatePropertyAll(p.brand.withValues(alpha: 0.06)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg,
        modalBackgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppText.h2.copyWith(color: p.textPrimary),
        contentTextStyle: AppText.body.copyWith(color: p.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF2C2C33)
            : const Color(0xFF232327),
        contentTextStyle: AppText.bodySm.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2.5,
        activeTrackColor: p.brand,
        inactiveTrackColor: p.textPrimary.withValues(alpha: 0.12),
        secondaryActiveTrackColor: p.brand.withValues(alpha: 0.28),
        thumbColor: p.brand,
        overlayColor: p.brand.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackShape: const RoundedRectSliderTrackShape(),
        padding: EdgeInsets.zero,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? const Color(0xFF7A7A84) : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.brand
              : (isDark ? const Color(0xFF3A3A42) : const Color(0xFFDDDDE3)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearMinHeight: 2,
      ),
      iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: AppText.body.copyWith(color: p.textTertiary),
        labelStyle: AppText.bodySm.copyWith(color: p.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFD13B3B), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFD13B3B), width: 1.6),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
