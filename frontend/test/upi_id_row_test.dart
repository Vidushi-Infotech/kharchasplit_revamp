import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kharchasplit/modules/profile/widgets/upi_id_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(String? upiId) => MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: UpiIdRow(upiId: upiId)),
        ),
        GoRoute(
          path: '/edit',
          name: 'edit-profile',
          builder: (_, _) => const Scaffold(body: Text('edit profile')),
        ),
      ]),
    );

void main() {
  testWidgets('NEW shows until the row is tapped once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('UPI ID'));
    await tester.pumpAndSettle();
    expect(find.text('edit profile'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('seen_new_upi_id_v1'), isTrue);

    // Next time the Account tab opens, no badge.
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('no NEW once a UPI ID is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app('payer@upi'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsNothing);
    expect(find.text('payer@upi'), findsOneWidget);
  });
}
