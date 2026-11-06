import '../../../core/utils/receipt_scan_parser.dart';
import '../../../core/utils/split_calculator.dart';
import 'add_expense_provider.dart';

/// What a receipt scan can fill in on the Add expense form, and how. Pure
/// functions — the receipt sheet only shows them.
enum ReceiptField { amount, date, title }

/// One value found on the receipt.
class ReceiptSuggestion {
  const ReceiptSuggestion({
    required this.field,
    required this.preselected,
    this.replaces = false,
  });

  final ReceiptField field;

  /// Ticked from the start: the field is still empty (or, for the date,
  /// still today's default). Fields the user already filled are offered
  /// unticked — a typed value is never overwritten without a tap.
  final bool preselected;

  /// The form already has a different value here.
  final bool replaces;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The fields [result] can fill in on [state], amount first. Values the
/// form already has are left out. [dateIsDefault]: the date is still the
/// untouched "today" of a new expense.
List<ReceiptSuggestion> receiptSuggestions(
  AddExpenseState state,
  ReceiptScanResult result, {
  required bool dateIsDefault,
}) {
  final out = <ReceiptSuggestion>[];
  final total = result.total;
  if (total != null &&
      SplitCalculator.toPaise(total) != SplitCalculator.toPaise(state.amount)) {
    final empty = state.amount <= 0;
    out.add(
      ReceiptSuggestion(
        field: ReceiptField.amount,
        preselected: empty,
        replaces: !empty,
      ),
    );
  }
  final date = result.date;
  if (date != null && !_sameDay(date, state.date)) {
    out.add(
      ReceiptSuggestion(
        field: ReceiptField.date,
        preselected: dateIsDefault,
        replaces: !dateIsDefault,
      ),
    );
  }
  final merchant = result.merchant;
  final title = (state.title ?? '').trim();
  if (merchant != null && merchant != title) {
    out.add(
      ReceiptSuggestion(
        field: ReceiptField.title,
        preselected: title.isEmpty,
        replaces: title.isNotEmpty,
      ),
    );
  }
  return out;
}

/// [state] with the [fields] the user kept taken from [result]. The title
/// is written here too; the screen's title field is updated by the caller.
AddExpenseState applyReceiptScan(
  AddExpenseState state,
  ReceiptScanResult result,
  Set<ReceiptField> fields,
) {
  return state.copyWith(
    amount: fields.contains(ReceiptField.amount) ? result.total : null,
    date: fields.contains(ReceiptField.date) && result.date != null
        ? DateTime(
            result.date!.year,
            result.date!.month,
            result.date!.day,
            state.date.hour,
            state.date.minute,
          )
        : null,
    title: fields.contains(ReceiptField.title) ? result.merchant : null,
  );
}
