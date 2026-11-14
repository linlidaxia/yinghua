import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/utils/charset_support.dart';
import '../../core/utils/lyric_parser.dart';
import '../../core/utils/url_template.dart';
import '../models/library_models.dart';
import '../models/lyric.dart';

/// 在线歌词补全（LRCLIB）。
///
/// 服务器自带歌词（OpenSubsonic `getLyricsBySongId` / `getLyrics`）缺失时，
/// 再去公开的 LRCLIB 曲库取一次，口径与主流播放器一致：
/// 1. `/api/get` 用「歌手 + 曲名 + 专辑 + 时长」精确匹配；
/// 2. 未命中再 `/api/search` 模糊搜索，优先取带时间轴的那一条。
///
/// 纯公共接口、无需 Key；失败时静默返回 null，不影响播放。
class OnlineLyrics {
  OnlineLyrics._();

  static const String _host = 'https://lrclib.net';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'YingHua/1.0 (Subsonic music player)',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// 内存缓存，避免同一首歌反复请求（切歌、反复打开歌词页）。
  static final Map<String, Lyric?> _cache = {};

  static Future<Lyric?> fetch(
    Song song, {
    String customTemplate = '',
    bool useOnline = true,
  }) async {
    final key =
        '$customTemplate|$useOnline|${song.title}|${song.artist}|${song.album}|${song.duration.inSeconds}';
    if (_cache.containsKey(key)) return _cache[key];

    final title = song.title.trim();
    if (title.isEmpty) return null;
    final artist = (song.artist ?? '').trim();

    Lyric? result;
    if (customTemplate.isNotEmpty) {
      try {
        result = await _fromTemplate(customTemplate, song);
      } catch (_) {
        result = null;
      }
    }
    if (result == null && useOnline) {
      try {
        result = await _get(title, artist, song);
      } catch (_) {
        result = null;
      }
      if (result == null && artist.isNotEmpty) {
        try {
          result = await _search(title, artist);
        } catch (_) {
          result = null;
        }
      }
    }
    if (!_usable(result)) result = null;
    _cache[key] = result;
    return result;
  }

  static bool _usable(Lyric? lyric) =>
      lyric != null && !lyric.isEmpty && !lyric.isCorrupted;

  /// 自定义歌词接口：LRC 文本或 JSON 均可。
  static Future<Lyric?> _fromTemplate(String template, Song song) async {
    final url = UrlTemplate.expand(template, {
      'id': song.id,
      'title': song.title,
      'artist': song.artist ?? '',
      'album': song.album ?? '',
      'duration': '${song.duration.inSeconds}',
    });
    if (url == null) return null;

    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final body = CharsetSupport.decodeLyric(
      response.data ?? const <int>[],
      contentType: response.headers.value(Headers.contentTypeHeader),
    ).trim();
    if (body.isEmpty) return null;

    final text = _lyricText(body);
    if (text == null || text.trim().isEmpty) return null;

    final lyric = LyricParser.fromLrcText(text) ?? LyricParser.fromPlain(text);
    if (lyric == null || lyric.isEmpty || lyric.isCorrupted) return null;
    return Lyric(
      lines: lyric.lines,
      synced: lyric.synced,
      source: '自定义接口',
      offset: lyric.offset,
    );
  }

  /// 从 JSON / 纯文本里取出歌词正文。
  static String? _lyricText(String body) {
    final head = body.substring(0, 1);
    if (head != '{' && head != '[') return body;
    try {
      final decoded = jsonDecode(body);
      return _findLyric(decoded);
    } catch (_) {
      return body;
    }
  }

  static String? _findLyric(Object? node, [int depth = 0]) {
    if (depth > 3 || node == null) return null;
    if (node is String) {
      return node.trim().isEmpty ? null : node;
    }
    if (node is List) {
      for (final item in node) {
        final found = _findLyric(item, depth + 1);
        if (found != null) return found;
      }
      return null;
    }
    if (node is Map) {
      const keys = ['lrc', 'lyric', 'lyrics', 'text', 'content', 'lyricText'];
      for (final key in keys) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
      for (final key in ['data', 'result', 'song', 'track']) {
        final found = _findLyric(node[key], depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static Future<Lyric?> _get(String title, String artist, Song song) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_host/api/get',
      queryParameters: {
        'track_name': title,
        if (artist.isNotEmpty) 'artist_name': artist,
        if ((song.album ?? '').trim().isNotEmpty)
          'album_name': song.album!.trim(),
        if (song.duration.inSeconds > 0)
          'duration': '${song.duration.inSeconds}',
      },
    );
    if (response.statusCode == 404) return null;
    final data = response.data;
    if (data == null) return null;
    return _parse(data);
  }

  static Future<Lyric?> _search(String title, String artist) async {
    final response = await _dio.get<List<dynamic>>(
      '$_host/api/search',
      queryParameters: {'track_name': title, 'artist_name': artist},
    );
    final data = response.data;
    if (data == null || data.isEmpty) return null;

    Lyric? unsynced;
    for (final raw in data) {
      if (raw is! Map) continue;
      final lyric = _parse(Map<String, dynamic>.from(raw));
      if (lyric == null) continue;
      if (lyric.synced) return lyric;
      unsynced ??= lyric;
    }
    return unsynced;
  }

  static Lyric? _parse(Map<String, dynamic> json) {
    final synced = '${json['syncedLyrics'] ?? ''}'.trim();
    if (synced.isNotEmpty) {
      final lyric = LyricParser.fromLrcText(synced);
      if (lyric != null && !lyric.isEmpty && !lyric.isCorrupted) {
        return Lyric(
          lines: lyric.lines,
          synced: lyric.synced,
          source: 'LRCLIB',
          offset: lyric.offset,
        );
      }
    }
    final plain = '${json['plainLyrics'] ?? ''}'.trim();
    if (plain.isNotEmpty) {
      final lyric = LyricParser.fromPlain(plain);
      if (lyric != null && !lyric.isEmpty && !lyric.isCorrupted) {
        return Lyric(lines: lyric.lines, synced: false, source: 'LRCLIB');
      }
    }
    return null;
  }
}
