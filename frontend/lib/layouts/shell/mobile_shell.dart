import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/lifecycle/app_lifecycle_refresher.dart';
import 'glass_shell_bar.dart';
import 'pick_group_for_expense_sheet.dart';
import 'shell_bottom_bar.dart';
import 'shell_state.dart';
import 'whats_new_sheet.dart';

/// Mobile shell: flat bottom tabs (Groups · Friends · Activity · Account)
/// plus a floating "Add expense" button — see [ShellTab] for the index ↔
/// route mapping shared with the tablet rail.
class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({Key? key, required this.child}) : super(key: key);

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
            ref.read(selectedNavIndexProvider.notifier).state = ShellTab.groups;
            context.go(ShellTab.locations[ShellTab.groups]!);
          } else {
            SystemNavigator.pop();
          }
        },
        child: _buildScaffold(
          context,
          ref,
          routerState.uri.path,
          selectedIndex,
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref,
    String path,
    int? selectedIndex,
  ) {
    void onTab(int index) {
      ref.read(selectedNavIndexProvider.notifier).state = index;
      _navigateToTab(context, index);
    }

    void addExpense() => PickGroupForExpenseSheet.show(context);
    final showAdd = _showsAddExpense(path);

    if (useGlassShell) {
      // iOS 26: native Liquid Glass tab bar; content scrolls under it
      // (extendBody) and pushed pages slide over it.
      return Scaffold(
        extendBody: true,
        body: child,
        floatingActionButton: showAdd
            ? GlassAddExpenseButton(onPressed: addExpense)
            : null,
        bottomNavigationBar: GlassShellTabBar(
          selectedTab: selectedIndex,
          onTabSelected: onTab,
        ),
      );
    }

    return Scaffold(
      body: child,
      floatingActionButton: showAdd
          ? ShellAddExpenseButton(onPressed: addExpense)
          : null,
      bottomNavigationBar: ShellBottomBar(
        selectedTab: selectedIndex,
        onTabSelected: onTab,
      ),
    );
  }

  /// The floating "Add expense" button shows on the Groups, Friends and
  /// Activity tab roots only — screens pushed inside the shell (group
  /// detail…) have their own add button, and Account has nothing to add.
  static bool _showsAddExpense(String path) =>
      path == ShellTab.locations[ShellTab.groups] ||
      path == ShellTab.locations[ShellTab.friends] ||
      path == ShellTab.locations[ShellTab.activity];

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
