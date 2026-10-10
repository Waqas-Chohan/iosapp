import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// One YouTube search hit (UI-friendly, no package types leak out).
class SearchHit {
  const SearchHit({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
    this.viewCount,
    this.isLive = false,
  });

  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;
  final int? viewCount;
  final bool isLive;

  String get url => 'https://www.youtube.com/watch?v=$videoId';
}

/// In-app YouTube search + query suggestions (youtube_explode_dart).
class YoutubeSearchDatasource {
  final YoutubeExplode _yt = YoutubeExplode();
  VideoSearchList? _page;

  /// First page of results for [query] (~20 videos).
  Future<List<SearchHit>> search(String query) async {
    _page = await _yt.search.search(query);
    return _toHits(_page!);
  }

  /// Next page of the last search, or an empty list when there is none.
  Future<List<SearchHit>> more() async {
    final current = _page;
    if (current == null) return const [];
    final next = await current.nextPage();
    if (next == null) return const [];
    _page = next;
    return _toHits(next);
  }

  /// Autocomplete suggestions while typing.
  Future<List<String>> suggestions(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      return await _yt.search.getQuerySuggestions(query);
    } catch (_) {
      return const [];
    }
  }

  List<SearchHit> _toHits(List<Video> videos) => videos
      .map((v) => SearchHit(
            videoId: v.id.value,
            title: v.title,
            author: v.author,
            thumbnailUrl: v.thumbnails.mediumResUrl,
            duration: v.duration,
            viewCount: v.engagement.viewCount,
            isLive: v.isLive,
          ))
      .toList();

  void close() => _yt.close();
}
