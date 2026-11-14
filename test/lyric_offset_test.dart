import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghua/core/utils/formatters.dart';
import 'package:yinghua/data/local/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fmt.lyricOffset formats seconds and minutes', () {
    expect(Fmt.lyricOffset(0), '0.0s');
    expect(Fmt.lyricOffset(500), '+0.5s');
    expect(Fmt.lyricOffset(-12000), '-12.0s');
    expect(Fmt.lyricOffset(65500), '+1:05.5');
    expect(Fmt.lyricOffset(-120000), '-2:00.0');
  });

  test('lyric offsets are stored per song and per playlist', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();

    expect(settings.lyricOffsetForSong('s1'), isNull);
    expect(settings.lyricOffsetForPlaylist('p1'), isNull);

    await settings.setSongLyricOffset('s1', 7300);
    await settings.setPlaylistLyricOffset('p1', -42000);

    expect(settings.lyricOffsetForSong('s1'), 7300);
    expect(settings.lyricOffsetForPlaylist('p1'), -42000);
    // 未单独设置的歌不会继承别的值。
    expect(settings.lyricOffsetForSong('s2'), isNull);

    // 超出范围时按 ±2 分钟收敛。
    await settings.setSongLyricOffset('s3', 999999);
    expect(settings.lyricOffsetForSong('s3'), SettingsStore.lyricOffsetLimitMs);
    await settings.setPlaylistLyricOffset('p2', -999999);
    expect(
      settings.lyricOffsetForPlaylist('p2'),
      -SettingsStore.lyricOffsetLimitMs,
    );

    // 重启后仍然保留。
    final restored = SettingsStore();
    await restored.init();
    expect(restored.lyricOffsetForSong('s1'), 7300);
    expect(restored.lyricOffsetForPlaylist('p1'), -42000);

    // 清除后回到「未设置」。
    await restored.clearSongLyricOffset('s1');
    expect(restored.lyricOffsetForSong('s1'), isNull);
    await restored.clearPlaylistLyricOffset('p1');
    expect(restored.lyricOffsetForPlaylist('p1'), isNull);
  });
}
