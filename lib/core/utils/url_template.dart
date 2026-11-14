/// 自定义接口 URL 模板。
///
/// 用户在设置里填写形如
/// `https://api.example.com/cover?artist={artist}&album={album}&size={size}`
/// 的模板，占位符按 URL 编码替换；未提供的占位符会被清空，避免请求里残留
/// 大括号导致的 400。
class UrlTemplate {
  UrlTemplate._();

  static final RegExp _placeholder = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}');

  /// 可用占位符（用于设置页文案）。
  static const List<String> coverKeys = [
    'id',
    'size',
    'album',
    'artist',
    'title',
  ];

  static const List<String> lyricKeys = [
    'id',
    'title',
    'artist',
    'album',
    'duration',
  ];

  /// 展开模板；模板为空或展开后不是 http(s) 地址时返回 null。
  static String? expand(String template, Map<String, String> values) {
    final raw = template.trim();
    if (raw.isEmpty) return null;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      return null;
    }
    final result = raw.replaceAllMapped(_placeholder, (match) {
      final key = match.group(1)!.toLowerCase();
      final value = values[key] ?? '';
      return Uri.encodeComponent(value.trim());
    });
    final uri = Uri.tryParse(result);
    if (uri == null || uri.host.isEmpty) return null;
    return result;
  }

  /// 模板里是否至少包含一个占位符（设置页做提示用）。
  static bool hasPlaceholder(String template) =>
      _placeholder.hasMatch(template);
}
