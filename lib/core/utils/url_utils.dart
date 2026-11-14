import 'dart:math';

import 'package:crypto/crypto.dart';

import 'dart:convert';

class UrlUtils {
  UrlUtils._();

  /// 容错处理用户输入：补全协议、去掉尾部斜杠与误粘贴的 /rest。
  static String normalizeBase(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    s = _fixBareIpv6(s);
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('/rest')) {
      s = s.substring(0, s.length - 5);
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  /// IPv6 字面量在 URL 中必须带方括号。
  ///
  /// 用户经常直接粘贴 `2409:8a62:...:4533`（八段地址 + 端口）或
  /// `[2409:8a62::1]:4533`，这里统一补齐方括号，避免 Uri 解析失败。
  static String _fixBareIpv6(String url) {
    final schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) return url;
    final prefix = url.substring(0, schemeEnd + 3);
    final body = url.substring(schemeEnd + 3);
    if (body.isEmpty || body.startsWith('[')) return url;

    final slash = body.indexOf('/');
    var host = slash >= 0 ? body.substring(0, slash) : body;
    final rest = slash >= 0 ? body.substring(slash) : '';
    final at = host.lastIndexOf('@');
    if (at >= 0) host = host.substring(at + 1);

    final parts = host.split(':');
    if (parts.length < 3) return url;
    if (!RegExp(r'^[0-9a-fA-F:.%]+$').hasMatch(host)) return url;

    // 八段 IPv6 + 端口（共 9 段）时，最后一段是端口。
    var address = host;
    var port = '';
    if (parts.length == 9 && RegExp(r'^\d{1,5}$').hasMatch(parts.last)) {
      address = parts.sublist(0, 8).join(':');
      port = parts.last;
    }
    final head = at >= 0
        ? url.substring(schemeEnd + 3, schemeEnd + 3 + at + 1)
        : '';
    return '$prefix$head[$address]${port.isEmpty ? '' : ':$port'}$rest';
  }

  static bool isValidBase(String input) {
    final s = normalizeBase(input);
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) return false;
    return true;
  }

  static String hostOf(String url) {
    final uri = Uri.tryParse(normalizeBase(url));
    if (uri == null) return url;
    // IPv6 需要方括号才便于阅读与再次拼装 URL。
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return uri.hasPort ? '$host:${uri.port}' : host;
  }

  /// Subsonic token 认证：t = md5(password + salt)
  static String tokenFor(String password, String salt) {
    return md5.convert(utf8.encode('$password$salt')).toString();
  }

  static String makeSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(10, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '').substring(0, 12);
  }

  /// 去掉扩展名以外的非法字符，作为缓存文件名。
  static String safeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    if (cleaned.length <= 80) return cleaned;
    return cleaned.substring(0, 80);
  }
}
