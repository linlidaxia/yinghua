/// 一行歌词。
class LyricLine {
  const LyricLine({required this.at, required this.text});
  final Duration at;
  final String text;
}

/// 歌词。synced 为 false 时按纯文本逐行展示。
class Lyric {
  const Lyric({
    required this.lines,
    this.synced = true,
    this.source,
    this.offset = 0,
  });

  final List<LyricLine> lines;
  final bool synced;
  final String? source;

  /// 额外偏移（毫秒），正值表示歌词延后出现。
  final int offset;

  bool get isEmpty =>
      lines.isEmpty || lines.every((l) => l.text.trim().isEmpty);

  /// 服务器把非 UTF-8 的歌词文件按 UTF-8 读取时，内容会变成大量 U+FFFD（�），
  /// 这类损坏不可逆，直接当作「没有歌词」，交给在线 / 自定义接口补全。
  bool get isCorrupted {
    if (lines.isEmpty) return false;
    var bad = 0;
    var total = 0;
    for (final line in lines) {
      for (final rune in line.text.runes) {
        total++;
        if (rune == 0xFFFD) bad++;
      }
    }
    if (total == 0) return false;
    return bad >= 2 && bad * 8 >= total;
  }

  Duration effectiveTime(LyricLine line) =>
      line.at + Duration(milliseconds: offset);

  /// 当前行下标；-1 表示还没到第一行。
  int indexAt(Duration position, {int offsetMs = 0}) {
    if (!synced || lines.isEmpty) return -1;
    final t = position.inMilliseconds + offsetMs;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final at = lines[mid].at.inMilliseconds;
      if (at <= t) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  Lyric withOffset(int offsetMs) =>
      Lyric(lines: lines, synced: synced, source: source, offset: offsetMs);
}
