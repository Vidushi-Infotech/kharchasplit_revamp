import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/utils/currency_catalog.dart';
import 'package:kharchasplit/core/utils/fx_convert.dart';
import 'package:kharchasplit/core/utils/receipt_scan_parser.dart';
import 'package:kharchasplit/core/utils/receipt_scan_rows.dart';
import 'package:kharchasplit/data/expenses/expenses_repository.dart';
import 'package:kharchasplit/models/models.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_form_helpers.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_fx.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_provider.dart';
import 'package:kharchasplit/modules/expenses/state/add_expense_split_math.dart';
import 'package:kharchasplit/modules/expenses/state/expense_error_message.dart';
import 'package:kharchasplit/modules/expenses/state/fx_rate_text.dart';
import 'package:kharchasplit/modules/expenses/state/receipt_scan_apply.dart';

/// A converted expense as GET /expenses/:id returns it: entered as $100.00
/// split $33.33 / $33.33 / $33.34 by exact amounts, stored in INR.
Map<String, dynamic> _convertedJson({
  String splitType = 'unequal',
  List<Map<String, dynamic>>? payers,
}) {
  const rate = 83.12;
  final total = FxConvert.totalPaise(10000, rate); // 8312.00
  final parts = FxConvert.partsPaise([3333, 3333, 3334], rate, total);
  return {
    'id': 'e1',
    'group_id': 'g1',
    'description': 'Dinner',
    'amount': (total / 100).toStringAsFixed(2),
    'currency': 'INR',
    'paid_by': 'a',
    'paid_by_name': 'A',
    'split_type': splitType,
    'expense_date': '2026-10-16T00:00:00.000Z',
    'original_amount': '100.00',
    'original_currency': 'USD',
    'fx_rate': '83.12',
    'fx_date': '2026-10-16',
    'has_receipt': true,
    'participants': [
      for (var i = 0; i < 3; i++)
        {
          'user_id': ['a', 'b', 'c'][i],
          'name': ['A', 'B', 'C'][i],
          'amount': (parts[i] / 100).toStringAsFixed(2),
        },
    ],
    'payers': ?payers,
  };
}

void main() {
  group('FxConvert (same maths as the server)', () {
    test('total rounds once; parts add up exactly', () {
      final total = FxConvert.totalPaise(12345, 83.1234); // $123.45
      expect(total, 1026158); // 10261.58
      final parts = FxConvert.partsPaise([4115, 4115, 4115], 83.1234, total);
      expect(parts.reduce((a, b) => a + b), total);
      expect(parts, [342053, 342053, 342052]);
    });

    test('back to the original currency recovers what was typed', () {
      const rate = 83.12;
      final typed = [3333, 3333, 3334];
      final total = FxConvert.totalPaise(10000, rate);
      final stored = FxConvert.partsPaise(typed, rate, total);
      expect(FxConvert.backToOriginal(stored, 10000), typed);
    });

    test('back: zeros stay zero, sums stay exact', () {
      final back = FxConvert.backToOriginal([0, 50001, 49999], 1201);
      expect(back.first, 0);
      expect(back.reduce((a, b) => a + b), 1201);
    });
  });

  group('ExpenseModel', () {
    test('parses the original-currency fields', () {
      final e = ExpenseModel.fromJson(_convertedJson());
      expect(e.isConverted, isTrue);
      expect(e.originalAmount, 100.0);
      expect(e.originalCurrency, 'USD');
      expect(e.fxRate, 83.12);
      expect(e.fxDate, DateTime(2026, 10, 16));
      expect(e.hasReceipt, isTrue);
    });

    test('an expense in the group currency is not converted', () {
      final json = _convertedJson()
        ..remove('original_amount')
        ..remove('original_currency')
        ..remove('fx_rate')
        ..remove('has_receipt');
      final e = ExpenseModel.fromJson(json);
      expect(e.isConverted, isFalse);
      expect(e.hasReceipt, isFalse);
    });
  });

  group('editing a converted expense', () {
    test('reopens in USD with the exact amounts that were typed', () {
      final e = ExpenseModel.fromJson(_convertedJson());
      final s = addExpenseStateFromExpense(e, inOriginalCurrency: true);
      expect(s.amount, 100.0);
      expect(s.entryCurrency, 'USD');
      expect(s.currency, r'$');
      expect(s.splits, {'a': 33.33, 'b': 33.33, 'c': 33.34});
      final owed = addExpenseOwedPaise(s, const ['a', 'b', 'c']);
      expect(owed.values.reduce((a, b) => a + b), 10000);
      // The saved rate is kept while currency and date don't change.
      expect(addExpenseFxRateOverride(s), 83.12);
      expect(
        addExpenseFxRateOverride(s.copyWith(date: DateTime(2026, 10, 17))),
        isNull,
      );
    });

    test('multiple payers convert back to the paisa', () {
      final e = ExpenseModel.fromJson(
        _convertedJson(
          payers: [
            {'user_id': 'a', 'name': 'A', 'amount': '6234.00'},
            {'user_id': 'b', 'name': 'B', 'amount': '2078.00'},
          ],
        ),
      );
      final s = addExpenseStateFromExpense(e, inOriginalCurrency: true);
      expect(s.payers, {'a': 75.0, 'b': 25.0});
      expect(payersLeftPaise(s.amount, s.payers), 0);
    });

    test('percent split keeps its percentages', () {
      final json = _convertedJson(splitType: 'percentage');
      for (final p in json['participants'] as List) {
        (p as Map)['percentage'] = '33.33';
      }
      final s = addExpenseStateFromExpense(
        ExpenseModel.fromJson(json),
        inOriginalCurrency: true,
      );
      expect(s.splits.values.toSet(), {33.33});
    });

    test('flag off → today\'s behaviour: group currency amounts', () {
      final e = ExpenseModel.fromJson(_convertedJson());
      final s = addExpenseStateFromExpense(e);
      expect(s.entryCurrency, isNull);
      expect(s.amount, 8312.0);
    });
  });

  group('currency choice', () {
    final base = AddExpenseState(date: _date, amount: 100);
    test('another currency / back to the group one', () {
      final usd = addExpenseWithCurrency(base, 'USD', '₹');
      expect(usd.entryCurrency, 'USD');
      expect(usd.currency, r'$');
      expect(usd.amount, 100);
      final back = addExpenseWithCurrency(
        usd.copyWith(manualFxRate: 80.0),
        'INR',
        '₹',
      );
      expect(back.entryCurrency, isNull);
      expect(back.currency, '₹');
      expect(back.manualFxRate, isNull);
    });

    test('a typed rate is sent; none in the group currency', () {
      final usd = addExpenseWithCurrency(base, 'USD', '₹');
      expect(addExpenseFxRateOverride(usd), isNull);
      expect(addExpenseFxRateOverride(usd.copyWith(manualFxRate: 84.5)), 84.5);
      expect(
        addExpenseFxRateOverride(base.copyWith(manualFxRate: 84.5)),
        isNull,
      );
    });

    test('preview equals what the server stores', () {
      expect(addExpenseConvertedPaise(123.45, 83.1234), 1026158);
    });

    test('picker order: group, recent, then the rest, no repeats', () {
      final order = CurrencyCatalog.pickerOrder('INR', ['THB', 'AED', 'USD']);
      expect(order.take(3).map((c) => c.code), ['INR', 'THB', 'USD']);
      expect(order.length, CurrencyCatalog.all.length);
      expect(CurrencyCatalog.byCode('AED'), isNull); // not in ECB data
    });
  });

  group('wording', () {
    test('rate lines', () {
      expect(fxRateLine('USD', 83.12, '₹'), '1 USD = ₹83.12');
      expect(fxRateLine('IDR', 0.005321, '₹'), '1 IDR = ₹0.005321');
      expect(
        fxExpenseOriginalLine(
          ExpenseModel.fromJson(_convertedJson()),
          now: DateTime(2026, 10, 21),
        ),
        r'Paid $100.00 · 1 USD = ₹83.12 on 16 Oct',
      );
    });

    test('server errors', () {
      expect(
        expenseErrorMessage(
          ExpensesApiException('x', statusCode: 503, code: 'FX_UNAVAILABLE'),
          fallback: 'f',
        ),
        contains('exchange rate'),
      );
      expect(
        expenseErrorMessage(
          ExpensesApiException('x', statusCode: 400, code: 'INVALID_RECEIPT'),
          fallback: 'f',
        ),
        contains('8 MB'),
      );
    });
  });

  group('receipt suggestions', () {
    final scan = ReceiptScanResult(
      total: 1234.5,
      totalConfidence: 0.9,
      date: DateTime(2026, 10, 16),
      merchant: 'Hotel Sai Palace',
    );

    test('empty form: everything offered and ticked', () {
      final form = AddExpenseState(date: _date);
      final s = receiptSuggestions(form, scan, dateIsDefault: true);
      expect(s.map((x) => x.field), [
        ReceiptField.amount,
        ReceiptField.date,
        ReceiptField.title,
      ]);
      expect(s.every((x) => x.preselected), isTrue);
    });

    test('typed values are offered unticked, never overwritten', () {
      final form = AddExpenseState(date: _date, amount: 500, title: 'Dinner');
      final s = receiptSuggestions(form, scan, dateIsDefault: false);
      expect(s.where((x) => x.preselected), isEmpty);
      expect(s.every((x) => x.replaces), isTrue);
      final applied = applyReceiptScan(form, scan, const {});
      expect(applied.amount, 500);
      expect(applied.title, 'Dinner');
    });

    test('applies only the ticked fields', () {
      final form = AddExpenseState(date: _date, title: 'Dinner');
      final applied = applyReceiptScan(form, scan, {ReceiptField.amount});
      expect(applied.amount, 1234.5);
      expect(applied.title, 'Dinner');
      expect(applied.date, _date);
    });

    test('same amount already entered → not offered again', () {
      final form = AddExpenseState(date: _date, amount: 1234.5);
      final s = receiptSuggestions(form, scan, dateIsDefault: true);
      expect(s.map((x) => x.field), isNot(contains(ReceiptField.amount)));
    });
  });

  test('OCR rows: label and amount columns join into one line', () {
    final text = receiptRowsText(const [
      ReceiptOcrLine('Sub Total', left: 10, top: 100, bottom: 120),
      ReceiptOcrLine('Grand Total', left: 10, top: 130, bottom: 150),
      ReceiptOcrLine('1,000.00', left: 300, top: 101, bottom: 121),
      ReceiptOcrLine('1,050.00', left: 300, top: 132, bottom: 152),
      ReceiptOcrLine('CAFE MOCHA', left: 80, top: 20, bottom: 45),
    ]);
    expect(text, 'CAFE MOCHA\nSub Total  1,000.00\nGrand Total  1,050.00');
    expect(parseReceiptText(text).total, 1050.0);
  });
}

final _date = DateTime(2026, 10, 21, 12);
