import 'package:flutter/material.dart';

import 'controllers/theme_controller.dart';
import 'screens/splash_screen.dart';

/// Root application widget: theme + initial routing.
class MyApp extends StatefulWidget {
  const MyApp({super.key, this.themeController});

  final ThemeController? themeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeController _theme =
      widget.themeController ?? ThemeController();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          title: 'Muz',
          debugShowCheckedModeBanner: false,
          theme: _theme.activeTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
