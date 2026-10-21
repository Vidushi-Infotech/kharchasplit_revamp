import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../state/fx_rate_text.dart';

/// Expense detail hero, under the amount of an expense entered in another
/// currency: "Paid $100.00 · 1 USD = ₹83.12 on 16 Oct". Nothing for one
/// entered in the group's currency. White on the hero's teal gradient.
class ExpenseOriginalAmountLine extends StatelessWidget {
  const ExpenseOriginalAmountLine({super.key, required this.expense});

  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) {
    final line = fxExpenseOriginalLine(expense);
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        line,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
