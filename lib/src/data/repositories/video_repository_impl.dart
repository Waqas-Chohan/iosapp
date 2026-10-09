import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/youtube_datasource.dart';

/// Concrete [VideoRepository]: YoutubeExplode + dio + gal + path_provider.
class VideoRepositoryImpl implements VideoRepository {
  final YoutubeDatasource _youtube = YoutubeDatasource();
  final LocalStorageDatasource _storage = LocalStorageDatasource();
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  @override
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId) =>
      _youtube.fetch(urlOrId);

  @override
  Future<String> downloadToLocal(
    StreamOption option,
    DownloadProgressCallback? onProgress,
  ) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final dir = await _storage.downloadsDirectory();
    final path = '${dir.path}/${_safeFileName(option)}';

    if (option.isFragmentBased) {
      await _downloadFragments(option, path, onProgress);
    } else {
      await _dio.download(
        option.url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received, total);
        },
        cancelToken: _cancelToken,
      );
    }

    if (!await File(path).exists()) {
      throw Exception('Download failed: file was not saved.');
    }
    return path;
  }

  Future<void> _downloadFragments(
    StreamOption option,
    String path,
    DownloadProgressCallback? onProgress,
  ) async {
    final expected = option.sizeBytes ?? 0;
    var received = 0;
    final sink = File(path).openWrite();

    try {
      await for (final chunk in _youtube.streamFor(option.videoId, option.tag)) {
        if (_cancelToken!.isCancelled) {
          throw DioException.requestCancelled(
            requestOptions: RequestOptions(path: path),
            reason: 'Download cancelled',
          );
        }
        sink.add(chunk);
        received += chunk.length;
        if (expected > 0) onProgress?.call(received, expected);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  @override
  void cancelDownload() => _cancelToken?.cancel();

  @override
  Future<void> saveVideoToGallery(String filePath) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('Photo library access was denied.');
      }
    }
    await Gal.putVideo(filePath);
  }

  @override
  void close() => _youtube.close();

  String _safeFileName(StreamOption option) {
    final ext = option.extensionName.isEmpty ? 'mp4' : option.extensionName;
    return 'video_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }
}

