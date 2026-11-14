import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/audio_format.dart';
import '../../core/utils/url_utils.dart';
import '../models/library_models.dart';
import '../sources/music_source.dart';
import 'settings_store.dart';

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadedTrack {
  const DownloadedTrack({
    required this.song,
    required this.path,
    required this.bytes,
    required this.downloadedAt,
    this.coverPath,
  });

  final Song song;
  final String path;
  final int bytes;
  final DateTime downloadedAt;
  final String? coverPath;

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'path': path,
    'bytes': bytes,
    'downloadedAt': downloadedAt.toIso8601String(),
    'coverPath': coverPath,
  };

  static DownloadedTrack fromJson(Map<String, dynamic> json) {
    return DownloadedTrack(
      song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
      path: '${json['path']}',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      downloadedAt:
          DateTime.tryParse('${json['downloadedAt']}') ?? DateTime.now(),
      coverPath: json['coverPath'] as String?,
    );
  }
}

/// 离线下载：文件保存在应用私有目录，无需申请存储权限。
class DownloadManager extends ChangeNotifier {
  DownloadManager(this._settings);

  final SettingsStore _settings;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  final Map<String, DownloadedTrack> _tracks = {};
  Directory? _root;
  bool _loaded = false;

  bool _running = false;
  int _done = 0;
  int _total = 0;
  int _failed = 0;
  double _progress = 0;
  String? _currentTitle;

  List<DownloadedTrack> get tracks {
    final list = _tracks.values.toList();
    list.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return list;
  }

  bool get isLoaded => _loaded;
  bool get isRunning => _running;
  int get done => _done;
  int get total => _total;
  int get failed => _failed;
  double get progress => _progress;
  String? get currentTitle => _currentTitle;
  int get count => _tracks.length;
  int get totalBytes =>
      _tracks.values.fold(0, (sum, track) => sum + track.bytes);

  bool isDownloaded(Song song) => _tracks.containsKey(song.id);

  String? localPath(Song song) => _tracks[song.id]?.path;

  String? coverPathFor(String songId) => _tracks[songId]?.coverPath;

  Future<void> init() async {
    if (kIsWeb) {
      _loaded = true;
      return;
    }
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}${Platform.pathSeparator}downloads');
    if (!await _root!.exists()) {
      await _root!.create(recursive: true);
    }
    final indexFile = File('${_root!.path}${Platform.pathSeparator}index.json');
    if (await indexFile.exists()) {
      try {
        final data = jsonDecode(await indexFile.readAsString());
        if (data is List) {
          for (final raw in data.whereType<Map>()) {
            final track = DownloadedTrack.fromJson(
              Map<String, dynamic>.from(raw),
            );
            if (await File(track.path).exists()) {
              _tracks[track.song.id] = track;
            }
          }
        }
      } catch (_) {
        // 索引损坏时忽略，重新下载即可。
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveIndex() async {
    final root = _root;
    if (root == null) return;
    final file = File('${root.path}${Platform.pathSeparator}index.json');
    final payload = jsonEncode(_tracks.values.map((e) => e.toJson()).toList());
    await file.writeAsString(payload, flush: true);
  }

  /// 下载单曲。返回 true 表示新下载，false 表示此前已存在。
  Future<bool> download(Song song, MusicSource source) async {
    if (kIsWeb) {
      throw DownloadException('网页预览版不支持离线下载，请安装 Android 版本');
    }
    if (_tracks.containsKey(song.id)) return false;

    final root = _root;
    if (root == null) throw DownloadException('存储目录尚未准备好');

    final uri = await source.resolveStream(
      song,
      maxBitRate: _settings.maxBitRate,
    );
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw DownloadException('该音轨为本地占位音频，无需下载');
    }

    final serverId = UrlUtils.safeFileName(song.serverId ?? source.config.id);
    final dir = Directory('${root.path}${Platform.pathSeparator}$serverId');
    if (!await dir.exists()) await dir.create(recursive: true);

    // 服务端会把 wma 等无法解码的格式转成 mp3，落盘扩展名也要跟着改。
    final suffix = AudioFormat.effectiveSuffix(song.suffix);
    final safeName = UrlUtils.safeFileName(song.id);
    final target = File(
      '${dir.path}${Platform.pathSeparator}$safeName.$suffix',
    );
    final temp = File('${target.path}.part');

    _progress = 0;
    notifyListeners();

    try {
      await _dio.download(
        uri.toString(),
        temp.path,
        onReceiveProgress: (received, totalBytes) {
          if (totalBytes <= 0) return;
          final value = (received / totalBytes).clamp(0.0, 1.0);
          if ((value * 100).floor() != (_progress * 100).floor()) {
            _progress = value;
            notifyListeners();
          }
        },
      );
      if (await temp.exists()) {
        await temp.rename(target.path);
      }
    } on DioException catch (error) {
      if (await temp.exists()) await temp.delete();
      throw DownloadException(_downloadError(error));
    } catch (error) {
      if (await temp.exists()) await temp.delete();
      throw DownloadException('下载失败：$error');
    }

    String? coverPath;
    final cover = source.coverUri(song.coverArtId, size: 600);
    if (cover != null) {
      try {
        final coverFile = File(
          '${dir.path}${Platform.pathSeparator}$safeName.jpg',
        );
        await _dio.download(cover.toString(), coverFile.path);
        coverPath = coverFile.path;
      } catch (_) {
        // 封面下载失败不影响音频离线可用。
      }
    }

    final bytes = await target.length();
    _tracks[song.id] = DownloadedTrack(
      song: song,
      path: target.path,
      bytes: bytes,
      downloadedAt: DateTime.now(),
      coverPath: coverPath,
    );
    _progress = 1;
    await _saveIndex();
    notifyListeners();
    return true;
  }

  /// 批量下载，返回失败数量。串行执行以避免占满带宽与内存。
  Future<int> downloadAll(List<Song> songs, MusicSource source) async {
    if (_running) throw DownloadException('已有下载任务正在进行');
    _running = true;
    _total = songs.length;
    _done = 0;
    _failed = 0;
    _currentTitle = null;
    notifyListeners();

    for (final song in songs) {
      _currentTitle = song.title;
      notifyListeners();
      try {
        await download(song, source);
      } catch (_) {
        _failed++;
      }
      _done++;
      notifyListeners();
    }

    _running = false;
    _currentTitle = null;
    notifyListeners();
    return _failed;
  }

  Future<void> remove(Song song) async {
    final track = _tracks.remove(song.id);
    if (track == null) return;
    try {
      final file = File(track.path);
      if (await file.exists()) await file.delete();
      if (track.coverPath != null) {
        final cover = File(track.coverPath!);
        if (await cover.exists()) await cover.delete();
      }
    } catch (_) {
      // 文件已被系统清理时忽略。
    }
    await _saveIndex();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _tracks.clear();
    final root = _root;
    if (root != null && await root.exists()) {
      try {
        await root.delete(recursive: true);
      } catch (_) {}
      await root.create(recursive: true);
    }
    await _saveIndex();
    notifyListeners();
  }

  String _downloadError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return '下载超时，请检查网络';
      case DioExceptionType.connectionError:
        return '下载失败：无法连接服务器';
      case DioExceptionType.badResponse:
        return '下载失败：服务器返回 ${error.response?.statusCode}';
      default:
        return '下载失败，请稍后重试';
    }
  }
}
