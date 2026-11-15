import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_presets.dart';
import 'core/theme/app_theme.dart';
import 'data/local/download_manager.dart';
import 'data/local/favorites_store.dart';
import 'data/local/settings_store.dart';
import 'data/repositories/library_repository.dart';
import 'data/sources/source_registry.dart';
import 'data/update/update_service.dart';
import 'playback/dlna_controller.dart';
import 'playback/playback_controller.dart';
import 'ui/home_shell.dart';

class YingHuaApp extends StatelessWidget {
  const YingHuaApp({
    super.key,
    required this.settings,
    required this.registry,
    required this.downloads,
    required this.favorites,
    required this.library,
    required this.playback,
  });

  final SettingsStore settings;
  final SourceRegistry registry;
  final DownloadManager downloads;
  final FavoritesStore favorites;
  final LibraryRepository library;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<SourceRegistry>.value(value: registry),
        ChangeNotifierProvider<DownloadManager>.value(value: downloads),
        ChangeNotifierProvider<FavoritesStore>.value(value: favorites),
        Provider<LibraryRepository>.value(value: library),
        Provider<UpdateService>(
          create: (_) => UpdateService(settings: settings),
        ),
        ChangeNotifierProvider<PlaybackController>.value(value: playback),
        ChangeNotifierProvider<DlnaController>(
          create: (_) => DlnaController(playback: playback, registry: registry),
        ),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: settings.themeMode == ThemeMode.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: MaterialApp(
              title: '莺花',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(AppPresets.byId(settings.themePreset)),
              darkTheme: AppTheme.dark(AppPresets.byId(settings.themePreset)),
              themeMode: settings.themeMode,
              themeAnimationDuration: const Duration(milliseconds: 240),
              themeAnimationCurve: Curves.easeOutCubic,
              color: AppPresets.byId(settings.themePreset).brand,
              home: const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}
