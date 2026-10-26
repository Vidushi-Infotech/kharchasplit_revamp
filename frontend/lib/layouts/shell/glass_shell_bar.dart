import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import 'shell_state.dart';

/// iOS 26+ gets the system's Liquid Glass tab bar and buttons (native
/// UIKit views via adaptive_platform_ui); Android and older iOS keep the
/// Flutter bar in shell_bottom_bar.dart.
bool get useGlassShell => PlatformInfo.isIOS26OrHigher();

/// Native iOS 26 tab bar: Groups · Friends · Activity · Account, with SF
/// Symbols. [visible] false hides the native view while a page or sheet
/// covers the shell, so it can't show through Flutter content.
class GlassShellTabBar extends StatelessWidget {
  const GlassShellTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.visible,
  });

  /// A [ShellTab] index, or null when no tab owns the current route.
  final int? selectedTab;
  final ValueChanged<int> onTabSelected;
  final bool visible;

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
      showNativeView: visible,
      onTap: (i) {
        if (i != selected) HapticService.instance.selection();
        onTabSelected(_tabs[i]);
      },
    );
  }
}

/// "Add expense" as a native Liquid Glass button, tinted with the brand
/// color, floating above the glass tab bar.
class GlassAddExpenseButton extends StatelessWidget {
  const GlassAddExpenseButton({
    super.key,
    required this.onPressed,
    required this.visible,
  });

  final VoidCallback onPressed;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    // Offstage keeps the native view out of the way while covered, the
    // same rule as the tab bar.
    return Offstage(
      offstage: !visible,
      child: Semantics(
        button: true,
        label: AppStrings.addExpense,
        excludeSemantics: true,
        // A native view takes all the width it's given; keep it a pill.
        child: SizedBox(
          width: 168,
          height: 50,
          child: AdaptiveButton(
            onPressed: () {
              HapticService.instance.tap();
              onPressed();
            },
            label: AppStrings.addExpense,
            style: AdaptiveButtonStyle.prominentGlass,
            size: AdaptiveButtonSize.large,
            color: AppColors.brand,
            textColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
