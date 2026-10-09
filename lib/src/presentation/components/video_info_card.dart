import 'package:flutter/material.dart';

import '../../domain/entities/video_download_info.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'format.dart';

/// Thumbnail + title + author + duration for the fetched video.
class VideoInfoCard extends StatelessWidget {
  const VideoInfoCard({super.key, required this.info});

  final VideoDownloadInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            info.thumbnailUrl,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 180,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 180,
              color: AppColors.inputFill,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textGray),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.videoTitle,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.textGray),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        info.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.videoMeta,
                      ),
                    ),
                    if (info.duration != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.splashNavy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatDuration(info.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
