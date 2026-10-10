import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'src/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

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
