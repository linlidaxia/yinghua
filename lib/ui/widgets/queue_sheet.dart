import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library_models.dart';
import '../../playback/playback_controller.dart';
import 'common.dart';
import 'cover_image.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (_) => const QueueSheet(),
    fullHeight: true,
  );
}

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final palette = AppPalette.of(context);
    final queueTitle = playback.queueTitle;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '播放队列',
                      style: AppText.h2.copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$queueTitle · ${playback.queue.length} 首',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: palette.textSecondary,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              for (final mode in PlayMode.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _ModeChip(
                      mode: mode,
                      active: playback.mode == mode,
                      onTap: () => playback.setMode(mode),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: playback.queue.isEmpty
              ? const EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: '队列还是空的',
                  message: '从专辑或歌单里挑一首开始播放吧',
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: playback.queue.length,
                  onReorder: (oldIndex, newIndex) =>
                      playback.reorderQueue(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final song = playback.queue[index];
                    final current = index == playback.index;
                    return _QueueTile(
                      key: ValueKey('${song.id}_$index'),
                      song: song,
                      index: index,
                      current: current,
                      playing: current && playback.playing,
                      onTap: () => playback.jumpTo(index),
                      onRemove: () => playback.removeFromQueue(index),
                    );
                  },
                ),
        ),
        if (playback.queue.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
              child: Row(
                children: [
                  Text(
                    '共 ${playback.queue.length} 首 · 可拖动排序',
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: '清空播放队列',
                        message: '当前播放会停止，队列内容将被移除。',
                        confirmText: '清空',
                      );
                      if (confirmed) {
                        await playback.clearQueue();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      '清空',
                      style: AppText.caption.copyWith(color: palette.brand),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.active,
    required this.onTap,
  });

  final PlayMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? palette.brandSoft : palette.surface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Icon(
              mode.icon,
              size: 17,
              color: active ? palette.brand : palette.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              mode.label,
              style: AppText.caption.copyWith(
                fontSize: 9,
                color: active ? palette.brand : palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.current,
    required this.playing,
    required this.onTap,
    required this.onRemove,
  });

  final Song song;
  final int index;
  final bool current;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      color: current ? palette.brandSoft.withValues(alpha: 0.6) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: palette.textTertiary,
                  ),
                ),
              ),
              CoverImage(
                coverArtId: song.coverArtId,
                songId: song.id,
                size: 38,
                radius: 9,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (current) ...[
                          Icon(
                            playing
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            size: 12,
                            color: palette.brand,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleSm.copyWith(
                              color: current
                                  ? palette.brand
                                  : palette.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.displayArtist} · ${Fmt.duration(song.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: palette.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
