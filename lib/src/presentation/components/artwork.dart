import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/library_item.dart';
import 'app_colors.dart';

/// Artwork thumb: local file, fallback network URL, or a gradient icon.
///
/// Pass [width]/[height] for non-square art; [zoom] crops the letterbox
/// bars of YouTube's 4:3 `hqdefault` thumbnails.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.thumbnailPath,
    this.size = 56,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.zoom = 1.0,
    this.icon = Icons.music_note,
  });

  /// Square artwork for a library item (auto-crops YouTube letterboxing).
  factory Artwork.item(
    LibraryItem item, {
    Key? key,
    double size = 56,
    double? width,
    double? height,
    double borderRadius = 8,
  }) {
    final w = width ?? size;
    final h = height ?? size;
    return Artwork(
      key: key,
      thumbnailPath: item.thumbnailPath,
      size: size,
      width: width,
      height: height,
      borderRadius: borderRadius,
      zoom: item.isImported ? 1.0 : letterboxZoom(w / h),
      icon: item.isVideo ? Icons.movie_outlined : Icons.music_note,
    );
  }

  /// YouTube `hqdefault` thumbnails are 4:3 with a 16:9 picture inside.
  /// Returns the zoom that hides the black bars in a box of [aspect].
  static double letterboxZoom(double aspect) {
    if (aspect < 4 / 3) return 4 / 3;
    if (aspect < 16 / 9) return 16 / (9 * aspect);
    return 1.0;
  }

  final String thumbnailPath;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final double zoom;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = _IconFallback(icon: icon);
    Widget image;
    if (thumbnailPath.isEmpty) {
      image = fallback;
    } else if (!thumbnailPath.startsWith('http') &&
        File(thumbnailPath).existsSync()) {
      image = Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (thumbnailPath.startsWith('http')) {
      image = Image.network(
        thumbnailPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    if (zoom != 1.0 && image is Image) {
      image = Transform.scale(scale: zoom, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width ?? size,
        height: height ?? size,
        child: image,
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.splashBlue, AppColors.splashNavy],
        ),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) => Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.85),
            size: (c.biggest.shortestSide * 0.42).clamp(16.0, 64.0),
          ),
        ),
      ),
    );
  }
}
