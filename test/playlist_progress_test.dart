import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yinghua/data/local/settings_store.dart';
import 'package:yinghua/data/models/playlist_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PlaylistProgress serializes and restores fields', () {
    final progress = PlaylistProgress(
      songId: 'song-42',
      index: 41,
      position: const Duration(minutes: 3, seconds: 12),
      updatedAt: DateTime.utc(2026, 11, 16),
    );
    expect(progress.isUsable, isTrue);

    final restored = PlaylistProgress.fromJson(progress.toJson());
    expect(restored, isNotNull);
    expect(restored!.songId, 'song-42');
    expect(restored.index, 41);
    expect(restored.position, const Duration(minutes: 3, seconds: 12));
    expect(restored.updatedAt, DateTime.utc(2026, 11, 16));
  });

  test('PlaylistProgress ignores near-start positions', () {
    expect(
      const PlaylistProgress(
        songId: 'a',
        index: 0,
        position: Duration.zero,
      ).isUsable,
      isFalse,
    );
    expect(
      const PlaylistProgress(
        songId: 'a',
        index: 0,
        position: Duration(seconds: 2),
      ).isUsable,
      isFalse,
    );
    expect(
      const PlaylistProgress(
        songId: 'a',
        index: 0,
        position: Duration(seconds: 30),
      ).isUsable,
      isTrue,
    );
    expect(PlaylistProgress.fromJson({'index': 2}), isNull);
  });

  test('SettingsStore persists per-playlist progress', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    await settings.init();

    expect(settings.progressForPlaylist('pl-1'), isNull);

    await settings.savePlaylistProgress(
      'pl-1',
      const PlaylistProgress(
        songId: 'song-7',
        index: 6,
        position: Duration(minutes: 5, seconds: 30),
      ),
    );
    expect(settings.progressForPlaylist('pl-1')!.songId, 'song-7');

    // 重启后仍在
    final restored = SettingsStore();
    await restored.init();
    expect(
      restored.progressForPlaylist('pl-1')!.position,
      const Duration(minutes: 5, seconds: 30),
    );

    await restored.clearPlaylistProgress('pl-1');
    expect(restored.progressForPlaylist('pl-1'), isNull);
  });
}
