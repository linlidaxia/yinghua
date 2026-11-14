import 'dart:convert';

/// 歌曲。字段对齐 Subsonic `Child` 结构，并补充本地派生信息。
class Song {
  const Song({
    required this.id,
    required this.title,
    this.artist,
    this.artistId,
    this.album,
    this.albumId,
    this.coverArtId,
    this.duration = Duration.zero,
    this.track,
    this.discNumber,
    this.year,
    this.suffix,
    this.size,
    this.bitRate,
    this.starred = false,
    this.path,
    this.serverId,
    this.trackGain,
    this.albumGain,
  });

  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final String? album;
  final String? albumId;
  final String? coverArtId;
  final Duration duration;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? suffix;
  final int? size;
  final int? bitRate;
  final bool starred;
  final String? path;
  final String? serverId;
  final double? trackGain;
  final double? albumGain;

  bool get isLossless {
    final s = suffix?.toLowerCase();
    return s == 'flac' || s == 'wav' || s == 'alac' || s == 'ape' || s == 'dsf';
  }

  String get displayArtist {
    final a = artist?.trim();
    return (a == null || a.isEmpty) ? '未知歌手' : a;
  }

  String get displayAlbum {
    final a = album?.trim();
    return (a == null || a.isEmpty) ? '未知专辑' : a;
  }

  Song copyWith({
    bool? starred,
    String? coverArtId,
    double? trackGain,
    double? albumGain,
    String? serverId,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      artistId: artistId,
      album: album,
      albumId: albumId,
      coverArtId: coverArtId ?? this.coverArtId,
      duration: duration,
      track: track,
      discNumber: discNumber,
      year: year,
      suffix: suffix,
      size: size,
      bitRate: bitRate,
      starred: starred ?? this.starred,
      path: path,
      serverId: serverId ?? this.serverId,
      trackGain: trackGain ?? this.trackGain,
      albumGain: albumGain ?? this.albumGain,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artistId': artistId,
    'album': album,
    'albumId': albumId,
    'coverArtId': coverArtId,
    'duration': duration.inMilliseconds,
    'track': track,
    'discNumber': discNumber,
    'year': year,
    'suffix': suffix,
    'size': size,
    'bitRate': bitRate,
    'starred': starred,
    'path': path,
    'serverId': serverId,
    'trackGain': trackGain,
    'albumGain': albumGain,
  };

  static Song fromJson(Map<String, dynamic> json) => Song(
    id: '${json['id']}',
    title: (json['title'] as String?) ?? '未知歌曲',
    artist: json['artist'] as String?,
    artistId: json['artistId'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as String?,
    coverArtId: json['coverArtId'] as String?,
    duration: Duration(milliseconds: (json['duration'] as num?)?.toInt() ?? 0),
    track: (json['track'] as num?)?.toInt(),
    discNumber: (json['discNumber'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    suffix: json['suffix'] as String?,
    size: (json['size'] as num?)?.toInt(),
    bitRate: (json['bitRate'] as num?)?.toInt(),
    starred: json['starred'] as bool? ?? false,
    path: json['path'] as String?,
    serverId: json['serverId'] as String?,
    trackGain: (json['trackGain'] as num?)?.toDouble(),
    albumGain: (json['albumGain'] as num?)?.toDouble(),
  );

  static List<Song> listFromJson(String? raw) {
    // 必须是可变列表：调用方（最近播放）会直接 remove/insert。
    if (raw == null || raw.isEmpty) return <Song>[];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return <Song>[];
      return data
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <Song>[];
    }
  }
}

class Album {
  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArtId,
    this.songCount = 0,
    this.year,
    this.created,
    this.starred = false,
  });

  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArtId;
  final int songCount;
  final int? year;
  final DateTime? created;
  final bool starred;

  String get displayArtist {
    final a = artist?.trim();
    return (a == null || a.isEmpty) ? '未知歌手' : a;
  }

  String get meta {
    final parts = <String>[];
    if (year != null && year! > 0) parts.add('$year');
    if (songCount > 0) parts.add('$songCount 首');
    return parts.join(' · ');
  }
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.coverArtId,
    this.albumCount = 0,
    this.songCount,
  });

  final String id;
  final String name;
  final String? coverArtId;
  final int albumCount;
  final int? songCount;
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.owner,
    this.comment,
    this.songCount = 0,
    this.coverArtId,
    this.created,
    this.isPublic = true,
  });

  final String id;
  final String name;
  final String? owner;
  final String? comment;
  final int songCount;
  final String? coverArtId;
  final DateTime? created;
  final bool isPublic;

  String get meta {
    final parts = <String>['$songCount 首'];
    if (owner != null && owner!.trim().isNotEmpty) parts.add(owner!);
    return parts.join(' · ');
  }
}

/// 文件夹浏览节点（getMusicDirectory.child）
class DirectoryItem {
  const DirectoryItem({
    required this.id,
    required this.title,
    required this.isDirectory,
    this.coverArtId,
    this.artist,
    this.duration = Duration.zero,
    this.suffix,
    this.size,
    this.track,
    this.album,
  });

  final String id;
  final String title;
  final bool isDirectory;
  final String? coverArtId;
  final String? artist;
  final Duration duration;
  final String? suffix;
  final int? size;
  final int? track;
  final String? album;
}

class MusicFolder {
  const MusicFolder({required this.id, required this.name});
  final String id;
  final String name;
}

class SearchResult {
  const SearchResult({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });

  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;

  SearchResult merge(SearchResult other) => SearchResult(
    songs: [...songs, ...other.songs],
    albums: [...albums, ...other.albums],
    artists: [...artists, ...other.artists],
  );
}

class AlbumDetail {
  const AlbumDetail({required this.album, this.songs = const []});
  final Album album;
  final List<Song> songs;
}

class PlaylistDetail {
  const PlaylistDetail({required this.playlist, this.songs = const []});
  final Playlist playlist;
  final List<Song> songs;
}

class ArtistDetail {
  const ArtistDetail({
    required this.artist,
    this.albums = const [],
    this.topSongs = const [],
  });
  final Artist artist;
  final List<Album> albums;
  final List<Song> topSongs;
}

class DirectoryContent {
  const DirectoryContent({required this.id, this.items = const []});
  final String id;
  final List<DirectoryItem> items;
}

class HomeFeed {
  const HomeFeed({
    this.recommended = const [],
    this.newest = const [],
    this.playlists = const [],
    this.randomSongs = const [],
  });

  final List<Album> recommended;
  final List<Album> newest;
  final List<Playlist> playlists;
  final List<Song> randomSongs;

  bool get isEmpty =>
      recommended.isEmpty &&
      newest.isEmpty &&
      playlists.isEmpty &&
      randomSongs.isEmpty;
}
