import 'package:flutter/material.dart';

import '../../domain/entities/download_task.dart';
import '../../domain/entities/video_download_info.dart';
import '../controllers/download_manager.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'format.dart';

/// Bottom sheet listing every downloadable quality for one video.
/// Returns the queued task (or null when dismissed).
Future<DownloadTask?> showDownloadOptions(
  BuildContext context, {
  required DownloadManager downloads,
  required String videoId,
  required String title,
  required String author,
  required String thumbnailUrl,
  Duration? duration,
}) {
  return showModalBottomSheet<DownloadTask>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _DownloadOptionsSheet(
      downloads: downloads,
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
    ),
  );
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({
    required this.downloads,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
  });

  final DownloadManager downloads;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  late Future<VideoDownloadInfo> _future = widget.downloads.fetchInfo(widget.videoId);

  void _retry() => setState(() {
        _future = widget.downloads.fetchInfo(widget.videoId);
      });

  void _pick(VideoDownloadInfo info, StreamOption option) {
    final task = widget.downloads.enqueue(info, option);
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<VideoDownloadInfo>(
        future: _future,
        builder: (context, snap) {
          final children = <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDADFE6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _Header(
              title: snap.data?.title ?? widget.title,
              author: snap.data?.author ?? widget.author,
              thumbnailUrl: widget.thumbnailUrl,
              duration: snap.data?.duration ?? widget.duration,
            ),
            const SizedBox(height: 8),
          ];

          if (snap.connectionState != ConnectionState.done) {
            children.addAll(const [
              SizedBox(height: 40),
              Center(
                child: CircularProgressIndicator(color: AppColors.accentOrange),
              ),
              SizedBox(height: 14),
              Center(
                child: Text('Finding every available quality…',
                    style: AppTextStyles.description),
              ),
            ]);
          } else if (snap.hasError || snap.data == null) {
            final msg = '${snap.error}';
            children.addAll([
              const SizedBox(height: 30),
              const Icon(Icons.cloud_off_rounded,
                  size: 46, color: AppColors.textGray),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  msg.contains('RequestLimitExceeded')
                      ? 'YouTube is rate-limiting right now. Wait a minute, '
                          'or switch between Wi-Fi and mobile data.'
                      : 'Could not load the formats for this video.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.description,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: FilledButton.icon(
                  onPressed: _retry,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentOrange),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
            ]);
          } else {
            final info = snap.data!;
            final video = info.video;
            final audio = info.audio;
            final busy = widget.downloads.tasks
                .where((t) => t.videoId == info.videoId && !t.isFinished)
                .map((t) => t.option.tag)
                .toSet();
            if (video.isNotEmpty) {
              children.add(const _SectionLabel(
                icon: Icons.movie_outlined,
                text: 'Video',
                note: 'Saved to Photos › Muz and your Library',
              ));
              for (final o in video) {
                children.add(_OptionTile(
                  option: o,
                  busy: busy.contains(o.tag),
                  onTap: () => _pick(info, o),
                ));
              }
            }
            if (audio.isNotEmpty) {
              children.add(const _SectionLabel(
                icon: Icons.graphic_eq_rounded,
                text: 'Audio only',
                note: 'Kept in your Library and the Files app',
              ));
              for (final o in audio) {
                children.add(_OptionTile(
                  option: o,
                  busy: busy.contains(o.tag),
                  onTap: () => _pick(info, o),
                ));
              }
            }
            if (video.isEmpty && audio.isEmpty) {
              children.add(const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No downloadable formats were found for this video.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.description,
                ),
              ));
            }
            children.add(const SizedBox(height: 24));
          }
          return ListView(controller: scroll, children: children);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
  });

  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 128,
              height: 72,
              child: thumbnailUrl.isEmpty
                  ? const ColoredBox(color: AppColors.inputFill)
                  : Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.inputFill),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle),
                const SizedBox(height: 2),
                Text(
                  [author, if (duration != null) formatDuration(duration)]
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.videoMeta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.text,
    required this.note,
  });

  final IconData icon;
  final String text;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accentOrange),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.sectionTitle.copyWith(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyles.optionSubtitle.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.busy,
    required this.onTap,
  });

  final StreamOption option;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final details = <String>[
      o.isVideo ? 'MP4' : 'M4A · AAC',
      if (o.isVideo && (o.fps ?? 0) > 30) '${o.fps} fps',
      if (o.needsMerge) 'HQ audio',
      formatBytes(o.totalBytes),
    ].where((s) => s != '—').join(' · ');
    final badge = o.qualityBadge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    o.label,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.splashNavy,
                    ),
                  ),
                ),
                if (badge.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionSubtitle),
                ),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('Queued',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textGray)),
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download_rounded,
                            color: Colors.white, size: 20),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
