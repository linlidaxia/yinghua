import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/url_utils.dart';
import '../data/models/library_models.dart';

/// 「边听边存」缓存管理。
///
/// just_audio 的 LockCachingAudioSource 会把播放过的字节顺序写入磁盘，
/// 写入完成后可离线直接读取；此处负责定位缓存文件与容量回收。
class AudioCache {
  AudioCache._();

  static Directory? _dir;

  static Future<Directory?> _ensureDir() async {
    if (kIsWeb) return null;
    final cached = _dir;
    if (cached != null && await cached.exists()) return cached;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}audio_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  static Future<File?> fileFor(Song song) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    final name = UrlUtils.safeFileName(
      '${song.serverId ?? 'local'}_${song.id}',
    );
    return File('${dir.path}${Platform.pathSeparator}$name.audio');
  }

  static Future<int> totalBytes() async {
    final dir = await _ensureDir();
    if (dir == null) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// 超过容量上限时按最近修改时间回收。
  static Future<void> prune({int maxBytes = 1500 * 1024 * 1024}) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.audio')) {
        files.add(entity);
      }
    }
    var total = 0;
    final stats = <({File file, int size, DateTime modified})>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        total += stat.size;
        stats.add((file: file, size: stat.size, modified: stat.modified));
      } catch (_) {}
    }
    if (total <= maxBytes) return;
    stats.sort((a, b) => a.modified.compareTo(b.modified));
    for (final item in stats) {
      if (total <= maxBytes) break;
      try {
        await item.file.delete();
        total -= item.size;
      } catch (_) {}
    }
  }

  static Future<void> clear() async {
    final dir = await _ensureDir();
    if (dir == null) return;
    await for (final entity in dir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }
}
