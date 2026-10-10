import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../data/datasources/local_storage_datasource.dart';
import '../../domain/entities/library_item.dart';
import 'player_controller.dart';

class MoodPlaylist {
  MoodPlaylist({
    required this.title,
    required this.summary,
    required this.items,
  });

  final String title;
  final String summary;
  final List<LibraryItem> items;
}

class WeeklyListeningReport {
  WeeklyListeningReport({
    required this.title,
    required this.summary,
    required this.narrative,
    required this.highlights,
  });

  final String title;
  final String summary;
  final String narrative;
  final List<String> highlights;
}

class LibraryAiService {
  LibraryAiService(this.player, {LocalStorageDatasource? storage})
      : _storage = storage ?? LocalStorageDatasource();

  final PlayerController player;
  final LocalStorageDatasource _storage;
  final Dio _dio = Dio();
  final Map<String, String?> _artistArtworkMemory = {};

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<List<LibraryItem>> recommendations(List<LibraryItem> library) async {
    final recent = player.recentlyPlayed;
    final signature = _signature([...library, ...recent]);
    final cached = await _readCache('recommendations');
    if (cached != null && cached['signature'] == signature) {
      return _itemsFromIds(library, cached['ids'] as List? ?? const []);
    }

    final prompt = _recommendationPrompt(library, recent);
    final payload = await _generateJson(prompt, fallback: () {
      final fallbackItems = _localFallback(library, recent, 8);
      return {
        'ids': fallbackItems.map((i) => i.id).toList(),
      };
    });
    await _writeCache('recommendations', {
      'signature': signature,
      'ids': (payload['ids'] as List? ?? const []).whereType<String>().toList(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    return _itemsFromIds(library, payload['ids'] as List? ?? const []);
  }

  Future<MoodPlaylist> moodPlaylist({
    required List<LibraryItem> library,
    required String mood,
  }) async {
    final recent = player.recentlyPlayed;
    final signature = '${_signature([...library, ...recent])}::$mood';
    final cached = await _readCache('mood:$mood');
    if (cached != null && cached['signature'] == signature) {
      return MoodPlaylist(
        title: cached['title'] as String? ?? _moodTitle(mood),
        summary: cached['summary'] as String? ?? '',
        items: _itemsFromIds(library, cached['ids'] as List? ?? const []),
      );
    }

    final prompt = _moodPrompt(library, recent, mood);
    final payload = await _generateJson(prompt, fallback: () {
      final fallbackItems = _localFallback(library, recent, 10);
      return {
        'title': _moodTitle(mood),
        'summary': 'Built from your recent library activity.',
        'ids': fallbackItems.map((i) => i.id).toList(),
      };
    });
    final title = payload['title'] as String? ?? _moodTitle(mood);
    final summary = payload['summary'] as String? ?? '';
    final ids = (payload['ids'] as List? ?? const []).whereType<String>().toList();
    await _writeCache('mood:$mood', {
      'signature': signature,
      'title': title,
      'summary': summary,
      'ids': ids,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return MoodPlaylist(
      title: title,
      summary: summary,
      items: _itemsFromIds(library, ids),
    );
  }

  Future<WeeklyListeningReport> weeklyReport(List<LibraryItem> library) async {
    final recent = player.recentlyPlayed;
    final signature = _signature([...library, ...recent]);
    final cached = await _readCache('weekly_report');
    final cachedAt = DateTime.tryParse(cached?['createdAt'] as String? ?? '');
    if (cached != null && cached['signature'] == signature && cachedAt != null) {
      if (DateTime.now().difference(cachedAt) < const Duration(days: 7)) {
        return WeeklyListeningReport(
          title: cached['title'] as String? ?? 'Weekly listening report',
          summary: cached['summary'] as String? ?? '',
          narrative: cached['narrative'] as String? ?? '',
          highlights: (cached['highlights'] as List? ?? const [])
              .whereType<String>()
              .toList(),
        );
      }
    }

    final prompt = _weeklyPrompt(library, recent);
    final payload = await _generateJson(prompt, fallback: () {
      final fallbackHighlights = _topArtists(library, recent)
          .take(3)
          .map((e) => '${e.$1} · ${e.$2} tracks')
          .toList();
      return {
        'title': 'Weekly listening report',
        'summary': 'A quick snapshot of your recent listening.',
        'narrative':
            'You have been leaning into ${fallbackHighlights.isEmpty ? 'a balanced mix' : fallbackHighlights.first.split(' · ').first}.',
        'highlights': fallbackHighlights,
      };
    });
    final title = payload['title'] as String? ?? 'Weekly listening report';
    final summary = payload['summary'] as String? ?? '';
    final narrative = payload['narrative'] as String? ?? '';
    final highlights = (payload['highlights'] as List? ?? const [])
        .whereType<String>()
        .toList();
    await _writeCache('weekly_report', {
      'signature': signature,
      'title': title,
      'summary': summary,
      'narrative': narrative,
      'highlights': highlights,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return WeeklyListeningReport(
      title: title,
      summary: summary,
      narrative: narrative,
      highlights: highlights,
    );
  }

  Future<String?> artistArtworkUrl(String artist) async {
    final key = artist.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (_artistArtworkMemory.containsKey(key)) {
      return _artistArtworkMemory[key];
    }
    final cached = await _readCache('artist_artworks');
    final cachedUrl = cached?[key] as String?;
    if (cachedUrl != null) {
      _artistArtworkMemory[key] = cachedUrl;
      return cachedUrl;
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.deezer.com/search/artist',
        queryParameters: {
          'q': 'artist:"$artist"',
          'limit': 1,
        },
      );
      final data = res.data?['data'];
      final first = data is List && data.isNotEmpty ? data.first : null;
      final url = first is Map ? first['picture_big'] as String? ?? first['picture_medium'] as String? : null;
      _artistArtworkMemory[key] = url;
      if (url != null && url.isNotEmpty) {
        await _writeCache('artist_artworks', {
          ...?cached,
          key: url,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      return url;
    } catch (_) {
      _artistArtworkMemory[key] = null;
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final file = await _storage.aiCacheFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final entry = decoded[key];
      return entry is Map<String, dynamic> ? entry : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, Map<String, dynamic> value) async {
    try {
      final file = await _storage.aiCacheFile();
      Map<String, dynamic> decoded = <String, dynamic>{};
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) decoded = raw;
      }
      decoded[key] = value;
      await file.writeAsString(jsonEncode(decoded));
    } catch (_) {
      // Best effort only; cached AI results are optional.
    }
  }

  Future<Map<String, dynamic>> _generateJson(
    String prompt, {
    required Map<String, dynamic> Function() fallback,
  }) async {
    if (_apiKey.isEmpty) return fallback();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'responseMimeType': 'application/json',
          },
        },
      );
      final text = _extractText(res.data);
      if (text.isEmpty) return fallback();
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to the local fallback.
    }
    return fallback();
  }

  String _extractText(Map<String, dynamic>? data) {
    try {
      final candidates = data?['candidates'] as List?;
      final first = candidates?.first as Map?;
      final content = first?['content'] as Map?;
      final parts = content?['parts'] as List?;
      final text = parts?.firstWhere(
            (part) => part is Map && part['text'] is String,
            orElse: () => const <String, dynamic>{},
          ) as Map?;
      return text?['text'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  List<LibraryItem> _itemsFromIds(List<LibraryItem> library, List ids) {
    final map = {for (final item in library) item.id: item};
    final items = <LibraryItem>[];
    for (final id in ids.whereType<String>()) {
      final item = map[id];
      if (item != null && !items.any((entry) => entry.id == item.id)) {
        items.add(item);
      }
    }
    if (items.isEmpty) {
      items.addAll(_localFallback(library, player.recentlyPlayed, 6));
    }
    return items;
  }

  List<LibraryItem> _localFallback(
    List<LibraryItem> library,
    List<LibraryItem> recent,
    int limit,
  ) {
    final seen = <String>{};
    final items = <LibraryItem>[];
    void addAll(Iterable<LibraryItem> source) {
      for (final item in source) {
        if (seen.add(item.id)) items.add(item);
        if (items.length >= limit) return;
      }
    }

    addAll(recent.reversed);
    if (items.length < limit) addAll(library.take(limit * 2));

    if (items.length < limit) {
      final topArtists = _topArtists(library, recent);
      for (final entry in topArtists) {
        addAll(library.where((item) => item.author == entry.$1));
        if (items.length >= limit) break;
      }
    }

    return items.take(limit).toList();
  }

  List<(String, int)> _topArtists(List<LibraryItem> library, List<LibraryItem> recent) {
    final counts = <String, int>{};
    for (final item in [...recent, ...library]) {
      counts[item.author] = (counts[item.author] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => (e.key, e.value)).toList();
  }

  String _signature(List<LibraryItem> items) => items
      .map((item) =>
          '${item.id}:${item.title}:${item.author}:${item.createdAt.millisecondsSinceEpoch}')
      .join('|');

  String _recommendationPrompt(List<LibraryItem> library, List<LibraryItem> recent) {
    final catalog = _catalogBlock(library);
    final recentBlock = recent.isEmpty
        ? 'No recent plays captured yet.'
        : recent
            .take(12)
            .map((item) => '- ${item.title} — ${item.author}')
            .join('\n');
    return '''
You are generating local music recommendations for a Flutter music app.
Return JSON only with the shape:
{"title":"For you","summary":"short sentence","ids":["itemId", ...]}

Rules:
- Pick up to 8 ids.
- Use only ids from the catalog.
- Prefer songs that fit the recent listening pattern.
- Keep the mix fresh and varied.

Recent plays:
$recentBlock

Catalog:
$catalog
''';
  }

  String _moodPrompt(
    List<LibraryItem> library,
    List<LibraryItem> recent,
    String mood,
  ) {
    final catalog = _catalogBlock(library);
    final recentBlock = recent.isEmpty
        ? 'No recent plays captured yet.'
        : recent
            .take(12)
            .map((item) => '- ${item.title} — ${item.author}')
            .join('\n');
    return '''
Create a vibe-matched playlist for: $mood.
Return JSON only with the shape:
{"title":"playlist name","summary":"short sentence","ids":["itemId", ...]}

Rules:
- Pick up to 10 ids.
- Use only ids from the catalog.
- Make the sequence feel cohesive for the mood.

Recent plays:
$recentBlock

Catalog:
$catalog
''';
  }

  String _weeklyPrompt(List<LibraryItem> library, List<LibraryItem> recent) {
    final catalog = _catalogBlock(library);
    final recentBlock = recent.isEmpty
        ? 'No recent plays captured yet.'
        : recent
            .take(20)
            .map((item) => '- ${item.title} — ${item.author}')
            .join('\n');
    final topArtists = _topArtists(library, recent)
        .take(5)
        .map((entry) => '- ${entry.$1} (${entry.$2} tracks)')
        .join('\n');
    return '''
Write a short weekly listening report for a music app.
Return JSON only with the shape:
{"title":"Weekly listening report","summary":"short sentence","narrative":"short paragraph","highlights":["bullet 1", "bullet 2", "bullet 3"]}

Use the recent plays and top artists below.

Recent plays:
$recentBlock

Top artists:
$topArtists

Catalog:
$catalog
''';
  }

  String _catalogBlock(List<LibraryItem> library) {
    final items = List<LibraryItem>.of(library)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items
        .take(40)
        .map((item) =>
            '- id:${item.id} | title:${item.title} | artist:${item.author} | added:${item.createdAt.toIso8601String()}')
        .join('\n');
  }

  String _moodTitle(String mood) {
    if (mood.isEmpty) return 'Mood mix';
    return '${mood[0].toUpperCase()}${mood.substring(1)} mix';
  }
}