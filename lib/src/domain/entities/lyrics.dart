/// One time-stamped lyric line.
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

/// Lyrics for a track: time-synced lines (LRC) and/or plain text.
class Lyrics {
  const Lyrics({this.lines = const [], this.plain});

  /// Time-synced lines, sorted by time (empty when only plain text exists).
  final List<LyricLine> lines;

  /// Unsynced lyrics text (fallback).
  final String? plain;

  bool get isSynced => lines.isNotEmpty;
  bool get isEmpty => lines.isEmpty && (plain == null || plain!.trim().isEmpty);

  static final RegExp _stamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

  /// Parses LRC text such as `[01:23.45] some line`. A line may carry several
  /// time stamps (`[00:12.00][01:30.00] chorus`). Metadata tags are ignored.
  static List<LyricLine> parseLrc(String lrc) {
    final out = <LyricLine>[];
    for (final raw in lrc.split('\n')) {
      final matches = _stamp.allMatches(raw).toList();
      if (matches.isEmpty) continue;
      final text = raw.substring(matches.last.end).trim();
      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final frac = m.group(3);
        var ms = 0;
        if (frac != null) {
          ms = int.parse(frac.padRight(3, '0').substring(0, 3));
        }
        out.add(LyricLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  /// Serialises synced lines back to LRC (used for the offline cache).
  String toLrc() {
    String two(int v) => v.toString().padLeft(2, '0');
    return lines.map((l) {
      final m = l.time.inMinutes;
      final s = l.time.inSeconds % 60;
      final cs = (l.time.inMilliseconds % 1000) ~/ 10;
      return '[${two(m)}:${two(s)}.${two(cs)}] ${l.text}';
    }).join('\n');
  }

  /// Index of the line being sung at [position], or -1 before the first line.
  int indexAt(Duration position) {
    if (lines.isEmpty || position < lines.first.time) return -1;
    var lo = 0, hi = lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (lines[mid].time <= position) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}
