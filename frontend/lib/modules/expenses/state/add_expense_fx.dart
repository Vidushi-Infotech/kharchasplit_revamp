import '../../../core/utils/currency_catalog.dart';
import '../../../core/utils/fx_convert.dart';
import '../../../core/utils/split_calculator.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import 'add_expense_provider.dart';
import 'add_expense_submit.dart';

/// Pure helpers for an expense entered in another currency
/// (`currencyConversion` flag). The form keeps doing all its maths in the
/// entered currency; only the request says which one it is, and the server
/// converts (exact to the paisa, rate of the expense date).

/// The group's currency as an ISO code ("₹" → "INR").
String groupCurrencyCode(String? groupCurrency) =>
    normalizeCurrencyCode(groupCurrency ?? 'INR');

/// The ISO code the amounts are entered in.
String addExpenseEntryCode(AddExpenseState state, String? groupCurrency) =>
    state.entryCurrency ?? groupCurrencyCode(groupCurrency);

/// State after picking [code] in the currency picker. Picking the group's
/// own currency goes back to plain entry. The typed amounts are kept as
/// they are (they are now in [code]); a typed rate is dropped.
AddExpenseState addExpenseWithCurrency(
  AddExpenseState state,
  String code,
  String? groupCurrency,
) {
  final group = groupCurrencyCode(groupCurrency);
  final isGroup = code == group;
  return state.copyWith(
    entryCurrency: isGroup ? null : code,
    currency: isGroup
        ? (groupCurrency ?? '₹')
        : CurrencyCatalog.symbolFor(code),
    manualFxRate: null,
  );
}

/// Calendar day on the phone (a fetched expense date arrives in UTC).
bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// The rate the server should use instead of looking one up (`fxRate`):
/// the one the user typed, else — editing — the one the expense was saved
/// with while its currency and date are unchanged. Null = server looks up.
double? addExpenseFxRateOverride(AddExpenseState state) {
  if (state.entryCurrency == null) return null;
  if (state.manualFxRate != null) return state.manualFxRate;
  final saved = state.savedFx;
  if (saved != null &&
      saved.currency == state.entryCurrency &&
      _sameDay(saved.date, state.date)) {
    return saved.rate;
  }
  return null;
}

/// Group-currency paise [amount] comes to at [rate] — the same rounding as
/// the server, so the preview equals what will be stored.
int addExpenseConvertedPaise(double amount, double rate) =>
    FxConvert.totalPaise(SplitCalculator.toPaise(amount), rate);

/// Editing a converted expense in the currency it was entered in. The API
/// returns only the total in that currency (`original_amount`); split
/// amounts and payers come back converted. Equal / percent / shares are
/// currency-free (kept as they are); amount-valued splits ([splits] of an
/// exact or equal split) and [payers] are converted back in proportion to
/// what was stored, exact to the paisa (they add up to the original total;
/// converting them forward again gives the stored amounts). "By
/// adjustment" amounts are stored as typed, already in that currency.
({double amount, Map<String, double> splits, Map<String, double> payers})
addExpenseAmountsInOriginal(
  ExpenseModel expense,
  Map<String, double> splits,
  Map<String, double> payers,
) {
  final total = SplitCalculator.toPaise(expense.originalAmount!);
  Map<String, double> back(Map<String, double> parts) {
    final ids = parts.keys.toList();
    final paise = FxConvert.backToOriginal([
      for (final id in ids) SplitCalculator.toPaise(parts[id]!),
    ], total);
    return {for (var i = 0; i < ids.length; i++) ids[i]: paise[i] / 100};
  }

  final amountSplit =
      expense.splitType == SplitType.exact ||
      expense.splitType == SplitType.equal;
  return (
    amount: total / 100,
    splits: amountSplit && !expense.isAdjustmentSplit ? back(splits) : splits,
    payers: payers.isEmpty ? payers : back(payers),
  );
}

/// The saved conversion of [expense], kept while editing.
AddExpenseSavedFx? addExpenseSavedFxOf(ExpenseModel expense) =>
    expense.isConverted
    ? AddExpenseSavedFx(
        currency: expense.originalCurrency!,
        rate: expense.fxRate!,
        // The expense date (fx_date is today's for a future-dated one).
        date: expense.date,
      )
    : null;

/// Opening a converted expense in the group's currency (flag off): its
/// "By adjustment" amounts were stored in the original currency.
Map<String, double> addExpenseAdjustmentsInGroup(
  ExpenseModel expense,
  Map<String, double> adjustments,
) {
  if (!expense.isConverted) return adjustments;
  return {
    for (final e in adjustments.entries)
      e.key: SplitCalculator.roundToPaisa(e.value * expense.fxRate!),
  };
}

/// "This and future" of an expense entered in another currency: recurring
/// rules repeat in the group's currency, so the template is the saved
/// (converted) expense — its stored amounts add up exactly. A "By
/// adjustment" split repeats as the converted exact amounts.
Map<String, dynamic> recurringTemplateFromSaved({
  required AddExpenseState state,
  required ExpenseModel saved,
  required String? groupCurrency,
}) {
  final notes = state.notes?.trim() ?? '';
  final isPercentage =
      !state.adjustmentMode && state.splitType == SplitType.percentage;
  final isShares = !state.adjustmentMode && state.splitType == SplitType.shares;
  return {
    'description': (state.title ?? '').trim(),
    'amount': saved.amount,
    'currency': groupCurrencyCode(groupCurrency),
    'category': (state.category ?? CategoryModel.other).id,
    'notes': notes.isEmpty ? null : notes,
    'splitType': state.adjustmentMode
        ? 'unequal'
        : backendSplitType(state.splitType),
    'splitMeta': null,
    'payers': [
      for (final p in saved.payers) {'userId': p.userId, 'amount': p.amount},
    ],
    'participants': [
      for (final s in saved.splits)
        ExpenseParticipant(
          userId: s.userId,
          name: s.userName,
          amount: s.owedShare,
          percentage: isPercentage ? s.percentage : null,
          shares: isShares ? s.shares.round() : null,
        ).toJson(),
    ],
  };
}

/// The "this and future" template after saving [expenseId]. Entered in
/// another currency, it is built from the saved (converted) expense — rules
/// repeat in the group's currency.
Future<Map<String, dynamic>> recurringTemplateAfterSave(
  ExpensesRepository repo, {
  required String expenseId,
  required AddExpenseState state,
  required UserModel paidBy,
  required List<ExpenseParticipant> participants,
  String? groupCurrency,
}) async {
  if (state.entryCurrency == null) {
    return buildRecurringTemplate(
      state: state,
      paidBy: paidBy,
      participants: participants,
    );
  }
  return recurringTemplateFromSaved(
    state: state,
    saved: await repo.getById(expenseId),
    groupCurrency: groupCurrency,
  );
}
