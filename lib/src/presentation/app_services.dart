import 'package:flutter/material.dart';

import '../data/datasources/media_importer.dart';
import '../domain/entities/library_item.dart';
import 'controllers/collections_model.dart';
import 'controllers/download_manager.dart';
import 'controllers/library_ai_service.dart';
import 'controllers/library_model.dart';
import 'controllers/player_controller.dart';
import 'screens/player_screen.dart';

/// Shared app state handed to every post-login screen.
class AppServices {
  AppServices({
    required this.player,
    required this.library,
    required this.collections,
    required this.downloads,
    required this.ai,
    MediaImporter? importer,
  }) : importer = importer ?? MediaImporter();

  final PlayerController player;
  final LibraryModel library;
  final CollectionsModel collections;
  final DownloadManager downloads;
  final LibraryAiService ai;
  final MediaImporter importer;

  /// Rebuild trigger for anything that shows library or playlist data.
  Listenable get libraryChanges => Listenable.merge([library, collections]);

  /// Starts [queue] at [index] and opens the full player.
  Future<void> playAndOpen(
    BuildContext context,
    List<LibraryItem> queue, {
    int index = 0,
    bool shuffle = false,
  }) async {
    if (queue.isEmpty) return;
    var list = queue;
    var start = index;
    if (shuffle) {
      list = List.of(queue)..shuffle();
      start = 0;
    }
    final navigator = Navigator.of(context);
    await player.playQueue(list, startIndex: start);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(player: player)),
    );
  }
}
