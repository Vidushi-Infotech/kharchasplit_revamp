import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../components/components.dart';
import '../state/group_detail_provider.dart';

Widget buildGroupExpensesList(
  BuildContext context,
  bool isDark,
  GroupDetail detail,
) {
  if (detail.expenses.isEmpty) {
    return EmptyStateWidget.noExpenses();
  }

  final screenWidth = MediaQuery.sizeOf(context).width;
  final isCompact = screenWidth < 600;
  final horizontalPadding = isCompact ? 16.0 : 24.0;
  final verticalSpacing = isCompact ? 8.0 : 12.0;

  // Standalone-scrollable so it can act as the body of NestedScrollView
  // (the outer header dismisses when the user scrolls this list).
  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: detail.expenses.length,
    itemBuilder: (context, index) {
      final expense = detail.expenses[index];
      return Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: verticalSpacing,
        ),
        child: Semantics(
          button: true,
          label: 'Expense - ${expense.title} for ₹${expense.amount}',
          child: ExpenseCard(
            expense: expense,
            onTap: () {
              context.push('/expense/${expense.id}');
            },
          ),
        ),
      );
    },
  );
}
