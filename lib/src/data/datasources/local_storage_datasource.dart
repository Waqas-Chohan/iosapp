import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves app sandbox folders: downloads, library registry + artworks.
///
/// Everything lives in the app's Documents folder, which is also visible
/// in the iOS Files app (On My iPhone › Musically).
class LocalStorageDatasource {
  Future<Directory> downloadsDirectory() async {
    final dir = Directory('${(await _documents()).path}/musically_downloads');
    return _ensure(dir);
  }

  /// Partial files of in-progress downloads (kept for resume).
  Future<Directory> partialDirectory() async {
    final dir =
        Directory('${(await _documents()).path}/musically_library/partial');
    return _ensure(dir);
  }

  Future<Directory> thumbnailsDirectory() async {
    final dir =
        Directory('${(await _documents()).path}/musically_library/thumbs');
    return _ensure(dir);
  }

  Future<Directory> lyricsDirectory() async {
    final dir =
        Directory('${(await _documents()).path}/musically_library/lyrics');
    return _ensure(dir);
  }

  Future<File> libraryRegistryFile() => _libraryFile('library.json');

  Future<File> collectionsFile() => _libraryFile('collections.json');

  Future<File> downloadsRegistryFile() => _libraryFile('downloads.json');

  Future<File> aiCacheFile() => _libraryFile('ai_cache.json');

  Future<File> _libraryFile(String name) async {
    final dir = Directory('${(await _documents()).path}/musically_library');
    await _ensure(dir);
    return File('${dir.path}/$name');
  }

  /// iOS moves the app container on updates/reinstalls, so absolute paths
  /// saved earlier can go stale. Re-anchors [path] onto the current
  /// Documents folder when the original file no longer exists.
  Future<String> rebase(String path) async {
    if (path.isEmpty || !path.startsWith('/')) return path;
    if (await File(path).exists()) return path;
    const marker = '/Documents/';
    final i = path.indexOf(marker);
    if (i < 0) return path;
    final candidate =
        '${(await _documents()).path}/${path.substring(i + marker.length)}';
    return await File(candidate).exists() ? candidate : path;
  }

  Future<Directory> _documents() async => getApplicationDocumentsDirectory();

  Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
