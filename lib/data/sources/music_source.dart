import '../models/library_models.dart';
import '../models/lyric.dart';
import '../models/server_config.dart';

enum AlbumListType { newest, recent, frequent, random, alphabetical, starred }

/// 音乐源接入层契约。
///
/// 新增 Jellyfin / Emby 等协议时，只需实现此接口并注册到 SourceRegistry，
/// UI 与播放层无需改动。
abstract class MusicSource {
  /// 目录浏览兜底入口的固定 id（按歌手浏览）。
  static const String indexesFolderId = '__indexes__';

  ServerConfig get config;

  /// 显示用名称，例如「Navidrome」。
  String get protocolLabel;

  Future<String?> ping();

  Future<List<Album>> getAlbums(
    AlbumListType type, {
    int size = 30,
    int offset = 0,
  });

  Future<List<Song>> getRandomSongs({int size = 30});

  Future<AlbumDetail> getAlbum(String id);

  Future<List<Artist>> getArtists();

  Future<ArtistDetail> getArtist(String id);

  Future<List<Playlist>> getPlaylists();

  Future<PlaylistDetail> getPlaylist(String id);

  Future<List<Song>> getStarredSongs();

  Future<List<Album>> getStarredAlbums();

  Future<void> setStarred(Song song, bool starred);

  /// 搜索。歌曲支持分页（[songOffset] / [songCount]），专辑与歌手取首屏。
  Future<SearchResult> search(
    String query, {
    int songOffset = 0,
    int songCount = 100,
    int albumCount = 12,
    int artistCount = 10,
  });

  Future<Lyric?> getLyric(Song song);

  Future<List<MusicFolder>> getMusicFolders();

  Future<DirectoryContent> getMusicDirectory(String id);

  /// 目录浏览器不可用时的兜底：用歌手索引继续浏览。
  ///
  /// 大多数 Subsonic 实现都支持 getArtists，因此即使 getMusicDirectory
  /// 不被服务端支持，用户仍然能进入「歌手 → 专辑 → 歌曲」。
  Future<DirectoryContent> getIndexesDirectory() async {
    final artists = await getArtists();
    return DirectoryContent(
      id: '__indexes__',
      items: [
        for (final artist in artists)
          DirectoryItem(
            id: artist.id,
            title: artist.name,
            isDirectory: true,
            coverArtId: artist.coverArtId,
            artist: artist.name,
          ),
      ],
    );
  }

  Future<Song?> getSong(String id);

  Future<void> scrobble(Song song, {bool submission = true});

  /// [startOffset] 仅对需要服务端转码的曲目生效（Navidrome 的 timeOffset），
  /// 用于跳过片头：实时转码流不支持 Range，客户端无法 seek。
  Future<Uri> resolveStream(
    Song song, {
    int? maxBitRate,
    Duration? startOffset,
  });

  Uri? coverUri(String? coverArtId, {int size = 300});
}

class MusicSourceException implements Exception {
  MusicSourceException(this.message, {this.code, this.isAuthError = false});

  final String message;
  final int? code;
  final bool isAuthError;

  @override
  String toString() => message;
}
