import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'shell_state.dart';
import 'whats_new_sheet.dart';

/// Tablet shell with NavigationRail.
///
/// Same tab order as the mobile bottom bar (see [ShellTab]):
/// Groups · Friends · ➕ · Activity · Account.
class TabletShell extends ConsumerWidget {
  final Widget child;

  const TabletShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Route first, last-tapped index as the fallback — mirrors the mobile
    // shell so a deep link or notification tap highlights the right tab.
    final routeIndex =
        ShellTab.fromLocation(GoRouterState.of(context).uri.path);
    final selectedIndex =
        routeIndex ?? ref.watch(selectedNavIndexProvider);

    // One-time "A new look" intro to the new tab bar.
    WhatsNewSheet.maybeShow(context);

    return Scaffold(
      body: Row(
        children: [
          // NavigationRail
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              ref.read(selectedNavIndexProvider.notifier).state = index;
              _navigateToTab(context, index);
            },
            backgroundColor: AppColors.surface(isDark),
            indicatorColor: AppColors.brand.withValues(alpha: 0.2),
            leading: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.brand, AppColors.tealDark],
                  ),
                ),
                child: const Icon(Icons.receipt_rounded, color: Colors.white),
              ),
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.group_rounded),
                selectedIcon: Icon(Icons.group_rounded),
                label: Text(AppStrings.groups),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people_alt_rounded),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: Text(AppStrings.friends),
              ),
              NavigationRailDestination(
                icon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.brand, AppColors.tealDark],
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
                selectedIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.brand, AppColors.tealDark],
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
                label: const Text(AppStrings.addExpense),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.timeline_rounded),
                selectedIcon: Icon(Icons.timeline_rounded),
                label: Text(AppStrings.activity),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text(AppStrings.account),
              ),
            ],
          ),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    if (index == ShellTab.create) {
      context.go('/add-expense');
      return;
    }
    final location = ShellTab.locations[index];
    if (location != null) context.go(location);
  }
}
