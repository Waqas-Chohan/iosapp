import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/video_repository_impl.dart';
import '../../domain/entities/video_download_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/download_progress_panel.dart';
import '../components/format.dart';
import '../components/video_info_card.dart';
import '../controllers/download_controller.dart';
import '../controllers/library_model.dart';
import '../controllers/player_controller.dart';
import 'player_screen.dart';

/// Musically home — paste/type a link, pick a quality, download it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository, this.player, this.libraryModel});

  /// Injectable repository (tests); defaults to the real stack.
  final VideoRepository? repository;

  /// Shared player (provided by the app shell).
  final PlayerController? player;

  /// Shared library (provided by the app shell).
  final LibraryModel? libraryModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();
  late final DownloadController _controller;
  StreamOption? _selectedOption;

  @override
  void initState() {
    super.initState();
    _controller = DownloadController(
      widget.repository ?? VideoRepositoryImpl(),
      libraryRepository: widget.libraryModel?.repository,
    );
  }

  @override
  void dispose() {
    _linkController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    setState(() => _linkController.text = text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.music_note, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Musically',
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.splashNavy,
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputCard(),
                const SizedBox(height: 16),
                ..._buildBody(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputCard() {
    final busy = _controller.status == DownloadStatus.loading ||
        _controller.status == DownloadStatus.downloading;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YouTube Link', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _linkController,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onFetchPressed(),
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Paste a YouTube link…',
                    hintStyle: AppTextStyles.inputHint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy ? null : _pasteFromClipboard,
                tooltip: 'Paste from clipboard',
                icon:
                    const Icon(Icons.content_paste, color: AppColors.splashNavy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: busy ? null : _onFetchPressed,
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Fetch Video'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody() {
    switch (_controller.status) {
      case DownloadStatus.idle:
        return const [
          SizedBox(height: 24),
          Icon(Icons.cloud_download_outlined,
              size: 64, color: AppColors.textGray),
          SizedBox(height: 12),
          Text(
            'Paste a YouTube link above to start.\n'
            'Muxed qualities (video + audio) are available up to '
            'the video\u2019s best combined stream.',
            textAlign: TextAlign.center,
            style: AppTextStyles.description,
          ),
        ];
      case DownloadStatus.loading:
        return const [
          SizedBox(height: 40),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 12),
          Center(
            child:
                Text('Fetching video info…', style: AppTextStyles.description),
          ),
        ];
      case DownloadStatus.error:
        return [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.errorRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _controller.errorMessage ?? 'Something went wrong.',
                    style: AppTextStyles.videoMeta
                        .copyWith(color: AppColors.errorRed),
                  ),
                ),
              ],
            ),
          ),
        ];
      case DownloadStatus.ready:
        final info = _controller.info!;
        final options = info.streams;
        if (options.isEmpty) {
          return const [
            SizedBox(height: 20),
            Text(
              'No downloadable formats for this video on your network.',
              style: AppTextStyles.description,
            ),
          ];
        }
        final selected =
            options.contains(_selectedOption) ? _selectedOption! : options.first;
        return [
          VideoInfoCard(info: info),
          const SizedBox(height: 18),
          Text('Choose a format', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 10),
          DropdownButtonFormField<StreamOption>(
            key: ValueKey(info.videoId),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: options
                .map((o) => DropdownMenuItem<StreamOption>(
                      value: o,
                      child: Text(
                        _formatOptionLabel(o),
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.optionTitle,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedOption = v),
          ),
          const SizedBox(height: 6),
          Text(
            'Only formats that work on your network are listed.',
            style: AppTextStyles.optionSubtitle,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _startDownload(selected),
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Download'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ];
      case DownloadStatus.downloading:
        return [
          DownloadProgressPanel(
            progress: _controller.progress,
            totalLabel: _controller.totalLabel,
            speedLabel: _controller.speedLabel,
            onCancel: _controller.cancel,
          ),
        ];
      case DownloadStatus.done:
        return _buildDonePanel();
    }
  }

  String _formatOptionLabel(StreamOption o) {
    final kind = o.category == StreamCategory.audio
        ? 'Audio'
        : 'Video + Audio';
    final size =
        o.sizeBytes != null ? ' · ${formatBytes(o.sizeBytes)}' : '';
    final hls = o.isFragmentBased ? ' · HLS' : '';
    return '${o.label} · ${o.container} · $kind$size$hls';
  }

  /// Runs a download, then keeps Library + Photos in sync automatically.
  Future<void> _startDownload(StreamOption option) async {
    await _controller.startDownload(option);
    if (!mounted) return;

    // 1) The item is already persisted — refresh the Library view.
    await widget.libraryModel?.refresh();
    if (!mounted) return;

    // 2) Videos are also pushed to the iOS Photos library automatically.
    final item = _controller.downloadedItem;
    if (item == null || !item.isVideo) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.saveToGallery();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved to your Library and Photos ✓'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Photos save skipped: $e')),
      );
    }
  }

  List<Widget> _buildDonePanel() {
    final path = _controller.downloadedPath;
    final isVideo = _controller.downloadedCategory == StreamCategory.muxed;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.accentOrange, size: 22),
                SizedBox(width: 8),
                Text('Download complete!', style: AppTextStyles.sectionTitle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              path ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.optionSubtitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Added to your Library ✓',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.splashBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.play_circle_fill,
                    label: 'Play',
                    backgroundColor: AppColors.splashNavy,
                    onPressed: path == null ? null : _onPlayDownloaded,
                  ),
                ),
                const SizedBox(width: 10),
                if (isVideo)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Save to Photos',
                      backgroundColor: AppColors.accentOrange,
                      onPressed: path == null ? null : _onSaveToGallery,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _controller.reset,
        icon: const Icon(Icons.add_link),
        label: const Text('Download another video'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.splashNavy,
          side: const BorderSide(color: AppColors.splashNavy),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    ];
  }

  Future<void> _onPlayDownloaded() async {
    final item = _controller.downloadedItem;
    final player = widget.player;
    if (item == null || player == null) return;
    await player.playQueue([item]);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(player: player),
      ),
    );
  }

  Future<void> _onFetchPressed() async {
    setState(() => _selectedOption = null);
    await _controller.fetchVideo(_linkController.text);
  }

  Future<void> _onSaveToGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.saveToGallery();
      messenger.showSnackBar(
        const SnackBar(content: Text('Saved to your Photos library!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
      ),
    );
  }
}
