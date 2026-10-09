import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import 'app_colors.dart';
import 'artwork.dart';
import 'app_text_styles.dart';

/// Spotify-style mini player shown above the navigation bar.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.player, required this.onTap});

  final PlayerController player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderOnForeground: false,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Artwork(thumbnailPath: player.current?.thumbnailPath ?? '', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.current?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionTitle,
                    ),
                    Text(
                      player.current?.author ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionSubtitle,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: player.toggle,
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: AppColors.accentOrange,
                  size: 40,
                ),
              ),
              IconButton(
                onPressed: player.next,
                icon: const Icon(Icons.skip_next, color: AppColors.splashNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
