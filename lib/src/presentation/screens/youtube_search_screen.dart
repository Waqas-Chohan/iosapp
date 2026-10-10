import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/datasources/youtube_search_datasource.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';

/// Search YouTube inside the app. Tapping a result returns it to the caller
/// (the Home screen then fetches its formats for download).
class YoutubeSearchScreen extends StatefulWidget {
  const YoutubeSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<YoutubeSearchScreen> createState() => _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends State<YoutubeSearchScreen> {
  final YoutubeSearchDatasource _source = YoutubeSearchDatasource();
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  List<String> _suggestions = const [];
  List<SearchHit> _results = const [];
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showSuggestions = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    _source.close();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() => _showSuggestions = text.trim().isNotEmpty);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final list = await _source.suggestions(text);
      if (!mounted || _query.text != text) return;
      setState(() => _suggestions = list.take(8).toList());
    });
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _query.text = q;
    setState(() {
      _searching = true;
      _showSuggestions = false;
      _error = null;
      _hasMore = true;
    });
    try {
      final hits = await _source.search(q);
      if (!mounted) return;
      setState(() {
        _results = hits;
        _searching = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_loadingMore || !_hasMore || _results.isEmpty) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 600) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _source.more();
      if (!mounted) return;
      setState(() {
        final seen = _results.map((r) => r.videoId).toSet();
        _results = [..._results, ...more.where((m) => seen.add(m.videoId))];
        _hasMore = more.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.splashNavy,
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.textGray, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _query,
                  autofocus: widget.initialQuery.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _search,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Search songs, artists, videos…',
                    hintStyle: AppTextStyles.inputHint,
                  ),
                ),
              ),
              if (_query.text.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textGray),
                  onPressed: () => setState(() {
                    _query.clear();
                    _suggestions = const [];
                    _showSuggestions = false;
                  }),
                ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_showSuggestions && _suggestions.isNotEmpty) {
      return ListView(
        children: [
          for (final s in _suggestions)
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.textGray),
              title: Text(s, style: AppTextStyles.optionTitle),
              trailing: IconButton(
                icon: const Icon(Icons.north_west, size: 18, color: AppColors.textGray),
                tooltip: 'Edit',
                onPressed: () {
                  _query.text = s;
                  _query.selection = TextSelection.collapsed(offset: s.length);
                  _onChanged(s);
                },
              ),
              onTap: () => _search(s),
            ),
        ],
      );
    }
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentOrange),
      );
    }
    if (_error != null) {
      return _Empty(icon: Icons.wifi_off, text: _error!);
    }
    if (_results.isEmpty) {
      return const _Empty(
        icon: Icons.travel_explore,
        text: 'Search YouTube and tap a result to download it.',
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            ),
          );
        }
        final hit = _results[i];
        return _ResultTile(
          hit: hit,
          onTap: () => Navigator.of(context).pop(hit),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.network(
                  hit.thumbnailUrl,
                  width: 150,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 150,
                    height: 84,
                    color: AppColors.inputFill,
                    child: const Icon(Icons.music_note, color: AppColors.textGray),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hit.isLive ? AppColors.errorRed : Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hit.isLive ? 'LIVE' : _duration(hit.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.optionTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  [hit.author, if (hit.viewCount != null) _views(hit.viewCount!)]
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.optionSubtitle,
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.download_outlined, size: 16, color: AppColors.accentOrange),
                    SizedBox(width: 4),
                    Text('Tap to download',
                        style: TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }

  static String _views(int v) {
    if (v >= 1000000000) return '${(v / 1e9).toStringAsFixed(1)}B views';
    if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M views';
    if (v >= 1000) return '${(v / 1e3).toStringAsFixed(1)}K views';
    return '$v views';
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textGray),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.description),
          ],
        ),
      ),
    );
  }
}
