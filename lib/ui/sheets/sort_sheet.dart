import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/sorters.dart';
import '../widgets/common.dart';

/// 排序方式选择弹层。返回用户选择的顺序，取消时返回 null。
Future<SortOrder?> showSortSheet(
  BuildContext context, {
  required SortOrder current,
  bool media = false,
}) {
  final options = media
      ? const [
          SortOrder.server,
          SortOrder.titleAsc,
          SortOrder.titleDesc,
          SortOrder.artistAsc,
          SortOrder.yearDesc,
        ]
      : const [
          SortOrder.server,
          SortOrder.titleAsc,
          SortOrder.titleDesc,
          SortOrder.artistAsc,
          SortOrder.albumAsc,
          SortOrder.durationAsc,
          SortOrder.durationDesc,
          SortOrder.yearDesc,
        ];

  return showAppSheet<SortOrder>(context, (sheetContext) {
    final palette = AppPalette.of(sheetContext);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '排序方式',
                  style: AppText.h2.copyWith(color: palette.textPrimary),
                ),
              ),
              Text(
                media ? '专辑 / 歌手' : '歌曲',
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
        for (final option in options)
          ListTile(
            title: Text(option.label),
            trailing: option == current
                ? Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: palette.brand,
                  )
                : null,
            onTap: () => Navigator.of(sheetContext).pop(option),
          ),
      ],
    );
  });
}
