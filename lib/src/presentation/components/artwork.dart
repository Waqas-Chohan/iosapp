import 'dart:io';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Square artwork thumb: local file, fallback network URL, or icon.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.thumbnailPath,
    this.size = 56,
    this.borderRadius = 8,
  });

  final String thumbnailPath;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (thumbnailPath.isEmpty) {
      image = const _IconFallback();
    } else if (File(thumbnailPath).existsSync()) {
      image = Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _IconFallback(),
      );
    } else {
      image = Image.network(
        thumbnailPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _IconFallback(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.inputFill,
      child: Center(
        child: Icon(Icons.music_note, color: AppColors.textGray),
      ),
    );
  }
}
