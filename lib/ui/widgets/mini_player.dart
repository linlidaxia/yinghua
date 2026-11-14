import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../playback/playback_controller.dart';
import '../pages/player_page.dart';
import 'cover_image.dart';

/// 常驻底部迷你播放条。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final song = playback.current;
    if (song == null) return const SizedBox.shrink();

    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: () => openPlayer(context),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -220) openPlayer(context);
      },
      child: Container(
        height: 58,
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        decoration: BoxDecoration(
          color: palette.isDark ? palette.surface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: palette.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: palette.isDark ? 0.3 : 0.07,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  CoverImage(
                    coverArtId: song.coverArtId,
                    songId: song.id,
                    size: 42,
                    radius: 9,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.titleSm.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (playback.error != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: palette.brand,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (playback.casting) ...[
                              Icon(
                                Icons.cast_connected_rounded,
                                size: 12,
                                color: palette.brand,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '投屏中',
                                style: AppText.caption.copyWith(
                                  color: palette.brand,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                playback.error ?? song.displayArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  color: palette.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MiniButton(
                    icon: playback.loading
                        ? null
                        : (playback.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                    onTap: playback.togglePlay,
                  ),
                  _MiniButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () => playback.next(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<Duration>(
                  valueListenable: playback.position,
                  builder: (context, position, _) {
                    final total = playback.duration.inMilliseconds;
                    final value = total <= 0
                        ? 0.0
                        : (position.inMilliseconds / total).clamp(0.0, 1.0);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 2,
                            width: constraints.maxWidth * value,
                            decoration: BoxDecoration(
                              color: palette.brand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.onTap});

  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 38,
        height: 44,
        child: Center(
          child: icon == null
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              : Icon(icon, size: 26, color: palette.textPrimary),
        ),
      ),
    );
  }
}
