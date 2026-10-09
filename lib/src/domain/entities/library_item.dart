import 'video_download_info.dart';

/// A downloaded item saved to the on-device library.
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.filePath,
    required this.category,
    required this.qualityLabel,
    required this.container,
    required this.thumbnailPath,
    required this.createdAt,
    this.durationSeconds,
  });

  final String id;
  final String videoId;
  final String title;
  final String author;
  final String filePath;
  final StreamCategory category;
  final String qualityLabel;
  final String container;
  final String thumbnailPath;
  final DateTime createdAt;
  final int? durationSeconds;

  bool get isVideo => category == StreamCategory.muxed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'author': author,
        'filePath': filePath,
        'category': category.name,
        'qualityLabel': qualityLabel,
        'container': container,
        'thumbnailPath': thumbnailPath,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        id: json['id'] as String,
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        filePath: json['filePath'] as String,
        category: StreamCategory.values.firstWhere(
          (c) => c.name == (json['category'] as String? ?? 'muxed'),
          orElse: () => StreamCategory.muxed,
        ),
        qualityLabel: json['qualityLabel'] as String? ?? '',
        container: json['container'] as String? ?? 'mp4',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        durationSeconds: json['durationSeconds'] as int?,
      );
}
