import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/models/personal_summary_model.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/insights/category_breakdown_card.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/insights/daily_spend_chart.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/insights/spend_overview_card.dart';
import 'package:kharchasplit/modules/personal_expenses/widgets/insights/trend_chart.dart';

final _json = <String, dynamic>{
  'month': '2026-10',
  'previousMonth': '2026-09',
  'spent': 1849,
  'income': 40000,
  'previousSpent': 800,
  'previousIncome': 0,
  'categories': [
    {'category': 'fuel', 'amount': 1500, 'previousAmount': 0},
    {'category': 'food', 'amount': 349, 'previousAmount': 800},
    {'category': 'travel', 'amount': 0, 'previousAmount': 80},
  ],
  'incomeCategories': [
    {'category': 'salary', 'amount': 40000},
  ],
  'daily': [
    for (var d = 1; d <= 31; d++)
      {
        'day': '2026-10-${d.toString().padLeft(2, '0')}',
        'spent': d == 20 ? 1500 : (d == 5 ? '349' : 0),
        'income': d == 1 ? 40000 : 0,
      },
  ],
  'trend': [
    for (final m in ['05', '06', '07', '08', '09', '10'])
      {'month': '2026-$m', 'spent': m == '10' ? 1849 : 100, 'income': 0},
  ],
};

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));

void main() {
  final summary = PersonalSummary.fromJson(_json);

  test('summary from the server', () {
    expect(summary.month, DateTime(2026, 10));
    expect(summary.spent, 1849);
    expect(summary.daily, hasLength(31));
    expect(summary.daily[4].spent, 349);
    expect(summary.trend.last.month, DateTime(2026, 10));
    expect(summary.spentChange, closeTo(1.31125, 1e-6));
    expect(summary.isEmpty, isFalse);
    final none = PersonalSummary.fromJson({
      ..._json,
      'spent': 0,
      'income': 0,
      'previousSpent': 0,
    });
    expect(none.isEmpty, isTrue);
    expect(none.spentChange, isNull);
  });

  testWidgets('overview compares with last month', (tester) async {
    await _pump(tester, SpendOverviewCard(summary: summary));
    expect(find.text('131% more than September'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('category rows, and tapping one fills the middle',
      (tester) async {
    await _pump(tester, CategoryBreakdownCard(summary: summary));
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget); // only last month
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pump();
    expect(find.text('Food'), findsNWidgets(2));
    expect(find.text('19%'), findsOneWidget);
  });

  testWidgets('charts build', (tester) async {
    await _pump(
      tester,
      Column(children: [
        DailySpendChart(summary: summary),
        TrendChart(summary: summary),
      ]),
    );
    expect(find.text('Day by day'.toUpperCase()), findsOneWidget);
    expect(find.text('Oct'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
