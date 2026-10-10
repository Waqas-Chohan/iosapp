import 'package:flutter/foundation.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/repositories/collections_repository.dart';

/// Playlists & albums state (persisted after every change).
class CollectionsModel extends ChangeNotifier {
  CollectionsModel(this.repository);

  final CollectionsRepository repository;
  List<LibraryCollection> collections = [];
  bool loaded = false;

  Future<void> load() async {
    try {
      collections = await repository.load();
    } catch (_) {
      collections = [];
    }
    loaded = true;
    notifyListeners();
  }

  LibraryCollection? byId(String id) {
    for (final c in collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Resolves a collection's ids to library items (missing ones skipped).
  List<LibraryItem> itemsOf(LibraryCollection c, List<LibraryItem> library) {
    final byId = {for (final i in library) i.id: i};
    return [
      for (final id in c.itemIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<LibraryCollection> create(
    String name, {
    String type = LibraryCollection.playlist,
    List<String> itemIds = const [],
  }) async {
    final c = LibraryCollection(
      id: 'collection_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'My ${type.toLowerCase()}' : name.trim(),
      type: type,
      itemIds: List.of(itemIds),
      createdAt: DateTime.now(),
    );
    collections = [c, ...collections];
    await _persist();
    return c;
  }

  Future<void> rename(String id, String name, {String? description}) =>
      _update(id, (c) => c.copyWith(name: name.trim(), description: description));

  Future<void> setType(String id, String type) =>
      _update(id, (c) => c.copyWith(type: type));

  Future<void> delete(String id) async {
    collections = collections.where((c) => c.id != id).toList();
    await _persist();
  }

  /// Adds [itemIds] (skipping duplicates). Returns how many were added.
  Future<int> addItems(String id, List<String> itemIds) async {
    var added = 0;
    await _update(id, (c) {
      final ids = List.of(c.itemIds);
      for (final i in itemIds) {
        if (!ids.contains(i)) {
          ids.add(i);
          added++;
        }
      }
      return c.copyWith(itemIds: ids);
    });
    return added;
  }

  Future<void> removeItem(String id, String itemId) => _update(
        id,
        (c) => c.copyWith(
          itemIds: c.itemIds.where((i) => i != itemId).toList(),
        ),
      );

  /// Replaces the order with [orderedIds] (ids not listed keep their
  /// relative order at the end).
  Future<void> setOrder(String id, List<String> orderedIds) => _update(id, (c) {
        final rest = c.itemIds.where((i) => !orderedIds.contains(i));
        return c.copyWith(itemIds: [...orderedIds, ...rest]);
      });

  /// Drops references to a deleted library item from every collection.
  Future<void> forgetItem(String itemId) async {
    if (!collections.any((c) => c.itemIds.contains(itemId))) return;
    collections = [
      for (final c in collections)
        c.itemIds.contains(itemId)
            ? c.copyWith(
                itemIds: c.itemIds.where((i) => i != itemId).toList())
            : c,
    ];
    await _persist();
  }

  Future<void> _update(
    String id,
    LibraryCollection Function(LibraryCollection) change,
  ) async {
    collections = [
      for (final c in collections) c.id == id ? change(c) : c,
    ];
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    try {
      await repository.save(collections);
    } catch (_) {
      // Keep the in-memory state; next change retries the write.
    }
  }
}
