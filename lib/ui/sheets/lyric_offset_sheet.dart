import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/library_models.dart';
import '../../playback/playback_controller.dart';
import '../widgets/common.dart';

/// 歌词时间校准。
///
/// 只影响「当前歌曲」，或（在歌单页 / 队列来自歌单时）选择「整个歌单」，
/// 不再有全局生效的设置。
Future<void> showLyricOffsetSheet(
  BuildContext context, {
  String? playlistId,
  String? playlistName,
}) {
  final playback = context.read<PlaybackController>();
  final song = playback.current;
  final listId = playlistId ?? playback.queuePlaylistId;
  if (song == null && listId == null) {
    showToast(context, '请先播放一首歌，或在歌单页里校准');
    return Future<void>.value();
  }
  return showAppSheet<void>(
    context,
    (_) => _LyricOffsetBody(
      song: song,
      playlistId: listId,
      playlistName:
          playlistName ??
          (playlistId == null && listId != null ? playback.queueTitle : null),
    ),
  );
}

enum _Scope { song, playlist }

class _LyricOffsetBody extends StatefulWidget {
  const _LyricOffsetBody({
    required this.song,
    required this.playlistId,
    required this.playlistName,
  });

  final Song? song;
  final String? playlistId;
  final String? playlistName;

  @override
  State<_LyricOffsetBody> createState() => _LyricOffsetBodyState();
}

class _LyricOffsetBodyState extends State<_LyricOffsetBody> {
  static const int _limit = SettingsStore.lyricOffsetLimitMs;

  late final SettingsStore _settings = context.read<SettingsStore>();
  late _Scope _scope;
  late int _value;

  bool get _canPickSong => widget.song != null;
  bool get _canPickPlaylist => widget.playlistId != null;
  bool get _canSwitch => _canPickSong && _canPickPlaylist;

  @override
  void initState() {
    super.initState();
    _scope = _canPickSong ? _Scope.song : _Scope.playlist;
    _value = _valueFor(_scope);
  }

  int _valueFor(_Scope scope) {
    if (scope == _Scope.song) {
      final song = widget.song;
      if (song == null) return 0;
      return _settings.lyricOffsetForSong(song.id) ??
          _settings.lyricOffsetForPlaylist(widget.playlistId) ??
          0;
    }
    return _settings.lyricOffsetForPlaylist(widget.playlistId) ?? 0;
  }

  bool get _hasOwnSetting => switch (_scope) {
    _Scope.song => _settings.lyricOffsetForSong(widget.song?.id) != null,
    _Scope.playlist =>
      _settings.lyricOffsetForPlaylist(widget.playlistId) != null,
  };

  Future<void> _apply(int value) async {
    final clamped = value.clamp(-_limit, _limit);
    setState(() => _value = clamped);
    switch (_scope) {
      case _Scope.song:
        final song = widget.song;
        if (song != null) {
          await _settings.setSongLyricOffset(song.id, clamped);
        }
      case _Scope.playlist:
        final playlistId = widget.playlistId;
        if (playlistId != null) {
          await _settings.setPlaylistLyricOffset(playlistId, clamped);
        }
    }
  }

  Future<void> _clear() async {
    switch (_scope) {
      case _Scope.song:
        final song = widget.song;
        if (song != null) await _settings.clearSongLyricOffset(song.id);
      case _Scope.playlist:
        final playlistId = widget.playlistId;
        if (playlistId != null) {
          await _settings.clearPlaylistLyricOffset(playlistId);
        }
    }
    if (!mounted) return;
    setState(() => _value = _valueFor(_scope));
  }

  void _selectScope(_Scope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _value = _valueFor(scope);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final song = widget.song;
    final playlistName = widget.playlistName ?? widget.playlistId ?? '当前歌单';

    final String hint;
    if (_scope == _Scope.song) {
      hint =
          '只影响当前播放的《${song?.title ?? ''}》，'
          '换到别的歌曲不受影响。';
    } else {
      hint =
          '应用到「$playlistName」的全部曲目；'
          '之后仍可对单曲单独校准。';
    }

    final inherited = _scope == _Scope.song && !_hasOwnSetting
        ? _settings.lyricOffsetForPlaylist(widget.playlistId)
        : null;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text('歌词时间校准', style: AppText.h2.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 6),
        Text(
          '歌词比声音快就把数值调小，比声音慢则调大。',
          style: AppText.caption.copyWith(
            color: palette.textTertiary,
            height: 1.6,
          ),
        ),
        if (_canSwitch) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              _ScopeChip(
                label: '当前歌曲',
                selected: _scope == _Scope.song,
                onTap: () => _selectScope(_Scope.song),
              ),
              const SizedBox(width: 8),
              _ScopeChip(
                label: '整个歌单',
                selected: _scope == _Scope.playlist,
                onTap: () => _selectScope(_Scope.playlist),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text(
          Fmt.lyricOffset(_value),
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(
            color: palette.brand,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Slider(
          value: _value.toDouble(),
          min: -_limit.toDouble(),
          max: _limit.toDouble(),
          divisions: _limit ~/ 500 * 2,
          label: Fmt.lyricOffset(_value),
          activeColor: palette.brand,
          onChanged: (next) => setState(() => _value = next.round()),
          onChangeEnd: (next) => _apply(next.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '-2:00',
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
            Text(
              '0',
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
            Text(
              '+2:00',
              style: AppText.caption.copyWith(color: palette.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            GhostButton(label: '-5s', onPressed: () => _apply(_value - 5000)),
            GhostButton(label: '-0.5s', onPressed: () => _apply(_value - 500)),
            GhostButton(label: '归零', onPressed: () => _apply(0)),
            GhostButton(label: '+0.5s', onPressed: () => _apply(_value + 500)),
            GhostButton(label: '+5s', onPressed: () => _apply(_value + 5000)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          hint,
          style: AppText.caption.copyWith(
            color: palette.textTertiary,
            height: 1.6,
          ),
        ),
        if (inherited != null && inherited != 0) ...[
          const SizedBox(height: 6),
          Text(
            '本曲还没单独设置，当前跟随歌单的 ${Fmt.lyricOffset(inherited)}。',
            style: AppText.caption.copyWith(
              color: palette.textTertiary,
              height: 1.6,
            ),
          ),
        ],
        if (_hasOwnSetting) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _clear,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _scope == _Scope.song ? '清除本曲校准' : '清除歌单校准',
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        BrandButton(
          label: '完成',
          expanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.brandSoft : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? palette.brand : palette.divider),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: selected ? palette.brand : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
