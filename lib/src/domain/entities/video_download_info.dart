// Media stream types available for a YouTube video.
enum StreamCategory { muxed, audio, videoOnly }

/// A single downloadable option shown in the quality picker.
///
/// Most options map 1:1 to a YouTube stream. High resolutions (720p+)
/// are *adaptive*: a video-only MP4 plus a separate M4A audio stream that
/// are downloaded side by side and merged on device ([needsMerge]).
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
    this.audioTag,
    this.audioUrl = '',
    this.audioSizeBytes,
    this.fps,
    this.height,
    this.codec = '',
  });

  /// YouTube video this stream belongs to.
  final String videoId;

  /// Unique stream id inside the manifest (the video stream for merges).
  final int tag;

  /// Category of the *result*: merged options are [StreamCategory.muxed].
  final StreamCategory category;

  /// Human-friendly label, e.g. `360p`, `1080p`, `128kbps`.
  final String label;

  /// Container name, e.g. `MP4`, `M4A`.
  final String container;

  /// Size of the (video) stream in bytes, when known.
  final int? sizeBytes;

  /// Direct download URL (empty for fragment-based / HLS streams).
  final String url;

  /// Whether this stream must be assembled from fragments (e.g. HLS).
  final bool isFragmentBased;

  /// Audio stream merged into a video-only stream (adaptive formats).
  final int? audioTag;
  final String audioUrl;
  final int? audioSizeBytes;

  /// Video details (null for audio).
  final int? fps;
  final int? height;
  final String codec;

  bool get needsMerge => audioTag != null;

  bool get isVideo => category != StreamCategory.audio;

  /// Total bytes to transfer (video + audio for merged formats).
  int? get totalBytes {
    if (sizeBytes == null) return null;
    if (!needsMerge) return sizeBytes;
    return sizeBytes! + (audioSizeBytes ?? 0);
  }

  /// Lowercased file extension used for the local file.
  String get extensionName {
    final c = container.toLowerCase();
    if (category == StreamCategory.audio) return c == 'mp4' ? 'm4a' : c;
    return c.isEmpty ? 'mp4' : c;
  }

  /// Badge shown next to video resolutions.
  String get qualityBadge {
    final h = height ?? 0;
    if (h >= 2160) return '4K';
    if (h >= 1440) return 'QHD';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return '';
  }

  StreamOption copyWith({String? url, String? audioUrl}) => StreamOption(
        videoId: videoId,
        tag: tag,
        category: category,
        label: label,
        container: container,
        sizeBytes: sizeBytes,
        url: url ?? this.url,
        isFragmentBased: isFragmentBased,
        audioTag: audioTag,
        audioUrl: audioUrl ?? this.audioUrl,
        audioSizeBytes: audioSizeBytes,
        fps: fps,
        height: height,
        codec: codec,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'tag': tag,
        'category': category.name,
        'label': label,
        'container': container,
        'sizeBytes': sizeBytes,
        'url': url,
        'isFragmentBased': isFragmentBased,
        'audioTag': audioTag,
        'audioUrl': audioUrl,
        'audioSizeBytes': audioSizeBytes,
        'fps': fps,
        'height': height,
        'codec': codec,
      };

  factory StreamOption.fromJson(Map<String, dynamic> json) => StreamOption(
        videoId: json['videoId'] as String? ?? '',
        tag: json['tag'] as int? ?? 0,
        category: StreamCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => StreamCategory.muxed,
        ),
        label: json['label'] as String? ?? '',
        container: json['container'] as String? ?? 'mp4',
        sizeBytes: json['sizeBytes'] as int?,
        url: json['url'] as String? ?? '',
        isFragmentBased: json['isFragmentBased'] as bool? ?? false,
        audioTag: json['audioTag'] as int?,
        audioUrl: json['audioUrl'] as String? ?? '',
        audioSizeBytes: json['audioSizeBytes'] as int?,
        fps: json['fps'] as int?,
        height: json['height'] as int?,
        codec: json['codec'] as String? ?? '',
      );
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

  /// Every option that produces a playable video (direct + merged).
  List<StreamOption> get video => streams.where((s) => s.isVideo).toList();

  List<StreamOption> get muxed =>
      streams.where((s) => s.category == StreamCategory.muxed).toList();

  List<StreamOption> get audio =>
      streams.where((s) => s.category == StreamCategory.audio).toList();
}
