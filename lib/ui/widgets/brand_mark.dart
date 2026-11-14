import 'package:flutter/material.dart';

/// 莺花品牌标识：黑胶唱片里裁出的音符。
///
/// 图形来自 `assets/brand/logo.png`（由 `brand/vinyl-mark.svg` 导出）。
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
