import '../entities/library_item.dart';

/// Contract for the on-device media library (playlist store).
abstract interface class LibraryRepository {
  Future<List<LibraryItem>> loadItems();
  Future<void> addItem(LibraryItem item);
  Future<void> removeItem(String id);

  /// Downloads the artwork for [videoId] locally (persisted, offline-safe).
  Future<String> saveThumbnail(String url, String videoId);
}
