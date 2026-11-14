import 'dart:io';

import 'package:yinghua/data/dlna/dlna_client.dart';

/// 局域网 DLNA 设备扫描（手动验证用）。
///
/// 运行：dart run tool/dlna_scan.dart
Future<void> main() async {
  stdout.writeln('正在搜索 MediaRenderer（约 8 秒）…');
  final devices = await DlnaDiscovery.discover(
    timeout: const Duration(seconds: 8),
  );
  if (devices.isEmpty) {
    stdout.writeln('未发现设备。请确认本机与电视 / 音箱在同一 Wi-Fi，且设备开启了 DLNA。');
    return;
  }
  for (final device in devices) {
    stdout.writeln('===== ${device.name}');
    stdout.writeln('  model    : ${device.model ?? '-'}');
    stdout.writeln('  location : ${device.location}');
    stdout.writeln('  avt      : ${device.avTransportUrl ?? '不支持'}');
    stdout.writeln('  rcs      : ${device.renderingControlUrl ?? '无音量控制'}');
    if (device.canPlay) {
      final client = DlnaClient(device);
      final info = await client.playbackInfo();
      stdout.writeln('  state    : ${info?.state ?? '读取失败'}');
      if (info != null) {
        stdout.writeln(
          '  progress : ${info.position.inSeconds}s / '
          '${info.duration.inSeconds}s',
        );
      }
    }
  }
}
