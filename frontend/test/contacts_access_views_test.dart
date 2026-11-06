import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/services/contacts_access.dart';
import 'package:kharchasplit/modules/groups/widgets/contacts_access_views.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('limited with nothing shared: choose contacts, pick one, Settings',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_wrap(ContactsAccessEmpty(
      access: ContactsAccess.limited,
      onAddMore: () => taps.add('add'),
      onOpenSettings: () => taps.add('settings'),
      onPickContact: () => taps.add('pick'),
    )));
    expect(find.text('No contacts shared yet'), findsOneWidget);
    await tester.tap(find.text('Choose contacts to share'));
    await tester.tap(find.text('Pick a contact'));
    await tester.tap(find.text('Allow all contacts in Settings'));
    expect(taps, ['add', 'pick', 'settings']);
  });

  testWidgets('access off: Settings first, picker still offered',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_wrap(ContactsAccessEmpty(
      access: ContactsAccess.denied,
      onAddMore: () => taps.add('add'),
      onOpenSettings: () => taps.add('settings'),
      onPickContact: () => taps.add('pick'),
    )));
    expect(find.text('Contacts access is off'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.tap(find.text('Pick a contact'));
    expect(taps, ['settings', 'pick']);
  });

  testWidgets('limited banner says how many were shared', (tester) async {
    await tester.pumpWidget(_wrap(ContactsLimitedBanner(
      sharedCount: 3,
      onAddMore: () {},
      onAllowAll: () {},
    )));
    expect(find.text('You shared 3 contacts with KharchaSplit'), findsOneWidget);
    expect(find.text('Add more'), findsOneWidget);
    expect(find.text('Allow all'), findsOneWidget);
  });
}
