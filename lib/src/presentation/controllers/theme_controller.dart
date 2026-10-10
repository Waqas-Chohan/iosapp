import 'package:flutter/material.dart';

import '../../data/datasources/settings_datasource.dart';
import '../components/app_colors.dart';

/// Theme personalization: the default Figma theme is always kept, plus ONE
/// user-defined theme; the user can switch between them. Persisted to disk.
class ThemeController extends ChangeNotifier {
  ThemeController([SettingsDatasource? store])
      : _store = store ?? SettingsDatasource();

  static const Color defaultSeed = AppColors.accentOrange;

  final SettingsDatasource _store;
  Color _customSeed = defaultSeed;
  bool _useCustom = false;

  ThemeData get defaultTheme => _build(defaultSeed);
  ThemeData get customTheme => _build(_customSeed);
  ThemeData get activeTheme => _useCustom ? customTheme : defaultTheme;
  bool get isCustomActive => _useCustom;
  Color get customColor => _customSeed;

  Future<void> load() async {
    final data = await _store.read();
    final color = data['customColor'];
    if (color is int) _customSeed = Color(color);
    final active = data['active'];
    if (active == 'custom') _useCustom = true;
    notifyListeners();
  }

  void setCustomColor(Color color) {
    _customSeed = color;
    _persist();
    notifyListeners();
  }

  void useDefaultTheme() {
    _useCustom = false;
    _persist();
    notifyListeners();
  }

  void useCustomTheme() {
    _useCustom = true;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() => _store.write({
        'active': _useCustom ? 'custom' : 'default',
        'customColor': _customSeed.toARGB32(),
      });

  ThemeData _build(Color seed) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed)
            .copyWith(primary: seed),
        scaffoldBackgroundColor: Colors.white,
      );
}

/// Makes [ThemeController] available anywhere below the app root.
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ThemeController controller;

  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.controller;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      controller != oldWidget.controller;
}
