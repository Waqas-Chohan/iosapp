import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Native in-app preview of the downloaded file using `video_player`.
Future<void> showVideoPreview(BuildContext context, String filePath) async {
  final controller = VideoPlayerController.file(File(filePath));
  await controller.initialize();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PreviewDialog(controller: controller),
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _controller.value.aspectRatio;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: aspect > 0 ? aspect : 16 / 9,
            child: VideoPlayer(_controller),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.replay),
                onPressed: () => _controller.seekTo(Duration.zero),
              ),
              IconButton(
                icon: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                ),
                iconSize: 44,
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
