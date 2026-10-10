import '../entities/video_download_info.dart';

/// Contract for the video source + Photos export.
///
/// Implementations live in `data/repositories` (YoutubeExplode + gal).
/// Byte transfer itself is handled by the download manager.
abstract interface class VideoRepository {
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId);

  /// A fresh direct URL for stream [tag] (YouTube URLs expire).
  Future<String?> refreshStreamUrl(String videoId, int tag);

  /// Saves a local video file into the iOS Photos library.
  Future<void> saveVideoToGallery(String filePath);

  void close();
}
