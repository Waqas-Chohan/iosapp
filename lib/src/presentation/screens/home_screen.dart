import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/download_task.dart';
import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/artwork.dart';
import '../components/collection_sheets.dart';
import '../components/format.dart';
import '../components/import_actions.dart';
import '../components/ui_kit.dart';
import 'personalize_screen.dart';
import 'playlist_screen.dart';
import 'youtube_search_screen.dart';

/// Premium home: brand header with search, a sliding carousel of your
/// library, quick picks, playlists, recently added and videos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.services, this.onOpenTab});

  final AppServices services;

  /// Switches the bottom navigation tab (0 Home, 1 Search, 2 Library,
  /// 3 Downloads).
  final ValueChanged<int>? onOpenTab;

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YoutubeSearchScreen(services: services),
      ),
    );
  }

  Future<void> _newPlaylist(BuildContext context) async {
    final c = await showCreateCollectionSheet(context, services);
    if (c == null || !context.mounted) return;
    openPlaylist(context, services, c.id, promptAdd: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = services;
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListenableBuilder(
        listenable: s.libraryChanges,
        builder: (context, _) {
          final items = List.of(s.library.items)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final videos = items.where((i) => i.isVideo).toList();
          final collections = s.collections.collections;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  services: s,
                  onSearch: () => _openSearch(context),
                  onImport: () => importMedia(context, s),
                  onDownloads: () => onOpenTab?.call(3),
                ),
              ),
              SliverToBoxAdapter(
                child: _DownloadsBanner(
                  services: s,
                  onTap: () => onOpenTab?.call(3),
                ),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: EmptyState(
                      icon: Icons.headphones_rounded,
                      title: 'Your music lives here',
                      message: 'Search any song or video, pick a quality and '
                          'download it — or import videos from your iPhone.',
                      actions: [
                        PillButton(
                          label: 'Search & download',
                          icon: Icons.search_rounded,
                          onPressed: () => _openSearch(context),
                        ),
                        PillButton(
                          label: 'Import videos',
                          icon: Icons.add_photo_alternate_outlined,
                          outlined: true,
                          onPressed: () => importMedia(context, s),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'From your library',
                    subtitle: 'Swipe through your latest picks',
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FeaturedCarousel(
                    items: items.take(10).toList(),
                    onPlay: (i) =>
                        s.playAndOpen(context, items.take(10).toList(), index: i),
                  ),
                ),
                if (items.length >= 2)
                  SliverToBoxAdapter(
                    child: _QuickPicks(
                      items: items.take(6).toList(),
                      services: s,
                    ),
                  ),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Your playlists',
                  subtitle: collections.isEmpty
                      ? 'Group songs into playlists and albums'
                      : null,
                  action: collections.isEmpty ? null : 'See all',
                  onAction: () => onOpenTab?.call(2),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 206,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
                    children: [
                      _NewPlaylistCard(onTap: () => _newPlaylist(context)),
                      for (final c in collections)
                        _CoverCard(
                          title: c.name,
                          subtitle:
                              '${c.type} · ${c.itemIds.length} item${c.itemIds.length == 1 ? '' : 's'}',
                          cover: CollectionCover(
                            items: s.collections.itemsOf(c, s.library.items),
                            size: 150,
                            isAlbum: c.isAlbum,
                            borderRadius: 16,
                          ),
                          onTap: () => openPlaylist(context, s, c.id),
                        ),
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Recently added',
                    action: 'Library',
                    onAction: () => onOpenTab?.call(2),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 206,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: Ui.gutter),
                      itemCount: items.length.clamp(0, 15).toInt(),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return _CoverCard(
                          title: item.title,
                          subtitle: item.author,
                          cover: Artwork.item(item,
                              size: 150, borderRadius: 16),
                          onTap: () => s.playAndOpen(context, items, index: i),
                          onLongPress: () => showTrackActions(
                              context, s, item, queue: items),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (videos.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Videos',
                    subtitle: 'Play in the app or in Photos',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 182,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: Ui.gutter),
                      itemCount: videos.length,
                      itemBuilder: (context, i) => _VideoCard(
                        item: videos[i],
                        onTap: () => s.playAndOpen(context, videos, index: i),
                        onLongPress: () => showTrackActions(
                            context, s, videos[i], queue: videos),
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------- header ----

class _Header extends StatelessWidget {
  const _Header({
    required this.services,
    required this.onSearch,
    required this.onImport,
    required this.onDownloads,
  });

  final AppServices services;
  final VoidCallback onSearch;
  final VoidCallback onImport;
  final VoidCallback onDownloads;

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final lib = services.library;
    final stats = <String>[
      '${lib.songs.length} songs',
      '${lib.videos.length} videos',
      '${services.collections.collections.length} playlists',
    ].join('  ·  ');
    return Container(
      decoration: const BoxDecoration(
        gradient: Ui.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Ui.gutter, 10, 10, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Splash-screen logo, used as the brand mark on Home too.
                  Image.asset(
                    'assets/images/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Musically',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Personalize',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PersonalizeScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.palette_outlined,
                        color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Import videos',
                    onPressed: onImport,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white),
                  ),
                  ListenableBuilder(
                    listenable: services.downloads,
                    builder: (context, _) {
                      final n = services.downloads.inProgressCount;
                      return IconButton(
                        tooltip: 'Downloads',
                        onPressed: onDownloads,
                        icon: Badge(
                          isLabelVisible: n > 0,
                          label: Text('$n'),
                          backgroundColor: AppColors.accentOrange,
                          child: const Icon(Icons.download_rounded,
                              color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _greeting(),
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stats,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  key: const Key('home-search'),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: onSearch,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: AppColors.splashNavy),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search songs, artists, videos',
                              style: AppTextStyles.inputHint,
                            ),
                          ),
                          Icon(Icons.download_for_offline_outlined,
                              color: AppColors.accentOrange),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- downloads bar ----

class _DownloadsBanner extends StatelessWidget {
  const _DownloadsBanner({required this.services, required this.onTap});

  final AppServices services;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.downloads,
      builder: (context, _) {
        final running = services.downloads.active
            .where((t) =>
                t.state == DownloadState.downloading ||
                t.state == DownloadState.queued ||
                t.state == DownloadState.processing)
            .toList();
        if (running.isEmpty) return const SizedBox.shrink();
        final total = running.fold<int>(0, (a, t) => a + t.total);
        final got = running.fold<int>(0, (a, t) => a + t.received);
        final progress = total > 0 ? got / total : null;
        final first = running.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Ui.gutter, 16, Ui.gutter, 0),
          child: Material(
            color: const Color(0xFFFFF3EA),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3.5,
                            color: AppColors.accentOrange,
                            backgroundColor: Colors.white,
                          ),
                          const Icon(Icons.download_rounded,
                              size: 18, color: AppColors.accentOrange),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            running.length == 1
                                ? 'Downloading 1 item'
                                : 'Downloading ${running.length} items',
                            style: AppTextStyles.optionTitle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${first.option.label} · ${first.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.optionSubtitle,
                          ),
                        ],
                      ),
                    ),
                    if (progress != null)
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textGray),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ carousel ----

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.items, required this.onPlay});

  final List<LibraryItem> items;
  final ValueChanged<int> onPlay;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final PageController _pages = PageController(viewportFraction: 0.8);
  Timer? _auto;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void didUpdateWidget(covariant _FeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      if (_index >= widget.items.length) _index = 0;
      _startAuto();
    }
  }

  void _startAuto() {
    _auto?.cancel();
    if (widget.items.length < 2) return;
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pages.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _startAuto(); // user swiped
              return false;
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  var page = _index.toDouble();
                  if (_pages.hasClients && _pages.position.haveDimensions) {
                    page = _pages.page ?? page;
                  }
                  final d = (page - i).abs().clamp(0.0, 1.0);
                  return Transform.scale(scale: 1 - d * 0.08, child: child);
                },
                child: _FeaturedCard(
                  item: items[i],
                  onTap: () => widget.onPlay(i),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _index
                      ? AppColors.accentOrange
                      : const Color(0xFFDADFE6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: Ui.softShadow(0.22),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  Artwork.item(
                    item,
                    width: c.maxWidth,
                    height: c.maxHeight,
                    borderRadius: 0,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xE6071A38)],
                        stops: [0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isVideo
                                ? Icons.movie_outlined
                                : Icons.music_note_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            [
                              item.isVideo ? 'Video' : 'Audio',
                              if (item.qualityLabel.isNotEmpty)
                                item.qualityLabel,
                            ].join(' · '),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 19,
                                  height: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  item.author,
                                  if (item.duration != null)
                                    formatDuration(item.duration),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: Ui.accentGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentOrange
                                    .withValues(alpha: 0.5),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------- quick picks ----

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.items, required this.services});

  final List<LibraryItem> items;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Jump back in'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 60,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Material(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => services.playAndOpen(context, items, index: i),
                  onLongPress: () =>
                      showTrackActions(context, services, item, queue: items),
                  child: Row(
                    children: [
                      Artwork.item(item, size: 60, borderRadius: 0),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.optionTitle.copyWith(
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- cards ----

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Ui.softShadow(0.12),
                ),
                child: cover,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionTitle
                    .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionSubtitle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPlaylistCard extends StatelessWidget {
  const _NewPlaylistCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E7EC)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.accentOrange,
                      child: Icon(Icons.add_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New playlist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionTitle
                    .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              Text(
                'Playlist or album',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionSubtitle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Artwork.item(item,
                      width: 220, height: 124, borderRadius: 16),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  if (item.duration != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatDuration(item.duration),
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
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionTitle
                    .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              Text(
                '${item.qualityLabel} · ${item.author}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.optionSubtitle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
