import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/library_models.dart';
import 'common.dart';
import 'cover_image.dart';

/// 通用「大图 + 标题」卡片，对应网易云首页歌单卡片的视觉比例。
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.coverArtId,
    this.songId,
    this.onTap,
    this.playLabel = '播放',
    this.onPlay,
    this.badge,
    this.width,
  });

  final String title;
  final String? subtitle;
  final String? coverArtId;
  final String? songId;
  final VoidCallback? onTap;
  final String playLabel;
  final VoidCallback? onPlay;
  final Widget? badge;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadow.card,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: CoverImage(
                  coverArtId: coverArtId,
                  songId: songId,
                  radius: AppRadius.lg,
                  size: null,
                  album: title,
                  artist: subtitle,
                  title: title,
                ),
              ),
            ),
            if (badge != null) Positioned(left: 8, top: 8, child: badge!),
            if (onPlay != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: _PlayBadge(onTap: onPlay!),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.titleSm.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: palette.textTertiary),
          ),
        ],
      ],
    );

    final content = onTap == null
        ? card
        : PressableScale(onTap: onTap, child: card);
    return width == null ? content : SizedBox(width: width, child: content);
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: 20,
          color: AppPalette.of(context).brand,
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    this.onTap,
    this.onPlay,
    this.width,
    this.subtitle,
  });

  final Album album;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double? width;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return MediaCard(
      title: album.name,
      subtitle: subtitle ?? album.displayArtist,
      coverArtId: album.coverArtId,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
      badge: album.starred ? TagBadge('喜欢', color: palette.brand) : null,
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.onPlay,
    this.width,
  });

  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      title: playlist.name,
      subtitle: playlist.meta,
      coverArtId: playlist.coverArtId,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
    );
  }
}

class ArtistRow extends StatelessWidget {
  const ArtistRow({super.key, required this.artist, this.onTap});

  final Artist artist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.page,
          vertical: 10,
        ),
        child: Row(
          children: [
            CoverImage(
              coverArtId: artist.coverArtId,
              seed: artist.id,
              size: 48,
              circle: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${artist.albumCount} 张专辑',
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
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
    );
  }
}
