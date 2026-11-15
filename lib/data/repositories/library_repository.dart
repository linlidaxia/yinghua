import '../models/library_models.dart';
import '../sources/music_source.dart';
import '../sources/source_registry.dart';

class _CacheEntry {
  _CacheEntry(this.value, this.expiresAt);
  final Object? value;
  final DateTime expiresAt;
  bool get fresh => DateTime.now().isBefore(expiresAt);
}

/// 资料库查询门面：统一缓存策略，UI 不直接触碰网络客户端。
class LibraryRepository {
  LibraryRepository(this.registry) {
    registry.addListener(_onSourceChanged);
  }

  final SourceRegistry registry;
  final Map<String, _CacheEntry> _cache = {};
  String? _serverId;
  static const _ttl = Duration(minutes: 5);

  MusicSource get _source {
    final source = registry.source;
    if (source == null) {
      throw MusicSourceException('尚未连接音乐服务器');
    }
    return source;
  }

  void _onSourceChanged() {
    if (_serverId != registry.activeId) {
      _serverId = registry.activeId;
      _cache.clear();
    }
  }

  void invalidate() => _cache.clear();

  Future<T> _remember<T>(
    String key,
    Future<T> Function() load, {
    bool refresh = false,
    Duration ttl = _ttl,
  }) async {
    final entry = _cache[key];
    if (!refresh && entry != null && entry.fresh) {
      return entry.value as T;
    }
    final value = await load();
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
    return value;
  }

  Future<HomeFeed> homeFeed({bool refresh = false}) async {
    final sid = registry.activeId ?? '';
    return _remember(
      'home_$sid',
      () async {
        final recommended = await _safe(
          () => _source.getAlbums(AlbumListType.frequent, size: 8),
        );
        final newest = await _safe(
          () => _source.getAlbums(AlbumListType.newest, size: 8),
        );
        final playlists = await _safe(() => _source.getPlaylists());
        final random = await _safe(() => _source.getRandomSongs(size: 24));
        return HomeFeed(
          recommended: recommended,
          newest: newest,
          playlists: playlists,
          randomSongs: random,
        );
      },
      refresh: refresh,
      ttl: const Duration(minutes: 3),
    );
  }

  Future<List<Album>> albums(
    AlbumListType type, {
    int size = 30,
    bool refresh = false,
  }) {
    return _remember(
      'albums_${type.name}_$size',
      () => _source.getAlbums(type, size: size),
      refresh: refresh,
    );
  }

  Future<List<Song>> randomSongs({int size = 30}) =>
      _source.getRandomSongs(size: size);

  Future<AlbumDetail> album(String id, {bool refresh = false}) =>
      _remember('album_$id', () => _source.getAlbum(id), refresh: refresh);

  Future<PlaylistDetail> playlist(String id, {bool refresh = false}) =>
      _remember(
        'playlist_$id',
        () => _source.getPlaylist(id),
        refresh: refresh,
      );

  Future<ArtistDetail> artist(String id, {bool refresh = false}) =>
      _remember('artist_$id', () => _source.getArtist(id), refresh: refresh);

  Future<List<Playlist>> playlists({bool refresh = false}) =>
      _remember('playlists', () => _source.getPlaylists(), refresh: refresh);

  Future<List<Artist>> artists({bool refresh = false}) =>
      _remember('artists', () => _source.getArtists(), refresh: refresh);

  Future<List<MusicFolder>> musicFolders({bool refresh = false}) =>
      _remember('folders', () => _source.getMusicFolders(), refresh: refresh);

  Future<DirectoryContent> directory(String id, {bool refresh = false}) =>
      _remember(
        'dir_$id',
        () => _source.getMusicDirectory(id),
        refresh: refresh,
        ttl: const Duration(minutes: 10),
      );

  Future<SearchResult> search(
    String query, {
    int songOffset = 0,
    int songCount = 100,
    int albumCount = 12,
    int artistCount = 10,
  }) => _source.search(
    query,
    songOffset: songOffset,
    songCount: songCount,
    albumCount: albumCount,
    artistCount: artistCount,
  );

  Future<List<Song>> starredSongs({bool refresh = false}) => _remember(
    'starred_songs',
    () => _source.getStarredSongs(),
    refresh: refresh,
  );

  Future<List<Album>> starredAlbums({bool refresh = false}) => _remember(
    'starred_albums',
    () => _source.getStarredAlbums(),
    refresh: refresh,
  );

  Future<LyricFetch> lyric(Song song) async {
    try {
      final raw = await _source.getLyric(song);
      // 服务器歌词如果已经是乱码（编码错误且不可逆），视为没有歌词。
      if (raw != null && raw.isCorrupted) {
        return const LyricFetch(corrupted: true);
      }
      return LyricFetch(lyric: raw);
    } catch (error) {
      return LyricFetch(error: '$error');
    }
  }

  Future<List<T>> _safe<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return <T>[];
    }
  }

  void dispose() {
    registry.removeListener(_onSourceChanged);
  }
}

class LyricFetch {
  const LyricFetch({this.lyric, this.error, this.corrupted = false});
  final dynamic lyric;
  final String? error;

  /// 服务器返回了歌词，但已经是不可逆的乱码（编码错误）。
  final bool corrupted;
}
