import 'package:flutter/material.dart';

import '../../domain/entities/video_download_info.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'format.dart';

/// A tappable row representing one downloadable muxed stream.
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
    final subtitle =
        '${option.container} · ${formatBytes(option.sizeBytes)}';
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: enabled ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.splashNavy,
          child: const Icon(Icons.download_for_offline_outlined,
              color: Colors.white, size: 22),
        ),
        title: Text(
          '${option.label} · Muxed (video + audio)',
          style: AppTextStyles.optionTitle,
        ),
        subtitle: Text(subtitle, style: AppTextStyles.optionSubtitle),
        trailing: const Icon(Icons.download_outlined,
            color: AppColors.accentOrange),
      ),
    );
  }
}
