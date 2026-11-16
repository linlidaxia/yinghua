import 'package:flutter_test/flutter_test.dart';
import 'package:yinghua/core/utils/audio_format.dart';

void main() {
  test('direct playable formats do not need transcoding', () {
    expect(AudioFormat.shouldTranscode('mp3'), isFalse);
    expect(AudioFormat.shouldTranscode('flac'), isFalse);
    expect(AudioFormat.shouldTranscode('m4a'), isFalse);
    expect(AudioFormat.shouldTranscode(''), isFalse);
  });

  test('unsupported formats always transcode', () {
    expect(AudioFormat.shouldTranscode('wma'), isTrue);
    expect(AudioFormat.shouldTranscode('ape'), isTrue);
    expect(AudioFormat.shouldTranscode('dsf'), isTrue);
  });

  test('bitrate cap never forces transcoding of direct formats', () {
    expect(AudioFormat.shouldTranscode('mp3'), isFalse);
    expect(AudioFormat.shouldTranscode('flac'), isFalse);
    expect(AudioFormat.shouldTranscode('wma'), isTrue);
  });
}
