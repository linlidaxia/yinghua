import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/sources/music_source.dart';
import '../../data/sources/source_registry.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';
import '../widgets/media_cards.dart';
import 'album_page.dart';
import 'artist_page.dart';
import 'playlist_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<List<Album>> _albums;
  late Future<List<Artist>> _artists;
  late Future<List<Playlist>> _playlists;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<LibraryRepository>();
    _albums = repo.albums(AlbumListType.alphabetical, size: 200, refresh: true);
    _artists = repo.artists(refresh: true);
    _playlists = repo.playlists(refresh: true);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<Object?>([
      _albums.catchError((_) => <Album>[]),
      _artists.catchError((_) => <Artist>[]),
      _playlists.catchError((_) => <Playlist>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final registry = context.watch<SourceRegistry>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 62,
          titleSpacing: AppSpace.page,
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '资料库',
                style: AppText.display.copyWith(
                  color: palette.textPrimary,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                registry.isDemo ? '演示资料库' : registry.displayName,
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 21),
              color: palette.textSecondary,
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '专辑'),
              Tab(text: '歌手'),
              Tab(text: '歌单'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AlbumTab(future: _albums, onRefresh: _refresh),
            _ArtistTab(future: _artists, onRefresh: _refresh),
            _PlaylistTab(future: _playlists, onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

class _AlbumTab extends StatelessWidget {
  const _AlbumTab({required this.future, required this.onRefresh});

  final Future<List<Album>> future;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return FutureBuilder<List<Album>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: '正在读取专辑');
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: onRefresh);
        }
        final albums = snapshot.data ?? const [];
        if (albums.isEmpty) {
          return const EmptyState(
            icon: Icons.album_outlined,
            title: '音乐库里还没有专辑',
            message: '在服务器上添加音乐后会自动出现',
          );
        }
        return RefreshIndicator(
          color: palette.brand,
          onRefresh: onRefresh,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              16,
              AppSpace.page,
              28,
            ),
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
          ),
        );
      },
    );
  }
}

class _ArtistTab extends StatelessWidget {
  const _ArtistTab({required this.future, required this.onRefresh});

  final Future<List<Artist>> future;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return FutureBuilder<List<Artist>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: '正在读取歌手');
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: onRefresh);
        }
        final artists = snapshot.data ?? const [];
        if (artists.isEmpty) {
          return const EmptyState(
            icon: Icons.person_outline_rounded,
            title: '还没有歌手信息',
            message: '音乐文件的标签里写入歌手后即可显示',
          );
        }
        return RefreshIndicator(
          color: palette.brand,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return ArtistRow(
                artist: artist,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistPage(
                      artistId: artist.id,
                      artistName: artist.name,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PlaylistTab extends StatelessWidget {
  const _PlaylistTab({required this.future, required this.onRefresh});

  final Future<List<Playlist>> future;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return FutureBuilder<List<Playlist>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: '正在读取歌单');
        }
        if (snapshot.hasError) {
          return ErrorView(message: '${snapshot.error}', onRetry: onRefresh);
        }
        final playlists = snapshot.data ?? const [];
        if (playlists.isEmpty) {
          return EmptyState(
            icon: Icons.queue_music_rounded,
            title: '服务器上没有歌单',
            message: '在 Navidrome 里创建歌单后会同步到这里',
            actionLabel: '刷新',
            onAction: () => onRefresh(),
          );
        }
        return RefreshIndicator(
          color: palette.brand,
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              8,
              AppSpace.page,
              28,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '共 ${playlists.length} 个歌单 · 来自 ${context.read<SourceRegistry>().displayName}',
                  style: AppText.caption.copyWith(color: palette.textTertiary),
                ),
              ),
              for (final playlist in playlists)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlaylistPage(
                          playlistId: playlist.id,
                          playlistName: playlist.name,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CoverImage(
                            coverArtId: playlist.coverArtId,
                            seed: playlist.id,
                            size: 62,
                            radius: 12,
                            album: playlist.name,
                            artist: playlist.owner,
                            title: playlist.name,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.title.copyWith(
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  playlist.meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                                if (playlist.comment != null &&
                                    playlist.comment!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    playlist.comment!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(
                                      color: palette.textTertiary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: palette.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
