import '../entities/video_download_info.dart';

/// Progress callback for an active download.
typedef DownloadProgressCallback = void Function(
  int receivedBytes,
  int totalBytes,
);

/// Contract for the video source + local media store.
///
/// Implementations live in `data/repositories` (YoutubeExplode + dio + gal).
abstract interface class VideoRepository {
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId);

  /// Downloads the given stream and returns the local file path.
  Future<String> downloadToLocal(
    StreamOption option,
    DownloadProgressCallback? onProgress,
  );

  void cancelDownload();

  /// Saves a local file into the iOS Photos library.
  Future<void> saveVideoToGallery(String filePath);

  void close();
}
