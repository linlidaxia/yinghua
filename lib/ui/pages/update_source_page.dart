import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/settings_store.dart';
import '../../data/update/update_service.dart';
import '../widgets/common.dart';

/// 更新源设置：GitHub Release / 自建清单（NAS、对象存储）。
class UpdateSourcePage extends StatefulWidget {
  const UpdateSourcePage({super.key});

  @override
  State<UpdateSourcePage> createState() => _UpdateSourcePageState();
}

class _UpdateSourcePageState extends State<UpdateSourcePage> {
  late final SettingsStore _settings = context.read<SettingsStore>();
  late final TextEditingController _url = TextEditingController(
    text: _settings.updateManifestUrl,
  );
  late String _source = _settings.updateSource;
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (_source == 'manifest') {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        showToast(context, '清单地址需要以 http:// 或 https:// 开头');
        return;
      }
      if (uri.host.isEmpty) {
        showToast(context, '清单地址缺少主机名，例如 [2409:8a62::1]');
        return;
      }
    }
    await _settings.setUpdateManifestUrl(url);
    await _settings.setUpdateSource(_source);
    if (!mounted) return;
    showToast(
      context,
      _source == 'manifest' ? '已切换到自建更新清单' : '已使用 GitHub Release',
    );
    Navigator.of(context).pop();
  }

  /// 用当前填写的地址实际请求一次清单，展示解析结果。
  Future<void> _test() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      showToast(context, '请先填写清单地址');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      showToast(context, '清单地址需要以 http:// 或 https:// 开头');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final service = context.read<UpdateService>();
    try {
      final info = await service.checkManifest(url);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = info == null
            ? '成功 · 清单可访问，当前已是最新版本'
            : '成功 · 最新版本 ${info.version}'
                  '${info.apkSize > 0 ? ' · ${info.sizeMb.toStringAsFixed(1)} MB' : ''}';
      });
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '失败 · ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '失败 · $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('更新源')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'GitHub 直连在国内经常只有几十 KB/s，安装包要下很久。'
              '如果 NAS 24 小时开机，可以把它当成更新服务器：'
              'App 直接按 IPv6 地址读取清单并下载，几秒到几十秒就能下完。',
              style: AppText.caption.copyWith(
                color: palette.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Option(
            selected: _source == 'github',
            title: 'GitHub Release',
            subtitle: '公开仓库的 /releases/latest，可自动回退加速镜像',
            onTap: () => setState(() => _source = 'github'),
          ),
          const SizedBox(height: 10),
          _Option(
            selected: _source == 'manifest',
            title: '自建清单（NAS / 对象存储）',
            subtitle: '读取一个 JSON，按里面的 apk 地址直接下载',
            onTap: () => setState(() => _source = 'manifest'),
          ),
          if (_source == 'manifest') ...[
            const SizedBox(height: 16),
            Text(
              '清单地址',
              style: AppText.titleSm.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'http://[2409:8a62::1]:8080/yinghua/update.json',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '清单示例：\n'
              '{\n'
              '  "version": "1.0.22",\n'
              '  "notes": "本次更新内容",\n'
              '  "apk": "yinghua-1.0.22.apk",\n'
              '  "size": 69643090,\n'
              '  "sha256": "…"\n'
              '}\n'
              'apk 可以写相对文件名，也可以写完整 URL。SHA-256 建议填写，下载后会校验。',
              style: AppText.caption.copyWith(
                color: palette.textTertiary,
                height: 1.7,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 14),
            GhostButton(
              label: _testing ? '测试中…' : '测试清单',
              icon: Icons.wifi_tethering_rounded,
              onPressed: _testing ? null : _test,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Text(
                _testResult!,
                style: AppText.caption.copyWith(
                  color: _testResult!.startsWith('成功')
                      ? palette.textSecondary
                      : const Color(0xFFD13B3B),
                  height: 1.5,
                ),
              ),
            ],
          ],
          const SizedBox(height: 26),
          BrandButton(label: '保存', expanded: true, onPressed: _save),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: selected ? palette.brandSoft : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? palette.brand : palette.divider,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? palette.brand : palette.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(
                      color: palette.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
