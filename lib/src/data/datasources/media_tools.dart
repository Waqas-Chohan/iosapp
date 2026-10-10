import 'package:flutter/services.dart';

/// Result of [MediaTools.probe].
class MediaProbe {
  const MediaProbe({
    this.duration,
    this.width,
    this.height,
    this.thumbnailPath,
    this.title,
    this.artist,
    this.hasVideo = false,
  });

  final Duration? duration;
  final int? width;
  final int? height;
  final String? thumbnailPath;
  final String? title;
  final String? artist;
  final bool hasVideo;
}

/// Native AVFoundation / PhotosUI helpers (see `ios/Runner/AppDelegate.swift`).
class MediaTools {
  const MediaTools();

  static const MethodChannel _channel = MethodChannel('musically/media');

  /// Merges a video-only MP4 and an M4A audio file into one MP4 without
  /// re-encoding (fast, lossless).
  Future<void> merge({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<String>('merge', {
      'video': videoPath,
      'audio': audioPath,
      'output': outputPath,
    });
  }

  /// Duration, size, embedded title/artist and a JPEG thumbnail written to
  /// [thumbnailPath] (video frame or embedded cover art).
  Future<MediaProbe> probe(String path, String thumbnailPath) async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('probe', {
        'path': path,
        'thumbnail': thumbnailPath,
      });
      if (r == null) return const MediaProbe();
      final ms = (r['durationMs'] as num?)?.toInt() ?? 0;
      return MediaProbe(
        duration: ms > 0 ? Duration(milliseconds: ms) : null,
        width: (r['width'] as num?)?.toInt(),
        height: (r['height'] as num?)?.toInt(),
        thumbnailPath: r['thumbnail'] as String?,
        title: r['title'] as String?,
        artist: r['artist'] as String?,
        hasVideo: r['hasVideo'] as bool? ?? false,
      );
    } catch (_) {
      return const MediaProbe();
    }
  }

  /// Opens the Photos picker (videos, multi-select). Returns local copies.
  Future<List<String>> pickVideosFromPhotos() => _pick('pickPhotos');

  /// Opens the Files picker (video + audio, multi-select). Returns copies.
  Future<List<String>> pickFromFiles() => _pick('pickFiles');

  Future<List<String>> _pick(String method) async {
    final r = await _channel.invokeListMethod<String>(method);
    return r ?? const [];
  }
}
