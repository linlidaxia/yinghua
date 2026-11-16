/// 应用版本号与语义化版本比较。
///
/// 只保留一处定义：`pubspec.yaml`、关于页、更新检测都读这里，
/// 避免出现「关于页写 1.0.19、APK 却是 1.0.18」的不一致。
class AppVersion {
  AppVersion._();

  /// 与 `pubspec.yaml` 的 `version: X.Y.Z+BUILD` 保持一致。
  static const String current = '1.0.26';
  static const int build = 27;

  static String get display => '$current+$build';

  /// 去掉 `v` 前缀、构建号与预发布后缀：`v1.2.3+4-beta` → `1.2.3`。
  static String normalize(String version) {
    var value = version.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final cut = value.indexOf(RegExp(r'[+\-]'));
    if (cut >= 0) value = value.substring(0, cut);
    return value;
  }

  static List<int> _parts(String version) => normalize(version)
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();

  /// 比较两个版本：`a > b` 返回正数，相等返回 0，小于返回负数。
  static int compare(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// [remote] 是否比 [local] 新。
  static bool isNewer(String remote, String local) =>
      compare(remote, local) > 0;
}
