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

  test('bitrate limit only transcodes when source is above the cap', () {
    // 原始码率（0）不限制，FLAC 直连，不能带 maxBitRate。
    expect(
      AudioFormat.shouldTranscode('flac', bitRate: 900, maxBitRate: 0),
      isFalse,
    );
    // 上限低于源码率，需要转码降码率。
    expect(
      AudioFormat.shouldTranscode('flac', bitRate: 900, maxBitRate: 320),
      isTrue,
    );
    // 源码率本来就低于上限，保持直连。
    expect(
      AudioFormat.shouldTranscode('flac', bitRate: 200, maxBitRate: 320),
      isFalse,
    );
    // 码率未知时无法判断，保持直连，避免误触发服务端转码。
    expect(AudioFormat.shouldTranscode('flac', maxBitRate: 128), isFalse);
  });
}
