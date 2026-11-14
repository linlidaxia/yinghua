import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../playback/playback_controller.dart';
import 'mini_player.dart';

/// 详情页底部的迷你播放条。
///
/// 歌单 / 专辑 / 歌手等页面是独立路由，不在 HomeShell 的 Tab 容器里，
/// 需要自己挂一条，点了播放之后就能直接看到控制栏。
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSong = context.select<PlaybackController, bool>(
      (playback) => playback.current != null,
    );
    if (!hasSong) return const SizedBox.shrink();
    return const SafeArea(top: false, child: MiniPlayer());
  }
}
