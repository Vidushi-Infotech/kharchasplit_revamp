import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../components/buttons/glass_surface.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import 'shell_state.dart';

/// iOS 26+ gets the system's Liquid Glass tab bar and buttons (native
/// UIKit views via adaptive_platform_ui); Android and older iOS keep the
/// Flutter bar in shell_bottom_bar.dart.
bool get useGlassShell => PlatformInfo.isIOS26OrHigher();

/// Native iOS 26 tab bar: Groups · Friends · Activity · Account, with SF
/// Symbols. It stays in place while a page slides in: Flutter draws the
/// incoming page over the native view, like iOS covering its tab bar.
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

  static final _destinations = [
    AdaptiveNavigationDestination(
      icon: 'person.3',
      selectedIcon: 'person.3.fill',
      label: AppStrings.groups,
    ),
    AdaptiveNavigationDestination(
      icon: 'person',
      selectedIcon: 'person.fill',
      label: AppStrings.friends,
    ),
    AdaptiveNavigationDestination(
      icon: 'chart.line.uptrend.xyaxis',
      label: AppStrings.activity,
    ),
    AdaptiveNavigationDestination(
      icon: 'person.crop.circle',
      selectedIcon: 'person.crop.circle.fill',
      label: AppStrings.account,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _tabs.indexOf(selectedTab ?? -1);
    return IOS26NativeTabBar(
      destinations: _destinations,
      selectedIndex: selected < 0 ? 0 : selected,
      tint: AppColors.brand,
      onTap: (i) {
        if (i != selected) HapticService.instance.selection();
        onTabSelected(_tabs[i]);
      },
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
