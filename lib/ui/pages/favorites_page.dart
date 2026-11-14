import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/favorites_store.dart';
import '../../data/models/library_models.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';
import 'album_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesStore>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesStore>();
    final playback = context.watch<PlaybackController>();
    final palette = AppPalette.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我喜欢的音乐'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '歌曲'),
              Tab(text: '专辑'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: favorites.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: palette.textSecondary,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: favorites.loading && favorites.songs.isEmpty
            ? const LoadingView(label: '正在读取收藏')
            : TabBarView(
                children: [
                  _SongsTab(songs: favorites.songs, playback: playback),
                  _AlbumsTab(albums: favorites.albums),
                ],
              ),
      ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({required this.songs, required this.playback});

  final List<Song> songs;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: '还没有收藏的歌曲',
        message: '在播放页点一下红心，喜欢的歌会出现在这里',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 30),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            12,
          ),
          child: Row(
            children: [
              BrandButton(
                label: '播放全部',
                icon: Icons.play_arrow_rounded,
                onPressed: () => playback.playSongs(songs, title: '我喜欢的音乐'),
              ),
              const Spacer(),
              Text(
                '${songs.length} 首',
                style: AppText.caption.copyWith(
                  color: AppPalette.of(context).textTertiary,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            showCover: true,
            highlight: playback.current?.id == songs[i].id,
            playing: playback.playing && playback.current?.id == songs[i].id,
            onTap: () =>
                playback.playSongs(songs, startIndex: i, title: '我喜欢的音乐'),
          ),
      ],
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const EmptyState(
        icon: Icons.album_outlined,
        title: '还没有收藏的专辑',
        message: '在专辑页收藏后，会在这里集中显示',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(
          album: album,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AlbumPage(albumId: album.id, albumName: album.name),
            ),
          ),
        );
      },
    );
  }
}
