import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/login_input_field.dart';
import 'app_shell.dart';

/// Login screen, reproduced from the GYM SAAS Figma design
/// (frame `login` `1510:10546`, 390 x 844).
///
/// Demo mode: credentials are pre-filled and any values are accepted.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController =
      TextEditingController(text: 'demo@musically.app');
  final TextEditingController _passwordController =
      TextEditingController(text: 'musically123');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Demo login — no backend yet; lands on the app shell.
  void _onLoginPressed() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 96),
                        const Text(
                          'Welcome Back!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.welcomeHeading,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sign in to access your dashboard '
                          '& manage gym membership',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.description,
                        ),
                        const SizedBox(height: 48),
                        LoginInputField(
                          label: 'Email Address',
                          hint: 'Enter Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 24),
                        LoginInputField(
                          label: 'Password',
                          hint: 'Enter Password',
                          controller: _passwordController,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _onLoginPressed(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: navigate to the forgot-password flow.
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: AppTextStyles.linkLabel,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Demo mode — credentials are pre-filled.\n'
                          'Tap Login to continue.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.description,
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _onLoginPressed,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Login',
                                  style: AppTextStyles.buttonLabel,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
