import 'package:equatable/equatable.dart';
import 'category_model.dart';
import 'split_model.dart';
import 'user_model.dart';

/// Split type enum
enum SplitType {
  equal,
  exact,
  percentage,
  shares,
}

/// Expense model representing a single expense
class ExpenseModel extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final CategoryModel category;
  final UserModel paidBy;
  final List<SplitModel> splits;
  final String? groupId;
  final DateTime date;
  final String? notes;
  final String? receiptImageUrl;
  final SplitType splitType;
  final bool isSettled;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    this.currency = '₹',
    required this.category,
    required this.paidBy,
    required this.splits,
    this.groupId,
    required this.date,
    this.notes,
    this.receiptImageUrl,
    this.splitType = SplitType.equal,
    this.isSettled = false,
    required this.createdAt,
  });

  ExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? currency,
    CategoryModel? category,
    UserModel? paidBy,
    List<SplitModel>? splits,
    String? groupId,
    DateTime? date,
    String? notes,
    String? receiptImageUrl,
    SplitType? splitType,
    bool? isSettled,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      splits: splits ?? this.splits,
      groupId: groupId ?? this.groupId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      splitType: splitType ?? this.splitType,
      isSettled: isSettled ?? this.isSettled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Total amount across all splits (should equal amount)
  double get totalSplitAmount => splits.fold(0, (sum, split) => sum + split.owedShare);

  /// Check if splits are valid (sum equals expense amount)
  bool get isValidSplit => (totalSplitAmount - amount).abs() < 0.01;

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        currency,
        category,
        paidBy,
        splits,
        groupId,
        date,
        notes,
        receiptImageUrl,
        splitType,
        isSettled,
        createdAt,
      ];
}
