import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/download_manager.dart';
import '../../data/local/favorites_store.dart';
import '../../data/models/library_models.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/playback_controller.dart';
import '../pages/album_page.dart';
import '../pages/artist_page.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';

Future<void> downloadSong(BuildContext context, Song song) async {
  final registry = context.read<SourceRegistry>();
  final downloads = context.read<DownloadManager>();
  final source = registry.source;
  if (source == null) {
    showToast(context, '请先连接音乐服务器');
    return;
  }
  if (downloads.isDownloaded(song)) {
    showToast(context, '已下载到本地', icon: Icons.check_circle_outline_rounded);
    return;
  }
  if (downloads.isRunning) {
    showToast(context, '已有批量下载正在进行');
    return;
  }
  final messengerContext = context;
  try {
    await downloads.download(song, source);
    if (messengerContext.mounted) {
      showToast(messengerContext, '已保存到本地', icon: Icons.download_done_rounded);
    }
  } catch (error) {
    if (messengerContext.mounted) {
      showToast(messengerContext, '$error');
    }
  }
}

Future<void> downloadSongs(BuildContext context, List<Song> songs) async {
  if (songs.isEmpty) return;
  final registry = context.read<SourceRegistry>();
  final downloads = context.read<DownloadManager>();
  final source = registry.source;
  if (source == null) {
    showToast(context, '请先连接音乐服务器');
    return;
  }
  if (downloads.isRunning) {
    showToast(context, '已有下载任务正在进行，请稍后再试');
    return;
  }
  final messengerContext = context;
  showToast(context, '开始下载 ${songs.length} 首歌曲');
  try {
    final failed = await downloads.downloadAll(songs, source);
    if (!messengerContext.mounted) return;
    showToast(
      messengerContext,
      failed == 0
          ? '已全部下载完成，可在「我的 - 本地下载」查看'
          : '下载完成，${songs.length - failed} 首成功，$failed 首失败',
      icon: failed == 0 ? Icons.download_done_rounded : null,
      duration: const Duration(seconds: 3),
    );
  } catch (error) {
    if (messengerContext.mounted) showToast(messengerContext, '$error');
  }
}

Future<void> showSongOptionsSheet(BuildContext context, Song song) async {
  final playback = context.read<PlaybackController>();
  final favorites = context.read<FavoritesStore>();
  final downloads = context.read<DownloadManager>();
  final starred = favorites.isSongStarred(song);
  final downloaded = downloads.isDownloaded(song);

  await showAppSheet<void>(
    context,
    (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              CoverImage(
                coverArtId: song.coverArtId,
                songId: song.id,
                size: 54,
                radius: 11,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(
                        color: AppPalette.of(sheetContext).textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.displayArtist} · ${song.displayAlbum}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        _ActionRow(
          icon: Icons.playlist_play_rounded,
          label: '下一首播放',
          onTap: () {
            Navigator.of(sheetContext).pop();
            playback.addToQueueNext(song);
            showToast(context, '已加入下一首播放');
          },
        ),
        _ActionRow(
          icon: starred
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: starred ? AppPalette.of(sheetContext).brand : null,
          label: starred ? '取消收藏' : '收藏这首歌曲',
          onTap: () {
            Navigator.of(sheetContext).pop();
            favorites.toggleSong(song);
          },
        ),
        _ActionRow(
          icon: downloaded
              ? Icons.download_done_rounded
              : Icons.download_outlined,
          label: downloaded ? '已下载到本地' : '下载到本地',
          onTap: () {
            Navigator.of(sheetContext).pop();
            if (downloaded) {
              showToast(context, '可在「我的 - 本地下载」中管理');
            } else {
              downloadSong(context, song);
            }
          },
        ),
        if (song.albumId != null && song.albumId!.isNotEmpty)
          _ActionRow(
            icon: Icons.album_outlined,
            label: '查看专辑 · ${song.displayAlbum}',
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AlbumPage(albumId: song.albumId!, albumName: song.album),
                ),
              );
            },
          ),
        if (song.artistId != null && song.artistId!.isNotEmpty)
          _ActionRow(
            icon: Icons.person_outline_rounded,
            label: '查看歌手 · ${song.displayArtist}',
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ArtistPage(
                    artistId: song.artistId!,
                    artistName: song.artist,
                  ),
                ),
              );
            },
          ),
        _ActionRow(
          icon: Icons.info_outline_rounded,
          label: '歌曲信息',
          onTap: () {
            Navigator.of(sheetContext).pop();
            showSongInfoSheet(context, song);
          },
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color ?? palette.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: color ?? palette.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSongInfoSheet(BuildContext context, Song song) async {
  final registry = context.read<SourceRegistry>();
  final palette = AppPalette.of(context);
  final rows = <(String, String)>[
    ('专辑', song.displayAlbum),
    ('歌手', song.displayArtist),
    ('时长', Fmt.duration(song.duration)),
    if (song.suffix != null) ('格式', song.suffix!.toUpperCase()),
    if (song.bitRate != null && song.bitRate! > 0)
      ('码率', Fmt.bitRate(song.bitRate)),
    if (song.size != null && song.size! > 0) ('大小', Fmt.fileSize(song.size!)),
    if (song.track != null) ('音轨', '第 ${song.track} 首'),
    if (song.year != null) ('年份', '${song.year}'),
    ('音乐源', registry.displayName),
    if (song.path != null) ('路径', song.path!),
  ];
  await showAppSheet<void>(
    context,
    (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('歌曲信息', style: AppText.h2.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 16),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    row.$1,
                    style: AppText.bodySm.copyWith(color: palette.textTertiary),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: AppText.bodySm.copyWith(color: palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Future<void> showSleepTimerSheet(BuildContext context) async {
  final playback = context.read<PlaybackController>();
  await showAppSheet<void>(
    context,
    (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '定时停止',
                  style: AppText.h2.copyWith(
                    color: AppPalette.of(sheetContext).textPrimary,
                  ),
                ),
              ),
              if (playback.sleepRemaining != null)
                Text(
                  '剩余 ${Fmt.clock(playback.sleepRemaining)}',
                  style: AppText.caption.copyWith(
                    color: AppPalette.of(sheetContext).brand,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final option in SleepOption.values)
          ListTile(
            leading: Icon(
              option == SleepOption.off
                  ? Icons.timer_off_outlined
                  : Icons.timer_outlined,
              size: 21,
            ),
            title: Text(option.label),
            trailing: playback.hasSleepTimer && option != SleepOption.off
                ? null
                : null,
            onTap: () {
              Navigator.of(sheetContext).pop();
              playback.setSleepTimer(option);
              showToast(
                context,
                option == SleepOption.off
                    ? '已关闭定时停止'
                    : '将在${option.label}后停止播放',
              );
            },
          ),
      ],
    ),
  );
}
