import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_repeat.dart';
import '../state/add_expense_validation.dart';

/// Small chips under the "Paid by … split …" line for the extras that are
/// set — repeat (with its end-date problem, if any), receipt and notes.
/// Each opens its sheet. Nothing at all when none is set.
class AddExpenseExtrasSummary extends StatelessWidget {
  const AddExpenseExtrasSummary({
    super.key,
    required this.isDark,
    required this.state,
    required this.onReceiptTap,
    required this.onNotesTap,
    this.onRepeatTap,
  });

  final bool isDark;
  final AddExpenseState state;
  final VoidCallback onReceiptTap;
  final VoidCallback onNotesTap;
  final VoidCallback? onRepeatTap;

  static bool hasReceiptIn(AddExpenseState s) =>
      s.invoiceImagePath != null ||
      (s.receiptBase64 != null && s.receiptBase64!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final notes = (state.notes ?? '').trim();
    final repeatError = state.repeatError;
    final chips = <Widget>[
      if (onRepeatTap != null && state.repeat.isOn)
        _Chip(
          icon: Icons.event_repeat_rounded,
          text: repeatError ?? repeatSummary(state.repeat),
          error: repeatError != null,
          isDark: isDark,
          onTap: onRepeatTap!,
        ),
      if (hasReceiptIn(state))
        _Chip(
          icon: Icons.receipt_long_outlined,
          text: AppStrings.receiptAdded,
          isDark: isDark,
          onTap: onReceiptTap,
        ),
      if (notes.isNotEmpty)
        _Chip(
          icon: Icons.notes_rounded,
          text: notes.length > 28 ? '${notes.substring(0, 26)}…' : notes,
          isDark: isDark,
          onTap: onNotesTap,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.isDark,
    required this.onTap,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool isDark;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.errorText(isDark)
        : AppColors.textSecondary(isDark);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface(isDark),
        shape: StadiumBorder(
          side: BorderSide(
            color: error ? color : AppColors.divider(isDark),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
