import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

import 'src/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure the audio session so playback keeps running in the
  // background / lock screen / Dynamic Island (with UIBackgroundModes).
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  runApp(const MyApp());
}

