import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography synced with the GYM SAAS Figma design.
///
/// Two families are used across the app:
/// - **Sora** for display/headings
/// - **Poppins** for body, labels and inputs
abstract final class AppTextStyles {
  /// Custom bundled font family names (see pubspec.yaml `fonts`).
  static const String sora = 'Sora';
  static const String poppins = 'Poppins';

  /// "Welcome Back!" — Sora Bold, 24, navy.
  static const TextStyle welcomeHeading = TextStyle(
    fontFamily: sora,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.26,
    color: AppColors.splashNavy,
  );

  /// Login description — Poppins Regular, 14, gray, centered.
  static const TextStyle description = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: AppColors.textGray,
  );

  /// Field label — Poppins Medium, 14, gray.
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.5,
    color: AppColors.textGray,
  );

  /// Typed input text — Poppins Regular, 16.
  static const TextStyle inputText = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
    color: Color(0xFF161616),
  );

  /// Input hint / placeholder — Poppins Regular, 16, gray.
  static const TextStyle inputHint = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textGray,
  );

  /// "Forgot Password?" — Poppins Medium, 16, orange, underlined.
  static const TextStyle linkLabel = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.5,
    color: AppColors.accentOrange,
    decoration: TextDecoration.underline,
  );

  /// Button label — Poppins Medium, 16, white, centered.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.5,
    color: Colors.white,
  );

  /// Fetched video title — Poppins Medium, 16, navy.
  static const TextStyle videoTitle = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.4,
    color: AppColors.splashNavy,
  );

  /// Meta row (author, timestamps) — Poppins Regular, 13, gray.
  static const TextStyle videoMeta = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: AppColors.textGray,
  );

  /// Section heading (e.g. "Available Downloads") — Sora Bold, 17, navy.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: sora,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.3,
    color: AppColors.splashNavy,
  );

  /// Download option title — Poppins Medium, 15, navy.
  static const TextStyle optionTitle = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.4,
    color: AppColors.splashNavy,
  );

  /// Download option subtitle — Poppins Regular, 13, gray.
  static const TextStyle optionSubtitle = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: AppColors.textGray,
  );
}
