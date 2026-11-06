import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../models/models.dart';
import '../../groups/state/group_detail_provider.dart';
import 'add_expense_repeat.dart';

class AddExpenseState {
  final String? title;
  final double amount;
  final String currency;
  final CategoryModel? category;
  final UserModel? paidBy;
  final UserModel? expenseFor; // New: member the expense is for
  final SplitType splitType;
  final Map<String, double> splits; // userId -> amount/percentage/shares
  final Set<String> includedMemberIds; // empty = all included
  final DateTime date;
  final String? notes;
  final String? groupId;
  final bool isLoading;
  final String? error;

  // Invoice / receipt fields
  final String? invoiceImagePath;
  final bool isScanning;
  final bool invoiceScanned;

  /// Base64-encoded receipt image, posted to the backend as `receiptBase64`
  /// and rendered on the expense detail screen as proof.
  final String? receiptBase64;

  /// Multiple payers, userId → amount paid, in the order they were entered.
  /// Empty = a single payer ([paidBy], or me) paid the whole amount.
  final Map<String, double> payers;

  /// "By adjustment" split. Stored with [splitType] = exact (that is how the
  /// server keeps it); [adjustments] holds the +/− per person (userId →
  /// rupees) and [splits] is unused while this is on.
  final bool adjustmentMode;
  final Map<String, double> adjustments;

  /// The user picked a category by hand in this form — auto-suggestions must
  /// never override it.
  final bool categoryTouched;

  /// The split was pre-filled from the group's default split (new expenses
  /// only). Drives the "Using the group's default split" hint; cleared as
  /// soon as the user picks another split method.
  final bool usingGroupDefaultSplit;

  /// "Repeat" of a new expense (recurring flag; never set when editing).
  final AddExpenseRepeat repeat;

  /// Edit mode: the recurring rule the expense came from, or null. Saving
  /// then asks "just this one" or "this and future".
  final String? recurringRuleId;

  /// Edit mode: the server's `updated_at` of the expense being edited, sent
  /// as `baseUpdatedAt` so an edit made against an outdated copy (e.g.
  /// offline) is refused (409 EDIT_CONFLICT) instead of overwriting.
  final String? baseUpdatedAt;

  /// `currencyConversion`: the currency amount, payers and split are
  /// entered in (ISO code) when it isn't the group's; null = the group's.
  /// [currency] is then its symbol. The server converts on save.
  final String? entryCurrency;

  /// Rate typed by the user (1 [entryCurrency] = this much group currency)
  /// when none could be looked up; sent as `fxRate`.
  final double? manualFxRate;

  /// Edit mode: the rate a converted expense was saved with. Kept (sent as
  /// `fxRate`) while the currency and date are unchanged, so re-saving
  /// never silently re-prices it.
  final AddExpenseSavedFx? savedFx;

  const AddExpenseState({
    this.title,
    this.amount = 0,
    this.currency = '₹',
    this.category,
    this.paidBy,
    this.expenseFor,
    this.splitType = SplitType.equal,
    this.splits = const {},
    this.includedMemberIds = const {},
    required this.date,
    this.notes,
    this.groupId,
    this.isLoading = false,
    this.error,
    this.invoiceImagePath,
    this.isScanning = false,
    this.invoiceScanned = false,
    this.receiptBase64,
    this.payers = const {},
    this.adjustmentMode = false,
    this.adjustments = const {},
    this.categoryTouched = false,
    this.usingGroupDefaultSplit = false,
    this.repeat = AddExpenseRepeat.never,
    this.recurringRuleId,
    this.baseUpdatedAt,
    this.entryCurrency,
    this.manualFxRate,
    this.savedFx,
  });

  static const _keep = Object();

  AddExpenseState copyWith({
    String? title,
    double? amount,
    String? currency,
    CategoryModel? category,
    UserModel? paidBy,
    UserModel? expenseFor,
    SplitType? splitType,
    Map<String, double>? splits,
    Set<String>? includedMemberIds,
    DateTime? date,
    String? notes,
    String? groupId,
    bool? isLoading,
    String? error,
    String? invoiceImagePath,
    bool? isScanning,
    bool? invoiceScanned,
    String? receiptBase64,
    Map<String, double>? payers,
    bool? adjustmentMode,
    Map<String, double>? adjustments,
    bool? categoryTouched,
    bool? usingGroupDefaultSplit,
    AddExpenseRepeat? repeat,
    // Clearable (null = back to the group currency / no rate / no receipt).
    Object? entryCurrency = _keep,
    Object? manualFxRate = _keep,
    bool clearReceipt = false,
  }) {
    return AddExpenseState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      expenseFor: expenseFor ?? this.expenseFor,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      includedMemberIds: includedMemberIds ?? this.includedMemberIds,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      groupId: groupId ?? this.groupId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      invoiceImagePath: clearReceipt
          ? null
          : invoiceImagePath ?? this.invoiceImagePath,
      isScanning: isScanning ?? this.isScanning,
      invoiceScanned: invoiceScanned ?? this.invoiceScanned,
      receiptBase64: clearReceipt ? null : receiptBase64 ?? this.receiptBase64,
      payers: payers ?? this.payers,
      adjustmentMode: adjustmentMode ?? this.adjustmentMode,
      adjustments: adjustments ?? this.adjustments,
      categoryTouched: categoryTouched ?? this.categoryTouched,
      usingGroupDefaultSplit:
          usingGroupDefaultSplit ?? this.usingGroupDefaultSplit,
      repeat: repeat ?? this.repeat,
      recurringRuleId: recurringRuleId,
      baseUpdatedAt: baseUpdatedAt,
      entryCurrency: identical(entryCurrency, _keep)
          ? this.entryCurrency
          : entryCurrency as String?,
      manualFxRate: identical(manualFxRate, _keep)
          ? this.manualFxRate
          : manualFxRate as double?,
      savedFx: savedFx,
    );
  }

  // isValid / isSplitValid / splitError / payer checks live in
  // add_expense_validation.dart (AddExpenseValidation extension).
}

/// The conversion an expense being edited was saved with (see
/// [AddExpenseState.savedFx]).
class AddExpenseSavedFx {
  const AddExpenseSavedFx({
    required this.currency,
    required this.rate,
    required this.date,
  });

  /// ISO code of the original currency.
  final String currency;
  final double rate;

  /// The expense date it was converted for (date only).
  final DateTime date;
}

/// autoDispose so the form state is destroyed (and re-created fresh) whenever
/// the Add Expense screen is closed. This is what prevents a draft — e.g. an
/// amount entered for one group but not saved — from carrying over when the
/// user opens Add Expense again for another group.
final addExpenseProvider = StateProvider.autoDispose<AddExpenseState>((ref) {
  return AddExpenseState(date: DateTime.now());
});

/// Carries the equal-split derivation. Structural `==` so listener-side
/// no-op detection becomes a single `prev == next` comparison instead of
/// per-entry mapEquals / setEquals checks at every consumer.
class EqualSplitDerived {
  const EqualSplitDerived({
    required this.splits,
    required this.includedMemberIds,
  });
  final Map<String, double> splits;
  final Set<String> includedMemberIds;

  static const _mapEq = MapEquality<String, double>();
  static const _setEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EqualSplitDerived &&
          _mapEq.equals(splits, other.splits) &&
          _setEq.equals(includedMemberIds, other.includedMemberIds));

  @override
  int get hashCode =>
      Object.hash(_mapEq.hash(splits), _setEq.hash(includedMemberIds));
}

/// Derives the equal-split share map + initialised includedMemberIds
/// from the current addExpense state + the group's members. Pure
/// function of (amount, splitType, includedMemberIds, members) — the
/// previous implementation lived inside the add-expense screen's
/// `build()` via `addPostFrameCallback` which kept scheduling state
/// writes on every frame. Pulling the math here means consumers can
/// `ref.listen` it and apply the change exactly once per structural
/// update.
// autoDispose + must not pin addExpenseProvider alive: if this stayed a
// non-autoDispose provider it would keep watching (and thus keep alive) the
// autoDispose addExpenseProvider forever, defeating its reset-on-close.
final equalSplitDerivedProvider = Provider.autoDispose
    .family<EqualSplitDerived?, String?>((ref, groupId) {
      if (groupId == null) return null;
      final s = ref.watch(addExpenseProvider);
      if (s.splitType != SplitType.equal || s.adjustmentMode) return null;

      final detail = ref.watch(groupDetailProvider(groupId)).value;
      if (detail == null) return null;
      final members = detail.members;
      if (members.isEmpty) return null;

      final includedIds = s.includedMemberIds.isEmpty
          ? Set<String>.from(members.map((m) => m.id))
          : s.includedMemberIds;

      final equalShare = (s.amount > 0 && includedIds.isNotEmpty)
          ? s.amount / includedIds.length
          : 0.0;

      final splits = <String, double>{
        for (final m in members)
          m.id: includedIds.contains(m.id) ? equalShare : 0,
      };

      return EqualSplitDerived(splits: splits, includedMemberIds: includedIds);
    });
