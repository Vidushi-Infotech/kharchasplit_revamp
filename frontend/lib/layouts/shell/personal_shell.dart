import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/lifecycle/app_lifecycle_refresher.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/state/app_mode.dart';
import '../../core/theme/app_colors.dart';
import 'glass_shell_bar.dart' show useGlassShell;
import 'mode_tab_bar.dart';
import 'web_shell.dart';

/// Shell of the Personal "app": the user's own money, apart from groups.
/// Its own tabs (bottom bar on phones, a rail on tablets), the last of
/// which switches back to Groups. Desktop keeps the one sidebar for both.
class PersonalShell extends StatelessWidget {
  const PersonalShell({super.key, required this.child});

  final Widget child;

  static const expensesLocation = '/personal';
  static const accountLocation = '/personal/account';

  /// Bar position → route; the slot after the last is the mode switch.
  static const _locations = [expensesLocation, accountLocation];

  static const _items = [
    ShellNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: AppStrings.personalHome,
    ),
    ShellNavItem(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: AppStrings.account,
    ),
    ShellNavItem(
      icon: Icons.groups_rounded,
      selectedIcon: Icons.groups_rounded,
      label: AppStrings.groups,
      modeSwitch: true,
    ),
  ];

  static int? _indexOf(String path) {
    if (path.startsWith(accountLocation)) return 1;
    if (path.startsWith(expensesLocation)) return 0;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppModeStore.remember(AppMode.personal);
    final width = MediaQuery.sizeOf(context).width;
    if (width >= Breakpoints.shellWeb) return WebShell(child: child);

    final selected = _indexOf(GoRouterState.of(context).uri.path);
    void onSelect(int i) {
      if (i >= _locations.length) {
        switchAppMode(context, AppMode.shared);
      } else if (i != selected) {
        context.go(_locations[i]);
      }
    }

    return AppLifecycleRefresher(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else if (selected != 0) {
            // Back from Account returns to Expenses; back there leaves.
            context.go(expensesLocation);
          } else {
            SystemNavigator.pop();
          }
        },
        child: width < Breakpoints.shellTablet
            ? Scaffold(
                extendBody: useGlassShell,
                body: child,
                bottomNavigationBar: ModeTabBar(
                  items: _items,
                  selectedIndex: selected,
                  onSelect: onSelect,
                ),
              )
            : _TabletLayout(
                selected: selected,
                onSelect: onSelect,
                child: child,
              ),
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final int? selected;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = PersonalShell._items.where((i) => !i.modeSwitch).toList();
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: onSelect,
            backgroundColor: AppColors.surface(isDark),
            indicatorColor: AppColors.brand.withValues(alpha: 0.2),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: Text(t.label),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ModeSwitchRailButton(
                    to: AppMode.shared,
                    onPressed: () => onSelect(tabs.length),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
