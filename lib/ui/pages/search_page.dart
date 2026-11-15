import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/sorters.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/sources/source_registry.dart';
import '../../playback/playback_controller.dart';
import '../sheets/song_actions.dart';
import '../sheets/sort_sheet.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';
import '../widgets/media_cards.dart';
import '../widgets/song_tile.dart';
import 'album_page.dart';
import 'artist_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  SearchResult? _result;
  bool _loading = false;
  String? _error;
  String _query = '';
  SortOrder _sort = SortOrder.server;

  /// 搜索结果歌曲分页：首屏 100，自动补齐到 300，之后手动「加载更多」。
  static const int _songPageSize = 100;
  static const int _autoSongTarget = 300;

  int _requestId = 0;
  int _songOffset = 0;
  bool _hasMoreSongs = false;
  bool _loadingMore = false;

  static const _hotKeywords = <String>[
    '晚风',
    '南方',
    '城市',
    '雨',
    '海岸',
    '夏天',
    '深夜',
    '列车',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _query = '';
        _result = null;
        _loading = false;
        _loadingMore = false;
        _hasMoreSongs = false;
        _songOffset = 0;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 380), () {
      _search(query);
    });
  }

  /// 把新一页歌曲追加到结果里，按 id 去重（服务端排序不稳定时也安全）。
  static List<Song> _appendUnique(List<Song> existing, List<Song> incoming) {
    final ids = existing.map((song) => song.id).toSet();
    return incoming.where((song) => ids.add(song.id)).toList();
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    final request = ++_requestId;
    final repository = context.read<LibraryRepository>();
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
      _loadingMore = false;
      _hasMoreSongs = false;
      _songOffset = 0;
    });
    try {
      final first = await repository.search(query, songCount: _songPageSize);
      if (!mounted ||
          request != _requestId ||
          _controller.text.trim() != query) {
        return;
      }

      var songs = first.songs;
      var offset = songs.length;
      // 不假设服务端一定按请求的条数返回：只要本页非空就继续，直到取空或达到自动上限。
      var hasMore = songs.isNotEmpty;
      setState(() {
        _result = first;
        _loading = false;
        _songOffset = offset;
        _hasMoreSongs = hasMore;
      });

      // 自动补齐前几页，避免只搜出 40 首就和服务器对不上。
      while (hasMore &&
          songs.length < _autoSongTarget &&
          mounted &&
          request == _requestId) {
        final next = await repository.search(
          query,
          songOffset: offset,
          songCount: _songPageSize,
        );
        if (!mounted ||
            request != _requestId ||
            _controller.text.trim() != query) {
          return;
        }
        final fresh = _appendUnique(songs, next.songs);
        if (fresh.isEmpty) {
          hasMore = false;
          break;
        }
        songs = [...songs, ...fresh];
        offset += next.songs.length;
        hasMore = next.songs.length > 0 && fresh.isNotEmpty;
        setState(() {
          _result = SearchResult(
            songs: songs,
            albums: first.albums,
            artists: first.artists,
          );
          _songOffset = offset;
          _hasMoreSongs = hasMore;
        });
      }
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  /// 手动加载下一批歌曲。
  Future<void> _loadMoreSongs() async {
    final result = _result;
    if (result == null || _loadingMore || !_hasMoreSongs) return;
    final request = _requestId;
    final query = _query;
    final repository = context.read<LibraryRepository>();
    setState(() => _loadingMore = true);
    try {
      final next = await repository.search(
        query,
        songOffset: _songOffset,
        songCount: _songPageSize,
      );
      if (!mounted || request != _requestId) return;
      final current = _result;
      if (current == null) return;
      final fresh = _appendUnique(current.songs, next.songs);
      setState(() {
        _result = SearchResult(
          songs: [...current.songs, ...fresh],
          albums: current.albums,
          artists: current.artists,
        );
        _songOffset += next.songs.length;
        _hasMoreSongs = fresh.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() => _loadingMore = false);
    }
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    context.read<SettingsStore>().addRecentSearch(query);
    _focus.unfocus();
    _search(query);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final registry = context.watch<SourceRegistry>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                10,
                AppSpace.page,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: palette.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              textInputAction: TextInputAction.search,
                              onChanged: _onChanged,
                              onSubmitted: _submit,
                              style: AppText.body.copyWith(
                                color: palette.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: '搜索歌曲、专辑、歌手',
                                hintStyle: AppText.bodySm.copyWith(
                                  color: palette.textTertiary,
                                ),
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                              icon: const Icon(Icons.close_rounded, size: 17),
                              color: palette.textTertiary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _submit(_controller.text),
                    child: Text(
                      '搜索',
                      style: AppText.button.copyWith(color: palette.brand),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, registry, palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SourceRegistry registry,
    AppPalette palette,
  ) {
    if (!registry.hasSource) {
      return const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: '还没有连接音乐服务器',
        message: '连接后即可搜索自己的音乐库',
      );
    }
    if (_loading) {
      return const LoadingView(label: '正在搜索');
    }
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () => _search(_controller.text.trim()),
      );
    }
    final result = _result;
    if (result == null || _query.isEmpty) {
      return _DiscoverView(
        onKeyword: (keyword) {
          _controller.text = keyword;
          _submit(keyword);
        },
      );
    }
    if (result.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: '没有找到「$_query」',
        message: '换一个关键词，或检查服务器上的音乐标签',
      );
    }
    final playback = context.read<PlaybackController>();
    final artists = sortArtists(result.artists, _sort);
    final albums = sortAlbums(result.albums, _sort);
    final songs = sortSongs(result.songs, _sort);
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            6,
            AppSpace.page,
            2,
          ),
          child: Row(
            children: [
              Text(
                '搜索结果',
                style: AppText.caption.copyWith(color: palette.textTertiary),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () async {
                  final picked = await showSortSheet(context, current: _sort);
                  if (picked != null && mounted) {
                    setState(() => _sort = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _sort.isDefault
                        ? palette.surface
                        : palette.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 15,
                        color: _sort.isDefault
                            ? palette.textSecondary
                            : palette.brand,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sort.shortLabel,
                        style: AppText.caption.copyWith(
                          color: _sort.isDefault
                              ? palette.textSecondary
                              : palette.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (artists.isNotEmpty) ...[
          const SectionHeader(title: '歌手'),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistPage(
                        artistId: artist.id,
                        artistName: artist.name,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        CoverImage(
                          coverArtId: artist.coverArtId,
                          seed: artist.id,
                          size: 62,
                          circle: true,
                          artist: artist.name,
                          title: artist.name,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppText.caption.copyWith(
                            color: palette.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (albums.isNotEmpty) ...[
          SectionHeader(title: '专辑', subtitle: '${albums.length} 张'),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              itemCount: albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (context, index) {
                final album = albums[index];
                return AlbumCard(
                  album: album,
                  width: 138,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AlbumPage(albumId: album.id, albumName: album.name),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (songs.isNotEmpty) ...[
          SectionHeader(
            title: '单曲',
            subtitle: _hasMoreSongs
                ? '已显示 ${songs.length} 首'
                : '${songs.length} 首',
          ),
          for (var i = 0; i < songs.length; i++)
            SongTile(
              song: songs[i],
              showCover: true,
              dense: true,
              onTap: () => playback.playSongs(
                songs,
                startIndex: i,
                title: '搜索 · $_query',
              ),
              onMore: () => showSongOptionsSheet(context, songs[i]),
            ),
          if (_hasMoreSongs)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                12,
                AppSpace.page,
                4,
              ),
              child: _loadingMore
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在加载更多歌曲',
                          style: AppText.caption.copyWith(
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: GhostButton(
                        label: '加载更多歌曲',
                        onPressed: _loadMoreSongs,
                      ),
                    ),
            ),
        ],
      ],
    );
  }
}

class _DiscoverView extends StatelessWidget {
  const _DiscoverView({required this.onKeyword});

  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final settings = context.watch<SettingsStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 16, AppSpace.page, 30),
      children: [
        if (settings.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '最近搜索',
                style: AppText.h2.copyWith(color: palette.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: settings.clearRecentSearches,
                style: TextButton.styleFrom(
                  foregroundColor: palette.textTertiary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '清空',
                  style: AppText.caption.copyWith(color: palette.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final keyword in settings.recentSearches)
                _KeywordChip(
                  label: keyword,
                  icon: Icons.history_rounded,
                  onTap: () => onKeyword(keyword),
                ),
            ],
          ),
          const SizedBox(height: 26),
        ],
        Text('试试这些', style: AppText.h2.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final keyword in _SearchPageState._hotKeywords)
              _KeywordChip(label: keyword, onTap: () => onKeyword(keyword)),
          ],
        ),
        const SizedBox(height: 34),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 19,
                color: AppColors.mint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '搜索只发生在你自己的音乐服务器上，莺花不会上传关键词或播放记录。',
                  style: AppText.caption.copyWith(
                    color: palette.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: palette.textTertiary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppText.bodySm.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
