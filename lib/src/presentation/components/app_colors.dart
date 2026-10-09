import 'package:flutter/material.dart';

/// Brand palette extracted from the GYM SAAS Figma design file.
abstract final class AppColors {
  /// Main accent orange (style "Main Accent/Orange - FE6E04") used for the logo.
  static const Color accentOrange = Color(0xFFFE6E04);

  /// Splash radial gradient — inner (center) color.
  static const Color splashBlue = Color(0xFF004E8C);

  /// Splash radial gradient — outer (edge) color.
  static const Color splashNavy = Color(0xFF0C2C5C);

  /// Secondary text color used across login form (labels, hints, description).
  static const Color textGray = Color(0xFF737373);

  /// Background of the rounded input fields on the login screen.
  static const Color inputFill = Color(0xFFF7F7F7);
}

