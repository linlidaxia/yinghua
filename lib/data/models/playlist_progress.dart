/// 歌单级播放进度：记住最后播放到哪首、播放到哪里。
///
/// 只保存歌曲 id 与位置，不保存整份队列；歌单增删歌曲后仍能按 id 找回。
class PlaylistProgress {
  const PlaylistProgress({
    required this.songId,
    required this.index,
    required this.position,
    this.updatedAt,
  });

  final String songId;

  /// 上次播放时在队列里的下标（歌曲被移出歌单时的兜底参考）。
  final int index;

  final Duration position;

  final DateTime? updatedAt;

  /// 位置太靠前时不值得提示「继续播放」。
  bool get isUsable =>
      songId.isNotEmpty && position > const Duration(seconds: 3);

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'index': index,
    'position': position.inMilliseconds,
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  };

  static PlaylistProgress? fromJson(Map<String, dynamic> json) {
    final songId = (json['songId'] as String?)?.trim() ?? '';
    if (songId.isEmpty) return null;
    return PlaylistProgress(
      songId: songId,
      index: (json['index'] as num?)?.toInt() ?? 0,
      position: Duration(
        milliseconds: (json['position'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
    );
  }
}
