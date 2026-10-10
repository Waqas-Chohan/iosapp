import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../app_services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'artwork.dart';
import 'ui_kit.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
);

Widget _grabber() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDADFE6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

// ------------------------------------------------------------ create ------

/// Asks for a name + type and creates the collection (with [itemIds]).
Future<LibraryCollection?> showCreateCollectionSheet(
  BuildContext context,
  AppServices services, {
  List<String> itemIds = const [],
  String type = LibraryCollection.playlist,
}) {
  return showModalBottomSheet<LibraryCollection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (_) => _CreateSheet(
      services: services,
      itemIds: itemIds,
      initialType: type,
    ),
  );
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({
    required this.services,
    required this.itemIds,
    required this.initialType,
  });

  final AppServices services;
  final List<String> itemIds;
  final String initialType;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final TextEditingController _name = TextEditingController();
  late String _type = widget.initialType;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final c = await widget.services.collections.create(
      _name.text,
      type: _type,
      itemIds: widget.itemIds,
    );
    navigator.pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final isAlbum = _type == LibraryCollection.album;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grabber(),
            const SizedBox(height: 8),
            Center(
              child: CollectionCover(
                items: const [],
                size: 112,
                isAlbum: isAlbum,
                borderRadius: 18,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isAlbum ? 'Give your album a name' : 'Give your playlist a name',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.splashNavy,
              ),
              decoration: InputDecoration(
                hintText: isAlbum ? 'My album' : 'My playlist',
                hintStyle: const TextStyle(color: Color(0xFFB9C0CA)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFDADFE6)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: AppColors.accentOrange, width: 2),
                ),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: LibraryCollection.playlist,
                  icon: Icon(Icons.queue_music_rounded),
                  label: Text('Playlist'),
                ),
                ButtonSegment(
                  value: LibraryCollection.album,
                  icon: Icon(Icons.album_rounded),
                  label: Text('Album'),
                ),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: widget.itemIds.isEmpty
                  ? 'Create'
                  : 'Create with ${widget.itemIds.length} item'
                      '${widget.itemIds.length == 1 ? '' : 's'}',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- rename/delete ----

Future<void> showRenameCollectionDialog(
  BuildContext context,
  AppServices services,
  LibraryCollection collection,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: collection.name),
  );
  if (name == null || name.trim().isEmpty) return;
  await services.collections.rename(collection.id, name);
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ---------------------------------------------------- add to playlist -----

/// "Add to playlist" picker for one or more library items.
Future<void> showAddToCollectionSheet(
  BuildContext context,
  AppServices services,
  List<LibraryItem> items,
) async {
  if (items.isEmpty) return;
  final ids = items.map((i) => i.id).toList();
  final messenger = ScaffoldMessenger.of(context);
  final result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ListenableBuilder(
        listenable: services.libraryChanges,
        builder: (ctx, _) {
          final collections = services.collections.collections;
          return ListView(
            controller: scroll,
            children: [
              _grabber(),
              const Padding(
                padding: EdgeInsets.fromLTRB(Ui.gutter, 6, Ui.gutter, 10),
                child: Text('Add to playlist', style: AppTextStyles.sectionTitle),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: Ui.gutter),
                leading: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.splashNavy, size: 30),
                ),
                title: const Text('New playlist',
                    style: AppTextStyles.optionTitle),
                onTap: () => Navigator.of(ctx).pop('__new__'),
              ),
              for (final c in collections)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: Ui.gutter),
                  leading: CollectionCover(
                    items: services.collections
                        .itemsOf(c, services.library.items),
                    size: 54,
                    isAlbum: c.isAlbum,
                    borderRadius: 10,
                  ),
                  title: Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.optionTitle),
                  subtitle: Text(
                    '${c.type} · ${c.itemIds.length} items',
                    style: AppTextStyles.optionSubtitle,
                  ),
                  trailing: ids.every(c.itemIds.contains)
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accentOrange)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(c.id),
                ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    ),
  );
  if (result == null) return;
  if (result == '__new__') {
    if (!context.mounted) return;
    final c = await showCreateCollectionSheet(context, services, itemIds: ids);
    if (c != null) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Created “${c.name}”'),
      ));
    }
    return;
  }
  final added = await services.collections.addItems(result, ids);
  final name = services.collections.byId(result)?.name ?? 'playlist';
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text(added == 0
        ? 'Already in “$name”'
        : 'Added ${added == 1 ? '1 item' : '$added items'} to “$name”'),
  ));
}

// ------------------------------------------------------- pick songs -------

/// Multi-select picker over the library. Returns the chosen ids.
Future<List<String>?> showPickSongsSheet(
  BuildContext context,
  AppServices services, {
  Set<String> exclude = const {},
  String title = 'Add songs',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (_) => _PickSongsSheet(
      services: services,
      exclude: exclude,
      title: title,
    ),
  );
}

class _PickSongsSheet extends StatefulWidget {
  const _PickSongsSheet({
    required this.services,
    required this.exclude,
    required this.title,
  });

  final AppServices services;
  final Set<String> exclude;
  final String title;

  @override
  State<_PickSongsSheet> createState() => _PickSongsSheetState();
}

class _PickSongsSheetState extends State<_PickSongsSheet> {
  final TextEditingController _q = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim().toLowerCase();
    final items = widget.services.library.items.where((i) {
      if (widget.exclude.contains(i.id)) return false;
      if (query.isEmpty) return true;
      return '${i.title} ${i.author}'.toLowerCase().contains(query);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          _grabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(Ui.gutter, 4, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: AppTextStyles.sectionTitle),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                  child: Text(
                    _selected.isEmpty ? 'Done' : 'Add ${_selected.length}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search your library',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('Nothing to add yet.',
                        style: AppTextStyles.description),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final on = _selected.contains(item.id);
                      return TrackTile(
                        item: item,
                        onTap: () => setState(() {
                          on ? _selected.remove(item.id) : _selected.add(item.id);
                        }),
                        trailing: Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: on
                              ? AppColors.accentOrange
                              : AppColors.textGray,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ track actions -----

/// Long-press / ⋮ menu for a library item.
Future<void> showTrackActions(
  BuildContext context,
  AppServices services,
  LibraryItem item, {
  LibraryCollection? collection,
  List<LibraryItem>? queue,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (ctx) {
      Widget tile(IconData icon, String label, String value,
              {Color color = AppColors.splashNavy}) =>
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
            leading: Icon(icon, color: color),
            title: Text(label,
                style: AppTextStyles.optionTitle.copyWith(color: color)),
            onTap: () => Navigator.of(ctx).pop(value),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Ui.gutter),
              leading: Artwork.item(item, size: 52, borderRadius: 10),
              title: Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.optionTitle
                      .copyWith(fontWeight: FontWeight.w600)),
              subtitle:
                  Text(Ui.itemMeta(item), style: AppTextStyles.optionSubtitle),
            ),
            const Divider(height: 8),
            tile(Icons.play_circle_outline_rounded, 'Play', 'play'),
            tile(Icons.playlist_add_rounded, 'Add to playlist', 'add'),
            if (collection != null)
              tile(Icons.remove_circle_outline_rounded,
                  'Remove from this ${collection.type.toLowerCase()}', 'remove'),
            if (item.isVideo)
              tile(Icons.photo_library_outlined, 'Save to Photos', 'photos'),
            tile(Icons.delete_outline_rounded, 'Delete from library', 'delete',
                color: AppColors.errorRed),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'play':
      final list = queue ?? [item];
      final at = list.indexWhere((i) => i.id == item.id);
      await services.playAndOpen(context, list, index: at < 0 ? 0 : at);
    case 'add':
      await showAddToCollectionSheet(context, services, [item]);
    case 'remove':
      await services.collections.removeItem(collection!.id, item.id);
    case 'photos':
      try {
        await services.downloads.saveFileToPhotos(item.filePath);
        if (context.mounted) Ui.snack(context, 'Saved to Photos › Musically');
      } catch (e) {
        if (context.mounted) Ui.snack(context, 'Could not save: $e');
      }
    case 'delete':
      final ok = await confirmAction(
        context,
        title: 'Delete “${item.title}”?',
        message: 'The file is removed from this iPhone and from every '
            'playlist. Copies already saved to Photos stay there.',
      );
      if (ok) await services.library.remove(item.id);
  }
}
