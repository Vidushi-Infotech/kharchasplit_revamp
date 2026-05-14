import 'package:equatable/equatable.dart';

import '../core/utils/currency_formatter.dart';
import 'category_model.dart';

/// A personal (non-shared) expense — owned by one user, no splits, no group.
/// Maps to the `personal_expenses` table on the backend.
class PersonalExpenseModel extends Equatable {
  const PersonalExpenseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.currency = 'INR',
    required this.category,
    required this.expenseDate,
    this.notes,
    this.receiptBase64,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final double amount;
  final String currency;
  final CategoryModel category;
  final DateTime expenseDate;
  final String? notes;
  final String? receiptBase64;
  final DateTime createdAt;

  factory PersonalExpenseModel.fromJson(Map<String, dynamic> json) {
    final categoryId =
        (json['category'] as String?)?.toLowerCase() ?? 'other';
    final category = CategoryModel.fromId(categoryId) ?? CategoryModel.other;

    final dateRaw = json['expenseDate'] ??
        json['expense_date'] ??
        json['createdAt'] ??
        json['created_at'];
    final createdRaw = json['createdAt'] ?? json['created_at'];

    return PersonalExpenseModel(
      id: json['id'] as String,
      userId: (json['userId'] ?? json['user_id'] ?? '') as String,
      title: (json['description'] ?? json['title'] ?? '') as String,
      amount: _parseAmount(json['amount']),
      currency: CurrencyFormatter.symbolFor(
          (json['currency'] as String?) ?? 'INR'),
      category: category,
      expenseDate:
          dateRaw is String ? DateTime.parse(dateRaw) : DateTime.now(),
      notes: json['notes'] as String?,
      receiptBase64:
          (json['receiptBase64'] ?? json['receipt_base64']) as String?,
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

  PersonalExpenseModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? currency,
    CategoryModel? category,
    DateTime? expenseDate,
    String? notes,
    String? receiptBase64,
    DateTime? createdAt,
  }) {
    return PersonalExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      receiptBase64: receiptBase64 ?? this.receiptBase64,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        amount,
        currency,
        category,
        expenseDate,
        notes,
        receiptBase64,
        createdAt,
      ];
}
