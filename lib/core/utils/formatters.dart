/// 通用格式化工具。
class Fmt {
  Fmt._();

  /// 03:45 / 1:02:03
  static String duration(Duration? d) {
    if (d == null || d.inMilliseconds <= 0) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String clock(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String bitRate(int? bps) {
    if (bps == null || bps <= 0) return '';
    if (bps >= 1000) return '${(bps / 1000).round()} kbps';
    return '$bps kbps';
  }

  /// 歌词校准偏移：`+1:05.5` / `-12.5s` / `0.0s`。
  static String lyricOffset(int ms) {
    final sign = ms < 0 ? '-' : (ms > 0 ? '+' : '');
    final abs = ms.abs();
    final minutes = abs ~/ 60000;
    final seconds = (abs % 60000) / 1000;
    if (minutes > 0) {
      return '$sign$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
    }
    return '$sign${seconds.toStringAsFixed(1)}s';
  }

  /// 2024-03-18
  static String date(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String relativeDay(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '$diff 天前';
    return date(d);
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return '夜深了';
    if (h < 9) return '早上好';
    if (h < 12) return '上午好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    if (h < 23) return '晚上好';
    return '夜深了';
  }

  static String count(int n, String unit) => '$n $unit';
}
