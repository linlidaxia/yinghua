import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/cover_image.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';
import 'album_page.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId, this.artistName});

  final String artistId;
  final String? artistName;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late Future<ArtistDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ArtistDetail> _load() =>
      context.read<LibraryRepository>().artist(widget.artistId, refresh: true);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playback = context.watch<PlaybackController>();
    return Scaffold(
      bottomNavigationBar: const MiniPlayerBar(),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 300,
            child: _ArtistBackdrop(coverArtId: null, seed: widget.artistId),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: FutureBuilder<ArtistDetail>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(label: '正在读取歌手');
                      }
                      if (snapshot.hasError) {
                        return ErrorView(
                          message: '${snapshot.error}',
                          onRetry: () => setState(() => _future = _load()),
                        );
                      }
                      final detail = snapshot.data;
                      if (detail == null) {
                        return const EmptyState(
                          icon: Icons.person_outline_rounded,
                          title: '没有找到这位歌手',
                        );
                      }
                      final artist = detail.artist;
                      final songs = detail.topSongs;
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 34),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.page,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artist.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.display.copyWith(
                                    color: palette.textPrimary,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${artist.albumCount} 张专辑'
                                  '${artist.songCount == null ? '' : ' · ${artist.songCount} 首歌曲'}',
                                  style: AppText.caption.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (songs.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.page,
                              ),
                              child: Row(
                                children: [
                                  BrandButton(
                                    label: '播放热门歌曲',
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () => context
                                        .read<PlaybackController>()
                                        .playSongs(
                                          songs,
                                          title: '${artist.name} · 热门歌曲',
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  GhostButton(
                                    label: '随机',
                                    icon: Icons.shuffle_rounded,
                                    onPressed: () {
                                      final shuffled = List.of(songs)
                                        ..shuffle();
                                      context
                                          .read<PlaybackController>()
                                          .playSongs(
                                            shuffled,
                                            title: '${artist.name} · 随机',
                                          );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SectionHeader(title: '热门歌曲', subtitle: '播放最多'),
                            for (var i = 0; i < songs.length; i++)
                              SongTile(
                                song: songs[i],
                                index: i,
                                highlight: playback.current?.id == songs[i].id,
                                playing:
                                    playback.playing &&
                                    playback.current?.id == songs[i].id,
                                onTap: () => context
                                    .read<PlaybackController>()
                                    .playSongs(
                                      songs,
                                      startIndex: i,
                                      title: '${artist.name} · 热门歌曲',
                                    ),
                              ),
                            const SizedBox(height: AppSpace.section),
                          ],
                          SectionHeader(
                            title: '专辑',
                            subtitle: '${detail.albums.length} 张',
                          ),
                          if (detail.albums.isEmpty)
                            const EmptyState(
                              icon: Icons.album_outlined,
                              title: '暂无专辑',
                            )
                          else
                            GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.page,
                              ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: detail.albums.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 18,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.78,
                                  ),
                              itemBuilder: (context, index) {
                                final album = detail.albums[index];
                                return AlbumCard(
                                  album: album,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AlbumPage(
                                        albumId: album.id,
                                        albumName: album.name,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.bg.withValues(alpha: 0.62),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistBackdrop extends StatelessWidget {
  const _ArtistBackdrop({this.coverArtId, this.seed});

  final String? coverArtId;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Transform.scale(
              scale: 1.3,
              child: CoverImage(
                coverArtId: coverArtId,
                seed: seed,
                size: null,
                radius: 0,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.bg.withValues(alpha: 0.62),
                  palette.bg.withValues(alpha: 0.88),
                  palette.bg,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
