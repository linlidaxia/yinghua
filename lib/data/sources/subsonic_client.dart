import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/utils/charset_support.dart';
import '../../core/utils/url_utils.dart';
import '../models/server_config.dart';
import 'music_source.dart';

/// Subsonic / OpenSubsonic 协议客户端（Navidrome、Airsonic、Gonic 等）。
///
/// 认证使用 token 方案，不传输明文密码；支持「主线路 + 备用线路」自动故障转移。
class SubsonicClient {
  SubsonicClient(this.config, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 12),
              headers: {'Accept': 'application/json'},
              followRedirects: true,
              maxRedirects: 3,
            ),
          );

  final ServerConfig config;
  final Dio _dio;
  String? _preferredBase;

  List<String> get _bases {
    final list = <String>[
      UrlUtils.normalizeBase(config.baseUrl),
      if (config.hasFallback) UrlUtils.normalizeBase(config.fallbackUrl),
    ].where((e) => e.isNotEmpty).toList();
    final preferred = _preferredBase;
    if (preferred != null && list.contains(preferred)) {
      list.remove(preferred);
      list.insert(0, preferred);
    }
    return list;
  }

  String get activeBase => _preferredBase ?? _bases.first;
  bool get usingFallback =>
      config.hasFallback &&
      activeBase == UrlUtils.normalizeBase(config.fallbackUrl);

  Uri uri(String endpoint, [Map<String, String>? params]) {
    final query = <String, String>{...config.authParams, ...?params};
    return Uri.parse('$activeBase/rest/$endpoint.view')
        .replace(queryParameters: query);
  }

  /// 发起请求。网络层失败时自动尝试备用线路；
  /// 只要服务器返回了合法的 Subsonic 响应，就固定使用该线路。
  Future<Map<String, dynamic>> call(
    String endpoint, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    MusicSourceException? failure;

    for (final base in _bases) {
      Response<List<int>> response;
      try {
        response = await _dio.get<List<int>>(
          '$base/rest/$endpoint.view',
          queryParameters: {...config.authParams, ...?params},
          options: Options(
            // 先取字节，再按 BOM / charset / GBK 等规则解码，
            // 避免 GBK 服务端的标题与歌词变成乱码。
            responseType: ResponseType.bytes,
            receiveTimeout: timeout,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      } on DioException catch (error) {
        failure = MusicSourceException(_networkMessage(error));
        continue;
      } catch (error) {
        failure = MusicSourceException('请求失败：$error');
        continue;
      }

      // 到这里说明线路可达，后续只在当前线路上处理结果。
      _preferredBase = base;
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw MusicSourceException('登录状态已失效，请重新输入密码连接', isAuthError: true);
      }
      if (status >= 400) {
        throw MusicSourceException('服务器返回 HTTP $status，请检查服务地址');
      }

      final body = CharsetSupport.decode(
        response.data ?? const <int>[],
        contentType: response.headers.value(Headers.contentTypeHeader),
      ).trim();
      if (body.isEmpty) {
        throw MusicSourceException('服务器没有返回内容，请确认地址指向 Subsonic 服务');
      }
      if (body.startsWith('<')) {
        throw MusicSourceException(
          '返回的是网页而非音乐接口，请确认地址为 Navidrome / Subsonic 的服务器根地址',
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        throw MusicSourceException('无法解析服务器响应，请确认服务器支持 JSON 输出');
      }
      if (decoded is! Map) {
        throw MusicSourceException('服务器响应格式不正确');
      }
      final envelope =
          decoded['subsonic-response'] ?? decoded['SubsonicResponse'];
      if (envelope is! Map) {
        throw MusicSourceException('不是有效的 Subsonic 响应，请核对服务器地址');
      }
      final sub = Map<String, dynamic>.from(envelope);
      if ('${sub['status']}' != 'ok') {
        throw _mapError(sub);
      }
      return sub;
    }

    throw failure ?? MusicSourceException('无法连接到服务器');
  }

  MusicSourceException _mapError(Map<String, dynamic> sub) {
    final error = sub['error'];
    final code = error is Map ? (error['code'] as num?)?.toInt() : null;
    final rawMessage = error is Map ? '${error['message'] ?? ''}'.trim() : '';
    switch (code) {
      case 10:
        return MusicSourceException('请求缺少必要参数，请检查服务器版本', code: code);
      case 20:
        return MusicSourceException('客户端与服务器版本不兼容', code: code);
      case 30:
        return MusicSourceException('服务器版本过旧，请升级 Navidrome', code: code);
      case 40:
        return MusicSourceException('用户名或密码不正确', code: code, isAuthError: true);
      case 41:
        return MusicSourceException('服务器不支持 token 登录，请升级服务端', code: code);
      case 50:
        return MusicSourceException('当前账号没有访问权限', code: code);
      case 70:
        return MusicSourceException('没有找到对应的内容', code: code);
      default:
        return MusicSourceException(
          rawMessage.isEmpty
              ? '服务器返回错误${code == null ? '' : '（$code）'}'
              : rawMessage,
          code: code,
        );
    }
  }

  String _networkMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _ipv6Hint('连接超时，请检查地址与服务是否可访问');
      case DioExceptionType.badCertificate:
        return 'HTTPS 证书校验失败，可尝试使用 http 地址';
      case DioExceptionType.connectionError:
        return _ipv6Hint('无法连接服务器，请确认服务已启动且处于同一网络');
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return _ipv6Hint('网络请求失败，请检查服务器地址');
    }
  }

  bool get _isIpv6 => Uri.tryParse(activeBase)?.host.contains(':') ?? false;

  String _ipv6Hint(String message) {
    if (!_isIpv6) return message;
    return '$message（当前地址为 IPv6，请确认手机已获取 IPv6 网络，'
        '且路由器 / 防火墙放行该端口）';
  }

  /// 登录探活：成功后返回带 token 的配置。
  static Future<ServerConfig> probe({
    required String baseUrl,
    required String fallbackUrl,
    required String username,
    required String password,
    String? displayName,
  }) async {
    final base = UrlUtils.normalizeBase(baseUrl);
    if (!UrlUtils.isValidBase(base)) {
      throw MusicSourceException('请输入有效的服务器地址，例如 http://192.168.1.8:4533');
    }
    if (username.trim().isEmpty) {
      throw MusicSourceException('请输入用户名');
    }
    if (password.isEmpty) {
      throw MusicSourceException('请输入密码');
    }

    final salt = UrlUtils.makeSalt();
    final config = ServerConfig(
      id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
      type: 'subsonic',
      name: (displayName == null || displayName.trim().isEmpty)
          ? UrlUtils.hostOf(base)
          : displayName.trim(),
      baseUrl: base,
      fallbackUrl: UrlUtils.normalizeBase(fallbackUrl),
      username: username.trim(),
      salt: salt,
      token: UrlUtils.tokenFor(password, salt),
      createdAt: DateTime.now(),
    );

    final client = SubsonicClient(config);
    final response = await client.call(
      'ping',
      timeout: const Duration(seconds: 15),
    );
    return config.copyWith(serverVersion: '${response['version'] ?? ''}');
  }
}
