// Formatting helpers shared by the downloader UI.

String formatDuration(Duration? duration) {
  if (duration == null) return '—';
  final h = duration.inHours;
  final m = duration.inMinutes % 60;
  final s = duration.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}
