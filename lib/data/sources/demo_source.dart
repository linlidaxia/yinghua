import 'package:flutter/foundation.dart';

import '../models/library_models.dart';
import '../models/lyric.dart';
import '../models/server_config.dart';
import 'music_source.dart';

/// 内置演示资料库：无需服务器即可体验完整浏览、播放与歌词链路。
///
/// 所有专辑、歌手、歌曲名均为原创示例数据；音频为本地合成的占位音轨，
/// 不包含任何受版权保护的音乐内容。
class DemoSource extends MusicSource {
  DemoSource(this.config);

  @override
  final ServerConfig config;

  @override
  String get protocolLabel => '演示资料库';

  static const _albumSeeds = <_AlbumSeed>[
    _AlbumSeed('晚风收音机', '林间雾', 2024, [
      '晚风来信',
      '灯塔以北',
      '雨季候车室',
      '候鸟南飞',
      '风筝与线',
      '微光岛屿',
      '海岸线',
      '午夜电台',
    ]),
    _AlbumSeed('南方的雨', '苏晚', 2023, [
      '雨停之前',
      '南方姑娘',
      '湖边公路',
      '橘子汽水',
      '柔软的刺',
      '十九岁',
      '慢慢',
    ]),
    _AlbumSeed('城市浮游', '青芒乐队', 2025, [
      '城市浮游',
      '落日飞车',
      '街灯',
      '无人接听',
      '夜航星',
      '长街短梦',
      '蓝色时刻',
      '银河修理员',
      '晚安北京',
    ]),
    _AlbumSeed('折光', '陈默', 2022, [
      '折光',
      '旧梦一场',
      '小镇夏天',
      '黄昏列车',
      '回声房间',
      '十二月的海',
    ]),
    _AlbumSeed('归零', '回声社', 2024, [
      '归零',
      '山雾散场',
      '风从海上来',
      '星星坠落时',
      '无声焰火',
      '白昼梦游',
    ]),
    _AlbumSeed('山雾里', '南枝', 2021, [
      '山雾里',
      '月光邮局',
      '一封没有寄出的信',
      '青苔',
      '溪水与蝉',
      '晚归的人',
    ]),
    _AlbumSeed('旧磁带', '何小野', 2020, [
      '旧磁带',
      'A 面第一首',
      '倒带',
      '磁带机',
      '夏天结束前',
      '木质唱片',
    ]),
    _AlbumSeed('蓝色星期五', '夜航船', 2025, [
      '蓝色星期五',
      '星期五的雨',
      '深夜食堂',
      '零点以后',
      '海员日记',
      '凌晨四点的街',
    ]),
    _AlbumSeed('纸飞机', '路远', 2023, ['纸飞机', '操场', '毕业那天', '夏末的风', '很久以前', '少年']),
    _AlbumSeed('潮汐信件', '海水与岛', 2024, ['潮汐信件', '灯塔', '退潮', '盐与风', '远航', '岛上的夜']),
    _AlbumSeed('长夜漫游', '林间雾', 2025, [
      '长夜漫游',
      '雾中列车',
      '白噪音',
      '失眠者协会',
      '凌晨两点半',
      '晚安曲',
    ]),
    _AlbumSeed('夏日告别式', '青芒乐队', 2022, [
      '夏日告别式',
      '最后一场球',
      '蝉鸣',
      '汽水与汗',
      '再见夏天',
      '二十岁',
    ]),
    _AlbumSeed('无名花园', '苏晚', 2020, [
      '无名花园',
      '植物园',
      '蔷薇',
      '玻璃温室',
      '浇水的下午',
      '缓慢生长',
    ]),
    _AlbumSeed('玻璃海', '回声社', 2023, ['玻璃海', '潜泳', '水下的光', '蓝色房间', '呼吸', '浮出水面']),
  ];

  static const _poemLines = <String>[
    '晚风穿过旧收音机',
    '把夏天吹回我怀里',
    '灯影在窗台上摇晃',
    '像一封迟到的信',
    '我们沿着海岸线走',
    '脚步声落进潮汐里',
    '你说别怕夜太长',
    '星星会替你点灯',
    '列车驶过无声的城',
    '月光在铁轨上结冰',
    '如果明天还会下雨',
    '就把心事唱给风听',
    '把音量调到刚好',
    '让世界慢一点',
    '旧唱片还在转',
    '时间却停了',
  ];

  late final List<_AlbumData> _albumData = _buildAlbums();
  final Set<String> _starredSongIds = {};
  final Set<String> _starredAlbumIds = {};

  List<_AlbumData> _buildAlbums() {
    final result = <_AlbumData>[];
    for (var i = 0; i < _albumSeeds.length; i++) {
      final seed = _albumSeeds[i];
      final albumId = 'demo-album-$i';
      final songs = <Song>[];
      for (var j = 0; j < seed.songs.length; j++) {
        songs.add(
          Song(
            id: 'demo-song-$i-$j',
            title: seed.songs[j],
            artist: seed.artist,
            artistId: 'demo-artist-${seed.artist}',
            album: seed.name,
            albumId: albumId,
            coverArtId: 'demo-cover-$i',
            duration: Duration(seconds: 168 + ((i * 17 + j * 23) % 96)),
            track: j + 1,
            discNumber: 1,
            year: seed.year,
            suffix: (i + j) % 5 == 0 ? 'flac' : 'mp3',
            size: 6800000 + (i * 137 + j * 53) * 1024,
            bitRate: (i + j) % 5 == 0 ? 900 : 320,
            starred: (i + j) % 11 == 0,
            path: 'assets/audio/demo_loop.wav',
            serverId: config.id,
          ),
        );
      }
      result.add(
        _AlbumData(
          Album(
            id: albumId,
            name: seed.name,
            artist: seed.artist,
            artistId: 'demo-artist-${seed.artist}',
            coverArtId: 'demo-cover-$i',
            songCount: songs.length,
            year: seed.year,
            created: DateTime(seed.year, ((i % 12) + 1), 8 + (i % 20)),
          ),
          songs,
        ),
      );
    }
    return result;
  }

  List<Song> get _allSongs =>
      _albumData.expand((e) => e.songs).toList(growable: false);

  List<Artist> get _artists {
    final map = <String, Artist>{};
    for (final a in _albumData) {
      final artist = a.album.artist ?? '未知歌手';
      final id = a.album.artistId ?? 'demo-artist-$artist';
      final existing = map[id];
      map[id] = Artist(
        id: id,
        name: artist,
        albumCount: (existing?.albumCount ?? 0) + 1,
        songCount: (existing?.songCount ?? 0) + a.songs.length,
      );
    }
    return map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Playlist> get _playlists {
    const seeds = [
      ('深夜电台', '莺花编辑部', '给还没睡的人，一点温柔的白噪音。'),
      ('通勤轻音乐', '莺花编辑部', '地铁与耳机，城市里最安静的三十分钟。'),
      ('雨天书桌', '莺花编辑部', '雨声、书页与一杯慢慢变凉的茶。'),
      ('城市漫游', '莺花编辑部', '适合走路时听的独立摇滚与前卫流行。'),
      ('独立新声', '莺花编辑部', '值得被听见的新乐队与卧室音乐人。'),
      ('海边公路', '莺花编辑部', '沿着海岸线一直开，直到日落。'),
    ];
    final songs = _allSongs;
    return [
      for (var i = 0; i < seeds.length; i++)
        Playlist(
          id: 'demo-playlist-$i',
          name: seeds[i].$1,
          owner: seeds[i].$2,
          comment: seeds[i].$3,
          songCount: 8 + i,
          coverArtId: songs[(i * 5) % songs.length].coverArtId,
          created: DateTime(2025, (i % 12) + 1, 3 + i),
        ),
    ];
  }

  PlaylistDetail _playlistDetail(String id) {
    final index = int.tryParse(id.replaceAll('demo-playlist-', '')) ?? 0;
    final playlist = _playlists[index % _playlists.length];
    final all = _allSongs;
    final count = 8 + index;
    final songs = <Song>[
      for (var k = 0; k < count; k++) all[(index * 7 + k * 3) % all.length],
    ];
    return PlaylistDetail(playlist: playlist, songs: songs);
  }

  Song? _songById(String id) {
    for (final song in _allSongs) {
      if (song.id == id) {
        return song.copyWith(starred: _starredSongIds.contains(song.id));
      }
    }
    return null;
  }

  @override
  Future<String?> ping() async => 'demo';

  @override
  Future<List<Album>> getAlbums(
    AlbumListType type, {
    int size = 30,
    int offset = 0,
  }) async {
    var albums = _albumData.map((e) => e.album).toList();
    switch (type) {
      case AlbumListType.newest:
        albums.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case AlbumListType.recent:
        albums.sort((a, b) => b.created!.compareTo(a.created!));
      case AlbumListType.alphabetical:
        albums.sort((a, b) => a.name.compareTo(b.name));
      case AlbumListType.random:
      case AlbumListType.frequent:
        albums = List.of(albums)..shuffle();
      case AlbumListType.starred:
        albums = albums.where((a) => _starredAlbumIds.contains(a.id)).toList();
    }
    return albums.skip(offset).take(size).toList();
  }

  @override
  Future<List<Song>> getRandomSongs({int size = 30}) async {
    final songs = List.of(_allSongs)..shuffle();
    return songs.take(size).toList();
  }

  @override
  Future<AlbumDetail> getAlbum(String id) async {
    final data = _albumData.firstWhere(
      (e) => e.album.id == id,
      orElse: () => _albumData.first,
    );
    return AlbumDetail(album: data.album, songs: data.songs);
  }

  @override
  Future<List<Artist>> getArtists() async => _artists;

  @override
  Future<ArtistDetail> getArtist(String id) async {
    final artist = _artists.firstWhere(
      (e) => e.id == id,
      orElse: () => _artists.first,
    );
    final albums = _albumData
        .where((e) => e.album.artistId == artist.id)
        .map((e) => e.album)
        .toList();
    final songs = _allSongs
        .where((s) => s.artistId == artist.id)
        .take(10)
        .toList();
    return ArtistDetail(artist: artist, albums: albums, topSongs: songs);
  }

  @override
  Future<List<Playlist>> getPlaylists() async => _playlists;

  @override
  Future<PlaylistDetail> getPlaylist(String id) async => _playlistDetail(id);

  @override
  Future<List<Song>> getStarredSongs() async =>
      _allSongs.where((s) => _starredSongIds.contains(s.id)).toList();

  @override
  Future<List<Album>> getStarredAlbums() async => _albumData
      .map((e) => e.album)
      .where((a) => _starredAlbumIds.contains(a.id))
      .toList();

  @override
  Future<void> setStarred(Song song, bool starred) async {
    if (starred) {
      _starredSongIds.add(song.id);
    } else {
      _starredSongIds.remove(song.id);
    }
  }

  @override
  Future<SearchResult> search(
    String query, {
    int songOffset = 0,
    int songCount = 100,
    int albumCount = 12,
    int artistCount = 10,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const SearchResult();
    final matched = _allSongs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.displayArtist.toLowerCase().contains(q) ||
              s.displayAlbum.toLowerCase().contains(q),
        )
        .toList();
    return SearchResult(
      songs: matched.skip(songOffset).take(songCount).toList(),
      albums: _albumData
          .map((e) => e.album)
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.displayArtist.toLowerCase().contains(q),
          )
          .take(albumCount)
          .toList(),
      artists: _artists
          .where((a) => a.name.toLowerCase().contains(q))
          .take(artistCount)
          .toList(),
    );
  }

  @override
  Future<Lyric?> getLyric(Song song) async {
    final seed = song.id.hashCode.abs();
    final rotation = seed % _poemLines.length;
    final lines = <LyricLine>[];
    final count = 12;
    final total = song.duration.inMilliseconds;
    final start = 4200 + (seed % 1200);
    final step = ((total - start - 6000) / count).clamp(4200, 9000).toInt();
    for (var i = 0; i < count; i++) {
      lines.add(
        LyricLine(
          at: Duration(milliseconds: start + step * i),
          text: _poemLines[(rotation + i) % _poemLines.length],
        ),
      );
    }
    return Lyric(lines: lines, synced: true, source: '演示歌词');
  }

  @override
  Future<List<MusicFolder>> getMusicFolders() async => const [
    MusicFolder(id: 'demo-folder-root', name: '演示音乐库'),
  ];

  @override
  Future<DirectoryContent> getMusicDirectory(String id) async {
    if (id == 'demo-folder-root') {
      return DirectoryContent(
        id: id,
        items: [
          for (final data in _albumData)
            DirectoryItem(
              id: data.album.id,
              title: data.album.name,
              isDirectory: true,
              coverArtId: data.album.coverArtId,
              artist: data.album.displayArtist,
            ),
        ],
      );
    }
    if (id.startsWith('demo-artist-')) {
      final albums = _albumData.where((e) => e.album.artistId == id).toList();
      return DirectoryContent(
        id: id,
        items: [
          for (final data in albums)
            DirectoryItem(
              id: data.album.id,
              title: data.album.name,
              isDirectory: true,
              coverArtId: data.album.coverArtId,
              artist: data.album.displayArtist,
            ),
        ],
      );
    }
    final data = _albumData.firstWhere(
      (e) => e.album.id == id,
      orElse: () => _albumData.first,
    );
    return DirectoryContent(
      id: id,
      items: [
        for (final song in data.songs)
          DirectoryItem(
            id: song.id,
            title: song.title,
            isDirectory: false,
            coverArtId: song.coverArtId,
            artist: song.artist,
            album: song.album,
            duration: song.duration,
            suffix: song.suffix,
            size: song.size,
            track: song.track,
          ),
      ],
    );
  }

  @override
  Future<Song?> getSong(String id) async => _songById(id);

  @override
  Future<void> scrobble(Song song, {bool submission = true}) async {}

  @override
  Future<Uri> resolveStream(
    Song song, {
    int? maxBitRate,
    Duration? startOffset,
  }) async => Uri.parse('assets/audio/demo_loop.wav');

  @override
  Uri? coverUri(String? coverArtId, {int size = 300}) => null;

  /// 演示模式下用于给「我喜欢的音乐」预置一些内容。
  void seedStarred() {
    if (_starredSongIds.isNotEmpty) return;
    final all = _allSongs;
    for (var i = 0; i < 7; i++) {
      _starredSongIds.add(all[(i * 13) % all.length].id);
    }
    _starredAlbumIds.addAll(_albumData.take(3).map((e) => e.album.id));
  }

  @override
  String toString() => 'DemoSource(${kDebugMode ? 'debug' : ''})';
}

class _AlbumSeed {
  const _AlbumSeed(this.name, this.artist, this.year, this.songs);
  final String name;
  final String artist;
  final int year;
  final List<String> songs;
}

class _AlbumData {
  const _AlbumData(this.album, this.songs);
  final Album album;
  final List<Song> songs;
}
