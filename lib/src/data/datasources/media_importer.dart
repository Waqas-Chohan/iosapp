import 'dart:io';
import 'dart:math' as math;

import '../../domain/entities/library_item.dart';
import '../../domain/entities/video_download_info.dart';
import 'local_storage_datasource.dart';
import 'media_tools.dart';

/// Copies picked videos / audio files into the app and describes them as
/// [LibraryItem]s (duration, thumbnail, embedded title/artist).
class MediaImporter {
  MediaImporter({LocalStorageDatasource? storage, MediaTools? tools})
      : _storage = storage ?? LocalStorageDatasource(),
        _tools = tools ?? const MediaTools();

  final LocalStorageDatasource _storage;
  final MediaTools _tools;

  static const videoExtensions = {'mp4', 'mov', 'm4v', '3gp'};
  static const audioExtensions = {
    'm4a', 'mp3', 'aac', 'wav', 'aif', 'aiff', 'caf', 'flac', 'alac',
  };

  Future<List<String>> pickFromPhotos() => _tools.pickVideosFromPhotos();

  Future<List<String>> pickFromFiles() => _tools.pickFromFiles();

  Future<List<LibraryItem>> import(List<String> paths) async {
    final out = <LibraryItem>[];
    final downloads = await _storage.downloadsDirectory();
    final thumbs = await _storage.thumbnailsDirectory();
    var n = 0;
    for (final source in paths) {
      final file = File(source);
      if (!await file.exists()) continue;
      final name = source.split('/').last;
      final dot = name.lastIndexOf('.');
      final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
      final stem = dot > 0 ? name.substring(0, dot) : name;
      if (!videoExtensions.contains(ext) && !audioExtensions.contains(ext)) {
        continue;
      }

      final id = 'import_${DateTime.now().millisecondsSinceEpoch}_${n++}';
      var target = File('${downloads.path}/$stem.$ext');
      var k = 2;
      while (await target.exists()) {
        target = File('${downloads.path}/$stem $k.$ext');
        k++;
      }
      try {
        await file.copy(target.path);
      } catch (_) {
        continue;
      }
      try {
        await file.delete(); // picker copies live in tmp/Inbox
      } catch (_) {
        // Not ours to delete — fine.
      }

      final probe = await _tools.probe(target.path, '${thumbs.path}/$id.jpg');
      final isVideo = probe.hasVideo || videoExtensions.contains(ext);
      final w = probe.width ?? 0;
      final h = probe.height ?? 0;
      final quality =
          isVideo && w > 0 && h > 0 ? '${math.min(w, h)}p' : ext.toUpperCase();

      out.add(LibraryItem(
        id: id,
        videoId: id,
        title: (probe.title?.trim().isNotEmpty ?? false)
            ? probe.title!.trim()
            : _prettify(stem),
        author: (probe.artist?.trim().isNotEmpty ?? false)
            ? probe.artist!.trim()
            : (isVideo ? 'Imported video' : 'Imported audio'),
        filePath: target.path,
        category: isVideo ? StreamCategory.muxed : StreamCategory.audio,
        qualityLabel: quality,
        container: ext,
        thumbnailPath: probe.thumbnailPath ?? '',
        createdAt: DateTime.now(),
        durationSeconds: probe.duration?.inSeconds,
      ));
    }
    return out;
  }

  static String _prettify(String stem) {
    final s = stem.replaceAll(RegExp(r'_+'), ' ').trim();
    return s.isEmpty ? 'Imported media' : s;
  }
}
