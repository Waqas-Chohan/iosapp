import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../../domain/entities/download_task.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/artwork.dart';
import '../components/collection_sheets.dart';
import '../components/format.dart';
import '../components/ui_kit.dart';

/// Pushes the Downloads screen on top of the current route.
void openDownloads(BuildContext context, AppServices services) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DownloadsScreen(services: services),
    ),
  );
}

/// Download queue: progress, pause / resume / cancel / retry per item,
/// and the recently finished downloads.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, required this.services, this.onSearch});

  final AppServices services;

  /// Opens search (shown on the empty state).
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final downloads = services.downloads;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.splashNavy,
        title: const Text('Downloads', style: Ui.screenTitle),
        actions: [
          ListenableBuilder(
            listenable: downloads,
            builder: (context, _) {
              final canPause = downloads.tasks.any((t) => t.canPause);
              final canResume = downloads.tasks
                  .any((t) => t.state == DownloadState.paused);
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (v) {
                  switch (v) {
                    case 'pause':
                      downloads.pauseAll();
                    case 'resume':
                      downloads.resumeAll();
                    case 'clear':
                      downloads.clearFinished();
                    case 'photos':
                      Gal.open();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pause',
                    enabled: canPause,
                    child: const Text('Pause all'),
                  ),
                  PopupMenuItem(
                    value: 'resume',
                    enabled: canResume,
                    child: const Text('Resume all'),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    enabled: downloads.finished.isNotEmpty,
                    child: const Text('Clear finished'),
                  ),
                  const PopupMenuItem(
                    value: 'photos',
                    child: Text('Open Photos app'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: downloads,
        builder: (context, _) {
          final active = downloads.active;
          final done = downloads.finished;
          if (active.isEmpty && done.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.download_rounded,
                title: 'No downloads yet',
                message: 'Search for a song or video, tap the download '
                    'button and choose a quality. It shows up here.',
                actions: [
                  if (onSearch != null)
                    PillButton(
                      label: 'Search YouTube',
                      icon: Icons.search_rounded,
                      onPressed: onSearch,
                    ),
                ],
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.only(
              bottom: 32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (active.isNotEmpty) ...[
                SectionHeader(
                  title: 'In progress',
                  subtitle: _summary(active),
                ),
                for (final t in active)
                  _ActiveTile(task: t, services: services),
              ],
              if (done.isNotEmpty) ...[
                SectionHeader(
                  title: 'Finished',
                  subtitle: '${done.length} in your Library',
                  action: 'Clear',
                  onAction: downloads.clearFinished,
                ),
                for (final t in done) _DoneTile(task: t, services: services),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _summary(List<DownloadTask> tasks) {
    final running =
        tasks.where((t) => t.state == DownloadState.downloading).length;
    final paused = tasks.where((t) => t.state == DownloadState.paused).length;
    final failed = tasks.where((t) => t.state == DownloadState.failed).length;
    return [
      if (running > 0) '$running downloading',
      if (tasks.any((t) => t.state == DownloadState.queued))
        '${tasks.where((t) => t.state == DownloadState.queued).length} queued',
      if (paused > 0) '$paused paused',
      if (failed > 0) '$failed failed',
    ].join(' · ');
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Artwork(
          thumbnailPath: task.thumbnailUrl,
          width: 96,
          height: 54,
          borderRadius: 10,
          icon: task.isVideo ? Icons.movie_outlined : Icons.music_note,
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              task.option.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.task, required this.services});

  final DownloadTask task;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final downloads = services.downloads;
    final (status, color) = switch (t.state) {
      DownloadState.queued => ('Waiting…', AppColors.textGray),
      DownloadState.downloading => (_rate(t), AppColors.accentOrange),
      DownloadState.paused => ('Paused', AppColors.textGray),
      DownloadState.processing => (
          t.option.needsMerge ? 'Merging video & audio…' : 'Finishing…',
          AppColors.splashBlue
        ),
      DownloadState.failed => (t.error ?? 'Failed', AppColors.errorRed),
      DownloadState.completed => ('Done', AppColors.textGray),
    };
    final sizes = t.total > 0
        ? '${formatBytes(t.received)} of ${formatBytes(t.total)}'
        : (t.received > 0 ? formatBytes(t.received) : '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.gutter, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(task: t),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.optionTitle
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: t.state == DownloadState.processing ||
                            (t.state == DownloadState.queued && t.received == 0)
                        ? null
                        : (t.progress ?? 0),
                    color: color,
                    backgroundColor: const Color(0xFFEDEFF2),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.optionSubtitle
                            .copyWith(fontSize: 12, color: color),
                      ),
                    ),
                    if (sizes.isNotEmpty)
                      Text(sizes,
                          style: AppTextStyles.optionSubtitle
                              .copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (t.canPause)
            _RoundAction(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              onTap: () => downloads.pause(t.id),
            )
          else if (t.canResume)
            _RoundAction(
              icon: t.state == DownloadState.failed
                  ? Icons.refresh_rounded
                  : Icons.play_arrow_rounded,
              tooltip: t.state == DownloadState.failed ? 'Retry' : 'Resume',
              filled: true,
              onTap: () => downloads.resume(t.id),
            ),
          if (t.state != DownloadState.processing)
            _RoundAction(
              icon: Icons.close_rounded,
              tooltip: 'Cancel',
              onTap: () async {
                final ok = await confirmAction(
                  context,
                  title: 'Cancel download?',
                  message: 'The partly downloaded data will be deleted.',
                  confirm: 'Cancel download',
                );
                if (ok) await downloads.cancel(t.id);
              },
            ),
        ],
      ),
    );
  }

  static String _rate(DownloadTask t) {
    if (t.speed <= 0) return 'Starting…';
    final eta = t.eta;
    final speed = '${formatBytes(t.speed.round())}/s';
    if (eta == null) return speed;
    final left = eta.inMinutes >= 1
        ? '${eta.inMinutes} min ${eta.inSeconds % 60} s left'
        : '${eta.inSeconds} s left';
    return '$speed · $left';
  }
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.task, required this.services});

  final DownloadTask task;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final item = t.libraryItemId == null
        ? null
        : services.library.byId(t.libraryItemId!);
    final photos = !t.isVideo
        ? 'In Library & Files'
        : t.savedToPhotos
            ? 'Saved to Photos'
            : (t.photosError != null ? 'Not in Photos' : 'Saving to Photos…');
    return InkWell(
      onTap: item == null
          ? null
          : () => services.playAndOpen(context, [item]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Ui.gutter, 8, 8, 8),
        child: Row(
          children: [
            _Thumb(task: t),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.optionTitle
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        t.isVideo && !t.savedToPhotos
                            ? Icons.photo_library_outlined
                            : Icons.check_circle_rounded,
                        size: 14,
                        color: t.isVideo && !t.savedToPhotos
                            ? AppColors.textGray
                            : const Color(0xFF2E9E5B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$photos · ${formatBytes(t.total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.optionSubtitle
                              .copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (t.isVideo && !t.savedToPhotos && t.photosError != null)
              _RoundAction(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: 'Save to Photos',
                onTap: () async {
                  try {
                    await services.downloads.saveToPhotos(t.id);
                  } catch (e) {
                    if (context.mounted) Ui.snack(context, '$e');
                  }
                },
              ),
            if (item != null)
              _RoundAction(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Play',
                filled: true,
                onTap: () => services.playAndOpen(context, [item]),
              ),
            _RoundAction(
              icon: Icons.close_rounded,
              tooltip: 'Remove from list',
              onTap: () => services.downloads.dismiss(t.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.accentOrange : AppColors.inputFill,
        ),
        child: Icon(icon,
            size: 20, color: filled ? Colors.white : AppColors.splashNavy),
      ),
    );
  }
}
