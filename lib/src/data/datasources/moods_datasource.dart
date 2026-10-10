import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tiny JSON store for user-created moods, kept in its own file so it never
/// collides with the theme settings (`settings.json`).
class MoodsStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/moods.json');
  }

  /// The list of custom mood names the user has added (best-effort).
  Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persists [moods] (overwrites the stored list).
  Future<void> save(List<String> moods) async {
    try {
      await (await _file()).writeAsString(jsonEncode(moods));
    } catch (_) {
      // best-effort persistence
    }
  }
}
