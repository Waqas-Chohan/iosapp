import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/entities/lyrics.dart';
import 'local_storage_datasource.dart';

/// Thrown when LRCLIB could not be reached (offline, DNS, timeout…).
class LyricsNetworkException implements Exception {
  const LyricsNetworkException();

  @override
  String toString() => 'Could not reach the lyrics service.';
}

/// Free, key-less lyrics from LRCLIB (https://lrclib.net), cached on disk so
/// they also work offline.
class LyricsDatasource {
  LyricsDatasource({Dio? dio, LocalStorageDatasource? storage})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://lrclib.net/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {
                // LRCLIB asks clients to identify themselves.
                'User-Agent': 'Musically/1.0 (personal iOS app)',
              },
            )),
        _storage = storage ?? LocalStorageDatasource();

  final Dio _dio;
  final LocalStorageDatasource _storage;
  final Map<String, Lyrics> _memory = {};

  /// Returns lyrics for [item]: memory → disk cache → LRCLIB.
  ///
  /// Pass [title]/[artist] to search with custom terms (manual search).
  /// Throws [LyricsNetworkException] when LRCLIB could not be reached at all,
  /// so the UI can say "check your connection" instead of "not found".
  Future<Lyrics> lyricsFor(
    LibraryItem item, {
    String? title,
    String? artist,
  }) async {
    final key = item.videoId;
    final manual = title != null;
    if (!manual) {
      final cached = _memory[key] ?? await _readCache(key);
      if (cached != null && !cached.isEmpty) return _memory[key] = cached;
    }

    final query = title != null
        ? (title: title.trim(), artist: (artist ?? '').trim())
        : cleanQuery(item.title, item.author);
    final found = await _fetch(query.title, query.artist, item.title,
        item.author, item.durationSeconds);
    // Only real lyrics are cached; "not found" is retried next time.
    if (!found.isEmpty) {
      _memory[key] = found;
      await _writeCache(key, found);
    }
    return found;
  }

  /// The cleaned (title, artist) the automatic search uses for [item].
  ({String title, String artist}) queryFor(LibraryItem item) =>
      cleanQuery(item.title, item.author);

  /// Forgets the cached result so the next call queries LRCLIB again.
  Future<void> clear(LibraryItem item) async {
    _memory.remove(item.videoId);
    for (final f in await _cacheFiles(item.videoId)) {
      if (await f.exists()) await f.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // LRCLIB
  // ---------------------------------------------------------------------------

  Future<Lyrics> _fetch(
    String title,
    String artist,
    String rawTitle,
    String channel,
    int? duration,
  ) async {
    var reached = false; // at least one request got an HTTP answer
    var networkErrors = 0;

    Future<T?> call<T>(String path, Map<String, dynamic> params) async {
      try {
        final res = await _dio.get<T>(path, queryParameters: params);
        reached = true;
        return res.data;
      } on DioException catch (e) {
        if (e.response != null) {
          reached = true; // e.g. 404 = not found
        } else {
          networkErrors++;
        }
        return null;
      }
    }

    // 1) Exact lookup. No duration here: LRCLIB would then demand a ±2 s
    //    match, and YouTube videos often have intros/outros.
    if (artist.isNotEmpty) {
      final l = _fromJson(await call<Map<String, dynamic>>(
          '/get', {'track_name': title, 'artist_name': artist}));
      if (l != null && !l.isEmpty) return l;
    }

    // 2) Several searches, from most to least specific.
    final cleanRaw = rawTitle
        .replaceAll(RegExp(r'\s*[\(\[【][^\)\]】]*[\)\]】]'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final queries = <Map<String, dynamic>>[
      if (artist.isNotEmpty) {'track_name': title, 'artist_name': artist},
      if (artist.isNotEmpty) {'q': '$artist $title'},
      {'track_name': title},
      {'q': cleanRaw},
      if (channel.isNotEmpty) {'q': '$title $channel'},
    ];
    final seen = <String>{};
    final candidates = <Map<String, dynamic>>[];
    for (final params in queries) {
      final sig = params.toString();
      if (!seen.add(sig)) continue;
      final data = await call<List<dynamic>>('/search', params);
      candidates.addAll((data ?? const []).whereType<Map<String, dynamic>>());
      if (candidates.any(_hasSynced)) break;
    }

    if (candidates.isEmpty) {
      if (!reached && networkErrors > 0) throw const LyricsNetworkException();
      return const Lyrics();
    }

    final wanted = _norm(title);
    int score(Map<String, dynamic> c) {
      var s = 0;
      final d = (c['duration'] as num?)?.round();
      if (duration != null && d != null) s += (d - duration).abs().clamp(0, 120);
      if (!_hasSynced(c)) s += 60;
      final name = _norm((c['trackName'] ?? c['name'] ?? '') as String);
      if (wanted.isNotEmpty && !name.contains(wanted) && !wanted.contains(name)) {
        s += 80;
      }
      if (c['instrumental'] == true) s += 1000;
      return s;
    }

    final usable = candidates
        .where((c) =>
            _hasSynced(c) || ((c['plainLyrics'] as String?)?.isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => score(a).compareTo(score(b)));
    if (usable.isEmpty) return const Lyrics();
    return _fromJson(usable.first) ?? const Lyrics();
  }

  static bool _hasSynced(Map<String, dynamic> c) =>
      (c['syncedLyrics'] as String?)?.isNotEmpty ?? false;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0080-\uffff]+'), '');

  Lyrics? _fromJson(Map<String, dynamic>? data) {
    if (data == null) return null;
    final synced = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;
    return Lyrics(
      lines: synced == null ? const [] : Lyrics.parseLrc(synced),
      plain: plain,
    );
  }

  // ---------------------------------------------------------------------------
  // Title cleaning: "Artist - Song (Official Video) [4K]" → (Song, Artist)
  // ---------------------------------------------------------------------------

  static ({String title, String artist}) cleanQuery(String rawTitle, String channel) {
    var t = rawTitle;
    // Drop bracketed tags: (Official Video), [4K], 【MV】, etc.
    t = t.replaceAll(RegExp(r'\s*[\(\[【][^\)\]】]*[\)\]】]'), ' ');
    // Drop trailing marketing words.
    t = t.replaceAll(
        RegExp(r'\b(official|music|lyric|lyrics|video|audio|visuali[sz]er|hd|hq|4k|mv|m/v)\b',
            caseSensitive: false),
        ' ');
    t = t.replaceAll(RegExp(r'\s*\|.*$'), ''); // "Song | Album" → "Song"

    var artist = channel
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(official)\s*$', caseSensitive: false), '')
        .trim();

    final parts = t.split(RegExp(r'\s+[-–—]\s+'));
    var title = t;
    if (parts.length >= 2) {
      artist = parts.first.trim();
      title = parts.sublist(1).join(' ').trim();
    }
    // "Song ft. X" / "Song feat. X" → "Song"
    title = title.replaceAll(RegExp(r'\s+(ft\.?|feat\.?|featuring)\s+.*$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    artist = artist.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return (title: title.isEmpty ? rawTitle : title, artist: artist);
  }

  // ---------------------------------------------------------------------------
  // Offline cache: <documents>/musically_library/lyrics/<videoId>.lrc|.txt|.none
  // ---------------------------------------------------------------------------

  Future<List<File>> _cacheFiles(String key) async {
    final dir = await _storage.lyricsDirectory();
    return [
      File('${dir.path}/$key.lrc'),
      File('${dir.path}/$key.txt'),
      File('${dir.path}/$key.none'),
    ];
  }

  Future<Lyrics?> _readCache(String key) async {
    try {
      final files = await _cacheFiles(key);
      if (await files[0].exists()) {
        final lrc = await files[0].readAsString();
        final plain = await files[1].exists() ? await files[1].readAsString() : null;
        return Lyrics(lines: Lyrics.parseLrc(lrc), plain: plain);
      }
      if (await files[1].exists()) return Lyrics(plain: await files[1].readAsString());
      // Old "not found" markers from earlier versions are ignored.
      if (await files[2].exists()) await files[2].delete();
    } catch (_) {
      // Corrupt cache → refetch.
    }
    return null;
  }

  Future<void> _writeCache(String key, Lyrics lyrics) async {
    try {
      final files = await _cacheFiles(key);
      if (lyrics.isSynced) await files[0].writeAsString(lyrics.toLrc());
      if (lyrics.plain != null && lyrics.plain!.trim().isNotEmpty) {
        await files[1].writeAsString(lyrics.plain!);
      }
    } catch (_) {
      // Cache is optional.
    }
  }
}
