import 'package:flutter/material.dart';

/// 一套主题皮肤。
///
/// 每套皮肤只定义「品牌色 / 按下态 / 品牌浅底」，其余色板由 [AppPalette]
/// 按亮暗模式派生，避免出现 6 套完全独立的调色板而失控。
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.brand,
    required this.brandPressed,
    required this.brandSoft,
    required this.brandSoftDark,
    this.tint = 0.045,
  });

  final String id;
  final String name;
  final String description;
  final Color brand;
  final Color brandPressed;
  final Color brandSoft;
  final Color brandSoftDark;

  /// 界面底色的品牌色混合比例，越大越有该 App 的味道。
  final double tint;

  bool get isDefault => id == AppPresets.yinghua.id;
}

/// 内置主题皮肤，参考主流音乐 App 的主色与气质。
class AppPresets {
  AppPresets._();

  static const yinghua = AppThemePreset(
    id: 'yinghua',
    name: '莺花',
    description: '品牌红 · 白底黑字',
    brand: Color(0xFFE23B3B),
    brandPressed: Color(0xFFC42B2B),
    brandSoft: Color(0xFFFDECEC),
    brandSoftDark: Color(0xFF3A1D1F),
    tint: 0.03,
  );

  static const netease = AppThemePreset(
    id: 'netease',
    name: '网易云音乐',
    description: '云村红 · 黑胶与乐评',
    brand: Color(0xFFEC4141),
    brandPressed: Color(0xFFD63030),
    brandSoft: Color(0xFFFDEBEB),
    brandSoftDark: Color(0xFF3B1B1B),
    tint: 0.04,
  );

  static const qqmusic = AppThemePreset(
    id: 'qqmusic',
    name: 'QQ 音乐',
    description: '清新绿 · 歌单与推荐',
    brand: Color(0xFF31C27C),
    brandPressed: Color(0xFF22A968),
    brandSoft: Color(0xFFE8F8F0),
    brandSoftDark: Color(0xFF14301F),
    tint: 0.05,
  );

  static const kuwo = AppThemePreset(
    id: 'kuwo',
    name: '酷我音乐',
    description: '活力蓝 · 电台与榜单',
    brand: Color(0xFF0F88FF),
    brandPressed: Color(0xFF0B6FD1),
    brandSoft: Color(0xFFE9F3FF),
    brandSoftDark: Color(0xFF12263A),
    tint: 0.05,
  );

  static const kugou = AppThemePreset(
    id: 'kugou',
    name: '酷狗音乐',
    description: '青蓝 · 蝰蛇音效',
    brand: Color(0xFF00BBD3),
    brandPressed: Color(0xFF0097AA),
    brandSoft: Color(0xFFE4F8FB),
    brandSoftDark: Color(0xFF10292E),
    tint: 0.05,
  );

  static const qianqian = AppThemePreset(
    id: 'qianqian',
    name: '千千静听',
    description: '经典蓝 · 极简歌词',
    brand: Color(0xFF4E7FE8),
    brandPressed: Color(0xFF3A66C7),
    brandSoft: Color(0xFFEBF1FF),
    brandSoftDark: Color(0xFF172238),
    tint: 0.045,
  );

  static const all = <AppThemePreset>[
    yinghua,
    netease,
    qqmusic,
    kuwo,
    kugou,
    qianqian,
  ];

  static AppThemePreset byId(String? id) {
    if (id == null || id.isEmpty) return yinghua;
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return yinghua;
  }
}
