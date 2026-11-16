import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_models.dart';
import '../models/playlist_progress.dart';
import '../models/skip_config.dart';

/// 首页模块定义，供「首页自定义」与渲染共用。
class HomeSection {
  const HomeSection(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

const kHomeSections = <HomeSection>[
  HomeSection('quick', '快捷入口', '随机播放、最近播放、文件夹与下载'),
  HomeSection('recommend', '为你推荐', '常听专辑，横向大图卡片'),
  HomeSection('playlists', '精选歌单', '服务器上的公开歌单'),
  HomeSection('newest', '最近添加', '音乐库里最新入库的专辑'),
  HomeSection('recent', '最近播放', '本机播放记录'),
];

/// 全部本地偏好设置。不包含任何会员 / 付费 / 权限校验字段。
class SettingsStore extends ChangeNotifier {
  SettingsStore();

  static const _kTheme = 'theme_mode';
  static const _kThemePreset = 'theme_preset';
  static const _kCache = 'cache_enabled';
  static const _kReplayGain = 'replay_gain';
  static const _kOnlineLyrics = 'online_lyrics';
  static const _kFloatingLyric = 'floating_lyric';
  static const _kMaxBitRate = 'max_bit_rate';
  static const _kVolume = 'user_volume';
  static const _kHomeOrder = 'home_order';
  static const _kHomeHidden = 'home_hidden';
  static const _kRecentSongs = 'recent_songs';
  static const _kRecentSearches = 'recent_searches';
  static const _kServers = 'servers_v1';
  static const _kActiveServer = 'active_server';
  static const _kOnboarded = 'onboarded';
  static const _kCoverSource = 'cover_source';
  static const _kCoverApiUrl = 'cover_api_url';
  static const _kLyricsApiUrl = 'lyrics_api_url';
  static const _kAutoUpdateCheck = 'auto_update_check';
  static const _kUpdateRepo = 'update_repo';
  static const _kSkippedUpdate = 'skipped_update_version';
  static const _kUpdateMirror = 'update_use_mirror';
  static const _kUpdateSource = 'update_source';
  static const _kUpdateManifestUrl = 'update_manifest_url';
  static const _kPlaylistSkips = 'playlist_skips';
  static const _kPlaylistProgress = 'playlist_progress';
  static const _kSongLyricOffsets = 'lyric_offsets_song';
  static const _kPlaylistLyricOffsets = 'lyric_offsets_playlist';

  SharedPreferences? _prefs;
  bool _ready = false;

  ThemeMode themeMode = ThemeMode.system;

  /// 主题皮肤 id（见 core/theme/app_presets.dart）。
  String themePreset = 'yinghua';
  bool cacheEnabled = true;
  bool replayGainEnabled = true;
  bool onlineLyricsEnabled = true;

  /// 封面来源：`server`（服务器 getCoverArt）或 `custom`（自定义接口）。
  String coverSource = 'server';
  String coverApiUrl = '';

  /// 自定义歌词接口，空字符串表示不使用。
  String lyricsApiUrl = '';

  /// 启动时自动检查 GitHub 最新 Release。
  bool autoUpdateCheck = true;

  /// 更新源仓库（`owner/repo`），需要是公开仓库。
  String updateRepo = 'linlidaxia/yinghua';

  /// 用户在自动弹窗里点「稍后」的版本，避免每次启动都弹同一个版本。
  String skippedUpdateVersion = '';

  /// GitHub 下载慢或不可达时，经公共加速镜像下载 APK。
  bool updateUseMirror = true;

  /// 更新源：`github`（公开 Release）或 `manifest`（自建 JSON 清单，例如 NAS）。
  String updateSource = 'github';

  /// 自建更新清单地址，指向返回版本信息的 JSON。
  String updateManifestUrl = '';

  /// 歌单 id → 跳过头尾配置。
  final Map<String, SkipConfig> playlistSkips = {};

  /// 歌单 id → 上次播放进度（最后歌曲 + 位置）。
  final Map<String, PlaylistProgress> playlistProgress = {};
  bool floatingLyricEnabled = false;
  int maxBitRate = 0;

  /// 歌词校准的最大偏移（±2 分钟）。有声书 / 广播剧的偏差可能到分钟级。
  static const int lyricOffsetLimitMs = 120000;

  /// 歌曲 id → 该曲目的歌词偏移（优先级最高）。
  final Map<String, int> songLyricOffsets = {};

  /// 歌单 id → 该歌单全部曲目的歌词偏移（歌曲没有单独设置时生效）。
  final Map<String, int> playlistLyricOffsets = {};

  double userVolume = 1.0;
  bool onboarded = false;

  List<String> homeOrder = kHomeSections.map((e) => e.id).toList();
  final Set<String> homeHidden = {};

  List<Song> recentSongs = [];
  List<String> recentSearches = [];

  bool get isReady => _ready;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    themeMode = switch (prefs.getString(_kTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    cacheEnabled = prefs.getBool(_kCache) ?? true;
    replayGainEnabled = prefs.getBool(_kReplayGain) ?? true;
    onlineLyricsEnabled = prefs.getBool(_kOnlineLyrics) ?? true;
    floatingLyricEnabled = prefs.getBool(_kFloatingLyric) ?? false;
    maxBitRate = prefs.getInt(_kMaxBitRate) ?? 0;
    songLyricOffsets
      ..clear()
      ..addAll(_decodeOffsets(prefs.getString(_kSongLyricOffsets)));
    playlistLyricOffsets
      ..clear()
      ..addAll(_decodeOffsets(prefs.getString(_kPlaylistLyricOffsets)));
    userVolume = (prefs.getDouble(_kVolume) ?? 1.0).clamp(0.0, 1.0);
    onboarded = prefs.getBool(_kOnboarded) ?? false;
    themePreset = prefs.getString(_kThemePreset) ?? 'yinghua';
    coverSource = prefs.getString(_kCoverSource) ?? 'server';
    coverApiUrl = prefs.getString(_kCoverApiUrl) ?? '';
    lyricsApiUrl = prefs.getString(_kLyricsApiUrl) ?? '';
    autoUpdateCheck = prefs.getBool(_kAutoUpdateCheck) ?? true;
    updateRepo = prefs.getString(_kUpdateRepo) ?? 'linlidaxia/yinghua';
    skippedUpdateVersion = prefs.getString(_kSkippedUpdate) ?? '';
    updateUseMirror = prefs.getBool(_kUpdateMirror) ?? true;
    updateSource = prefs.getString(_kUpdateSource) ?? 'github';
    updateManifestUrl = prefs.getString(_kUpdateManifestUrl) ?? '';
    playlistSkips
      ..clear()
      ..addAll(_decodeSkips(prefs.getString(_kPlaylistSkips)));
    playlistProgress
      ..clear()
      ..addAll(_decodeProgress(prefs.getString(_kPlaylistProgress)));
    final order = prefs.getStringList(_kHomeOrder);
    if (order != null && order.isNotEmpty) {
      final known = kHomeSections.map((e) => e.id).toSet();
      homeOrder = [
        ...order.where(known.contains),
        ...known.where((id) => !order.contains(id)),
      ];
    }
    homeHidden
      ..clear()
      ..addAll(prefs.getStringList(_kHomeHidden) ?? const []);
    recentSongs = Song.listFromJson(prefs.getString(_kRecentSongs));
    recentSearches = List<String>.of(
      prefs.getStringList(_kRecentSearches) ?? const <String>[],
    );
    _ready = true;
  }

  String get serversRaw => _prefs?.getString(_kServers) ?? '';
  String? get activeServerRaw => _prefs?.getString(_kActiveServer);

  Future<void> saveServers(String raw, String activeId) async {
    await _prefs?.setString(_kServers, raw);
    await _prefs?.setString(_kActiveServer, activeId);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_kTheme, mode.name);
  }

  Future<void> setThemePreset(String id) async {
    themePreset = id;
    notifyListeners();
    await _prefs?.setString(_kThemePreset, id);
  }

  Future<void> setCacheEnabled(bool value) async {
    cacheEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kCache, value);
  }

  Future<void> setReplayGain(bool value) async {
    replayGainEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kReplayGain, value);
  }

  Future<void> setOnlineLyrics(bool value) async {
    onlineLyricsEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kOnlineLyrics, value);
  }

  Future<void> setCoverSource(String value) async {
    coverSource = value == 'custom' ? 'custom' : 'server';
    notifyListeners();
    await _prefs?.setString(_kCoverSource, coverSource);
  }

  Future<void> setCoverApiUrl(String value) async {
    coverApiUrl = value.trim();
    notifyListeners();
    await _prefs?.setString(_kCoverApiUrl, coverApiUrl);
  }

  Future<void> setLyricsApiUrl(String value) async {
    lyricsApiUrl = value.trim();
    notifyListeners();
    await _prefs?.setString(_kLyricsApiUrl, lyricsApiUrl);
  }

  // ---------------------------------------------------------------------------
  // 应用更新
  // ---------------------------------------------------------------------------

  Future<void> setAutoUpdateCheck(bool value) async {
    autoUpdateCheck = value;
    notifyListeners();
    await _prefs?.setBool(_kAutoUpdateCheck, value);
  }

  Future<void> setUpdateRepo(String value) async {
    final repo = value.trim().replaceAll(RegExp(r'^https?://'), '');
    updateRepo = repo.isEmpty ? 'linlidaxia/yinghua' : repo;
    notifyListeners();
    await _prefs?.setString(_kUpdateRepo, updateRepo);
  }

  /// 自动弹窗里点「稍后」时记住该版本，下次启动不再重复打扰。
  Future<void> skipUpdateVersion(String version) async {
    skippedUpdateVersion = version;
    notifyListeners();
    await _prefs?.setString(_kSkippedUpdate, version);
  }

  Future<void> clearSkippedUpdate() async {
    if (skippedUpdateVersion.isEmpty) return;
    skippedUpdateVersion = '';
    notifyListeners();
    await _prefs?.remove(_kSkippedUpdate);
  }

  Future<void> setUpdateUseMirror(bool value) async {
    updateUseMirror = value;
    notifyListeners();
    await _prefs?.setBool(_kUpdateMirror, value);
  }

  Future<void> setUpdateSource(String value) async {
    updateSource = value == 'manifest' ? 'manifest' : 'github';
    notifyListeners();
    await _prefs?.setString(_kUpdateSource, updateSource);
  }

  Future<void> setUpdateManifestUrl(String value) async {
    updateManifestUrl = value.trim();
    notifyListeners();
    await _prefs?.setString(_kUpdateManifestUrl, updateManifestUrl);
  }

  // ---------------------------------------------------------------------------
  // 歌单跳过头尾
  // ---------------------------------------------------------------------------

  static Map<String, SkipConfig> _decodeSkips(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final result = <String, SkipConfig>{};
      data.forEach((key, value) {
        if (value is Map) {
          result['$key'] = SkipConfig.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  SkipConfig? skipFor(String? playlistId) {
    if (playlistId == null || playlistId.isEmpty) return null;
    return playlistSkips[playlistId];
  }

  Future<void> setPlaylistSkip(String playlistId, SkipConfig config) async {
    if (config.intro == Duration.zero && config.outro == Duration.zero) {
      playlistSkips.remove(playlistId);
    } else {
      playlistSkips[playlistId] = config;
    }
    notifyListeners();
    await _prefs?.setString(
      _kPlaylistSkips,
      jsonEncode(playlistSkips.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> clearPlaylistSkip(String playlistId) async {
    playlistSkips.remove(playlistId);
    notifyListeners();
    await _prefs?.setString(
      _kPlaylistSkips,
      jsonEncode(playlistSkips.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  // ---------------------------------------------------------------------------
  // 歌单播放进度
  // ---------------------------------------------------------------------------

  static Map<String, PlaylistProgress> _decodeProgress(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final result = <String, PlaylistProgress>{};
      data.forEach((key, value) {
        if (value is Map) {
          final progress = PlaylistProgress.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (progress != null) result['$key'] = progress;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  PlaylistProgress? progressForPlaylist(String? playlistId) {
    if (playlistId == null || playlistId.isEmpty) return null;
    return playlistProgress[playlistId];
  }

  /// 播放中会高频调用，默认不 notify，避免整页每秒重建；
  /// 暂停 / 切歌这类关键时刻传 `notify: true`，让歌单页立即刷新「继续播放」。
  Future<void> savePlaylistProgress(
    String playlistId,
    PlaylistProgress progress, {
    bool notify = false,
  }) async {
    if (playlistId.isEmpty) return;
    playlistProgress[playlistId] = progress;
    await _prefs?.setString(
      _kPlaylistProgress,
      jsonEncode(playlistProgress.map((k, v) => MapEntry(k, v.toJson()))),
    );
    if (notify) notifyListeners();
  }

  Future<void> clearPlaylistProgress(String playlistId) async {
    if (playlistProgress.remove(playlistId) == null) return;
    notifyListeners();
    await _prefs?.setString(
      _kPlaylistProgress,
      jsonEncode(playlistProgress.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> setFloatingLyric(bool value) async {
    floatingLyricEnabled = value;
    notifyListeners();
    await _prefs?.setBool(_kFloatingLyric, value);
  }

  Future<void> setMaxBitRate(int value) async {
    maxBitRate = value;
    notifyListeners();
    await _prefs?.setInt(_kMaxBitRate, value);
  }

  // ---------------------------------------------------------------------------
  // 歌词校准（按歌曲 / 按歌单，默认只影响当前歌曲）
  // ---------------------------------------------------------------------------

  static Map<String, int> _decodeOffsets(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final result = <String, int>{};
      data.forEach((key, value) {
        if (value is num) {
          result['$key'] = value.toInt().clamp(
            -lyricOffsetLimitMs,
            lyricOffsetLimitMs,
          );
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveOffsets(String key, Map<String, int> values) async {
    await _prefs?.setString(key, jsonEncode(values));
  }

  int? lyricOffsetForSong(String? songId) {
    if (songId == null || songId.isEmpty) return null;
    return songLyricOffsets[songId];
  }

  int? lyricOffsetForPlaylist(String? playlistId) {
    if (playlistId == null || playlistId.isEmpty) return null;
    return playlistLyricOffsets[playlistId];
  }

  Future<void> setSongLyricOffset(String songId, int value) async {
    if (songId.isEmpty) return;
    songLyricOffsets[songId] = value.clamp(
      -lyricOffsetLimitMs,
      lyricOffsetLimitMs,
    );
    notifyListeners();
    await _saveOffsets(_kSongLyricOffsets, songLyricOffsets);
  }

  Future<void> clearSongLyricOffset(String songId) async {
    if (songLyricOffsets.remove(songId) == null) return;
    notifyListeners();
    await _saveOffsets(_kSongLyricOffsets, songLyricOffsets);
  }

  Future<void> setPlaylistLyricOffset(String playlistId, int value) async {
    if (playlistId.isEmpty) return;
    playlistLyricOffsets[playlistId] = value.clamp(
      -lyricOffsetLimitMs,
      lyricOffsetLimitMs,
    );
    notifyListeners();
    await _saveOffsets(_kPlaylistLyricOffsets, playlistLyricOffsets);
  }

  Future<void> clearPlaylistLyricOffset(String playlistId) async {
    if (playlistLyricOffsets.remove(playlistId) == null) return;
    notifyListeners();
    await _saveOffsets(_kPlaylistLyricOffsets, playlistLyricOffsets);
  }

  Future<void> setUserVolume(double value) async {
    userVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await _prefs?.setDouble(_kVolume, userVolume);
  }

  Future<void> setOnboarded(bool value) async {
    onboarded = value;
    notifyListeners();
    await _prefs?.setBool(_kOnboarded, value);
  }

  List<String> get visibleHomeSections =>
      homeOrder.where((id) => !homeHidden.contains(id)).toList();

  Future<void> moveHomeSection(String id, int delta) async {
    final index = homeOrder.indexOf(id);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= homeOrder.length) return;
    final item = homeOrder.removeAt(index);
    homeOrder.insert(target, item);
    notifyListeners();
    await _prefs?.setStringList(_kHomeOrder, homeOrder);
  }

  Future<void> reorderHomeSections(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= homeOrder.length) return;
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = homeOrder.removeAt(oldIndex);
    homeOrder.insert(adjusted.clamp(0, homeOrder.length), item);
    notifyListeners();
    await _prefs?.setStringList(_kHomeOrder, homeOrder);
  }

  Future<void> toggleHomeSection(String id) async {
    if (homeHidden.contains(id)) {
      homeHidden.remove(id);
    } else {
      // 至少保留一个模块，避免首页空白。
      if (visibleHomeSections.length <= 1) return;
      homeHidden.add(id);
    }
    notifyListeners();
    await _prefs?.setStringList(_kHomeHidden, homeHidden.toList());
  }

  Future<void> resetHomeSections() async {
    homeOrder = kHomeSections.map((e) => e.id).toList();
    homeHidden.clear();
    notifyListeners();
    await _prefs?.setStringList(_kHomeOrder, homeOrder);
    await _prefs?.setStringList(_kHomeHidden, const []);
  }

  Future<void> recordPlayed(Song song) async {
    // 防御式拷贝，避免上游给了不可变列表时崩溃（曾导致最近播放一直为空）。
    recentSongs = List<Song>.of(recentSongs)
      ..removeWhere((e) => e.id == song.id);
    recentSongs.insert(0, song);
    if (recentSongs.length > 50) {
      recentSongs = recentSongs.sublist(0, 50);
    }
    notifyListeners();
    await _prefs?.setString(
      _kRecentSongs,
      jsonEncode(recentSongs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearRecentSongs() async {
    recentSongs = [];
    notifyListeners();
    await _prefs?.remove(_kRecentSongs);
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    recentSearches = List<String>.of(recentSearches)..remove(q);
    recentSearches.insert(0, q);
    if (recentSearches.length > 12) {
      recentSearches = recentSearches.sublist(0, 12);
    }
    notifyListeners();
    await _prefs?.setStringList(_kRecentSearches, recentSearches);
  }

  Future<void> clearRecentSearches() async {
    recentSearches = [];
    notifyListeners();
    await _prefs?.remove(_kRecentSearches);
  }
}
