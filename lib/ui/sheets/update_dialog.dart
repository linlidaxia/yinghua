import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_version.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/settings_store.dart';
import '../../data/update/update_service.dart';
import '../widgets/common.dart';

/// 检查更新。
///
/// [manual] 为 false 时用于启动自动检测：失败静默、点「稍后」会记住该版本；
/// 为 true 时用于设置页手动检测：失败与「已是最新」都会明确提示。
Future<void> checkForUpdates(
  BuildContext context, {
  bool manual = false,
}) async {
  final service = context.read<UpdateService>();
  final settings = context.read<SettingsStore>();
  try {
    final info = await service.checkLatest();
    if (!context.mounted) return;
    if (info == null) {
      if (manual) showToast(context, '当前已是最新版本 ${AppVersion.current}');
      return;
    }
    if (!manual && info.version == settings.skippedUpdateVersion) {
      // 用户上次选择了「稍后」，本次启动不再打扰。
      return;
    }
    await promptUpdate(context, info, manual: manual);
  } on UpdateException catch (error) {
    if (!context.mounted) return;
    if (manual) showToast(context, error.message);
  } catch (error) {
    if (!context.mounted) return;
    if (manual) showToast(context, '检查更新失败：$error');
  }
}

/// 弹出版本说明，确认后下载并引导安装。
Future<void> promptUpdate(
  BuildContext context,
  UpdateInfo info, {
  bool manual = false,
}) async {
  final settings = context.read<SettingsStore>();
  final service = context.read<UpdateService>();

  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = AppPalette.of(dialogContext);
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        title: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: palette.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '发现新版本 ${info.version}',
                style: AppText.h2.copyWith(color: palette.textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前 ${AppVersion.current}'
                '${info.apkSize > 0 ? ' · ${info.sizeMb.toStringAsFixed(1)} MB' : ''}',
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      info.notes,
                      style: AppText.bodySm.copyWith(
                        color: palette.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '更新包会从 GitHub 下载，安装前系统可能要求允许「安装未知应用」。',
                style: AppText.caption.copyWith(
                  color: palette.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('立即更新'),
          ),
        ],
      );
    },
  );

  if (accepted != true) {
    if (!manual) await settings.skipUpdateVersion(info.version);
    return;
  }
  await settings.clearSkippedUpdate();
  if (!context.mounted) return;
  await _downloadAndInstall(context, service, info);
}

Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) async {
  final progress = ValueNotifier<double>(0);
  final label = ValueNotifier<String>('正在准备下载…');
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogClosed = false;
  var cancelled = false;

  void closeDialog() {
    if (dialogClosed) return;
    dialogClosed = true;
    if (navigator.canPop()) navigator.pop();
  }

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在下载更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value <= 0 ? null : value,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(99),
                    color: palette.brand,
                    backgroundColor: palette.divider,
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: label,
                  builder: (_, text, __) => Text(
                    text,
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '直连较慢时会自动改用加速镜像',
                  style: AppText.caption.copyWith(
                    color: palette.textTertiary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  service.cancelDownload();
                  closeDialog();
                },
                child: const Text('取消下载'),
              ),
            ],
          ),
        );
      },
    ),
  );

  String? path;
  String? failure;
  try {
    path = await service.download(
      info,
      onProgress: (received, total) {
        final size = total > 0 ? total : info.apkSize;
        if (size <= 0) {
          label.value = '已下载 ${(received / 1024 / 1024).toStringAsFixed(1)} MB';
          return;
        }
        progress.value = (received / size).clamp(0.0, 1.0);
        label.value =
            '${(received / 1024 / 1024).toStringAsFixed(1)} / '
            '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
      },
    );
  } on UpdateException catch (error) {
    failure = error.message;
  } catch (error) {
    failure = '下载失败：$error';
  } finally {
    closeDialog();
  }

  if (!context.mounted) return;
  if (cancelled) return;
  if (failure != null) {
    showToast(context, failure);
    return;
  }
  if (path == null) return;

  final install = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = AppPalette.of(dialogContext);
      return AlertDialog(
        title: const Text('下载完成'),
        content: Text(
          '莺花 ${info.version} 已下载完成，是否现在安装？',
          style: AppText.bodySm.copyWith(
            color: palette.textSecondary,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('立即安装'),
          ),
        ],
      );
    },
  );
  if (install != true || !context.mounted) return;

  final allowed = await service.canInstall();
  if (!context.mounted) return;
  if (!allowed) {
    await _showInstallPermission(context, service);
    return;
  }
  final started = await service.install(path);
  if (!started && context.mounted) {
    await _showInstallPermission(context, service);
  }
}

Future<void> _showInstallPermission(
  BuildContext context,
  UpdateService service,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('需要安装权限'),
      content: const Text('请允许莺花安装应用，返回后即可继续安装更新。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('去设置'),
        ),
      ],
    ),
  );
  if (go == true) await service.openInstallSettings();
}
