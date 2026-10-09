import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/presentation/app.dart';
import 'src/presentation/controllers/player_controller.dart';

const MethodChannel _mediaChannel = MethodChannel('musically/media');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure the audio session so playback keeps running in the
  // background / lock screen / Dynamic Island (with UIBackgroundModes).
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await session.setActive(true);

  // Lock-screen / Dynamic Island remote commands → the active player.
  _mediaChannel.setMethodCallHandler((call) async {
    final player = PlayerController.instance;
    if (player == null) return null;
    switch (call.method) {
      case 'play':
        await player.play();
      case 'pause':
        if (player.isPlaying) await player.pause();
      case 'next':
        await player.next();
      case 'previous':
        await player.previous();
    }
    return null;
  });

  runApp(const MyApp());
}

