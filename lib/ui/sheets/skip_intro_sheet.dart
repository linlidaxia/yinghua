import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/skip_config.dart';
import '../widgets/common.dart';

/// 歌单级别的「跳过片头 / 片尾」设置（有声书、广播剧）。
Future<void> showSkipIntroSheet(
  BuildContext context, {
  required String playlistId,
  required String playlistName,
}) async {
  await showAppSheet<void>(
    context,
    (_) => _SkipIntroBody(playlistId: playlistId, playlistName: playlistName),
  );
}

class _SkipIntroBody extends StatefulWidget {
  const _SkipIntroBody({required this.playlistId, required this.playlistName});

  final String playlistId;
  final String playlistName;

  @override
  State<_SkipIntroBody> createState() => _SkipIntroBodyState();
}

class _SkipIntroBodyState extends State<_SkipIntroBody> {
  late final SettingsStore _settings = context.read<SettingsStore>();
  late bool _enabled;
  late final TextEditingController _intro;
  late final TextEditingController _outro;

  @override
  void initState() {
    super.initState();
    final config = _settings.skipFor(widget.playlistId);
    _enabled = config?.enabled ?? true;
    _intro = TextEditingController(
      text: ((config?.intro.inSeconds) ?? 0).toString(),
    );
    _outro = TextEditingController(
      text: ((config?.outro.inSeconds) ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _outro.dispose();
    super.dispose();
  }

  int _seconds(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim()) ?? 0;
    return value.clamp(0, 600);
  }

  Future<void> _save() async {
    final intro = _seconds(_intro);
    final outro = _seconds(_outro);
    if (intro == 0 && outro == 0) {
      await _settings.clearPlaylistSkip(widget.playlistId);
    } else {
      await _settings.setPlaylistSkip(
        widget.playlistId,
        SkipConfig(
          intro: Duration(seconds: intro),
          outro: Duration(seconds: outro),
          enabled: _enabled,
        ),
      );
    }
    if (!mounted) return;
    showToast(
      context,
      intro == 0 && outro == 0
          ? '已关闭该歌单的跳过头尾'
          : '已应用到「${widget.playlistName}」全部曲目',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text('跳过片头片尾', style: AppText.h2.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 6),
        Text(
          '有声书 / 广播剧常带片头片尾。设置后，'
          '播放「${widget.playlistName}」里的每一集都会自动从片头结束处开始，'
          '并在片尾开始前跳到下一集。',
          style: AppText.caption.copyWith(
            color: palette.textTertiary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          title: Text(
            '启用跳过头尾',
            style: AppText.titleSm.copyWith(color: palette.textPrimary),
          ),
          subtitle: Text(
            '关闭后保留设置，但播放时不跳过',
            style: AppText.caption.copyWith(color: palette.textTertiary),
          ),
        ),
        const SizedBox(height: 6),
        _Field(label: '片头', hint: '跳过开头的秒数', controller: _intro, suffix: '秒'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final seconds in const [15, 30, 45, 60])
              _Chip(
                label: '${seconds}s',
                onTap: () => setState(() => _intro.text = '$seconds'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Field(label: '片尾', hint: '提前结束的秒数', controller: _outro, suffix: '秒'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final seconds in const [10, 15, 30, 45])
              _Chip(
                label: '${seconds}s',
                onTap: () => setState(() => _outro.text = '$seconds'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: '清除',
                icon: Icons.delete_outline_rounded,
                onPressed: () async {
                  await _settings.clearPlaylistSkip(widget.playlistId);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  showToast(context, '已清除该歌单的跳过头尾');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: BrandButton(label: '保存并应用', onPressed: _save),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: AppText.bodySm.copyWith(color: palette.textPrimary),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: hint, suffixText: suffix),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

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
