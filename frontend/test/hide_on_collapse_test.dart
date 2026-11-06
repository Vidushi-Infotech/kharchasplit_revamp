import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/headers/glass_large_title.dart';

void main() {
  testWidgets('a HideOnCollapse action goes away when the header collapses',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlassLargeTitleFrame(
          title: 'Groups',
          actions: const [
            Icon(Icons.search_rounded),
            HideOnCollapse(child: Icon(Icons.favorite_rounded)),
          ],
          child: ListView(
            children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('row $i'))],
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
