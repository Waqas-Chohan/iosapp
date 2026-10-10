import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/src/data/datasources/lyrics_datasource.dart';
import 'package:my_first_app/src/domain/entities/lyrics.dart';

void main() {
  group('Lyrics.parseLrc', () {
    test('parses time stamps, multi-stamps and skips metadata', () {
      final lines = Lyrics.parseLrc('[ar:Someone]\n'
          '[00:12.50] First line\n'
          '[00:05.00][01:00.25] Chorus\n'
          'no stamp here');
      expect(lines.map((l) => l.text), ['Chorus', 'First line', 'Chorus']);
      expect(lines.first.time, const Duration(seconds: 5));
      expect(lines.last.time, const Duration(minutes: 1, milliseconds: 250));
    });

    test('indexAt finds the active line', () {
      final lyrics = Lyrics(lines: Lyrics.parseLrc('[00:01.00] a\n[00:03.00] b\n[00:05.00] c'));
      expect(lyrics.indexAt(Duration.zero), -1);
      expect(lyrics.indexAt(const Duration(seconds: 1)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 4)), 1);
      expect(lyrics.indexAt(const Duration(minutes: 9)), 2);
    });

    test('LRC round-trip keeps lines', () {
      final lyrics = Lyrics(lines: Lyrics.parseLrc('[00:01.50] a\n[02:03.00] b'));
      final again = Lyrics.parseLrc(lyrics.toLrc());
      expect(again.length, 2);
      expect(again[1].time, const Duration(minutes: 2, seconds: 3));
    });
  });

  group('LyricsDatasource.cleanQuery', () {
    test('splits "Artist - Song (Official Video) [4K]"', () {
      final q = LyricsDatasource.cleanQuery(
          'Artist - Song (Official Video) [4K]', 'Some Channel');
      expect(q.title, 'Song');
      expect(q.artist, 'Artist');
    });

    test('uses the channel name when the title has no artist', () {
      final q = LyricsDatasource.cleanQuery('Song ft. Guest', 'Singer - Topic');
      expect(q.title, 'Song');
      expect(q.artist, 'Singer');
    });
  });
}
