import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/video_download_info.dart';

/// Wraps `youtube_explode_dart` — a pure Dart engine, no API key required.
///
/// Only formats that iOS can play and save to Photos are exposed:
/// - **Muxed MP4** (usually 360p) — downloaded as-is.
/// - **Adaptive H.264 MP4 + M4A audio** (480p … 1080p) — downloaded in
///   parallel and merged on device (AVFoundation, no re-encode).
/// - **M4A (AAC) audio** — WebM/Opus is skipped (not playable on iOS).
/// HLS (MPEG-TS) streams are ignored: they cannot be stored as MP4.
class YoutubeDatasource {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();
  final Map<String, VideoDownloadInfo> _infoCache = {};
  final Map<String, DateTime> _infoFetchedAt = {};
  final Map<String, bool> _probeCache = {};

  /// Fetched URLs expire after ~6 hours, cached info after 1 hour.
  static const _infoTtl = Duration(hours: 1);

  Future<VideoDownloadInfo> fetch(String urlOrId, {bool force = false}) async {
    final parsed = VideoId.parseVideoId(urlOrId);
    final id = parsed ?? urlOrId.trim();

    final cached = _infoCache[id];
    final fetchedAt = _infoFetchedAt[id];
    if (!force &&
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _infoTtl) {
      return cached;
    }

    // Metadata path resilient to a blocked / bot-checked watch page.
    final video = await _tryGetVideo(id);
    final meta = video != null
        ? (
            video.title,
            video.author,
            // 1280x720 artwork — sharp banners regardless of stream quality.
            video.thumbnails.maxResUrl,
            video.duration,
          )
        : await _oembedMetadata(id);

    final manifest = await _getManifest(id);
    final options = await _buildOptions(id, manifest);

    final info = VideoDownloadInfo(
      videoId: id,
      title: meta.$1,
      author: meta.$2,
      thumbnailUrl: meta.$3,
      duration: meta.$4,
      streams: options,
    );
    _infoCache[id] = info;
    _infoFetchedAt[id] = DateTime.now();
    return info;
  }

  Future<List<StreamOption>> _buildOptions(
    String id,
    StreamManifest manifest,
  ) async {
    // --- Audio: AAC in MP4 only, default language track, best first.
    final aac = manifest.audioOnly
        .where((s) =>
            s.fragments.isEmpty &&
            s.container == StreamContainer.mp4 &&
            (s.audioTrack == null || s.audioTrack!.audioIsDefault))
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    final bestAudio = aac.isEmpty ? null : aac.first;

    final audio = <String, StreamOption>{};
    for (final s in aac) {
      final kb = s.bitrate.kiloBitsPerSecond.round();
      final label = kb > 0 ? '${kb}kbps' : 'Audio';
      audio.putIfAbsent(
        label,
        () => StreamOption(
          videoId: id,
          tag: s.tag,
          category: StreamCategory.audio,
          label: label,
          container: 'm4a',
          sizeBytes: _size(s),
          url: s.url.toString(),
          codec: s.audioCodec,
        ),
      );
    }

    // --- Video: muxed MP4 first, then adaptive H.264 for higher resolutions.
    final video = <int, StreamOption>{}; // keyed by height
    for (final s in manifest.muxed) {
      if (s.fragments.isNotEmpty || s.container != StreamContainer.mp4) {
        continue;
      }
      final h = _height(s.qualityLabel, s.videoResolution);
      video.putIfAbsent(
        h,
        () => StreamOption(
          videoId: id,
          tag: s.tag,
          category: StreamCategory.muxed,
          label: _label(s.qualityLabel, h),
          container: 'mp4',
          sizeBytes: _size(s),
          url: s.url.toString(),
          fps: s.framerate.framesPerSecond.round(),
          height: h,
          codec: s.videoCodec,
        ),
      );
    }

    if (bestAudio != null) {
      final adaptive = manifest.videoOnly
          .where((s) =>
              s.fragments.isEmpty &&
              s.container == StreamContainer.mp4 &&
              s.videoCodec.toLowerCase().startsWith('avc1'))
          .toList()
        // Prefer higher fps, then higher bitrate for the same resolution.
        ..sort((a, b) {
          final fps = b.framerate.framesPerSecond
              .compareTo(a.framerate.framesPerSecond);
          return fps != 0 ? fps : b.bitrate.compareTo(a.bitrate);
        });
      for (final s in adaptive) {
        final h = _height(s.qualityLabel, s.videoResolution);
        if (h < 240) continue;
        video.putIfAbsent(
          h,
          () => StreamOption(
            videoId: id,
            tag: s.tag,
            category: StreamCategory.muxed,
            label: _label(s.qualityLabel, h),
            container: 'mp4',
            sizeBytes: _size(s),
            url: s.url.toString(),
            audioTag: bestAudio.tag,
            audioUrl: bestAudio.url.toString(),
            audioSizeBytes: _size(bestAudio),
            fps: s.framerate.framesPerSecond.round(),
            height: h,
            codec: s.videoCodec,
          ),
        );
      }
    }

    final videoList = video.values.toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    final audioList = audio.values.toList()
      ..sort((a, b) => _num(b.label).compareTo(_num(a.label)));

    final verified = await _verifyStreams([...videoList, ...audioList]);
    return verified;
  }

  /// Probes each candidate with a tiny range request and keeps only the
  /// streams that respond. If every probe fails (probes blocked) all
  /// candidates are kept and the downloader's own retries take over.
  Future<List<StreamOption>> _verifyStreams(List<StreamOption> options) async {
    final results = await Future.wait(options.map((o) async {
      final key = '${o.videoId}:${o.tag}';
      final ok = _probeCache[key] ?? await _probe(o.url);
      _probeCache[key] = ok;
      return (option: o, ok: ok);
    }));
    final kept = results.where((r) => r.ok).map((r) => r.option).toList();
    return kept.isEmpty ? options : kept;
  }

  Future<bool> _probe(String url) async {
    if (url.isEmpty) return false;
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Range': 'bytes=0-511'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 400;
    } catch (_) {
      return false;
    }
  }

  /// Fresh direct URL for [tag] (download URLs expire after a few hours).
  Future<String?> refreshStreamUrl(String videoId, int tag) async {
    try {
      final manifest = await _getManifest(videoId);
      for (final s in manifest.streams) {
        if (s.tag == tag && s.fragments.isEmpty) return s.url.toString();
      }
    } catch (_) {
      // Caller keeps the previous URL.
    }
    return null;
  }

  Future<Video?> _tryGetVideo(String id) async {
    try {
      return await _yt.videos.get(id);
    } catch (_) {
      return null; // Watch page blocked/throttled — use oEmbed.
    }
  }

  Future<(String, String, String, Duration?)> _oembedMetadata(String id) async {
    try {
      final url = 'https://www.youtube.com/oembed?url='
          '${Uri.encodeQueryComponent('https://www.youtube.com/watch?v=$id')}'
          '&format=json';
      final res = await _dio.get<Map<String, dynamic>>(url);
      final data = res.data;
      // oEmbed serves a 480x360 thumb; ask for the HD variant instead.
      final thumb = ((data?['thumbnail_url'] as String?) ?? '')
          .replaceAll('hqdefault.jpg', 'maxresdefault.jpg');
      return (
        (data?['title'] as String?) ?? id,
        (data?['author_name'] as String?) ?? 'Unknown',
        thumb,
        null,
      );
    } catch (_) {
      return (id, 'Unknown', '', null);
    }
  }

  Future<StreamManifest> _getManifest(String id) async {
    // Each combo merges the clients' formats; rotate on failure.
    final combos = <List<YoutubeApiClient>>[
      const [YoutubeApiClient.androidSdkless, YoutubeApiClient.androidVr],
      [YoutubeApiClient.ios],
      const [YoutubeApiClient.tv],
    ];

    Object? lastError;
    for (final combo in combos) {
      try {
        final manifest = await _yt.videos.streams.getManifest(
          id,
          ytClients: combo,
          requireWatchPage: false,
        );
        if (manifest.muxed.isNotEmpty ||
            manifest.videoOnly.isNotEmpty ||
            manifest.audioOnly.isNotEmpty) {
          return manifest;
        }
      } catch (e) {
        lastError = e;
        if (e.toString().contains('RequestLimitExceeded')) {
          await Future<void>.delayed(const Duration(seconds: 4));
        }
      }
    }
    throw lastError ?? StateError('Unable to fetch streams for $id');
  }

  static int? _size(StreamInfo s) =>
      s.size.totalBytes > 0 ? s.size.totalBytes : null;

  static int _height(String qualityLabel, VideoResolution res) {
    final m = RegExp(r'(\d{3,4})p').firstMatch(qualityLabel);
    if (m != null) return int.parse(m.group(1)!);
    return math.min(res.width, res.height);
  }

  static String _label(String qualityLabel, int height) {
    final m = RegExp(r'(\d{3,4}p\d*)').firstMatch(qualityLabel);
    return m?.group(1) ?? '${height}p';
  }

  static int _num(String label) =>
      int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '') ?? 0;

  void close() => _yt.close();
}
