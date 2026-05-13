import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(selectedNavIndexProvider.notifier).state = index;
          _navigateToTab(context, index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface(isDark),
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.textSecondary(isDark),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.brand, AppColors.tealDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            label: 'Create',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Personal',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Activity',
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
