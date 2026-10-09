import 'package:dio/dio.dart';
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
  final Dio _dio = Dio();
  final Map<String, VideoDownloadInfo> _infoCache = {};
  final Map<String, StreamInfo> _streamInfos = {};

  Future<VideoDownloadInfo> fetch(String urlOrId) async {
    final parsed = VideoId.parseVideoId(urlOrId);
    final id = parsed ?? urlOrId.trim();

    final cached = _infoCache[id];
    if (cached != null) return cached;

    // Metadata path resilient to a blocked / bot-checked watch page.
    final video = await _tryGetVideo(id);
    final meta = video != null
        ? (
            video.title,
            video.author,
            video.thumbnails.highResUrl,
            video.duration,
          )
        : await _oembedMetadata(id);

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
      title: meta.$1,
      author: meta.$2,
      thumbnailUrl: meta.$3,
      duration: meta.$4,
      streams: [
        ..._sortedTrim(muxed, 4),
        ..._sortedTrim(audio, 4),
        ..._sortedTrim(videoOnly, 4),
      ],
    );
    _infoCache[id] = info;
    return info;
  }

  Future<Video?> _tryGetVideo(String id) async {
    try {
      return await _yt.videos.get(id);
    } catch (_) {
      // Watch page blocked/throttled — metadata via oEmbed fallback.
      return null;
    }
  }

  Future<(String, String, String, Duration?)> _oembedMetadata(String id) async {
    try {
      final url =
          'https://www.youtube.com/oembed?url='
          '${Uri.encodeQueryComponent('https://www.youtube.com/watch?v=$id')}'
          '&format=json';
      final res = await _dio.get<Map<String, dynamic>>(url);
      final data = res.data;
      return (
        (data?['title'] as String?) ?? id,
        (data?['author_name'] as String?) ?? 'Unknown',
        (data?['thumbnail_url'] as String?) ?? '',
        null,
      );
    } catch (_) {
      return (id, 'Unknown', '', null);
    }
  }

  /// Re-fetches the manifest and returns a fresh URL for [tag], updating the
  /// cached [StreamInfo] (used to recover from 403/expired download URLs).
  Future<String?> refreshStreamUrl(String videoId, int tag) async {
    try {
      final manifest = await _getManifest(videoId);
      for (final s in manifest.streams) {
        if (s.tag == tag) {
          _streamInfos['$videoId:$tag'] = s;
          return s.fragments.isEmpty ? s.url.toString() : null;
        }
      }
    } catch (_) {
      // Keep the previous URL — retry will use it as-is.
    }
    return null;
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
    // Preferred quality combo first; rotate on failure/rate-limit.
    final combos = <List<YoutubeApiClient>>[
      const [
        YoutubeApiClient.androidSdkless,
        YoutubeApiClient.safari,
      ],
      [YoutubeApiClient.ios],
      const [YoutubeApiClient.androidVr],
    ];

    Object? lastError;
    for (final combo in combos) {
      try {
        return await _yt.videos.streams.getManifest(
          id,
          ytClients: combo,
          requireWatchPage: false,
        );
      } catch (e) {
        lastError = e;
        if (e.toString().contains('RequestLimitExceeded')) {
          await Future<void>.delayed(const Duration(seconds: 4));
        }
      }
    }
    throw lastError ?? StateError('Unable to fetch streams for $id');
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

