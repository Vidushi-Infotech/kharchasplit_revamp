import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../models/models.dart';
import '../../groups/state/group_detail_provider.dart';

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
  });

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
      invoiceImagePath: invoiceImagePath ?? this.invoiceImagePath,
      isScanning: isScanning ?? this.isScanning,
      invoiceScanned: invoiceScanned ?? this.invoiceScanned,
      receiptBase64: receiptBase64 ?? this.receiptBase64,
    );
  }

  bool get isValid {
    // Title is required so the expense list / detail / activity feed all
    // show a meaningful label. We require ≥1 non-whitespace character.
    if (title == null || title!.trim().isEmpty) {
      return false;
    }
    if (amount <= 0) {
      return false;
    }
    return isSplitValid;
  }

  /// Whether the split breakdown itself is valid for the current split type,
  /// independent of title/amount. Equal split (and the no-group case) is
  /// always valid. Used to disable the split sheet's Done button and to flag
  /// the Split row on the form.
  bool get isSplitValid {
    // If no group selected, equal split is valid
    if (groupId == null) {
      return true;
    }

    // If equal split, no additional validation needed
    if (splitType == SplitType.equal) {
      return true;
    }

    // For other split types, validate splits
    if (splits.isEmpty) {
      return false;
    }

    final includedSum = splits.entries
        .where(
          (e) => includedMemberIds.isEmpty || includedMemberIds.contains(e.key),
        )
        .fold<double>(0, (sum, e) => sum + e.value);

    switch (splitType) {
      case SplitType.exact:
        // Sum of amounts should equal total (within 0.01)
        return (includedSum - amount).abs() < 0.01;
      case SplitType.percentage:
        // Sum of percentages should equal 100 (within 0.01)
        return (includedSum - 100).abs() < 0.01;
      case SplitType.shares:
        // Total shares should be > 0
        return includedSum > 0;
      case SplitType.equal:
        return true;
    }
  }

  /// Short reason the split is invalid, or null when valid. Surfaced on the
  /// Split row so the user sees *why* it's blocking the save.
  String? get splitError {
    if (isSplitValid) return null;
    if (splits.isEmpty) return 'Set each share';
    final includedSum = splits.entries
        .where(
          (e) => includedMemberIds.isEmpty || includedMemberIds.contains(e.key),
        )
        .fold<double>(0, (sum, e) => sum + e.value);
    switch (splitType) {
      case SplitType.exact:
        final diff = amount - includedSum;
        return diff > 0
            ? '₹${diff.toStringAsFixed(2)} left to assign'
            : 'Over by ₹${(-diff).toStringAsFixed(2)}';
      case SplitType.percentage:
        final diff = 100 - includedSum;
        return diff > 0
            ? '${diff.toStringAsFixed(1)}% left to assign'
            : 'Over by ${(-diff).toStringAsFixed(1)}%';
      case SplitType.shares:
        return 'Set at least one share';
      case SplitType.equal:
        return null;
    }
  }
}

final addExpenseProvider = StateProvider<AddExpenseState>((ref) {
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
final equalSplitDerivedProvider = Provider.family<EqualSplitDerived?, String?>((
  ref,
  groupId,
) {
  if (groupId == null) return null;
  final s = ref.watch(addExpenseProvider);
  if (s.splitType != SplitType.equal) return null;

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
    for (final m in members) m.id: includedIds.contains(m.id) ? equalShare : 0,
  };

  return EqualSplitDerived(splits: splits, includedMemberIds: includedIds);
});
