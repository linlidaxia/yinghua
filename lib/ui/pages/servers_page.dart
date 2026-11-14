import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/url_utils.dart';
import '../../data/models/server_config.dart';
import '../../data/sources/source_registry.dart';
import '../widgets/common.dart';
import 'server_login_page.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  @override
  Widget build(BuildContext context) {
    final registry = context.watch<SourceRegistry>();
    final palette = AppPalette.of(context);
    final servers = registry.servers;

    return Scaffold(
      appBar: AppBar(title: const Text('音乐服务器')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          10,
          AppSpace.page,
          28,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: palette.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '莺花使用 Subsonic Token 认证，只在本地保存 salt 与哈希，不会保存明文密码。',
                    style: AppText.caption.copyWith(
                      color: palette.brand,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '已连接',
                style: AppText.h2.copyWith(color: palette.textPrimary),
              ),
              const Spacer(),
              Text(
                '${servers.length} 台',
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (servers.isEmpty)
            const EmptyState(
              icon: Icons.dns_outlined,
              title: '还没有服务器',
              message: '添加 Navidrome / Subsonic 地址即可开始',
            )
          else
            for (final server in servers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ServerCard(
                  server: server,
                  active: registry.activeId == server.id,
                  onTap: () async {
                    await registry.activate(server.id);
                    if (context.mounted) {
                      showToast(context, '已切换到 ${server.name}');
                    }
                  },
                  onEdit: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServerLoginPage(existing: server),
                      ),
                    );
                  },
                  onDelete: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: '删除服务器',
                      message: '只会移除本机保存的连接信息，服务器上的音乐不受影响。',
                      confirmText: '删除',
                    );
                    if (!confirmed) return;
                    await registry.removeServer(server.id);
                    if (context.mounted)
                      showToast(context, '已删除 ${server.name}');
                  },
                ),
              ),
          const SizedBox(height: 12),
          BrandButton(
            label: '添加音乐服务器',
            icon: Icons.add_rounded,
            expanded: true,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServerLoginPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: registry.servers.any((e) => e.isDemo)
                ? '切换到演示资料库'
                : '先逛逛演示资料库',
            icon: Icons.headphones_rounded,
            onPressed: () async {
              await context.read<SourceRegistry>().addDemo();
              if (context.mounted) {
                showToast(context, '已进入演示资料库');
                Navigator.of(context).maybePop();
              }
            },
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接说明',
                  style: AppText.titleSm.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '· 地址填写服务器根地址，例如 http://192.168.1.8:4533\n'
                  '· 外网访问可填写域名，需要反向代理与 HTTPS\n'
                  '· 备用线路用于内网 / 外网自动切换\n'
                  '· Jellyfin / Emby 适配层已预留，后续可直接扩展',
                  style: AppText.caption.copyWith(
                    color: palette.textSecondary,
                    height: 1.9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.active,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ServerConfig server;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: active
                ? palette.brand.withValues(alpha: 0.42)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: active ? palette.brandSoft : palette.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                server.isDemo ? Icons.headphones_rounded : Icons.dns_rounded,
                size: 20,
                color: active ? palette.brand : palette.textSecondary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSm.copyWith(
                            color: palette.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.brandSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '当前',
                            style: AppText.overline.copyWith(
                              color: palette.brand,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    server.isDemo
                        ? '内置原创示例数据'
                        : '${server.username} · ${UrlUtils.hostOf(server.baseUrl)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: palette.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                  if (server.hasFallback) ...[
                    const SizedBox(height: 2),
                    Text(
                      '备用线路已配置',
                      style: AppText.caption.copyWith(
                        color: AppColors.mint,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 19,
                color: palette.textTertiary,
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                if (!server.isDemo)
                  const PopupMenuItem(value: 'edit', child: Text('编辑连接')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
