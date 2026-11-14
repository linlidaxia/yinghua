import '../../data/models/library_models.dart';

/// 列表排序方式。
///
/// `server` 表示保持服务端返回顺序（歌单 / 搜索结果默认值），
/// 其余为本地排序，方便在歌单里按歌名、歌手、时长快速整理。
enum SortOrder {
  server,
  titleAsc,
  titleDesc,
  artistAsc,
  albumAsc,
  durationAsc,
  durationDesc,
  yearDesc,
}

extension SortOrderX on SortOrder {
  String get label => switch (this) {
    SortOrder.server => '默认顺序（服务器）',
    SortOrder.titleAsc => '标题 A → Z',
    SortOrder.titleDesc => '标题 Z → A',
    SortOrder.artistAsc => '歌手 A → Z',
    SortOrder.albumAsc => '专辑 A → Z',
    SortOrder.durationAsc => '时长 短 → 长',
    SortOrder.durationDesc => '时长 长 → 短',
    SortOrder.yearDesc => '年份 新 → 旧',
  };

  String get shortLabel => switch (this) {
    SortOrder.server => '默认顺序',
    SortOrder.titleAsc => '标题 A→Z',
    SortOrder.titleDesc => '标题 Z→A',
    SortOrder.artistAsc => '歌手 A→Z',
    SortOrder.albumAsc => '专辑 A→Z',
    SortOrder.durationAsc => '时长短→长',
    SortOrder.durationDesc => '时长长→短',
    SortOrder.yearDesc => '年份新→旧',
  };

  bool get isDefault => this == SortOrder.server;
}

String _key(String? value) => (value ?? '').trim().toLowerCase();

List<Song> sortSongs(Iterable<Song> songs, SortOrder order) {
  final list = songs.toList();
  switch (order) {
    case SortOrder.server:
      return list;
    case SortOrder.titleAsc:
      list.sort((a, b) => _key(a.title).compareTo(_key(b.title)));
    case SortOrder.titleDesc:
      list.sort((a, b) => _key(b.title).compareTo(_key(a.title)));
    case SortOrder.artistAsc:
      list.sort((a, b) {
        final byArtist = _key(a.artist).compareTo(_key(b.artist));
        if (byArtist != 0) return byArtist;
        return (a.track ?? 0).compareTo(b.track ?? 0);
      });
    case SortOrder.albumAsc:
      list.sort((a, b) {
        final byAlbum = _key(a.album).compareTo(_key(b.album));
        if (byAlbum != 0) return byAlbum;
        return (a.track ?? 0).compareTo(b.track ?? 0);
      });
    case SortOrder.durationAsc:
      list.sort((a, b) => a.duration.compareTo(b.duration));
    case SortOrder.durationDesc:
      list.sort((a, b) => b.duration.compareTo(a.duration));
    case SortOrder.yearDesc:
      list.sort((a, b) {
        final byYear = (b.year ?? 0).compareTo(a.year ?? 0);
        if (byYear != 0) return byYear;
        return (a.track ?? 0).compareTo(b.track ?? 0);
      });
  }
  return list;
}

List<Album> sortAlbums(Iterable<Album> albums, SortOrder order) {
  final list = albums.toList();
  switch (order) {
    case SortOrder.server:
      return list;
    case SortOrder.titleAsc:
    case SortOrder.durationAsc:
    case SortOrder.durationDesc:
      list.sort((a, b) => _key(a.name).compareTo(_key(b.name)));
    case SortOrder.titleDesc:
      list.sort((a, b) => _key(b.name).compareTo(_key(a.name)));
    case SortOrder.artistAsc:
      list.sort((a, b) => _key(a.artist).compareTo(_key(b.artist)));
    case SortOrder.albumAsc:
      list.sort((a, b) => _key(a.name).compareTo(_key(b.name)));
    case SortOrder.yearDesc:
      list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
  }
  return list;
}

List<Artist> sortArtists(Iterable<Artist> artists, SortOrder order) {
  final list = artists.toList();
  switch (order) {
    case SortOrder.server:
      return list;
    case SortOrder.titleDesc:
      list.sort((a, b) => _key(b.name).compareTo(_key(a.name)));
    case SortOrder.titleAsc:
    case SortOrder.artistAsc:
    case SortOrder.albumAsc:
    case SortOrder.durationAsc:
    case SortOrder.durationDesc:
    case SortOrder.yearDesc:
      list.sort((a, b) => _key(a.name).compareTo(_key(b.name)));
  }
  return list;
}
