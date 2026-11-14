// 截图专用入口（仅供文档与设计评审使用，不参与 APK 构建）。
//
// 用法：
//   flutter build web -t tool/screenshots/main.dart --output build/web_shots
//   http://127.0.0.1:8123/index.html?shot=home | player | lyrics
//
// 它复用正式 App 的 Provider 装配、主题、页面与演示资料库，只是把首页
// 换成指定的目标页面，方便在无模拟器的环境里生成 390 x 844 的界面截图。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yinghua/core/theme/app_presets.dart';
import 'package:yinghua/core/theme/app_theme.dart';
import 'package:yinghua/data/local/download_manager.dart';
import 'package:yinghua/data/local/favorites_store.dart';
import 'package:yinghua/data/local/settings_store.dart';
import 'package:yinghua/data/repositories/library_repository.dart';
import 'package:yinghua/data/sources/music_source.dart';
import 'package:yinghua/data/sources/source_registry.dart';
import 'package:yinghua/playback/dlna_controller.dart';
import 'package:yinghua/playback/playback_controller.dart';
import 'package:yinghua/ui/home_shell.dart';
import 'package:yinghua/ui/pages/folder_page.dart';
import 'package:yinghua/ui/pages/player_page.dart';
import 'package:yinghua/ui/pages/playlist_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final query = Uri.base.queryParameters;
  final shot = query['shot'] ?? 'home';
  final preset = AppPresets.byId(query['preset']);

  final settings = SettingsStore();
  await settings.init();
  await settings.setThemeMode(ThemeMode.light);
  await settings.setThemePreset(preset.id);

  // 自定义封面接口（截图验证用）：?cover=<url-template>
  final cover = query['cover'];
  if (cover != null && cover.isNotEmpty) {
    await settings.setCoverApiUrl(cover);
    await settings.setCoverSource('custom');
  }

  final registry = SourceRegistry(settings);
  await registry.init();
  if (!registry.isDemo) {
    await registry.addDemo();
  }

  final downloads = DownloadManager(settings);
  await downloads.init();

  final favorites = FavoritesStore(registry);
  final library = LibraryRepository(registry);
  final playback = PlaybackController(
    settings: settings,
    registry: registry,
    downloads: downloads,
    favorites: favorites,
    library: library,
  );
  await playback.init();

  // 载入一张演示专辑，让迷你播放条与播放页都有内容。
  try {
    final detail = await library.album('demo-album-2');
    if (detail.songs.isNotEmpty) {
      await playback.playSongs(detail.songs, title: detail.album.name);
      // 先暂停；等歌词就绪后定位到演示音轨的三分之一处，进度条更自然。
      await playback.pause();
      for (var i = 0; i < 40; i++) {
        if (playback.lyric != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await playback.seek(const Duration(seconds: 12));
      await playback.pause();
      // 截图时暂停，避免进度条在等待渲染期间继续前进。
      await playback.pause();
    }
  } catch (error) {
    debugPrint('演示歌曲加载失败: $error');
  }

  final home = switch (shot) {
    'player' => const PlayerPage(),
    'lyrics' => const PlayerPage(initialPage: 1),
    'folders' => const FolderPage(),
    'playlist' => const PlaylistPage(playlistId: 'demo-playlist-0'),
    'index' => const FolderPage(
        folderId: MusicSource.indexesFolderId,
        title: '按歌手浏览',
      ),
    _ => const HomeShell(),
  };

  runApp(
    _ShotApp(
      settings: settings,
      registry: registry,
      downloads: downloads,
      favorites: favorites,
      library: library,
      playback: playback,
      preset: preset,
      home: home,
    ),
  );
}

class _ShotApp extends StatelessWidget {
  const _ShotApp({
    required this.settings,
    required this.registry,
    required this.downloads,
    required this.favorites,
    required this.library,
    required this.playback,
    required this.preset,
    required this.home,
  });

  final SettingsStore settings;
  final SourceRegistry registry;
  final DownloadManager downloads;
  final FavoritesStore favorites;
  final LibraryRepository library;
  final PlaybackController playback;
  final AppThemePreset preset;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<SourceRegistry>.value(value: registry),
        ChangeNotifierProvider<DownloadManager>.value(value: downloads),
        ChangeNotifierProvider<FavoritesStore>.value(value: favorites),
        Provider<LibraryRepository>.value(value: library),
        ChangeNotifierProvider<PlaybackController>.value(value: playback),
        ChangeNotifierProvider<DlnaController>(
          create: (_) =>
              DlnaController(playback: playback, registry: registry),
        ),
      ],
      child: MaterialApp(
        title: '莺花',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(preset),
        darkTheme: AppTheme.dark(preset),
        themeMode: ThemeMode.light,
        home: home,
      ),
    );
  }
}
