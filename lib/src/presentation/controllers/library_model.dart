import 'package:flutter/foundation.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/repositories/library_repository.dart';

/// Shared on-device library state (drives the Library screen).
class LibraryModel extends ChangeNotifier {
  LibraryModel(this.repository);

  final LibraryRepository repository;
  List<LibraryItem> items = [];
  bool loaded = false;

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

  Future<void> remove(String id) async {
    await repository.removeItem(id);
    await refresh();
  }
}
