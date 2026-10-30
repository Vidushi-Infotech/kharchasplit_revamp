import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/category_model.dart';
import 'package:kharchasplit/models/wallet_source_model.dart';
import 'package:kharchasplit/modules/personal_expenses/state/voice_entry_controller.dart';
import 'package:kharchasplit/modules/personal_expenses/state/voice_entry_parser.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/voice_entry_sheet.dart';

/// Hears [heard] straight away, without a microphone.
class _Heard extends VoiceEntryController {
  _Heard(this.heard);
  final VoiceState heard;

  @override
  VoiceState build() => heard;

  @override
  Future<void> start() async => state = heard;
}

/// Opens the sheet; what it hands back lands in [result].
Future<void> _open(
  WidgetTester tester,
  VoiceState heard, [
  List<VoiceDraft?>? result,
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceEntryProvider.overrideWith(() => _Heard(heard))],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final draft = await VoiceEntrySheet.show(
                  context,
                  accounts: const [
                    WalletSource(
                      id: 'cash',
                      name: 'Cash',
                      type: WalletSourceType.cash,
                      balance: 0,
                    ),
                  ],
                );
                result?.add(draft);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows what it understood and hands it back', (tester) async {
    final result = <VoiceDraft?>[];
    await _open(
      tester,
      const VoiceState(
        phase: VoicePhase.done,
        transcript: 'kal 450 ka khana cash se',
      ),
      result,
    );
    expect(find.text('"kal 450 ka khana cash se"'), findsOneWidget);
    for (final chip in [
      '₹450.00',
      'Expense',
      'Food',
      'Khana',
      'Yesterday',
      'Cash',
    ]) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();
    expect(find.text('Use this'), findsNothing);
    final draft = result.single!;
    expect(draft.amount, 450);
    expect(draft.daysAgo, 1);
    expect(draft.accountId, 'cash');
  });

  testWidgets('no amount: can only try again', (tester) async {
    await _open(
      tester,
      const VoiceState(phase: VoicePhase.done, transcript: 'some coffee'),
    );
    expect(find.text('No amount heard. Say it with a number.'), findsOneWidget);
    final use = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Use this'),
    );
    expect(use.onPressed, isNull);
  });

  testWidgets('no microphone', (tester) async {
    await _open(tester, const VoiceState(phase: VoicePhase.unavailable));
    expect(find.textContaining("Voice isn't available"), findsOneWidget);
  });

  test('draft category for the form', () {
    expect(
      VoiceEntryParser.parse('got salary 50000').category,
      CategoryModel.salary,
    );
  });
}
