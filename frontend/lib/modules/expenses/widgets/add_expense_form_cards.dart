import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_validation.dart';
import 'add_expense_quick_row.dart';

/// Paid by / Split / When / Category card of the Add/Edit expense form.
/// Every tap is forwarded to the screen, which opens the matching sheet.
class AddExpenseQuickRowsCard extends StatelessWidget {
  const AddExpenseQuickRowsCard({
    super.key,
    required this.isDark,
    required this.state,
    required this.groupMembers,
    required this.me,
    required this.showValidation,
    required this.onPaidByTap,
    required this.onSplitTap,
    required this.onDateTap,
    required this.onCategoryTap,
  });

  final bool isDark;
  final AddExpenseState state;
  final List<UserModel> groupMembers;

  /// Signed-in user, watched by the screen.
  final UserModel? me;
  final bool showValidation;
  final VoidCallback onPaidByTap;
  final VoidCallback onSplitTap;
  final VoidCallback onDateTap;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final paidByText = addExpensePaidBySummary(state, groupMembers, me?.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          AddExpenseQuickRow(
            icon: Icons.person_outline_rounded,
            iconColor: AppColors.tealDark,
            label: 'Paid by',
            value: paidByText,
            isDark: isDark,
            // Shown straight away, not only after a Save attempt: the
            // amount changed after the payers were entered and we never
            // rescale them silently.
            errorText: state.payersError,
            onTap: () => onPaidByTap(),
          ),
          AddExpenseRowDivider(isDark: isDark),
          AddExpenseQuickRow(
            icon: Icons.pie_chart_outline_rounded,
            iconColor: AppColors.tealDark,
            label: 'Split',
            value: addExpenseSplitSummary(state, groupMembers),
            isDark: isDark,
            errorText: (showValidation && !state.isSplitValid)
                ? (state.splitError ?? 'Split doesn\'t add up')
                : null,
            onTap: () => onSplitTap(),
          ),
          AddExpenseRowDivider(isDark: isDark),
          AddExpenseQuickRow(
            icon: Icons.event_outlined,
            iconColor: AppColors.tealDark,
            label: 'When',
            value: formatAddExpenseDate(state.date),
            isDark: isDark,
            onTap: () => onDateTap(),
          ),
          AddExpenseRowDivider(isDark: isDark),
          AddExpenseQuickRow(
            icon: state.category?.icon ?? Icons.local_offer_outlined,
            iconColor:
                addExpenseHexToColor(state.category?.colorHex) ??
                AppColors.tealDark,
            label: 'Category',
            value: state.category?.name ?? 'Choose',
            isDark: isDark,
            onTap: () => onCategoryTap(),
          ),
        ],
      ),
    );
  }
}

/// Receipt / Notes ("optional extras") card of the Add/Edit expense form.
class AddExpenseMoreOptionsCard extends StatelessWidget {
  const AddExpenseMoreOptionsCard({
    super.key,
    required this.isDark,
    required this.state,
    required this.onReceiptTap,
    required this.onNotesTap,
  });

  final bool isDark;
  final AddExpenseState state;
  final VoidCallback onReceiptTap;
  final VoidCallback onNotesTap;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        state.invoiceImagePath != null ||
        (state.receiptBase64 != null && state.receiptBase64!.isNotEmpty);
    final notes = state.notes ?? '';
    final hasNotes = notes.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          AddExpenseQuickRow(
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.tealDark,
            label: 'Receipt',
            value: hasReceipt ? 'Added' : 'Optional',
            valueIsMuted: !hasReceipt,
            isDark: isDark,
            onTap: () => onReceiptTap(),
          ),
          AddExpenseRowDivider(isDark: isDark),
          AddExpenseQuickRow(
            icon: Icons.notes_rounded,
            iconColor: AppColors.tealDark,
            label: 'Notes',
            value: hasNotes
                ? (notes.length > 24 ? '${notes.substring(0, 22)}…' : notes)
                : 'Optional',
            valueIsMuted: !hasNotes,
            isDark: isDark,
            onTap: () => onNotesTap(),
          ),
        ],
      ),
    );
  }
}
