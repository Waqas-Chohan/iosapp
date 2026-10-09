import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// A labeled, pill-shaped text field matching the login design
/// (label + 48px input with a `#F7F7F7` fill and 24px corner radius).
class LoginInputField extends StatelessWidget {
  const LoginInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            textAlignVertical: TextAlignVertical.center,
            style: AppTextStyles.inputText,
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: AppTextStyles.inputHint,
            ),
          ),
        ),
      ],
    );
  }
}
