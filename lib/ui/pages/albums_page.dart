import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/sources/music_source.dart';
import '../widgets/common.dart';
import '../widgets/media_cards.dart';
import 'album_page.dart';

/// 「查看全部」专辑列表，按来源类型加载。
class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key, required this.type, required this.title});

  final AlbumListType type;
  final String title;

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  late Future<List<Album>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Album>> _load() {
    return context.read<LibraryRepository>().albums(
      widget.type,
      size: 80,
      refresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Album>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final albums = snapshot.data ?? const [];
          if (albums.isEmpty) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: '这里还没有专辑',
              message: '换一个分类，或先在服务器上添加音乐',
            );
          }
          return RefreshIndicator(
            color: palette.brandSoft,
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                8,
                AppSpace.page,
                24,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return AlbumCard(
                  album: album,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AlbumPage(albumId: album.id, albumName: album.name),
                    ),
                  ),
                  onPlay: () => _playAlbum(context, album.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _playAlbum(BuildContext context, String albumId) async {
    // 由专辑详情页负责播放，避免列表页重复实现队列构建。
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlbumPage(albumId: albumId)),
    );
  }
}
