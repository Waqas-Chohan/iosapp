import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/collection_sheets.dart';
import '../controllers/library_ai_service.dart';
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
  String? _selectedArtist;

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

  List<({String artist, List<LibraryItem> items})> _artists(List<LibraryItem> all) {
    final q = _search.text.trim().toLowerCase();
    final map = <String, List<LibraryItem>>{};
    for (final item in all.where((i) => !i.isVideo)) {
      if (q.isNotEmpty && !item.author.toLowerCase().contains(q)) continue;
      map.putIfAbsent(item.author, () => <LibraryItem>[]).add(item);
    }
    final artists = map.entries
        .map((e) => (artist: e.key, items: e.value))
        .toList()
      ..sort((a, b) => b.items.length.compareTo(a.items.length));
    return artists;
  }

  String _artistInitials(String artist) {
    final parts = artist.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.isEmpty ? 'A' : parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
        centerTitle: true,
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
            : const Text('Library', style: Ui.screenTitle),
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
            tooltip: 'Add',
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: _createCollection,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'import':
                  await importMedia(context, s);
                  return;
                case 'artists':
                  if (mounted) setState(() => _selectedArtist = null);
                  return;
                case 'recommendations':
                  if (mounted) setState(() => _filter = _Filter.all);
                  return;
                case 'mood':
                  if (!mounted) return;
                  final playlist = await s.ai.moodPlaylist(
                    library: s.library.items,
                    mood: 'evening drive',
                  );
                  if (!mounted || playlist.items.isEmpty) return;
                  _showPlaylistSheet(playlist.title, playlist.summary, playlist.items);
                  return;
                case 'report':
                  if (!mounted) return;
                  final report = await s.ai.weeklyReport(s.library.items);
                  if (!mounted) return;
                  _showReportSheet(report);
                  return;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Import videos')),
              PopupMenuItem(value: 'artists', child: Text('Artists')),
              PopupMenuItem(value: 'recommendations', child: Text('Recommendations')),
              PopupMenuItem(value: 'mood', child: Text('Mood playlist')),
              PopupMenuItem(value: 'report', child: Text('Weekly report')),
            ],
          ),
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
          final artists = _artists(all);
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
          final artistTracks = _selectedArtist == null ? const <LibraryItem>[] : _artistTracks(all);
          final recommendedFuture = all.isEmpty ? null : s.ai.recommendations(all);

          final children = <Widget>[
            if (_selectedArtist != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Ui.gutter, 12, Ui.gutter, 0),
                child: InputChip(
                  label: Text(_selectedArtist!),
                  onDeleted: () => setState(() => _selectedArtist = null),
                  deleteIcon: const Icon(Icons.close_rounded),
                  avatar: CircleAvatar(child: Text(_artistInitials(_selectedArtist!))),
                ),
              ),
            if (recommendedFuture != null)
              FutureBuilder<List<LibraryItem>>(
                future: recommendedFuture,
                builder: (context, snapshot) {
                  final recommended = snapshot.data ?? const <LibraryItem>[];
                  if (recommended.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      SectionHeader(
                        title: 'For you',
                        subtitle: 'Recommendations tailored from your recent listening',
                        action: 'Play all',
                        onAction: () => s.playAndOpen(context, recommended),
                      ),
                      for (final item in recommended.take(5))
                        TrackTile(
                          item: item,
                          isPlaying: s.player.current?.id == item.id,
                          onTap: () => s.playAndOpen(context, recommended, index: recommended.indexOf(item)),
                          onMore: () => showTrackActions(context, s, item, queue: recommended),
                        ),
                    ],
                  );
                },
              ),
            if (artists.isNotEmpty) ...[
              SectionHeader(
                title: 'Artists',
                subtitle: 'Tap a profile to see every song by that artist',
                action: _selectedArtist == null ? null : 'Clear',
                onAction: _selectedArtist == null ? null : () => setState(() => _selectedArtist = null),
              ),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
                  scrollDirection: Axis.horizontal,
                  itemCount: artists.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final artist = artists[index];
                    final selected = _selectedArtist == artist.artist;
                    return FutureBuilder<String?>(
                      future: s.ai.artistArtworkUrl(artist.artist),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;
                        return InkWell(
                          onTap: () => setState(() => _selectedArtist = artist.artist),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 108,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.splashNavy : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selected ? AppColors.splashNavy : const Color(0xFFE4E8EE),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: selected ? Colors.white : AppColors.splashNavy,
                                  backgroundImage: imageUrl == null || imageUrl.isEmpty
                                      ? null
                                      : NetworkImage(imageUrl),
                                  child: imageUrl == null || imageUrl.isEmpty
                                      ? Text(
                                          _artistInitials(artist.artist),
                                          style: TextStyle(
                                            color: selected ? AppColors.splashNavy : Colors.white,
                                            fontFamily: 'Sora',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  artist.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected ? Colors.white : AppColors.splashNavy,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${artist.items.length} songs',
                                  style: TextStyle(
                                    color: selected ? Colors.white70 : AppColors.textGray,
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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
            if (_selectedArtist != null) ...[
              _SortRow(
                count: artistTracks.length,
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
              ),
              for (var i = 0; i < artistTracks.length; i++)
                TrackTile(
                  item: artistTracks[i],
                  isPlaying: s.player.current?.id == artistTracks[i].id,
                  onTap: () => s.playAndOpen(context, artistTracks, index: i),
                  onMore: () => showTrackActions(context, s, artistTracks[i], queue: artistTracks),
                ),
            ] else if (tracks.isNotEmpty) ...[
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

  List<LibraryItem> _artistTracks(List<LibraryItem> all) {
    final artist = _selectedArtist;
    if (artist == null) return const [];
    return _sorted(all.where((item) => item.author == artist && !item.isVideo).toList());
  }

  void _showPlaylistSheet(String title, String summary, List<LibraryItem> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _InfoSheet(
        title: title,
        summary: summary,
        items: items,
        onPlay: () => s.playAndOpen(context, items),
      ),
    );
  }

  void _showReportSheet(WeeklyListeningReport report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _ReportSheet(report: report),
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

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.title,
    required this.summary,
    required this.items,
    required this.onPlay,
  });

  final String title;
  final String summary;
  final List<LibraryItem> items;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      shrinkWrap: true,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDADFE6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
          child: Text(title, style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
        ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Ui.gutter, 8, Ui.gutter, 0),
            child: Text(summary, textAlign: TextAlign.center, style: AppTextStyles.optionSubtitle),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
          child: PillButton(label: 'Play all', icon: Icons.play_arrow_rounded, onPressed: onPlay),
        ),
        const SizedBox(height: 14),
        for (final item in items)
          TrackTile(item: item),
      ],
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.report});

  final WeeklyListeningReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      shrinkWrap: true,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDADFE6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
          child: Text(report.title, textAlign: TextAlign.center, style: AppTextStyles.sectionTitle),
        ),
        if (report.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Ui.gutter, 8, Ui.gutter, 0),
            child: Text(report.summary, textAlign: TextAlign.center, style: AppTextStyles.optionSubtitle),
          ),
        if (report.narrative.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Ui.gutter, 16, Ui.gutter, 0),
            child: Text(report.narrative, textAlign: TextAlign.center, style: AppTextStyles.description),
          ),
        if (report.highlights.isNotEmpty) ...[
          const SizedBox(height: 18),
          for (final highlight in report.highlights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Ui.gutter, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, color: AppColors.accentOrange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(highlight, style: AppTextStyles.optionTitle)),
                ],
              ),
            ),
        ],
      ],
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
