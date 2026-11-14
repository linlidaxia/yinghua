import 'dart:convert';

import '../../data/models/lyric.dart';

/// 歌词解析：兼容 OpenSubsonic 结构化歌词、LRC 文本与纯文本。
class LyricParser {
  LyricParser._();

  static Lyric? fromStructured(
    List<dynamic> structured, {
    Duration songDuration = Duration.zero,
  }) {
    if (structured.isEmpty) return null;
    Map<String, dynamic>? chosen;
    for (final raw in structured) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final lines = item['line'];
      if (lines is List && lines.isNotEmpty) {
        if (chosen == null) chosen = item;
        if (item['synced'] == true) {
          chosen = item;
          break;
        }
      }
    }
    if (chosen == null) return null;

    final rawLines = (chosen['line'] as List).whereType<Map>();
    final parsed = <LyricLine>[];
    for (final l in rawLines) {
      final m = Map<String, dynamic>.from(l);
      final value = (m['value'] as String?)?.trim() ?? '';
      final startRaw = m['start'];
      final start = startRaw is num ? startRaw.toInt() : 0;
      parsed.add(
        LyricLine(
          at: Duration(milliseconds: start),
          text: value,
        ),
      );
    }
    if (parsed.isEmpty) return null;

    final synced = chosen['synced'] == true;
    // 个别服务端把 start 当作「秒」返回，做一个保守修正。
    if (synced && parsed.length > 3) {
      final maxStart = parsed
          .map((e) => e.at.inMilliseconds)
          .reduce((a, b) => a > b ? a : b);
      if (maxStart < 1000) {
        for (var i = 0; i < parsed.length; i++) {
          parsed[i] = LyricLine(
            at: Duration(milliseconds: parsed[i].at.inMilliseconds * 1000),
            text: parsed[i].text,
          );
        }
      }
    }

    if (synced) parsed.sort((a, b) => a.at.compareTo(b.at));
    final offsetRaw = chosen['offset'];
    final offset = offsetRaw is num ? offsetRaw.toInt() : 0;
    return Lyric(
      lines: parsed,
      synced: synced,
      source: 'OpenSubsonic',
      offset: offset,
    );
  }

  static Lyric? fromLrcText(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;
    final lines = const LineSplitter().convert(raw);
    final parsed = <LyricLine>[];
    var synced = false;
    final tag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final offsetTag = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);
    var offset = 0;
    for (final line in lines) {
      final offsetMatch = offsetTag.firstMatch(line);
      if (offsetMatch != null) {
        offset = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        continue;
      }
      final matches = tag.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final content = line.substring(matches.last.end).trim();
      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '') ?? 0;
        final fracRaw = m.group(3) ?? '0';
        final frac =
            int.tryParse(fracRaw.padRight(3, '0').substring(0, 3)) ?? 0;
        synced = true;
        parsed.add(
          LyricLine(
            at: Duration(milliseconds: min * 60000 + sec * 1000 + frac),
            text: content,
          ),
        );
      }
    }
    if (parsed.isEmpty) return fromPlain(text);
    parsed.sort((a, b) => a.at.compareTo(b.at));
    return Lyric(lines: parsed, synced: synced, source: 'LRC', offset: offset);
  }

  static Lyric? fromPlain(String text) {
    final raw = text.replaceAll('\r\n', '\n').trim();
    if (raw.isEmpty) return null;
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => LyricLine(at: Duration.zero, text: e))
        .toList();
    if (lines.isEmpty) return null;
    return Lyric(lines: lines, synced: false, source: '纯文本');
  }
}
