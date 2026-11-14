import 'dart:convert';

/// 一台音乐服务器的配置。
///
/// 出于安全考虑不保存明文密码，只保留 Subsonic token 认证所需的
/// `salt` 与 `token`（t = md5(password + salt)）。
class ServerConfig {
  const ServerConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.baseUrl,
    this.fallbackUrl = '',
    this.username = '',
    this.salt = '',
    this.token = '',
    this.createdAt,
    this.serverVersion,
  });

  /// subsonic / demo
  final String type;
  final String id;
  final String name;
  final String baseUrl;

  /// 备用线路：内网/外网切换时使用，可为空。
  final String fallbackUrl;

  final String username;
  final String salt;
  final String token;
  final DateTime? createdAt;
  final String? serverVersion;

  bool get isDemo => type == 'demo';
  bool get hasFallback => fallbackUrl.trim().isNotEmpty;

  Map<String, String> get authParams => {
    'u': username,
    't': token,
    's': salt,
    'v': '1.16.1',
    'c': 'YingHua',
    'f': 'json',
  };

  ServerConfig copyWith({
    String? name,
    String? baseUrl,
    String? fallbackUrl,
    String? username,
    String? salt,
    String? token,
    String? serverVersion,
  }) {
    return ServerConfig(
      id: id,
      type: type,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      fallbackUrl: fallbackUrl ?? this.fallbackUrl,
      username: username ?? this.username,
      salt: salt ?? this.salt,
      token: token ?? this.token,
      createdAt: createdAt,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'baseUrl': baseUrl,
    'fallbackUrl': fallbackUrl,
    'username': username,
    'salt': salt,
    'token': token,
    'createdAt': createdAt?.toIso8601String(),
    'serverVersion': serverVersion,
  };

  static ServerConfig fromJson(Map<String, dynamic> json) => ServerConfig(
    id: '${json['id']}',
    type: (json['type'] as String?) ?? 'subsonic',
    name: (json['name'] as String?) ?? '音乐服务器',
    baseUrl: (json['baseUrl'] as String?) ?? '',
    fallbackUrl: (json['fallbackUrl'] as String?) ?? '',
    username: (json['username'] as String?) ?? '',
    salt: (json['salt'] as String?) ?? '',
    token: (json['token'] as String?) ?? '',
    createdAt: DateTime.tryParse('${json['createdAt']}'),
    serverVersion: json['serverVersion'] as String?,
  );

  static String encodeList(List<ServerConfig> servers) =>
      jsonEncode(servers.map((e) => e.toJson()).toList());

  static List<ServerConfig> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => ServerConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
