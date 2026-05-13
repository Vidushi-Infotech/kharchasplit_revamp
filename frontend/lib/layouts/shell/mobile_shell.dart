import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'floating_bottom_bar.dart';
import 'shell_state.dart';

/// Mobile shell with BottomNavigationBar
class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);

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
            FloatingNavItem(
              icon: Icons.notifications_rounded,
              label: 'Activity',
              badgeCount: unreadCount,
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
        context.push('/home/create-group');
        break;
      case 3:
        context.go('/home/personal');
        break;
      case 4:
        context.go('/home/activity');
        break;
    }
  }
}
