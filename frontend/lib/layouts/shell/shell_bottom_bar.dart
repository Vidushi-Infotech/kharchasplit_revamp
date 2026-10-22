import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import 'shell_state.dart';

/// Flat bottom tab bar (Splitwise-style): Groups · Friends · Activity ·
/// Account, with labels. Adding an expense lives on the floating
/// [ShellAddExpenseButton] instead of a tab.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _tabs.indexOf(selectedTab ?? -1);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.6),
        ),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: selected < 0 ? 0 : selected,
        backgroundColor: AppColors.surface(isDark),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: isDark ? 0.25 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i != selected) HapticService.instance.selection();
          onTabSelected(_tabs[i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded, color: AppColors.brand),
            label: AppStrings.groups,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.brand),
            label: AppStrings.friends,
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_rounded),
            selectedIcon: Icon(Icons.timeline_rounded, color: AppColors.brand),
            label: AppStrings.activity,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon:
                Icon(Icons.account_circle_rounded, color: AppColors.brand),
            label: AppStrings.account,
          ),
        ],
      ),
    );
  }
}

/// "Add expense" pill that floats bottom-right on the Groups, Friends and
/// Activity tabs.
class ShellAddExpenseButton extends StatelessWidget {
  const ShellAddExpenseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'shell_add_expense',
      onPressed: () {
        HapticService.instance.tap();
        onPressed();
      },
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.receipt_long_rounded),
      label: const Text(AppStrings.addExpense),
    );
  }
}
