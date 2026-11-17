import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/utils/audio_format.dart';
import '../data/local/download_manager.dart';
import '../data/local/favorites_store.dart';
import '../data/local/settings_store.dart';
import '../data/models/library_models.dart';
import '../data/models/lyric.dart';
import '../data/models/playlist_progress.dart';
import '../data/models/skip_config.dart';
import '../data/repositories/library_repository.dart';
import '../data/sources/music_source.dart';
import '../data/sources/online_lyrics.dart';
import '../data/sources/source_registry.dart';
import 'audio_cache.dart';
import 'audio_handler.dart';

enum PlayMode { sequence, repeatAll, repeatOne, shuffle }

extension PlayModeX on PlayMode {
  String get label => switch (this) {
    PlayMode.sequence => '顺序播放',
    PlayMode.repeatAll => '列表循环',
    PlayMode.repeatOne => '单曲循环',
    PlayMode.shuffle => '随机播放',
  };

  IconData get icon => switch (this) {
    PlayMode.sequence => Icons.format_list_numbered_rounded,
    PlayMode.repeatAll => Icons.repeat_rounded,
    PlayMode.repeatOne => Icons.repeat_one_rounded,
    PlayMode.shuffle => Icons.shuffle_rounded,
  };
}

enum SleepOption { off, minutes15, minutes30, minutes60, endOfTrack }

extension SleepOptionX on SleepOption {
  String get label => switch (this) {
    SleepOption.off => '关闭定时',
    SleepOption.minutes15 => '15 分钟后',
    SleepOption.minutes30 => '30 分钟后',
    SleepOption.minutes60 => '60 分钟后',
    SleepOption.endOfTrack => '播完当前歌曲',
  };

  Duration? get duration => switch (this) {
    SleepOption.minutes15 => const Duration(minutes: 15),
    SleepOption.minutes30 => const Duration(minutes: 30),
    SleepOption.minutes60 => const Duration(minutes: 60),
    _ => null,
  };
}

/// DLNA 投屏时的远端控制接口。
///
/// 进入投屏后手机本地播放器完全静音，播放 / 暂停 / 拖动都交给音箱。
abstract class CastTransport {
  /// 设备时间轴相对曲目时间轴的偏移。
  ///
  /// 服务端从片头开始转码时，设备上的 0 秒对应曲目的「片头结束处」，
  /// 界面上要补上这段偏移才能显示原集数的时间。
  Duration get offset;

  Future<void> play();
  Future<void> pause();

  /// [position] 是曲目时间轴上的位置（不是设备时间轴）。
  Future<void> seek(Duration position);
}

/// 播放控制层。
///
/// 统一管理队列、播放模式、定时停止、缓存、回放增益与歌词同步；
/// UI 只通过本类的状态与方法驱动播放。
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.settings,
    required this.registry,
    required this.downloads,
    required this.favorites,
    required this.library,
  });

  final SettingsStore settings;
  final SourceRegistry registry;
  final DownloadManager downloads;
  final FavoritesStore favorites;
  final LibraryRepository library;

  late final YingHuaAudioHandler handler;
  late final AudioPlayer player;

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> buffered = ValueNotifier(Duration.zero);
  final ValueNotifier<int> lyricLine = ValueNotifier(-1);

  final List<Song> _queue = [];
  List<int> _order = [];
  int _index = -1;
  PlayMode _mode = PlayMode.repeatAll;
  Song? _current;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _duration = Duration.zero;
  String _queueTitle = '播放队列';
  String? _queuePlaylistId;

  /// 恢复歌单进度时，新曲目加载完成后要跳到的位置。
  Duration? _pendingStart;
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _progressSaveInterval = Duration(seconds: 5);

  /// 蓝牙歌词：当前是否连了蓝牙输出、最后推送的歌词行。
  bool _btConnected = false;
  bool _lyricModeActive = false;
  String _lastBtLyric = '';
  StreamSubscription<Set<AudioDevice>>? _btDeviceSub;
  Lyric? _lyric;
  bool _lyricLoading = false;
  String? _lyricError;
  int _lyricRequest = 0;
  bool _handlingComplete = false;
  bool _outroTriggered = false;
  Duration _streamOffset = Duration.zero;
  int _introAttempts = 0;
  bool _introDone = false;
  bool _scrobbled = false;
  bool _disposed = false;
  CastTransport? _cast;
  bool _castPlaying = false;
  DateTime? _castSeekGuard;

  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  bool _sleepEndOfTrack = false;

  final Map<String, double?> _gainCache = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _scrobbleTimer;

  List<Song> get queue => List.unmodifiable(_queue);
  int get index => _index;
  PlayMode get mode => _mode;
  Song? get current => _current;
  bool get playing => casting ? _castPlaying : _playing;
  bool get loading => _loading;
  String? get error => _error;
  Duration get duration => _duration;

  /// 正在把声音投放到 DLNA 设备（手机本地不出声）。
  bool get casting => _cast != null;

  String get queueTitle => _queueTitle;
  String? get queuePlaylistId => _queuePlaylistId;

  /// 当前队列（歌单）的跳过头尾配置。
  SkipConfig? get activeSkip => _activeSkip;

  /// 服务端转码时已跳过的片头（时间轴从 0 开始）。
  Duration get streamOffset => _streamOffset;

  SkipConfig? get _activeSkip => settings.skipFor(_queuePlaylistId);

  /// 本集开始播放的位置：有声书跳过片头时为片头结束处，否则 0。
  Duration get _trackStart {
    final skip = _activeSkip;
    if (skip == null || !skip.isActive || skip.intro <= Duration.zero) {
      return Duration.zero;
    }
    final total = _duration;
    if (total > Duration.zero && skip.intro >= total - skip.outro) {
      return Duration.zero;
    }
    return skip.intro;
  }

  /// 当前歌词校准值：优先当前歌曲，其次队列来源歌单，最后 0。
  int get lyricOffsetMs {
    final songOffset = settings.lyricOffsetForSong(_current?.id);
    if (songOffset != null) return songOffset;
    return settings.lyricOffsetForPlaylist(_queuePlaylistId) ?? 0;
  }

  Lyric? get lyric => _lyric;
  bool get lyricLoading => _lyricLoading;
  String? get lyricError => _lyricError;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get hasSleepTimer => _sleepRemaining != null || _sleepEndOfTrack;
  bool get sleepEndOfTrack => _sleepEndOfTrack;
  bool get isCurrentStarred =>
      _current != null && favorites.isSongStarred(_current!);

  Future<void> init() async {
    if (kIsWeb) {
      handler = YingHuaAudioHandler();
    } else {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        handler = await AudioService.init(
          builder: YingHuaAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.yinghua.yinghua.playback',
            androidNotificationChannelName: '莺花播放',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: false,
            androidNotificationIcon: 'drawable/ic_stat_yinghua',
            notificationColor: Color(0xFFE23B3B),
            preloadArtwork: true,
            fastForwardInterval: Duration(seconds: 15),
            rewindInterval: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        // 后台服务初始化失败时仍保证应用内播放可用。
        handler = YingHuaAudioHandler();
      }
    }

    player = handler.player;
    handler.onSkipNext = () => next(fromUser: false);
    handler.onSkipPrevious = () => previous(fromUser: false);
    // 通知栏 / 锁屏 / 蓝牙耳机的播放控制也要走本类，
    // 否则投屏时从通知栏点播放会让手机同时出声。
    handler.onPlay = play;
    handler.onPause = pause;
    handler.onSeek = seek;

    settings.addListener(_onSettingsChanged);
    unawaited(_listenAudioDevices());

    _subscriptions.add(
      player.positionStream.listen((value) {
        position.value = value;
        _updateLyricLine();
        _applyIntroOnTick(value);
        _applyOutroSkip(value);
        unawaited(_savePlaylistProgress());
      }),
    );
    _subscriptions.add(
      player.bufferedPositionStream.listen((value) => buffered.value = value),
    );
    _subscriptions.add(
      player.durationStream.listen((value) {
        if (value != null && value > Duration.zero) {
          _duration = value;
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen((state) {
        _playing = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _onCompleted();
        }
        _notify();
      }),
    );
    _subscriptions.add(
      player.errorStream.listen((error) {
        _loading = false;
        _error = _friendlyError(error);
        _notify();
      }),
    );

    await player.setVolume(settings.userVolume);
    unawaited(AudioCache.prune());
  }

  // ---------------------------------------------------------------------------
  // 队列与播放
  // ---------------------------------------------------------------------------

  Future<void> playSongs(
    List<Song> songs, {
    int startIndex = 0,
    String? title,
    String? playlistId,
    Duration? startPosition,
  }) async {
    if (songs.isEmpty) return;
    await _savePlaylistProgress(force: true);
    _queue
      ..clear()
      ..addAll(songs);
    _index = startIndex.clamp(0, _queue.length - 1);
    _queueTitle = title?.trim().isNotEmpty == true ? title!.trim() : '播放队列';
    _queuePlaylistId = playlistId;
    _pendingStart = startPosition;
    _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
    _rebuildOrder();
    debugPrint(
      '[playback] playSongs len=${songs.length} start=$_index '
      'mode=${_mode.name} playlist=${playlistId ?? '-'}',
    );
    await _loadCurrent(autoPlay: true);
    _syncHandlerQueue();
    _notify();
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) {
      await playSongs([song]);
      return;
    }
    _queue.add(song);
    _order.add(_queue.length - 1);
    _syncHandlerQueue();
    _notify();
  }

  Future<void> addToQueueNext(Song song) async {
    if (_current == null) {
      await playSongs([song]);
      return;
    }
    _queue.insert(_index + 1, song);
    _rebuildOrder();
    _syncHandlerQueue();
    _notify();
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _savePlaylistProgress(force: true);
    await _loadCurrent(index: index, autoPlay: true);
    _syncHandlerQueue();
    _notify();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removingCurrent = index == _index;
    if (removingCurrent) await _savePlaylistProgress(force: true);
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      await clearQueue();
      return;
    }
    if (removingCurrent) {
      _index = index.clamp(0, _queue.length - 1);
      _rebuildOrder();
      await _loadCurrent(autoPlay: _playing);
    } else {
      if (index < _index) _index--;
      _rebuildOrder();
    }
    _syncHandlerQueue();
    _notify();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(adjusted.clamp(0, _queue.length), song);
    final currentSong = _current;
    _index = currentSong == null
        ? 0
        : _queue.indexWhere((e) => e.id == currentSong.id);
    _rebuildOrder();
    _syncHandlerQueue();
    _notify();
  }

  Future<void> clearQueue() async {
    await _savePlaylistProgress(force: true);
    _queue.clear();
    _order.clear();
    _index = -1;
    _current = null;
    _lyric = null;
    _error = null;
    _duration = Duration.zero;
    position.value = Duration.zero;
    buffered.value = Duration.zero;
    lyricLine.value = -1;
    await player.stop();
    if (casting) {
      try {
        await _cast?.pause();
      } catch (_) {}
      _castPlaying = false;
    }
    handler.mediaItem.add(null);
    _notify();
  }

  Future<void> togglePlay() async {
    if (_current == null) return;
    if (_error != null) {
      await _loadCurrent(autoPlay: true);
      return;
    }
    if (playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> pause() async {
    final cast = _cast;
    if (cast != null) {
      _castPlaying = false;
      _notify();
      try {
        await cast.pause();
      } catch (_) {
        // 设备离线时保持 UI 状态，下一次操作会重试。
      }
      await _savePlaylistProgress(force: true);
      return;
    }
    await player.pause();
    await _savePlaylistProgress(force: true);
  }

  Future<void> play() async {
    final cast = _cast;
    if (cast != null) {
      _castPlaying = true;
      _notify();
      try {
        await cast.play();
      } catch (_) {}
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    await player.play();
  }

  // ---------------------------------------------------------------------------
  // DLNA 投屏
  // ---------------------------------------------------------------------------

  /// 进入投屏：本地播放器立即静音并停止，后续切歌只推给音箱。
  Future<void> attachCast(CastTransport transport) async {
    _cast = transport;
    _castPlaying = true;
    handler.externalMode = true;
    handler.externalPlaying = true;
    try {
      await player.setVolume(0);
      await player.stop();
    } catch (_) {
      // 本地播放器已闲置时忽略。
    }
    handler.broadcast();
    _notify();
    _syncBluetoothLyric(force: true);
  }

  /// 退出投屏，把声音交还手机（[resume] 为真时接着放）。
  Future<void> detachCast({bool resume = false}) async {
    if (_cast == null) return;
    final wasPlaying = _castPlaying;
    final at = position.value;
    _cast = null;
    _castPlaying = false;
    handler.externalMode = false;
    _notify();
    handler.broadcast();
    _syncBluetoothLyric(force: true);
    final song = _current;
    // 先恢复音量，即使重新载入音源失败也不会一直静音。
    try {
      await player.setVolume(settings.userVolume);
    } catch (_) {}
    if (song == null) {
      return;
    }
    await _loadCurrent(autoPlay: resume && wasPlaying);
    if (at > Duration.zero) {
      try {
        await player.seek(at);
        position.value = at;
        _updateLyricLine();
      } catch (_) {
        // 恢复本地播放时进度对齐失败不影响播放。
      }
    }
  }

  /// 音箱回传的进度 / 状态（由 DlnaController 轮询驱动）。
  ///
  /// [devicePosition] 是**设备时间轴**上的位置；界面上要加上
  /// [CastTransport.offset]，这样服务端从片头开始转码时也能显示原集数时间。
  void updateCastPlayback(
    Duration devicePosition, {
    Duration? deviceDuration,
    required bool isPlaying,
  }) {
    final cast = _cast;
    if (cast == null) return;

    // 用户刚拖动过：先跟着拖动后的位置走，等设备追上再跟随，避免进度条回跳。
    final guard = _castSeekGuard;
    if (guard != null && DateTime.now().isBefore(guard)) {
      if (isPlaying != _castPlaying) {
        _castPlaying = isPlaying;
        handler.externalPlaying = isPlaying;
        handler.broadcast();
        _notify();
      }
      return;
    }
    _castSeekGuard = null;

    final playingChanged = isPlaying != _castPlaying;
    _castPlaying = isPlaying;

    // 曲目总时长优先用服务器元数据；没有元数据时才参考设备上报值。
    var durationChanged = false;
    if ((deviceDuration ?? Duration.zero) > Duration.zero &&
        _duration <= Duration.zero) {
      _duration = deviceDuration! + cast.offset;
      durationChanged = true;
    }

    final shown = devicePosition + cast.offset;
    position.value = shown < Duration.zero ? Duration.zero : shown;
    _updateLyricLine();
    _applyOutroSkip(position.value);
    unawaited(_savePlaylistProgress());

    handler.externalPlaying = isPlaying;
    handler.externalPosition = position.value;
    if (playingChanged || durationChanged) {
      handler.broadcast();
      _notify();
    }
  }

  /// 投屏开始 / 切集时把界面进度锚定到片头结束处。
  void anchorCast(Duration at) {
    if (_cast == null) return;
    final target = at < Duration.zero ? Duration.zero : at;
    position.value = target;
    _updateLyricLine();
    handler.externalPlaying = _castPlaying;
    handler.externalPosition = target;
    handler.broadcast();
  }

  Future<void> next({bool fromUser = true}) async {
    if (_queue.isEmpty) return;
    await _savePlaylistProgress(force: true);
    final pos = _orderPos;
    debugPrint(
      '[playback] next fromUser=$fromUser mode=${_mode.name} '
      'index=$_index pos=$pos order=${_order.length} queue=${_queue.length}',
    );
    if (_mode == PlayMode.repeatOne && !fromUser) {
      final start = _trackStart;
      if (casting) {
        position.value = start;
        _updateLyricLine();
        try {
          await _cast?.seek(start);
          await _cast?.play();
        } catch (_) {}
        return;
      }
      await player.seek(start);
      await player.play();
      return;
    }
    if (pos < _order.length - 1) {
      await _loadCurrent(index: _order[pos + 1], autoPlay: true);
      _syncHandlerQueue();
      return;
    }
    if (_mode == PlayMode.sequence) {
      if (casting) {
        await pause();
        position.value = _duration;
        _updateLyricLine();
        return;
      }
      await player.pause();
      await player.seek(_duration);
      return;
    }
    await _loadCurrent(index: _order.first, autoPlay: true);
    _syncHandlerQueue();
  }

  Future<void> previous({bool fromUser = true}) async {
    if (_queue.isEmpty) return;
    await _savePlaylistProgress(force: true);
    final at = casting ? position.value : player.position;
    final start = _trackStart;
    if (at > const Duration(seconds: 3) + start) {
      if (casting) {
        position.value = start;
        _updateLyricLine();
        try {
          await _cast?.seek(start);
        } catch (_) {}
        return;
      }
      await player.seek(start);
      return;
    }
    final pos = _orderPos;
    if (pos > 0) {
      await _loadCurrent(index: _order[pos - 1], autoPlay: true);
      _syncHandlerQueue();
      return;
    }
    if (_mode == PlayMode.sequence) {
      if (casting) {
        position.value = start;
        _updateLyricLine();
        try {
          await _cast?.seek(start);
        } catch (_) {}
        return;
      }
      await player.seek(start);
      return;
    }
    await _loadCurrent(index: _order.last, autoPlay: true);
    _syncHandlerQueue();
  }

  Future<void> seek(Duration target) async {
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
              ? _duration
              : target);
    position.value = clamped;
    if (casting) {
      _updateLyricLine();
      // 设备 seek 有 1~2 秒延迟，这段时间不要被旧的轮询进度拉回去。
      _castSeekGuard = DateTime.now().add(const Duration(seconds: 2));
      try {
        await _cast?.seek(clamped);
      } catch (_) {}
      return;
    }
    await player.seek(clamped);
    _updateLyricLine();
  }

  Future<void> seekToLyric(int lineIndex) async {
    final lyric = _lyric;
    if (lyric == null || !lyric.synced) return;
    if (lineIndex < 0 || lineIndex >= lyric.lines.length) return;
    final target =
        lyric.lines[lineIndex].at + Duration(milliseconds: -lyricOffsetMs);
    await seek(target);
  }

  Future<void> setMode(PlayMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _rebuildOrder();
    _notify();
  }

  void cycleMode() {
    final nextMode = switch (_mode) {
      PlayMode.sequence => PlayMode.repeatAll,
      PlayMode.repeatAll => PlayMode.repeatOne,
      PlayMode.repeatOne => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.sequence,
    };
    setMode(nextMode);
  }

  Future<void> toggleStarCurrent() async {
    final song = _current;
    if (song == null) return;
    await favorites.toggleSong(song);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 定时停止
  // ---------------------------------------------------------------------------

  void setSleepTimer(SleepOption option) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = null;
    _sleepEndOfTrack = false;

    if (option == SleepOption.endOfTrack) {
      _sleepEndOfTrack = true;
      _notify();
      return;
    }
    final total = option.duration;
    if (total == null) {
      _notify();
      return;
    }
    _sleepRemaining = total;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepRemaining;
      if (remaining == null) {
        timer.cancel();
        return;
      }
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        _sleepRemaining = null;
        _sleepTimer = null;
        unawaited(pause());
      } else {
        _sleepRemaining = next;
      }
      _notify();
    });
    _notify();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = null;
    _sleepEndOfTrack = false;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 歌词
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 有声书：跳过头尾
  // ---------------------------------------------------------------------------

  /// 载入新曲目后跳到片头结束处。
  Future<void> _applyIntroSkip() async {
    final skip = _activeSkip;
    debugPrint(
      '[playback] introSkip playlist=${_queuePlaylistId ?? '-'} '
      'skip=${skip?.intro.inSeconds}/${skip?.outro.inSeconds} '
      'streamOffset=${_streamOffset.inSeconds}',
    );
    if (skip == null || !skip.isActive || skip.intro <= Duration.zero) return;
    // 转码流已经让服务端从片头处开始，无需再 seek。
    if (_streamOffset > Duration.zero) {
      _introDone = true;
      return;
    }
    final total = _duration;
    final limit = total - skip.outro;
    if (limit > Duration.zero && skip.intro >= limit) {
      _introDone = true;
      return;
    }
    try {
      await player.seek(skip.intro);
      position.value = skip.intro;
    } catch (_) {
      // 失败后由 position 回调重试。
    }
  }

  /// 有些音源（缓存代理 / 刚开始缓冲）会忽略播放前的 seek，
  /// 在进度回调里再补几次，直到位置越过片头。
  void _applyIntroOnTick(Duration value) {
    if (_introDone) return;
    final skip = _activeSkip;
    if (skip == null || !skip.isActive || skip.intro <= Duration.zero) {
      _introDone = true;
      return;
    }
    if (_streamOffset > Duration.zero) {
      _introDone = true;
      return;
    }
    if (value >= skip.intro) {
      _introDone = true;
      return;
    }
    if (_introAttempts >= 6) {
      _introDone = true;
      return;
    }
    _introAttempts++;
    unawaited(
      player
          .seek(skip.intro)
          .then((_) {
            position.value = skip.intro;
          })
          .catchError((Object _) {}),
    );
  }

  /// 播放到片尾阈值时跳到下一集。
  void _applyOutroSkip(Duration value) {
    final skip = _activeSkip;
    if (skip == null || !skip.isActive || skip.outro <= Duration.zero) return;
    final total = _duration;
    if (total <= Duration.zero) return;
    final threshold = total - skip.outro;
    if (threshold <= Duration.zero) return;
    if (value < threshold) {
      // 用户往回拖后允许再次触发。
      if (_outroTriggered && value < threshold - const Duration(seconds: 1)) {
        _outroTriggered = false;
      }
      return;
    }
    if (_outroTriggered) return;
    _outroTriggered = true;
    debugPrint(
      '[playback] outroSkip at=${value.inSeconds}s '
      'total=${total.inSeconds}s outro=${skip.outro.inSeconds}s',
    );
    unawaited(_handleOutro());
  }

  Future<void> _handleOutro() async {
    if (_mode == PlayMode.repeatOne) {
      final skip = _activeSkip;
      final target = (skip != null && skip.intro > Duration.zero)
          ? skip.intro
          : Duration.zero;
      if (casting) {
        position.value = target;
        _outroTriggered = false;
        _castPlaying = true;
        _updateLyricLine();
        try {
          await _cast?.seek(target);
          await _cast?.play();
        } catch (_) {}
        return;
      }
      try {
        await player.seek(target);
        _outroTriggered = false;
        await player.play();
      } catch (_) {
        _outroTriggered = false;
      }
      return;
    }
    await next(fromUser: false);
  }

  /// 恢复歌单进度：把新加载的曲目定位到上次播放的位置。
  Future<void> _applyPendingStart() async {
    final resume = _pendingStart;
    _pendingStart = null;
    if (resume == null || resume <= Duration.zero) return;
    try {
      await player.seek(resume);
      position.value = resume;
      _introDone = true;
      _outroTriggered = false;
    } catch (_) {
      // seek 失败时保持从头播放。
    }
  }

  /// 记录当前歌单播到哪首、哪个位置。
  ///
  /// 播放中由 positionStream 高频触发，内部按 5 秒节流；
  /// 切歌 / 暂停 / 退出时用 `force: true` 立即落盘。
  Future<void> _savePlaylistProgress({bool force = false}) async {
    final playlistId = _queuePlaylistId;
    final song = _current;
    if (playlistId == null || playlistId.isEmpty || song == null) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastProgressSave) < _progressSaveInterval) {
      return;
    }
    Duration at;
    try {
      at = casting ? position.value : player.position;
    } catch (_) {
      at = position.value;
    }
    if (!force && at < const Duration(seconds: 5)) return;
    // 已经播到结尾时保存「下一首从头开始」，避免下次继续播放直接秒完。
    final total = _duration;
    if (total > Duration.zero && at > total - const Duration(seconds: 2)) {
      at = Duration.zero;
    }
    _lastProgressSave = now;
    await settings.savePlaylistProgress(
      playlistId,
      PlaylistProgress(
        songId: song.id,
        index: _index,
        position: at < Duration.zero ? Duration.zero : at,
        updatedAt: now,
      ),
      notify: force,
    );
  }

  void _onSettingsChanged() {
    _syncBluetoothLyric(force: true);
  }

  /// 监听音频输出设备，只有连着蓝牙时才会改写系统媒体信息。
  Future<void> _listenAudioDevices() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      _btDeviceSub = session.devicesStream.listen((devices) {
        final connected = devices.any(
          (device) =>
              device.isOutput &&
              // ignore: experimental_member_use
              (device.type == AudioDeviceType.bluetoothA2dp ||
                  // ignore: experimental_member_use
                  device.type == AudioDeviceType.bluetoothSco ||
                  // ignore: experimental_member_use
                  device.type == AudioDeviceType.bluetoothLe),
        );
        if (connected == _btConnected) return;
        _btConnected = connected;
        debugPrint('[playback] bluetooth output: $connected');
        _syncBluetoothLyric(force: true);
      });
    } catch (_) {
      // 拿不到设备列表时退化为「不启用蓝牙歌词」。
    }
  }

  /// 把当前歌词行推送到蓝牙设备（AVRCP 媒体信息）。
  ///
  /// 多数车机 / 蓝牙音箱显示的是 title / artist，所以这里用歌词替换 title，
  /// 歌名与歌手放在 artist 与 display 字段；没有歌词或断开蓝牙时恢复原信息。
  void _syncBluetoothLyric({bool force = false}) {
    final song = _current;
    if (song == null) return;
    final enabled = settings.bluetoothLyrics && _btConnected && !casting;
    String text = '';
    if (enabled) {
      final lyric = _lyric;
      final index = lyricLine.value;
      if (lyric != null &&
          lyric.synced &&
          index >= 0 &&
          index < lyric.lines.length) {
        text = lyric.lines[index].text.trim();
      }
    }
    if (!enabled || text.isEmpty) {
      if (_lyricModeActive) {
        _lyricModeActive = false;
        _lastBtLyric = '';
        handler.restoreNowPlaying(song);
      }
      return;
    }
    if (!force && text == _lastBtLyric) return;
    _lastBtLyric = text;
    _lyricModeActive = true;
    handler.setBluetoothLyric(song, text);
  }

  void _updateLyricLine({bool force = false}) {
    final lyric = _lyric;
    if (lyric == null || !lyric.synced) {
      if (lyricLine.value != -1) lyricLine.value = -1;
      _syncBluetoothLyric();
      return;
    }
    final index = lyric.indexAt(position.value, offsetMs: lyricOffsetMs);
    if (force || index != lyricLine.value) {
      lyricLine.value = index;
      _syncBluetoothLyric();
    }
  }

  Future<void> reloadLyric() async {
    final song = _current;
    if (song == null) return;
    await _loadLyric(song);
  }

  Future<void> _loadLyric(Song song) async {
    final request = ++_lyricRequest;
    _lyric = null;
    _lyricError = null;
    _lyricLoading = true;
    lyricLine.value = -1;
    _notify();
    final result = await library.lyric(song);
    if (request != _lyricRequest || _current?.id != song.id || _disposed) {
      return;
    }
    var lyric = result.lyric as Lyric?;
    String? error = result.error;
    if (result.corrupted) {
      lyric = null;
      error = '服务器歌词编码异常（歌词文件不是 UTF-8），已尝试在线歌词';
    }
    if (lyric != null && lyric.isCorrupted) {
      lyric = null;
    }

    // 服务器没有歌词时，按「自定义接口 → 在线歌词（LRCLIB）」补全一次。
    if (lyric == null &&
        (settings.onlineLyricsEnabled || settings.lyricsApiUrl.isNotEmpty)) {
      lyric = await OnlineLyrics.fetch(
        song,
        customTemplate: settings.lyricsApiUrl,
        useOnline: settings.onlineLyricsEnabled,
      );
      if (lyric != null) error = null;
      if (request != _lyricRequest || _current?.id != song.id || _disposed) {
        return;
      }
    }

    _lyric = lyric;
    _lyricError = error;
    _lyricLoading = false;
    _updateLyricLine(force: true);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  Future<void> _loadCurrent({int? index, bool autoPlay = true}) async {
    final target = index ?? _index;
    if (target < 0 || target >= _queue.length) return;
    _index = target;
    final song = _queue[target];
    _current = song;
    _loading = true;
    _error = null;
    _duration = song.duration;
    _lyric = null;
    _lyricError = null;
    _lyricLoading = false;
    _scrobbled = false;
    _handlingComplete = false;
    _outroTriggered = false;
    _introAttempts = 0;
    _introDone = false;
    _streamOffset = Duration.zero;
    position.value = Duration.zero;
    buffered.value = Duration.zero;
    lyricLine.value = -1;
    _notify();

    unawaited(settings.recordPlayed(song));
    final cover = registry.coverUrl(song.coverArtId);
    handler.setMediaItemForSong(
      song,
      artUri: cover == null ? null : Uri.tryParse(cover),
    );
    handler.setQueueIndex(_orderPos);
    _lastBtLyric = '';
    _lyricModeActive = false;

    // 投屏中：本地播放器保持停止，只把曲目信息与进度交给音箱。
    if (casting) {
      _loading = false;
      _error = null;
      _duration = song.duration;
      _castPlaying = true;
      position.value = Duration.zero;
      buffered.value = Duration.zero;
      try {
        await player.stop();
      } catch (_) {
        // 本地播放器已停止时忽略。
      }
      handler.externalPlaying = true;
      handler.externalPosition = Duration.zero;
      handler.broadcast();
      // 有声书片头交给 DlnaController 在推送音源后处理
      // （转码流由服务端从片头处开始，其余格式由音箱 seek）。
      _scheduleScrobble(song);
      unawaited(_loadLyric(song));
      _notify();
      return;
    }

    try {
      final source = await _buildSource(song);
      await player.setAudioSource(source);
      _loading = false;
      _error = null;
      await _applyIntroSkip();
      await _applyPendingStart();
      if (autoPlay) {
        unawaited(player.play().catchError((Object _) {}));
      }
      unawaited(_applyGain(song));
      _scheduleScrobble(song);
      unawaited(_loadLyric(song));
    } catch (error) {
      debugPrint(
        '[playback] setAudioSource failed: id=${song.id} '
        'suffix=${song.suffix} error=$error',
      );
      // 缓存音源异常时退回直连流，保证可播放。
      try {
        final fallback = await _directSource(song);
        await player.setAudioSource(fallback);
        _loading = false;
        _error = null;
        await _applyIntroSkip();
        await _applyPendingStart();
        if (autoPlay) {
          unawaited(player.play().catchError((Object _) {}));
        }
        unawaited(_applyGain(song));
        _scheduleScrobble(song);
        unawaited(_loadLyric(song));
      } catch (_) {
        _loading = false;
        _error = _friendlyError(error, song);
      }
    }
    _notify();
  }

  Future<AudioSource> _buildSource(Song song) async {
    final local = downloads.localPath(song);
    if (local != null && AudioFormat.canPlayPath(local)) {
      return AudioSource.file(local, tag: song);
    }
    final path = song.path;
    if (path != null && path.startsWith('assets/')) {
      return AudioSource.asset(path, tag: song);
    }
    final uri = await _resolveUri(song);
    // 服务端转码出来的是实时流（没有 Content-Length、不支持 Range），
    // 交给 LockCachingAudioSource 会卡住或失败，直接播放更稳。
    final transcoded = AudioFormat.needsTranscode(song.suffix);
    if (settings.cacheEnabled && !kIsWeb && !transcoded) {
      final cacheFile = await AudioCache.fileFor(song);
      if (cacheFile != null) {
        // ignore: experimental_member_use
        return LockCachingAudioSource(uri, cacheFile: cacheFile, tag: song);
      }
    }
    return AudioSource.uri(uri, tag: song);
  }

  Future<AudioSource> _directSource(Song song) async {
    final local = downloads.localPath(song);
    if (local != null && AudioFormat.canPlayPath(local)) {
      return AudioSource.file(local, tag: song);
    }
    final path = song.path;
    if (path != null && path.startsWith('assets/')) {
      return AudioSource.asset(path, tag: song);
    }
    return AudioSource.uri(
      await _resolveUri(song, ignoreBitRate: true),
      tag: song,
    );
  }

  Future<Uri> _resolveUri(Song song, {bool ignoreBitRate = false}) async {
    final source = registry.source;
    if (source == null) throw MusicSourceException('尚未连接音乐服务器');
    // 转码流不支持 seek，用服务端 timeOffset 从片头结束处开始转码。
    final skip = _activeSkip;
    final offset =
        (skip != null &&
            skip.isActive &&
            skip.intro > Duration.zero &&
            AudioFormat.needsTranscode(song.suffix))
        ? skip.intro
        : Duration.zero;
    _streamOffset = offset;
    if (offset > Duration.zero) {
      debugPrint(
        '[playback] 服务端跳过片头 ${offset.inSeconds}s '
        '(id=${song.id}, suffix=${song.suffix})',
      );
    }
    final uri = await source.resolveStream(
      song,
      maxBitRate: ignoreBitRate || settings.maxBitRate <= 0
          ? null
          : settings.maxBitRate,
      startOffset: offset,
    );
    // 只记录参数名与关键值，token 等敏感参数不会进日志。
    debugPrint(
      '[playback] stream id=${song.id} suffix=${song.suffix} '
      'bitRate=${song.bitRate} maxBitRate=${settings.maxBitRate} '
      'format=${uri.queryParameters['format']} '
      'params=${uri.queryParameters.keys.join(',')}',
    );
    return uri;
  }

  Future<void> _applyGain(Song song) async {
    var volume = settings.userVolume;
    if (settings.replayGainEnabled && settings.userVolume > 0) {
      final gain = await _gainFor(song);
      if (gain != null) {
        volume *= pow(10, gain / 20).toDouble();
      }
    }
    await player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<double?> _gainFor(Song song) async {
    if (song.albumGain != null || song.trackGain != null) {
      return song.albumGain ?? song.trackGain;
    }
    if (_gainCache.containsKey(song.id)) return _gainCache[song.id];
    _gainCache[song.id] = null;
    final source = registry.source;
    if (source == null) return null;
    final detail = await source.getSong(song.id);
    final gain = detail?.albumGain ?? detail?.trackGain;
    _gainCache[song.id] = gain;
    return gain;
  }

  void _scheduleScrobble(Song song) {
    _scrobbleTimer?.cancel();
    _scrobbleTimer = Timer(const Duration(seconds: 10), () {
      if (_current?.id != song.id || _scrobbled) return;
      if (casting ? !_castPlaying : !player.playing) return;
      _scrobbled = true;
      unawaited(registry.source?.scrobble(song) ?? Future.value());
    });
  }

  void _onCompleted() {
    if (_handlingComplete) return;
    _handlingComplete = true;
    final song = _current;
    if (song != null && !_scrobbled) {
      _scrobbled = true;
      unawaited(registry.source?.scrobble(song) ?? Future.value());
    }
    if (_sleepEndOfTrack) {
      _sleepEndOfTrack = false;
      _sleepRemaining = null;
      unawaited(pause());
      _notify();
      return;
    }
    unawaited(_advanceAfterComplete());
  }

  Future<void> _advanceAfterComplete() async {
    debugPrint(
      '[playback] completed mode=${_mode.name} index=$_index '
      'order=${_order.length} queue=${_queue.length} '
      'skip=${_activeSkip?.intro.inSeconds}/${_activeSkip?.outro.inSeconds}',
    );
    if (_mode == PlayMode.repeatOne) {
      await player.seek(Duration.zero);
      await player.play();
      _handlingComplete = false;
      return;
    }
    if (_queue.isEmpty) {
      _handlingComplete = false;
      return;
    }
    if (_order.isEmpty) _rebuildOrder();
    // 不依赖 next() 里的下标推导，单独算一次目标曲目，避免出现「列表循环
    // 却反复播同一首」的边界情况（队列只有一项、order 与 index 不同步等）。
    final pos = _orderPos;
    var target = _order.first;
    if (pos < _order.length - 1) {
      target = _order[pos + 1];
    } else if (_mode == PlayMode.sequence) {
      _handlingComplete = false;
      await pause();
      return;
    } else if (_mode == PlayMode.shuffle) {
      final remaining = List<int>.generate(_queue.length, (i) => i)
        ..remove(_index)
        ..shuffle(Random());
      target = remaining.isEmpty ? _index : remaining.first;
    }
    if (target == _index && _queue.length > 1) {
      // 防御：同一个队列里绝不在非单曲循环模式下重复当前曲目。
      target = _order[(pos + 1) % _order.length];
    }
    debugPrint('[playback] advance to index=$target (from $_index)');
    await _loadCurrent(index: target, autoPlay: true);
    _syncHandlerQueue();
    // 整首播完后，进度应指向新曲目的开头，而不是上一首的结尾。
    _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
    await _savePlaylistProgress(force: true);
    _handlingComplete = false;
  }

  int get _orderPos {
    final pos = _order.indexOf(_index);
    return pos < 0 ? 0 : pos;
  }

  void _rebuildOrder() {
    final indices = List<int>.generate(_queue.length, (i) => i);
    if (_mode == PlayMode.shuffle && _index >= 0 && _index < _queue.length) {
      indices.remove(_index);
      indices.shuffle(Random());
      _order = [_index, ...indices];
    } else {
      _order = indices;
    }
  }

  void _syncHandlerQueue() {
    handler.syncQueue(_queue, (song) {
      final uri = registry.coverUrl(song.coverArtId);
      return uri == null ? null : Uri.tryParse(uri);
    }, _index);
  }

  String _friendlyError(Object error, [Song? song]) {
    if (error is MusicSourceException) return error.message;
    final subject = song ?? _current;
    if (error is PlayerException) {
      final suffix = AudioFormat.normalize(subject?.suffix);
      if (suffix.isNotEmpty && AudioFormat.needsTranscode(suffix)) {
        return '这首歌是 ${suffix.toUpperCase()} 格式，设备无法直接解码。'
            'App 已请求 Navidrome 转码，但服务器没有返回音频（常见于未安装 ffmpeg 或转码队列繁忙）。'
            '请在「设置 → 播放 → 音质上限」选择「原始码率」，并在 Navidrome 中确认转码可用。';
      }
      return '无法播放这首歌，可能是音频格式不受支持或链接已失效';
    }
    if (error is PlayerInterruptedException) {
      return '播放已中断';
    }
    final raw = '$error';
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return '网络连接中断，请检查服务器';
    }
    return '播放失败，请稍后重试';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_savePlaylistProgress(force: true));
    _disposed = true;
    settings.removeListener(_onSettingsChanged);
    unawaited(_btDeviceSub?.cancel());
    _sleepTimer?.cancel();
    _scrobbleTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    position.dispose();
    buffered.dispose();
    lyricLine.dispose();
    super.dispose();
  }
}
