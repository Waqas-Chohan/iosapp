import 'package:flutter/material.dart';

import '../../domain/entities/video_download_info.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'format.dart';

/// A tappable row representing one downloadable stream.
class StreamOptionTile extends StatelessWidget {
  const StreamOptionTile({
    super.key,
    required this.option,
    this.onTap,
    this.enabled = true,
  });

  final StreamOption option;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final size = option.sizeBytes != null
        ? formatBytes(option.sizeBytes)
        : (option.isFragmentBased ? 'streaming assembly' : null);
    final subtitle = [
      option.container,
      size,
      if (option.isFragmentBased) 'HLS',
    ].whereType<String>().join(' · ');

    final (IconData icon, Color color) = switch (option.category) {
      StreamCategory.muxed => (
          Icons.download_for_offline_outlined,
          AppColors.accentOrange,
        ),
      StreamCategory.audio => (
          Icons.library_music_outlined,
          AppColors.splashBlue,
        ),
      StreamCategory.videoOnly => (
          Icons.videocam_outlined,
          AppColors.splashNavy,
        ),
    };

    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: enabled ? onTap : null,
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 22)),
        title: Text('${option.label} · ${option.container}', style: AppTextStyles.optionTitle),
        subtitle: Text(subtitle, style: AppTextStyles.optionSubtitle),
        trailing: const Icon(Icons.download_outlined, color: AppColors.accentOrange),
      ),
    );
  }
}

