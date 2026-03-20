import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'shell_state.dart';

/// Tablet shell with NavigationRail
class TabletShell extends ConsumerWidget {
  final Widget child;

  const TabletShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);

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
            indicatorColor: AppColors.brand.withOpacity(0.2),
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
                icon: Icon(Icons.home_rounded),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.group_rounded),
                selectedIcon: Icon(Icons.group_rounded),
                label: Text('Groups'),
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
                label: Text('Add'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people_alt_rounded),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: Text('Friends'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: const Text('Activity'),
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
    switch (index) {
      case 0:
        context.go('/home/dashboard');
        break;
      case 1:
        context.go('/home/groups');
        break;
      case 2:
        context.go('/add-expense');
        break;
      case 3:
        context.go('/home/friends');
        break;
      case 4:
        context.go('/home/activity');
        break;
    }
  }
}
