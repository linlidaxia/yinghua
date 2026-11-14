import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/background_guard.dart';
import '../widgets/common.dart';

/// 后台播放保护说明与快捷设置。
Future<void> showBackgroundGuardSheet(BuildContext context) async {
  await showAppSheet<void>(context, (_) => const _BackgroundGuardBody());
}

class _BackgroundGuardBody extends StatefulWidget {
  const _BackgroundGuardBody();

  @override
  State<_BackgroundGuardBody> createState() => _BackgroundGuardBodyState();
}

class _BackgroundGuardBodyState extends State<_BackgroundGuardBody> {
  BackgroundStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await BackgroundGuard.status();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (!mounted) return;
    setState(() => _busy = false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final status = _status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon_outlined, size: 20, color: palette.brand),
              const SizedBox(width: 8),
              Text(
                '后台播放保护',
                style: AppText.h2.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Android 可能在锁屏或切到后台后清理应用。完成下面两项后，'
            '播放会以「前台服务 + 常驻通知」的形式继续运行。',
            style: AppText.caption.copyWith(
              color: palette.textTertiary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          if (status == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在读取系统设置…',
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _StatusRow(
              icon: Icons.notifications_active_outlined,
              title: '媒体通知权限',
              ok: status.notifications,
              okText: '已允许',
              failText: '未允许',
            ),
            const SizedBox(height: 8),
            _StatusRow(
              icon: Icons.battery_charging_full_rounded,
              title: '忽略电池优化',
              ok: status.ignoringBattery,
              okText: '已允许后台运行',
              failText: '未允许',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BrandButton(
                    label: _busy ? '请稍候…' : '允许后台运行',
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await BackgroundGuard.requestNotifications();
                            await BackgroundGuard.requestIgnoreBattery();
                          }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: '自启动设置',
                    icon: Icons.settings_outlined,
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final opened =
                                await BackgroundGuard.openAutoStart();
                            if (!opened) {
                              await BackgroundGuard.openBatterySettings();
                            }
                          }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(BackgroundGuard.openBatterySettings),
              child: Text(
                '打开系统电池优化设置',
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                BackgroundGuard.tipFor(status.manufacturer),
                style: AppText.caption.copyWith(
                  color: palette.textSecondary,
                  height: 1.7,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '提示：插着耳机 / 蓝牙时，音量和播放键由系统媒体会话接管；'
            '如果仍被清理，请把本应用从「省电模式」白名单中排除。',
            style: AppText.caption.copyWith(
              color: palette.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okText,
    required this.failText,
  });

  final IconData icon;
  final String title;
  final bool ok;
  final String okText;
  final String failText;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppText.bodySm.copyWith(color: palette.textPrimary),
          ),
        ),
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 17,
          color: ok ? palette.mint : palette.brand,
        ),
        const SizedBox(width: 5),
        Text(
          ok ? okText : failText,
          style: AppText.caption.copyWith(
            color: ok ? palette.mint : palette.brand,
          ),
        ),
      ],
    );
  }
}
