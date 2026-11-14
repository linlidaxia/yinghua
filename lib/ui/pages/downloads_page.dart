import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/download_manager.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';
import '../widgets/song_tile.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadManager>();
    final playback = context.watch<PlaybackController>();
    final palette = AppPalette.of(context);
    final tracks = downloads.tracks;
    final songs = tracks.map((e) => e.song).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地下载'),
        actions: [
          if (tracks.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: '清空所有下载',
                  message:
                      '将删除 ${tracks.length} 首歌曲及其封面，释放 '
                      '${Fmt.fileSize(downloads.totalBytes)} 空间。',
                  confirmText: '删除',
                );
                if (confirmed) await downloads.clearAll();
              },
              child: Text(
                '清空',
                style: AppText.caption.copyWith(color: palette.brand),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (downloads.isRunning) _DownloadProgress(downloads: downloads),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              10,
              AppSpace.page,
              8,
            ),
            child: Row(
              children: [
                Text(
                  '${tracks.length} 首 · ${Fmt.fileSize(downloads.totalBytes)}',
                  style: AppText.caption.copyWith(color: palette.textTertiary),
                ),
                const Spacer(),
                if (tracks.isNotEmpty)
                  GestureDetector(
                    onTap: () => playback.playSongs(songs, title: '本地下载'),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16,
                          color: palette.brand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '播放全部',
                          style: AppText.caption.copyWith(color: palette.brand),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tracks.isEmpty
                ? const EmptyState(
                    icon: Icons.download_outlined,
                    title: '还没有下载的歌曲',
                    message: '在歌曲菜单里选择「下载到本地」，离线也能听',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 30),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final song = track.song;
                      return SongTile(
                        song: song,
                        showCover: true,
                        highlight: playback.current?.id == song.id,
                        playing:
                            playback.playing && playback.current?.id == song.id,
                        subtitle:
                            '${Fmt.fileSize(track.bytes)} · ${Fmt.relativeDay(track.downloadedAt)}',
                        onTap: () => playback.playSongs(
                          songs,
                          startIndex: index,
                          title: '本地下载',
                        ),
                        onMore: () =>
                            _showTrackOptions(context, downloads, track),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTrackOptions(
    BuildContext context,
    DownloadManager downloads,
    DownloadedTrack track,
  ) async {
    await showAppSheet<void>(context, (sheetContext) {
      final palette = AppPalette.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(
                          color: AppPalette.of(sheetContext).textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.song.displayArtist} · ${Fmt.fileSize(track.bytes)}',
                        style: AppText.caption.copyWith(
                          color: AppPalette.of(sheetContext).textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, size: 21),
            title: const Text('立即播放'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.read<PlaybackController>().playSongs([
                track.song,
              ], title: '本地下载');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              size: 21,
              color: palette.brand,
            ),
            title: Text(
              '删除本地文件',
              style: AppText.body.copyWith(color: palette.brand),
            ),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await downloads.remove(track.song);
              if (context.mounted) showToast(context, '已删除本地文件');
            },
          ),
          const SizedBox(height: 10),
        ],
      );
    });
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.downloads});

  final DownloadManager downloads;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final progress = downloads.total <= 0
        ? null
        : downloads.done / downloads.total;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.downloading_rounded, size: 17, color: palette.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  downloads.currentTitle == null
                      ? '正在准备下载'
                      : '正在下载 · ${downloads.currentTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: palette.brand),
                ),
              ),
              Text(
                '${downloads.done}/${downloads.total}',
                style: AppText.numeric.copyWith(color: palette.brand),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: palette.brand.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(palette.brand),
            ),
          ),
        ],
      ),
    );
  }
}
