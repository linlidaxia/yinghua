import 'package:flutter/material.dart';

/// 莺花设计规范 · 字阶
///
/// 中文正文 15sp / 行高 1.45，标题使用 600–700 字重，
/// 数字与英文跟随系统无衬线字体，字距略收紧以提升精致感。
class AppText {
  AppText._();

  static const display = TextStyle(
    fontSize: 26,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const h1 = TextStyle(
    fontSize: 22,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const h2 = TextStyle(
    fontSize: 18,
    height: 1.32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const title = TextStyle(
    fontSize: 16,
    height: 1.36,
    fontWeight: FontWeight.w600,
  );

  static const titleSm = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const bodySm = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const overline = TextStyle(
    fontSize: 10,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static const button = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const lyric = TextStyle(
    fontSize: 17,
    height: 1.6,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const lyricActive = TextStyle(
    fontSize: 20,
    height: 1.55,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const numeric = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// 莺花设计规范 · 间距
class AppSpace {
  AppSpace._();
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// 页面左右安全留白
  static const page = 20.0;

  /// 卡片间距
  static const gap = 12.0;

  /// 模块之间的呼吸距离
  static const section = 26.0;
}

/// 莺花设计规范 · 圆角
class AppRadius {
  AppRadius._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const sheet = 26.0;
  static const pill = 999.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const cover = BorderRadius.all(Radius.circular(md));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// 莺花设计规范 · 阴影
class AppShadow {
  AppShadow._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
