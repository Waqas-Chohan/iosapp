// Live smoke test for the ManifestDatasource fix.
// ignore_for_file: avoid_print
//
// Usage: dart run tool/check_manifest.dart [videoId]
//
// Validates getManifest FIRST (the call that was failing), then videos.get.
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args[0] : 'JdqKBtc5bLo';
  final yt = YoutubeExplode();
  try {
    // The exact call that failed in the app: manifest by string id.
    final manifest = await yt.videos.streams.getManifest(
      id,
      requireWatchPage: false,
    );
    print('MUXED STREAMS: ${manifest.muxed.length}');
    for (final s in manifest.muxed) {
      print('  ${s.qualityLabel} · ${s.container.name} · '
          '${s.size.totalBytes} bytes');
    }

    final video = await yt.videos.get(id);
    print('TITLE : ${video.title}');
    print('AUTHOR: ${video.author}');
    print('OK: both manifest and video resolved.');
  } catch (e) {
    print('ERROR: $e');
    rethrow;
  } finally {
    yt.close();
  }
}
