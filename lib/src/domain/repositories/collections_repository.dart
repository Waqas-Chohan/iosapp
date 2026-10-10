import '../entities/library_collection.dart';

/// Persistent store for playlists and albums.
abstract interface class CollectionsRepository {
  Future<List<LibraryCollection>> load();
  Future<void> save(List<LibraryCollection> collections);
}
