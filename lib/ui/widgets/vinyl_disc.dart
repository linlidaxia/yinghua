import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/library_models.dart';
import 'cover_image.dart';

/// 黑胶唱片：中心封面 + 纹路 + 缓慢旋转。
class VinylDisc extends StatefulWidget {
  const VinylDisc({
    super.key,
    required this.size,
    required this.song,
    required this.playing,
  });

  final double size;
  final Song? song;
  final bool playing;

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final song = widget.song;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 36,
            offset: const Offset(0, 20),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 盘体
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 1.05,
                  colors: [
                    Color(0xFF232328),
                    AppColors.vinylBlack,
                    AppColors.vinylEdge,
                  ],
                  stops: [0.0, 0.62, 1.0],
                ),
              ),
            ),
            // 纹路
            CustomPaint(size: Size.square(size), painter: _GroovePainter()),
            // 中心封面
            Container(
              width: size * 0.60,
              height: size * 0.60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: size * 0.006,
                ),
              ),
              child: ClipOval(
                child: CoverImage(
                  coverArtId: song?.coverArtId,
                  songId: song?.id,
                  seed: song?.albumId,
                  size: null,
                  radius: 0,
                ),
              ),
            ),
            // 唱针孔
            Container(
              width: size * 0.035,
              height: size * 0.035,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF101014),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
            ),
            // 高光
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      stops: const [0.0, 0.36, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    for (var i = 0; i < 22; i++) {
      final radius = outer * (0.64 + i * 0.0155);
      if (radius >= outer) break;
      final alpha = 0.028 + (i % 3 == 0 ? 0.02 : 0.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: alpha),
      );
    }
    // 一道斜向高光弧
    final rect = Rect.fromCircle(center: center, radius: outer * 0.82);
    canvas.drawArc(
      rect,
      -math.pi * 0.85,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer * 0.035
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
