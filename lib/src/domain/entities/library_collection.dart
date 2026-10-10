/// A user playlist or album: an ordered list of library item ids.
class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.name,
    required this.type,
    required this.itemIds,
    required this.createdAt,
    this.description = '',
    this.updatedAt,
  });

  static const playlist = 'Playlist';
  static const album = 'Album';

  final String id;
  final String name;

  /// [playlist] or [album].
  final String type;
  final List<String> itemIds;
  final DateTime createdAt;
  final String description;
  final DateTime? updatedAt;

  bool get isAlbum => type == album;

  LibraryCollection copyWith({
    String? name,
    String? type,
    List<String>? itemIds,
    String? description,
  }) =>
      LibraryCollection(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        itemIds: itemIds ?? this.itemIds,
        createdAt: createdAt,
        description: description ?? this.description,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'itemIds': itemIds,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory LibraryCollection.fromJson(Map<String, dynamic> json) =>
      LibraryCollection(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled',
        type: json['type'] as String? ?? playlist,
        itemIds:
            (json['itemIds'] as List?)?.whereType<String>().toList() ??
                const [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        description: json['description'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}
