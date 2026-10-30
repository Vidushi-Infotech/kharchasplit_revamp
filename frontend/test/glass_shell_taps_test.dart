import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/buttons/glass_icon_button.dart';
import 'package:kharchasplit/components/headers/glass_large_title.dart';
import 'package:kharchasplit/layouts/shell/mode_tab_bar.dart';

void main() {
  testWidgets('every tab and the mode switch report their tap', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ModeTabBar(
          items: const [
            ShellNavItem(icon: Icons.groups, selectedIcon: Icons.groups,
                label: 'Groups'),
            ShellNavItem(icon: Icons.person, selectedIcon: Icons.person,
                label: 'Friends'),
            ShellNavItem(icon: Icons.wallet, selectedIcon: Icons.wallet,
                label: 'Personal', modeSwitch: true),
          ],
          selectedIndex: 0,
          onSelect: taps.add,
        ),
      ),
    ));
    for (final label in ['Friends', 'Personal', 'Groups']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(taps, [1, 2, 0]);
  });

  testWidgets('buttons inside a glass capsule take taps', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassActionGroup(children: [
            GlassIconButton(
              icon: Icons.search_rounded,
              sfSymbol: 'magnifyingglass',
              tooltip: 'Search',
              onPressed: () => taps.add('search'),
            ),
            GlassIconButton(
              icon: Icons.add,
              sfSymbol: 'plus',
              tooltip: 'Add',
              onPressed: () => taps.add('add'),
            ),
          ]),
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.tap(find.byIcon(Icons.add));
    expect(taps, ['search', 'add']);
  });
}
