import 'package:flutter/material.dart';

import '../app_services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'ui_kit.dart';

/// "Import" flow: choose Photos or Files, copy the media in, add to Library.
Future<void> importMedia(BuildContext context, AppServices services) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Text('Import to your Library',
                  style: AppTextStyles.sectionTitle),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Copies are stored in Muz, the originals stay put.',
                style: AppTextStyles.optionSubtitle,
              ),
            ),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFFE8572F),
              title: 'Videos from Photos',
              subtitle: 'Pick one or more videos',
              onTap: () => Navigator.of(ctx).pop('photos'),
            ),
            _SourceTile(
              icon: Icons.folder_rounded,
              color: const Color(0xFF2D7FF9),
              title: 'From Files',
              subtitle: 'Videos and audio (MP4, MOV, M4A, MP3, WAV…)',
              onTap: () => Navigator.of(ctx).pop('files'),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  List<String> paths;
  try {
    paths = source == 'photos'
        ? await services.importer.pickFromPhotos()
        : await services.importer.pickFromFiles();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open picker: $e')));
    return;
  }
  if (paths.isEmpty || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.accentOrange),
            SizedBox(width: 18),
            Expanded(child: Text('Importing…')),
          ],
        ),
      ),
    ),
  );
  var count = 0;
  try {
    final items = await services.importer.import(paths);
    for (final item in items) {
      await services.library.add(item);
      count++;
    }
  } finally {
    navigator.pop();
  }
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text(count == 0
        ? 'Nothing was imported (unsupported file type?)'
        : 'Imported $count item${count == 1 ? '' : 's'} to your Library'),
  ));
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title,
          style: AppTextStyles.optionTitle.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTextStyles.optionSubtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: Ui.gutter - 8),
    );
  }
}
