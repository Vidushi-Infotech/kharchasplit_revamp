import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_catalog.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';

/// Wording of exchange rates on the Add expense form and the expense
/// detail. Pure formatting, no widgets.

/// "₹83.12" for 1 unit at [rate] in [groupCurrency] (symbol or code):
/// 2 decimals from 1 up, 4 significant digits below (1 IDR = ₹0.005321).
String fxRateValueText(double rate, String groupCurrency) {
  final symbol = CurrencyCatalog.symbolFor(
    CurrencyFormatter.symbolFor(groupCurrency),
  );
  if (rate >= 1) return CurrencyFormatter.format(rate, currency: symbol);
  final digits = (3 - (math.log(rate) / math.ln10).floor()).clamp(2, 8);
  return '$symbol${rate.toStringAsFixed(digits)}';
}

/// "1 USD = ₹83.12".
String fxRateLine(String fromCode, double rate, String groupCurrency) =>
    '1 $fromCode = ${fxRateValueText(rate, groupCurrency)}';

/// "16 Oct" this year, "16 Oct 2025" before.
String fxShortDate(DateTime d, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  return DateFormat(d.year == year ? 'd MMM' : 'd MMM y').format(d);
}

/// "$100.00" in the currency [code] (its catalogue symbol).
String fxOriginalAmountText(double amount, String code) =>
    CurrencyFormatter.format(amount, currency: CurrencyCatalog.symbolFor(code));

/// Expense detail, under the amount of a converted expense: "Paid $100.00 ·
/// 1 USD = ₹83.12 on 16 Oct". Null for an expense in the group currency.
String? fxExpenseOriginalLine(ExpenseModel e, {DateTime? now}) {
  if (!e.isConverted) return null;
  final paid = fxOriginalAmountText(e.originalAmount!, e.originalCurrency!);
  final rate = fxRateLine(e.originalCurrency!, e.fxRate!, e.currency);
  final date = e.fxDate ?? e.date;
  return AppStrings.fxPaidOriginal(paid, rate, fxShortDate(date, now: now));
}
