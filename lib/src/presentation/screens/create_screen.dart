import 'package:flutter/material.dart';

import '../../domain/entities/library_collection.dart';
import '../../domain/entities/library_item.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({
    super.key,
    required this.items,
    required this.onCreate,
  });

  final List<LibraryItem> items;
  final ValueChanged<LibraryCollection> onCreate;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _type = 'Playlist';
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createCollection() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your album or playlist a name.')),
      );
      return;
    }

    final selected = widget.items
        .where((item) => _selectedIds.contains(item.id))
        .map((item) => item.id)
        .toList();

    final collection = LibraryCollection(
      id: 'collection_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: _type,
      itemIds: selected,
      createdAt: DateTime.now(),
    );

    widget.onCreate(collection);
    _nameController.clear();
    _selectedIds.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create',
          style: TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.splashNavy,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create album or playlist', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Name your collection',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Playlist', label: Text('Playlist')),
                      ButtonSegment(value: 'Album', label: Text('Album')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (value) => setState(() => _type = value.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Add songs from your library', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'Download some music first to create a playlist.',
                        style: AppTextStyles.description,
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = _selectedIds.contains(item.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accentOrange.withValues(alpha: 0.08) : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? AppColors.accentOrange : const Color(0xFFE6E6E6),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(item.id);
                                } else {
                                  _selectedIds.add(item.id);
                                }
                              });
                            },
                            title: Text(item.title, style: AppTextStyles.optionTitle),
                            subtitle: Text(
                              '${item.author} · ${item.qualityLabel}',
                              style: AppTextStyles.optionSubtitle,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createCollection,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create collection'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
