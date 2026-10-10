import 'package:flutter/material.dart';

import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/library_collection.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../components/app_colors.dart';
import '../components/mini_player_bar.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';

/// Root post-login shell: Home + Library tabs with the mini player.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.repository, this.libraryRepository});

  final VideoRepository? repository;
  final LibraryRepository? libraryRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final PlayerController _player = PlayerController();
  late final LibraryModel _library;
  int _tab = 0;
  final List<LibraryCollection> _collections = [];

  @override
  void initState() {
    super.initState();
    _library = LibraryModel(
      widget.libraryRepository ?? LibraryRepositoryImpl(),
    );
    _library.refresh();
  }

  @override
  void dispose() {
    _player.dispose();
    _library.dispose();
    super.dispose();
  }

  void _openPlayer() {
    if (_player.current == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(player: _player),
      ),
    );
  }

  void _onCollectionCreated(LibraryCollection collection) {
    setState(() {
      _collections.insert(0, collection);
      _tab = 2;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${collection.type} created: ${collection.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _library,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                repository: widget.repository,
                player: _player,
                libraryModel: _library,
              ),
              SearchScreen(items: _library.items, player: _player),
              LibraryScreen(
                player: _player,
                libraryModel: _library,
                collections: _collections,
              ),
              CreateScreen(
                items: _library.items,
                onCreate: _onCollectionCreated,
              ),
            ],
          ),
          bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: _player,
            builder: (context, _) => _player.current == null
                ? const SizedBox.shrink()
                : MiniPlayerBar(player: _player, onTap: _openPlayer),
          ),
          NavigationBar(
            backgroundColor: Colors.white,
            indicatorColor: AppColors.accentOrange.withValues(alpha: 0.18),
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: Icon(
                  _tab == 0 ? Icons.home : Icons.home_outlined,
                  color: _tab == 0
                      ? AppColors.splashNavy
                      : AppColors.textGray,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  _tab == 1 ? Icons.search : Icons.search_outlined,
                  color: _tab == 1
                      ? AppColors.splashNavy
                      : AppColors.textGray,
                ),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(
                  _tab == 2
                      ? Icons.library_music
                      : Icons.library_music_outlined,
                  color: _tab == 2
                      ? AppColors.splashNavy
                      : AppColors.textGray,
                ),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(
                  _tab == 3 ? Icons.create : Icons.create_outlined,
                  color: _tab == 3
                      ? AppColors.splashNavy
                      : AppColors.textGray,
                ),
                label: 'Create',
              ),
            ],
          ),
        ],
      ),
    );
      },
    );
  }
}
