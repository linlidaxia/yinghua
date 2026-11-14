import 'package:flutter/material.dart';

import 'app_presets.dart';

/// 莺花设计规范 · 色彩
///
/// 品牌色不再写死，而由当前主题皮肤（[AppThemePreset]）决定；
/// 品牌色只承担「行动 / 正在播放 / 强调」三类语义，
/// 大面积背景保持白或近黑，避免红色（或绿色、蓝色）泛滥。
class AppColors {
  AppColors._();

  // ---------- 默认品牌（莺花皮肤，供常量场景兜底） ----------
  static const brand = Color(0xFFE23B3B); // 主色 · 莺红
  static const brandPressed = Color(0xFFC42B2B); // 按下态
  static const brandSoft = Color(0xFFFDECEC); // 浅色底
  static const brandSoftDark = Color(0xFF3A1D1F); // 深色底

  // ---------- 辅助 ----------
  static const gold = Color(0xFFF0A93B); // 音质 / Hi-Res 标记
  static const mint = Color(0xFF3AAE8C); // 在线状态

  // ---------- 浅色 ----------
  static const lightBg = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF6F6F8);
  static const lightSurfaceHigh = Color(0xFFEFEFF2);
  static const textPrimary = Color(0xFF16161A);
  static const textSecondary = Color(0xFF6E6E78);
  static const textTertiary = Color(0xFFA4A4AE);
  static const divider = Color(0x0F000000);

  // ---------- 深色 ----------
  static const darkBg = Color(0xFF101013);
  static const darkSurface = Color(0xFF1A1A1F);
  static const darkSurfaceHigh = Color(0xFF26262C);
  static const darkTextPrimary = Color(0xFFF4F4F7);
  static const darkTextSecondary = Color(0xFFA0A0AA);
  static const darkTextTertiary = Color(0xFF6C6C76);
  static const darkDivider = Color(0x14FFFFFF);

  // ---------- 播放页 ----------
  static const playerScrimTop = Color(0x4D000000);
  static const playerScrimBottom = Color(0xB3000000);
  static const vinylBlack = Color(0xFF0C0C0E);
  static const vinylEdge = Color(0xFF1E1E23);
}

/// 随亮暗模式 + 主题皮肤切换的语义色板。
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.brand,
    required this.brandPressed,
    required this.brandSoft,
    required this.brandSoftDark,
    required this.gold,
    required this.mint,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  final Color brand;
  final Color brandPressed;
  final Color brandSoft;
  final Color brandSoftDark;
  final Color gold;
  final Color mint;

  final bool isDark;

  /// 浅色色板：底色带一点品牌色，切换皮肤后整屏气质随之改变。
  static AppPalette lightFor(AppThemePreset preset) {
    final tint = preset.tint;
    return AppPalette(
      bg: const Color(0xFFFFFFFF),
      surface: Color.alphaBlend(
        preset.brand.withValues(alpha: tint),
        const Color(0xFFFFFFFF),
      ),
      surfaceHigh: Color.alphaBlend(
        preset.brand.withValues(alpha: tint * 1.7),
        const Color(0xFFFFFFFF),
      ),
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textTertiary: AppColors.textTertiary,
      divider: AppColors.divider,
      brand: preset.brand,
      brandPressed: preset.brandPressed,
      brandSoft: preset.brandSoft,
      brandSoftDark: preset.brandSoftDark,
      gold: AppColors.gold,
      mint: AppColors.mint,
      isDark: false,
    );
  }

  /// 深色色板：在近黑底上混入品牌色，避免纯黑死板。
  static AppPalette darkFor(AppThemePreset preset) {
    final tint = preset.tint;
    final brand = Color.lerp(preset.brand, Colors.white, 0.18)!;
    return AppPalette(
      bg: Color.alphaBlend(
        preset.brand.withValues(alpha: tint * 0.6),
        AppColors.darkBg,
      ),
      surface: Color.alphaBlend(
        preset.brand.withValues(alpha: tint),
        AppColors.darkSurface,
      ),
      surfaceHigh: Color.alphaBlend(
        preset.brand.withValues(alpha: tint * 1.8),
        AppColors.darkSurfaceHigh,
      ),
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textTertiary: AppColors.darkTextTertiary,
      divider: AppColors.darkDivider,
      brand: brand,
      brandPressed: Color.lerp(preset.brandPressed, Colors.white, 0.10)!,
      brandSoft: preset.brandSoftDark,
      brandSoftDark: preset.brandSoftDark,
      gold: AppColors.gold,
      mint: AppColors.mint,
      isDark: true,
    );
  }

  static AppPalette get light => lightFor(AppPresets.yinghua);
  static AppPalette get dark => darkFor(AppPresets.yinghua);

  /// 从当前 [ThemeData] 读取色板；没有注册扩展时按亮度回退默认皮肤。
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppPaletteTheme>();
    if (extension != null) return extension.palette;
    return theme.brightness == Brightness.dark ? dark : light;
  }
}

/// 把当前皮肤色板挂到 ThemeData 上，供 [AppPalette.of] 读取。
@immutable
class AppPaletteTheme extends ThemeExtension<AppPaletteTheme> {
  const AppPaletteTheme(this.palette);

  final AppPalette palette;

  @override
  AppPaletteTheme copyWith({AppPalette? palette}) =>
      AppPaletteTheme(palette ?? this.palette);

  @override
  AppPaletteTheme lerp(ThemeExtension<AppPaletteTheme>? other, double t) {
    if (other is! AppPaletteTheme) return this;
    return AppPaletteTheme(other.palette);
  }
}
