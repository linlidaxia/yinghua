import 'dart:io';
import 'dart:math';
import 'dart:ui' show MaskFilter, BlurStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/cover_cache.dart';
import '../../data/local/download_manager.dart';
import '../../data/sources/source_registry.dart';

/// 统一封面组件。
///
/// 优先级：离线封面 → 服务器封面 → 程序化「莺花封面」占位图。
/// 占位图由歌曲/专辑 id 作为随机种子生成，保证同一首歌每次颜色一致，
/// 也让没有封面的音乐库保持视觉完整。
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.coverArtId,
    this.songId,
    this.url,
    this.size,
    this.radius = 12,
    this.circle = false,
    this.fit = BoxFit.cover,
    this.seed,
    this.album,
    this.artist,
    this.title,
  });

  final String? coverArtId;
  final String? songId;
  final String? url;
  final double? size;
  final double radius;
  final bool circle;
  final BoxFit fit;
  final String? seed;

  /// 自定义封面接口需要的元数据占位符（{album} / {artist} / {title}）。
  final String? album;
  final String? artist;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<SourceRegistry>();
    final downloads = context.watch<DownloadManager>();

    String? localCover;
    if (!kIsWeb && songId != null) {
      localCover = downloads.coverPathFor(songId!);
    }
    final coverSize = ((size ?? 120).toInt() * 3).clamp(120, 1600);
    final remote =
        url ??
        registry.coverUrl(
          coverArtId,
          size: coverSize,
          album: album,
          artist: artist,
          title: title,
        );
    // 自定义封面接口失败时，回退到服务器封面，避免整屏都是占位图。
    final serverFallback = url == null
        ? registry.serverCoverUrl(coverArtId, size: coverSize)
        : null;
    final fallbackUrl = (serverFallback != null && serverFallback != remote)
        ? serverFallback
        : null;

    final seedKey = seed ?? coverArtId ?? songId ?? 'yinghua';
    final placeholder = SizedBox.expand(
      child: CustomPaint(painter: _CoverArtPainter(seedKey.hashCode)),
    );

    Widget image;
    if (localCover != null && File(localCover).existsSync()) {
      image = Image.file(
        File(localCover),
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (remote != null && remote.isNotEmpty) {
      image = kIsWeb
          ? _networkCover(remote, placeholder, fallbackUrl: fallbackUrl)
          : _CachedCover(
              url: remote,
              placeholder: placeholder,
              fit: fit,
              cacheWidth: coverSize,
              fallbackUrl: fallbackUrl,
            );
    } else {
      image = placeholder;
    }

    final borderRadius = circle
        ? BorderRadius.circular((size ?? 100) / 2)
        : BorderRadius.circular(radius);

    final content = ClipRRect(borderRadius: borderRadius, child: image);
    if (size == null) return content;
    return SizedBox(width: size, height: size, child: content);
  }
}

/// 网页版直接用网络图片（浏览器自带 HTTP 缓存）。
Widget _networkCover(String url, Widget placeholder, {String? fallbackUrl}) {
  return Image.network(
    url,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSyncLoaded) {
      if (wasSyncLoaded || frame != null) return child;
      return placeholder;
    },
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return placeholder;
    },
    errorBuilder: (_, __, ___) => fallbackUrl != null
        ? _networkCover(fallbackUrl, placeholder)
        : placeholder,
  );
}

/// Android / iOS 走本地封面缓存：第二次进入列表直接读磁盘，离线也能显示。
class _CachedCover extends StatefulWidget {
  const _CachedCover({
    required this.url,
    required this.placeholder,
    required this.fit,
    required this.cacheWidth,
    this.fallbackUrl,
  });

  final String url;
  final Widget placeholder;
  final BoxFit fit;
  final int cacheWidth;
  final String? fallbackUrl;

  @override
  State<_CachedCover> createState() => _CachedCoverState();
}

class _CachedCoverState extends State<_CachedCover> {
  late Future<File?> _future = CoverCache.load(widget.url);

  @override
  void didUpdateWidget(covariant _CachedCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = CoverCache.load(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded || frame != null) return child;
              return widget.placeholder;
            },
            errorBuilder: (_, __, ___) => widget.placeholder,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder;
        }
        // 磁盘缓存不可用时退回直连下载；自定义接口失败则回退服务器封面。
        return _networkCover(
          widget.url,
          widget.placeholder,
          fallbackUrl: widget.fallbackUrl,
        );
      },
    );
  }
}

class _CoverArtPainter extends CustomPainter {
  _CoverArtPainter(this.seed);

  final int seed;

  static const _palettes = <List<Color>>[
    [Color(0xFFF3C7B3), Color(0xFFE08A7D), Color(0xFF7B4B63)],
    [Color(0xFFCFE3D9), Color(0xFF7DAA9E), Color(0xFF2E4F52)],
    [Color(0xFFD8D3E8), Color(0xFF9C8FB8), Color(0xFF463A5C)],
    [Color(0xFFF6E2B8), Color(0xFFD9A15B), Color(0xFF6B4A2B)],
    [Color(0xFFC9D8EA), Color(0xFF6F8FB5), Color(0xFF2C3E5C)],
    [Color(0xFFF0C9CE), Color(0xFFC2707E), Color(0xFF5C2F3C)],
    [Color(0xFFD7E6C9), Color(0xFF8BAE72), Color(0xFF3F5230)],
    [Color(0xFFE8D5C4), Color(0xFFB08A6A), Color(0xFF4C382A)],
    [Color(0xFFD2E7E9), Color(0xFF79B0B8), Color(0xFF2C4A4F)],
    [Color(0xFFEAD9E7), Color(0xFFB089B1), Color(0xFF4F3350)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final palette = _palettes[seed.abs() % _palettes.length];
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: palette,
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = gradient);

    for (var i = 0; i < 3; i++) {
      final center = Offset(
        size.width * (0.15 + random.nextDouble() * 0.7),
        size.height * (0.15 + random.nextDouble() * 0.7),
      );
      final radius = size.width * (0.18 + random.nextDouble() * 0.3);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.10),
      );
    }

    final ringCenter = Offset(size.width * 0.52, size.height * 0.54);
    canvas.drawCircle(
      ringCenter,
      size.width * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.007
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '♪',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: size.width * 0.26,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      ringCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CoverArtPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
