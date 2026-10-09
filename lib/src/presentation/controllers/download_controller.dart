import 'package:flutter/foundation.dart';

import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/extract_video_id.dart';

enum DownloadStatus { idle, loading, ready, downloading, done, error }

/// Drives the home screen state machine.
///
/// All I/O goes through the injected [VideoRepository] + [LibraryRepository].
class DownloadController extends ChangeNotifier {
  DownloadController(
    this._repository, {
    LibraryRepository? libraryRepository,
  })  : _library = libraryRepository ?? LibraryRepositoryImpl(),
        _extract = ExtractVideoId();

  final VideoRepository _repository;
  final LibraryRepository _library;
  final ExtractVideoId _extract;

  DownloadStatus status = DownloadStatus.idle;
  VideoDownloadInfo? info;
  String? errorMessage;
  String? downloadedPath;
  LibraryItem? downloadedItem;
  StreamCategory? downloadedCategory;

  /// Progress 0..1, or `null` when the total size is unknown.
  double? progress;
  String totalLabel = '';
  String speedLabel = '';

  DateTime? _lastTick;
  int _lastReceivedAtTick = 0;
  int _received = 0;
  int _total = 0;

  /// Validates and fetches video info. Never touches the network on
  /// an invalid link (the id extractor fails first).
  Future<void> fetchVideo(String rawInput) async {
    final videoId = _extract(rawInput);
    if (videoId == null) {
      status = DownloadStatus.error;
      errorMessage = 'That does not look like a valid YouTube link.';
      notifyListeners();
      return;
    }

    status = DownloadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      info = await _repository.fetchVideoInfo(videoId);
      status = DownloadStatus.ready;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('RequestLimitExceeded') ||
          msg.toLowerCase().contains('rate limit')) {
        errorMessage = 'YouTube is rate-limiting right now.\n'
            'Wait a minute or two, or switch between Wi-Fi & '
            'mobile data, then try again.';
      } else {
        errorMessage = 'Could not fetch the video.\n${_shortError(e)}';
      }
      status = DownloadStatus.error;
    }
    notifyListeners();
  }

  Future<void> startDownload(StreamOption option) async {
    _received = 0;
    _total = 0;
    _lastTick = DateTime.now();
    _lastReceivedAtTick = 0;
    progress = 0;
    totalLabel = '';
    speedLabel = '';
    downloadedPath = null;
    downloadedItem = null;
    downloadedCategory = null;
    status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final path = await _repository.downloadToLocal(option, _onProgress);
      if (status != DownloadStatus.downloading) return;
      await _registerInLibrary(option, path);
      progress = 1;
      totalLabel = totalLabel.isEmpty
          ? _formatBytes(option.sizeBytes ?? _received)
          : totalLabel;
      status = DownloadStatus.done;
    } catch (e) {
      if (status != DownloadStatus.downloading) {
        status = DownloadStatus.ready; // user cancelled
      } else {
        errorMessage = 'Download failed.\n${_shortError(e)}';
        status = DownloadStatus.error;
      }
    }
    notifyListeners();
  }

  Future<void> _registerInLibrary(StreamOption option, String path) async {
    final video = info;
    if (video == null) return;
    downloadedCategory = option.category;
    final thumbnailPath = await _library.saveThumbnail(
      video.thumbnailUrl,
      video.videoId,
    );
    downloadedItem = LibraryItem(
      id: '${option.videoId}_${option.tag}_'
          '${DateTime.now().millisecondsSinceEpoch}',
      videoId: video.videoId,
      title: video.title,
      author: video.author,
      filePath: path,
      category: option.category,
      qualityLabel: option.label,
      container: option.container,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
      durationSeconds: video.duration?.inSeconds,
    );
    try {
      await _library.addItem(downloadedItem!);
    } catch (_) {
      // Registry failure must never block the completed download.
    }
  }

  void _onProgress(int received, int total) {
    if (total > 0) _total = total;
    _received = received;

    final now = DateTime.now();
    final elapsedMs =
        _lastTick == null ? 0 : now.difference(_lastTick!).inMilliseconds;
    if (elapsedMs < 200) return;

    final bytesSinceTick = received - _lastReceivedAtTick;
    final speedBytesPerSec = bytesSinceTick / (elapsedMs / 1000);

    _lastTick = now;
    _lastReceivedAtTick = received;
    progress = _total > 0 ? _received / _total : null;
    totalLabel = _total > 0
        ? '${_formatBytes(_received)} / ${_formatBytes(_total)}'
        : _formatBytes(_received);
    speedLabel = '${_formatBytes(speedBytesPerSec.round())}/s';
    notifyListeners();
  }

  void cancel() {
    status = DownloadStatus.ready;
    notifyListeners();
    _repository.cancelDownload();
  }

  Future<void> saveToGallery() async {
    if (downloadedPath == null) return;
    if (downloadedCategory != StreamCategory.muxed) {
      throw Exception('Only videos can be saved to Photos.');
    }
    await _repository.saveVideoToGallery(downloadedPath!);
  }

  void reset() {
    status = DownloadStatus.idle;
    info = null;
    errorMessage = null;
    downloadedPath = null;
    downloadedItem = null;
    downloadedCategory = null;
    progress = 0;
    notifyListeners();
  }

  String _shortError(Object error) {
    final msg = error.toString();
    return msg.length > 160 ? msg.substring(0, 160) : msg;
  }

  static String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
