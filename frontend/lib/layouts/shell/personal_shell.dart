import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/lifecycle/app_lifecycle_refresher.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/state/app_mode.dart';
import '../../core/state/feature_flags_provider.dart';
import '../../core/theme/app_colors.dart';
import 'glass_shell_bar.dart' show useGlassShell;
import 'mode_tab_bar.dart';
import 'web_shell.dart';

/// Shell of the Personal "app": the user's own money, apart from groups.
/// Its own tabs (bottom bar on phones, a rail on tablets), the last of
/// which switches back to Groups. Desktop keeps the one sidebar for both.
class PersonalShell extends ConsumerWidget {
  const PersonalShell({super.key, required this.child});

  final Widget child;

  static const expensesLocation = '/personal';
  static const insightsLocation = '/personal/insights';
  static const budgetsLocation = '/personal/budgets';
  static const accountLocation = '/personal/account';

  static const _home = (
    expensesLocation,
    ShellNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: AppStrings.personalHome,
    ),
  );
  static const _insights = (
    insightsLocation,
    ShellNavItem(
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
      label: AppStrings.insights,
    ),
  );
  static const _budgets = (
    budgetsLocation,
    ShellNavItem(
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings_rounded,
      label: AppStrings.budgets,
    ),
  );
  static const _account = (
    accountLocation,
    ShellNavItem(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: AppStrings.account,
    ),
  );
  static const _switch = ShellNavItem(
    icon: Icons.groups_rounded,
    selectedIcon: Icons.groups_rounded,
    label: AppStrings.groups,
    modeSwitch: true,
  );

  /// The tab owning [path]: the longest location it starts with (so
  /// /personal/account isn't taken for /personal).
  static int? _indexOf(List<String> locations, String path) {
    int? best;
    for (var i = 0; i < locations.length; i++) {
      final l = locations[i];
      if ((path == l || path.startsWith('$l/')) &&
          (best == null || l.length > locations[best].length)) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppModeStore.remember(AppMode.personal);
    final width = MediaQuery.sizeOf(context).width;
    if (width >= Breakpoints.shellWeb) return WebShell(child: child);

    // Tabs in bar order; the mode switch follows them.
    final tabs = [
      _home,
      if (watchFeature(ref, 'personalInsights')) _insights,
      if (watchFeature(ref, 'personalBudgets')) _budgets,
      _account,
    ];
    final locations = [for (final t in tabs) t.$1];
    final items = [for (final t in tabs) t.$2, _switch];
    final selected = _indexOf(locations, GoRouterState.of(context).uri.path);
    void onSelect(int i) {
      if (i >= locations.length) {
        switchAppMode(context, AppMode.shared);
      } else if (i != selected) {
        context.go(locations[i]);
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
                  items: items,
                  selectedIndex: selected,
                  onSelect: onSelect,
                ),
              )
            : _TabletLayout(
                items: items,
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
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final List<ShellNavItem> items;
  final int? selected;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = items.where((i) => !i.modeSwitch).toList();
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
