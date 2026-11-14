import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/sources/music_source.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

class FolderPage extends StatefulWidget {
  const FolderPage({super.key, this.folderId, this.title});

  final String? folderId;
  final String? title;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late Future<Object> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Object> _load() {
    final repo = context.read<LibraryRepository>();
    final future = widget.folderId == null
        ? repo.musicFolders(refresh: true)
        : repo.directory(widget.folderId!, refresh: true);
    // 服务端目录接口有时会长时间无响应，超时后给出可操作的提示，
    // 避免一直停在加载态。
    return future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw MusicSourceException(
        '目录加载超时：服务器响应过慢，或该服务端未开启目录浏览。'
        '可以改用「按歌手浏览」。',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final registry = context.watch<SourceRegistry>();
    return Scaffold(
      bottomNavigationBar: const MiniPlayerBar(),
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.title ?? '文件夹'),
            Text(
              registry.displayName,
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: FutureBuilder<Object>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Expanded(
                  child: ErrorView(
                    message: '${snapshot.error}',
                    onRetry: () => setState(() => _future = _load()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: GhostButton(
                    label: '按歌手浏览',
                    icon: Icons.person_outline_rounded,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const FolderPage(
                          folderId: MusicSource.indexesFolderId,
                          title: '按歌手浏览',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          if (widget.folderId == null) {
            final folders = snapshot.data as List<MusicFolder>? ?? const [];
            return _FolderList(
              folders: folders,
              onOpen: (folder) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      FolderPage(folderId: folder.id, title: folder.name),
                ),
              ),
            );
          }
          final content = snapshot.data as DirectoryContent?;
          return _DirectoryView(
            content: content ?? DirectoryContent(id: widget.folderId!),
            title: widget.title ?? '文件夹',
          );
        },
      ),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.folders, required this.onOpen});

  final List<MusicFolder> folders;
  final ValueChanged<MusicFolder> onOpen;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_rounded,
        title: '没有可浏览的文件夹',
        message: '服务器可能未开启文件目录浏览',
      );
    }
    final palette = AppPalette.of(context);
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: folders.length,
      separatorBuilder: (_, __) =>
          Divider(indent: AppSpace.page, endIndent: AppSpace.page),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.folder_rounded, color: palette.brand),
          ),
          title: Text(
            folder.name,
            style: AppText.title.copyWith(color: palette.textPrimary),
          ),
          subtitle: Text(
            '按服务器目录结构浏览',
            style: AppText.caption.copyWith(color: palette.textTertiary),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: palette.textTertiary,
          ),
          onTap: () => onOpen(folder),
        );
      },
    );
  }
}

class _DirectoryView extends StatelessWidget {
  const _DirectoryView({required this.content, required this.title});

  final DirectoryContent content;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playback = context.read<PlaybackController>();
    final registry = context.read<SourceRegistry>();

    final directories = content.items.where((e) => e.isDirectory).toList();
    final files = content.items.where((e) => !e.isDirectory).toList();

    if (content.items.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_rounded,
        title: '空文件夹',
        message: '这里面还没有音乐文件',
      );
    }

    final songs = files
        .map(
          (item) => Song(
            id: item.id,
            title: item.title,
            artist: item.artist,
            album: item.album ?? title,
            coverArtId: item.coverArtId,
            duration: item.duration,
            track: item.track,
            suffix: item.suffix,
            size: item.size,
            serverId: registry.activeId,
          ),
        )
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: directories.length + files.length,
      itemBuilder: (context, index) {
        if (index < directories.length) {
          final dir = directories[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FolderPage(folderId: dir.id, title: dir.title),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.page,
                vertical: 9,
              ),
              child: Row(
                children: [
                  dir.coverArtId != null
                      ? CoverImage(
                          coverArtId: dir.coverArtId,
                          songId: dir.id,
                          size: 46,
                          radius: 10,
                          album: dir.title,
                          artist: dir.artist,
                          title: dir.title,
                        )
                      : Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.folder_rounded,
                            color: palette.brand,
                            size: 22,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dir.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSm.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '文件夹',
                          style: AppText.caption.copyWith(
                            color: palette.textTertiary,
                          ),
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
            ),
          );
        }
        final fileIndex = index - directories.length;
        final song = songs[fileIndex];
        return SongTile(
          song: song,
          index: fileIndex,
          onTap: () =>
              playback.playSongs(songs, startIndex: fileIndex, title: title),
          subtitle: '${song.displayArtist} · ${Fmt.duration(song.duration)}',
        );
      },
    );
  }
}
