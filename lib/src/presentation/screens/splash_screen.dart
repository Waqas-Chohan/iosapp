import 'dart:async';

import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import 'app_shell.dart';

/// The app splash screen, reproduced from the GYM SAAS Figma design
/// (section `Splash Screen` `2575:3422`, frame 390 x 844).
///
/// Visual recipe from the design:
/// - Background: radial gradient, `#004E8C` at the center fading to
///   `#0C2C5C` towards the edges.
/// - Centered logo group (135.4 x 120) filled with the accent orange
///   `#FE6E04` — rendered as a transparent PNG asset.
///
/// Shows for ~2.5s, then replaces itself with the app shell
/// (login is currently commented out / skipped).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _animation, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1)
      .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), _goToHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0),
            radius: 2.2,
            colors: [AppColors.splashBlue, AppColors.splashNavy],
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Image.asset(
                'assets/images/logo.png',
                width: 135.4,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

