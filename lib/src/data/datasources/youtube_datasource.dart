import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/video_download_info.dart';

/// Wraps `youtube_explode_dart` — a pure Dart engine, no API key required.
class YoutubeDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<VideoDownloadInfo> fetch(String urlOrId) async {
    final video = await _yt.videos.get(urlOrId);
    // Set requireWatchPage: false for a faster, lighter request.
    // `VideoId.fromString` in v3.1.0 only accepts String|VideoId, so
    // pass the id string — NOT the Video object — or it will throw
    // "Invalid YouTube video ID or URL".
    final manifest = await _yt.videos.streams.getManifest(
      video.id.value,
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
