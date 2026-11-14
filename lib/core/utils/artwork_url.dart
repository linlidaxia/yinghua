/// 封面图床 URL 工具。
///
/// 很多封面接口（例如 `api.lrc.cx`）会 302 到 Apple Music 的图床，
/// 路径里带着尺寸：`.../3000x3000bb.jpg`，一张图能到 1–2 MB。
/// 列表页一次要加载十几张，这里统一降到 720，肉眼几乎无差别。
class ArtworkUrl {
  ArtworkUrl._();

  /// 允许的最大边长。
  static const int maxEdge = 720;

  static final RegExp _sizePattern = RegExp(
    r'/(\d{2,5})x(\d{2,5})(bb|ac|sr|bb-60|bb-75)\.(jpg|jpeg|png|webp)$',
    caseSensitive: false,
  );

  /// 只处理已知的 Apple 图床域名，避免改写其它接口的 URL。
  static bool _isAppleCdn(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.endsWith('mzstatic.com');
  }

  /// 把大尺寸封面降到 [maxEdge]；不认识的地址原样返回。
  static String shrink(String url) {
    if (!_isAppleCdn(url)) return url;
    final match = _sizePattern.firstMatch(url);
    if (match == null) return url;
    final width = int.tryParse(match.group(1) ?? '') ?? 0;
    final height = int.tryParse(match.group(2) ?? '') ?? 0;
    if (width <= maxEdge && height <= maxEdge) return url;
    final suffix = match.group(3);
    final ext = match.group(4);
    return url.replaceRange(
      match.start,
      match.end,
      '/${maxEdge}x$maxEdge$suffix.$ext',
    );
  }

  /// 解析 3xx 的 Location（可能是相对路径）。
  static String resolve(String base, String location) {
    final uri = Uri.tryParse(location);
    if (uri != null && uri.hasScheme) return location;
    return Uri.parse(base).resolve(location).toString();
  }
}
