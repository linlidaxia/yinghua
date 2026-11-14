/// 歌单级别的「跳过片头 / 片尾」配置（有声书、广播剧常用）。
class SkipConfig {
  const SkipConfig({
    this.intro = Duration.zero,
    this.outro = Duration.zero,
    this.enabled = true,
  });

  /// 跳过开头的时长。
  final Duration intro;

  /// 跳过结尾的时长。
  final Duration outro;

  final bool enabled;

  bool get isActive =>
      enabled && (intro > Duration.zero || outro > Duration.zero);

  SkipConfig copyWith({Duration? intro, Duration? outro, bool? enabled}) =>
      SkipConfig(
        intro: intro ?? this.intro,
        outro: outro ?? this.outro,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
    'intro': intro.inMilliseconds,
    'outro': outro.inMilliseconds,
    'enabled': enabled,
  };

  static SkipConfig fromJson(Map<String, dynamic> json) => SkipConfig(
    intro: Duration(milliseconds: (json['intro'] as num?)?.toInt() ?? 0),
    outro: Duration(milliseconds: (json['outro'] as num?)?.toInt() ?? 0),
    enabled: json['enabled'] != false,
  );
}
