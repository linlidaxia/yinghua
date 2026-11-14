import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/settings_store.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';
import '../widgets/song_tile.dart';

class RecentSongsPage extends StatelessWidget {
  const RecentSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final playback = context.read<PlaybackController>();
    final palette = AppPalette.of(context);
    final songs = settings.recentSongs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('最近播放'),
        actions: [
          if (songs.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: '清空最近播放',
                  message: '只会清除本机的播放记录，不影响服务器数据。',
                  confirmText: '清空',
                );
                if (confirmed) await settings.clearRecentSongs();
              },
              child: Text(
                '清空',
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: '还没有播放记录',
              message: '听过的歌曲会出现在这里，最多保留 50 首',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  showCover: true,
                  onTap: () => playback.playSongs(
                    songs,
                    startIndex: index,
                    title: '最近播放',
                  ),
                );
              },
            ),
    );
  }
}
