import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/headers/glass_large_title.dart';

void main() {
  const title = 'Friends';

  Widget app(ScrollController controller) => MaterialApp(
    home: Scaffold(
      body: GlassLargeTitleFrame(
        title: title,
        child: Builder(
          builder: (context) => ListView(
            controller: controller,
            padding: EdgeInsets.only(
              top: GlassLargeTitleFrame.topInset(context),
            ),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 56, child: Text('Row $i')),
            ],
          ),
        ),
      ),
    ),
  );

  // The large title is the 32pt one; the small one sits in the button row.
  Finder largeTitle() => find.byWidgetPredicate(
    (w) => w is Text && w.data == title && w.style?.fontSize == 32,
  );
  Finder smallTitle() => find.byWidgetPredicate(
    (w) => w is Text && w.data == title && w.style?.fontSize != 32,
  );
  double opacityOf(WidgetTester tester, Finder text) => tester
      .widget<Opacity>(
        find.ancestor(of: text, matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('shows the large title at rest', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    expect(largeTitle(), findsOneWidget);
    expect(opacityOf(tester, largeTitle()), 1);
    expect(opacityOf(tester, smallTitle()), 0);
  });

  testWidgets('collapses into the small title after scrolling', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(100));

    expect(opacityOf(tester, smallTitle()), 1);
    final large = largeTitle();
    expect(
      large.evaluate().isEmpty || opacityOf(tester, large) == 0,
      isTrue,
      reason: 'large title should be gone or transparent',
    );
  });
}
