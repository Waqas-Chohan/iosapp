import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// One action inside a [showGlassMenu] bottom sheet.
class GlassMenuAction {
  const GlassMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.enabled = true,
  });

  /// Value handed back to `onSelected`.
  final String value;
  final String label;
  final IconData icon;

  /// Accent color for the icon bubble (matches the app palette).
  final Color color;

  final bool enabled;
}

/// Shows a frosted-glass ("liquid glass") action menu as a bottom sheet and
/// returns the selected [GlassMenuAction.value] (or null when dismissed).
///
/// Fully dismissible: tap the scrim, drag the handle down, or press Cancel.
Future<String?> showGlassMenu(
  BuildContext context, {
  required String title,
  required List<GlassMenuAction> actions,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    // Explicit: tapping outside closes it (fixes the "can't go back" bug).
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GlassMenuSheet(title: title, actions: actions),
  );
}

class _GlassMenuSheet extends StatelessWidget {
  const _GlassMenuSheet({required this.title, required this.actions});

  final String title;
  final List<GlassMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + safeBottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              // Subtle frosted tint; no solid color — content shows through.
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.splashNavy.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Drag handle (also the visual cue that this is dismissible).
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textGray.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(title, style: AppTextStyles.sectionTitle),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in actions)
                    _MenuRow(
                      action: a,
                      onTap: () => Navigator.of(context).pop(a.value),
                    ),
                  const SizedBox(height: 6),
                  const _Divider(),
                  _CancelRow(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.action, required this.onTap});

  final GlassMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: action.enabled ? 1 : 0.4,
      child: ListTile(
        onTap: action.enabled ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(action.icon, color: action.color, size: 22),
        ),
        title: Text(
          action.label,
          style: AppTextStyles.optionTitle.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
      ),
    );
  }
}

class _CancelRow extends StatelessWidget {
  const _CancelRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.textGray.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.close_rounded, color: AppColors.splashNavy, size: 22),
      ),
      title: Text(
        'Cancel',
        style: AppTextStyles.optionTitle.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.splashNavy,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.textGray.withValues(alpha: 0.15),
      ),
    );
  }
}
