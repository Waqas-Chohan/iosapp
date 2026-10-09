/// Extracts a YouTube video id from a raw link or plain id.
///
/// Handles:
/// - `https://youtu.be/<id>`
/// - `https://www.youtube.com/watch?v=<id>`
/// - `https://music.youtube.com/watch?v=<id>`
/// - `https://www.youtube.com/shorts/<id>`, `.../embed/<id>`
/// - a bare 11-character id.
class ExtractVideoId {
  const ExtractVideoId();

  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  String? call(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (_idPattern.hasMatch(trimmed)) return trimmed;

    // Accept scheme-less links like `youtube.com/watch?v=...`.
    var candidate = trimmed;
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(candidate)) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();

    if (host.contains('youtu.be')) {
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList();
      return segments.isNotEmpty && _idPattern.hasMatch(segments.first)
          ? segments.first
          : null;
    }

    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && _idPattern.hasMatch(v)) return v;
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty && s != 'watch').toList();
      if (segments.isNotEmpty && _idPattern.hasMatch(segments.last)) {
        return segments.last;
      }
    }

    return null;
  }
}
