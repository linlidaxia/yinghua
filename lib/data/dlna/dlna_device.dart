import 'package:xml/xml.dart';

/// 一个可投屏的 DLNA 渲染设备（MediaRenderer）。
class DlnaDevice {
  const DlnaDevice({
    required this.id,
    required this.name,
    required this.location,
    this.model,
    this.avTransportUrl,
    this.renderingControlUrl,
  });

  final String id;
  final String name;
  final String location;
  final String? model;

  /// AVTransport 控制地址（播放 / 暂停 / 停止 / 跳转）。
  final String? avTransportUrl;

  /// RenderingControl 控制地址（音量），部分设备没有。
  final String? renderingControlUrl;

  bool get canPlay => avTransportUrl != null && avTransportUrl!.isNotEmpty;

  String get subtitle {
    final parts = <String>[
      if ((model ?? '').trim().isNotEmpty) model!.trim(),
      if (!canPlay) '不支持 AVTransport',
    ];
    return parts.isEmpty ? location : parts.join(' · ');
  }
}

/// 解析 UPnP 设备描述 XML。
DlnaDevice? parseDeviceDescription(String xml, Uri descriptionUrl) {
  XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } catch (_) {
    return null;
  }

  final devices = doc.findAllElements('device').toList();
  if (devices.isEmpty) return null;

  // 优先选择带 AVTransport 服务的设备（有些描述里会有嵌套设备）。
  XmlElement? chosen;
  for (final device in devices) {
    if (_serviceControl(device, 'AVTransport') != null) {
      chosen = device;
      break;
    }
  }
  chosen ??= devices.first;

  final udn = chosen.getElement('UDN')?.innerText.trim();
  final name = chosen.getElement('friendlyName')?.innerText.trim();
  final model = chosen.getElement('modelName')?.innerText.trim();

  String? resolve(String? control) {
    if (control == null || control.isEmpty) return null;
    return descriptionUrl.resolve(control).toString();
  }

  return DlnaDevice(
    id: (udn == null || udn.isEmpty) ? descriptionUrl.toString() : udn,
    name: (name == null || name.isEmpty) ? 'DLNA 设备' : name,
    location: descriptionUrl.toString(),
    model: model,
    avTransportUrl: resolve(_serviceControl(chosen, 'AVTransport')),
    renderingControlUrl: resolve(_serviceControl(chosen, 'RenderingControl')),
  );
}

String? _serviceControl(XmlElement device, String fragment) {
  for (final service in device.findAllElements('service')) {
    final type = service.getElement('serviceType')?.innerText ?? '';
    if (!type.contains(fragment)) continue;
    final control = service.getElement('controlURL')?.innerText.trim();
    if (control == null || control.isEmpty) continue;
    return control;
  }
  return null;
}
