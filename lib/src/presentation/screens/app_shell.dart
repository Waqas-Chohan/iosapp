import 'package:flutter/material.dart';

import '../../data/repositories/library_repository_impl.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../components/mini_player_bar.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            repository: widget.repository,
            player: _player,
            libraryModel: _library,
          ),
          LibraryScreen(player: _player, libraryModel: _library),
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
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
