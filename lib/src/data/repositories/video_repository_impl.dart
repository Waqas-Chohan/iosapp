import 'package:gal/gal.dart';

import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/youtube_datasource.dart';

/// Concrete [VideoRepository]: YoutubeExplode + gal.
class VideoRepositoryImpl implements VideoRepository {
  final YoutubeDatasource _youtube = YoutubeDatasource();

  /// Album created in the Photos app for everything Muz saves.
  static const photosAlbum = 'Muz';

  @override
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId) =>
      _youtube.fetch(urlOrId);

  @override
  Future<String?> refreshStreamUrl(String videoId, int tag) =>
      _youtube.refreshStreamUrl(videoId, tag);

  @override
  Future<void> saveVideoToGallery(String filePath) async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw Exception('Photo library access was denied. '
            'Allow it in Settings › Musically › Photos.');
      }
    }
    await Gal.putVideo(filePath, album: photosAlbum);
  }

  @override
  void close() => _youtube.close();
}
