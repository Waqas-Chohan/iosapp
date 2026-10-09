import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../components/app_colors.dart';
import '../components/artwork.dart';
import '../controllers/player_controller.dart';

/// Full-screen, Spotify-style player for the local queue.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.player});

  final PlayerController player;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double _dragProgressMs = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F24),
      body: ListenableBuilder(
        listenable: widget.player,
        builder: (context, _) {
          final current = widget.player.current;
          if (current == null) {
            return const Center(
              child: Text('Nothing playing',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          final vc = widget.player.videoController;
          final durationMs = widget.player.duration.inMilliseconds.toDouble();
          final progressMs = _dragProgressMs >= 0
              ? _dragProgressMs
              : widget.player.position.inMilliseconds.toDouble();
          final maxMs = durationMs > 0 ? durationMs : 1.0;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'NOW PLAYING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: current.isVideo
                          ? _VideoSurface(videoController: vc)
                          : Artwork(
                              thumbnailPath: current.thumbnailPath,
                              size: 300,
                              borderRadius: 20,
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    current.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${current.qualityLabel} · ${current.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: AppColors.accentOrange,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.accentOrange,
                      overlayColor:
                          AppColors.accentOrange.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      max: maxMs,
                      value: (progressMs.clamp(0, maxMs)).toDouble(),
                      onChanged: (v) => setState(() => _dragProgressMs = v),
                      onChangeEnd: (v) {
                        setState(() => _dragProgressMs = -1);
                        widget.player.seek(Duration(milliseconds: v.round()));
                      },
                    ),
                  ),
                  _TimeRow(player: widget.player, progressMs: progressMs),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: widget.player.previous,
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white, size: 36),
                      ),
                      IconButton(
                        onPressed: widget.player.toggle,
                        icon: Icon(
                          widget.player.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: AppColors.accentOrange,
                          size: 72,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        onPressed: widget.player.next,
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white, size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.videoController});

  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final vc = videoController;
    if (vc == null || !vc.value.isInitialized) {
      return const CircularProgressIndicator(color: AppColors.accentOrange);
    }
    final aspect = vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(vc)),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.player, required this.progressMs});

  final PlayerController player;
  final double progressMs;

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_fmt(progressMs),
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(_fmt(player.duration.inMilliseconds.toDouble()),
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}
