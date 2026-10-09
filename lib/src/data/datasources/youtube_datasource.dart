import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/video_download_info.dart';

/// Wraps `youtube_explode_dart` — a pure Dart engine, no API key required.
///
/// Strategy:
/// - Merges [YoutubeApiClient.androidSdkless] (reliable 360p muxed +
///   audio) with [YoutubeApiClient.safari] (high-quality HLS muxed,
///   720p/1080p) so every available quality is exposed.
/// - Fragment-based (HLS) streams are downloadable through
///   [streamFor] — the library concatenates fragments into one file.
/// - Caches fetched info per video id to avoid redundant requests
///   (rate-limit friendly).
class YoutubeDatasource {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, VideoDownloadInfo> _infoCache = {};
  final Map<String, StreamInfo> _streamInfos = {};

  Future<VideoDownloadInfo> fetch(String urlOrId) async {
    final video = await _yt.videos.get(urlOrId);
    final id = video.id.value;

    final cached = _infoCache[id];
    if (cached != null) return cached;

    final manifest = await _getManifest(id);
    _streamInfos.removeWhere((k, _) => k.startsWith('$id:'));

    final muxed = <StreamOption>[
      ...manifest.muxed.map(
          (s) => _toOption(s, id, StreamCategory.muxed)),
      ...manifest.hls.whereType<HlsMuxedStreamInfo>().map(
          (s) => _toOption(s, id, StreamCategory.muxed)),
    ];
    final audio = <StreamOption>[
      ...manifest.audioOnly.map(
          (s) => _toOption(s, id, StreamCategory.audio)),
      ...manifest.hls.whereType<HlsAudioStreamInfo>().map(
          (s) => _toOption(s, id, StreamCategory.audio)),
    ];
    final videoOnly = <StreamOption>[
      ...manifest.videoOnly.map(
          (s) => _toOption(s, id, StreamCategory.videoOnly)),
      ...manifest.hls.whereType<HlsVideoStreamInfo>().map(
          (s) => _toOption(s, id, StreamCategory.videoOnly)),
    ];

    final info = VideoDownloadInfo(
      videoId: id,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      duration: video.duration,
      streams: [
        ..._sortedTrim(muxed, 4),
        ..._sortedTrim(audio, 4),
        ..._sortedTrim(videoOnly, 4),
      ],
    );
    _infoCache[id] = info;
    return info;
  }

  /// Assembles a fragment-based (HLS) stream into a byte stream.
  Stream<List<int>> streamFor(String videoId, int tag) {
    final streamInfo = _streamInfos['$videoId:$tag'];
    if (streamInfo == null) {
      throw StateError(
        'Stream manifest is gone — please fetch the video again.',
      );
    }
    return _yt.videos.streams.get(streamInfo);
  }

  Future<StreamManifest> _getManifest(String id) async {
    try {
      // safari = high-quality muxed (HLS, m3u8) for 720p/1080p+audio.
      return await _yt.videos.streams.getManifest(
        id,
        ytClients: const [
          YoutubeApiClient.androidSdkless,
          YoutubeApiClient.safari,
        ],
        requireWatchPage: false,
      );
    } catch (_) {
      // Fallback: single reliable client.
      return await _yt.videos.streams.getManifest(
        id,
        requireWatchPage: false,
      );
    }
  }

  StreamOption _toOption(StreamInfo s, String videoId, StreamCategory c) {
    final fragments = s.fragments.isNotEmpty;
    _streamInfos['$videoId:${s.tag}'] = s;

    final String label;
    if (c == StreamCategory.audio) {
      final kb = s.bitrate.kiloBitsPerSecond;
      label = kb > 0 ? '${kb.round()}kbps' : 'Audio';
    } else {
      label = s.qualityLabel.isNotEmpty ? s.qualityLabel : c.name;
    }

    return StreamOption(
      videoId: videoId,
      tag: s.tag,
      category: c,
      label: label,
      container: s.container.name,
      sizeBytes: s.size.totalBytes > 0 ? s.size.totalBytes : null,
      url: fragments ? '' : s.url.toString(),
      isFragmentBased: fragments,
    );
  }

  List<StreamOption> _sortedTrim(Iterable<StreamOption> options, int max) {
    int rank(StreamOption o) {
      final m = RegExp(r'^(\d+)').firstMatch(o.label);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    return (options.toList()..sort((a, b) => rank(b).compareTo(rank(a))))
        .take(max)
        .toList();
  }

  void close() => _yt.close();
}

