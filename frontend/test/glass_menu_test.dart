import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/menus/glass_menu.dart';

void main() {
  Future<String?> open(WidgetTester tester, List<GlassMenuItem<String>> items) async {
    String? result = 'unset';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () async => result = await showGlassMenu(ctx, items),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('picking a row resolves to its value', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            child: const Text('open'),
            onPressed: () async => picked = await showGlassMenu(ctx, const [
              GlassMenuItem(value: 'csv', label: 'Export to CSV'),
              GlassMenuItem(value: 'pdf', label: 'Statement (PDF)'),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Statement (PDF)'), findsOneWidget);
    await tester.tap(find.text('Statement (PDF)'));
    await tester.pumpAndSettle();
    expect(picked, 'pdf');
    expect(find.text('Statement (PDF)'), findsNothing);
  });

  testWidgets('tapping outside dismisses with null', (tester) async {
    String? picked = 'unset';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              child: const Text('open'),
              onPressed: () async => picked = await showGlassMenu(ctx, const [
                GlassMenuItem(value: 'a', label: 'All groups', checked: true),
                GlassMenuItem(value: 'b', label: 'Groups you owe'),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Groups you owe'), findsNothing);
  });

  testWidgets('opens from a right-edge button without overflowing', (tester) async {
    await open(tester, const [GlassMenuItem(value: 'x', label: 'Edit history')]);
    expect(find.text('Edit history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
