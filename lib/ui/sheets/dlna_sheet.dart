import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/dlna/dlna_device.dart';
import '../../playback/dlna_controller.dart';
import '../widgets/common.dart';

/// 打开「投屏到 DLNA 设备」弹层。
Future<void> showDlnaSheet(BuildContext context) async {
  final dlna = context.read<DlnaController>();
  if (!dlna.hasDevice && dlna.devices.isEmpty && !dlna.busy) {
    dlna.search();
  }
  await showAppSheet<void>(context, (_) => const _DlnaBody());
}

class _DlnaBody extends StatefulWidget {
  const _DlnaBody();

  @override
  State<_DlnaBody> createState() => _DlnaBodyState();
}

class _DlnaBodyState extends State<_DlnaBody> {
  double _volume = 0.7;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dlna = context.watch<DlnaController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cast_rounded, size: 20, color: palette.brand),
              const SizedBox(width: 8),
              Text(
                '投屏播放',
                style: AppText.h2.copyWith(color: palette.textPrimary),
              ),
              const Spacer(),
              if (dlna.hasDevice)
                Text(
                  dlna.isCasting ? '已连接' : '连接中',
                  style: AppText.caption.copyWith(
                    color: dlna.isCasting ? palette.mint : palette.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '把当前歌曲推送到电视 / 音箱播放，需要设备与手机在同一局域网。',
            style: AppText.caption.copyWith(
              color: palette.textTertiary,
              height: 1.6,
            ),
          ),
          if (dlna.device != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.tv_rounded, size: 22, color: palette.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dlna.device!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSm.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dlna.device!.model ?? dlna.device!.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (dlna.device!.renderingControlUrl != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      onChanged: (value) => setState(() => _volume = value),
                      onChangeEnd: dlna.setVolume,
                    ),
                  ),
                  Text(
                    '${(_volume * 100).round()}',
                    style: AppText.numeric.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: '重新推送',
                    icon: Icons.refresh_rounded,
                    onPressed: dlna.busy ? null : dlna.castCurrent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrandButton(label: '断开投屏', onPressed: dlna.disconnect),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            if (dlna.busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.brand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '正在搜索局域网设备…',
                      style: AppText.bodySm.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (dlna.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dlna.message ?? '还没有发现设备。',
                      style: AppText.bodySm.copyWith(
                        color: palette.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GhostButton(
                      label: '重新搜索',
                      icon: Icons.wifi_find_rounded,
                      onPressed: dlna.search,
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: dlna.devices.length,
                  separatorBuilder: (_, __) => Divider(color: palette.divider),
                  itemBuilder: (context, index) {
                    final device = dlna.devices[index];
                    return _DeviceTile(
                      device: device,
                      onTap: device.canPlay ? () => dlna.connect(device) : null,
                    );
                  },
                ),
              ),
          ],
          if (dlna.message != null && dlna.device != null) ...[
            const SizedBox(height: 10),
            Text(
              dlna.message!,
              style: AppText.caption.copyWith(
                color: const Color(0xFFD13B3B),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final DlnaDevice device;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          device.canPlay ? Icons.speaker_rounded : Icons.tv_off_rounded,
          size: 20,
          color: device.canPlay ? palette.brand : palette.textTertiary,
        ),
      ),
      title: Text(
        device.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.titleSm.copyWith(color: palette.textPrimary),
      ),
      subtitle: Text(
        device.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption.copyWith(color: palette.textTertiary),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: palette.textTertiary,
      ),
      onTap: onTap,
    );
  }
}
