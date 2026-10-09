// Media stream types available for a YouTube video.
enum StreamCategory { muxed, audio, videoOnly }

/// A single downloadable media stream.
class StreamOption {
  const StreamOption({
    required this.videoId,
    required this.tag,
    required this.category,
    required this.label,
    required this.container,
    this.sizeBytes,
    required this.url,
    this.isFragmentBased = false,
  });

  /// YouTube video this stream belongs to.
  final String videoId;

  /// Unique stream id inside the manifest.
  final int tag;

  final StreamCategory category;

  /// Human-friendly label, e.g. `360p`, `1080p`, `128kbps`.
  final String label;

  /// Container name, e.g. `MP4`, `M4A`, `WEBM`.
  final String container;

  /// Stream size in bytes, when known.
  final int? sizeBytes;

  /// Direct download URL (empty for fragment-based / HLS streams).
  final String url;

  /// Whether this stream must be assembled from fragments (e.g. HLS).
  final bool isFragmentBased;

  /// Lowercased file extension used for the local file.
  String get extensionName => container.toLowerCase();
}

/// Metadata + download options for a YouTube video.
class VideoDownloadInfo {
  const VideoDownloadInfo({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
    required this.streams,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;
  final List<StreamOption> streams;

  List<StreamOption> get muxed =>
      streams.where((s) => s.category == StreamCategory.muxed).toList();

  List<StreamOption> get audio =>
      streams.where((s) => s.category == StreamCategory.audio).toList();

  List<StreamOption> get videoOnly =>
      streams.where((s) => s.category == StreamCategory.videoOnly).toList();
}

