import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves app sandbox folders: downloads, library registry + artworks.
class LocalStorageDatasource {
  Future<Directory> downloadsDirectory() async {
    final dir = Directory('${(await _documents()).path}/musically_downloads');
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

  Future<File> libraryRegistryFile() async {
    final dir = Directory('${(await _documents()).path}/musically_library');
    await _ensure(dir);
    return File('${dir.path}/library.json');
  }

  Future<Directory> _documents() async =>
      getApplicationDocumentsDirectory();

  Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

