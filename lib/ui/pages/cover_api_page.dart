import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/url_template.dart';
import '../../data/local/settings_store.dart';
import '../widgets/common.dart';

/// 封面接口设置：服务器封面 / 自定义图片接口。
class CoverApiPage extends StatefulWidget {
  const CoverApiPage({super.key});

  @override
  State<CoverApiPage> createState() => _CoverApiPageState();
}

class _CoverApiPageState extends State<CoverApiPage> {
  late final SettingsStore _settings = context.read<SettingsStore>();
  late final TextEditingController _url = TextEditingController(
    text: _settings.coverApiUrl,
  );
  late String _source = _settings.coverSource;
  bool _testing = false;
  String? _testResult;
  Uint8List? _preview;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (_source == 'custom') {
      if (url.isEmpty) {
        showToast(context, '请填写封面接口地址');
        return;
      }
      if (url.contains('api.example.com')) {
        showToast(context, '这是示例地址，请替换成你真实的封面接口');
        return;
      }
      if (!UrlTemplate.hasPlaceholder(url)) {
        showToast(context, '接口地址里至少需要一个占位符，例如 {id} 或 {album}');
        return;
      }
      if (UrlTemplate.expand(url, const {'id': '1', 'size': '360'}) == null) {
        showToast(context, '接口地址需要以 http:// 或 https:// 开头');
        return;
      }
    }
    await _settings.setCoverApiUrl(url);
    await _settings.setCoverSource(_source);
    if (!mounted) return;
    showToast(context, _source == 'custom' ? '已切换到自定义封面接口' : '已使用服务器封面');
    Navigator.of(context).pop();
  }

  /// 用示例歌曲实际请求一次接口，返回状态、类型与预览图。
  Future<void> _test() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      showToast(context, '请先填写接口地址');
      return;
    }
    if (!UrlTemplate.hasPlaceholder(url)) {
      showToast(context, '接口地址里至少需要一个占位符，例如 {id} 或 {album}');
      return;
    }
    final sample = UrlTemplate.expand(url, const {
      'id': 'al-1',
      'size': '360',
      'album': 'Super Star',
      'artist': 'S.H.E',
      'title': 'Super Star',
    });
    if (sample == null) {
      showToast(context, '接口地址需要以 http:// 或 https:// 开头');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _preview = null;
    });
    try {
      final response = await Dio().get<List<int>>(
        sample,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 12),
          validateStatus: (status) => status != null && status < 500,
          followRedirects: true,
        ),
      );
      final bytes = response.data ?? const <int>[];
      final type = response.headers.value('content-type') ?? '未知类型';
      final status = response.statusCode ?? 0;
      final ok =
          status == 200 &&
          bytes.length > 512 &&
          type.toLowerCase().startsWith('image/');
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = ok
            ? '成功 · HTTP 200 · $type · ${(bytes.length / 1024).toStringAsFixed(0)} KB'
            : '失败 · HTTP $status · $type · ${bytes.length} 字节';
        _preview = ok ? Uint8List.fromList(bytes) : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '请求失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('封面接口')),
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
              '默认使用音乐服务器的封面（Navidrome / Subsonic 的 getCoverArt）。'
              '如果服务器封面缺失或加载慢，可以换成任意返回图片的接口。',
              style: AppText.caption.copyWith(
                color: palette.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Option(
            selected: _source == 'server',
            title: '服务器封面',
            subtitle: 'Navidrome getCoverArt，随歌曲自动更新',
            onTap: () => setState(() => _source = 'server'),
          ),
          const SizedBox(height: 10),
          _Option(
            selected: _source == 'custom',
            title: '自定义封面接口',
            subtitle: '支持 {id} {size} {album} {artist} {title} 占位符',
            onTap: () => setState(() => _source = 'custom'),
          ),
          if (_source == 'custom') ...[
            const SizedBox(height: 16),
            Text(
              '接口地址',
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
                hintText: 'https://api.example.com/cover?artist={artist}&album={album}&size={size}',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '可用占位符：${UrlTemplate.coverKeys.map((e) => '{$e}').join('  ')}\n'
              '接口需要直接返回图片（jpg / png / webp），无需鉴权也可以把 token 写进地址里。',
              style: AppText.caption.copyWith(
                color: palette.textTertiary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ExampleChip(
                  label: '按歌曲 id',
                  onTap: () => setState(
                    () => _url.text =
                        'https://api.example.com/cover/{id}?size={size}',
                  ),
                ),
                _ExampleChip(
                  label: '按专辑名',
                  onTap: () => setState(
                    () => _url.text = 'https://api.example.com/cover?album={album}&artist={artist}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                GhostButton(
                  label: _testing ? '测试中…' : '测试接口',
                  icon: Icons.wifi_tethering_rounded,
                  onPressed: _testing ? null : _test,
                ),
                if (_preview != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _preview!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ],
              ],
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? palette.brand : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
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
                    style: AppText.titleSm.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: palette.brandSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(color: palette.brand),
        ),
      ),
    );
  }
}
