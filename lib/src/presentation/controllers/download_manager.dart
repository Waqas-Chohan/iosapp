import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local_storage_datasource.dart';
import '../../data/datasources/media_tools.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/video_repository.dart';
import 'library_model.dart';

/// Download queue with independent pause / resume / cancel per task.
///
/// - Bytes are fetched in 10 MB `Range` chunks (what YouTube's CDN expects),
///   appended to a partial file, so a paused or interrupted download
///   resumes exactly where it stopped — even after the app restarts.
/// - Expired URLs (403/410) are refreshed from a new manifest automatically.
/// - 720p/1080p video + audio parts are merged on device (no re-encode).
/// - Finished items are added to the Library and videos are saved to the
///   "Musically" album in Photos.
class DownloadManager extends ChangeNotifier {
  DownloadManager(
    this._repository, {
    required this.library,
    LocalStorageDatasource? storage,
    MediaTools? tools,
    this.maxConcurrent = 2,
  })  : _storage = storage ?? LocalStorageDatasource(),
        _tools = tools ?? const MediaTools();

  final VideoRepository _repository;
  /// Finished downloads are registered here.
  final LibraryModel library;
  final LocalStorageDatasource _storage;
  final MediaTools _tools;
  final int maxConcurrent;

  /// Save finished videos to the Photos app automatically.
  bool autoSaveToPhotos = true;

  static const int _chunkSize = 10 * 1024 * 1024;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _tokens = {};
  final Map<String, ({DateTime at, int bytes})> _speedMarks = {};
  final StreamController<DownloadTask> _completed =
      StreamController<DownloadTask>.broadcast();
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// Newest first.
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  List<DownloadTask> get active =>
      _tasks.where((t) => t.state != DownloadState.completed).toList();

  List<DownloadTask> get finished =>
      _tasks.where((t) => t.state == DownloadState.completed).toList();

  /// Downloads currently transferring or waiting in the queue.
  int get inProgressCount => _tasks
      .where((t) =>
          t.state == DownloadState.downloading ||
          t.state == DownloadState.queued ||
          t.state == DownloadState.processing)
      .length;

  /// Fires once per task when it lands in the Library.
  Stream<DownloadTask> get onCompleted => _completed.stream;

  DownloadTask? byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Most recent task for [videoId] (used for the search result badges).
  DownloadTask? latestFor(String videoId) {
    for (final t in _tasks) {
      if (t.videoId == videoId) return t;
    }
    return null;
  }

  Future<VideoDownloadInfo> fetchInfo(String videoId) =>
      _repository.fetchVideoInfo(videoId);

  // ---------------------------------------------------------------- queue --

  Future<void> load() async {
    try {
      final file = await _storage.downloadsRegistryFile();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      for (final raw in decoded.whereType<Map<String, dynamic>>()) {
        final t = DownloadTask.fromJson(raw);
        if (t.id.isEmpty) continue;
        // Anything that was running when the app closed waits for the user.
        if (t.state != DownloadState.completed &&
            t.state != DownloadState.failed) {
          t.state = DownloadState.paused;
        }
        final result = t.resultPath;
        if (result != null) t.resultPath = await _storage.rebase(result);
        _tasks.add(t);
      }
      _notify(force: true);
    } catch (_) {
      // A corrupt registry must never block the app.
    }
  }

  DownloadTask enqueue(VideoDownloadInfo info, StreamOption option) {
    final task = DownloadTask(
      id: 'dl_${DateTime.now().microsecondsSinceEpoch}',
      videoId: info.videoId,
      title: info.title,
      author: info.author,
      thumbnailUrl: info.thumbnailUrl,
      durationSeconds: info.duration?.inSeconds,
      option: option,
      createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    _changed();
    _pump();
    return task;
  }

  void pause(String id) {
    final t = byId(id);
    if (t == null || !t.canPause) return;
    t.state = DownloadState.paused;
    t.speed = 0;
    _tokens[id]?.cancel('paused');
    _changed();
  }

  void resume(String id) {
    final t = byId(id);
    if (t == null || !t.canResume) return;
    t.state = DownloadState.queued;
    t.error = null;
    _changed();
    _pump();
  }

  void pauseAll() {
    for (final t in _tasks.where((t) => t.canPause).toList()) {
      pause(t.id);
    }
  }

  void resumeAll() {
    for (final t in _tasks.where((t) => t.state == DownloadState.paused)) {
      t.state = DownloadState.queued;
      t.error = null;
    }
    _changed();
    _pump();
  }

  /// Stops the task and deletes its partial data.
  Future<void> cancel(String id) async {
    final t = byId(id);
    if (t == null || t.state == DownloadState.processing) return;
    _tasks.remove(t);
    _tokens[id]?.cancel('cancelled');
    _changed();
    await _deleteParts(t);
  }

  /// Removes a finished entry from the list (the Library keeps the file).
  void dismiss(String id) {
    _tasks.removeWhere((t) => t.id == id && t.isFinished);
    _changed();
  }

  void clearFinished() {
    _tasks.removeWhere((t) => t.isFinished);
    _changed();
  }

  Future<void> saveToPhotos(String id) async {
    final t = byId(id);
    final path = t?.resultPath;
    if (t == null || path == null || !t.isVideo) return;
    try {
      await _repository.saveVideoToGallery(path);
      t.savedToPhotos = true;
      t.photosError = null;
    } catch (e) {
      t.photosError = _short(e);
      rethrow;
    } finally {
      _changed();
    }
  }

  /// Saves any local video (e.g. from the Library) to Photos.
  Future<void> saveFileToPhotos(String path) =>
      _repository.saveVideoToGallery(path);

  void _pump() {
    if (_disposed) return;
    var running = _tasks.where((t) => t.isRunning).length;
    // Oldest queued first (list is newest first).
    for (final t in _tasks.reversed.toList()) {
      if (running >= maxConcurrent) break;
      if (t.state == DownloadState.queued) {
        running++;
        unawaited(_run(t));
      }
    }
  }

  // ------------------------------------------------------------- transfer --

  Future<void> _run(DownloadTask t) async {
    final token = CancelToken();
    _tokens[t.id] = token;
    t.state = DownloadState.downloading;
    t.error = null;
    _changed();

    try {
      final partial = await _storage.partialDirectory();
      final main = File('${partial.path}/${t.id}.main');
      final audio = File('${partial.path}/${t.id}.audio');

      await _transfer(t, main, token,
          tag: t.option.tag, isAudioPart: false, base: 0);
      if (t.option.needsMerge) {
        await _transfer(t, audio, token,
            tag: t.option.audioTag!,
            isAudioPart: true,
            base: await main.length());
      }
      if (token.isCancelled) return;

      t.state = DownloadState.processing;
      t.speed = 0;
      _notify(force: true);

      final out = await _uniqueTarget(t);
      if (t.option.needsMerge) {
        await _tools.merge(
          videoPath: main.path,
          audioPath: audio.path,
          outputPath: out.path,
        );
        await _deleteParts(t);
      } else {
        await main.rename(out.path);
      }
      t.resultPath = out.path;
      await _finish(t);
    } catch (e) {
      final cancelled = (e is DioException && CancelToken.isCancel(e)) ||
          token.isCancelled;
      if (!cancelled) {
        t.state = DownloadState.failed;
        t.error = _friendly(e);
      }
    } finally {
      _tokens.remove(t.id);
      _speedMarks.remove(t.id);
      t.speed = 0;
      _changed();
      _pump();
    }
  }

  Future<void> _transfer(
    DownloadTask t,
    File file,
    CancelToken token, {
    required int tag,
    required bool isAudioPart,
    required int base,
  }) async {
    final already = base;
    var total = (isAudioPart ? t.option.audioSizeBytes : t.option.sizeBytes) ?? 0;
    var refreshes = 0;
    var failures = 0;
    if (!await file.exists()) await file.create(recursive: true);

    while (true) {
      if (token.isCancelled) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(path: file.path),
          reason: 'paused',
        );
      }
      var offset = await file.length();
      if (total > 0 && offset > total) {
        await file.writeAsBytes(const [], flush: true);
        offset = 0;
      }
      if (total > 0 && offset >= total) return;

      final url = isAudioPart ? t.option.audioUrl : t.option.url;
      final end = total > 0
          ? math.min(offset + _chunkSize, total) - 1
          : offset + _chunkSize - 1;
      try {
        final res = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Range': 'bytes=$offset-$end'},
          ),
          cancelToken: token,
        );
        final code = res.statusCode ?? 0;
        final range = res.headers.value('content-range');
        final rangeTotal = range == null
            ? null
            : int.tryParse(RegExp(r'/(\d+)').firstMatch(range)?.group(1) ?? '');
        if (rangeTotal != null && rangeTotal > 0) total = rangeTotal;

        final whole = code == 200; // server ignored the Range header
        if (whole) {
          if (offset > 0) await file.writeAsBytes(const [], flush: true);
          offset = 0;
          total = int.tryParse(res.headers.value('content-length') ?? '') ?? 0;
        }
        _updateTotal(t, isAudioPart, total);

        var got = 0;
        final sink = file.openWrite(mode: FileMode.append);
        try {
          await for (final chunk in res.data!.stream) {
            sink.add(chunk);
            got += chunk.length;
            _onBytes(t, already + offset + got);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (whole) return;
        if (got == 0) {
          if (total == 0) return; // unknown size and nothing more to read
          if (++failures > 4) throw StateError('The download stalled.');
          await Future<void>.delayed(Duration(seconds: 2 * failures));
          continue;
        }
        failures = 0;
        if (total == 0 && got < end - offset + 1) return; // reached the end
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        final status = e.response?.statusCode;
        if (status == 416) return; // nothing left to fetch
        if ((status == 403 || status == 410 || status == 404) &&
            refreshes < 3) {
          refreshes++;
          final fresh = await _repository.refreshStreamUrl(t.videoId, tag);
          if (fresh != null && fresh.isNotEmpty) {
            t.option = isAudioPart
                ? t.option.copyWith(audioUrl: fresh)
                : t.option.copyWith(url: fresh);
            continue;
          }
        }
        if (++failures > 4) rethrow;
        await Future<void>.delayed(Duration(seconds: 2 * failures));
      }
    }
  }

  void _updateTotal(DownloadTask t, bool isAudioPart, int partTotal) {
    if (partTotal <= 0) return;
    final o = t.option;
    final other = isAudioPart ? (o.sizeBytes ?? 0) : (o.audioSizeBytes ?? 0);
    t.total = partTotal + (o.needsMerge ? other : 0);
  }

  void _onBytes(DownloadTask t, int received) {
    t.received = received;
    final now = DateTime.now();
    final mark = _speedMarks[t.id];
    if (mark == null) {
      _speedMarks[t.id] = (at: now, bytes: received);
    } else {
      final ms = now.difference(mark.at).inMilliseconds;
      if (ms >= 800) {
        final instant = (received - mark.bytes) * 1000 / ms;
        t.speed = t.speed == 0 ? instant : t.speed * 0.6 + instant * 0.4;
        _speedMarks[t.id] = (at: now, bytes: received);
      }
    }
    _notify();
  }

  Future<void> _finish(DownloadTask t) async {
    final path = t.resultPath!;
    final thumb =
        await library.repository.saveThumbnail(t.thumbnailUrl, t.videoId);
    final item = LibraryItem(
      id: '${t.videoId}_${t.option.tag}_${DateTime.now().millisecondsSinceEpoch}',
      videoId: t.videoId,
      title: t.title,
      author: t.author,
      filePath: path,
      category: t.option.isVideo ? StreamCategory.muxed : StreamCategory.audio,
      qualityLabel: t.option.label,
      container: t.option.extensionName,
      thumbnailPath: thumb,
      createdAt: DateTime.now(),
      durationSeconds: t.durationSeconds,
    );
    try {
      await library.add(item);
    } catch (_) {
      // The file is safe on disk even if the registry write fails.
    }
    t.libraryItemId = item.id;
    t.state = DownloadState.completed;
    t.completedAt = DateTime.now();
    if (t.total <= 0) t.total = t.received;
    t.received = t.total;
    _changed();

    if (t.isVideo && autoSaveToPhotos) {
      try {
        await _repository.saveVideoToGallery(path);
        t.savedToPhotos = true;
      } catch (e) {
        t.photosError = _short(e);
      }
    }
    if (!_completed.isClosed) _completed.add(t);
  }

  Future<File> _uniqueTarget(DownloadTask t) async {
    final dir = await _storage.downloadsDirectory();
    final ext = t.option.extensionName;
    final safe = t.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final base = safe.isEmpty ? t.videoId : safe;
    final stem =
        '${base.length > 80 ? base.substring(0, 80).trim() : base} (${t.option.label})';
    var file = File('${dir.path}/$stem.$ext');
    var n = 2;
    while (await file.exists()) {
      file = File('${dir.path}/$stem $n.$ext');
      n++;
    }
    return file;
  }

  Future<void> _deleteParts(DownloadTask t) async {
    try {
      final partial = await _storage.partialDirectory();
      for (final suffix in const ['main', 'audio']) {
        final f = File('${partial.path}/${t.id}.$suffix');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {
      // Best effort.
    }
  }

  // ------------------------------------------------------------- plumbing --

  /// State change: notify now and persist.
  void _changed() {
    _notify(force: true);
    unawaited(_persist());
  }

  void _notify({bool force = false}) {
    if (_disposed) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify).inMilliseconds < 250) return;
    _lastNotify = now;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final file = await _storage.downloadsRegistryFile();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode(_tasks.take(200).map((t) => t.toJson()).toList()),
        flush: true,
      );
      await tmp.rename(file.path);
    } catch (_) {
      // Ignore (e.g. tests without a documents directory).
    }
  }

  static String _friendly(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 403) {
        return 'YouTube refused this format. Try another quality.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection lost. Tap retry to continue where it stopped.';
      }
      if (code != null) return 'Server error $code. Tap retry.';
    }
    if (e is FileSystemException) return 'Not enough storage space?';
    return _short(e);
  }

  static String _short(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    return msg.length > 140 ? '${msg.substring(0, 140)}…' : msg;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      token.cancel('disposed');
    }
    _completed.close();
    _repository.close();
    super.dispose();
  }
}
