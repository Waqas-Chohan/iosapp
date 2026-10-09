import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/video_download_info.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/artwork.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'player_screen.dart';

/// Spotify-style Library: all downloaded tracks/videos, play + manage.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.player,
    required this.libraryModel,
    this.collections = const [],
  });

  final PlayerController player;
  final LibraryModel libraryModel;
  final List<LibraryCollection> collections;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Your Library',
          style: TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.splashNavy,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.libraryModel,
        builder: (context, _) {
          if (!widget.libraryModel.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = widget.libraryModel.items;
          final filtered = _searchController.text.trim().isEmpty
              ? items
              : items.where((item) {
                  final q = _searchController.text.trim().toLowerCase();
                  final haystack =
                      '${item.title} ${item.author} ${item.qualityLabel}'.toLowerCase();
                  return haystack.contains(q);
                }).toList();

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.library_music_outlined,
                        size: 64, color: AppColors.textGray),
                    SizedBox(height: 12),
                    Text(
                      'Your Library is empty.\n'
                      'Download a video from Home and it lands here.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.description,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search your music',
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: AppColors.splashNavy),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.collections.isNotEmpty) ...[
                const Text('My Collections', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.collections.map((collection) {
                    return Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6E6E6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            collection.type == 'Album'
                                ? Icons.album_outlined
                                : Icons.playlist_play,
                            color: AppColors.accentOrange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            collection.name,
                            style: AppTextStyles.optionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${collection.type} · ${collection.itemIds.length} songs',
                            style: AppTextStyles.optionSubtitle,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],
              const Text('All songs', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No tracks match your search.',
                      style: AppTextStyles.description,
                    ),
                  ),
                )
              else
                ...filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LibraryTile(
                      item: item,
                      onTap: () {
                        widget.player.playQueue(filtered, startIndex: index);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlayerScreen(player: widget.player),
                          ),
                        );
                      },
                      onDelete: () => widget.libraryModel.remove(item.id),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tag = switch (item.category) {
      StreamCategory.muxed => 'VIDEO',
      StreamCategory.audio => 'AUDIO',
      StreamCategory.videoOnly => 'VIDEO ONLY',
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Artwork(
                thumbnailPath: item.thumbnailPath,
                size: 56,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$tag · ${item.qualityLabel} · ${item.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionSubtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Remove from Library',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
