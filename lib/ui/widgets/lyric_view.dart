import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/lyric.dart';

/// 逐行歌词：当前行高亮并自动居中；用户主动滚动时暂停跟随 4 秒。
class LyricView extends StatefulWidget {
  const LyricView({
    super.key,
    required this.lyric,
    required this.currentIndex,
    required this.loading,
    required this.onSeek,
    required this.onRetry,
    this.error,
  });

  final Lyric? lyric;
  final ValueNotifier<int> currentIndex;
  final bool loading;
  final ValueChanged<int> onSeek;
  final VoidCallback onRetry;
  final String? error;

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  static const _itemExtent = 66.0;
  final ScrollController _scroll = ScrollController();
  int _lastIndex = -2;
  DateTime _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.currentIndex.addListener(_onIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(widget.currentIndex.value, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      oldWidget.currentIndex.removeListener(_onIndexChanged);
      widget.currentIndex.addListener(_onIndexChanged);
    }
    if (oldWidget.lyric != widget.lyric) {
      _lastIndex = -2;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollTo(0, animate: false),
      );
    }
  }

  @override
  void dispose() {
    widget.currentIndex.removeListener(_onIndexChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onIndexChanged() {
    final index = widget.currentIndex.value;
    if (index == _lastIndex) return;
    _lastIndex = index;
    if (DateTime.now().isBefore(_holdUntil)) return;
    _scrollTo(index);
  }

  void _scrollTo(int index, {bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = (index.clamp(0, 9999) * _itemExtent).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (!animate) {
      _scroll.jumpTo(target);
      return;
    }
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyric = widget.lyric;
    if (widget.loading) return const _LyricSkeleton();
    if (lyric == null || lyric.isEmpty) {
      return _LyricEmpty(error: widget.error, onRetry: widget.onRetry);
    }

    final lines = lyric.lines;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxHeight / 2 - _itemExtent / 2;
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _holdUntil = DateTime.now().add(const Duration(seconds: 4));
            }
            return false;
          },
          child: ValueListenableBuilder<int>(
            valueListenable: widget.currentIndex,
            builder: (context, activeIndex, _) {
              return ListView.builder(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.only(top: half, bottom: half),
                itemExtent: _itemExtent,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final active = lyric.synced && index == activeIndex;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: lyric.synced ? () => widget.onSeek(index) : null,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        style: active
                            ? AppText.lyricActive.copyWith(
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: AppPalette.of(context).brand
                                        .withValues(alpha: 0.45),
                                    blurRadius: 18,
                                  ),
                                ],
                              )
                            : AppText.lyric.copyWith(
                                color: Colors.white.withValues(alpha: 0.46),
                              ),
                        textAlign: TextAlign.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: Text(
                            line.text.isEmpty ? '♪' : line.text,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LyricSkeleton extends StatelessWidget {
  const _LyricSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final width in [0.62, 0.78, 0.5, 0.7, 0.44])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LyricEmpty extends StatelessWidget {
  const _LyricEmpty({this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                Icons.lyrics_outlined,
                size: 32,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '这首歌还没有歌词',
              style: AppText.title.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error == null ? '音乐服务器未提供歌词，或歌词尚未收录' : '歌词获取失败，请检查网络后重试',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text('重新获取'),
            ),
          ],
        ),
      ),
    );
  }
}
