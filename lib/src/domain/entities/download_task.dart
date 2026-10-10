import 'video_download_info.dart';

enum DownloadState { queued, downloading, paused, processing, completed, failed }

/// One entry of the Downloads screen (persisted across launches).
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.option,
    required this.createdAt,
    this.durationSeconds,
    this.state = DownloadState.queued,
    this.received = 0,
    int? total,
    this.error,
    this.resultPath,
    this.libraryItemId,
    this.savedToPhotos = false,
    this.photosError,
    this.completedAt,
  }) : total = total ?? option.totalBytes ?? 0;

  final String id;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int? durationSeconds;
  final DateTime createdAt;

  StreamOption option;
  DownloadState state;
  int received;
  int total;
  String? error;
  String? resultPath;
  String? libraryItemId;
  bool savedToPhotos;
  String? photosError;
  DateTime? completedAt;

  /// Live transfer speed in bytes/second (not persisted).
  double speed = 0;

  double? get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  bool get isVideo => option.isVideo;
  bool get isFinished => state == DownloadState.completed;
  bool get isRunning =>
      state == DownloadState.downloading || state == DownloadState.processing;
  bool get canPause =>
      state == DownloadState.downloading || state == DownloadState.queued;
  bool get canResume =>
      state == DownloadState.paused || state == DownloadState.failed;

  /// Estimated time left, when speed and size are known.
  Duration? get eta {
    if (speed <= 0 || total <= 0 || received >= total) return null;
    return Duration(seconds: ((total - received) / speed).round());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'author': author,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.toIso8601String(),
        'option': option.toJson(),
        'state': state.name,
        'received': received,
        'total': total,
        'error': error,
        'resultPath': resultPath,
        'libraryItemId': libraryItemId,
        'savedToPhotos': savedToPhotos,
        'photosError': photosError,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String? ?? '',
        videoId: json['videoId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        option: StreamOption.fromJson(
          (json['option'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        state: DownloadState.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => DownloadState.paused,
        ),
        received: json['received'] as int? ?? 0,
        total: json['total'] as int?,
        error: json['error'] as String?,
        resultPath: json['resultPath'] as String?,
        libraryItemId: json['libraryItemId'] as String?,
        savedToPhotos: json['savedToPhotos'] as bool? ?? false,
        photosError: json['photosError'] as String?,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      );
}
