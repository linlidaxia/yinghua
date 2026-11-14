import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/artwork_url.dart';

/// 封面磁盘缓存。
///
/// 服务器封面（尤其是 Navidrome 的 `getCoverArt`）每次进页面都重新下载会很慢，
/// 这里按 URL 做内容哈希落盘，第二次进入列表 / 播放页即可秒开，也支持离线显示。
class CoverCache {
  CoverCache._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: true,
      maxRedirects: 3,
      headers: const {'Accept': 'image/*'},
    ),
  );

  static const int _maxFiles = 1200;

  static Directory? _dir;
  static bool _pruned = false;
  static final Map<String, Future<File?>> _inflight = {};

  static Future<Directory?> _ensureDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}covers');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// 取封面文件；失败返回 null，由调用方回退到占位图 / 网络图片。
  static Future<File?> load(String url) {
    return _inflight.putIfAbsent(url, () => _load(url));
  }

  static Future<File?> _load(String url) async {
    final dir = await _ensureDir();
    if (dir == null) return null;

    final name = md5.convert(utf8.encode(url)).toString();
    final file = File('${dir.path}${Platform.pathSeparator}$name.img');
    try {
      if (await file.exists() && await file.length() > 512) return file;
    } catch (_) {
      // 忽略读失败，继续重新下载。
    }

    try {
      final bytes = await _download(url);
      if (bytes == null || bytes.length < 512) return null;
      await file.writeAsBytes(bytes, flush: true);
      if (!_pruned) {
        _pruned = true;
        // 缓存目录只保留最近的若干张，避免无限增长；不阻塞首帧。
        Future<void>(() => _prune(dir));
      }
      return file;
    } catch (_) {
      _inflight.remove(url);
      return null;
    }
  }

  /// 先按 720 封面尺寸下载；失败则回到原始地址重试一次。
  static Future<List<int>?> _download(String url) async {
    for (final shrink in const [true, false]) {
      try {
        final bytes = await _follow(url, shrink: shrink);
        if (bytes.length > 512) return bytes;
      } catch (_) {
        // 继续尝试下一种方式。
      }
    }
    return null;
  }

  /// 手动跟随 3xx：封面接口常 302 到 Apple 图床，顺手把尺寸降到 720。
  static Future<List<int>> _follow(String url, {required bool shrink}) async {
    var target = url;
    for (var hop = 0; hop < 4; hop++) {
      final response = await _dio.get<List<int>>(
        target,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (status >= 300 &&
          status < 400 &&
          location != null &&
          location.isNotEmpty) {
        final next = ArtworkUrl.resolve(target, location);
        target = shrink ? ArtworkUrl.shrink(next) : next;
        continue;
      }
      if (status != 200) {
        throw DioException(
          requestOptions: RequestOptions(path: target),
          message: '封面接口返回 HTTP $status',
        );
      }
      return response.data ?? const <int>[];
    }
    throw DioException(
      requestOptions: RequestOptions(path: url),
      message: '封面接口重定向次数过多',
    );
  }

  static Future<void> _prune(Directory dir) async {
    try {
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (files.length <= _maxFiles) return;
      final stats = <MapEntry<File, DateTime>>[];
      for (final file in files) {
        try {
          stats.add(MapEntry(file, (await file.stat()).modified));
        } catch (_) {
          // 忽略个别文件的状态读取失败。
        }
      }
      stats.sort((a, b) => a.value.compareTo(b.value));
      final removeCount = stats.length - _maxFiles;
      for (var i = 0; i < removeCount; i++) {
        try {
          await stats[i].key.delete();
        } catch (_) {
          // 删除失败不影响播放。
        }
      }
    } catch (_) {
      // 清理失败可以忽略。
    }
  }

  /// 清空封面缓存（设置页「清理缓存」时调用）。
  static Future<void> clear() async {
    _inflight.clear();
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      await for (final entry in dir.list()) {
        if (entry is File) await entry.delete();
      }
    } catch (_) {
      // 忽略。
    }
  }

  static Future<int> totalBytes() async {
    final dir = await _ensureDir();
    if (dir == null) return 0;
    var total = 0;
    try {
      await for (final entry in dir.list()) {
        if (entry is File) {
          try {
            total += await entry.length();
          } catch (_) {
            // 忽略。
          }
        }
      }
    } catch (_) {
      // 忽略。
    }
    return total;
  }
}
