import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/utils/charset_support.dart';
import 'dlna_device.dart';

class DlnaException implements Exception {
  const DlnaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 音箱回传的播放进度与状态。
class DlnaPlaybackInfo {
  const DlnaPlaybackInfo({
    required this.position,
    required this.duration,
    required this.state,
  });

  final Duration position;
  final Duration duration;

  /// UPnP 的 CurrentTransportState：PLAYING / PAUSED_PLAYBACK / STOPPED …
  final String state;

  bool get isPlaying => state == 'PLAYING';
  bool get isPaused => state == 'PAUSED_PLAYBACK' || state == 'PAUSED';
  bool get isStopped =>
      state == 'STOPPED' || state == 'NO_MEDIA_PRESENT' || state == 'NO_MEDIA';
}

/// SSDP 发现 + UPnP 设备描述解析。
class DlnaDiscovery {
  DlnaDiscovery._();

  static const String _ssdpHost = '239.255.255.250';
  static const int _ssdpPort = 1900;
  static const String _searchTarget =
      'urn:schemas-upnp-org:device:MediaRenderer:1';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
      followRedirects: true,
    ),
  );

  /// 搜索局域网内的 MediaRenderer。默认等待 4 秒。
  static Future<List<DlnaDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final locations = <String>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = socket!.receive()) != null) {
          final text = latin1.decode(datagram!.data, allowInvalid: true);
          final location = _header(text, 'location');
          if (location != null && location.isNotEmpty) locations.add(location);
        }
      });

      final payload = utf8.encode(
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $_ssdpHost:$_ssdpPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: $_searchTarget\r\n'
        '\r\n',
      );
      final target = InternetAddress(_ssdpHost);
      // 发三次，降低丢包影响。
      for (var attempt = 0; attempt < 3; attempt++) {
        socket.send(payload, target, _ssdpPort);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await Future<void>.delayed(timeout);
    } catch (_) {
      // 没有网络 / 无法创建 socket 时返回空列表，由 UI 提示。
    } finally {
      await subscription?.cancel();
      socket?.close();
    }

    final devices = <DlnaDevice>[];
    final seen = <String>{};
    for (final location in locations) {
      final uri = Uri.tryParse(location);
      if (uri == null) continue;
      try {
        final response = await _dio.get<List<int>>(
          location,
          options: Options(responseType: ResponseType.bytes),
        );
        final xml = CharsetSupport.decode(
          response.data ?? const <int>[],
          contentType: response.headers.value('content-type'),
        );
        final device = parseDeviceDescription(xml, uri);
        if (device != null && seen.add(device.id)) devices.add(device);
      } catch (_) {
        // 单个设备描述拉取失败不影响其它设备。
      }
    }
    devices.sort((a, b) => a.name.compareTo(b.name));
    return devices;
  }

  static String? _header(String text, String name) {
    for (final line in const LineSplitter().convert(text)) {
      final index = line.indexOf(':');
      if (index <= 0) continue;
      if (line.substring(0, index).trim().toLowerCase() != name) continue;
      return line.substring(index + 1).trim();
    }
    return null;
  }
}

/// 单个 DLNA 设备的 AVTransport / RenderingControl 控制。
class DlnaClient {
  DlnaClient(this.device)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          headers: const {'Content-Type': 'text/xml; charset="utf-8"'},
        ),
      );

  final DlnaDevice device;
  final Dio _dio;

  static const String _avTransport =
      'urn:schemas-upnp-org:service:AVTransport:1';
  static const String _renderingControl =
      'urn:schemas-upnp-org:service:RenderingControl:1';

  Future<void> setAvTransportUri(String url, {required String metadata}) async {
    await _invoke(device.avTransportUrl, _avTransport, 'SetAVTransportURI', {
      'InstanceID': '0',
      'CurrentURI': url,
      'CurrentURIMetaData': metadata,
    });
  }

  Future<void> play() => _invoke(device.avTransportUrl, _avTransport, 'Play', {
    'InstanceID': '0',
    'Speed': '1',
  });

  Future<void> pause() => _invoke(
    device.avTransportUrl,
    _avTransport,
    'Pause',
    {'InstanceID': '0'},
  );

  Future<void> stop() =>
      _invoke(device.avTransportUrl, _avTransport, 'Stop', {'InstanceID': '0'});

  Future<void> seek(Duration position) => _invoke(
    device.avTransportUrl,
    _avTransport,
    'Seek',
    {'InstanceID': '0', 'Unit': 'REL_TIME', 'Target': hms(position)},
  );

  Future<void> setVolume(int volume) async {
    final control = device.renderingControlUrl;
    if (control == null || control.isEmpty) return;
    await _invoke(control, _renderingControl, 'SetVolume', {
      'InstanceID': '0',
      'Channel': 'Master',
      'DesiredVolume': '$volume',
    });
  }

  Future<String?> transportState() async {
    try {
      final body = await _invoke(
        device.avTransportUrl,
        _avTransport,
        'GetTransportInfo',
        {'InstanceID': '0'},
      );
      final match = RegExp(
        r'<CurrentTransportState>([^<]+)</CurrentTransportState>',
      ).firstMatch(body);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// 同时读取进度与传输状态，用于手机端同步显示与自动下一集。
  Future<DlnaPlaybackInfo?> playbackInfo() async {
    try {
      final results = await Future.wait([
        _invoke(device.avTransportUrl, _avTransport, 'GetPositionInfo', {
          'InstanceID': '0',
        }),
        _invoke(device.avTransportUrl, _avTransport, 'GetTransportInfo', {
          'InstanceID': '0',
        }),
      ]);
      final positionXml = results[0];
      final stateXml = results[1];
      return DlnaPlaybackInfo(
        position: parseHms(_tag(positionXml, 'RelTime')) ?? Duration.zero,
        duration: parseHms(_tag(positionXml, 'TrackDuration')) ?? Duration.zero,
        state:
            _tag(stateXml, 'CurrentTransportState') ??
            _tag(positionXml, 'CurrentTransportState') ??
            'UNKNOWN',
      );
    } catch (_) {
      return null;
    }
  }

  static String? _tag(String xml, String name) =>
      RegExp('<$name>([^<]*)</$name>').firstMatch(xml)?.group(1);

  /// 解析 UPnP 的 `HH:MM:SS` 时间（部分设备会带毫秒）。
  static Duration? parseHms(String? value) {
    if (value == null) return null;
    final parts = value.trim().split(':');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2].split('.').first);
    if (hours == null || minutes == null || seconds == null) return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  Future<String> _invoke(
    String? controlUrl,
    String serviceType,
    String action,
    Map<String, String> args,
  ) async {
    if (controlUrl == null || controlUrl.isEmpty) {
      throw const DlnaException('该设备不支持投屏控制（缺少 AVTransport）');
    }
    final response = await _dio.post<String>(
      controlUrl,
      data: buildEnvelope(serviceType, action, args),
      options: Options(
        responseType: ResponseType.plain,
        headers: {'SOAPACTION': '"$serviceType#$action"'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = response.data ?? '';
    if ((response.statusCode ?? 0) != 200) {
      throw DlnaException('设备返回 HTTP ${response.statusCode}');
    }
    if (body.contains('<s:Fault>') || body.contains('<UPnPError')) {
      final description = RegExp(
        r'<errorDescription>([^<]*)</errorDescription>',
      ).firstMatch(body)?.group(1);
      throw DlnaException(
        description?.isNotEmpty == true ? description! : '设备拒绝了这次操作',
      );
    }
    return body;
  }

  /// SOAP 1.1 信封。
  static String buildEnvelope(
    String serviceType,
    String action,
    Map<String, String> args,
  ) {
    final inner = args.entries
        .map(
          (entry) => '<${entry.key}>${escapeXml(entry.value)}</${entry.key}>',
        )
        .join();
    return '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$serviceType">$inner</u:$action></s:Body>'
        '</s:Envelope>';
  }

  /// DIDL-Lite 元数据，告诉设备标题 / 歌手 / 封面与资源类型。
  static String buildMetadata({
    required String id,
    required String title,
    String? artist,
    String? album,
    String? coverUrl,
    required String resourceUrl,
    required String mimeType,
  }) {
    final buffer = StringBuffer()
      ..write(
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">',
      )
      ..write('<item id="${escapeXml(id)}" parentID="0" restricted="1">')
      ..write('<dc:title>${escapeXml(title)}</dc:title>');
    if ((artist ?? '').trim().isNotEmpty) {
      buffer
        ..write('<dc:creator>${escapeXml(artist!)}</dc:creator>')
        ..write('<upnp:artist>${escapeXml(artist)}</upnp:artist>');
    }
    if ((album ?? '').trim().isNotEmpty) {
      buffer.write('<upnp:album>${escapeXml(album!)}</upnp:album>');
    }
    if ((coverUrl ?? '').isNotEmpty) {
      buffer.write(
        '<upnp:albumArtURI>${escapeXml(coverUrl!)}</upnp:albumArtURI>',
      );
    }
    buffer
      ..write('<upnp:class>object.item.audioItem.musicTrack</upnp:class>')
      ..write(
        '<res protocolInfo="http-get:*:${escapeXml(mimeType)}:*">'
        '${escapeXml(resourceUrl)}</res>',
      )
      ..write('</item></DIDL-Lite>');
    return buffer.toString();
  }

  static String hms(Duration position) {
    final hours = position.inHours;
    final minutes = position.inMinutes.remainder(60);
    final seconds = position.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
