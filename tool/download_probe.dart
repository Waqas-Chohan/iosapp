// Downloads audio/HD streams two ways: dio direct URL vs library streaming.
// ignore_for_file: avoid_print
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args[0] : 'JdqKBtc5bLo';
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streams.getManifest(
    id,
    ytClients: const [YoutubeApiClient.androidSdkless, YoutubeApiClient.safari],
    requireWatchPage: false,
  );

  final audio = manifest.audioOnly.sortByBitrate().first;
  final video = manifest.videoOnly.sortByBitrate().first;
  print('AUDIO: ${audio.qualityLabel} ${audio.container.name} '
      'n=${audio.url.queryParameters.containsKey('n')}');
  print('VIDEO: ${video.qualityLabel} ${video.container.name} '
      'n=${video.url.queryParameters.containsKey('n')}');

  for (final s in [audio, video]) {
    final label =
        s == audio ? 'AUDIO' : 'VIDEO-${s.qualityLabel}';
    // 1) dio direct URL with range
    try {
      final dio = Dio();
      final r = await dio.get<dynamic>(
        s.url.toString(),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-200000'},
        ),
      );
      print('DIO $label => HTTP ${r.statusCode}');
    } catch (e) {
      print('DIO $label => FAIL ${e.runtimeType}');
    }
    // 2) library streaming (range + manifest-refresh recovery)
    try {
      var ok = false;
      await for (final chunk in yt.videos.streams.get(s)) {
        print('LIB  $label => OK chunk=${chunk.length}');
        ok = true;
        break;
      }
      if (!ok) print('LIB  $label => no data');
    } catch (e) {
      print('LIB  $label => FAIL ${e.runtimeType}');
    }
  }
  yt.close();
}
