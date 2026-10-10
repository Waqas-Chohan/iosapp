import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/collection_sheets.dart';
import '../components/ui_kit.dart';

/// Opens a playlist / album. With [promptAdd] the song picker opens right
/// away (used after creating a new, empty collection).
void openPlaylist(
  BuildContext context,
  AppServices services,
  String collectionId, {
  bool promptAdd = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlaylistScreen(
        services: services,
        collectionId: collectionId,
        promptAdd: promptAdd,
      ),
    ),
  );
}

/// Spotify-like playlist page: big cover, Play / Shuffle, drag to reorder,
/// swipe to remove, add songs and recommendations from your library.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.services,
    required this.collectionId,
    this.promptAdd = false,
  });

  final AppServices services;
  final String collectionId;
  final bool promptAdd;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final ScrollController _scroll = ScrollController();
  bool _showTitle = false;

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 250;
      if (show != _showTitle) setState(() => _showTitle = show);
    });
    if (widget.promptAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && s.library.items.isNotEmpty) _addSongs();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _addSongs() async {
    final c = s.collections.byId(widget.collectionId);
    if (c == null) return;
    final ids = await showPickSongsSheet(
      context,
      s,
      exclude: c.itemIds.toSet(),
      title: 'Add to ${c.name}',
    );
    if (ids == null || ids.isEmpty) return;
    await s.collections.addItems(c.id, ids);
  }

  Future<void> _more(LibraryCollection c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add songs'),
              onTap: () => Navigator.of(ctx).pop('add'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: Icon(c.isAlbum
                  ? Icons.queue_music_rounded
                  : Icons.album_outlined),
              title: Text(c.isAlbum ? 'Make it a playlist' : 'Make it an album'),
              onTap: () => Navigator.of(ctx).pop('type'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.errorRed),
              title: Text('Delete ${c.type.toLowerCase()}',
                  style: const TextStyle(color: AppColors.errorRed)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'add':
        await _addSongs();
      case 'rename':
        await showRenameCollectionDialog(context, s, c);
      case 'type':
        await s.collections.setType(c.id,
            c.isAlbum ? LibraryCollection.playlist : LibraryCollection.album);
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Delete “${c.name}”?',
          message: 'Only the ${c.type.toLowerCase()} is deleted — '
              'the songs stay in your Library.',
        );
        if (!ok || !mounted) return;
        final navigator = Navigator.of(context);
        await s.collections.delete(c.id);
        navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s.libraryChanges, s.player]),
      builder: (context, _) {
        final c = s.collections.byId(widget.collectionId);
        if (c == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final items = s.collections.itemsOf(c, s.library.items);
        final inList = items.map((i) => i.id).toSet();
        final recommended =
            s.library.items.where((i) => !inList.contains(i.id)).take(5).toList();
        final playingHere =
            s.player.current != null && inList.contains(s.player.current!.id);

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.splashNavy,
                surfaceTintColor: AppColors.splashNavy,
                foregroundColor: Colors.white,
                title: AnimatedOpacity(
                  opacity: _showTitle ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text(c.name,
                      style: const TextStyle(
                          fontFamily: 'Sora',
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                ),
                actions: [
                  IconButton(
                    tooltip: 'More',
                    onPressed: () => _more(c),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _Header(
                  collection: c,
                  items: items,
                  playingHere: playingHere && s.player.isPlaying,
                  onPlay: () {
                    if (playingHere) {
                      s.player.toggle();
                    } else {
                      s.playAndOpen(context, items);
                    }
                  },
                  onShuffle: () => s.playAndOpen(context, items, shuffle: true),
                  onAdd: _addSongs,
                ),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: "Let's find something for your "
                        '${c.type.toLowerCase()}',
                    message: s.library.items.isEmpty
                        ? 'Download or import some music first.'
                        : 'Add songs and videos from your Library.',
                    actions: [
                      if (s.library.items.isNotEmpty)
                        PillButton(
                          label: 'Add songs',
                          icon: Icons.add_rounded,
                          onPressed: _addSongs,
                        ),
                    ],
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: items.length,
                  onReorderItem: (from, to) {
                    final ids = items.map((i) => i.id).toList();
                    final moved = ids.removeAt(from);
                    ids.insert(to, moved);
                    s.collections.setOrder(c.id, ids);
                  },
                  proxyDecorator: (child, _, _) => Material(
                    elevation: 6,
                    color: Colors.white,
                    shadowColor: Colors.black26,
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey('${c.id}/${item.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.errorRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.remove_circle_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) {
                        s.collections.removeItem(c.id, item.id);
                        Ui.snack(context, 'Removed from ${c.name}',
                            action: 'Undo', onAction: () {
                          final ids = items.map((e) => e.id).toList();
                          s.collections.setOrder(c.id, ids);
                        });
                      },
                      child: Material(
                        color: Colors.white,
                        child: TrackTile(
                          item: item,
                          isPlaying: s.player.current?.id == item.id,
                          onTap: () => s.playAndOpen(context, items, index: i),
                          onMore: () => showTrackActions(context, s, item,
                              collection: c, queue: items),
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: AppColors.textGray),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (recommended.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Recommended',
                    subtitle: 'From your Library',
                  ),
                ),
                SliverList.builder(
                  itemCount: recommended.length,
                  itemBuilder: (context, i) {
                    final item = recommended[i];
                    return TrackTile(
                      item: item,
                      onTap: () => s.playAndOpen(context, recommended, index: i),
                      trailing: IconButton(
                        tooltip: 'Add',
                        onPressed: () =>
                            s.collections.addItems(c.id, [item.id]),
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            color: AppColors.splashNavy),
                      ),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.collection,
    required this.items,
    required this.playingHere,
    required this.onPlay,
    required this.onShuffle,
    required this.onAdd,
  });

  final LibraryCollection collection;
  final List<LibraryItem> items;
  final bool playingHere;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.splashNavy, AppColors.splashBlue],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Ui.gutter, 8, Ui.gutter, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(c.isAlbum ? 110 : 14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: CollectionCover(
                  items: items,
                  size: 210,
                  isAlbum: c.isAlbum,
                  borderRadius: c.isAlbum ? 105 : 14,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              c.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Ui.collectionMeta(c, items.length, Ui.totalDuration(items)),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _GhostButton(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onTap: onAdd,
                ),
                const SizedBox(width: 8),
                _GhostButton(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  onTap: items.isEmpty ? null : onShuffle,
                ),
                const Spacer(),
                Material(
                  color: AppColors.accentOrange,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: AppColors.accentOrange.withValues(alpha: 0.5),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: items.isEmpty ? null : onPlay,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Icon(
                        playingHere
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.splashNavy,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: AppTextStyles.optionSubtitle
            .copyWith(fontWeight: FontWeight.w600, color: AppColors.splashNavy),
      ),
    );
  }
}
