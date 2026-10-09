import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves the app sandbox folder used to store downloads.
class LocalStorageDatasource {
  Future<Directory> downloadsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/musically_downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
