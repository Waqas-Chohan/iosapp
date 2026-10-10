import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'artwork.dart';
import 'format.dart';

/// Shared building blocks for the premium look (Home, Library, playlists).
abstract final class Ui {
  static const double gutter = 20;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.splashNavy, AppColors.splashBlue],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A2B), AppColors.accentOrange],
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: 'Sora',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: AppColors.splashNavy,
  );

  static List<BoxShadow> softShadow([double opacity = 0.10]) => [
        BoxShadow(
          color: AppColors.splashNavy.withValues(alpha: opacity),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static String itemMeta(LibraryItem item) {
    final parts = <String>[
      item.author,
      if (item.qualityLabel.isNotEmpty) item.qualityLabel,
      if (item.duration != null) formatDuration(item.duration),
    ];
    return parts.join(' · ');
  }

  static String collectionMeta(LibraryCollection c, int count, Duration total) {
    final songs = count == 1 ? '1 item' : '$count items';
    if (total.inSeconds <= 0) return '${c.type} · $songs';
    final mins = total.inMinutes;
    final length = mins >= 60 ? '${mins ~/ 60} h ${mins % 60} min' : '$mins min';
    return '${c.type} · $songs · $length';
  }

  static Duration totalDuration(Iterable<LibraryItem> items) => Duration(
        seconds: items.fold<int>(0, (s, i) => s + (i.durationSeconds ?? 0)),
      );

  static void snack(BuildContext context, String text,
      {String? action, VoidCallback? onAction}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: action == null
            ? null
            : SnackBarAction(
                label: action,
                textColor: AppColors.accentOrange,
                onPressed: onAction ?? () {},
              ),
      ),
    );
  }
}

/// "Title ........ See all" row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.gutter, 26, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 19)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: AppTextStyles.optionSubtitle),
                  ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentOrange,
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Spotify-like cover: a 2×2 artwork mosaic, one big artwork, or a
/// gradient with an icon for empty collections.
class CollectionCover extends StatelessWidget {
  const CollectionCover({
    super.key,
    required this.items,
    required this.size,
    this.isAlbum = false,
    this.borderRadius = 12,
  });

  final List<LibraryItem> items;
  final double size;
  final bool isAlbum;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (items.isEmpty) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          gradient: isAlbum ? Ui.accentGradient : Ui.brandGradient,
        ),
        child: Center(
          child: Icon(
            isAlbum ? Icons.album_rounded : Icons.queue_music_rounded,
            size: size * 0.4,
            color: Colors.white,
          ),
        ),
      );
    } else if (items.length < 4) {
      child = Artwork.item(items.first, size: size, borderRadius: 0);
    } else {
      final half = size / 2;
      child = Column(
        children: [
          Row(children: [
            Artwork.item(items[0], size: half, borderRadius: 0),
            Artwork.item(items[1], size: half, borderRadius: 0),
          ]),
          Row(children: [
            Artwork.item(items[2], size: half, borderRadius: 0),
            Artwork.item(items[3], size: half, borderRadius: 0),
          ]),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Standard track row used by Library, playlists and pickers.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.item,
    this.onTap,
    this.onMore,
    this.trailing,
    this.isPlaying = false,
    this.index,
  });

  final LibraryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? trailing;
  final bool isPlaying;
  final int? index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ui.gutter, vertical: 7),
        child: Row(
          children: [
            Stack(
              children: [
                Artwork.item(item, size: 54, borderRadius: 10),
                if (item.isVideo)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.optionTitle.copyWith(
                      color: isPlaying
                          ? AppColors.accentOrange
                          : AppColors.splashNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _Badge(item.isVideo ? 'VIDEO' : 'AUDIO'),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          Ui.itemMeta(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.optionSubtitle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ?trailing,
            if (onMore != null)
              IconButton(
                onPressed: onMore,
                tooltip: 'More',
                icon: const Icon(Icons.more_vert, color: AppColors.textGray),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.textGray,
        ),
      ),
    );
  }
}

/// Rounded empty state with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentOrange.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 40, color: AppColors.accentOrange),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.description),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

/// Primary pill button in the brand orange.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
    const text = TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final child = Text(label);
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? null : Icon(icon, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.splashNavy,
          side: const BorderSide(color: Color(0xFFDADFE6)),
          shape: shape,
          padding: padding,
          textStyle: text,
        ),
        label: child,
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon, size: 18),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        shape: shape,
        padding: padding,
        textStyle: text,
      ),
      label: child,
    );
  }
}
