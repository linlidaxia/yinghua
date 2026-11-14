import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 后台保活状态。
class BackgroundStatus {
  const BackgroundStatus({
    required this.ignoringBattery,
    required this.notifications,
    required this.manufacturer,
    required this.sdk,
  });

  final bool ignoringBattery;
  final bool notifications;
  final String manufacturer;
  final int sdk;

  bool get isReady => ignoringBattery && notifications;

  static const unknown = BackgroundStatus(
    ignoringBattery: false,
    notifications: true,
    manufacturer: '',
    sdk: 0,
  );
}

/// 与 Android 原生侧的后台保活通道。
///
/// 网页 / 桌面没有这些系统设置，统一降级为「未知」并给出通用提示。
class BackgroundGuard {
  BackgroundGuard._();

  static const MethodChannel _channel = MethodChannel(
    'com.yinghua.yinghua/background',
  );

  static Future<BackgroundStatus> status() async {
    if (kIsWeb) return BackgroundStatus.unknown;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('status');
      if (raw == null) return BackgroundStatus.unknown;
      return BackgroundStatus(
        ignoringBattery: raw['ignoringBattery'] == true,
        notifications: raw['notifications'] == true,
        manufacturer: '${raw['manufacturer'] ?? ''}',
        sdk: (raw['sdk'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return BackgroundStatus.unknown;
    }
  }

  /// 申请忽略电池优化（会弹出系统确认框）。
  static Future<bool> requestIgnoreBattery() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('requestIgnoreBattery') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openBatterySettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } catch (_) {
      // 忽略。
    }
  }

  /// 打开国产 ROM 的「自启动 / 后台运行」管理页。
  static Future<bool> openAutoStart() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutoStart') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android 13+ 需要运行时通知权限，否则媒体通知不会显示。
  static Future<bool> requestNotifications() async {
    if (kIsWeb) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } catch (_) {
      return true;
    }
  }

  /// 针对不同厂商给一句更具体的操作建议。
  static String tipFor(String manufacturer) {
    final name = manufacturer.toLowerCase();
    if (name.contains('xiaomi') || name.contains('redmi')) {
      return '小米 / Redmi：设置 → 应用设置 → 莺花 → 省电策略选「无限制」，'
          '并打开「自启动」；最近任务里下拉 App 卡片加锁。';
    }
    if (name.contains('huawei') || name.contains('honor')) {
      return '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 莺花改为「手动管理」，'
          '允许自启动、关联启动、后台活动。';
    }
    if (name.contains('oppo') ||
        name.contains('realme') ||
        name.contains('oneplus')) {
      return 'OPPO / realme / 一加：设置 → 电池 → 应用耗电管理 → 莺花 → 允许后台运行，'
          '并在「自启动」里打开。';
    }
    if (name.contains('vivo') || name.contains('iqoo')) {
      return 'vivo / iQOO：设置 → 电池 → 后台高耗电 → 允许莺花后台运行；'
          'i管家 → 应用管理 → 自启动 → 打开。';
    }
    if (name.contains('samsung')) {
      return '三星：设置 → 电池 → 后台使用限制 → 从「休眠应用」中移除莺花。';
    }
    return '在系统设置里允许莺花「后台运行 / 自启动」，并在最近任务中锁定本应用。';
  }
}
