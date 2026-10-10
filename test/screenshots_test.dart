// Scratch-only visual review: renders key screens to PNG.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/src/domain/entities/library_collection.dart';
import 'package:my_first_app/src/domain/entities/library_item.dart';
import 'package:my_first_app/src/domain/entities/video_download_info.dart';
import 'package:my_first_app/src/domain/repositories/collections_repository.dart';
import 'package:my_first_app/src/domain/repositories/library_repository.dart';
import 'package:my_first_app/src/domain/repositories/video_repository.dart';
import 'package:my_first_app/src/presentation/app_services.dart';
import 'package:my_first_app/src/presentation/components/app_colors.dart';
import 'package:my_first_app/src/presentation/controllers/collections_model.dart';
import 'package:my_first_app/src/presentation/controllers/download_manager.dart';
import 'package:my_first_app/src/presentation/controllers/library_model.dart';
import 'package:my_first_app/src/presentation/controllers/player_controller.dart';
import 'package:my_first_app/src/presentation/screens/downloads_screen.dart';
import 'package:my_first_app/src/presentation/screens/home_screen.dart';
import 'package:my_first_app/src/presentation/screens/library_screen.dart';
import 'package:my_first_app/src/presentation/screens/playlist_screen.dart';

Future<void> _fonts() async {
  Future<void> load(String family, List<Future<ByteData>> data) async {
    final l = FontLoader(family);
    for (final d in data) {
      l.addFont(d);
    }
    await l.load();
  }

  await load('Sora', [rootBundle.load('assets/fonts/Sora-Bold.ttf')]);
  await load('Poppins', [
    rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    rootBundle.load('assets/fonts/Poppins-Medium.ttf'),
    rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  Future<ByteData> bytes(File f) async =>
      ByteData.view((await f.readAsBytes()).buffer);
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      final n = f.path.split('/').last;
      if (n.startsWith('MaterialIcons')) await load('MaterialIcons', [bytes(f)]);
      if (n == 'Roboto-Regular.ttf' || n == 'Roboto-Medium.ttf') {
        await load('Roboto', [bytes(f)]);
      }
    }
  }
}

LibraryItem _item(String id, String title, String author,
        {bool audio = false, String q = '1080p'}) =>
    LibraryItem(
      id: id,
      videoId: 'v$id',
      title: title,
      author: author,
      filePath: '/x/$id',
      category: audio ? StreamCategory.audio : StreamCategory.muxed,
      qualityLabel: audio ? '128kbps' : q,
      container: audio ? 'm4a' : 'mp4',
      thumbnailPath: '',
      createdAt: DateTime(2026, 10, int.parse(id)),
      durationSeconds: 180 + int.parse(id) * 13,
    );

class _Lib implements LibraryRepository {
  _Lib(this.items);
  final List<LibraryItem> items;
  @override
  Future<List<LibraryItem>> loadItems() async => items;
  @override
  Future<void> addItem(LibraryItem item) async {}
  @override
  Future<void> removeItem(String id) async {}
  @override
  Future<String> saveThumbnail(String url, String videoId) async => url;
}

class _Col implements CollectionsRepository {
  @override
  Future<List<LibraryCollection>> load() async => [];
  @override
  Future<void> save(List<LibraryCollection> c) async {}
}

class _Video implements VideoRepository {
  @override
  Future<VideoDownloadInfo> fetchVideoInfo(String urlOrId) =>
      throw UnimplementedError();
  @override
  Future<String?> refreshStreamUrl(String videoId, int tag) async => null;
  @override
  Future<void> saveVideoToGallery(String filePath) async {}
  @override
  void close() {}
}

Future<AppServices> _services() async {
  final lib = LibraryModel(_Lib([
    _item('1', 'Blinding Lights', 'The Weeknd', audio: true),
    _item('2', 'Levitating (Official Video)', 'Dua Lipa'),
    _item('3', 'Shape of You', 'Ed Sheeran', audio: true),
    _item('4', 'Believer', 'Imagine Dragons', q: '720p'),
    _item('5', 'Perfect', 'Ed Sheeran', audio: true),
    _item('6', 'Peaches', 'Justin Bieber', q: '360p'),
  ]));
  await lib.refresh();
  final col = CollectionsModel(_Col());
  await col.create('Road trip', itemIds: ['1', '2', '3', '4']);
  await col.create('Chill evenings',
      type: LibraryCollection.album, itemIds: ['5']);
  return AppServices(
    player: PlayerController(),
    library: lib,
    collections: col,
    downloads: DownloadManager(_Video(), library: lib),
  );
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accentOrange),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: home,
    );

void main() {
  setUpAll(_fonts);

  Future<void> shot(WidgetTester tester, Widget w, String name,
      {double h = 844}) async {
    tester.view.physicalSize = Size(390 * 3, h * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(w));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  }

  testWidgets('home', (t) async {
    final s = await _services();
    await shot(t, HomeScreen(services: s), 'home', h: 1900);
  });
  testWidgets('library', (t) async {
    final s = await _services();
    await shot(t, LibraryScreen(services: s), 'library');
  });
  testWidgets('playlist', (t) async {
    final s = await _services();
    await shot(t,
        PlaylistScreen(services: s, collectionId: s.collections.collections.last.id),
        'playlist', h: 1300);
  });
  testWidgets('downloads', (t) async {
    final s = await _services();
    await shot(t, DownloadsScreen(services: s), 'downloads');
  });
}
