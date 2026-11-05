import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/services/review_prompt.dart';

void main() {
  final now = DateTime(2026, 11, 5, 12);
  final weekAgo = now.subtract(const Duration(days: 7));

  bool ask({
    int wins = 3,
    DateTime? firstWin,
    DateTime? lastAsked,
    int asks = 0,
  }) => ReviewPrompt.shouldAsk(
    wins: wins,
    firstWin: firstWin ?? weekAgo,
    lastAsked: lastAsked,
    asks: asks,
    now: now,
  );

  test('asks a returning user after a few things worked', () {
    expect(ask(), isTrue);
  });

  test('waits for enough wins', () {
    expect(ask(wins: 2), isFalse);
  });

  test('waits until the user has been around a few days', () {
    expect(ask(firstWin: now.subtract(const Duration(days: 1))), isFalse);
  });

  test('leaves months between asks', () {
    expect(ask(lastAsked: now.subtract(const Duration(days: 30))), isFalse);
    expect(ask(lastAsked: now.subtract(const Duration(days: 121))), isTrue);
  });

  test('stops after the last ask', () {
    expect(ask(asks: ReviewPrompt.maxAsks), isFalse);
  });
}
