import 'package:flutter/material.dart';

import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/ui_kit.dart';

/// Browse-by-artist screen: every artist in your library, favorite artists
/// pinned at the top, a search filter, and a per-artist favorite toggle.
class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

/// An artist grouped from the library with their (song) tracks.
typedef _ArtistGroup = ({String artist, List<LibraryItem> items});

class _ArtistsScreenState extends State<ArtistsScreen> {
  String _query = '';

  /// Groups library songs (non-videos) by author, ordered by track count.
  List<_ArtistGroup> _group(List<LibraryItem> all) {
    final map = <String, List<LibraryItem>>{};
    for (final item in all.where((i) => !i.isVideo)) {
      map.putIfAbsent(item.author, () => <LibraryItem>[]).add(item);
    }
    final groups =
        map.entries.map((e) => (artist: e.key, items: e.value)).toList()
          ..sort((a, b) => b.items.length.compareTo(a.items.length));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Browse by artist', style: Ui.screenTitle),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: s.libraryChanges,
        builder: (context, _) {
          final all = _group(s.library.items);
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.person_search_rounded,
              title: 'No artists yet',
              message: 'Download some songs and the artists will appear here, '
                  'ready to favorite.',
            );
          }

          final favorites = s.favorites.artists;
          final favoriteGroups = [
            for (final name in favorites)
              if (all.any((g) =>
                  g.artist.trim().toLowerCase() == name.trim().toLowerCase()))
                all.firstWhere((g) =>
                    g.artist.trim().toLowerCase() ==
                    name.trim().toLowerCase()),
          ];

          final query = _query.trim().toLowerCase();
          final otherGroups = all
              .where((g) =>
                  !favoriteGroups.any((f) => f.artist == g.artist) &&
                  (query.isEmpty || g.artist.toLowerCase().contains(query)))
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _SearchField(
                onChanged: (v) => setState(() => _query = v),
              )),

              if (favoriteGroups.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Favorites',
                    subtitle: 'Your starred artists, newest first',
                  ),
                ),
                SliverList.builder(
                  itemCount: favoriteGroups.length,
                  itemBuilder: (context, i) => _ArtistTile(
                    group: favoriteGroups[i],
                    isFavorite: true,
                    services: s,
                    onToggleFavorite: () =>
                        s.favorites.toggle(favoriteGroups[i].artist),
                    onTap: () => _openArtist(context, s, favoriteGroups[i]),
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: SectionHeader(
                  title: query.isEmpty ? 'All artists' : 'Results',
                  subtitle: '${otherGroups.length} artist'
                      '${otherGroups.length == 1 ? '' : 's'}',
                ),
              ),
              if (otherGroups.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Ui.gutter, 8, Ui.gutter, 20),
                    child: Text('No artists match your search.',
                        style: AppTextStyles.optionSubtitle),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: otherGroups.length,
                  itemBuilder: (context, i) => _ArtistTile(
                    group: otherGroups[i],
                    isFavorite: false,
                    services: s,
                    onToggleFavorite: () =>
                        s.favorites.toggle(otherGroups[i].artist),
                    onTap: () => _openArtist(context, s, otherGroups[i]),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(
                    height: 28 + MediaQuery.paddingOf(context).bottom),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openArtist(BuildContext context, AppServices s, _ArtistGroup group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ArtistSongsSheet(services: s, group: group),
    );
  }
}


class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.gutter, 4, Ui.gutter, 0),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.inputText,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.inputFill,
          hintText: 'Search your artists',
          hintStyle: AppTextStyles.inputHint,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.accentOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({
    required this.group,
    required this.isFavorite,
    required this.services,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final _ArtistGroup group;
  final bool isFavorite;
  final AppServices services;
  final Future<void> Function() onToggleFavorite;
  final VoidCallback onTap;

  String get _initials {
    final parts = group.artist.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
      leading: SizedBox(
        width: 52,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: FutureBuilder<String?>(
            future: services.ai.artistArtworkUrl(group.artist),
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url != null && url.isNotEmpty) {
                return Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _Initials(_initials));
              }
              return _Initials(_initials);
            },
          ),
        ),
      ),
      title: Text(group.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.optionTitle),
      subtitle: Text(
        '${group.items.length} song${group.items.length == 1 ? '' : 's'}',
        style: AppTextStyles.optionSubtitle,
      ),
      trailing: IconButton(
        tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? AppColors.accentOrange : AppColors.textGray,
        ),
        onPressed: onToggleFavorite,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Ui.brandGradient.colors.first,
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          )),
    );
  }
}


class _ArtistSongsSheet extends StatelessWidget {
  const _ArtistSongsSheet({required this.services, required this.group});

  final AppServices services;
  final _ArtistGroup group;

  @override
  Widget build(BuildContext context) {
    final isFavorite = services.favorites.isFavorite(group.artist);
    final songs = group.items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      shrinkWrap: true,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
          decoration: const BoxDecoration(
            gradient: Ui.brandGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
                child: Text(
                  group.artist,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.sectionTitle.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${songs.length} song${songs.length == 1 ? '' : 's'}',
                style: AppTextStyles.optionSubtitle
                    .copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Play all',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {
                          Navigator.of(context).pop();
                          services.playAndOpen(context, songs);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PillButton(
                        label: 'Shuffle',
                        icon: Icons.shuffle_rounded,
                        outlined: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          services.playAndOpen(context, songs, shuffle: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => services.favorites.toggle(group.artist),
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  isFavorite ? 'Remove favorite' : 'Add to favorites',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < songs.length; i++)
          TrackTile(
            item: songs[i],
            onTap: () {
              Navigator.of(context).pop();
              services.playAndOpen(context, songs, index: i);
            },
          ),
      ],
    );
  }
}
