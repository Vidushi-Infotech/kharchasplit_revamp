import 'package:equatable/equatable.dart';
import '../core/utils/currency_formatter.dart';
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
  final String? receiptBase64;
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
    this.receiptBase64,
    this.splitType = SplitType.equal,
    this.isSettled = false,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    // paidBy can arrive as a nested object (dashboard endpoint) or as flat
    // `paid_by` UUID + `paid_by_name` (the per-group expenses endpoint).
    UserModel paidBy;
    final paidByJson = json['paidBy'];
    if (paidByJson is Map<String, dynamic>) {
      paidBy = UserModel.fromJson(paidByJson);
    } else {
      final id = (json['paid_by'] ?? json['paidById'] ?? '') as String;
      final name = (json['paid_by_name'] ?? json['paidByName'] ?? '') as String;
      paidBy = UserModel(
        id: id,
        name: name.isEmpty ? 'Unknown' : name,
        email: '',
        phone: '',
        createdAt: DateTime.now(),
      );
    }

    // Splits also live under `participants` in the per-group expenses response.
    final splitsRaw = json['splits'] ?? json['participants'];
    final splits = splitsRaw is List
        ? splitsRaw
            .whereType<Map<String, dynamic>>()
            .map(SplitModel.fromJson)
            .toList()
        : <SplitModel>[];

    final categoryId = (json['category'] as String?)?.toLowerCase() ?? 'other';
    final category = CategoryModel.fromId(categoryId) ?? CategoryModel.other;

    final dateRaw = json['expenseDate'] ??
        json['expense_date'] ??
        json['date'] ??
        json['created_at'];
    final createdRaw = json['createdAt'] ?? json['created_at'];

    return ExpenseModel(
      id: json['id'] as String,
      title: (json['description'] ?? json['title'] ?? '') as String,
      amount: _parseAmount(json['amount']),
      currency: CurrencyFormatter.symbolFor(
          (json['currency'] as String?) ?? 'INR'),
      category: category,
      paidBy: paidBy,
      splits: splits,
      groupId: (json['groupId'] ?? json['group_id']) as String?,
      date: dateRaw is String ? DateTime.parse(dateRaw) : DateTime.now(),
      notes: json['notes'] as String?,
      receiptBase64:
          (json['receiptBase64'] ?? json['receipt_base64']) as String?,
      splitType: _parseSplitType(
          (json['splitType'] ?? json['split_type']) as String?),
      isSettled: (json['isSettled'] as bool?) ?? false,
      createdAt:
          createdRaw is String ? DateTime.parse(createdRaw) : DateTime.now(),
    );
  }

  static double _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static SplitType _parseSplitType(String? raw) {
    switch (raw) {
      case 'unequal':
      case 'exact':
        return SplitType.exact;
      case 'percentage':
        return SplitType.percentage;
      case 'shares':
        return SplitType.shares;
      default:
        return SplitType.equal;
    }
  }

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
    String? receiptBase64,
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
      receiptBase64: receiptBase64 ?? this.receiptBase64,
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
        receiptBase64,
        splitType,
        isSettled,
        createdAt,
      ];
}
