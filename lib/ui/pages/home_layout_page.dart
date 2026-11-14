import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/local/settings_store.dart';

class HomeLayoutPage extends StatelessWidget {
  const HomeLayoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final palette = AppPalette.of(context);
    final sections = <HomeSection>[
      for (final id in settings.homeOrder)
        for (final section in kHomeSections)
          if (section.id == id) section,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页自定义'),
        actions: [
          TextButton(
            onPressed: settings.resetHomeSections,
            child: Text(
              '恢复默认',
              style: AppText.caption.copyWith(color: palette.brand),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          12,
          AppSpace.page,
          30,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '按住右侧拖动排序；关闭开关即可隐藏模块。至少保留一个模块。',
                    style: AppText.caption.copyWith(
                      color: palette.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: sections.length * 78.0,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: sections.length,
              onReorder: (oldIndex, newIndex) {
                settings.reorderHomeSections(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final section = sections[index];
                final visible = !settings.homeHidden.contains(section.id);
                return Container(
                  key: ValueKey(section.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 6),
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: visible
                            ? palette.brandSoft
                            : palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        _iconFor(section.id),
                        size: 18,
                        color: visible ? palette.brand : palette.textTertiary,
                      ),
                    ),
                    title: Text(
                      section.title,
                      style: AppText.titleSm.copyWith(
                        color: visible
                            ? palette.textPrimary
                            : palette.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      section.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: visible,
                          onChanged: (_) =>
                              settings.toggleHomeSection(section.id),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, right: 6),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String id) => switch (id) {
    'quick' => Icons.bolt_rounded,
    'recommend' => Icons.auto_awesome_rounded,
    'playlists' => Icons.queue_music_rounded,
    'newest' => Icons.new_releases_outlined,
    'recent' => Icons.history_rounded,
    _ => Icons.widgets_outlined,
  };
}
