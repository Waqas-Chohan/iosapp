class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.type,
    required this.itemIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final List<String> itemIds;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LibraryCollection.fromJson(Map<String, dynamic> json) =>
      LibraryCollection(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled',
        type: json['type'] as String? ?? 'Playlist',
        itemIds: (json['itemIds'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
