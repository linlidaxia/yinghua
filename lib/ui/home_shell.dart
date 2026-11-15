import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local/settings_store.dart';
import '../playback/playback_controller.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/mine_page.dart';
import 'pages/search_page.dart';
import 'sheets/update_dialog.dart';
import 'widgets/app_nav_bar.dart';
import 'widgets/floating_lyric.dart';
import 'widgets/mini_player.dart';

/// 主框架：四个一级页面 + 常驻迷你播放条 + 可选悬浮歌词。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  /// 启动后自动检查 GitHub 最新版本；失败静默，不打扰使用。
  Future<void> _autoCheckUpdate() async {
    if (!mounted) return;
    final settings = context.read<SettingsStore>();
    if (!settings.autoUpdateCheck) return;
    // 等首屏与服务器请求稳定后再检测，避免抢带宽。
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await checkForUpdates(context);
  }

  void _openSearch() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final playback = context.watch<PlaybackController>();
    final hasSong = playback.current != null;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomePage(onOpenSearch: _openSearch),
                    const LibraryPage(),
                    const SearchPage(),
                    const MinePage(),
                  ],
                ),
              ),
              if (hasSong) const MiniPlayer(),
              AppNavBar(
                index: _index,
                onChanged: (index) => setState(() => _index = index),
              ),
            ],
          ),
          if (settings.floatingLyricEnabled && hasSong)
            const FloatingLyricOverlay(),
        ],
      ),
    );
  }
}
