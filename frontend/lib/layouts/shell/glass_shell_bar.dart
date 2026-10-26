import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show PlatformInfo;
import 'package:flutter/material.dart';

import '../../components/buttons/glass_surface.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import 'shell_state.dart';

/// iOS 26+ gets the Liquid Glass tab bar and buttons; Android and older
/// iOS keep the Flutter bar in shell_bottom_bar.dart.
bool get useGlassShell => PlatformInfo.isIOS26OrHigher();

/// iOS 26 style tab bar: a floating Liquid Glass capsule with Groups ·
/// Friends · Activity · Account and a glass bubble that slides to the
/// selected tab.
///
/// Drawn by Flutter (liquid_glass_renderer). The native UITabBar from
/// adaptive_platform_ui dropped about every other tap (the highlight moved
/// but the app never heard about it), followed the phone's light/dark
/// setting instead of the app's, and went blank after a hot restart.
class GlassShellTabBar extends StatelessWidget {
  const GlassShellTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  /// A [ShellTab] index, or null when no tab owns the current route.
  final int? selectedTab;
  final ValueChanged<int> onTabSelected;

  static const _tabs = [
    ShellTab.groups,
    ShellTab.friends,
    ShellTab.activity,
    ShellTab.account,
  ];

  static const _items = [
    (Icons.groups_outlined, Icons.groups_rounded, AppStrings.groups),
    (Icons.person_outline_rounded, Icons.person_rounded, AppStrings.friends),
    (Icons.timeline_rounded, Icons.timeline_rounded, AppStrings.activity),
    (
      Icons.account_circle_outlined,
      Icons.account_circle_rounded,
      AppStrings.account,
    ),
  ];

  static const double _height = 62;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _tabs.indexOf(selectedTab ?? -1);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final idle = AppColors.textPrimary(isDark);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom - 6 : 12),
      child: SizedBox(
        height: _height,
        child: GlassSurface(
          circle: false,
          radius: _height / 2,
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / _items.length;
                return Stack(
                  children: [
                    // The bubble behind the selected tab, sliding between
                    // tabs with a slight spring.
                    if (selected >= 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        left: w * selected,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: isDark ? 0.14 : 0.07),
                            borderRadius: BorderRadius.circular(_height / 2),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: _GlassTab(
                              icon: i == selected ? _items[i].$2 : _items[i].$1,
                              label: _items[i].$3,
                              selected: i == selected,
                              color: i == selected ? AppColors.brand : idle,
                              onTap: () {
                                if (i != selected) {
                                  HapticService.instance.selection();
                                }
                                onTabSelected(_tabs[i]);
                              },
                            ),
                          ),
                      ],
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1.08 : 1.0,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add expense" as a brand-tinted Liquid Glass pill floating above the
/// glass tab bar. Drawn by Flutter (like the header buttons), so it is
/// there immediately and moves with the page.
class GlassAddExpenseButton extends StatelessWidget {
  const GlassAddExpenseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.addExpense,
      excludeSemantics: true,
      child: SizedBox(
        height: 52,
        child: GlassSurface(
          circle: false,
          radius: 26,
          tint: AppColors.tealDark.withValues(alpha: 0.96),
          onTap: () {
            HapticService.instance.tap();
            onPressed();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  AppStrings.addExpense,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
