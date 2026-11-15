import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_version.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/download_manager.dart';
import '../../data/local/favorites_store.dart';
import '../../data/local/settings_store.dart';
import '../../data/sources/source_registry.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import 'downloads_page.dart';
import 'favorites_page.dart';
import 'folder_page.dart';
import 'home_layout_page.dart';
import 'recent_page.dart';
import 'servers_page.dart';
import 'settings_page.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final registry = context.watch<SourceRegistry>();
    final favorites = context.watch<FavoritesStore>();
    final downloads = context.watch<DownloadManager>();
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            4,
            AppSpace.page,
            30,
          ),
          children: [
            Row(
              children: [
                Text(
                  '我的',
                  style: AppText.display.copyWith(
                    color: palette.textPrimary,
                    fontSize: 24,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 22),
                  color: palette.textSecondary,
                  tooltip: '设置',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProfileCard(
              serverName: registry.isDemo ? '演示资料库' : registry.displayName,
              protocol: registry.protocolName,
              favoriteCount: favorites.songCount,
              downloadCount: downloads.count,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ServersPage()),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '我的音乐',
              style: AppText.h2.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 12),
            _EntryGrid(
              entries: [
                _Entry(
                  icon: Icons.favorite_rounded,
                  label: '我喜欢的音乐',
                  detail: '${favorites.songCount} 首',
                  color: palette.brand,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesPage(),
                    ),
                  ),
                ),
                _Entry(
                  icon: Icons.history_rounded,
                  label: '最近播放',
                  detail: '${settings.recentSongs.length} 首',
                  color: const Color(0xFF4C7DD8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecentSongsPage(),
                    ),
                  ),
                ),
                _Entry(
                  icon: Icons.download_done_rounded,
                  label: '本地下载',
                  detail: '${downloads.count} 首',
                  color: const Color(0xFF3AAE8C),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DownloadsPage(),
                    ),
                  ),
                ),
                _Entry(
                  icon: Icons.folder_open_rounded,
                  label: '文件夹',
                  detail: '按目录浏览',
                  color: const Color(0xFFF0A93B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const FolderPage()),
                  ),
                ),
                _Entry(
                  icon: Icons.dns_outlined,
                  label: '音乐服务器',
                  detail: registry.isDemo ? '演示中' : 'Navidrome',
                  color: const Color(0xFF8E7BD8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ServersPage(),
                    ),
                  ),
                ),
                _Entry(
                  icon: Icons.dashboard_customize_outlined,
                  label: '首页自定义',
                  detail: '排序与隐藏',
                  color: const Color(0xFF5C9BB8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HomeLayoutPage(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsPreview(
              settings: settings,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Column(
                children: [
                  const BrandMark(size: 26),
                  const SizedBox(height: 8),
                  Text(
                    '莺花 · ${AppVersion.current}',
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '所有功能默认开放，不含会员、付费与广告',
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
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.serverName,
    required this.protocol,
    required this.favoriteCount,
    required this.downloadCount,
    required this.onTap,
  });

  final String serverName;
  final String protocol;
  final int favoriteCount;
  final int downloadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.isDark
                ? [const Color(0xFF2A1D20), const Color(0xFF1C1C22)]
                : [const Color(0xFFFFF3F1), const Color(0xFFF7F7FA)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.bg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.brand.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Center(child: BrandMark(size: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(
                          color: palette.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.mint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              protocol.isEmpty ? '未连接服务器' : protocol,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(value: '$favoriteCount', label: '收藏'),
                _divider(palette),
                _Stat(value: '$downloadCount', label: '已下载'),
                _divider(palette),
                _Stat(value: '免费', label: '全部功能', highlight: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppPalette palette) => Container(
    width: 1,
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    color: palette.divider,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppText.title.copyWith(
            color: highlight ? palette.brand : palette.textPrimary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppText.caption.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class _Entry {
  const _Entry({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.55,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return PressableScale(
          onTap: entry.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entry.icon, size: 18, color: entry.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleSm.copyWith(
                          color: palette.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
        );
      },
    );
  }
}

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview({required this.settings, required this.onOpen});

  final SettingsStore settings;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.light => '浅色模式',
      ThemeMode.dark => '深色模式',
      ThemeMode.system => '跟随系统',
    };
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          _PreviewTile(
            icon: Icons.contrast_rounded,
            label: '外观',
            value: themeLabel,
            onTap: onOpen,
          ),
          Divider(height: 1, indent: 56, color: palette.divider),
          _PreviewTile(
            icon: Icons.graphic_eq_rounded,
            label: '播放',
            value: settings.cacheEnabled ? '边听边存已开启' : '仅在线播放',
            onTap: onOpen,
          ),
          Divider(height: 1, indent: 56, color: palette.divider),
          _PreviewTile(
            icon: Icons.info_outline_rounded,
            label: '关于莺花',
            value: '免费 · 无广告',
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: palette.textPrimary),
              ),
            ),
            Text(
              value,
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
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
