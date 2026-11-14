import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library_models.dart';
import 'common.dart';
import 'cover_image.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.showCover = false,
    this.dense = false,
    this.highlight = false,
    this.playing = false,
    this.onTap,
    this.onMore,
    this.trailing,
    this.subtitle,
  });

  final Song song;
  final int? index;
  final bool showCover;
  final bool dense;
  final bool highlight;
  final bool playing;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final secondary = subtitle ?? song.displayArtist;

    Widget leading;
    if (highlight && playing) {
      leading = const SizedBox(
        width: 26,
        child: Center(child: _EqualizerBars()),
      );
    } else if (index != null && !showCover) {
      leading = SizedBox(
        width: 26,
        child: Text(
          '${index! + 1}'.padLeft(2, '0'),
          textAlign: TextAlign.center,
          style: AppText.numeric.copyWith(
            color: palette.textTertiary,
            fontSize: 12,
          ),
        ),
      );
    } else if (showCover) {
      leading = CoverImage(
        coverArtId: song.coverArtId,
        songId: song.id,
        size: dense ? 40 : 46,
        radius: 10,
        album: song.displayAlbum,
        artist: song.displayArtist,
        title: song.title,
      );
    } else {
      leading = const SizedBox(width: 4);
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpace.page,
          vertical: dense ? 8 : 9,
        ),
        child: Row(
          children: [
            leading,
            SizedBox(width: showCover ? 12 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSm.copyWith(
                            color: highlight
                                ? palette.brand
                                : palette.textPrimary,
                            fontWeight: highlight
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (song.isLossless) ...[
                        const SizedBox(width: 6),
                        const TagBadge('无损', color: AppColors.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else ...[
              Text(
                Fmt.duration(song.duration),
                style: AppText.numeric.copyWith(color: palette.textTertiary),
              ),
              if (onMore != null)
                GestureDetector(
                  onTap: onMore,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: palette.textTertiary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = AppPalette.of(context).brand;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(6 + 8 * t, brand),
            _bar(13 - 7 * t, brand),
            _bar(8 + 5 * (1 - t), brand),
          ],
        );
      },
    );
  }

  Widget _bar(double height, Color color) => Container(
    width: 2.6,
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: 1.2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
