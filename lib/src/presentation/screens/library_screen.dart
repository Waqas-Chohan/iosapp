import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/collection_sheets.dart';
import '../components/import_actions.dart';
import '../components/ui_kit.dart';
import 'playlist_screen.dart';

enum _Filter { all, playlists, albums, songs, videos }

enum _Sort { recent, title, artist }

/// Spotify-style Library: playlists, albums, songs and videos.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.recent;
  bool _searching = false;

  AppServices get s => widget.services;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createCollection() async {
    final c = await showCreateCollectionSheet(
      context,
      s,
      type: _filter == _Filter.albums
          ? LibraryCollection.album
          : LibraryCollection.playlist,
    );
    if (c == null || !mounted) return;
    openPlaylist(context, s, c.id, promptAdd: true);
  }

  List<LibraryItem> _sorted(List<LibraryItem> items) {
    final q = _search.text.trim().toLowerCase();
    final list = q.isEmpty
        ? List.of(items)
        : items
            .where((i) =>
                '${i.title} ${i.author} ${i.qualityLabel}'.toLowerCase().contains(q))
            .toList();
    switch (_sort) {
      case _Sort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.artist:
        list.sort(
            (a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.splashNavy,
        titleSpacing: Ui.gutter,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.inputText,
                decoration: const InputDecoration(
                  hintText: 'Search your library',
                  border: InputBorder.none,
                ),
              )
            : const Text('Your Library', style: Ui.screenTitle),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          IconButton(
            tooltip: 'Import videos',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => importMedia(context, s),
          ),
          IconButton(
            tooltip: 'New playlist',
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: _createCollection,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.libraryChanges,
        builder: (context, _) {
          if (!s.library.loaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            );
          }
          final all = s.library.items;
          final collections = s.collections.collections.where((c) {
            if (_filter == _Filter.playlists) return !c.isAlbum;
            if (_filter == _Filter.albums) return c.isAlbum;
            if (_filter == _Filter.all) return true;
            return false;
          }).where((c) {
            final q = _search.text.trim().toLowerCase();
            return q.isEmpty || c.name.toLowerCase().contains(q);
          }).toList();
          final tracks = switch (_filter) {
            _Filter.all => _sorted(all),
            _Filter.songs => _sorted(s.library.songs),
            _Filter.videos => _sorted(s.library.videos),
            _ => <LibraryItem>[],
          };

          final children = <Widget>[
            _filters(),
            if (all.isEmpty && s.collections.collections.isEmpty)
              EmptyState(
                icon: Icons.library_music_rounded,
                title: 'Your Library is empty',
                message: 'Download from Search or import videos from '
                    'Photos and Files. Everything you add lands here.',
                actions: [
                  PillButton(
                    label: 'Import videos',
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed: () => importMedia(context, s),
                  ),
                  PillButton(
                    label: 'New playlist',
                    icon: Icons.add_rounded,
                    outlined: true,
                    onPressed: _createCollection,
                  ),
                ],
              ),
            if (_filter == _Filter.playlists || _filter == _Filter.albums)
              _NewCollectionRow(
                label: _filter == _Filter.albums ? 'New album' : 'New playlist',
                onTap: _createCollection,
              ),
            for (final c in collections)
              _CollectionRow(
                collection: c,
                items: s.collections.itemsOf(c, all),
                onTap: () => openPlaylist(context, s, c.id),
              ),
            if (tracks.isNotEmpty) ...[
              _SortRow(
                count: tracks.length,
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
              ),
              for (var i = 0; i < tracks.length; i++)
                TrackTile(
                  item: tracks[i],
                  isPlaying: s.player.current?.id == tracks[i].id,
                  onTap: () => s.playAndOpen(context, tracks, index: i),
                  onMore: () =>
                      showTrackActions(context, s, tracks[i], queue: tracks),
                ),
            ] else if (all.isNotEmpty &&
                (_filter == _Filter.songs || _filter == _Filter.videos))
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Nothing here yet.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.description),
              ),
            const SizedBox(height: 24),
          ];
          return ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            children: children,
          );
        },
      ),
    );
  }

  Widget _filters() {
    const labels = {
      _Filter.all: 'All',
      _Filter.playlists: 'Playlists',
      _Filter.albums: 'Albums',
      _Filter.songs: 'Songs',
      _Filter.videos: 'Videos',
    };
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Ui.gutter, vertical: 8),
        children: [
          for (final f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[f]!),
                selected: _filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = f),
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: _filter == f ? Colors.white : AppColors.splashNavy,
                ),
                selectedColor: AppColors.splashNavy,
                backgroundColor: AppColors.inputFill,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.count, required this.sort, required this.onSort});

  final int count;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context) {
    const names = {
      _Sort.recent: 'Recently added',
      _Sort.title: 'Title',
      _Sort.artist: 'Artist',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.gutter, 14, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'item' : 'items'}',
              style: AppTextStyles.optionSubtitle,
            ),
          ),
          PopupMenuButton<_Sort>(
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final e in names.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_vert_rounded,
                      size: 18, color: AppColors.splashNavy),
                  const SizedBox(width: 4),
                  Text(names[sort]!,
                      style: AppTextStyles.optionSubtitle.copyWith(
                          color: AppColors.splashNavy,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    required this.items,
    required this.onTap,
  });

  final LibraryCollection collection;
  final List<LibraryItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ui.gutter, vertical: 7),
        child: Row(
          children: [
            CollectionCover(
              items: items,
              size: 60,
              isAlbum: collection.isAlbum,
              borderRadius: collection.isAlbum ? 30 : 10,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.optionTitle
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Ui.collectionMeta(
                        collection, items.length, Ui.totalDuration(items)),
                    style: AppTextStyles.optionSubtitle,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }
}

class _NewCollectionRow extends StatelessWidget {
  const _NewCollectionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ui.gutter, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 32, color: AppColors.splashNavy),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: AppTextStyles.optionTitle
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
