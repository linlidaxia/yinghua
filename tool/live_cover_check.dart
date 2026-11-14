import 'dart:io';

import 'package:dio/dio.dart';
import 'package:yinghua/core/utils/artwork_url.dart';
import 'package:yinghua/core/utils/url_template.dart';

/// 手动验证：展开封面模板 → 跟随 302 → 检查图片 → 验证 720 尺寸可用。
///
/// 运行：dart run tool/live_cover_check.dart
Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  const template = 'https://api.lrc.cx/cover?album={album}&artist={artist}';
  const samples = [
    ('Super Star', 'S.H.E'),
    ('叶惠美', '周杰伦'),
    ('七里香', '周杰伦'),
    ('不存在的专辑', '不存在的歌手'),
  ];

  for (final (album, artist) in samples) {
    final url = UrlTemplate.expand(template, {
      'album': album,
      'artist': artist,
    });
    stdout.writeln('===== $album / $artist');
    if (url == null) {
      stdout.writeln('  模板展开失败');
      continue;
    }
    var target = url;
    Response<List<int>>? response;
    final trace = <String>[];
    for (var hop = 0; hop < 4; hop++) {
      final r = await dio.get<List<int>>(
        target,
        options: Options(responseType: ResponseType.bytes),
      );
      final status = r.statusCode ?? 0;
      final location = r.headers.value('location');
      trace.add('$status $target');
      if (status >= 300 && status < 400 && location != null) {
        target = ArtworkUrl.resolve(target, location);
        continue;
      }
      response = r;
      break;
    }
    for (final line in trace) {
      stdout.writeln('  $line');
    }
    stdout.writeln(
      '  -> ${response?.statusCode} ${response?.headers.value('content-type')} '
      '${response?.data?.length ?? 0} bytes',
    );

    final shrunk = ArtworkUrl.shrink(target);
    if (shrunk != target) {
      final r = await dio.get<List<int>>(
        shrunk,
        options: Options(responseType: ResponseType.bytes),
      );
      stdout.writeln(
        '  720: ${r.statusCode} ${r.headers.value('content-type')} '
        '${r.data?.length ?? 0} bytes',
      );
    }
  }
}
