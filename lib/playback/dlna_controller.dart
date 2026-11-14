import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/audio_format.dart';
import '../data/dlna/dlna_client.dart';
import '../data/dlna/dlna_device.dart';
import '../data/sources/source_registry.dart';
import 'playback_controller.dart';

enum DlnaStatus { idle, discovering, connecting, casting }

/// 音箱侧的播放控制，交给 [PlaybackController] 统一调度。
class _DlnaCastTransport implements CastTransport {
  _DlnaCastTransport(this._owner);

  final DlnaController _owner;
  Duration _offset = Duration.zero;

  set offset(Duration value) => _offset = value;

  @override
  Duration get offset => _offset;

  @override
  Future<void> play() async {
    await _owner._client?.play();
    _owner._onRemotePlay();
  }

  @override
  Future<void> pause() async {
    await _owner._client?.pause();
    _owner._onRemotePause();
  }

  @override
  Future<void> seek(Duration position) async {
    final relative = position - _offset;
    final target = relative < Duration.zero ? Duration.zero : relative;
    await _owner._client?.seek(target);
    _owner._onSeeked(target);
  }
}

/// DLNA 投屏会话。
///
/// 负责：发现设备 → 设置 AVTransportURI → 播放 → 跟随切歌 → 断开。
/// 投屏期间手机本地播放器保持静音，切歌只把新的音频地址推给音箱；
/// 手机上的进度条跟随音箱回传的进度，拖动会回传到音箱seek。
class DlnaController extends ChangeNotifier {
  DlnaController({required this.playback, required this.registry}) {
    _transport = _DlnaCastTransport(this);
    playback.addListener(_onPlaybackChanged);
  }

  final PlaybackController playback;
  final SourceRegistry registry;

  DlnaStatus status = DlnaStatus.idle;
  List<DlnaDevice> devices = const [];
  DlnaDevice? device;
  String? message;

  DlnaClient? _client;
  late final _DlnaCastTransport _transport;
  String? _castSongId;
  bool _syncing = false;
  bool _disposed = false;

  Timer? _tickTimer;
  int _ticks = 0;
  bool _polling = false;
  bool _advancing = false;
  int _pollFailures = 0;
  Duration _lastPosition = Duration.zero;
  bool _lastPlaying = false;

  // 进度锚点：手机在两次轮询之间按这个锚点匀速外推，
  // 避免进度条每秒跳一下、看起来和音箱不同步。
  Duration _anchorPosition = Duration.zero;
  DateTime _anchorAt = DateTime.now();
  bool _anchorPlaying = false;
  bool _anchored = false;
  DateTime? _seekGuard;

  bool get isCasting => status == DlnaStatus.casting && device != null;
  bool get busy =>
      status == DlnaStatus.discovering || status == DlnaStatus.connecting;
  bool get hasDevice => device != null;

  Future<void> search() async {
    if (busy) return;
    status = DlnaStatus.discovering;
    message = null;
    devices = const [];
    _notify();
    try {
      final found = await DlnaDiscovery.discover();
      devices = found;
      status = isCasting ? DlnaStatus.casting : DlnaStatus.idle;
      if (found.isEmpty) {
        message = '没有发现支持 DLNA 的设备，请确认手机与音箱 / 电视在同一个 Wi-Fi。';
      }
    } catch (error) {
      status = isCasting ? DlnaStatus.casting : DlnaStatus.idle;
      message = '搜索失败：$error';
    }
    _notify();
  }

  Future<void> connect(DlnaDevice target) async {
    if (!target.canPlay) {
      message = '该设备不支持投屏控制（缺少 AVTransport）';
      _notify();
      return;
    }
    if (playback.current == null) {
      // 没有正在播放的曲目时不进入投屏模式，否则手机也会被静音。
      message = '请先播放一首歌，再选择投屏设备';
      status = DlnaStatus.idle;
      _notify();
      return;
    }
    status = DlnaStatus.connecting;
    device = target;
    _client = DlnaClient(target);
    message = null;
    _notify();
    // 进入投屏模式：手机静音并停止本地播放，避免与音箱同时出声。
    await playback.attachCast(_transport);
    await castCurrent();
  }

  /// 把当前歌曲推给设备（切歌时也会调用）。
  Future<void> castCurrent() async {
    final client = _client;
    if (client == null) return;
    // 从设备列表里点「重新推送」时也要先进入投屏模式，避免两边同时出声。
    if (!playback.casting) {
      await playback.attachCast(_transport);
    }
    final song = playback.current;
    if (song == null) {
      // 队列被清空后还点了「重新推送」：退出投屏，避免手机继续静音。
      _castSongId = null;
      _stopPolling();
      await disconnect();
      message = '请先播放一首歌';
      _notify();
      return;
    }
    final source = registry.source;
    if (source == null) {
      message = '尚未连接音乐服务器';
      _notify();
      return;
    }

    // 歌单的「跳过片头」在投屏时同样生效：
    // 需要服务端转码的格式直接让服务端从片头之后开始，其余交给设备 seek。
    final skip = playback.activeSkip;
    final intro = (skip != null && skip.isActive && skip.intro > Duration.zero)
        ? skip.intro
        : Duration.zero;
    final serverOffset =
        (intro > Duration.zero && AudioFormat.needsTranscode(song.suffix))
        ? intro
        : Duration.zero;
    _transport.offset = serverOffset;

    try {
      final uri = await source.resolveStream(song, startOffset: serverOffset);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw const DlnaException('演示音频是本地资源，无法投屏');
      }
      final metadata = DlnaClient.buildMetadata(
        id: song.id,
        title: song.title,
        artist: song.displayArtist,
        album: song.displayAlbum,
        coverUrl: registry.coverUrl(
          song.coverArtId,
          size: 600,
          album: song.displayAlbum,
          artist: song.displayArtist,
          title: song.title,
        ),
        resourceUrl: uri.toString(),
        mimeType: AudioFormat.mimeType(song.suffix),
      );
      await client.setAvTransportUri(uri.toString(), metadata: metadata);
      await client.play();

      // 起点：片头结束处；从手机切到音箱时接着手机当前的进度继续。
      var start = intro;
      if (status == DlnaStatus.connecting) {
        final local = playback.position.value;
        if (local > start) start = local;
      }
      if (start < Duration.zero) start = Duration.zero;

      // 设备时间轴 = 曲目时间轴 - 服务端已跳过的时间。
      var deviceStart = start - serverOffset;
      if (deviceStart < Duration.zero) deviceStart = Duration.zero;
      if (deviceStart > Duration.zero) {
        try {
          await client.seek(deviceStart);
        } catch (_) {
          message = '这个音箱不支持跳到指定位置，已从头播放';
          deviceStart = Duration.zero;
        }
      }
      final songPosition = deviceStart + serverOffset;

      _anchorPosition = deviceStart;
      _anchorAt = DateTime.now();
      _anchorPlaying = true;
      _anchored = true;
      _seekGuard = null;
      playback.anchorCast(songPosition);

      _castSongId = song.id;
      status = DlnaStatus.casting;
      _pollFailures = 0;
      _lastPosition = deviceStart;
      _lastPlaying = true;
      _startPolling();
    } catch (error) {
      final wasCasting = isCasting;
      status = wasCasting ? DlnaStatus.casting : DlnaStatus.idle;
      message = error is DlnaException
          ? '投屏失败：${error.message}'
          : '投屏失败：$error';
      _stopPolling();
      if (!wasCasting) {
        // 一次都没投成功就退回手机播放，避免两边都没声音。
        _client = null;
        device = null;
        await playback.detachCast(resume: true);
      }
    }
    _notify();
  }

  void _onPlaybackChanged() {
    if (_client == null || status != DlnaStatus.casting || _syncing) return;
    // 暂停 / 恢复由用户直接操作设备或手机，不需要重投。
    final current = playback.current;
    if (current == null || current.id == _castSongId) return;
    _syncing = true;
    unawaited(castCurrent().whenComplete(() => _syncing = false));
  }

  // ---------------------------------------------------------------------------
  // 进度同步
  // ---------------------------------------------------------------------------

  Duration _predicted() {
    if (!_anchored) return Duration.zero;
    if (!_anchorPlaying) return _anchorPosition;
    final elapsed = DateTime.now().difference(_anchorAt);
    if (elapsed <= Duration.zero) return _anchorPosition;
    return _anchorPosition + elapsed;
  }

  void _anchorAtDevice(Duration position, {required bool playing}) {
    _anchorPosition = position;
    _anchorAt = DateTime.now();
    _anchorPlaying = playing;
    _anchored = true;
  }

  void _onRemotePlay() {
    _anchorAt = DateTime.now();
    _anchorPlaying = true;
    _anchored = true;
  }

  void _onRemotePause() {
    _anchorPosition = _predicted();
    _anchorAt = DateTime.now();
    _anchorPlaying = false;
  }

  void _onSeeked(Duration devicePosition) {
    _anchorAtDevice(devicePosition, playing: playback.playing);
    // 设备回传新位置有延迟，这段时间不要被旧数据拉回去。
    _seekGuard = DateTime.now().add(const Duration(seconds: 3));
    _lastPosition = devicePosition;
  }

  void _startPolling() {
    _tickTimer?.cancel();
    _ticks = 0;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _ticks++;
      if (_ticks % 6 == 0) {
        unawaited(_poll());
      } else if (_anchorPlaying) {
        playback.updateCastPlayback(_predicted(), isPlaying: true);
      }
    });
  }

  void _stopPolling() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _polling = false;
  }

  /// 轮询音箱进度：校正手机端进度，并在整集播完后自动推下一集。
  Future<void> _poll() async {
    final client = _client;
    if (client == null || _polling) return;
    _polling = true;
    try {
      final info = await client.playbackInfo();
      if (info == null) {
        _pollFailures++;
        if (_pollFailures == 5 && isCasting) {
          message = '音箱没有响应，投屏可能已中断';
          _notify();
        }
        return;
      }
      _pollFailures = 0;
      if (!isCasting) return;

      final ended = _hasEnded(info);
      final songBefore = playback.current?.id;
      _resync(info);
      playback.updateCastPlayback(
        _predicted(),
        deviceDuration: info.duration,
        isPlaying: _anchorPlaying,
      );
      _lastPosition = info.position;
      _lastPlaying = info.isPlaying;

      // 片尾跳过可能已经切到下一集，避免重复推进。
      if (ended && !_advancing && playback.current?.id == songBefore) {
        _advancing = true;
        try {
          await playback.next(fromUser: false);
        } finally {
          _advancing = false;
        }
      }
    } finally {
      _polling = false;
    }
  }

  /// 用设备回传的位置校正锚点；偏差小于 2 秒时保持外推，避免进度抖动。
  void _resync(DlnaPlaybackInfo info) {
    final now = DateTime.now();
    final guard = _seekGuard;
    if (guard != null && now.isBefore(guard)) return;
    _seekGuard = null;

    if (!_anchored || info.isPlaying != _anchorPlaying || !info.isPlaying) {
      _anchorAtDevice(info.position, playing: info.isPlaying);
      return;
    }
    final drift = (info.position - _predicted()).abs();
    if (drift > const Duration(seconds: 2)) {
      _anchorAtDevice(info.position, playing: info.isPlaying);
    }
  }

  /// 判定「这一集已经播完」：设备停止，或进度达到片尾。
  bool _hasEnded(DlnaPlaybackInfo info) {
    if (info.isStopped && _lastPlaying && _lastPosition > Duration.zero) {
      return true;
    }
    final total = playback.duration;
    if (total <= Duration.zero) return false;
    final songPosition = info.position + _transport.offset;
    if (songPosition < total - const Duration(seconds: 2)) return false;
    // 部分设备播完把状态仍报成 PAUSED，进度停在最后。
    return !info.isPlaying && _lastPlaying;
  }

  Future<void> disconnect() async {
    final client = _client;
    final wasPlaying = playback.playing;
    _client = null;
    device = null;
    _castSongId = null;
    status = DlnaStatus.idle;
    message = null;
    _stopPolling();
    _seekGuard = null;
    _anchored = false;
    _lastPosition = Duration.zero;
    _lastPlaying = false;
    _notify();
    if (client != null) {
      try {
        await client.stop();
      } catch (_) {
        // 设备已离线时忽略。
      }
    }
    // 声音交还手机。
    await playback.detachCast(resume: wasPlaying);
  }

  Future<void> setVolume(double value) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.setVolume((value.clamp(0.0, 1.0) * 100).round());
    } catch (_) {
      // 部分设备不支持音量控制。
    }
  }

  void clearMessage() {
    if (message == null) return;
    message = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    playback.removeListener(_onPlaybackChanged);
    super.dispose();
  }
}
