import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/library_models.dart';

/// 与 Android MediaSession 对接的播放处理器：
/// 负责通知栏 / 锁屏 / 耳机线控，并用 just_audio 完成真正的解码播放。
class YingHuaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  YingHuaAudioHandler() {
    player.playbackEventStream.listen((_) => _broadcast(), onError: (_, __) {});
  }

  final AudioPlayer player = AudioPlayer();

  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function(Duration)? onSeek;

  /// 投屏时本地播放器是静音的，通知栏状态改由控制器直接提供。
  bool externalMode = false;
  bool externalPlaying = false;
  Duration externalPosition = Duration.zero;

  int? _queueIndex;
  Uri? _artUri;

  /// 当前是否用歌词替换了系统媒体信息（蓝牙歌词）。
  bool _lyricMode = false;

  void _broadcast() {
    final playing = externalMode ? externalPlaying : player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: externalMode
            ? AudioProcessingState.ready
            : _mapState(player.processingState),
        playing: playing,
        updatePosition: externalMode ? externalPosition : player.position,
        bufferedPosition: externalMode
            ? Duration.zero
            : player.bufferedPosition,
        speed: player.speed,
        queueIndex: _queueIndex,
      ),
    );
  }

  /// 供控制器在投屏进度变化时刷新通知栏。
  void broadcast() => _broadcast();

  AudioProcessingState _mapState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void setMediaItemForSong(Song song, {Uri? artUri}) {
    _artUri = artUri;
    _lyricMode = false;
    mediaItem.add(
      MediaItem(
        id: song.id,
        title: song.title,
        artist: song.displayArtist,
        album: song.displayAlbum,
        duration: song.duration,
        artUri: artUri,
        extras: {'songId': song.id},
      ),
    );
  }

  /// 蓝牙歌词：把当前歌词行写进 AVRCP 媒体信息。
  ///
  /// 车机 / 蓝牙音箱读取的是 title / artist（以及部分设备读取的
  /// displayTitle / displaySubtitle），这里把歌词放进 title，
  /// 歌名与歌手保留在 artist 与 display 字段里。
  void setBluetoothLyric(Song song, String line) {
    final text = line.trim();
    if (text.isEmpty) return;
    _lyricMode = true;
    mediaItem.add(
      MediaItem(
        id: song.id,
        title: text,
        artist: '${song.title} · ${song.displayArtist}',
        album: song.displayAlbum,
        duration: song.duration,
        artUri: _artUri,
        displayTitle: text,
        displaySubtitle: song.title,
        displayDescription: song.displayArtist,
        extras: {'songId': song.id, 'bluetoothLyric': true},
      ),
    );
  }

  /// 恢复到正常的歌曲信息（关闭蓝牙歌词 / 断开蓝牙 / 没有歌词时）。
  void restoreNowPlaying(Song song) {
    if (!_lyricMode) return;
    setMediaItemForSong(song, artUri: _artUri);
  }

  void syncQueue(List<Song> songs, Uri? Function(Song) artUri, int index) {
    _queueIndex = index;
    queue.add([
      for (final song in songs)
        MediaItem(
          id: song.id,
          title: song.title,
          artist: song.displayArtist,
          album: song.displayAlbum,
          duration: song.duration,
          artUri: artUri(song),
          extras: {'songId': song.id},
        ),
    ]);
    _broadcast();
  }

  void setQueueIndex(int index) {
    _queueIndex = index;
    _broadcast();
  }

  @override
  Future<void> play() async {
    final callback = onPlay;
    if (callback != null) {
      await callback();
      return;
    }
    await player.play();
  }

  @override
  Future<void> pause() async {
    final callback = onPause;
    if (callback != null) {
      await callback();
      return;
    }
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final callback = onSeek;
    if (callback != null) {
      await callback(position);
      return;
    }
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious?.call();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    _broadcast();
    await super.stop();
  }
}
