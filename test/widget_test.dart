// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/src/domain/entities/library_item.dart';
import 'package:my_first_app/src/domain/entities/video_download_info.dart';
import 'package:my_first_app/src/domain/repositories/video_repository.dart';
import 'package:my_first_app/src/domain/usecases/extract_video_id.dart';
import 'package:my_first_app/src/presentation/app.dart';
import 'package:my_first_app/src/presentation/screens/home_screen.dart';
import 'package:my_first_app/src/presentation/screens/login_screen.dart';

void main() {
  group('ExtractVideoId', () {
    const extract = ExtractVideoId();

    test('extracts id from watch URLs', () {
      expect(extract('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(extract('youtube.com/watch?v=dQw4w9WgXcQ&t=10'),
          'dQw4w9WgXcQ');
      expect(extract('https://music.youtube.com/watch?v=dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
    });

    test('extracts id from youtu.be / shorts / embed', () {
      expect(extract('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(extract('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(
          extract('https://www.youtube.com/embed/dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
    });

    test('accepts a bare 11-character id', () {
      expect(extract('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('rejects invalid input', () {
      expect(extract(''), isNull);
      expect(extract('not a link'), isNull);
      expect(extract('https://example.com/video'), isNull);
    });
  });

  group('App flow', () {
    testWidgets('splash navigates to login after delay',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget); // splash logo

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
    });

    testWidgets('login is pre-filled and opens the home screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Dummy credentials are autofilled.
      expect(find.text('demo@musically.app'), findsOneWidget);
      expect(find.text('musically123'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pump(); // start the route transition
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Musically'), findsOneWidget);
      expect(find.text('Fetch Video'), findsOneWidget);
    });
  });

  group('LibraryItem', () {
    test('JSON round-trip preserves all fields', () {
      final item = LibraryItem(
        id: 'abc_123_1',
        videoId: 'dQw4w9WgXcQ',
        title: 'Knock Knock',
        author: 'Jxggi',
        filePath: '/docs/video_1.mp4',
        category: StreamCategory.audio,
        qualityLabel: '160kbps',
        container: 'm4a',
        thumbnailPath: '/thumbs/x.jpg',
        createdAt: DateTime(2026, 10, 9),
        durationSeconds: 240,
      );
      final restored = LibraryItem.fromJson(item.toJson());
      expect(restored.title, item.title);
      expect(restored.category, StreamCategory.audio);
      expect(restored.qualityLabel, '160kbps');
      expect(restored.isVideo, isFalse);
    });
  });


  group('Home screen', () {
    testWidgets('renders input and rejects invalid links offline',
        (WidgetTester tester) async {
      final repo = _FakeVideoRepository();
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(repository: repo)),
      );

      expect(find.text('Musically'), findsOneWidget);
      expect(find.text('Fetch Video'), findsOneWidget);

      // Invalid input → local error, no network/plugin calls.
      await tester.enterText(find.byType(TextField), 'not a youtube link');
      await tester.tap(find.text('Fetch Video'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('does not look like a valid YouTube link'),
        findsOneWidget,
      );
      expect(repo.fetchCalls, 0);
    });
  });
}

class _FakeVideoRepository implements VideoRepository {
  int fetchCalls = 0;

  @override
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId) async {
    fetchCalls++;
    throw UnimplementedError();
  }

  @override
  Future<String> downloadToLocal(
    StreamOption option,
    DownloadProgressCallback? onProgress,
  ) {
    throw UnimplementedError();
  }

  @override
  void cancelDownload() {}

  @override
  Future<void> saveVideoToGallery(String filePath) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}


