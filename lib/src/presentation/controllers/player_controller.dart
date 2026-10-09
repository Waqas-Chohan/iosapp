import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/library_item.dart';

/// Spotify-style queue + playback engine over local files.
///
/// Uses `video_player`/AVPlayer for both videos (muxed) and audio tracks.
class PlayerController extends ChangeNotifier {
  VideoPlayerController? _videoController;
  List<LibraryItem> playlist = [];
  int _index = -1;
  bool _advancing = false;

  LibraryItem? get current =>
      (_index >= 0 && _index < playlist.length) ? playlist[_index] : null;

  VideoPlayerController? get videoController => _videoController;
  bool get isPlaying => _videoController?.value.isPlaying ?? false;
  bool get isBuffering => _videoController?.value.isBuffering ?? false;
  Duration get position => _videoController?.value.position ?? Duration.zero;
  Duration get duration => _videoController?.value.duration ?? Duration.zero;

  /// Plays [items] as a queue starting at [startIndex].
  Future<void> playQueue(List<LibraryItem> items, {int startIndex = 0}) async {
    if (items.isEmpty) return;
    playlist
      ..clear()
      ..addAll(items);
    await _load(startIndex.clamp(0, items.length - 1));
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= playlist.length) return;
    await _load(index);
    notifyListeners();
  }

  Future<void> _load(int index) async {
    _index = index;
    final old = _videoController;
    old?.removeListener(_onValueChanged);
    await old?.dispose();

    final item = current;
    if (item == null) return;
    final controller = VideoPlayerController.file(File(item.filePath));
    await controller.initialize();
    controller.setLooping(false);
    controller.addListener(_onValueChanged);
    _videoController = controller;
    await controller.play();
  }

  void _onValueChanged() {
    final vc = _videoController;
    if (vc == null || _advancing) return;
    if (vc.value.isCompleted &&
        vc.value.duration > Duration.zero &&
        vc.value.position >= vc.value.duration) {
      _advancing = true;
      next();
      _advancing = false;
      return;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    final vc = _videoController;
    if (vc == null) return;
    vc.value.isPlaying ? await vc.pause() : await vc.play();
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    await _videoController?.seekTo(target);
    notifyListeners();
  }

  Future<void> next() async {
    if (_index < playlist.length - 1) {
      await _load(_index + 1);
    } else {
      await _videoController?.pause();
    }
    notifyListeners();
  }

  Future<void> previous() async {
    if (_index > 0) {
      await _load(_index - 1);
    } else {
      await _videoController?.seekTo(Duration.zero);
    }
    notifyListeners();
  }

  void stop() {
    final vc = _videoController;
    vc?.removeListener(_onValueChanged);
    _videoController = null;
    vc?.dispose();
    _index = -1;
    playlist = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
