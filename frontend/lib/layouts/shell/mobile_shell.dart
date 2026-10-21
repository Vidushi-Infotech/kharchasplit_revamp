import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/lifecycle/app_lifecycle_refresher.dart';
import 'floating_bottom_bar.dart';
import 'pick_group_for_expense_sheet.dart';
import 'shell_state.dart';
import 'whats_new_sheet.dart';

/// Mobile shell with the floating bottom bar.
///
/// Tabs (Splitwise-style): Groups · Friends · ➕ · Activity · Account — see
/// [ShellTab] for the index ↔ route mapping shared with the tablet rail.
class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive the active tab from the current route so it stays in sync
    // when other widgets navigate (e.g. a notification tap → Activity).
    final routerState = GoRouterState.of(context);
    final routeIndex = ShellTab.fromLocation(routerState.uri.path);
    final stickyIndex = ref.watch(selectedNavIndexProvider);
    final selectedIndex = routeIndex ?? stickyIndex;

    // Keep the provider in sync so other readers (e.g. PopScope below) see
    // the same index. Defer to next frame to avoid setState-during-build.
    if (routeIndex != null && routeIndex != stickyIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedNavIndexProvider.notifier).state = routeIndex;
      });
    }

    // One-time "A new look" intro to the new tab bar.
    WhatsNewSheet.maybeShow(context);

    // Resume-after-long-background refresh lives here (not in main.dart)
    // because only a signed-in user inside the shell has data to refresh.
    return AppLifecycleRefresher(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else if (selectedIndex != ShellTab.groups) {
            // Back from any other tab returns to Groups (the home tab);
            // back on Groups leaves the app.
            ref.read(selectedNavIndexProvider.notifier).state =
                ShellTab.groups;
            context.go(ShellTab.locations[ShellTab.groups]!);
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          extendBody: true,
          body: child,
          bottomNavigationBar: FloatingBottomBar(
            selectedIndex: selectedIndex,
            fabIndex: ShellTab.create,
            onItemSelected: (index) {
              ref.read(selectedNavIndexProvider.notifier).state = index;
              _navigateToTab(context, index);
            },
            items: const [
              FloatingNavItem(
                icon: Icons.group_rounded,
                label: AppStrings.groups,
              ),
              FloatingNavItem(
                icon: Icons.people_alt_rounded,
                label: AppStrings.friends,
              ),
              FloatingNavItem(
                icon: Icons.add_rounded,
                label: AppStrings.addExpense,
              ),
              FloatingNavItem(
                icon: Icons.timeline_rounded,
                label: AppStrings.activity,
              ),
              FloatingNavItem(
                icon: Icons.person_outline_rounded,
                label: AppStrings.account,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    if (index == ShellTab.create) {
      // The + button opens a group picker so the user can quickly add an
      // expense to one of their groups. Creating a new group is offered as
      // a secondary action inside the sheet.
      PickGroupForExpenseSheet.show(context);
      return;
    }
    final location = ShellTab.locations[index];
    if (location != null) context.go(location);
  }
}
