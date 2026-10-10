import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/local_storage_datasource.dart';

/// JSON-file backed media library + local thumbnail cache.
class LibraryRepositoryImpl implements LibraryRepository {
  final LocalStorageDatasource _storage = LocalStorageDatasource();
  final Dio _dio = Dio();

  @override
  Future<List<LibraryItem>> loadItems() async {
    final file = await _storage.libraryRegistryFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList();
      // Re-anchor paths if iOS moved the app container (app update).
      var changed = false;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final file = await _storage.rebase(item.filePath);
        final thumb = await _storage.rebase(item.thumbnailPath);
        if (file != item.filePath || thumb != item.thumbnailPath) {
          items[i] = item.copyWith(filePath: file, thumbnailPath: thumb);
          changed = true;
        }
      }
      if (changed) await _write(items);
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addItem(LibraryItem item) async {
    final items = await loadItems();
    items.insert(0, item);
    await _write(items);
  }

  @override
  Future<void> removeItem(String id) async {
    final items = await loadItems();
    items.removeWhere((i) => i.id == id);
    await _write(items);
  }

  @override
  Future<String> saveThumbnail(String url, String videoId) async {
    if (url.isEmpty) return '';
    final dir = await _storage.thumbnailsDirectory();
    final file = File('${dir.path}/$videoId.jpg');
    if (await file.exists()) return file.path;
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      await file.writeAsBytes(res.data ?? const [], flush: true);
      return (await file.exists()) ? file.path : url;
    } catch (_) {
      return url; // Fall back to the network URL.
    }
  }

  Future<void> _write(List<LibraryItem> items) async {
    final file = await _storage.libraryRegistryFile();
    await file.writeAsString(
      jsonEncode(items.map((i) => i.toJson()).toList()),
    );
  }
}
