import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:charset/charset.dart';
import 'package:yinghua/core/theme/app_presets.dart';
import 'package:yinghua/core/utils/audio_format.dart';
import 'package:yinghua/core/utils/artwork_url.dart';
import 'package:yinghua/core/utils/charset_support.dart';
import 'package:yinghua/core/utils/formatters.dart';
import 'package:yinghua/core/utils/lyric_parser.dart';
import 'package:yinghua/core/utils/sorters.dart';
import 'package:yinghua/core/utils/url_template.dart';
import 'package:yinghua/core/utils/url_utils.dart';
import 'package:yinghua/data/dlna/dlna_client.dart';
import 'package:yinghua/data/dlna/dlna_device.dart';
import 'package:yinghua/data/models/library_models.dart';
import 'package:yinghua/data/models/lyric.dart';

void main() {
  group('Fmt', () {
    test('formats durations', () {
      expect(Fmt.duration(const Duration(seconds: 65)), '01:05');
      expect(
        Fmt.duration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(Fmt.duration(null), '--:--');
    });

    test('formats file sizes', () {
      expect(Fmt.fileSize(0), '0 B');
      expect(Fmt.fileSize(1024 * 1024 * 5), '5.0 MB');
    });
  });

  group('LyricParser', () {
    test('parses LRC timestamps in order', () {
      const lrc = '[00:12.50]第一行\n[00:03.00]第二行\n[00:20.00]第三行';
      final lyric = LyricParser.fromLrcText(lrc);
      expect(lyric, isNotNull);
      expect(lyric!.lines.length, 3);
      expect(lyric.lines.first.text, '第二行');
      expect(lyric.lines.first.at, const Duration(seconds: 3));
      expect(lyric.lines[1].at, const Duration(seconds: 12, milliseconds: 500));
      expect(lyric.synced, isTrue);
    });

    test('treats plain text as unsynced lyrics', () {
      final lyric = LyricParser.fromPlain('第一行\n第二行');
      expect(lyric, isNotNull);
      expect(lyric!.synced, isFalse);
      expect(lyric.lines.length, 2);
    });
  });

  group('AudioFormat', () {
    test('accepts common formats directly', () {
      for (final suffix in ['mp3', 'FLAC', 'm4a', 'wav', 'opus']) {
        expect(AudioFormat.canPlayDirectly(suffix), isTrue, reason: suffix);
        expect(
          AudioFormat.effectiveSuffix(suffix),
          AudioFormat.normalize(suffix),
        );
      }
    });

    test('routes wma and other uncommon formats to transcode', () {
      for (final suffix in ['wma', 'ape', 'dsf', 'dff', 'tta', 'wv']) {
        expect(AudioFormat.needsTranscode(suffix), isTrue, reason: suffix);
        expect(AudioFormat.effectiveSuffix(suffix), 'mp3');
      }
    });

    test('handles empty or dotted suffix', () {
      expect(AudioFormat.effectiveSuffix(null), 'mp3');
      expect(AudioFormat.effectiveSuffix('.WMA'), 'mp3');
      expect(AudioFormat.label('flac'), 'FLAC');
    });

    test('checks downloaded file extension', () {
      expect(AudioFormat.canPlayPath('/data/a/song.mp3'), isTrue);
      expect(AudioFormat.canPlayPath('/data/a/song.FLAC'), isTrue);
      expect(AudioFormat.canPlayPath('/data/a/song.wma'), isFalse);
      expect(AudioFormat.canPlayPath('/data/a/song'), isFalse);
    });
  });

  group('UrlUtils', () {
    test('keeps bracketed IPv6 addresses', () {
      const url = 'http://[2409:8a62:ae76:b120:211:32ff:fe7e:1de1]:4533';
      expect(UrlUtils.normalizeBase(url), url);
      expect(UrlUtils.isValidBase(url), isTrue);
      expect(UrlUtils.isValidBase('$url/'), isTrue);
      expect(
        UrlUtils.hostOf(url),
        '[2409:8a62:ae76:b120:211:32ff:fe7e:1de1]:4533',
      );
    });

    test('adds brackets to bare IPv6 with port', () {
      final base = UrlUtils.normalizeBase(
        '2409:8a62:ae76:b120:211:32ff:fe7e:1de1:4533',
      );
      expect(base, 'http://[2409:8a62:ae76:b120:211:32ff:fe7e:1de1]:4533');
      expect(UrlUtils.isValidBase(base), isTrue);
    });

    test('still accepts IPv4 and domain addresses', () {
      expect(UrlUtils.isValidBase('192.168.1.8:4533'), isTrue);
      expect(
        UrlUtils.isValidBase('https://music.example.com/navidrome'),
        isTrue,
      );
      expect(
        UrlUtils.normalizeBase('music.example.com/rest'),
        'http://music.example.com',
      );
    });
  });

  group('UrlTemplate', () {
    test('expands and encodes placeholders', () {
      final url = UrlTemplate.expand(
        'https://api.example.com/cover?album={album}&artist={artist}&size={size}',
        const {'album': '夜的第七章', 'artist': '周杰伦', 'size': '360'},
      );
      expect(url, isNotNull);
      expect(
        url,
        contains('album=%E5%A4%9C%E7%9A%84%E7%AC%AC%E4%B8%83%E7%AB%A0'),
      );
      expect(url, contains('artist=%E5%91%A8%E6%9D%B0%E4%BC%A6'));
      expect(url, contains('size=360'));
      expect(url, isNot(contains('{')));
    });

    test('leaves missing placeholders empty', () {
      final url = UrlTemplate.expand(
        'https://api.example.com/lyric?title={title}&artist={artist}',
        const {'title': '晴天'},
      );
      expect(
        url,
        'https://api.example.com/lyric?title=%E6%99%B4%E5%A4%A9&artist=',
      );
    });

    test('rejects templates without http scheme', () {
      expect(
        UrlTemplate.expand('api.example.com/{id}', const {'id': '1'}),
        isNull,
      );
      expect(UrlTemplate.expand('   ', const {'id': '1'}), isNull);
    });

    test('detects placeholders', () {
      expect(UrlTemplate.hasPlaceholder('https://a.com/{id}'), isTrue);
      expect(UrlTemplate.hasPlaceholder('https://a.com/cover'), isFalse);
    });
  });

  group('AppPresets', () {
    test('has unique ids and distinct brand colors', () {
      final ids = AppPresets.all.map((e) => e.id).toSet();
      expect(ids.length, AppPresets.all.length);
      final colors = AppPresets.all.map((e) => e.brand.toARGB32()).toSet();
      expect(colors.length, AppPresets.all.length);
    });

    test('falls back to yinghua for unknown ids', () {
      expect(AppPresets.byId('unknown').id, 'yinghua');
      expect(AppPresets.byId(null).id, 'yinghua');
      expect(AppPresets.byId('qqmusic').name, 'QQ 音乐');
    });
  });

  group('Lyric', () {
    test('detects irreversibly corrupted server lyrics', () {
      const bad = Lyric(
        lines: [
          LyricLine(
            at: Duration.zero,
            text: '\uFFFD\uFFFD\uFFFD - \uFFFD\uFFFD',
          ),
          LyricLine(
            at: Duration(seconds: 2),
            text: '\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD',
          ),
        ],
      );
      expect(bad.isCorrupted, isTrue);

      const good = Lyric(
        lines: [
          LyricLine(at: Duration.zero, text: '窗外的麻雀 在电线杆上多嘴'),
          LyricLine(at: Duration(seconds: 2), text: '你说这一句 很有夏天的感觉'),
        ],
      );
      expect(good.isCorrupted, isFalse);

      const mostlyGood = Lyric(
        lines: [
          LyricLine(at: Duration.zero, text: '窗外的麻雀 在电线杆上多嘴'),
          LyricLine(at: Duration(seconds: 2), text: '你说这一句 很有夏天的感觉'),
          LyricLine(at: Duration(seconds: 4), text: '\uFFFD'),
        ],
      );
      expect(mostlyGood.isCorrupted, isFalse);
    });
  });

  group('CharsetSupport', () {
    test('decodes plain UTF-8', () {
      expect(CharsetSupport.decode(utf8.encode('晴天 - 周杰伦')), '晴天 - 周杰伦');
    });

    test('decodes UTF-8 with BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('莺花')];
      expect(CharsetSupport.decode(bytes), '莺花');
    });

    test('decodes GBK lyrics', () {
      final bytes = gbk.encode('把心事唱给风听');
      expect(CharsetSupport.decode(bytes), '把心事唱给风听');
    });

    test('decodes UTF-16LE with BOM', () {
      final bytes = <int>[
        0xFF,
        0xFE,
        for (final unit in '萤火'.codeUnits) ...[unit & 0xFF, unit >> 8],
      ];
      expect(CharsetSupport.decode(bytes), '萤火');
    });

    test('keeps Latin-1 text readable', () {
      expect(CharsetSupport.decode(latin1.encode('Café')), 'Café');
    });

    test('repairs GBK-hidden-as-Latin-1 mojibake', () {
      final mojibake = latin1.decode(gbk.encode('夜空中最亮的星'));
      expect(mojibake, isNot(contains('夜')));
      expect(CharsetSupport.repairText(mojibake), '夜空中最亮的星');
    });

    test('repairs UTF-8-hidden-as-Latin-1 mojibake', () {
      final mojibake = latin1.decode(utf8.encode('晴天'));
      expect(mojibake, isNot(contains('晴')));
      expect(CharsetSupport.repairText(mojibake), '晴天');
    });

    test('repairs UTF-8-hidden-as-GBK mojibake', () {
      final mojibake = gbk.decode(utf8.encode('晴天'));
      expect(mojibake, isNot('晴天'));
      expect(CharsetSupport.repairText(mojibake), '晴天');
    });

    test('does not touch normal Chinese or Latin text', () {
      expect(CharsetSupport.repairText('晴天'), '晴天');
      expect(CharsetSupport.repairText('Björk'), 'Björk');
      expect(CharsetSupport.repairText('Café'), 'Café');
    });
  });

  group('ArtworkUrl', () {
    test('shrinks oversized Apple artwork', () {
      const url =
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/a/b/23.jpg/3000x3000bb.jpg';
      expect(
        ArtworkUrl.shrink(url),
        'https://is1-ssl.mzstatic.com/image/thumb/Music126/a/b/23.jpg/720x720bb.jpg',
      );
    });

    test('keeps small artwork and foreign hosts untouched', () {
      const small = 'https://is1-ssl.mzstatic.com/a/620x620bb.jpg';
      expect(ArtworkUrl.shrink(small), small);
      const other = 'https://api.lrc.cx/cover?album=x/3000x3000bb.jpg';
      expect(ArtworkUrl.shrink(other), other);
    });

    test('resolves relative redirect locations', () {
      expect(
        ArtworkUrl.resolve('https://a.com/x/y', '/z.jpg'),
        'https://a.com/z.jpg',
      );
      expect(
        ArtworkUrl.resolve('https://a.com/x/y', 'https://b.com/z.jpg'),
        'https://b.com/z.jpg',
      );
    });
  });

  group('DLNA', () {
    const description = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>客厅电视</friendlyName>
    <modelName>MiTV</modelName>
    <UDN>uuid:abc-123</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/avt</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/rcs</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';

    test('parses a device description', () {
      final device = parseDeviceDescription(
        description,
        Uri.parse('http://192.168.1.5:49152/desc.xml'),
      );
      expect(device, isNotNull);
      expect(device!.name, '客厅电视');
      expect(device.model, 'MiTV');
      expect(device.id, 'uuid:abc-123');
      expect(device.canPlay, isTrue);
      expect(
        device.avTransportUrl,
        'http://192.168.1.5:49152/upnp/control/avt',
      );
      expect(
        device.renderingControlUrl,
        'http://192.168.1.5:49152/upnp/control/rcs',
      );
    });

    test('reports devices without AVTransport as not playable', () {
      final device = parseDeviceDescription(
        '<root><device><friendlyName>旧设备</friendlyName></device></root>',
        Uri.parse('http://192.168.1.9/desc.xml'),
      );
      expect(device, isNotNull);
      expect(device!.canPlay, isFalse);
    });

    test('builds SOAP envelope with escaped arguments', () {
      final xml = DlnaClient.buildEnvelope(
        'urn:schemas-upnp-org:service:AVTransport:1',
        'SetAVTransportURI',
        {
          'InstanceID': '0',
          'CurrentURI': 'http://a/b?s=1&t=2',
          'CurrentURIMetaData': '<DIDL/>',
        },
      );
      expect(xml, contains('SetAVTransportURI'));
      expect(xml, contains('http://a/b?s=1&amp;t=2'));
      expect(xml, contains('&lt;DIDL/&gt;'));
    });

    test('builds DIDL-Lite metadata', () {
      final meta = DlnaClient.buildMetadata(
        id: 'song-1',
        title: 'Super Star',
        artist: 'S.H.E',
        album: 'Super Star',
        coverUrl: 'http://server/cover?id=1',
        resourceUrl: 'http://server/stream?id=1',
        mimeType: AudioFormat.mimeType('flac'),
      );
      expect(meta, contains('<dc:title>Super Star</dc:title>'));
      expect(meta, contains('<upnp:artist>S.H.E</upnp:artist>'));
      expect(meta, contains('object.item.audioItem.musicTrack'));
      expect(meta, contains('audio/flac'));
      expect(meta, contains('albumArtURI'));
    });

    test('formats seek target and mime types', () {
      expect(
        DlnaClient.hms(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(AudioFormat.mimeType('mp3'), 'audio/mpeg');
      expect(AudioFormat.mimeType('flac'), 'audio/flac');
      expect(AudioFormat.mimeType('wma'), 'audio/mpeg');
    });
  });

  group('Sorters', () {
    const songs = [
      Song(
        id: '1',
        title: 'Beta',
        artist: 'C',
        duration: Duration(seconds: 90),
      ),
      Song(
        id: '2',
        title: 'Alpha',
        artist: 'A',
        duration: Duration(seconds: 30),
      ),
      Song(
        id: '3',
        title: 'Gamma',
        artist: 'B',
        duration: Duration(seconds: 60),
      ),
    ];

    test('server order is preserved', () {
      expect(sortSongs(songs, SortOrder.server).map((e) => e.id), [
        '1',
        '2',
        '3',
      ]);
    });

    test('sorts by title asc and desc', () {
      expect(sortSongs(songs, SortOrder.titleAsc).map((e) => e.title), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
      expect(sortSongs(songs, SortOrder.titleDesc).map((e) => e.title), [
        'Gamma',
        'Beta',
        'Alpha',
      ]);
    });

    test('sorts by duration', () {
      expect(
        sortSongs(
          songs,
          SortOrder.durationAsc,
        ).map((e) => e.duration.inSeconds),
        [30, 60, 90],
      );
      expect(
        sortSongs(
          songs,
          SortOrder.durationDesc,
        ).map((e) => e.duration.inSeconds),
        [90, 60, 30],
      );
    });

    test('does not mutate the input list', () {
      final input = [...songs];
      sortSongs(input, SortOrder.titleAsc);
      expect(input.map((e) => e.id), ['1', '2', '3']);
    });
  });
}
