import 'dart:convert';
import 'dart:io';

import '../../domain/repositories/favorites_repository.dart';
import '../datasources/local_storage_datasource.dart';

/// JSON-file backed favorite artists (`musically_library/favorites.json`).
///
/// Stores an ordered list of artist name strings. Names are trimmed and
/// de-duplicated case-insensitively on save.
class FavoritesRepositoryImpl implements FavoritesRepository {
  final LocalStorageDatasource _storage = LocalStorageDatasource();

  @override
  Future<List<String>> load() async {
    final file = await _storage.favoritesFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<String> names) async {
    // Normalize: trim, drop empties, de-dup (case-insensitive), keep order.
    final seen = <String>{};
    final clean = <String>[];
    for (final n in names) {
      final trimmed = n.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) clean.add(trimmed);
    }
    final file = await _storage.favoritesFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(clean), flush: true);
    await tmp.rename(file.path); // atomic replace
  }
}
