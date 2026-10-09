import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Live progress + speed + cancel during an active download.
class DownloadProgressPanel extends StatelessWidget {
  const DownloadProgressPanel({
    super.key,
    required this.progress,
    required this.totalLabel,
    required this.speedLabel,
    required this.onCancel,
  });

  final double? progress;
  final String totalLabel;
  final String speedLabel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percentLabel = progress == null
        ? '—'
        : '${(progress!.clamp(0, 1) * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.downloading,
                  color: AppColors.accentOrange, size: 22),
              const SizedBox(width: 8),
              Text('Downloading…', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text(percentLabel, style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.inputFill,
              valueColor: const AlwaysStoppedAnimation(
                  AppColors.accentOrange),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(totalLabel, style: AppTextStyles.optionSubtitle),
              ),
              Text(speedLabel, style: AppTextStyles.optionSubtitle),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.splashNavy,
                side: const BorderSide(color: AppColors.splashNavy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
