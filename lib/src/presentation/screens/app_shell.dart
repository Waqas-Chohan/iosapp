import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/collections_repository_impl.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/repositories/collections_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../app_services.dart';
import '../components/glass_nav_bar.dart';
import '../components/mini_player_bar.dart';
import '../components/ui_kit.dart';
import '../controllers/collections_model.dart';
import '../controllers/download_manager.dart';
import '../controllers/favorites_model.dart';
import '../controllers/library_ai_service.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'youtube_search_screen.dart';

/// Root post-login shell: Home, Search, Library and Downloads tabs with
/// the mini player above the navigation bar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.repository,
    this.libraryRepository,
    this.collectionsRepository,
  });

  final VideoRepository? repository;
  final LibraryRepository? libraryRepository;
  final CollectionsRepository? collectionsRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppServices _services;
  StreamSubscription<DownloadTask>? _completedSub;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final library =
        LibraryModel(widget.libraryRepository ?? LibraryRepositoryImpl());
    final collections = CollectionsModel(
      widget.collectionsRepository ?? CollectionsRepositoryImpl(),
    );
    final player = PlayerController();
    library.onRemoved = collections.forgetItem;
    final favorites = FavoritesModel(FavoritesRepositoryImpl());
    _services = AppServices(
      player: player,
      library: library,
      collections: collections,
      downloads: DownloadManager(
        widget.repository ?? VideoRepositoryImpl(),
        library: library,
      ),
      ai: LibraryAiService(player),
      favorites: favorites,
    );
    library.refresh();
    collections.load();
    favorites.load();
    _services.downloads.load();
    _completedSub = _services.downloads.onCompleted.listen(_onCompleted);
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _services.downloads.dispose();
    _services.player.dispose();
    _services.library.dispose();
    _services.collections.dispose();
    _services.favorites.dispose();
    super.dispose();
  }

  void _onCompleted(DownloadTask t) {
    if (!mounted) return;
    final where = !t.isVideo
        ? 'added to your Library'
        : t.savedToPhotos
            ? 'saved to Photos and your Library'
            : 'added to your Library';
    Ui.snack(
      context,
      '“${t.title}” $where',
      action: 'Play',
      onAction: () {
        final item = t.libraryItemId == null
            ? null
            : _services.library.byId(t.libraryItemId!);
        if (item != null) _services.playAndOpen(context, [item]);
      },
    );
  }

  void _openPlayer() {
    if (_services.player.current == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(player: _services.player),
      ),
    );
  }

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final s = _services;
    return Scaffold(
      // Let page content extend behind the glass bar so the blur shows it.
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(services: s, onOpenTab: _goTo),
          YoutubeSearchScreen(services: s, embedded: true),
          LibraryScreen(services: s),
          DownloadsScreen(services: s, onSearch: () => _goTo(1)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: s.player,
            builder: (context, _) => s.player.current == null
                ? const SizedBox.shrink()
                : MiniPlayerBar(player: s.player, onTap: _openPlayer),
          ),
          // iOS 27 Liquid Glass tab bar — same tabs, badge and callbacks.
          ListenableBuilder(
            listenable: s.downloads,
            builder: (context, _) => GlassNavBar(
              selectedIndex: _tab,
              onSelected: _goTo,
              items: [
                NavItem(
                  icon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                ),
                NavItem(
                  icon: Icons.search_rounded,
                  inactiveIcon: Icons.search_outlined,
                  label: 'Search',
                  index: 1,
                ),
                NavItem(
                  icon: Icons.library_music_rounded,
                  inactiveIcon: Icons.library_music_outlined,
                  label: 'Library',
                  index: 2,
                ),
                NavItem(
                  icon: Icons.download_rounded,
                  inactiveIcon: Icons.download_outlined,
                  label: 'Downloads',
                  index: 3,
                  badgeCount: s.downloads.inProgressCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
