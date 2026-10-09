import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/video_download_info.dart';

/// Wraps `youtube_explode_dart` — a pure Dart engine, no API key required.
class YoutubeDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<VideoDownloadInfo> fetch(String urlOrId) async {
    final video = await _yt.videos.get(urlOrId);
    // Set requireWatchPage: false for a faster, lighter request.
    // Muxed streams (audio+video in one file) are the free-stack ceiling.
    final manifest = await _yt.videos.streams.getManifest(
      video,
      requireWatchPage: false,
    );

    final options = manifest.muxed
        .map((s) => StreamOption(
              label: s.qualityLabel,
              container: s.container.name,
              sizeBytes: s.size.totalBytes > 0 ? s.size.totalBytes : null,
              url: s.url.toString(),
            ))
        .toList();

    return VideoDownloadInfo(
      videoId: video.id.value,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      duration: video.duration,
      streams: options,
    );
  }

  void close() => _yt.close();
}
