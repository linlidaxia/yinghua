import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghua/data/local/settings_store.dart';
import 'package:yinghua/data/models/library_models.dart';
import 'package:yinghua/data/models/server_config.dart';
import 'package:yinghua/data/models/skip_config.dart';
import 'package:yinghua/data/sources/subsonic_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SkipConfig serializes and reports active state', () {
    const config = SkipConfig(
      intro: Duration(seconds: 30),
      outro: Duration(seconds: 15),
    );
    expect(config.isActive, isTrue);
    final json = config.toJson();
    final restored = SkipConfig.fromJson(json);
    expect(restored.intro, const Duration(seconds: 30));
    expect(restored.outro, const Duration(seconds: 15));
    expect(restored.enabled, isTrue);

    expect(
      const SkipConfig(intro: Duration.zero, outro: Duration.zero).isActive,
      isFalse,
    );
    expect(
      const SkipConfig(intro: Duration(seconds: 10), enabled: false).isActive,
      isFalse,
    );
  });

  test('SettingsStore persists per-playlist skip config', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();

    expect(settings.skipFor('pl-1'), isNull);

    await settings.setPlaylistSkip(
      'pl-1',
      const SkipConfig(
        intro: Duration(seconds: 45),
        outro: Duration(seconds: 20),
      ),
    );
    expect(settings.skipFor('pl-1')!.intro, const Duration(seconds: 45));

    // 重启后仍在
    final restored = SettingsStore();
    await restored.init();
    expect(restored.skipFor('pl-1')!.outro, const Duration(seconds: 20));

    // 全部清零即删除
    await restored.setPlaylistSkip('pl-1', const SkipConfig());
    expect(restored.skipFor('pl-1'), isNull);
  });

  test('resolveStream uses timeOffset only for transcoded songs', () async {
    final config = ServerConfig(
      id: 'srv_test',
      type: 'subsonic',
      name: 'test',
      baseUrl: 'http://192.168.1.2:4533',
      username: 'u',
      salt: 's',
      token: 't',
      createdAt: DateTime(2026),
    );
    final source = SubsonicSource(config);

    const wma = Song(
      id: '1',
      title: '第一集',
      suffix: 'wma',
      duration: Duration(minutes: 23),
    );
    final transcoded = await source.resolveStream(
      wma,
      startOffset: const Duration(seconds: 70),
    );
    expect(transcoded.queryParameters['format'], 'mp3');
    expect(transcoded.queryParameters['timeOffset'], '70');

    const mp3 = Song(id: '2', title: '第二集', suffix: 'mp3');
    final direct = await source.resolveStream(
      mp3,
      startOffset: const Duration(seconds: 70),
    );
    expect(direct.queryParameters['format'], 'raw');
    expect(direct.queryParameters.containsKey('timeOffset'), isFalse);
  });
}
