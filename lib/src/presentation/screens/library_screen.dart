import 'package:flutter/material.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/entities/video_download_info.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/artwork.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'player_screen.dart';

/// Spotify-style Library: all downloaded tracks/videos, play + manage.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.player,
    required this.libraryModel,
  });

  final PlayerController player;
  final LibraryModel libraryModel;

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
        listenable: libraryModel,
        builder: (context, _) {
          if (!libraryModel.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = libraryModel.items;
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _LibraryTile(
              item: items[index],
              onTap: () {
                player.playQueue(items, startIndex: index);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerScreen(player: player),
                  ),
                );
              },
              onDelete: () => libraryModel.remove(items[index].id),
            ),
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
