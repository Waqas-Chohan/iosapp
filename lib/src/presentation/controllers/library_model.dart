import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/repositories/library_repository.dart';

/// Shared on-device library state (drives Home, Library and playlists).
class LibraryModel extends ChangeNotifier {
  LibraryModel(this.repository);

  final LibraryRepository repository;
  List<LibraryItem> items = [];
  bool loaded = false;

  /// Called after an item is removed (collections prune their references).
  void Function(String itemId)? onRemoved;

  List<LibraryItem> get videos => items.where((i) => i.isVideo).toList();
  List<LibraryItem> get songs => items.where((i) => !i.isVideo).toList();

  LibraryItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> refresh() async {
    try {
      items = await repository.loadItems();
    } catch (_) {
      items = [];
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> add(LibraryItem item) async {
    await repository.addItem(item);
    await refresh();
  }

  /// Removes the item from the library and deletes its media file.
  Future<void> remove(String id, {bool deleteFile = true}) async {
    final item = byId(id);
    await repository.removeItem(id);
    if (deleteFile && item != null) {
      try {
        final f = File(item.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // A file that is already gone is fine.
      }
    }
    onRemoved?.call(id);
    await refresh();
  }
}
