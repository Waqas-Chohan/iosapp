import 'package:flutter/foundation.dart';

import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/extract_video_id.dart';

enum DownloadStatus { idle, loading, ready, downloading, done, error }

/// Drives the home screen state machine.
///
/// Purely UI-policy logic; all I/O goes through the injected
/// [VideoRepository] (domain contract).
class DownloadController extends ChangeNotifier {
  DownloadController(this._repository) : _extract = ExtractVideoId();

  final VideoRepository _repository;
  final ExtractVideoId _extract;

  DownloadStatus status = DownloadStatus.idle;
  VideoDownloadInfo? info;
  String? errorMessage;
  String? downloadedPath;

  double progress = 0;
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
      errorMessage =
          'Could not fetch the video.\n${_shortError(e)}';
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
    status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final path = await _repository.downloadToLocal(option, _onProgress);
      if (status != DownloadStatus.downloading) return;
      downloadedPath = path;
      progress = 1;
      status = DownloadStatus.done;
    } catch (e) {
      if (status != DownloadStatus.downloading) return;
      errorMessage =
          'Download failed.\n${_shortError(e)}';
      status = DownloadStatus.error;
    }
    notifyListeners();
  }

  void _onProgress(int received, int total) {
    if (total > 0) _total = total;
    _received = received;

    final now = DateTime.now();
    final elapsedMs = _lastTick == null ? 0 : now.difference(_lastTick!).inMilliseconds;
    if (elapsedMs < 200) return; // Throttle rebuilds to ~5/s.

    final bytesSinceTick = received - _lastReceivedAtTick;
    final speedBytesPerSec = bytesSinceTick / (elapsedMs / 1000);

    _lastTick = now;
    _lastReceivedAtTick = received;
    progress = _total > 0 ? _received / _total : 0;
    totalLabel = '${_formatBytes(_received)} / ${_formatBytes(_total)}';
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
    await _repository.saveVideoToGallery(downloadedPath!);
  }

  void reset() {
    status = DownloadStatus.idle;
    info = null;
    errorMessage = null;
    downloadedPath = null;
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
