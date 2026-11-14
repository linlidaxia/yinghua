import 'package:flutter/foundation.dart';

import '../models/library_models.dart';
import '../sources/source_registry.dart';

/// 收藏状态（我喜欢的音乐）。服务端为准，本地做乐观更新。
class FavoritesStore extends ChangeNotifier {
  FavoritesStore(this._registry) {
    _registry.addListener(_onSourceChanged);
    _serverId = _registry.activeId;
  }

  final SourceRegistry _registry;
  final Set<String> _songIds = {};
  final Set<String> _albumIds = {};
  List<Song> _songs = [];
  List<Album> _albums = [];
  bool _loading = false;
  String? _error;
  String? _serverId;

  bool get loading => _loading;
  String? get error => _error;
  List<Song> get songs => List.unmodifiable(_songs);
  List<Album> get albums => List.unmodifiable(_albums);
  int get songCount => _songs.length;

  bool isSongStarred(Song song) => _songIds.contains(song.id);
  bool isAlbumStarred(Album album) => _albumIds.contains(album.id);

  void _onSourceChanged() {
    final current = _registry.activeId;
    if (current != _serverId) {
      _serverId = current;
      _songIds.clear();
      _albumIds.clear();
      _songs = [];
      _albums = [];
      notifyListeners();
      if (current != null) refresh();
    }
  }

  Future<void> refresh() async {
    final source = _registry.source;
    if (source == null) return;
    final serverId = _registry.activeId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final songs = await source.getStarredSongs();
      final albums = await source.getStarredAlbums();
      if (serverId != _registry.activeId) return;
      _songs = songs;
      _albums = albums;
      _songIds
        ..clear()
        ..addAll(songs.map((e) => e.id));
      _albumIds
        ..clear()
        ..addAll(albums.map((e) => e.id));
      _serverId = serverId;
    } catch (error) {
      _error = '$error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSong(Song song) async {
    final source = _registry.source;
    if (source == null) return;
    final wasStarred = _songIds.contains(song.id);
    if (wasStarred) {
      _songIds.remove(song.id);
      _songs.removeWhere((e) => e.id == song.id);
    } else {
      _songIds.add(song.id);
      if (!_songs.any((e) => e.id == song.id)) {
        _songs.insert(0, song.copyWith(starred: true));
      }
    }
    notifyListeners();
    try {
      await source.setStarred(song, !wasStarred);
    } catch (_) {
      // 失败则回滚，保持与服务端一致。
      if (wasStarred) {
        _songIds.add(song.id);
        if (!_songs.any((e) => e.id == song.id)) _songs.insert(0, song);
      } else {
        _songIds.remove(song.id);
        _songs.removeWhere((e) => e.id == song.id);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _registry.removeListener(_onSourceChanged);
    super.dispose();
  }
}
