// A single, directly downloadable media stream (muxed audio + video).
class StreamOption {
  const StreamOption({
    required this.label,
    required this.container,
    this.sizeBytes,
    required this.url,
  });

  /// Human-friendly quality label, e.g. `360p`.
  final String label;

  /// Container name, e.g. `MP4`.
  final String container;

  /// Stream size in bytes, when known.
  final int? sizeBytes;

  /// Direct download URL.
  final String url;

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
}
