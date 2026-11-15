import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_version.dart';
import '../local/settings_store.dart';

/// 更新检测 / 下载失败时抛出的可读异常。
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// GitHub 上的一个可安装版本。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.apkUrl,
    required this.apkName,
    required this.apkSize,
    required this.htmlUrl,
    this.publishedAt,
    this.sha256 = '',
  });

  /// 去掉 tag 前缀的版本号，例如 `1.0.20`。
  final String version;
  final String tag;
  final String notes;
  final String apkUrl;
  final String apkName;
  final int apkSize;
  final String htmlUrl;
  final DateTime? publishedAt;

  /// Release 说明里的 SHA-256（`tool/release.ps1` 会写入），为空表示发布者没提供。
  final String sha256;

  double get sizeMb => apkSize / (1024 * 1024);

  static UpdateInfo? fromRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    if (tag.isEmpty) return null;
    final version = AppVersion.normalize(tag);

    final assets = json['assets'];
    Map<String, dynamic>? apk;
    if (assets is List) {
      for (final item in assets) {
        if (item is! Map) continue;
        final name = (item['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk')) {
          apk = Map<String, dynamic>.from(item);
          break;
        }
      }
    }
    if (apk == null) return null;

    final url = (apk['browser_download_url'] as String?) ?? '';
    if (url.isEmpty) return null;

    DateTime? published;
    final rawDate = json['published_at'] as String?;
    if (rawDate != null) published = DateTime.tryParse(rawDate);

    final notes = (json['body'] as String?)?.trim() ?? '';
    final hash = RegExp(
      r'SHA-?256\s*[:：]?\s*([0-9a-fA-F]{64})',
      caseSensitive: false,
    ).firstMatch(notes);

    return UpdateInfo(
      version: version,
      tag: tag,
      notes: notes,
      apkUrl: url,
      apkName: (apk['name'] as String?) ?? 'yinghua-$version.apk',
      apkSize: (apk['size'] as num?)?.toInt() ?? 0,
      htmlUrl: (json['html_url'] as String?) ?? '',
      publishedAt: published,
      sha256: hash?.group(1)?.toLowerCase() ?? '',
    );
  }
}

/// 更新检测与下载。
///
/// 更新源是公开的 GitHub Release（`settings.updateRepo`），
/// 使用 `/releases/latest` 免登录读取；下载完成的 APK 放在应用缓存目录，
/// 再通过原生 FileProvider 交给系统安装器。
class UpdateService {
  UpdateService({required this.settings, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'yinghua-app',
              },
            ),
          );

  final SettingsStore settings;
  final Dio _dio;

  static const MethodChannel _channel = MethodChannel(
    'com.yinghua.yinghua/update',
  );

  /// 公共 GitHub 加速镜像（前缀 + 原始资源地址）。
  /// 直连很慢或完全不通时按顺序尝试，下载后会校验大小 / 文件头 / SHA-256。
  static const List<String> _mirrorPrefixes = [
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
    'https://ghproxy.imciel.com/',
  ];

  /// 本次进程里上次下载成功的源，下次优先使用（避免每次都先撞慢速直连）。
  static String? _lastGoodSource;

  CancelToken? _cancelToken;
  bool _userCancelled = false;

  /// 检查最新版本；没有更新时返回 `null`。
  ///
  /// 更新源可在设置里切换：GitHub 公开 Release，或自建 JSON 清单（NAS / 对象存储）。
  Future<UpdateInfo?> checkLatest() async {
    if (settings.updateSource == 'manifest') return checkManifest();
    return _checkGitHub();
  }

  /// 读取自建清单：`{version, notes, apk, sha256, size}`。
  ///
  /// `apk` 可以是相对清单地址的文件名，也可以是完整 URL（含 IPv6 地址）。
  /// 清单放在 NAS 上时，App 直接从 NAS 下载，不经过 GitHub。
  Future<UpdateInfo?> checkManifest([String? overrideUrl]) async {
    final raw = (overrideUrl ?? settings.updateManifestUrl).trim();
    if (raw.isEmpty) {
      throw const UpdateException('还没有填写更新清单地址');
    }
    final manifestUri = Uri.tryParse(raw);
    if (manifestUri == null || !manifestUri.hasScheme) {
      throw const UpdateException('更新清单地址格式不对，需要以 http:// 或 https:// 开头');
    }

    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        raw,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 20),
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) throw const UpdateException('清单地址不存在（404）');
      throw UpdateException('无法连接更新服务器：${_networkMessage(error)}');
    }

    final data = response.data;
    if (data is! Map) {
      throw const UpdateException('清单返回的不是 JSON 对象');
    }
    final map = Map<String, dynamic>.from(data);
    final inner = map['latest'];
    final body = inner is Map ? Map<String, dynamic>.from(inner) : map;

    final version = AppVersion.normalize((body['version'] as String?) ?? '');
    if (version.isEmpty || version == '0') {
      throw const UpdateException('清单里没有 version 字段');
    }
    final apkRaw = ((body['apk'] as String?) ?? (body['url'] as String?) ?? '')
        .trim();
    if (apkRaw.isEmpty) {
      throw const UpdateException('清单里没有 apk 字段');
    }
    final apkUri = manifestUri.resolve(apkRaw);
    final notes =
        ((body['notes'] as String?) ??
                (body['changelog'] as String?) ??
                (body['body'] as String?) ??
                '')
            .trim();

    final info = UpdateInfo(
      version: version,
      tag: (body['tag'] as String?) ?? 'v$version',
      notes: notes,
      apkUrl: apkUri.toString(),
      apkName: apkUri.pathSegments.isEmpty
          ? 'yinghua-$version.apk'
          : apkUri.pathSegments.last,
      apkSize: (body['size'] as num?)?.toInt() ?? 0,
      htmlUrl: raw,
      publishedAt: DateTime.tryParse((body['published_at'] as String?) ?? ''),
      sha256: ((body['sha256'] as String?) ?? '').toLowerCase(),
    );
    if (!AppVersion.isNewer(info.version, AppVersion.current)) return null;
    return info;
  }

  Future<UpdateInfo?> _checkGitHub() async {
    final repo = settings.updateRepo.trim();
    if (repo.isEmpty) {
      throw const UpdateException('还没有设置更新源');
    }
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        'https://api.github.com/repos/$repo/releases/latest',
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) {
        throw const UpdateException('更新源没有可用的 Release（仓库不存在或为私有）');
      }
      if (status == 403) {
        throw const UpdateException('GitHub 接口请求过于频繁，请稍后再试');
      }
      throw UpdateException('无法连接 GitHub：${_networkMessage(error)}');
    }

    final data = response.data;
    if (data is! Map) {
      throw const UpdateException('更新源返回了无法识别的数据');
    }
    final info = UpdateInfo.fromRelease(Map<String, dynamic>.from(data));
    if (info == null) {
      throw const UpdateException('最新版本没有附带 APK');
    }
    if (!AppVersion.isNewer(info.version, AppVersion.current)) return null;
    return info;
  }

  /// 下载 APK 到缓存目录，返回本地路径。
  ///
  /// 先试 GitHub 直连：8 秒内拿不到 512 KB 就判定为「太慢」，自动切到公共加速镜像；
  /// 直连失败也逐个尝试镜像。下载完成后校验大小、APK 文件头，以及 Release 说明里的
  /// SHA-256（有就校验，能挡掉镜像返回错误内容的情况）。
  Future<String> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}updates');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File(
      '${dir.path}${Platform.pathSeparator}${info.apkName.isEmpty ? 'yinghua-${info.version}.apk' : info.apkName}',
    );

    if (await target.exists()) {
      final length = await target.length();
      if ((info.apkSize <= 0 || length == info.apkSize) &&
          await _isValidApk(target, info)) {
        return target.path;
      }
      await target.delete();
    }

    final part = File('${target.path}.part');
    final sources = _sources(info);
    _userCancelled = false;
    String? lastError;

    for (var i = 0; i < sources.length; i++) {
      final url = sources[i];
      if (await part.exists()) await part.delete();
      if (_userCancelled) throw const UpdateException('已取消下载');
      if (i > 0) onProgress?.call(0, info.apkSize);

      final direct = url == info.apkUrl;
      final ok = await _fetch(
        url,
        part,
        info,
        onProgress: onProgress,
        watchSpeed: direct && sources.length > 1,
      );
      if (!ok) {
        if (_userCancelled) throw const UpdateException('已取消下载');
        lastError = '网络错误';
        continue;
      }

      if (info.apkSize > 0 && await part.length() != info.apkSize) {
        lastError = '安装包下载不完整';
        continue;
      }
      if (!await _isValidApk(part, info)) {
        lastError = '下载到的文件不是有效的 APK';
        continue;
      }
      _lastGoodSource = url;
      await part.rename(target.path);
      return target.path;
    }

    throw UpdateException(
      lastError == null || lastError == '网络错误'
          ? '下载失败：GitHub 直连与加速镜像都不可用，请稍后重试'
          : '下载失败：$lastError，请稍后重试',
    );
  }

  /// 取消正在进行的下载（下载对话框里的「取消」）。
  void cancelDownload() {
    _userCancelled = true;
    _cancelToken?.cancel('cancelled');
  }

  /// 下载源顺序：上次成功的源优先；直连在前，镜像在后。
  List<String> _sources(UpdateInfo info) {
    final direct = info.apkUrl;
    final host = Uri.tryParse(direct)?.host ?? '';
    final isGitHub = host == 'github.com' || host.endsWith('.github.com');
    final sources = <String>[direct];
    if (settings.updateUseMirror && isGitHub) {
      for (final prefix in _mirrorPrefixes) {
        sources.add('$prefix$direct');
      }
    }
    final last = _lastGoodSource;
    if (last != null && sources.contains(last)) {
      sources
        ..remove(last)
        ..insert(0, last);
    }
    return sources;
  }

  /// 下载单个源；返回 false 表示这个源不可用，应该换下一个。
  Future<bool> _fetch(
    String url,
    File part,
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    required bool watchSpeed,
  }) async {
    final token = CancelToken();
    _cancelToken = token;
    var received = 0;
    Timer? watchdog;
    if (watchSpeed) {
      // 直连能通但只有几十 KB/s 时，等它下完要一小时，不如早点换镜像。
      watchdog = Timer(const Duration(seconds: 8), () {
        if (!token.isCancelled && received < 512 * 1024) {
          token.cancel('too-slow');
        }
      });
    }
    try {
      await _dio.download(
        url,
        part.path,
        cancelToken: token,
        onReceiveProgress: (count, total) {
          received = count;
          onProgress?.call(count, total > 0 ? total : info.apkSize);
        },
        deleteOnError: true,
        options: Options(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 45),
          headers: const {'User-Agent': 'yinghua-app'},
        ),
      );
      return true;
    } on DioException {
      // 太慢、用户取消、DNS 失败、镜像 502 都走同一条「换下一个源」的路径。
      return false;
    } finally {
      watchdog?.cancel();
      _cancelToken = null;
    }
  }

  Future<bool> _isValidApk(File file, UpdateInfo info) async {
    // APK 本质是 zip，至少校验文件头，避免把错误页面当成安装包。
    try {
      final head = await file.openRead(0, 2).first;
      if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
        return false;
      }
      if (info.sha256.isEmpty) return true;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == info.sha256.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// 系统是否允许本应用安装 APK（Android 8+ 需要用户授权）。
  Future<bool> canInstall() async {
    if (!Platform.isAndroid) return true;
    try {
      final value = await _channel.invokeMethod<bool>('canInstall');
      return value ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 打开「安装未知应用」授权页。
  Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // 系统页面不可用时忽略。
    }
  }

  /// 交给系统安装器；返回 false 表示需要先授权。
  Future<bool> install(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      final value = await _channel.invokeMethod<bool>('installApk', {
        'path': path,
      });
      return value ?? false;
    } on PlatformException {
      return false;
    }
  }

  String _networkMessage(DioException error) {
    // 优先给中文原因：dio 的 message 是英文，直接显示对用户没帮助。
    return switch (error.type) {
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.sendTimeout => '发送超时',
      DioExceptionType.receiveTimeout => '服务器响应超时',
      DioExceptionType.connectionError => '无法连接（地址或端口不可达）',
      DioExceptionType.badResponse =>
        '服务器返回 ${error.response?.statusCode ?? '错误'}',
      DioExceptionType.cancel => '请求已取消',
      _ => '网络错误',
    };
  }
}
