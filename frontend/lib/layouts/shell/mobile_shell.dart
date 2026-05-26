import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'floating_bottom_bar.dart';
import 'pick_group_for_expense_sheet.dart';
import 'shell_state.dart';

/// Mobile shell with BottomNavigationBar
class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// Map a route location to the index of the bottom-nav tab it belongs to.
  /// Returns null when the location isn't owned by a tab (e.g. deep links
  /// like /home/groups/:groupId) — in that case we keep the last-tapped
  /// index.
  int? _indexFromLocation(String location) {
    if (location.startsWith('/home/dashboard')) return 0;
    if (location.startsWith('/home/groups')) return 1;
    if (location.startsWith('/home/create-group') ||
        location.startsWith('/add-expense')) {
      return 2;
    }
    if (location.startsWith('/home/personal')) return 3;
    if (location.startsWith('/home/profile')) return 4;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive the active tab from the current route so it stays in sync
    // when other widgets navigate (e.g. Home → "See all" → Groups).
    final routerState = GoRouterState.of(context);
    final routeIndex = _indexFromLocation(routerState.uri.path);
    final stickyIndex = ref.watch(selectedNavIndexProvider);
    final selectedIndex = routeIndex ?? stickyIndex;

    // Keep the provider in sync so other readers (e.g. PopScope below) see
    // the same index. Defer to next frame to avoid setState-during-build.
    if (routeIndex != null && routeIndex != stickyIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedNavIndexProvider.notifier).state = routeIndex;
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else if (selectedIndex != 0) {
          ref.read(selectedNavIndexProvider.notifier).state = 0;
          context.go('/home/dashboard');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: FloatingBottomBar(
          selectedIndex: selectedIndex,
          fabIndex: 2,
          onItemSelected: (index) {
            ref.read(selectedNavIndexProvider.notifier).state = index;
            _navigateToTab(context, index);
          },
          items: [
            const FloatingNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
            ),
            const FloatingNavItem(
              icon: Icons.group_rounded,
              label: 'Groups',
            ),
            const FloatingNavItem(
              icon: Icons.add_rounded,
              label: 'Create',
            ),
            const FloatingNavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Personal',
            ),
            const FloatingNavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
            ),
          ],
        ),
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
        // The + button now opens a group picker so the user can quickly
        // add an expense to one of their groups. Creating a new group
        // is offered as a secondary action inside the sheet.
        PickGroupForExpenseSheet.show(context);
        break;
      case 3:
        context.go('/home/personal');
        break;
      case 4:
        context.go('/home/profile');
        break;
    }
  }
}
