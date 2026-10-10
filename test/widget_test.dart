// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/src/domain/entities/download_task.dart';
import 'package:my_first_app/src/domain/entities/library_collection.dart';
import 'package:my_first_app/src/domain/entities/library_item.dart';
import 'package:my_first_app/src/domain/entities/video_download_info.dart';
import 'package:my_first_app/src/domain/repositories/collections_repository.dart';
import 'package:my_first_app/src/domain/repositories/library_repository.dart';
import 'package:my_first_app/src/domain/repositories/video_repository.dart';
import 'package:my_first_app/src/domain/usecases/extract_video_id.dart';
import 'package:my_first_app/src/presentation/app.dart';
import 'package:my_first_app/src/presentation/app_services.dart';
import 'package:my_first_app/src/presentation/components/artwork.dart';
import 'package:my_first_app/src/presentation/controllers/collections_model.dart';
import 'package:my_first_app/src/presentation/controllers/download_manager.dart';
import 'package:my_first_app/src/presentation/controllers/library_model.dart';
import 'package:my_first_app/src/presentation/controllers/player_controller.dart';
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
      expect(find.byKey(const Key('home-search')), findsOneWidget);
      expect(find.text('Fetch Video'), findsNothing);
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
    testWidgets('shows the library carousel and playlists',
        (WidgetTester tester) async {
      final services = _services([
        _item('a', 'First Song', audio: true),
        _item('b', 'Second Video'),
        _item('c', 'Third Song', audio: true),
      ]);
      await services.library.refresh();
      await services.collections.create('Road trip', itemIds: ['a', 'b']);

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(services: services)),
      );
      await tester.pump();

      expect(find.byKey(const Key('home-search')), findsOneWidget);
      expect(find.text('From your library'), findsOneWidget);
      expect(find.text('First Song'), findsWidgets);
      expect(find.text('Jump back in'), findsOneWidget);
      expect(find.text('Road trip'), findsOneWidget);
      expect(find.text('New playlist'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty library invites to search or import',
        (WidgetTester tester) async {
      final services = _services(const []);
      await services.library.refresh();
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(services: services)),
      );
      await tester.pump();
      expect(find.text('Your music lives here'), findsOneWidget);
      expect(find.text('Search & download'), findsOneWidget);
      expect(find.text('Import videos'), findsOneWidget);
    });
  });

  group('Collections', () {
    test('create, add (deduped), reorder and forget items', () async {
      final model = CollectionsModel(_MemoryCollections());
      await model.load();
      final c = await model.create('Chill', itemIds: ['a']);
      expect(model.collections.single.name, 'Chill');

      expect(await model.addItems(c.id, ['a', 'b', 'c']), 2);
      expect(model.byId(c.id)!.itemIds, ['a', 'b', 'c']);

      await model.setOrder(c.id, ['c', 'a']);
      expect(model.byId(c.id)!.itemIds, ['c', 'a', 'b']);

      await model.forgetItem('a');
      expect(model.byId(c.id)!.itemIds, ['c', 'b']);

      await model.rename(c.id, 'Late night');
      await model.setType(c.id, LibraryCollection.album);
      expect(model.byId(c.id)!.name, 'Late night');
      expect(model.byId(c.id)!.isAlbum, isTrue);

      await model.delete(c.id);
      expect(model.collections, isEmpty);
    });

    test('JSON round-trip', () {
      final c = LibraryCollection(
        id: 'x',
        name: 'Gym',
        type: LibraryCollection.album,
        itemIds: const ['1', '2'],
        createdAt: DateTime(2026, 10, 10),
        description: 'loud',
      );
      final r = LibraryCollection.fromJson(c.toJson());
      expect(r.name, 'Gym');
      expect(r.isAlbum, isTrue);
      expect(r.itemIds, ['1', '2']);
      expect(r.description, 'loud');
    });
  });

  group('Downloads', () {
    test('merged option sizes and badges', () {
      const o = StreamOption(
        videoId: 'v',
        tag: 137,
        category: StreamCategory.muxed,
        label: '1080p',
        container: 'mp4',
        sizeBytes: 1000,
        url: 'u',
        audioTag: 140,
        audioUrl: 'a',
        audioSizeBytes: 200,
        height: 1080,
      );
      expect(o.needsMerge, isTrue);
      expect(o.totalBytes, 1200);
      expect(o.qualityBadge, 'FHD');
      expect(o.extensionName, 'mp4');
      final back = StreamOption.fromJson(o.toJson());
      expect(back.audioTag, 140);
      expect(back.totalBytes, 1200);
    });

    test('task JSON keeps progress and state', () {
      final t = DownloadTask(
        id: 'dl_1',
        videoId: 'v',
        title: 'Song',
        author: 'Artist',
        thumbnailUrl: '',
        option: const StreamOption(
          videoId: 'v',
          tag: 140,
          category: StreamCategory.audio,
          label: '128kbps',
          container: 'm4a',
          sizeBytes: 400,
          url: 'u',
        ),
        createdAt: DateTime(2026, 10, 10),
        state: DownloadState.paused,
        received: 100,
      );
      expect(t.total, 400);
      expect(t.progress, 0.25);
      expect(t.canResume, isTrue);
      final r = DownloadTask.fromJson(t.toJson());
      expect(r.state, DownloadState.paused);
      expect(r.received, 100);
      expect(r.option.label, '128kbps');
    });

    test('letterbox zoom hides YouTube bars', () {
      expect(Artwork.letterboxZoom(1), closeTo(4 / 3, 1e-9));
      expect(Artwork.letterboxZoom(16 / 9), 1.0);
      expect(Artwork.letterboxZoom(1.5), closeTo(16 / 13.5, 1e-9));
    });
  });
}

LibraryItem _item(String id, String title, {bool audio = false}) => LibraryItem(
      id: id,
      videoId: 'vid_$id',
      title: title,
      author: 'Artist $id',
      filePath: '/nowhere/$id.mp4',
      category: audio ? StreamCategory.audio : StreamCategory.muxed,
      qualityLabel: audio ? '128kbps' : '1080p',
      container: audio ? 'm4a' : 'mp4',
      thumbnailPath: '',
      createdAt: DateTime(2026, 10, 1),
      durationSeconds: 200,
    );

AppServices _services(List<LibraryItem> items) {
  final library = LibraryModel(_MemoryLibrary(items));
  return AppServices(
    player: PlayerController(),
    library: library,
    collections: CollectionsModel(_MemoryCollections()),
    downloads: DownloadManager(_FakeVideoRepository(), library: library),
  );
}

class _MemoryLibrary implements LibraryRepository {
  _MemoryLibrary(List<LibraryItem> items) : _items = List.of(items);

  final List<LibraryItem> _items;

  @override
  Future<List<LibraryItem>> loadItems() async => List.of(_items);

  @override
  Future<void> addItem(LibraryItem item) async => _items.insert(0, item);

  @override
  Future<void> removeItem(String id) async =>
      _items.removeWhere((i) => i.id == id);

  @override
  Future<String> saveThumbnail(String url, String videoId) async => url;
}

class _MemoryCollections implements CollectionsRepository {
  List<LibraryCollection> saved = [];

  @override
  Future<List<LibraryCollection>> load() async => List.of(saved);

  @override
  Future<void> save(List<LibraryCollection> collections) async =>
      saved = List.of(collections);
}

class _FakeVideoRepository implements VideoRepository {
  int fetchCalls = 0;

  @override
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId) async {
    fetchCalls++;
    throw UnimplementedError();
  }

  @override
  Future<String?> refreshStreamUrl(String videoId, int tag) async => null;

  @override
  Future<void> saveVideoToGallery(String filePath) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}
