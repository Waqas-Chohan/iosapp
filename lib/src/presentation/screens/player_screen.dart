import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Artwork(
                                  thumbnailPath: current.thumbnailPath,
                                  size: 300,
                                  borderRadius: 20,
                                ),
                                const SizedBox(height: 24),
                                const _EqualizerBars(),
                              ],
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: widget.player.cycleLoopMode,
                        icon: Icon(
                          widget.player.loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: widget.player.loopMode == LoopMode.off
                              ? Colors.white38
                              : AppColors.accentOrange,
                          size: 22,
                        ),
                        label: Text(
                          switch (widget.player.loopMode) {
                            LoopMode.off => 'Loop off',
                            LoopMode.all => 'Loop all',
                            LoopMode.one => 'Loop one',
                          },
                          style: TextStyle(
                            color: widget.player.loopMode == LoopMode.off
                                ? Colors.white38
                                : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.player.cycleSpeed,
                        icon: const Icon(Icons.speed,
                            color: Colors.white70, size: 22),
                        label: Text(
                          _speedLabel(widget.player.speed),
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.player.toggleBackgroundPlay,
                        icon: Icon(
                          widget.player.backgroundPlayEnabled
                              ? Icons.headset
                              : Icons.headset_off,
                          color: widget.player.backgroundPlayEnabled
                              ? AppColors.accentOrange
                              : Colors.white38,
                          size: 22,
                        ),
                        label: Text(
                          widget.player.backgroundPlayEnabled
                              ? 'Background on'
                              : 'Background off',
                          style: TextStyle(
                            color: widget.player.backgroundPlayEnabled
                                ? Colors.white70
                                : Colors.white38,
                            fontSize: 13,
                          ),
                        ),
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
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          AspectRatio(aspectRatio: aspect, child: VideoPlayer(vc)),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _openFullscreen(context, vc),
                tooltip: 'Fullscreen',
                icon: const Icon(Icons.fullscreen, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openFullscreen(
  BuildContext context,
  VideoPlayerController vc,
) async {
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenPage(videoController: vc),
    ),
  );
  if (context.mounted) {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({required this.videoController});

  final VideoPlayerController videoController;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.videoController.value.aspectRatio,
              child: VideoPlayer(widget.videoController),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
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

String _speedLabel(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.round()}x';
  }
  return '${speed}x';
}

/// Animated equalizer bars shown behind audio-only tracks (Spotify vibe).
class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars();

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final wave = sin((t * 2 * pi) + (i * 1.1));
            final height = 8 + ((wave + 1) / 2) * 22;
            return Container(
              width: 6,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
