import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../controllers/theme_controller.dart';

/// Lets the user keep the default theme and store/switch one custom theme.
class PersonalizeScreen extends StatefulWidget {
  const PersonalizeScreen({super.key});

  @override
  State<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends State<PersonalizeScreen> {
  static const List<Color> presets = [
    Color(0xFFFE6E04),
    Color(0xFF004E8C),
    Color(0xFF0C2C5C),
    Color(0xFF00897B),
    Color(0xFF7B1FA2),
    Color(0xFFD81B60),
    Color(0xFFE53935),
    Color(0xFF2E7D32),
    Color(0xFFF57F17),
    Color(0xFF3949AB),
  ];

  late ThemeController _theme;
  double _hue = 25.0;
  double _saturation = 0.85;
  double _value = 1.0;

  @override
  void initState() {
    super.initState();
    _theme = ThemeScope.of(context);
    final hsv = HSVColor.fromColor(_theme.customColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _previewColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _saveAndApply(Color color) {
    _theme.setCustomColor(color);
    _theme.useCustomTheme();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('My theme saved & applied (${_hex(color)})')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Personalize',
          style: TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.splashNavy,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListenableBuilder(
            listenable: _theme,
            builder: (context, _) => Row(
              children: [
                _ThemeCard(
                  title: 'Default Theme',
                  subtitle: 'Muz orange · navy',
                  color: ThemeController.defaultSeed,
                  selected: !_theme.isCustomActive,
                  onTap: () {
                    _theme.useDefaultTheme();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Default theme restored')),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _ThemeCard(
                  title: 'My Theme',
                  subtitle: _hex(_theme.customColor),
                  color: _theme.customColor,
                  selected: _theme.isCustomActive,
                  onTap: () => _theme.useCustomTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Pick a preset color', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: presets
                .map((c) => GestureDetector(
                      onTap: () => _saveAndApply(c),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                _theme.customColor.toARGB32() == c.toARGB32()
                                    ? AppColors.splashNavy
                                    : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Text('Craft your own color', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Slider(
            value: _hue,
            min: 0,
            max: 360,
            onChanged: (v) => setState(() => _hue = v),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _previewColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Preview · ${_hex(_previewColor)}',
                  style: AppTextStyles.description,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _saveAndApply(_previewColor),
              icon: const Icon(Icons.colorize, size: 20),
              label: const Text('Save & use this color'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(
              width: 2,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE6E6E6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: AppTextStyles.optionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.splashBlue, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: AppTextStyles.optionSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
