import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_typography.dart';
import '../../playback/playback_controller.dart';
import '../pages/player_page.dart';
import '../widgets/cover_image.dart';

/// 应用内悬浮歌词：在浏览其他页面时显示当前歌词行，可拖动。
///
/// 说明：这是应用内浮层，不会覆盖系统桌面；系统级悬浮窗需要额外授权，
/// 因此默认不申请任何敏感权限。
class FloatingLyricOverlay extends StatefulWidget {
  const FloatingLyricOverlay({super.key});

  @override
  State<FloatingLyricOverlay> createState() => _FloatingLyricOverlayState();
}

class _FloatingLyricOverlayState extends State<FloatingLyricOverlay> {
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final song = playback.current;
    if (song == null) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      bottom: 132 + _dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dy = (_dy + details.delta.dy).clamp(-60.0, 320.0);
          });
        },
        onTap: () => openPlayer(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C22).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CoverImage(
                coverArtId: song.coverArtId,
                songId: song.id,
                size: 34,
                radius: 8,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: playback.lyricLine,
                  builder: (context, index, _) {
                    final lyric = playback.lyric;
                    final text =
                        (lyric != null &&
                            lyric.synced &&
                            index >= 0 &&
                            index < lyric.lines.length)
                        ? lyric.lines[index].text
                        : '${song.title} · ${song.displayArtist}';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '莺花 · 悬浮歌词',
                          style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
