import 'package:flutter_test/flutter_test.dart';
import 'package:yinghua/core/app_version.dart';
import 'package:yinghua/data/update/update_service.dart';

void main() {
  test('AppVersion normalizes tags and compares versions', () {
    expect(AppVersion.normalize('v1.2.3+4'), '1.2.3');
    expect(AppVersion.normalize('1.2.3-beta'), '1.2.3');
    expect(AppVersion.normalize('V1.0.20'), '1.0.20');

    expect(AppVersion.compare('1.0.20', '1.0.19'), greaterThan(0));
    expect(AppVersion.compare('1.0.19', '1.0.20'), lessThan(0));
    expect(AppVersion.compare('1.0.20', 'v1.0.20'), 0);
    expect(AppVersion.compare('1.0.20', '1.0'), greaterThan(0));
    expect(AppVersion.compare('1.10.0', '1.9.9'), greaterThan(0));

    expect(AppVersion.isNewer('1.0.99', AppVersion.current), isTrue);
    expect(AppVersion.isNewer(AppVersion.current, AppVersion.current), isFalse);
  });

  test('UpdateInfo picks the APK asset from a GitHub release', () {
    final info = UpdateInfo.fromRelease({
      'tag_name': 'v1.0.20',
      'body': '修复若干问题\n\nSHA-256：76fdb19c7035fea950e314ddc97586c01b1a12bb614b6e87c52c8bd8679cc5b7',
      'html_url': 'https://github.com/linlidaxia/yinghua/releases/tag/v1.0.20',
      'published_at': '2026-11-15T10:00:00Z',
      'assets': [
        {
          'name': 'notes.txt',
          'size': 10,
          'browser_download_url': 'https://example.com/notes.txt',
        },
        {
          'name': 'yinghua-1.0.20.apk',
          'size': 69496000,
          'browser_download_url': 'https://example.com/yinghua-1.0.20.apk',
        },
      ],
    });

    expect(info, isNotNull);
    expect(info!.version, '1.0.20');
    expect(info.apkName, 'yinghua-1.0.20.apk');
    expect(info.apkUrl, endsWith('.apk'));
    expect(info.apkSize, 69496000);
    expect(info.notes, startsWith('修复若干问题'));
    expect(info.publishedAt, isNotNull);
    expect(
      info.sha256,
      '76fdb19c7035fea950e314ddc97586c01b1a12bb614b6e87c52c8bd8679cc5b7',
    );
  });

  test('UpdateInfo ignores releases without an APK', () {
    final info = UpdateInfo.fromRelease({
      'tag_name': 'v1.0.20',
      'assets': [
        {
          'name': 'notes.txt',
          'browser_download_url': 'https://example.com/notes.txt',
        },
      ],
    });
    expect(info, isNull);
  });
}
