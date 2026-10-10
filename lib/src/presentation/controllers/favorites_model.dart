import 'package:flutter/foundation.dart';

import '../../domain/repositories/favorites_repository.dart';

/// Favorite-artists state (persisted after every change).
///
/// Stores an ordered list of artist names. Toggling prepends newly favorited
/// artists so the favorites list stays in "most recent first" order.
class FavoritesModel extends ChangeNotifier {
  FavoritesModel(this.repository);

  final FavoritesRepository repository;
  List<String> artists = [];
  bool loaded = false;

  Future<void> load() async {
    try {
      artists = await repository.load();
    } catch (_) {
      artists = [];
    }
    loaded = true;
    notifyListeners();
  }

  /// Case-insensitive membership check.
  bool isFavorite(String artist) {
    final key = artist.trim().toLowerCase();
    return artists.any((a) => a.trim().toLowerCase() == key);
  }

  /// Adds or removes [artist]. Returns `true` if it is now a favorite.
  Future<bool> toggle(String artist) async {
    final trimmed = artist.trim();
    if (trimmed.isEmpty) return isFavorite(trimmed);
    if (isFavorite(trimmed)) {
      artists = artists
          .where((a) => a.trim().toLowerCase() != trimmed.toLowerCase())
          .toList();
      await _persist();
      return false;
    }
    artists = [trimmed, ...artists];
    await _persist();
    return true;
  }

  Future<void> add(String artist) async {
    if (isFavorite(artist)) return;
    artists = [artist.trim(), ...artists];
    await _persist();
  }

  Future<void> remove(String artist) async {
    final key = artist.trim().toLowerCase();
    artists =
        artists.where((a) => a.trim().toLowerCase() != key).toList();
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    try {
      await repository.save(artists);
    } catch (_) {
      // Keep in-memory state; next change retries the write.
    }
  }
}
