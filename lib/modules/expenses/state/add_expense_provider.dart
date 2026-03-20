import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';

class AddExpenseState {
  final String? title;
  final double amount;
  final String currency;
  final CategoryModel? category;
  final UserModel? paidBy;
  final SplitType splitType;
  final Map<String, double> splits; // userId -> amount/percentage/shares
  final DateTime date;
  final String? notes;
  final String? groupId;
  final bool isLoading;
  final String? error;

  const AddExpenseState({
    this.title,
    this.amount = 0,
    this.currency = '₹',
    this.category,
    this.paidBy,
    this.splitType = SplitType.equal,
    this.splits = const {},
    required this.date,
    this.notes,
    this.groupId,
    this.isLoading = false,
    this.error,
  });

  AddExpenseState copyWith({
    String? title,
    double? amount,
    String? currency,
    CategoryModel? category,
    UserModel? paidBy,
    SplitType? splitType,
    Map<String, double>? splits,
    DateTime? date,
    String? notes,
    String? groupId,
    bool? isLoading,
    String? error,
  }) {
    return AddExpenseState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      groupId: groupId ?? this.groupId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isValid => title != null && title!.isNotEmpty && amount > 0;
}

final addExpenseProvider = StateProvider<AddExpenseState>((ref) {
  return AddExpenseState(date: DateTime.now());
});
