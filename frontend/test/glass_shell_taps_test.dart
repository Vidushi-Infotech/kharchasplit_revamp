import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/buttons/glass_icon_button.dart';
import 'package:kharchasplit/components/headers/glass_large_title.dart';
import 'package:kharchasplit/layouts/shell/glass_shell_bar.dart';
import 'package:kharchasplit/layouts/shell/shell_state.dart';

void main() {
  testWidgets('every glass tab reports its tap', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: GlassShellTabBar(
          selectedTab: ShellTab.groups,
          onTabSelected: taps.add,
        ),
      ),
    ));
    for (final label in ['Friends', 'Activity', 'Account', 'Groups', 'Friends']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(taps, [
      ShellTab.friends,
      ShellTab.activity,
      ShellTab.account,
      ShellTab.groups,
      ShellTab.friends,
    ]);
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
