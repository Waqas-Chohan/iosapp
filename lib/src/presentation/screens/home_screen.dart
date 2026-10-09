import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/video_repository_impl.dart';
import '../../domain/repositories/video_repository.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/download_progress_panel.dart';
import '../components/preview_dialog.dart';
import '../components/stream_option_tile.dart';
import '../components/video_info_card.dart';
import '../controllers/download_controller.dart';

/// Musically home — paste/type a link, pick a quality, download it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});

  /// Injectable repository (tests); defaults to the real stack.
  final VideoRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();
  late final DownloadController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        DownloadController(widget.repository ?? VideoRepositoryImpl());
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
        return [
          VideoInfoCard(info: info),
          const SizedBox(height: 20),
          Text('Available Downloads', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 10),
          if (info.streams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No directly downloadable streams for this video.',
                style: AppTextStyles.description,
              ),
            )
          else
            ...info.streams.map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StreamOptionTile(
                    option: option,
                    onTap: () => _controller.startDownload(option),
                  ),
                )),
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

  List<Widget> _buildDonePanel() {
    final path = _controller.downloadedPath;
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.play_circle_fill,
                    label: 'Preview',
                    backgroundColor: AppColors.splashNavy,
                    onPressed: path == null
                        ? null
                        : () => showVideoPreview(context, path),
                  ),
                ),
                const SizedBox(width: 10),
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

  Future<void> _onFetchPressed() async {
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
