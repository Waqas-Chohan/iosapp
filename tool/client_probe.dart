// Live test: which YouTube clients survive the current IP rate-limit?
// ignore_for_file: avoid_print
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args[0] : 'JdqKBtc5bLo';
  final yt = YoutubeExplode();
  final combos = <String, List<YoutubeApiClient>>{
    'androidSdkless+safari': [YoutubeApiClient.androidSdkless, YoutubeApiClient.safari],
    'ios': [YoutubeApiClient.ios],
    'androidVr': [YoutubeApiClient.androidVr],
    'tv': [YoutubeApiClient.tv],
  };
  for (final combo in combos.entries) {
    try {
      final m = await yt.videos.streams.getManifest(
        id,
        ytClients: combo.value,
        requireWatchPage: false,
      );
      final muxed = m.muxed.map((s) => '${s.qualityLabel}/${s.container.name}');
      final hls = m.hls.map((s) => 'HLS:${s.qualityLabel}');
      print('CLIENT ${combo.key} => OK  muxed=[${muxed.join(',')}] hls=[${hls.join(',')}] audio=${m.audioOnly.length} videoOnly=${m.videoOnly.length}');
    } catch (e) {
      print('CLIENT ${combo.key} => FAIL ${e.runtimeType}');
    }
  }
  yt.close();
}
