import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/url_template.dart';
import '../../data/local/settings_store.dart';
import '../widgets/common.dart';

/// 歌词接口设置：服务器歌词 / 在线歌词（LRCLIB）/ 自定义歌词接口。
class LyricsApiPage extends StatefulWidget {
  const LyricsApiPage({super.key});

  @override
  State<LyricsApiPage> createState() => _LyricsApiPageState();
}

class _LyricsApiPageState extends State<LyricsApiPage> {
  late final SettingsStore _settings = context.read<SettingsStore>();
  late final TextEditingController _url = TextEditingController(
    text: _settings.lyricsApiUrl,
  );
  late bool _online = _settings.onlineLyricsEnabled;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (url.isNotEmpty) {
      if (url.contains('api.example.com')) {
        showToast(context, '这是示例地址，请替换成你真实的歌词接口');
        return;
      }
      if (!UrlTemplate.hasPlaceholder(url)) {
        showToast(context, '歌词接口至少需要一个占位符，例如 {title} 或 {artist}');
        return;
      }
      if (UrlTemplate.expand(url, const {'title': 'test', 'artist': 'test'}) ==
          null) {
        showToast(context, '歌词接口需要以 http:// 或 https:// 开头');
        return;
      }
    }
    await _settings.setLyricsApiUrl(url);
    await _settings.setOnlineLyrics(_online);
    if (!mounted) return;
    showToast(context, '歌词接口已保存');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('歌词接口')),
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
              '歌词按「服务器 → 自定义接口 → 在线歌词」的顺序获取，'
              '前一个来源没有结果时才会请求下一个。服务器歌词来自 '
              'OpenSubsonic getLyricsBySongId / getLyrics。',
              style: AppText.caption.copyWith(
                color: palette.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _online,
              onChanged: (value) => setState(() => _online = value),
              title: Text(
                '在线歌词补全（LRCLIB）',
                style: AppText.titleSm.copyWith(color: palette.textPrimary),
              ),
              subtitle: Text(
                '服务器没有歌词时，按歌手 / 曲名 / 时长自动匹配',
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '自定义歌词接口（可选）',
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
              hintText:
                  'https://api.example.com/lyric?title={title}&artist={artist}',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '可用占位符：${UrlTemplate.lyricKeys.map((e) => '{$e}').join('  ')}\n'
            '返回 LRC 文本，或 JSON（会自动读取 lrc / lyric / lyrics / text / content 字段，'
            '兼容 data、result 包裹）。填写后优先于 LRCLIB。',
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
                label: '按歌名 + 歌手',
                onTap: () => setState(
                  () => _url.text = 'https://api.example.com/lyric?title={title}&artist={artist}',
                ),
              ),
              _ExampleChip(
                label: '按歌曲 id',
                onTap: () => setState(
                  () => _url.text = 'https://api.example.com/lyric/{id}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          BrandButton(label: '保存', expanded: true, onPressed: _save),
        ],
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
