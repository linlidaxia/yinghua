import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/sources/music_source.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/playback_controller.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';
import 'albums_page.dart';
import 'album_page.dart';
import 'downloads_page.dart';
import 'folder_page.dart';
import 'playlist_page.dart';
import 'recent_page.dart';
import 'server_login_page.dart';
import 'servers_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeFeed> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeFeed> _load() =>
      context.read<LibraryRepository>().homeFeed(refresh: true);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<SourceRegistry>();
    final settings = context.watch<SettingsStore>();
    final palette = AppPalette.of(context);

    if (!registry.hasSource) {
      return Scaffold(
        body: SafeArea(
          child: _NoServerView(
            onConnected: () => setState(() => _future = _load()),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: palette.brand,
          onRefresh: _refresh,
          child: FutureBuilder<HomeFeed>(
            future: _future,
            builder: (context, snapshot) {
              final feed = snapshot.data;
              final waiting =
                  snapshot.connectionState == ConnectionState.waiting &&
                  feed == null;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      greeting: Fmt.greeting(DateTime.now()),
                      onOpenSearch: widget.onOpenSearch,
                    ),
                  ),
                  if (waiting)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: LoadingView(label: '正在读取音乐库'),
                      ),
                    )
                  else if (feed == null || feed.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: '音乐库暂时没有内容',
                          message: '请确认服务器上有歌曲，或检查网络连接后重试',
                          actionLabel: '重新加载',
                          onAction: _refresh,
                        ),
                      ),
                    )
                  else
                    for (final sectionId in settings.visibleHomeSections)
                      SliverToBoxAdapter(
                        child: _buildSection(
                          context,
                          sectionId,
                          feed,
                          settings,
                        ),
                      ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(32, 20, 32, 30),
                      child: Text(
                        '音乐内容来自你自建的服务器\n莺花不提供任何音频内容',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String id,
    HomeFeed feed,
    SettingsStore settings,
  ) {
    switch (id) {
      case 'quick':
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: AppSpace.section),
          child: _QuickActions(
            feed: feed,
            onRandom: () => _playRandom(context),
            onRecent: () => _openRecent(context, settings),
            onFolder: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const FolderPage())),
            onDownloads: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
            ),
          ),
        );
      case 'recommend':
        if (feed.recommended.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '为你推荐',
                subtitle: '根据播放记录挑选的专辑',
                actionLabel: '全部',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlbumsPage(
                      type: AlbumListType.frequent,
                      title: '为你推荐',
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.page,
                  ),
                  itemCount: feed.recommended.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 13),
                  itemBuilder: (context, index) {
                    final album = feed.recommended[index];
                    return AlbumCard(
                      album: album,
                      width: 148,
                      onTap: () => _openAlbum(context, album),
                      onPlay: () => _playAlbum(context, album),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      case 'playlists':
        if (feed.playlists.isEmpty) return const SizedBox.shrink();
        final playlists = feed.playlists.take(4).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '精选歌单', subtitle: '来自服务器策展'),
              _GridSection(
                itemCount: playlists.length,
                builder: (context, index) {
                  final playlist = playlists[index];
                  return PlaylistCard(
                    playlist: playlist,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _PlaylistLauncher(
                          playlistId: playlist.id,
                          playlistName: playlist.name,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      case 'newest':
        if (feed.newest.isEmpty) return const SizedBox.shrink();
        final albums = feed.newest.take(6).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '最近添加',
                actionLabel: '全部',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlbumsPage(
                      type: AlbumListType.newest,
                      title: '最近添加',
                    ),
                  ),
                ),
              ),
              _GridSection(
                itemCount: albums.length,
                builder: (context, index) {
                  final album = albums[index];
                  return AlbumCard(
                    album: album,
                    onTap: () => _openAlbum(context, album),
                    onPlay: () => _playAlbum(context, album),
                  );
                },
              ),
            ],
          ),
        );
      case 'recent':
        final recent = settings.recentSongs.take(5).toList();
        if (recent.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '最近播放',
                actionLabel: '全部',
                onAction: () => _openRecent(context, settings),
              ),
              for (var i = 0; i < recent.length; i++)
                SongTile(
                  song: recent[i],
                  showCover: true,
                  onTap: () {
                    context.read<PlaybackController>().playSongs(
                      recent,
                      startIndex: i,
                      title: '最近播放',
                    );
                  },
                ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openAlbum(BuildContext context, Album album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _AlbumLauncher(albumId: album.id, albumName: album.name),
      ),
    );
  }

  Future<void> _playAlbum(BuildContext context, Album album) async {
    final repo = context.read<LibraryRepository>();
    final playback = context.read<PlaybackController>();
    try {
      final detail = await repo.album(album.id);
      if (!context.mounted) return;
      if (detail.songs.isEmpty) {
        showToast(context, '这张专辑没有可播放的歌曲');
        return;
      }
      playback.playSongs(detail.songs, title: album.name);
      if (context.mounted) showToast(context, '开始播放 · ${album.name}');
    } catch (error) {
      if (context.mounted) showToast(context, '$error');
    }
  }

  Future<void> _playRandom(BuildContext context) async {
    final repo = context.read<LibraryRepository>();
    final playback = context.read<PlaybackController>();
    try {
      final songs = await repo.randomSongs(size: 30);
      if (!context.mounted) return;
      if (songs.isEmpty) {
        showToast(context, '音乐库里还没有歌曲');
        return;
      }
      playback.playSongs(songs, title: '随机漫游');
      showToast(context, '随机播放 ${songs.length} 首', icon: Icons.shuffle_rounded);
    } catch (error) {
      if (context.mounted) showToast(context, '$error');
    }
  }

  void _openRecent(BuildContext context, SettingsStore settings) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RecentSongsPage()));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.onOpenSearch});

  final String greeting;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final registry = context.watch<SourceRegistry>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 6, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 30),
              const SizedBox(width: 9),
              Text(
                '莺花',
                style: AppText.h1.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search_rounded, size: 23),
                color: palette.textPrimary,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ServersPage()),
                ),
                icon: const Icon(Icons.dns_outlined, size: 21),
                color: palette.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              greeting,
              style: AppText.display.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ServersPage()),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 7, 9, 7),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    registry.isDemo ? '演示资料库' : registry.displayName,
                    style: AppText.caption.copyWith(
                      color: palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: palette.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.feed,
    required this.onRandom,
    required this.onRecent,
    required this.onFolder,
    required this.onDownloads,
  });

  final HomeFeed feed;
  final VoidCallback onRandom;
  final VoidCallback onRecent;
  final VoidCallback onFolder;
  final VoidCallback onDownloads;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 22, AppSpace.page, 0),
      child: Row(
        children: [
          _QuickItem(
            icon: Icons.shuffle_rounded,
            label: '随机漫游',
            onTap: onRandom,
          ),
          _QuickItem(
            icon: Icons.history_rounded,
            label: '最近播放',
            onTap: onRecent,
          ),
          _QuickItem(
            icon: Icons.folder_open_rounded,
            label: '文件夹',
            onTap: onFolder,
          ),
          _QuickItem(
            icon: Icons.download_done_rounded,
            label: '本地下载',
            onTap: onDownloads,
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: palette.brand),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: palette.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSection extends StatelessWidget {
  const _GridSection({required this.itemCount, required this.builder});

  final int itemCount;
  final IndexedWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemBuilder: builder,
    );
  }
}

class _NoServerView extends StatelessWidget {
  const _NoServerView({required this.onConnected});

  final VoidCallback onConnected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandMark(size: 58),
          const SizedBox(height: 22),
          Text(
            '把你的音乐带在身边',
            style: AppText.display.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            '连接你的 Navidrome 或其他 Subsonic 服务器，\n歌曲、专辑、歌单与歌词都会出现在这里。',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(
              color: palette.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 28),
          BrandButton(
            label: '连接音乐服务器',
            icon: Icons.link_rounded,
            expanded: true,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServerLoginPage(),
                ),
              );
              onConnected();
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await context.read<SourceRegistry>().addDemo();
              onConnected();
            },
            style: TextButton.styleFrom(
              foregroundColor: palette.textSecondary,
              textStyle: AppText.bodySm,
            ),
            child: const Text('先逛逛演示资料库'),
          ),
        ],
      ),
    );
  }
}

// 延迟导入，避免首页文件承载过多详情页逻辑。
class _AlbumLauncher extends StatelessWidget {
  const _AlbumLauncher({required this.albumId, this.albumName});
  final String albumId;
  final String? albumName;

  @override
  Widget build(BuildContext context) =>
      AlbumPage(albumId: albumId, albumName: albumName);
}

class _PlaylistLauncher extends StatelessWidget {
  const _PlaylistLauncher({required this.playlistId, this.playlistName});
  final String playlistId;
  final String? playlistName;

  @override
  Widget build(BuildContext context) =>
      PlaylistPage(playlistId: playlistId, playlistName: playlistName);
}
