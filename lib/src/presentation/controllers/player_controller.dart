import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/library_item.dart';

enum LoopMode { off, all, one }

/// Which engine is currently producing sound.
enum _Engine { none, audio, video }

/// Spotify-style queue + playback engine over local files.
///
/// Two engines work together:
/// - **just_audio** (with just_audio_background) plays audio tracks and is
///   the only engine used while the app is in the background. It publishes
///   the lock screen / Dynamic Island "Now Playing" card (title, artist,
///   artwork, progress) and answers play/pause/next/previous from there.
/// - **video_player** shows video items while the app is in the foreground.
///
/// When the app leaves the foreground while a video is playing, playback is
/// handed off to just_audio at the same position (iOS suspends video
/// rendering in the background), and handed back to the video when the app
/// returns.
class PlayerController extends ChangeNotifier with WidgetsBindingObserver {
  static const List<double> playbackSpeeds = [1.0, 1.25, 1.5, 2.0];

  /// Last created controller.
  static PlayerController? instance;

  PlayerController() {
    instance = this;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_listenForInterruptions());
  }

  ja.AudioPlayer? _audioPlayer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VideoPlayerController? _videoController;
  _Engine _engine = _Engine.none;
  bool _inBackground = false;
  bool _handingOff = false;
  DateTime _lastPositionTick = DateTime.fromMillisecondsSinceEpoch(0);

  List<LibraryItem> playlist = [];
  int _index = -1;
  bool _advancing = false;

  LoopMode loopMode = LoopMode.off;
  double speed = 1.0;
  bool backgroundPlayEnabled = true;

  LibraryItem? get current =>
      (_index >= 0 && _index < playlist.length) ? playlist[_index] : null;

  /// The video surface, only while a video is shown in the foreground.
  VideoPlayerController? get videoController =>
      _engine == _Engine.video ? _videoController : null;

  bool get isPlaying => switch (_engine) {
        _Engine.video => _videoController?.value.isPlaying ?? false,
        _Engine.audio => _audioPlayer?.playing ?? false,
        _Engine.none => false,
      };

  bool get isBuffering => switch (_engine) {
        _Engine.video => _videoController?.value.isBuffering ?? false,
        _Engine.audio =>
          _audioPlayer?.processingState == ja.ProcessingState.buffering ||
              _audioPlayer?.processingState == ja.ProcessingState.loading,
        _Engine.none => false,
      };

  Duration get position => switch (_engine) {
        _Engine.video => _videoController?.value.position ?? Duration.zero,
        _Engine.audio => _audioPlayer?.position ?? Duration.zero,
        _Engine.none => Duration.zero,
      };

  Duration get duration {
    final d = switch (_engine) {
      _Engine.video => _videoController?.value.duration,
      _Engine.audio => _audioPlayer?.duration,
      _Engine.none => null,
    };
    if (d != null && d > Duration.zero) return d;
    final secs = current?.durationSeconds;
    return secs == null ? Duration.zero : Duration(seconds: secs);
  }

  // ---------------------------------------------------------------------------
  // just_audio engine (created lazily so widget tests never touch plugins)
  // ---------------------------------------------------------------------------

  ja.AudioPlayer get _audio {
    final existing = _audioPlayer;
    if (existing != null) return existing;
    final player = ja.AudioPlayer();
    _audioPlayer = player;
    _subscriptions
      ..add(player.playerStateStream.listen((_) {
        if (_engine == _Engine.audio) notifyListeners();
      }))
      ..add(player.positionStream.listen((_) {
        if (_engine != _Engine.audio) return;
        final now = DateTime.now();
        if (now.difference(_lastPositionTick).inMilliseconds < 250) return;
        _lastPositionTick = now;
        notifyListeners();
      }))
      ..add(player.currentIndexStream.listen(_onAudioIndexChanged));
    return player;
  }

  ja.AudioSource _sourceFor(LibraryItem item) {
    final thumb = item.thumbnailPath;
    return ja.AudioSource.uri(
      Uri.file(item.filePath),
      tag: MediaItem(
        id: item.id,
        title: item.title,
        artist: item.author,
        album: item.qualityLabel,
        duration: item.durationSeconds == null
            ? null
            : Duration(seconds: item.durationSeconds!),
        artUri: thumb.isNotEmpty && File(thumb).existsSync()
            ? Uri.file(thumb)
            : null,
      ),
    );
  }

  /// Fired when just_audio moves to another track by itself (end of track,
  /// or next/previous from the lock screen / Dynamic Island).
  void _onAudioIndexChanged(int? index) {
    if (index == null || _engine != _Engine.audio || _handingOff) return;
    if (index == _index) return;
    _index = index;
    // Back in the app and the new track is a video → show it.
    if (!_inBackground && (current?.isVideo ?? false)) {
      unawaited(_handoffToVideo());
    }
    notifyListeners();
  }

  ja.LoopMode get _audioLoopMode => switch (loopMode) {
        LoopMode.off => ja.LoopMode.off,
        LoopMode.all => ja.LoopMode.all,
        LoopMode.one => ja.LoopMode.one,
      };

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  /// Plays [items] as a queue starting at [startIndex].
  Future<void> playQueue(List<LibraryItem> items, {int startIndex = 0}) async {
    if (items.isEmpty) return;
    playlist
      ..clear()
      ..addAll(items);
    final start = startIndex.clamp(0, items.length - 1);
    await _ensureAudioSession();
    try {
      await _audio.setAudioSource(
        ja.ConcatenatingAudioSource(
          children: items.map(_sourceFor).toList(),
        ),
        initialIndex: start,
      );
      await _audio.setLoopMode(_audioLoopMode);
      await _audio.setSpeed(speed);
    } catch (e) {
      debugPrint('Audio queue setup failed: $e');
    }
    await _load(start);
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= playlist.length) return;
    await _load(index);
    notifyListeners();
  }

  Future<void> _load(int index, {bool autoplay = true}) async {
    _index = index;
    final item = current;
    if (item == null) return;
    await _ensureAudioSession();

    if (item.isVideo && !_inBackground) {
      _handingOff = true;
      try {
        await _audioPlayer?.pause();
        await _openVideo(item);
        _engine = _Engine.video;
        if (autoplay) await _videoController?.play();
      } finally {
        _handingOff = false;
      }
    } else {
      await _closeVideo();
      _engine = _Engine.audio;
      _handingOff = true;
      try {
        await _audio.seek(Duration.zero, index: index);
        await _audio.setSpeed(speed);
      } catch (e) {
        debugPrint('Could not load track: $e');
      } finally {
        _handingOff = false;
      }
      if (autoplay) unawaited(_audio.play());
    }
  }

  Future<void> _openVideo(LibraryItem item) async {
    await _closeVideo();
    final controller = VideoPlayerController.file(
      File(item.filePath),
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    await controller.initialize();
    await controller.setLooping(false);
    await controller.setPlaybackSpeed(speed);
    controller.addListener(_onVideoValueChanged);
    _videoController = controller;
  }

  Future<void> _closeVideo() async {
    final old = _videoController;
    if (old == null) return;
    _videoController = null;
    old.removeListener(_onVideoValueChanged);
    await old.dispose();
  }

  // ---------------------------------------------------------------------------
  // Background hand-off
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_inBackground) return;
        _inBackground = true;
        if (!backgroundPlayEnabled) {
          unawaited(pause());
          return;
        }
        unawaited(_handoffToAudio());
      case AppLifecycleState.resumed:
        if (!_inBackground) return;
        _inBackground = false;
        unawaited(_handoffToVideo());
      default:
        break;
    }
  }

  /// Video in foreground → audio engine (keeps playing in the background and
  /// shows on the lock screen / Dynamic Island).
  Future<void> _handoffToAudio() async {
    final vc = _videoController;
    if (_engine != _Engine.video || vc == null) return;
    final wasPlaying = vc.value.isPlaying;
    final pos = vc.value.position;
    _handingOff = true;
    try {
      await vc.pause();
      _engine = _Engine.audio;
      await _audio.seek(pos, index: _index);
      await _audio.setSpeed(speed);
      if (wasPlaying) unawaited(_audio.play());
    } catch (e) {
      debugPrint('Background hand-off failed: $e');
    } finally {
      _handingOff = false;
    }
    notifyListeners();
  }

  /// Back in the app: if the current track is a video, show it again at the
  /// position the audio engine reached.
  Future<void> _handoffToVideo() async {
    final item = current;
    if (_engine != _Engine.audio || item == null || !item.isVideo) return;
    final audio = _audioPlayer;
    final wasPlaying = audio?.playing ?? false;
    final pos = audio?.position ?? Duration.zero;
    _handingOff = true;
    try {
      await audio?.pause();
      final sameFile = _videoController?.dataSource == Uri.file(item.filePath).toString();
      if (!sameFile) await _openVideo(item);
      final vc = _videoController;
      if (vc == null) return;
      await vc.setPlaybackSpeed(speed);
      await vc.seekTo(pos);
      _engine = _Engine.video;
      if (wasPlaying) await vc.play();
    } catch (e) {
      debugPrint('Foreground hand-off failed: $e');
      // Keep playing audio rather than going silent.
      _engine = _Engine.audio;
      if (wasPlaying) unawaited(_audio.play());
    } finally {
      _handingOff = false;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Audio session / interruptions
  // ---------------------------------------------------------------------------

  Future<void> _ensureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {
      // best-effort — playback still works, just not in background.
    }
  }

  Future<void> _listenForInterruptions() async {
    try {
      final session = await AudioSession.instance;
      session.interruptionEventStream.listen((event) {
        // just_audio handles its own interruptions; this covers videos.
        if (_engine != _Engine.video) return;
        if (event.begin) {
          unawaited(_videoController?.pause());
        } else if (event.type == AudioInterruptionType.pause) {
          unawaited(_videoController?.play());
        }
      });
    } catch (_) {
      // ignore
    }
  }

  // ---------------------------------------------------------------------------
  // Video completion → advance the queue
  // ---------------------------------------------------------------------------

  void _onVideoValueChanged() {
    final vc = _videoController;
    if (vc == null || _advancing || _engine != _Engine.video) return;
    if (vc.value.isCompleted &&
        vc.value.duration > Duration.zero &&
        vc.value.position >= vc.value.duration) {
      _advancing = true;
      unawaited(_handleVideoFinished().whenComplete(() => _advancing = false));
      return;
    }
    notifyListeners();
  }

  Future<void> _handleVideoFinished() async {
    switch (loopMode) {
      case LoopMode.one:
        await _videoController?.seekTo(Duration.zero);
        await _videoController?.play();
      case LoopMode.all:
        await _load((_index + 1) % playlist.length);
      case LoopMode.off:
        if (_index < playlist.length - 1) {
          await _load(_index + 1);
        } else {
          await _videoController?.pause();
        }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Transport controls
  // ---------------------------------------------------------------------------

  Future<void> toggle() async {
    isPlaying ? await pause() : await play();
  }

  Future<void> play() async {
    await _ensureAudioSession();
    switch (_engine) {
      case _Engine.video:
        await _videoController?.play();
      case _Engine.audio:
        unawaited(_audio.play());
      case _Engine.none:
        break;
    }
    notifyListeners();
  }

  Future<void> pause() async {
    switch (_engine) {
      case _Engine.video:
        await _videoController?.pause();
      case _Engine.audio:
        await _audioPlayer?.pause();
      case _Engine.none:
        break;
    }
    notifyListeners();
  }

  /// Enables/disables playback after leaving the app.
  Future<void> toggleBackgroundPlay() async {
    backgroundPlayEnabled = !backgroundPlayEnabled;
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    switch (_engine) {
      case _Engine.video:
        await _videoController?.seekTo(target);
      case _Engine.audio:
        await _audioPlayer?.seek(target);
      case _Engine.none:
        break;
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (_index < playlist.length - 1) {
      await _load(_index + 1);
    } else if (loopMode == LoopMode.all && playlist.isNotEmpty) {
      await _load(0);
    } else {
      await pause();
    }
    notifyListeners();
  }

  Future<void> previous() async {
    if (position > const Duration(seconds: 3) || _index <= 0) {
      await seek(Duration.zero);
    } else {
      await _load(_index - 1);
    }
    notifyListeners();
  }

  void cycleLoopMode() {
    loopMode = LoopMode.values[(loopMode.index + 1) % LoopMode.values.length];
    unawaited(_audioPlayer?.setLoopMode(_audioLoopMode));
    notifyListeners();
  }

  Future<void> cycleSpeed() async {
    final i = playbackSpeeds.indexOf(speed);
    speed = playbackSpeeds[(i + 1) % playbackSpeeds.length];
    await _videoController?.setPlaybackSpeed(speed);
    await _audioPlayer?.setSpeed(speed);
    notifyListeners();
  }

  void stop() {
    unawaited(_closeVideo());
    unawaited(_audioPlayer?.stop());
    _engine = _Engine.none;
    _index = -1;
    playlist = [];
    notifyListeners();
  }

  @override
  void dispose() {
    if (instance == this) instance = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _videoController?.removeListener(_onVideoValueChanged);
    unawaited(_videoController?.dispose());
    unawaited(_audioPlayer?.dispose());
    super.dispose();
  }
}
