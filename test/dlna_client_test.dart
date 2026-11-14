import 'package:flutter_test/flutter_test.dart';
import 'package:yinghua/data/dlna/dlna_client.dart';

void main() {
  test('DlnaClient parses UPnP HH:MM:SS timestamps', () {
    expect(
      DlnaClient.parseHms('00:23:45'),
      const Duration(hours: 0, minutes: 23, seconds: 45),
    );
    expect(
      DlnaClient.parseHms('01:02:03'),
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    // 部分设备会带毫秒。
    expect(DlnaClient.parseHms('00:00:05.000'), const Duration(seconds: 5));
    expect(DlnaClient.parseHms(null), isNull);
    expect(DlnaClient.parseHms(''), isNull);
    expect(DlnaClient.parseHms('12:00'), isNull);
  });

  test('DlnaPlaybackInfo maps transport states', () {
    const playing = DlnaPlaybackInfo(
      position: Duration(seconds: 10),
      duration: Duration(minutes: 20),
      state: 'PLAYING',
    );
    expect(playing.isPlaying, isTrue);
    expect(playing.isStopped, isFalse);

    const paused = DlnaPlaybackInfo(
      position: Duration(seconds: 10),
      duration: Duration(minutes: 20),
      state: 'PAUSED_PLAYBACK',
    );
    expect(paused.isPlaying, isFalse);
    expect(paused.isPaused, isTrue);
    expect(paused.isStopped, isFalse);

    const stopped = DlnaPlaybackInfo(
      position: Duration(minutes: 20),
      duration: Duration(minutes: 20),
      state: 'STOPPED',
    );
    expect(stopped.isStopped, isTrue);
    expect(stopped.isPlaying, isFalse);
  });
}
