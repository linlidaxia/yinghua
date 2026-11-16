import '../../core/utils/audio_format.dart';
import '../../core/utils/charset_support.dart';
import '../../core/utils/lyric_parser.dart';
import '../models/library_models.dart';
import '../models/lyric.dart';
import '../models/server_config.dart';
import 'music_source.dart';
import 'subsonic_client.dart';

/// 把 Subsonic JSON 映射为莺花的领域模型。
class SubsonicSource extends MusicSource {
  SubsonicSource(this.config) : _client = SubsonicClient(config);

  @override
  final ServerConfig config;
  final SubsonicClient _client;

  @override
  String get protocolLabel => 'Navidrome / Subsonic';

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  int _int(dynamic value) => value is num ? value.toInt() : 0;

  /// 文本字段统一过一遍乱码修复（服务器可能返回 GBK→Latin-1 的二次编码）。
  String _text(dynamic value) => CharsetSupport.repairText('${value ?? ''}');

  String? _textOrNull(dynamic value) {
    if (value == null) return null;
    final text = '${value}'.trim();
    if (text.isEmpty) return null;
    return CharsetSupport.repairText(text);
  }

  double? _double(dynamic value) => value is num ? value.toDouble() : null;

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  bool _starred(Map<String, dynamic> json) {
    final v = json['starred'];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.isNotEmpty;
    return true;
  }

  Song _song(Map<String, dynamic> json) {
    final gain = _map(json['replayGain']);
    return Song(
      id: '${json['id']}',
      title: _text(json['title'] ?? json['name'] ?? '未知歌曲'),
      artist: _textOrNull(json['artist']),
      artistId: json['artistId']?.toString(),
      album: _textOrNull(json['album']),
      albumId: json['albumId']?.toString(),
      coverArtId: (json['coverArt'] ?? json['coverArtId'] ?? json['albumId'])
          ?.toString(),
      duration: Duration(seconds: _int(json['duration'])),
      track: json['track'] == null ? null : _int(json['track']),
      discNumber: json['discNumber'] == null ? null : _int(json['discNumber']),
      year: json['year'] == null ? null : _int(json['year']),
      suffix: json['suffix'] as String?,
      size: json['size'] == null ? null : _int(json['size']),
      bitRate: json['bitRate'] == null ? null : _int(json['bitRate']),
      starred: _starred(json),
      path: json['path'] as String?,
      serverId: config.id,
      trackGain: _double(gain['trackGain']),
      albumGain: _double(gain['albumGain']),
    );
  }

  Album _album(Map<String, dynamic> json) => Album(
    id: '${json['id']}',
    name: _text(json['name'] ?? json['title'] ?? '未知专辑'),
    artist: _textOrNull(json['artist']),
    artistId: json['artistId']?.toString(),
    coverArtId: (json['coverArt'] ?? json['coverArtId'] ?? json['id'])
        ?.toString(),
    songCount: _int(json['songCount']),
    year: json['year'] == null ? null : _int(json['year']),
    created: _date(json['created']),
    starred: _starred(json),
  );

  Artist _artist(Map<String, dynamic> json) => Artist(
    id: '${json['id']}',
    name: _text(json['name'] ?? '未知歌手'),
    coverArtId: (json['coverArt'] ?? json['coverArtId'])?.toString(),
    albumCount: _int(json['albumCount']),
    songCount: json['songCount'] == null ? null : _int(json['songCount']),
  );

  Playlist _playlist(Map<String, dynamic> json) => Playlist(
    id: '${json['id']}',
    name: _text(json['name'] ?? '未命名歌单'),
    owner: json['owner'] as String?,
    comment: json['comment'] as String?,
    songCount: _int(json['songCount']),
    coverArtId: (json['coverArt'] ?? json['coverArtId'])?.toString(),
    created: _date(json['created']),
    isPublic: json['public'] != false,
  );

  /// [sortTracks] 为 false 时保留服务器顺序（歌单、搜索结果需要原顺序）。
  List<Song> _songs(dynamic raw, {bool sortTracks = true}) {
    final list = _maps(raw).map(_song).toList();
    if (!sortTracks) return list;
    list.sort((a, b) {
      final discA = a.discNumber ?? 0;
      final discB = b.discNumber ?? 0;
      if (discA != discB) return discA.compareTo(discB);
      return (a.track ?? 0).compareTo(b.track ?? 0);
    });
    return list;
  }

  List<Album> _albums(dynamic raw) => _maps(raw).map(_album).toList();

  @override
  Future<String?> ping() async {
    final response = await _client.call('ping');
    final version = '${response['version'] ?? ''}';
    return version.isEmpty ? null : version;
  }

  @override
  Future<List<Album>> getAlbums(
    AlbumListType type, {
    int size = 30,
    int offset = 0,
  }) async {
    if (type == AlbumListType.starred) {
      return getStarredAlbums();
    }
    const typeNames = {
      AlbumListType.newest: 'newest',
      AlbumListType.recent: 'recent',
      AlbumListType.frequent: 'frequent',
      AlbumListType.random: 'random',
      AlbumListType.alphabetical: 'alphabeticalByName',
      AlbumListType.starred: 'starred',
    };
    final response = await _client.call(
      'getAlbumList2',
      params: {
        'type': typeNames[type] ?? 'newest',
        'size': '$size',
        'offset': '$offset',
      },
    );
    final list = _map(response['albumList2'])['album'];
    return _albums(list);
  }

  @override
  Future<List<Song>> getRandomSongs({int size = 30}) async {
    final response = await _client.call(
      'getRandomSongs',
      params: {'size': '$size'},
    );
    return _songs(_map(response['randomSongs'])['song']);
  }

  @override
  Future<AlbumDetail> getAlbum(String id) async {
    final response = await _client.call('getAlbum', params: {'id': id});
    final albumJson = _map(response['album']);
    return AlbumDetail(
      album: _album(albumJson),
      songs: _songs(albumJson['song'] ?? response['song']),
    );
  }

  @override
  Future<List<Artist>> getArtists() async {
    final response = await _client.call('getArtists');
    final indexes = _maps(_map(response['artists'])['index']);
    final result = <Artist>[];
    final seen = <String>{};
    for (final index in indexes) {
      for (final raw in _maps(index['artist'])) {
        final artist = _artist(raw);
        if (seen.add(artist.id)) result.add(artist);
      }
    }
    return result;
  }

  @override
  Future<ArtistDetail> getArtist(String id) async {
    final response = await _client.call('getArtist', params: {'id': id});
    final artistJson = _map(response['artist']);
    final artist = _artist(artistJson);

    var topSongs = <Song>[];
    try {
      final top = await _client.call(
        'getTopSongs',
        params: {'artist': artist.name, 'count': '20'},
      );
      topSongs = _songs(_map(top['topSongs'])['song']);
    } catch (_) {
      // 部分服务端不支持 getTopSongs，静默降级。
    }

    return ArtistDetail(
      artist: artist,
      albums: _albums(artistJson['album']),
      topSongs: topSongs,
    );
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final response = await _client.call('getPlaylists');
    return _maps(_map(response['playlists'])['playlist'])
        .map(_playlist)
        .toList();
  }

  @override
  Future<PlaylistDetail> getPlaylist(String id) async {
    final response = await _client.call('getPlaylist', params: {'id': id});
    final playlistJson = _map(response['playlist']);
    final playlist = _playlist(playlistJson);
    // 歌单保持服务器顺序（默认顺序），不要按碟号/音轨重排。
    final songs = _songs(
      playlistJson['entry'] ?? response['entry'],
      sortTracks: false,
    );
    return PlaylistDetail(
      playlist: Playlist(
        id: playlist.id,
        name: playlist.name,
        owner: playlist.owner,
        comment: playlist.comment,
        songCount: songs.isEmpty ? playlist.songCount : songs.length,
        coverArtId: playlist.coverArtId,
        created: playlist.created,
        isPublic: playlist.isPublic,
      ),
      songs: songs,
    );
  }

  @override
  Future<List<Song>> getStarredSongs() async {
    final response = await _client.call('getStarred2');
    return _songs(_map(response['starred2'])['song']);
  }

  @override
  Future<List<Album>> getStarredAlbums() async {
    final response = await _client.call('getStarred2');
    return _albums(_map(response['starred2'])['album']);
  }

  @override
  Future<void> setStarred(Song song, bool starred) async {
    final response = await _client.call(
      starred ? 'star' : 'unstar',
      params: {'id': song.id},
    );
    // 部分服务端返回空响应体，call 已保证状态 ok。
    if (response.isEmpty) return;
  }

  @override
  Future<SearchResult> search(
    String query, {
    int songOffset = 0,
    int songCount = 100,
    int albumCount = 12,
    int artistCount = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const SearchResult();
    final response = await _client.call(
      'search3',
      params: {
        'query': q,
        'songOffset': '$songOffset',
        'songCount': '$songCount',
        'albumCount': '$albumCount',
        'artistCount': '$artistCount',
      },
    );
    final result = _map(response['searchResult3']);
    return SearchResult(
      songs: _songs(result['song'], sortTracks: false),
      albums: _albums(result['album']),
      artists: _maps(result['artist']).map(_artist).toList(),
    );
  }

  @override
  Future<Lyric?> getLyric(Song song) async {
    try {
      final response = await _client.call(
        'getLyricsBySongId',
        params: {'id': song.id},
        timeout: const Duration(seconds: 12),
      );
      final structured = _map(response['lyricsList'])['structuredLyrics'];
      if (structured is List) {
        final lyric = LyricParser.fromStructured(
          structured,
          songDuration: song.duration,
        );
        if (lyric != null && !lyric.isEmpty) return _repaired(lyric);
      }
    } catch (_) {
      // 服务端可能未开启 OpenSubsonic 歌词扩展，继续尝试旧接口。
    }

    final artist = song.artist?.trim() ?? '';
    if (artist.isEmpty) return null;
    try {
      final response = await _client.call(
        'getLyrics',
        params: {'artist': artist, 'title': song.title},
        timeout: const Duration(seconds: 12),
      );
      final value = _map(response['lyrics'])['value'];
      if (value is String && value.trim().isNotEmpty) {
        final lyric = LyricParser.fromLrcText(value);
        if (lyric != null) return _repaired(lyric);
      }
    } catch (_) {
      // 无歌词时保持静默，UI 展示空状态。
    }
    return null;
  }

  /// 歌词正文可能是「GBK 字节 → Latin-1」的二次编码，逐行做一次修复。
  Lyric _repaired(Lyric lyric) {
    if (lyric.lines.isEmpty) return lyric;
    final lines = [
      for (final line in lyric.lines)
        LyricLine(at: line.at, text: CharsetSupport.repairText(line.text)),
    ];
    return Lyric(
      lines: lines,
      synced: lyric.synced,
      source: lyric.source,
      offset: lyric.offset,
    );
  }

  @override
  Future<List<MusicFolder>> getMusicFolders() async {
    try {
      final response = await _client.call(
        'getMusicFolders',
        timeout: const Duration(seconds: 15),
      );
      final folders = _maps(_map(response['musicFolders'])['musicFolder'])
          .map(
            (e) =>
                MusicFolder(id: '${e['id']}', name: _text(e['name'] ?? '音乐库')),
          )
          .toList();
      if (folders.isNotEmpty) return folders;
    } catch (_) {
      // 部分服务端未实现 getMusicFolders，降级为歌手索引。
    }
    return const [MusicFolder(id: MusicSource.indexesFolderId, name: '按歌手浏览')];
  }

  @override
  Future<DirectoryContent> getMusicDirectory(String id) async {
    if (id == MusicSource.indexesFolderId) return getIndexesDirectory();
    final response = await _client.call(
      'getMusicDirectory',
      params: {'id': id},
      timeout: const Duration(seconds: 20),
    );
    final items = _maps(_map(response['directory'])['child'])
        .map(
          (e) => DirectoryItem(
            id: '${e['id']}',
            title: _text(e['title'] ?? e['name'] ?? '未命名'),
            isDirectory: e['isDir'] == true,
            coverArtId: (e['coverArt'] ?? e['coverArtId'])?.toString(),
            artist: _textOrNull(e['artist']),
            duration: Duration(seconds: _int(e['duration'])),
            suffix: e['suffix'] as String?,
            size: e['size'] == null ? null : _int(e['size']),
            track: e['track'] == null ? null : _int(e['track']),
            album: _textOrNull(e['album']),
          ),
        )
        .toList();
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return DirectoryContent(id: id, items: items);
  }

  @override
  Future<Song?> getSong(String id) async {
    try {
      final response = await _client.call('getSong', params: {'id': id});
      final json = _map(response['song']);
      if (json.isEmpty) return null;
      return _song(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> scrobble(Song song, {bool submission = true}) async {
    try {
      await _client.call(
        'scrobble',
        params: {'id': song.id, 'submission': '$submission'},
        timeout: const Duration(seconds: 10),
      );
    } catch (_) {
      // 统计上报失败不影响播放。
    }
  }

  @override
  Future<Uri> resolveStream(
    Song song, {
    int? maxBitRate,
    Duration? startOffset,
  }) async {
    // wma / ape / dsf 等设备不支持的格式，交给服务端转成 mp3。
    // mp3 / flac 等一律直连：即使设置了「音质上限」也不对原始流发起转码，
    // 避免 Navidrome 缺少 ffmpeg 时返回 503 导致整首无法播放。
    if (AudioFormat.shouldTranscode(song.suffix)) {
      final rate = (maxBitRate != null && maxBitRate > 0)
          ? maxBitRate
          : AudioFormat.transcodeBitRate;
      return _client.uri('stream', {
        'id': song.id,
        'format': AudioFormat.transcodeTarget,
        'maxBitRate': '$rate',
        // Navidrome 支持从指定秒数开始转码，用于跳过片头。
        if (startOffset != null && startOffset.inSeconds > 0)
          'timeOffset': '${startOffset.inSeconds}',
      });
    }
    // 原始流（format=raw）不能带 maxBitRate：Navidrome 会因此尝试转码，
    // 未配置 ffmpeg 时直接返回 503，表现为「音频格式不受支持」。
    return _client.uri('stream', {'id': song.id, 'format': 'raw'});
  }

  @override
  Uri? coverUri(String? coverArtId, {int size = 300}) {
    final id = coverArtId?.trim();
    if (id == null || id.isEmpty) return null;
    return _client.uri('getCoverArt', {'id': id, 'size': '$size'});
  }
}
