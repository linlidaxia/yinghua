import 'dart:convert';

import 'package:charset/charset.dart';

/// 字符集兼容层。
///
/// 自建音乐服务器的来源很杂：Navidrome 默认 UTF-8，但一些老服务端 / 本地
/// 标签会把 GBK、GB18030、UTF-16、Shift_JIS 的内容直接塞进响应体或歌词里，
/// 统一按 UTF-8 解码就会变成「乱码」。
///
/// 这里按下面的顺序判断：
/// 1. BOM（UTF-8 / UTF-16 LE / UTF-16 BE / UTF-32）；
/// 2. `Content-Type` 里的 `charset=`；
/// 3. 严格 UTF-8（失败才继续）；
/// 4. GBK / GB18030（中文服务器最常见）；
/// 5. Shift_JIS、EUC-JP、EUC-KR；
/// 6. Latin-1 兜底（永不抛异常）。
class CharsetSupport {
  CharsetSupport._();

  static final RegExp _charsetPattern = RegExp(
    r'charset\s*=\s*"?([\w\-]+)"?',
    caseSensitive: false,
  );

  static final RegExp _cjk = RegExp(
    r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\u3040-\u30FF\uAC00-\uD7AF]',
  );

  static String decode(List<int> bytes, {String? contentType}) {
    if (bytes.isEmpty) return '';

    // 1. BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _tryDecode(utf16, bytes) ??
          utf8.decode(bytes, allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _tryDecode(utf16, bytes) ??
          utf8.decode(bytes, allowMalformed: true);
    }

    // 2. 严格 UTF-8：能解就说明就是 UTF-8
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // 继续向下尝试其它字符集。
    }

    // 3. 响应头声明的字符集优先
    final declared = charsetOf(contentType);
    if (declared != null && !_isUtf8Name(declared)) {
      final encoding = Charset.getByName(declared);
      if (encoding != null) {
        final text = _tryDecode(encoding, bytes);
        if (text != null) return text;
      }
    }

    // 3. 多字节字符集需要至少两个高位字节，否则直接按 Latin-1 处理，
    //    避免把 Café、Naïve 这类西文误当成 GBK 吃字。
    var highBytes = 0;
    for (final byte in bytes) {
      if (byte >= 0x80) highBytes++;
    }
    if (highBytes < 2) {
      return latin1.decode(bytes, allowInvalid: true);
    }

    // 4. 中文服务器最常见的 GBK / GB18030
    if (_looksLikeGbk(bytes)) {
      final gbkText = _tryDecode(gbk, bytes);
      if (gbkText != null) return gbkText;
    }

    // 5. 日文 / 韩文
    for (final encoding in const [shiftJis, eucJp, eucKr]) {
      final text = _tryDecode(encoding, bytes);
      if (text != null) return text;
    }

    // 6. 兜底
    return latin1.decode(bytes, allowInvalid: true);
  }

  /// 粗略判断字节是否像 GBK：至少存在一个合法的双字节序列。
  ///
  /// GBK 高位字节 0x81–0xFE，低位字节 0x40–0xFE（不含 0x7F）。
  static bool _looksLikeGbk(List<int> bytes) {
    var pairs = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      final lead = bytes[i];
      if (lead < 0x81 || lead > 0xFE) continue;
      final trail = bytes[i + 1];
      if (trail >= 0x40 && trail <= 0xFE && trail != 0x7F) {
        pairs++;
        i++;
      }
    }
    return pairs > 0;
  }

  /// 从 `Content-Type` / charset 名称里解析。
  static String? charsetOf(String? contentType) {
    if (contentType == null || contentType.isEmpty) return null;
    final match = _charsetPattern.firstMatch(contentType);
    if (match == null) return null;
    final name = match.group(1)?.trim().toLowerCase();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static bool _isUtf8Name(String name) =>
      name == 'utf-8' || name == 'utf8' || name == 'utf_8';

  static String? _tryDecode(Encoding encoding, List<int> bytes) {
    try {
      return encoding.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// 修复二次编码造成的乱码，支持三种常见方向：
  ///
  /// 1. UTF-8 字节被当成 Latin-1 / CP1252 → `æ™´å¤©`
  /// 2. GBK 字节被当成 Latin-1 → `ÇçÌì`
  /// 3. UTF-8 字节被当成 GBK → `鏅村ぉ`
  ///
  /// 只有「还原结果里出现了汉字（或假名 / 韩文）」时才替换，
  /// 正常西文（Café、Björk）与正常中文不会被误改。
  static String repairText(String text) {
    var current = text;
    for (var attempt = 0; attempt < 2; attempt++) {
      final fixed = _repairOnce(current);
      if (fixed == null || fixed == current) break;
      current = fixed;
    }
    return current;
  }

  static String? _repairOnce(String text) {
    if (text.length < 2) return null;
    if (!text.runes.any((r) => r >= 0x80)) return null;
    if (_cjk.hasMatch(text)) {
      // 已经是中文：只可能是「UTF-8 字节被当成 GBK」。
      final bytes = _tryEncode(gbk, text);
      if (bytes == null) return null;
      final decoded = _strictUtf8(bytes);
      if (decoded == null || decoded == text) return null;
      return _cjk.hasMatch(decoded) ? decoded : null;
    }

    final bytes = _legacyBytes(text);
    if (bytes == null) return null;

    // 乱码文本里高位字符占比通常很高；Björk、Café 这类正常西文只占 1 个，
    // 不满足阈值就直接放弃，避免误伤。
    var high = 0;
    for (final byte in bytes) {
      if (byte >= 0x80) high++;
    }
    if (high < 2 || high * 3 < bytes.length) return null;

    // 1) UTF-8 双重编码
    final asUtf8 = _strictUtf8(bytes);
    if (asUtf8 != null && _cjk.hasMatch(asUtf8)) return asUtf8;

    // 2) GBK 字节被当成 Latin-1 / CP1252
    if (_looksLikeGbk(bytes)) {
      final asGbk = _tryDecode(gbk, bytes);
      if (asGbk != null && _cjk.hasMatch(asGbk)) return asGbk;
    }
    return null;
  }

  static String? _strictUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static List<int>? _tryEncode(Encoding encoding, String text) {
    try {
      return encoding.encode(text);
    } catch (_) {
      return null;
    }
  }

  /// 把「看起来像 Latin-1 / CP1252 乱码」的文本还原成原始字节。
  static List<int>? _legacyBytes(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      if (rune <= 0xFF) {
        bytes.add(rune);
        continue;
      }
      final mapped = _cp1252[rune];
      if (mapped == null) return null;
      bytes.add(mapped);
    }
    return bytes;
  }

  /// Windows-1252 在 0x80–0x9F 区间的可打印字符 → 字节。
  static const Map<int, int> _cp1252 = {
    0x20AC: 0x80, // €
    0x201A: 0x82, // ‚
    0x0192: 0x83, // ƒ
    0x201E: 0x84, // „
    0x2026: 0x85, // …
    0x2020: 0x86, // †
    0x2021: 0x87, // ‡
    0x02C6: 0x88, // ˆ
    0x2030: 0x89, // ‰
    0x0160: 0x8A, // Š
    0x2039: 0x8B, // ‹
    0x0152: 0x8C, // Œ
    0x017D: 0x8E, // Ž
    0x2018: 0x91, // '
    0x2019: 0x92, // '
    0x201C: 0x93, // "
    0x201D: 0x94, // "
    0x2022: 0x95, // •
    0x2013: 0x96, // –
    0x2014: 0x97, // —
    0x02DC: 0x98, // ˜
    0x2122: 0x99, // ™
    0x0161: 0x9A, // š
    0x203A: 0x9B, // ›
    0x0153: 0x9C, // œ
    0x017E: 0x9E, // ž
    0x0178: 0x9F, // Ÿ
  };

  /// 歌词正文：先按字节解码，再尝试修复二次乱码。
  static String decodeLyric(List<int> bytes, {String? contentType}) =>
      repairText(decode(bytes, contentType: contentType));
}
