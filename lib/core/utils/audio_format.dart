/// 设备解码能力与「服务器转码」策略。
///
/// Android（ExoPlayer）与 iOS（AVPlayer）能直接解码的容器格式有限：
/// mp3 / flac / aac / m4a / wav / ogg / opus 都可以；
/// wma、ape、wv、dsf、dff、tta、mpc、aiff 等则普遍不支持。
/// 遇到不支持的格式时，统一让 Subsonic 服务端转成 mp3 再播放 / 下载。
class AudioFormat {
  AudioFormat._();

  /// 可直接交给播放器解码的扩展名。
  static const Set<String> directPlayable = {
    'mp3',
    'flac',
    'aac',
    'm4a',
    'm4b',
    'mp4',
    'wav',
    'wave',
    'ogg',
    'oga',
    'opus',
    'webm',
    'mkv',
  };

  /// 不能直连时请求服务端转成的目标格式。
  static const String transcodeTarget = 'mp3';

  /// 转码时的默认码率（kbps）。320 基本无损于 mp3 听觉体验。
  static const int transcodeBitRate = 320;

  static String normalize(String? suffix) =>
      (suffix ?? '').toLowerCase().trim().replaceAll('.', '');

  static bool canPlayDirectly(String? suffix) {
    final value = normalize(suffix);
    if (value.isEmpty) return true;
    return directPlayable.contains(value);
  }

  static bool needsTranscode(String? suffix) => !canPlayDirectly(suffix);

  /// 取路径的扩展名（不含点，已小写）。
  static String suffixOfPath(String path) {
    final index = path.lastIndexOf('.');
    if (index < 0 || index == path.length - 1) return '';
    return normalize(path.substring(index + 1));
  }

  /// 本地文件是否可直接交给播放器（下载时可能已转为 mp3）。
  static bool canPlayPath(String path) {
    final suffix = suffixOfPath(path);
    if (suffix.isEmpty) return false;
    return canPlayDirectly(suffix);
  }

  /// 实际落盘 / 实际播放使用的扩展名。
  static String effectiveSuffix(String? suffix) {
    final value = normalize(suffix);
    if (value.isEmpty) return 'mp3';
    return needsTranscode(value) ? transcodeTarget : value;
  }

  /// 界面上展示的大写格式标识，例如 FLAC / WMA。
  static String label(String? suffix) {
    final value = normalize(suffix);
    return value.isEmpty ? '' : value.toUpperCase();
  }

  /// 供 DLNA / DIDL-Lite 使用的 MIME 类型。
  static String mimeType(String? suffix) {
    switch (effectiveSuffix(suffix)) {
      case 'flac':
        return 'audio/flac';
      case 'm4a':
      case 'm4b':
      case 'mp4':
      case 'aac':
        return 'audio/mp4';
      case 'wav':
      case 'wave':
        return 'audio/wav';
      case 'ogg':
      case 'oga':
      case 'opus':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'mp3':
      default:
        return 'audio/mpeg';
    }
  }
}
