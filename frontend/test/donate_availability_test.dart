import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/components/buttons/donate_heart_button.dart';
import 'package:kharchasplit/core/constants/donate_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('no donate heart on iOS (App Store rules)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(DonateConfig.isAvailable, isFalse);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DonateHeartButton())),
    );
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('donate heart on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(DonateConfig.isAvailable, isTrue);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DonateHeartButton())),
    );
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
