import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/sorters.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../playback/playback_controller.dart';
import '../sheets/skip_intro_sheet.dart';
import '../sheets/lyric_offset_sheet.dart';
import '../sheets/song_actions.dart';
import '../sheets/sort_sheet.dart';
import '../widgets/common.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.playlistId, this.playlistName});

  final String playlistId;
  final String? playlistName;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late Future<PlaylistDetail> _future;
  PlaylistDetail? _detail;
  SortOrder _sort = SortOrder.server;

  /// 「继续播放」只在进入歌单后短暂显示，避免长期占位。
  bool _showResume = true;
  Timer? _resumeTimer;
  static const Duration _resumeLifetime = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _future = _load();
    _resumeTimer = Timer(_resumeLifetime, () {
      if (mounted) setState(() => _showResume = false);
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    super.dispose();
  }

  void _hideResume() {
    _resumeTimer?.cancel();
    if (_showResume) setState(() => _showResume = false);
  }

  Future<PlaylistDetail> _load() async {
    final detail = await context.read<LibraryRepository>().playlist(
      widget.playlistId,
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
            height: 340,
            child: _PlaylistBackdrop(coverArtId: _detail?.playlist.coverArtId),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onDownload: () => _downloadAll(context),
                ),
                Expanded(
                  child: FutureBuilder<PlaylistDetail>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(label: '正在读取歌单');
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
                          icon: Icons.queue_music_rounded,
                          title: '没有找到这个歌单',
                        );
                      }
                      final playlist = detail.playlist;
                      final songs = sortSongs(detail.songs, _sort);
                      final settings = context.watch<SettingsStore>();
                      final skip = settings.skipFor(widget.playlistId);
                      final saved = settings.progressForPlaylist(
                        widget.playlistId,
                      );
                      final resumeIndex = (saved != null && saved.isUsable)
                          ? songs.indexWhere((song) => song.id == saved.songId)
                          : -1;
                      final total = songs.fold<Duration>(
                        Duration.zero,
                        (sum, song) => sum + song.duration,
                      );
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 30),
                        children: [
                          _Header(
                            playlist: playlist,
                            subtitle:
                                '${songs.length} 首 · ${Fmt.duration(total)}',
                          ),
                          if (playlist.comment != null &&
                              playlist.comment!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpace.page,
                                14,
                                AppSpace.page,
                                0,
                              ),
                              child: Text(
                                playlist.comment!,
                                style: AppText.bodySm.copyWith(
                                  color: palette.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          if (_showResume && resumeIndex >= 0) ...[
                            const SizedBox(height: 14),
                            _ResumeBar(
                              song: songs[resumeIndex],
                              index: resumeIndex,
                              position: saved!.position,
                              onResume: () {
                                _hideResume();
                                _resume(
                                  context,
                                  songs,
                                  resumeIndex,
                                  saved.position,
                                );
                              },
                              onRestart: () {
                                _hideResume();
                                context
                                    .read<SettingsStore>()
                                    .clearPlaylistProgress(widget.playlistId);
                                _play(context, songs);
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
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
                                  onPressed: () => showLyricOffsetSheet(
                                    context,
                                    playlistId: widget.playlistId,
                                    playlistName: playlist.name,
                                  ),
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 22,
                                  ),
                                  color: palette.textSecondary,
                                  tooltip: '歌词校准',
                                ),
                                IconButton(
                                  onPressed: () => _downloadAll(context),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 22,
                                  ),
                                  color: palette.textSecondary,
                                  tooltip: '下载歌单',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.page,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${songs.length} 首歌曲',
                                  style: AppText.caption.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  onTap: () => showSkipIntroSheet(
                                    context,
                                    playlistId: widget.playlistId,
                                    playlistName: playlist.name,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: skip == null
                                          ? palette.surface
                                          : palette.brandSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.content_cut_rounded,
                                          size: 14,
                                          color: skip == null
                                              ? palette.textSecondary
                                              : palette.brand,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          skip == null
                                              ? '跳过头尾'
                                              : skip.isActive
                                              ? '跳过 ${skip.intro.inSeconds}/${skip.outro.inSeconds}s'
                                              : '已关闭跳过',
                                          style: AppText.caption.copyWith(
                                            color: skip == null
                                                ? palette.textSecondary
                                                : palette.brand,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  onTap: () async {
                                    final picked = await showSortSheet(
                                      context,
                                      current: _sort,
                                    );
                                    if (picked != null && mounted) {
                                      setState(() => _sort = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _sort.isDefault
                                          ? palette.surface
                                          : palette.brandSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.swap_vert_rounded,
                                          size: 15,
                                          color: _sort.isDefault
                                              ? palette.textSecondary
                                              : palette.brand,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _sort.shortLabel,
                                          style: AppText.caption.copyWith(
                                            color: _sort.isDefault
                                                ? palette.textSecondary
                                                : palette.brand,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (songs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 30),
                              child: EmptyState(
                                icon: Icons.music_off_outlined,
                                title: '这个歌单还没有歌曲',
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
    _hideResume();
    context.read<PlaybackController>().playSongs(
      songs,
      startIndex: index,
      title: widget.playlistName ?? _detail?.playlist.name ?? '歌单',
      playlistId: widget.playlistId,
    );
  }

  /// 从上次停下的歌曲与位置继续。
  void _resume(
    BuildContext context,
    List<Song> songs,
    int index,
    Duration position,
  ) {
    context.read<PlaybackController>().playSongs(
      songs,
      startIndex: index,
      title: widget.playlistName ?? _detail?.playlist.name ?? '歌单',
      playlistId: widget.playlistId,
      startPosition: position,
    );
  }

  void _playShuffled(BuildContext context, List<Song> songs) {
    _hideResume();
    final shuffled = List.of(songs)..shuffle();
    context.read<PlaybackController>().playSongs(
      shuffled,
      title: '${widget.playlistName ?? '歌单'} · 随机',
      playlistId: widget.playlistId,
    );
    showToast(context, '已随机播放 ${songs.length} 首');
  }

  void _downloadAll(BuildContext context) {
    final songs = _detail?.songs ?? const <Song>[];
    if (songs.isEmpty) {
      showToast(context, '歌单还没有可以下载的歌曲');
      return;
    }
    downloadSongs(context, songs);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onDownload});

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

class _Header extends StatelessWidget {
  const _Header({required this.playlist, required this.subtitle});

  final Playlist playlist;
  final String subtitle;

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
              coverArtId: playlist.coverArtId,
              seed: playlist.id,
              size: 148,
              radius: AppRadius.md,
              album: playlist.name,
              artist: playlist.owner,
              title: playlist.name,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h1.copyWith(
                    color: palette.textPrimary,
                    fontSize: 21,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
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
                        playlist.owner ?? '音乐服务器',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
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

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({
    required this.song,
    required this.index,
    required this.position,
    required this.onResume,
    required this.onRestart,
  });

  final Song song;
  final int index;
  final Duration position;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      child: Material(
        color: palette.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onResume,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 36,
                  color: palette.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '继续播放',
                        style: AppText.titleSm.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '第 ${index + 1} 首 · ${song.title} · '
                        '${Fmt.duration(position)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onRestart, child: const Text('从头播放')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistBackdrop extends StatelessWidget {
  const _PlaylistBackdrop({this.coverArtId});

  final String? coverArtId;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Transform.scale(
              scale: 1.28,
              child: CoverImage(coverArtId: coverArtId, size: null, radius: 0),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.bg.withValues(alpha: 0.52),
                  palette.bg.withValues(alpha: 0.74),
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
