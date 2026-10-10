import 'package:flutter/material.dart';

import '../../data/datasources/lyrics_datasource.dart';
import '../../domain/entities/library_item.dart';
import '../../domain/entities/lyrics.dart';
import '../controllers/player_controller.dart';
import 'app_colors.dart';

/// Apple Music–style live lyrics: the current line is highlighted and kept in
/// view; tapping a line seeks there. Falls back to plain lyrics.
class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.player, required this.item});

  final PlayerController player;
  final LibraryItem item;

  /// Shared so lyrics stay cached in memory across screens.
  static final LyricsDatasource datasource = LyricsDatasource();

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  Lyrics? _lyrics;
  bool _loading = true;
  bool _failed = false;
  int _active = -1;
  List<GlobalKey> _keys = const [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onTick);
    _load(initial: true);
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_onTick);
      widget.player.addListener(_onTick);
    }
    if (oldWidget.item.id != widget.item.id) _load();
  }

  @override
  void dispose() {
    widget.player.removeListener(_onTick);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false, bool initial = false}) async {
    void reset() {
      _loading = true;
      _failed = false;
      _lyrics = null;
      _active = -1;
    }

    initial ? reset() : setState(reset);
    try {
      if (refresh) await LyricsView.datasource.clear(widget.item);
      final lyrics = await LyricsView.datasource.lyricsFor(widget.item);
      if (!mounted) return;
      setState(() {
        _lyrics = lyrics;
        _keys = List.generate(lyrics.lines.length, (_) => GlobalKey());
        _loading = false;
      });
      _onTick();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onTick() {
    final lyrics = _lyrics;
    if (!mounted || lyrics == null || !lyrics.isSynced) return;
    final i = lyrics.indexAt(widget.player.position);
    if (i == _active) return;
    setState(() => _active = i);
    if (i < 0 || i >= _keys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[i].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentOrange),
      );
    }
    final lyrics = _lyrics;
    if (_failed || lyrics == null || lyrics.isEmpty) {
      return _Message(
        icon: Icons.lyrics_outlined,
        text: _failed
            ? 'Could not load lyrics.\nCheck your connection.'
            : 'No lyrics found for this track.',
        onRetry: () => _load(refresh: true),
      );
    }
    if (!lyrics.isSynced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Text(
          lyrics.plain!.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.7,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ShaderMask(
      // Soft fade at the top and bottom edges.
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.08, 0.92, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lyrics.lines.length; i++)
              _LyricLineTile(
                key: _keys[i],
                text: lyrics.lines[i].text,
                state: i == _active
                    ? _LineState.active
                    : (i < _active ? _LineState.past : _LineState.upcoming),
                onTap: () => widget.player.seek(lyrics.lines[i].time),
              ),
          ],
        ),
      ),
    );
  }
}

enum _LineState { past, active, upcoming }

class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    super.key,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _LineState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == _LineState.active;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: active ? 26 : 22,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: switch (state) {
              _LineState.active => Colors.white,
              _LineState.past => Colors.white38,
              _LineState.upcoming => Colors.white60,
            },
          ),
          child: Text(text.isEmpty ? '♪' : text),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again',
                style: TextStyle(color: AppColors.accentOrange)),
          ),
        ],
      ),
    );
  }
}
