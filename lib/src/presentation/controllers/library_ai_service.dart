import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  final ValueNotifier<String> status = ValueNotifier<String>('Ready');

  Future<List<LibraryItem>> recommendations(List<LibraryItem> library) async {
    final recent = player.recentlyPlayed;
    final signature = _signature([...library, ...recent]);
    final cached = await _readCache('recommendations');
    if (cached != null && cached['signature'] == signature) {
      status.value = 'Smart recommendations loaded from cache';
      return _itemsFromIds(library, cached['ids'] as List? ?? const []);
    }

    status.value = 'Building smart recommendations…';
    final items = _localRecommendations(library, recent, 8);
    await _writeCache('recommendations', {
      'signature': signature,
      'ids': items.map((i) => i.id).toList(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    status.value = items.isEmpty ? 'No recommendations available yet' : 'Smart recommendations ready';
    return items;
  }

  Future<MoodPlaylist> moodPlaylist({
    required List<LibraryItem> library,
    required String mood,
  }) async {
    final recent = player.recentlyPlayed;
    final signature = '${_signature([...library, ...recent])}::$mood';
    final cached = await _readCache('mood:$mood');
    if (cached != null && cached['signature'] == signature) {
      status.value = 'Mood playlist loaded from cache';
      return MoodPlaylist(
        title: cached['title'] as String? ?? _moodTitle(mood),
        summary: cached['summary'] as String? ?? '',
        items: _itemsFromIds(library, cached['ids'] as List? ?? const []),
      );
    }

    status.value = 'Building mood playlist…';
    final items = _localMoodPlaylist(library, recent, mood, 10);
    final title = _moodTitle(mood);
    final summary = _moodSummary(mood, items, recent);
    await _writeCache('mood:$mood', {
      'signature': signature,
      'title': title,
      'summary': summary,
      'ids': items.map((i) => i.id).toList(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    status.value = items.isEmpty ? 'Mood playlist using local fallback' : 'Mood playlist ready';
    return MoodPlaylist(
      title: title,
      summary: summary,
      items: items,
    );
  }

  /// Synchronous, uncached local mood match — used by the mood results sheet
  /// to show "From your library" instantly while YouTube results load.
  List<LibraryItem> moodPlaylistSync(List<LibraryItem> library, String mood) {
    return _localMoodPlaylist(library, player.recentlyPlayed, mood, 12);
  }

  Future<WeeklyListeningReport> weeklyReport(List<LibraryItem> library) async {
    final recent = player.recentlyPlayed;
    final signature = _signature([...library, ...recent]);
    final cached = await _readCache('weekly_report');
    final cachedAt = DateTime.tryParse(cached?['createdAt'] as String? ?? '');
    if (cached != null && cached['signature'] == signature && cachedAt != null) {
      if (DateTime.now().difference(cachedAt) < const Duration(days: 7)) {
        status.value = 'Weekly report loaded from cache';
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

    status.value = 'Building weekly report…';
    final topArtists = _topArtists(library, recent).take(3).toList();
    final highlights = <String>[
      if (recent.isNotEmpty) 'Recent plays: ${recent.length} tracks in your latest queue',
      if (topArtists.isNotEmpty)
        'Top artist: ${topArtists.first.$1} with ${topArtists.first.$2} tracks in rotation',
      if (library.isNotEmpty) 'Library size: ${library.length} items ready for curation',
    ];
    final summary = _weeklySummary(topArtists, recent);
    final narrative = _weeklyNarrative(topArtists, recent, library);
    const title = 'Weekly listening report';

    await _writeCache('weekly_report', {
      'signature': signature,
      'title': title,
      'summary': summary,
      'narrative': narrative,
      'highlights': highlights,
      'createdAt': DateTime.now().toIso8601String(),
    });
    status.value = 'Weekly report ready';
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
      final url = first is Map
          ? first['picture_big'] as String? ?? first['picture_medium'] as String?
          : null;
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

  List<LibraryItem> _localRecommendations(
    List<LibraryItem> library,
    List<LibraryItem> recent,
    int limit,
  ) {
    final recentIds = recent.map((item) => item.id).toSet();
    final recentArtistCounts = <String, int>{};
    for (final item in recent) {
      recentArtistCounts[item.author] = (recentArtistCounts[item.author] ?? 0) + 1;
    }
    final scored = <({LibraryItem item, int score})>[];

    for (final item in library) {
      var score = 0;
      if (!recentIds.contains(item.id)) score += 40;
      score += (recentArtistCounts[item.author] ?? 0) * 60;
      score += _keywordAffinity(item.title, recent) * 2;
      score += _keywordAffinity(item.author, recent);
      score += item.isVideo ? -5 : 10;
      score += item.createdAt.millisecondsSinceEpoch ~/ 100000000;
      scored.add((item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final items = <LibraryItem>[];
    for (final entry in scored) {
      if (items.any((candidate) => candidate.id == entry.item.id)) continue;
      items.add(entry.item);
      if (items.length >= limit) break;
    }

    if (items.isEmpty) {
      items.addAll(_localFallback(library, recent, limit));
    }

    return items.take(limit).toList();
  }

  List<LibraryItem> _localMoodPlaylist(
    List<LibraryItem> library,
    List<LibraryItem> recent,
    String mood,
    int limit,
  ) {
    final terms = _moodTerms(mood);
    final scored = <({LibraryItem item, int score})>[];

    for (final item in library) {
      var score = 0;
      for (final term in terms) {
        if (item.title.toLowerCase().contains(term)) score += 35;
        if (item.author.toLowerCase().contains(term)) score += 20;
      }
      score += _keywordAffinity(item.title, recent);
      score += item.isVideo ? -10 : 5;
      scored.add((item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final items = <LibraryItem>[];
    for (final entry in scored) {
      if (items.any((candidate) => candidate.id == entry.item.id)) continue;
      items.add(entry.item);
      if (items.length >= limit) break;
    }

    if (items.isEmpty) {
      items.addAll(_localFallback(library, recent, limit));
    }

    return items.take(limit).toList();
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

  int _keywordAffinity(String text, List<LibraryItem> recent) {
    final normalized = text.toLowerCase();
    var score = 0;
    for (final item in recent) {
      final recentWords = _words('${item.title} ${item.author}');
      if (recentWords.any(normalized.contains)) {
        score += 8;
      }
    }
    return score;
  }

  List<String> _words(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  List<String> _moodTerms(String mood) => _words(mood);

  String _weeklySummary(List<(String, int)> topArtists, List<LibraryItem> recent) {
    if (recent.isEmpty && topArtists.isEmpty) {
      return 'Your listening report will appear once you start playing more tracks.';
    }
    final artist = topArtists.isEmpty ? 'your favorites' : topArtists.first.$1;
    final recentCount = recent.length;
    return 'This week, $artist shaped most of your listening, with $recentCount recent plays feeding your queue.';
  }

  String _weeklyNarrative(
    List<(String, int)> topArtists,
    List<LibraryItem> recent,
    List<LibraryItem> library,
  ) {
    final artists = topArtists.take(3).map((entry) => entry.$1).toList();
    final artistPhrase = artists.isEmpty
        ? 'a balanced mix of artists'
        : artists.length == 1
            ? artists.first
            : '${artists.sublist(0, artists.length - 1).join(', ')} and ${artists.last}';
    final recentPhrase = recent.isEmpty
        ? 'There were no recent plays to summarize yet.'
        : 'Recent listening stayed active, with ${recent.length} tracks in the latest run.';
    final libraryPhrase = library.isEmpty
        ? 'Your library is still being built out.'
        : 'The catalog now contains ${library.length} items to curate from.';
    return 'Your week leaned toward $artistPhrase. $recentPhrase $libraryPhrase';
  }

  String _moodTitle(String mood) {
    final trimmed = mood.trim();
    if (trimmed.isEmpty) return 'Mood mix';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)} mix';
  }

  String _moodSummary(String mood, List<LibraryItem> items, List<LibraryItem> recent) {
    if (items.isEmpty) {
      return 'No matching tracks were found, so this mix falls back to your library history.';
    }
    final firstArtist = items.first.author;
    final recentCount = recent.length;
    return 'A ${mood.trim().isEmpty ? 'curated' : mood} mix centered around $firstArtist and informed by $recentCount recent plays.';
  }

  String _signature(List<LibraryItem> items) => items
      .map((item) =>
          '${item.id}:${item.title}:${item.author}:${item.createdAt.millisecondsSinceEpoch}')
      .join('|');
}
