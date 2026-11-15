import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_presets.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/download_manager.dart';
import '../../data/local/settings_store.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/audio_cache.dart';
import '../../playback/playback_controller.dart';
import '../sheets/background_sheet.dart';
import '../sheets/lyric_offset_sheet.dart';
import '../sheets/song_actions.dart';
import '../sheets/dlna_sheet.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import 'cover_api_page.dart';
import 'downloads_page.dart';
import 'home_layout_page.dart';
import 'lyrics_api_page.dart';
import 'servers_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int? _cacheBytes;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final bytes = await AudioCache.totalBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final registry = context.watch<SourceRegistry>();
    final downloads = context.watch<DownloadManager>();
    final playback = context.watch<PlaybackController>();
    final palette = AppPalette.of(context);

    final themeLabel = switch (settings.themeMode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟随系统',
    };
    final bitrateLabel = settings.maxBitRate <= 0
        ? '原始音质'
        : '${settings.maxBitRate} kbps';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
        children: [
          _GroupLabel('外观'),
          _Group(
            children: [
              _Tile(
                icon: Icons.palette_outlined,
                title: '主题风格',
                subtitle: '切换成主流音乐 App 的配色',
                trailingText: AppPresets.byId(settings.themePreset).name,
                onTap: () => _selectPreset(context, settings),
              ),
              _Tile(
                icon: Icons.contrast_rounded,
                title: '亮暗模式',
                subtitle: '浅色、深色或跟随系统',
                trailingText: themeLabel,
                onTap: () => _selectTheme(context, settings),
              ),
              _Tile(
                icon: Icons.dashboard_customize_outlined,
                title: '首页自定义',
                subtitle: '调整模块顺序，隐藏不需要的内容',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HomeLayoutPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _GroupLabel('播放'),
          _Group(
            children: [
              _SwitchTile(
                icon: Icons.cloud_download_outlined,
                title: '边听边存',
                subtitle: '播放时缓存音频，下次离线可听',
                value: settings.cacheEnabled,
                onChanged: settings.setCacheEnabled,
              ),
              _SwitchTile(
                icon: Icons.graphic_eq_rounded,
                title: '回放增益',
                subtitle: '按 ReplayGain 标签平衡不同歌曲音量',
                value: settings.replayGainEnabled,
                onChanged: settings.setReplayGain,
              ),
              _Tile(
                icon: Icons.high_quality_outlined,
                title: '音质上限',
                subtitle: '限制串流码率，节省流量',
                trailingText: bitrateLabel,
                onTap: () => _selectBitrate(context, settings),
              ),
              _Tile(
                icon: Icons.bedtime_outlined,
                title: '定时停止',
                subtitle: playback.sleepRemaining != null
                    ? '剩余 ${Fmt.clock(playback.sleepRemaining)} 后自动暂停'
                    : playback.sleepEndOfTrack
                    ? '播完当前歌曲后自动暂停'
                    : '到点自动暂停，适合睡前听歌',
                trailingText: playback.hasSleepTimer ? '修改' : '设置',
                onTap: () => showSleepTimerSheet(context),
              ),
              _Tile(
                icon: Icons.shield_moon_outlined,
                title: '后台播放保护',
                subtitle: '避免锁屏或切后台后被系统清理',
                trailingText: '设置',
                onTap: () => showBackgroundGuardSheet(context),
              ),
              _SwitchTile(
                icon: Icons.subtitles_outlined,
                title: '桌面歌词',
                subtitle: '在应用内显示可拖动的悬浮歌词',
                value: settings.floatingLyricEnabled,
                onChanged: settings.setFloatingLyric,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _GroupLabel('歌词'),
          _Group(
            children: [
              _Tile(
                icon: Icons.travel_explore_rounded,
                title: '歌词接口',
                subtitle: settings.lyricsApiUrl.isNotEmpty
                    ? '服务器 → 自定义接口 → 在线歌词'
                    : settings.onlineLyricsEnabled
                    ? '服务器 → LRCLIB 在线歌词'
                    : '仅使用服务器歌词',
                trailingText: '配置',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LyricsApiPage(),
                  ),
                ),
              ),
              _Tile(
                icon: Icons.tune_rounded,
                title: '歌词时间校准',
                subtitle: '只影响当前歌曲；在歌单页可应用到整个歌单',
                trailingText: playback.current == null
                    ? '未在播放'
                    : Fmt.lyricOffset(playback.lyricOffsetMs),
                onTap: () => showLyricOffsetSheet(context),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _GroupLabel('接口'),
          _Group(
            children: [
              _Tile(
                icon: Icons.image_outlined,
                title: '封面接口',
                subtitle: settings.coverSource == 'custom'
                    ? '自定义图片接口'
                    : '服务器封面（getCoverArt）',
                trailingText: '配置',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CoverApiPage()),
                ),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _GroupLabel('存储'),
          _Group(
            children: [
              _Tile(
                icon: Icons.download_done_rounded,
                title: '本地下载',
                subtitle:
                    '${downloads.count} 首 · ${Fmt.fileSize(downloads.totalBytes)}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadsPage(),
                  ),
                ),
              ),
              _Tile(
                icon: Icons.cached_rounded,
                title: '播放缓存',
                subtitle: _cacheBytes == null
                    ? '正在统计'
                    : Fmt.fileSize(_cacheBytes!),
                trailingText: '清理',
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '清理播放缓存',
                    message: '只会删除「边听边存」产生的临时缓存，离线下载不受影响。',
                    confirmText: '清理',
                  );
                  if (!confirmed) return;
                  await AudioCache.clear();
                  await _loadCache();
                  if (context.mounted) showToast(context, '播放缓存已清理');
                },
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _GroupLabel('服务'),
          _Group(
            children: [
              _Tile(
                icon: Icons.dns_outlined,
                title: '音乐服务器',
                subtitle: registry.hasSource
                    ? '${registry.displayName} · ${registry.protocolName}'
                    : '尚未连接',
                trailingText: '${registry.servers.length} 台',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ServersPage()),
                ),
              ),
              _Tile(
                icon: Icons.cast_rounded,
                title: 'DLNA 投屏',
                subtitle: '把当前歌曲推送到电视 / 音箱',
                trailingText: '搜索设备',
                onTap: () => showDlnaSheet(context),
              ),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: '关于莺花',
                subtitle: '版本 1.0.19 · 所有功能免费开放',
                onTap: () => _showAbout(context),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const BrandMark(size: 30),
                const SizedBox(height: 10),
                Text(
                  '莺花 1.0.19',
                  style: AppText.caption.copyWith(
                    color: palette.textTertiary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '不提供任何音频内容 · 仅连接你自建的音乐服务',
                  style: AppText.caption.copyWith(
                    color: palette.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPreset(
    BuildContext context,
    SettingsStore settings,
  ) async {
    await showAppSheet<void>(context, (sheetContext) {
      final palette = AppPalette.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '主题风格',
                    style: AppText.h2.copyWith(color: palette.textPrimary),
                  ),
                ),
                Text(
                  '参考主流音乐 App',
                  style: AppText.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
          for (final preset in AppPresets.all)
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: preset.brand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: preset.brand.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  preset.isDefault
                      ? Icons.local_florist_rounded
                      : Icons.music_note_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              title: Text(preset.name),
              subtitle: Text(
                preset.description,
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
              trailing: settings.themePreset == preset.id
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: preset.brand,
                    )
                  : null,
              onTap: () {
                settings.setThemePreset(preset.id);
                Navigator.of(sheetContext).pop();
              },
            ),
          const SizedBox(height: 10),
        ],
      );
    });
  }

  Future<void> _selectTheme(
    BuildContext context,
    SettingsStore settings,
  ) async {
    await showAppSheet<void>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  '主题',
                  style: AppText.h2.copyWith(
                    color: AppPalette.of(sheetContext).textPrimary,
                  ),
                ),
              ],
            ),
          ),
          for (final entry in const [
            (ThemeMode.system, '跟随系统', '随系统的深浅色自动切换'),
            (ThemeMode.light, '浅色模式', '白底黑字，品牌红点缀'),
            (ThemeMode.dark, '深色模式', '暗色背景，夜间更舒适'),
          ])
            ListTile(
              leading: Icon(
                entry.$1 == ThemeMode.system
                    ? Icons.brightness_auto_rounded
                    : entry.$1 == ThemeMode.light
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 21,
              ),
              title: Text(entry.$2),
              subtitle: Text(
                entry.$3,
                style: AppText.caption.copyWith(
                  color: AppPalette.of(sheetContext).textTertiary,
                ),
              ),
              trailing: settings.themeMode == entry.$1
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppPalette.of(sheetContext).brand,
                    )
                  : null,
              onTap: () {
                settings.setThemeMode(entry.$1);
                Navigator.of(sheetContext).pop();
              },
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Future<void> _selectBitrate(
    BuildContext context,
    SettingsStore settings,
  ) async {
    const options = [
      (0, '原始音质', '不限制码率，优先音质'),
      (320, '320 kbps', '高质量，适合移动网络'),
      (192, '192 kbps', '均衡，节省流量'),
      (128, '128 kbps', '流量优先'),
    ];
    await showAppSheet<void>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Text(
                  '音质上限',
                  style: AppText.h2.copyWith(
                    color: AppPalette.of(sheetContext).textPrimary,
                  ),
                ),
              ],
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.$2),
              subtitle: Text(
                option.$3,
                style: AppText.caption.copyWith(
                  color: AppPalette.of(sheetContext).textTertiary,
                ),
              ),
              trailing: settings.maxBitRate == option.$1
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppPalette.of(sheetContext).brand,
                    )
                  : null,
              onTap: () {
                settings.setMaxBitRate(option.$1);
                Navigator.of(sheetContext).pop();
              },
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final palette = AppPalette.of(context);
    await showAppSheet<void>(
      context,
      (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
        children: [
          Center(child: const BrandMark(size: 44)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              '莺花',
              style: AppText.h1.copyWith(
                color: palette.textPrimary,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '版本 1.0.19',
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '莺花是一款个人音乐库播放器，通过 Subsonic / OpenSubsonic 协议连接你自己搭建的 Navidrome 等服务器。应用本身不提供、不分发任何音频内容。',
            style: AppText.bodySm.copyWith(
              color: palette.textSecondary,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '所有功能——下载、歌词、音质、多服务器、主题、首页自定义、定时停止、回放增益——默认开放，没有会员、付费、广告或功能解锁。',
            style: AppText.bodySm.copyWith(
              color: palette.textSecondary,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutRow(label: '协议', value: 'Subsonic API 1.16.1'),
                _AboutRow(label: '登录', value: 'Token 认证，不保存明文密码'),
                _AboutRow(label: '数据', value: '仅保存在本机'),
                _AboutRow(label: '权限', value: '网络、前台服务、通知'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BrandButton(
            label: '知道了',
            expanded: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.caption.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: AppText.caption.copyWith(
          color: palette.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 14),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText!,
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            ],
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(width: 14),
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
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
