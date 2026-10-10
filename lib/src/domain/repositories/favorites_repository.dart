/// Persistent store for the user's favorite artist names.
abstract interface class FavoritesRepository {
  Future<List<String>> load();
  Future<void> save(List<String> names);
}
