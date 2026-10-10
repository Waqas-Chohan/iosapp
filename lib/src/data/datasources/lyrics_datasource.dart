import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/library_item.dart';
import '../../domain/entities/lyrics.dart';
import 'local_storage_datasource.dart';

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
  Future<Lyrics> lyricsFor(LibraryItem item) async {
    final key = item.videoId;
    final cached = _memory[key] ?? await _readCache(key);
    if (cached != null) return _memory[key] = cached;

    final query = cleanQuery(item.title, item.author);
    final found = await _fetch(query.title, query.artist, item.durationSeconds);
    _memory[key] = found;
    await _writeCache(key, found);
    return found;
  }

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

  Future<Lyrics> _fetch(String title, String artist, int? duration) async {
    // 1) Exact signature lookup (best match when the duration is known).
    if (artist.isNotEmpty) {
      try {
        final res = await _dio.get<Map<String, dynamic>>('/get', queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (duration != null && duration > 0) 'duration': duration,
        });
        final l = _fromJson(res.data);
        if (l != null && !l.isEmpty) return l;
      } on DioException {
        // 404 = not found → fall through to search.
      }
    }

    // 2) Search, then pick the closest duration (synced preferred).
    final candidates = <Map<String, dynamic>>[];
    for (final params in [
      if (artist.isNotEmpty) {'track_name': title, 'artist_name': artist},
      {'q': artist.isEmpty ? title : '$title $artist'},
    ]) {
      try {
        final res = await _dio.get<List<dynamic>>('/search', queryParameters: params);
        candidates.addAll((res.data ?? const []).whereType<Map<String, dynamic>>());
      } on DioException {
        // try next query
      }
      if (candidates.isNotEmpty) break;
    }
    if (candidates.isEmpty) return const Lyrics();

    int score(Map<String, dynamic> c) {
      final d = (c['duration'] as num?)?.round();
      final diff = (duration == null || d == null) ? 30 : (d - duration).abs();
      final synced = (c['syncedLyrics'] as String?)?.isNotEmpty ?? false;
      return diff + (synced ? 0 : 20) + ((c['instrumental'] == true) ? 1000 : 0);
    }

    candidates.sort((a, b) => score(a).compareTo(score(b)));
    final best = candidates.first;
    if (duration != null) {
      final d = (best['duration'] as num?)?.round();
      if (d != null && (d - duration).abs() > 15) return const Lyrics();
    }
    return _fromJson(best) ?? const Lyrics();
  }

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
      if (await files[2].exists()) {
        // "Not found" is cached for a day, then retried.
        final age = DateTime.now().difference(await files[2].lastModified());
        if (age < const Duration(days: 1)) return const Lyrics();
      }
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
      if (lyrics.isEmpty) await files[2].writeAsString('');
    } catch (_) {
      // Cache is optional.
    }
  }
}
