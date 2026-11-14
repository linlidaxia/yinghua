import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/local/background_guard.dart';
import 'data/local/download_manager.dart';
import 'data/local/favorites_store.dart';
import 'data/local/settings_store.dart';
import 'data/repositories/library_repository.dart';
import 'data/sources/source_registry.dart';
import 'playback/playback_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final settings = SettingsStore();
  await settings.init();

  final registry = SourceRegistry(settings);
  await registry.init();

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

  if (registry.hasSource) {
    unawaited(favorites.refresh());
  }

  // Android 13+ 需要通知权限，否则媒体通知与前台服务不可见。
  unawaited(BackgroundGuard.requestNotifications());

  runApp(
    YingHuaApp(
      settings: settings,
      registry: registry,
      downloads: downloads,
      favorites: favorites,
      library: library,
      playback: playback,
    ),
  );
}
