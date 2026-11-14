import 'package:flutter/foundation.dart';

import '../../core/utils/url_template.dart';
import '../local/settings_store.dart';
import '../models/server_config.dart';
import '../sources/demo_source.dart';
import '../sources/music_source.dart';
import '../sources/subsonic_source.dart';

/// 多服务器管理与音乐源构建。
///
/// UI 只依赖 [source]；协议差异被收敛在 MusicSource 实现内部。
class SourceRegistry extends ChangeNotifier {
  SourceRegistry(this._settings) {
    _settings.addListener(_onSettingsChanged);
    _coverKey = _coverSettingsKey();
  }

  final SettingsStore _settings;
  final List<ServerConfig> _servers = [];
  String? _activeId;
  MusicSource? _source;
  bool _initialized = false;
  String? _coverKey;

  /// 封面配置变化时要让所有 CoverImage 重新取地址。
  String _coverSettingsKey() =>
      '${_settings.coverSource}|${_settings.coverApiUrl}';

  void _onSettingsChanged() {
    final key = _coverSettingsKey();
    if (key == _coverKey) return;
    _coverKey = key;
    notifyListeners();
  }

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  String? get activeId => _activeId;
  MusicSource? get source => _source;
  bool get ready => _initialized;
  bool get hasSource => _source != null;
  bool get isDemo => active?.type == 'demo';

  ServerConfig? get active {
    if (_activeId == null) return null;
    for (final server in _servers) {
      if (server.id == _activeId) return server;
    }
    return null;
  }

  Future<void> init() async {
    _servers
      ..clear()
      ..addAll(ServerConfig.decodeList(_settings.serversRaw));
    _activeId = _settings.activeServerRaw;
    if (_activeId != null && !_servers.any((e) => e.id == _activeId)) {
      _activeId = _servers.isEmpty ? null : _servers.first.id;
    }
    _source = _buildSource(active);
    _initialized = true;
    notifyListeners();
  }

  MusicSource? _buildSource(ServerConfig? config) {
    if (config == null) return null;
    switch (config.type) {
      case 'demo':
        return DemoSource(config)..seedStarred();
      case 'subsonic':
      default:
        return SubsonicSource(config);
    }
  }

  Future<void> addServer(ServerConfig config, {bool activate = true}) async {
    _servers.removeWhere((e) => e.id == config.id);
    _servers.add(config);
    if (activate || _activeId == null) {
      _activeId = config.id;
    }
    await _rebuildAndPersist();
  }

  Future<void> addDemo() async {
    final existing = _servers.where((e) => e.type == 'demo').toList();
    if (existing.isNotEmpty) {
      await activate(existing.first.id);
      return;
    }
    const config = ServerConfig(
      id: 'demo-library',
      type: 'demo',
      name: '演示资料库',
      baseUrl: 'demo://yinghua',
      username: 'demo',
      createdAt: null,
    );
    await addServer(config);
  }

  Future<void> activate(String id) async {
    if (!_servers.any((e) => e.id == id)) return;
    _activeId = id;
    await _rebuildAndPersist();
  }

  Future<void> updateServer(ServerConfig config) async {
    final index = _servers.indexWhere((e) => e.id == config.id);
    if (index < 0) {
      await addServer(config);
      return;
    }
    _servers[index] = config;
    if (_activeId == config.id) {
      _source = _buildSource(config);
    }
    await _rebuildAndPersist();
  }

  Future<void> removeServer(String id) async {
    final wasActive = _activeId == id;
    _servers.removeWhere((e) => e.id == id);
    if (wasActive) {
      _activeId = _servers.isEmpty ? null : _servers.first.id;
    }
    await _rebuildAndPersist();
  }

  Future<void> _rebuildAndPersist() async {
    _source = _buildSource(active);
    notifyListeners();
    await _settings.saveServers(
      ServerConfig.encodeList(_servers),
      _activeId ?? '',
    );
  }

  /// 仅走服务器封面（自定义接口失败时的兜底）。
  String? serverCoverUrl(String? coverArtId, {int size = 360}) {
    final src = _source;
    if (src == null || coverArtId == null || coverArtId.isEmpty) return null;
    return src.coverUri(coverArtId, size: size)?.toString();
  }

  /// 封面地址。优先使用「自定义封面接口」，否则走服务器 getCoverArt；
  /// 演示资料库与缺失封面返回 null，由 UI 绘制占位艺术图。
  String? coverUrl(
    String? coverArtId, {
    int size = 360,
    String? album,
    String? artist,
    String? title,
  }) {
    if (_settings.coverSource == 'custom') {
      // 模板里的占位符全为空时不发请求，直接回退服务器封面。
      final hasValue = [
        coverArtId,
        album,
        artist,
        title,
      ].any((value) => (value ?? '').trim().isNotEmpty);
      if (hasValue) {
        final url = UrlTemplate.expand(_settings.coverApiUrl, {
          'id': coverArtId ?? '',
          'size': '$size',
          'album': album ?? '',
          'artist': artist ?? '',
          'title': title ?? '',
        });
        if (url != null) return url;
      }
    }
    final src = _source;
    if (src == null || coverArtId == null || coverArtId.isEmpty) return null;
    return src.coverUri(coverArtId, size: size)?.toString();
  }

  String get displayName {
    final config = active;
    if (config == null) return '未连接';
    return config.name;
  }

  String get protocolName => _source?.protocolLabel ?? '';

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @visibleForTesting
  void debugAddAll(List<ServerConfig> servers) {
    _servers.addAll(servers);
  }
}
