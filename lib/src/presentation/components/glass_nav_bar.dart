import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Model describing one tab of a [GlassNavBar].
class NavItem {
  const NavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.inactiveIcon,
    this.badgeCount = 0,
  });

  /// Selected-state icon (typically the filled variant).
  final IconData icon;

  /// Unselected-state icon; falls back to [icon].
  final IconData? inactiveIcon;

  final String label;

  /// Zero-based position of the tab inside the bar.
  final int index;

  /// When > 0, a count badge is drawn over the icon.
  final int badgeCount;
}

/// iOS-style "Liquid Glass" floating tab bar: a frosted-glass pill (blur 20)
/// where only the active tab gets a visible sliding highlight capsule.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.activeColor,
    this.inactiveColor,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Defaults to [ColorScheme.primary].
  final Color? activeColor;

  /// Defaults to [AppColors.textGray].
  final Color? inactiveColor;

  static const double _barHeight = 72;
  static const double _capsuleWidth = 56;
  static const double _capsuleHeight = 40;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? AppColors.textGray;
    // 16px gap below the home-indicator safe area.
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + safeBottom),
      child: ClipRRect(
        // Blur clipped to the navbar area only.
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: _barHeight,
            decoration: BoxDecoration(
              // Subtle tint over the blur; no solid color behind it.
              color: dark
                  ? Colors.black.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border(
                // 1px glass-edge catchlight along the top.
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = constraints.maxWidth / items.length;
                final selectedPosition = items
                    .indexWhere((item) => item.index == selectedIndex)
                    .clamp(0, items.length - 1);
                return Stack(
                  children: [
                    // Sliding capsule, only behind the active tab.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      left: selectedPosition * cellWidth +
                          (cellWidth - _capsuleWidth) / 2,
                      top: (_barHeight - _capsuleHeight) / 2,
                      width: _capsuleWidth,
                      height: _capsuleHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            // Soft inner glow for depth.
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.30),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (final item in items)
                            Expanded(
                              child: _GlassTab(
                                item: item,
                                selected: item.index == selectedIndex,
                                active: active,
                                inactive: inactive,
                                onTap: onSelected,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({
    required this.item,
    required this.selected,
    required this.active,
    required this.inactive,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color active;
  final Color inactive;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final glyph = selected ? item.icon : (item.inactiveIcon ?? item.icon);
    // Soft white edge faking the glass-reflection outline (white @ 55%).
    const reflection = <Shadow>[
      Shadow(color: Color(0x8CFFFFFF), blurRadius: 3),
    ];
    final iconWidget = Icon(
      glyph,
      size: 24,
      color: selected ? active : inactive,
      shadows: reflection,
    );

      return Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(item.index),
          child: SizedBox(
            height: GlassNavBar._barHeight,
            child: Center(
              child: SizedBox(
                height: GlassNavBar._capsuleHeight,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: item.badgeCount > 0
                        ? Badge(
                            label: Text('${item.badgeCount}'),
                            backgroundColor: active,
                            child: iconWidget,
                          )
                        : iconWidget,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }
}

