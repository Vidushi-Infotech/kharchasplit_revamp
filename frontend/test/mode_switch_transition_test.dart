import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kharchasplit/core/state/app_mode.dart';
import 'package:kharchasplit/layouts/shell/mode_switch_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two "apps" with the real shell pages, each with a button that switches.
GoRouter _router() => GoRouter(
  initialLocation: '/home/groups',
  routes: [
    ShellRoute(
      pageBuilder: (context, state, child) => modeShellPage(
        key: 'shared-shell',
        mode: AppMode.shared,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home/groups',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => switchAppMode(context, AppMode.personal),
                child: const Text('GROUPS PAGE'),
              ),
            ),
          ),
        ),
      ],
    ),
    ShellRoute(
      pageBuilder: (context, state, child) => modeShellPage(
        key: 'personal-shell',
        mode: AppMode.personal,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/personal',
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('PERSONAL PAGE'))),
        ),
      ],
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('switching opens the other mode in a circle, with its name',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GROUPS PAGE'));
    await tester.pump(); // navigation
    await tester.pump(const Duration(milliseconds: 300)); // mid-way

    // Both modes on screen: the old one behind, the new one clipped.
    expect(find.text('GROUPS PAGE'), findsOneWidget);
    expect(find.text('PERSONAL PAGE'), findsOneWidget);
    expect(find.byType(ClipPath), findsWidgets);
    expect(find.text('Personal'), findsOneWidget); // the badge

    await tester.pumpAndSettle();
    expect(find.text('GROUPS PAGE'), findsNothing);
    expect(find.text('PERSONAL PAGE'), findsOneWidget);
    expect(find.text('Personal'), findsNothing);
    expect(AppModeStore.current, AppMode.personal);
  });

  testWidgets('arriving any other way just fades (no circle, no badge)',
      (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go('/personal');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Personal'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('PERSONAL PAGE'), findsOneWidget);
  });
}
