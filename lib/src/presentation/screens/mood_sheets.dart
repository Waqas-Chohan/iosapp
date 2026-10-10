import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/datasources/moods_datasource.dart';
import '../../data/datasources/youtube_search_datasource.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/download_options_sheet.dart';
import '../components/ui_kit.dart';
import 'downloads_screen.dart';

/// A selectable mood with its own accent color so the UI feels dynamic.
class MoodPreset {
  const MoodPreset(this.name, this.color, this.icon);

  final String name;
  final Color color;
  final IconData icon;
}

/// The three built-in moods shown first.
const List<MoodPreset> _presets = [
  MoodPreset('Chill', Color(0xFF2E9E8F), Icons.spa_rounded),
  MoodPreset('Workout', Color(0xFFFE6E04), Icons.fitness_center_rounded),
  MoodPreset('Focus', Color(0xFF4C6FFF), Icons.center_focus_strong_rounded),
];

/// A rotating palette used to color custom moods the user adds.
const List<Color> _customPalette = [
  Color(0xFFB14BFF),
  Color(0xFFFF4D6D),
  Color(0xFF00B8A9),
  Color(0xFFF4A261),
  Color(0xFF3A86FF),
  Color(0xFF8338EC),
];

Color _colorForMood(String mood) {
  for (final p in _presets) {
    if (p.name.toLowerCase() == mood.toLowerCase()) return p.color;
  }
  final sum = mood.codeUnits.fold<int>(0, (a, b) => a + b);
  return _customPalette[sum % _customPalette.length];
}

IconData _iconForMood(String mood) {
  for (final p in _presets) {
    if (p.name.toLowerCase() == mood.toLowerCase()) return p.icon;
  }
  return Icons.auto_awesome_rounded;
}

/// Opens the mood picker. Returns the chosen mood name (or null).
Future<String?> showMoodPicker(BuildContext context, AppServices services) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _MoodPickerSheet(services: services),
  );
}

class _MoodPickerSheet extends StatefulWidget {
  const _MoodPickerSheet({required this.services});

  final AppServices services;

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  final MoodsStore _store = MoodsStore();
  List<String> _custom = const [];

  @override
  void initState() {
    super.initState();
    _store.load().then((list) {
      if (mounted) setState(() => _custom = list);
    });
  }

  Future<void> _addMood() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New mood', style: AppTextStyles.sectionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.inputText,
          decoration: const InputDecoration(
            hintText: 'e.g. Late night',
            hintStyle: AppTextStyles.inputHint,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add', style: TextStyle(color: AppColors.accentOrange)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final updated = [..._custom, name];
    await _store.save(updated);
    if (!mounted) return;
    setState(() => _custom = updated);
    // Immediately open the results for the new mood.
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final moods = <String>[..._presets.map((p) => p.name), ..._custom];
    return _GlassScaffold(
      safeBottom: safeBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GlassHandle(),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mood playlists', style: AppTextStyles.sectionTitle),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Pick a vibe — we mix your library and fresh finds from YouTube.',
              style: AppTextStyles.optionSubtitle,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final mood in moods)
                  _MoodChip(
                    mood: mood,
                    color: _colorForMood(mood),
                    icon: _iconForMood(mood),
                    onTap: () => Navigator.of(context).pop(mood),
                  ),
                _AddMoodChip(onTap: _addMood),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Shared frosted-glass container used by every mood sheet.
class _GlassScaffold extends StatelessWidget {
  const _GlassScaffold({required this.child, required this.safeBottom});

  final Widget child;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + safeBottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(28),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.splashNavy.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }
}

class _GlassHandle extends StatelessWidget {
  const _GlassHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: AppColors.textGray.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String mood;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                mood,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMoodChip extends StatelessWidget {
  const _AddMoodChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentOrange.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: AppColors.accentOrange, size: 20),
              SizedBox(width: 6),
              Text(
                'Add mood',
                style: TextStyle(
                  color: AppColors.accentOrange,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the results for [mood]: your library matches on top, live YouTube
/// finds below. Each YouTube row can be sent to the download queue.
Future<void> showMoodResults(
  BuildContext context,
  AppServices services,
  String mood,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _MoodResultsSheet(services: services, mood: mood),
  );
}

class _MoodResultsSheet extends StatefulWidget {
  const _MoodResultsSheet({required this.services, required this.mood});

  final AppServices services;
  final String mood;

  @override
  State<_MoodResultsSheet> createState() => _MoodResultsSheetState();
}

class _MoodResultsSheetState extends State<_MoodResultsSheet> {
  final YoutubeSearchDatasource _search = YoutubeSearchDatasource();
  List<SearchHit> _hits = const [];
  bool _loadingYt = true;
  String? _ytError;

  Color get _color => _colorForMood(widget.mood);

  @override
  void initState() {
    super.initState();
    _loadYoutube();
  }

  @override
  void dispose() {
    _search.close();
    super.dispose();
  }

  Future<void> _loadYoutube() async {
    try {
      final hits = await _search.search('${widget.mood} music');
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loadingYt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingYt = false;
        _ytError = 'Could not load YouTube results right now.';
      });
    }
  }

  Future<void> _download(SearchHit hit) async {
    FocusScope.of(context).unfocus();
    final task = await showDownloadOptions(
      context,
      downloads: widget.services.downloads,
      videoId: hit.videoId,
      title: hit.title,
      author: hit.author,
      thumbnailUrl: hit.thumbnailUrl,
      duration: hit.duration,
    );
    if (task == null || !mounted) return;
    Ui.snack(
      context,
      'Downloading ${task.option.label} · ${task.title}',
      action: 'View',
      onAction: () => openDownloads(context, widget.services),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final library = widget.services.ai
        .moodPlaylistSync(widget.services.library.items, widget.mood);
    return _GlassScaffold(
      safeBottom: safeBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GlassHandle(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_color, _color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_iconForMood(widget.mood), color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.mood[0].toUpperCase()}${widget.mood.substring(1)} mix',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Sora',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${library.length} from your library · fresh finds below',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Poppins',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (library.isNotEmpty)
                    IconButton(
                      tooltip: 'Play all',
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.services.playAndOpen(context, library);
                      },
                      icon: const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 40),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (library.isNotEmpty) ...[
                  const _SheetSection('From your library'),
                  for (final item in library)
                    TrackTile(
                      item: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.services.playAndOpen(context, library,
                            index: library.indexOf(item));
                      },
                    ),
                ],
                const _SheetSection('From YouTube'),
                if (_loadingYt)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accentOrange),
                    ),
                  )
                else if (_ytError != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(_ytError!, style: AppTextStyles.optionSubtitle),
                    ),
                  )
                else
                  for (final hit in _hits)
                    _MoodYtTile(hit: hit, color: _color, onDownload: () => _download(hit)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ui.gutter, 10, Ui.gutter, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppTextStyles.sectionTitle),
      ),
    );
  }
}

class _MoodYtTile extends StatelessWidget {
  const _MoodYtTile({
    required this.hit,
    required this.color,
    required this.onDownload,
  });

  final SearchHit hit;
  final Color color;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              hit.thumbnailUrl,
              width: 108,
              height: 61,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 108,
                height: 61,
                color: AppColors.inputFill,
                child: const Icon(Icons.music_note, color: AppColors.textGray),
              ),
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
                  style: AppTextStyles.optionTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  hit.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.optionSubtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: onDownload,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.download_rounded, color: AppColors.accentOrange, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
