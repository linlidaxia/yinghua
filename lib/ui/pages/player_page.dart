import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/download_manager.dart';
import '../../data/local/favorites_store.dart';
import '../../data/models/library_models.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/dlna_controller.dart';
import '../../playback/playback_controller.dart';
import '../pages/artist_page.dart';
import '../sheets/dlna_sheet.dart';
import '../sheets/lyric_offset_sheet.dart';
import '../sheets/song_actions.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';
import '../widgets/lyric_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/vinyl_disc.dart';

Future<void> openPlayer(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const PlayerPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.initialPage = 0});

  /// 0 = 黑胶封面，1 = 滚动歌词。供深链与截图脚本直接打开指定分页。
  final int initialPage;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialPage,
  );
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final song = playback.current;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C10),
        body: song == null
            ? SafeArea(
                child: Stack(
                  children: [
                    const _PlayerBackdrop(song: null),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '还没有正在播放的歌曲',
                            style: AppText.title.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          GhostButton(
                            label: '返回',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -280) {
                    playback.next();
                  } else if (velocity > 280) {
                    playback.previous();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PlayerBackdrop(song: song),
                    SafeArea(
                      child: Column(
                        children: [
                          _TopBar(
                            page: _page,
                            onDown: () {
                              if (_page == 1) {
                                _goToPage(0);
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            onRight: _page == 0
                                ? () => showSongOptionsSheet(context, song)
                                : () => showSongInfoSheet(context, song),
                            rightIcon: _page == 0
                                ? Icons.more_horiz_rounded
                                : Icons.info_outline_rounded,
                          ),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              scrollDirection: Axis.vertical,
                              onPageChanged: (index) =>
                                  setState(() => _page = index),
                              children: [
                                _VinylPage(
                                  playback: playback,
                                  onOpenLyrics: () => _goToPage(1),
                                ),
                                _LyricsPage(
                                  playback: playback,
                                  onBack: () => _goToPage(0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.onDown,
    required this.onRight,
    required this.rightIcon,
  });

  final int page;
  final VoidCallback onDown;
  final VoidCallback onRight;
  final IconData rightIcon;

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<SourceRegistry>();
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            color: Colors.white,
            tooltip: page == 1 ? '返回唱片' : '收起播放页',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  page == 0 ? '正在播放' : '歌词',
                  style: AppText.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  registry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRight,
            icon: Icon(rightIcon, size: 22),
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _VinylPage extends StatelessWidget {
  const _VinylPage({required this.playback, required this.onOpenLyrics});

  final PlaybackController playback;
  final VoidCallback onOpenLyrics;

  @override
  Widget build(BuildContext context) {
    final song = playback.current;
    if (song == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final discSize = math.min(
          constraints.maxWidth * 0.74,
          math.min(312.0, constraints.maxHeight * 0.40),
        );
        return Column(
          children: [
            const Spacer(flex: 5),
            VinylDisc(
              size: discSize,
              song: song,
              playing: playback.playing && !playback.loading,
            ),
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppText.h1.copyWith(
                      color: Colors.white,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (song.artistId != null && song.artistId!.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArtistPage(
                              artistId: song.artistId!,
                              artistName: song.artist,
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                        if (song.artistId != null) ...[
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (playback.streamOffset > Duration.zero) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '已跳过片头 ${Fmt.duration(playback.streamOffset)}',
                        style: AppText.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _LyricPreview(playback: playback, onTap: onOpenLyrics),
                ],
              ),
            ),
            const Spacer(flex: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PlayerProgress(playback: playback),
            ),
            const SizedBox(height: 4),
            _Controls(playback: playback),
            const SizedBox(height: 14),
            _Actions(playback: playback),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _LyricPreview extends StatelessWidget {
  const _LyricPreview({required this.playback, required this.onTap});

  final PlaybackController playback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 24,
        child: ValueListenableBuilder<int>(
          valueListenable: playback.lyricLine,
          builder: (context, index, _) {
            final lyric = playback.lyric;
            String text;
            if (playback.lyricLoading) {
              text = '歌词加载中…';
            } else if (lyric == null || lyric.isEmpty) {
              text = '暂无歌词 · 上滑查看';
            } else if (!lyric.synced) {
              text = lyric.lines.first.text;
            } else if (index >= 0 && index < lyric.lines.length) {
              text = lyric.lines[index].text;
            } else {
              text = lyric.lines.first.text;
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.32),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Text(
                      text,
                      key: ValueKey(text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerProgress extends StatefulWidget {
  const _PlayerProgress({required this.playback});
  final PlaybackController playback;

  @override
  State<_PlayerProgress> createState() => _PlayerProgressState();
}

class _PlayerProgressState extends State<_PlayerProgress> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return ValueListenableBuilder<Duration>(
      valueListenable: playback.position,
      builder: (context, position, _) {
        final total = playback.duration.inMilliseconds;
        final safeTotal = total <= 0 ? 1 : total;
        final value =
            _dragValue ?? (position.inMilliseconds / safeTotal).clamp(0.0, 1.0);
        final buffered =
            (_dragValue ?? (playback.buffered.value.inMilliseconds / safeTotal))
                .clamp(0.0, 1.0);
        final display = _dragValue == null
            ? position
            : Duration(milliseconds: (safeTotal * _dragValue!).round());
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
                secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.34),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 4.5,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                secondaryTrackValue: math.max(value, buffered),
                onChangeStart: (v) => setState(() => _dragValue = v),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) async {
                  await playback.seek(
                    Duration(milliseconds: (safeTotal * v).round()),
                  );
                  if (mounted) setState(() => _dragValue = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    Fmt.duration(display),
                    style: AppText.numeric.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.duration(playback.duration),
                    style: AppText.numeric.copyWith(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ControlButton(
            icon: playback.mode.icon,
            size: 21,
            color: Colors.white.withValues(alpha: 0.72),
            onTap: () {
              playback.cycleMode();
              showToast(context, playback.mode.label, icon: playback.mode.icon);
            },
          ),
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: 36,
            color: Colors.white,
            onTap: () => playback.previous(),
          ),
          _PlayButton(playback: playback),
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 36,
            color: Colors.white,
            onTap: () => playback.next(),
          ),
          _ControlButton(
            icon: Icons.queue_music_rounded,
            size: 23,
            color: Colors.white.withValues(alpha: 0.72),
            onTap: () => showQueueSheet(context),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: playback.togglePlay,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.brand,
          boxShadow: [
            BoxShadow(
              color: palette.brand.withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: playback.loading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(
                playback.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final song = playback.current;
    final favorites = context.watch<FavoritesStore>();
    final downloads = context.watch<DownloadManager>();
    final dlna = context.watch<DlnaController>();
    if (song == null) return const SizedBox.shrink();
    final starred = favorites.isSongStarred(song);
    final downloaded = downloads.isDownloaded(song);
    final sleepLeft = playback.sleepRemaining;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PlayerAction(
          icon: starred
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: starred ? '已收藏' : '收藏',
          active: starred,
          onTap: () => favorites.toggleSong(song),
        ),
        _PlayerAction(
          icon: downloaded
              ? Icons.download_done_rounded
              : Icons.download_outlined,
          label: downloaded ? '已下载' : '下载',
          active: downloaded,
          onTap: () => downloadSong(context, song),
        ),
        _PlayerAction(
          icon: dlna.isCasting
              ? Icons.cast_connected_rounded
              : Icons.cast_rounded,
          label: dlna.isCasting ? '投屏中' : '投屏',
          active: dlna.isCasting,
          onTap: () => showDlnaSheet(context),
        ),
        _PlayerAction(
          icon: playback.hasSleepTimer
              ? Icons.timer_rounded
              : Icons.timer_outlined,
          label: sleepLeft == null
              ? (playback.hasSleepTimer ? '定时中' : '定时')
              : Fmt.clock(sleepLeft),
          active: playback.hasSleepTimer,
          onTap: () => showSleepTimerSheet(context),
        ),
        _PlayerAction(
          icon: Icons.queue_music_rounded,
          label: '列表',
          onTap: () => showQueueSheet(context),
        ),
      ],
    );
  }
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = active ? palette.brand : Colors.white.withValues(alpha: 0.66);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: active ? palette.brand : color),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: color,
                fontSize: 10,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsPage extends StatelessWidget {
  const _LyricsPage({required this.playback, required this.onBack});

  final PlaybackController playback;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final lyric = playback.lyric;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 2, 20, 4),
          child: Row(
            children: [
              if (lyric != null && lyric.synced)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '逐行同步',
                        style: AppText.caption.copyWith(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (lyric != null && (lyric.source ?? '').isNotEmpty) ...[
                Text(
                  '· ${lyric.source}',
                  style: AppText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: () => showLyricOffsetSheet(context),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('校准'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.6),
                  textStyle: AppText.caption,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LyricView(
            lyric: lyric,
            currentIndex: playback.lyricLine,
            loading: playback.lyricLoading,
            error: playback.lyricError,
            onSeek: playback.seekToLyric,
            onRetry: playback.reloadLyric,
          ),
        ),
        _CompactTransport(playback: playback),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CompactTransport extends StatelessWidget {
  const _CompactTransport({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ValueListenableBuilder<Duration>(
            valueListenable: playback.position,
            builder: (context, position, _) {
              final total = playback.duration.inMilliseconds;
              final value = total <= 0
                  ? 0.0
                  : (position.inMilliseconds / total).clamp(0.0, 1.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: Icons.skip_previous_rounded,
              size: 28,
              color: Colors.white.withValues(alpha: 0.85),
              onTap: () => playback.previous(),
            ),
            const SizedBox(width: 12),
            _PlayButton(playback: playback),
            const SizedBox(width: 12),
            _ControlButton(
              icon: Icons.skip_next_rounded,
              size: 28,
              color: Colors.white.withValues(alpha: 0.85),
              onTap: () => playback.next(),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              icon: Icons.queue_music_rounded,
              size: 21,
              color: Colors.white.withValues(alpha: 0.6),
              onTap: () => showQueueSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.song});
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<SourceRegistry>();
    final coverUrl = song == null
        ? null
        : registry.coverUrl(song!.coverArtId, size: 900);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
              child: Transform.scale(
                scale: 1.35,
                child: CoverImage(
                  coverArtId: song!.coverArtId,
                  songId: song!.id,
                  size: null,
                  radius: 0,
                  album: song!.displayAlbum,
                  artist: song!.displayArtist,
                  title: song!.title,
                ),
              ),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.9),
                radius: 1.25,
                colors: [
                  Color(0xFF6E2029),
                  Color(0xFF2A1418),
                  Color(0xFF0C0C10),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.58),
                const Color(0xFF0C0C10).withValues(alpha: 0.94),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
