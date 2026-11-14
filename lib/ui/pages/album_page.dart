import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../playback/playback_controller.dart';
import '../sheets/song_actions.dart';
import '../widgets/common.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';
import 'artist_page.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.albumId, this.albumName});

  final String albumId;
  final String? albumName;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<AlbumDetail> _future;
  AlbumDetail? _detail;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AlbumDetail> _load() async {
    final detail = await context.read<LibraryRepository>().album(
      widget.albumId,
      refresh: true,
    );
    _detail = detail;
    return detail;
  }

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
            height: 360,
            child: FutureBuilder<AlbumDetail>(
              future: _future,
              builder: (context, snapshot) {
                return _HeaderBackdrop(
                  coverArtId: snapshot.data?.album.coverArtId,
                );
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _NavBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onDownload: () => _downloadAll(context),
                ),
                Expanded(
                  child: FutureBuilder<AlbumDetail>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(label: '正在读取专辑');
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
                          icon: Icons.album_outlined,
                          title: '没有找到这张专辑',
                        );
                      }
                      final album = detail.album;
                      final songs = detail.songs;
                      final totalDuration = songs.fold<Duration>(
                        Duration.zero,
                        (sum, song) => sum + song.duration,
                      );
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 30),
                        children: [
                          _AlbumHeader(
                            album: album,
                            subtitle:
                                '${album.meta} · ${Fmt.duration(totalDuration)}',
                            onArtistTap:
                                album.artistId == null ||
                                    album.artistId!.isEmpty
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ArtistPage(
                                        artistId: album.artistId!,
                                        artistName: album.artist,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.page,
                            ),
                            child: Row(
                              children: [
                                BrandButton(
                                  label: '播放全部',
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: songs.isEmpty
                                      ? null
                                      : () => _play(context, songs),
                                ),
                                const SizedBox(width: 10),
                                GhostButton(
                                  label: '随机',
                                  icon: Icons.shuffle_rounded,
                                  onPressed: songs.isEmpty
                                      ? null
                                      : () => _playShuffled(context, songs),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _downloadAll(context),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 22,
                                  ),
                                  color: palette.textSecondary,
                                  tooltip: '下载整张专辑',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.page,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '歌曲',
                                  style: AppText.h2.copyWith(
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${songs.length} 首',
                                  style: AppText.caption.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (songs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 30),
                              child: EmptyState(
                                icon: Icons.music_off_outlined,
                                title: '这张专辑还没有歌曲',
                              ),
                            ),
                          for (var i = 0; i < songs.length; i++)
                            SongTile(
                              song: songs[i],
                              index: i,
                              highlight: playback.current?.id == songs[i].id,
                              playing:
                                  playback.playing &&
                                  playback.current?.id == songs[i].id,
                              onTap: () => _play(context, songs, index: i),
                              onMore: () =>
                                  showSongOptionsSheet(context, songs[i]),
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

  void _play(BuildContext context, List<Song> songs, {int index = 0}) {
    context.read<PlaybackController>().playSongs(
      songs,
      startIndex: index,
      title: widget.albumName ?? '专辑',
    );
    if (index == 0) {
      showToast(context, '开始播放', icon: Icons.play_arrow_rounded);
    }
  }

  void _playShuffled(BuildContext context, List<Song> songs) {
    final shuffled = List.of(songs)..shuffle();
    context.read<PlaybackController>().playSongs(
      shuffled,
      title: '${widget.albumName ?? '专辑'} · 随机',
    );
    showToast(context, '已随机播放 ${songs.length} 首');
  }

  void _downloadAll(BuildContext context) {
    final songs = _detail?.songs ?? const <Song>[];
    if (songs.isEmpty) {
      showToast(context, '专辑还没有可以下载的歌曲');
      return;
    }
    downloadSongs(context, songs);
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onBack, required this.onDownload});

  final VoidCallback onBack;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: 6),
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          _GlassIconButton(icon: Icons.download_outlined, onTap: onDownload),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: palette.bg.withValues(alpha: 0.62),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: palette.textPrimary),
      ),
    );
  }
}

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({
    required this.album,
    required this.subtitle,
    this.onArtistTap,
  });

  final Album album;
  final String subtitle;
  final VoidCallback? onArtistTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 2, AppSpace.page, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadow.floating,
            ),
            child: CoverImage(
              coverArtId: album.coverArtId,
              seed: album.id,
              size: 140,
              radius: AppRadius.md,
              album: album.name,
              artist: album.displayArtist,
              title: album.name,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h1.copyWith(
                    color: palette.textPrimary,
                    fontSize: 21,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onArtistTap,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: palette.surfaceHigh,
                        child: Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          album.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      if (onArtistTap != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: palette.textTertiary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppText.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop({this.coverArtId});

  final String? coverArtId;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
            child: Transform.scale(
              scale: 1.25,
              child: CoverImage(coverArtId: coverArtId, size: null, radius: 0),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.bg.withValues(alpha: 0.50),
                  palette.bg.withValues(alpha: 0.72),
                  palette.bg.withValues(alpha: 0.94),
                  palette.bg,
                ],
                stops: const [0.0, 0.45, 0.8, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
