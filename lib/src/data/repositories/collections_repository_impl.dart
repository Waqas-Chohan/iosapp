import 'dart:convert';
import 'dart:io';

import '../../domain/entities/library_collection.dart';
import '../../domain/repositories/collections_repository.dart';
import '../datasources/local_storage_datasource.dart';

/// JSON-file backed playlists/albums (`musically_library/collections.json`).
class CollectionsRepositoryImpl implements CollectionsRepository {
  final LocalStorageDatasource _storage = LocalStorageDatasource();

  @override
  Future<List<LibraryCollection>> load() async {
    final file = await _storage.collectionsFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LibraryCollection.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<LibraryCollection> collections) async {
    final file = await _storage.collectionsFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(collections.map((c) => c.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(file.path); // atomic replace
  }
}
