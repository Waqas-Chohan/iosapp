import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'src/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load optional environment config (e.g. API keys) from .env.
  // The .env file is git-ignored (secret), so it is absent in cloud builds —
  // load it best-effort so a missing file never crashes app startup.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env bundled (cloud build / secret not provided) — continue without it.
  }

  // Lock screen / Dynamic Island "Now Playing" card and remote controls
  // (play, pause, next, previous, scrubbing) for the audio engine.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.hellophone.musically.playback',
    androidNotificationChannelName: 'Musically playback',
    androidNotificationOngoing: true,
  );

  // Music audio session: keeps playing in the background / on the lock
  // screen (together with UIBackgroundModes = audio in Info.plist).
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {
    // Best-effort; the player re-applies it before every playback.
  }

  runApp(const MyApp());
}
