import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghua/data/local/settings_store.dart';
import 'package:yinghua/data/models/library_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recordPlayed keeps and persists recent songs', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();

    const song = Song(
      id: '1',
      title: '李爱民',
      artist: '测试歌手',
      album: '测试专辑',
      duration: Duration(seconds: 200),
    );

    // 直接验证 toJson 可编码
    final encoded = jsonEncode(song.toJson());
    expect(encoded, contains('李爱民'));

    await settings.recordPlayed(song);
    expect(settings.recentSongs.length, 1);
    expect(settings.recentSongs.first.title, '李爱民');

    // 重新读取，模拟重启
    final restored = SettingsStore();
    await restored.init();
    expect(restored.recentSongs.length, 1);
    expect(restored.recentSongs.first.title, '李爱民');
  });
}
