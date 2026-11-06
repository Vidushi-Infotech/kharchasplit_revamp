import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/receipt_scan_parser.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import '../state/receipt_scan_apply.dart';

/// "Use ₹1,234.50 from the receipt?" card in the receipt sheet: what the
/// scan found, each value with a tick. Empty fields start ticked; a value
/// the user already entered shows "Replaces …" and stays unticked, so
/// nothing typed is overwritten without a tap.
class ReceiptScanSuggestionsCard extends StatefulWidget {
  const ReceiptScanSuggestionsCard({
    super.key,
    required this.isDark,
    required this.form,
    required this.result,
    required this.suggestions,
    required this.onUse,
    required this.onDismiss,
  });

  final bool isDark;
  final AddExpenseState form;
  final ReceiptScanResult result;
  final List<ReceiptSuggestion> suggestions;
  final ValueChanged<Set<ReceiptField>> onUse;
  final VoidCallback onDismiss;

  @override
  State<ReceiptScanSuggestionsCard> createState() =>
      _ReceiptScanSuggestionsCardState();
}

class _ReceiptScanSuggestionsCardState
    extends State<ReceiptScanSuggestionsCard> {
  /// Ticks — local to this card until "Use".
  late Set<ReceiptField> _picked = {
    for (final s in widget.suggestions)
      if (s.preselected) s.field,
  };

  @override
  void didUpdateWidget(ReceiptScanSuggestionsCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.result, widget.result)) {
      _picked = {
        for (final s in widget.suggestions)
          if (s.preselected) s.field,
      };
    }
  }

  String _money(double v) =>
      CurrencyFormatter.format(v, currency: widget.form.currency);

  (String label, String value, String current) _texts(ReceiptField f) {
    final r = widget.result;
    final form = widget.form;
    return switch (f) {
      ReceiptField.amount => (
        AppStrings.receiptFieldAmount,
        _money(r.total!),
        _money(form.amount),
      ),
      ReceiptField.date => (
        AppStrings.receiptFieldDate,
        formatAddExpenseDate(r.date!),
        formatAddExpenseDate(form.date),
      ),
      ReceiptField.title => (
        AppStrings.receiptFieldTitle,
        r.merchant!,
        (form.title ?? '').trim(),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final total = widget.result.total;
    final offersTotal = widget.suggestions.any(
      (s) => s.field == ReceiptField.amount,
    );
    final header = total != null && offersTotal
        ? AppStrings.receiptUseTotal(_money(total))
        : total == null
        ? AppStrings.receiptNoTotal
        : AppStrings.receiptFound;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealDark.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              header,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          for (final s in widget.suggestions) _row(s),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onDismiss,
                child: const Text(AppStrings.receiptNotNow),
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                onPressed: _picked.isEmpty
                    ? null
                    : () => widget.onUse(Set.of(_picked)),
                child: const Text(AppStrings.receiptUse),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(ReceiptSuggestion s) {
    final isDark = widget.isDark;
    final (label, value, current) = _texts(s.field);
    final picked = _picked.contains(s.field);
    void toggle() => setState(() {
      picked ? _picked.remove(s.field) : _picked.add(s.field);
    });

    return Semantics(
      checked: picked,
      label: '$label $value',
      excludeSemantics: true,
      onTap: toggle,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: picked,
                activeColor: AppColors.tealDark,
                onChanged: (_) => toggle(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · $value',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2(isDark),
                    ),
                    if (s.replaces && current.isNotEmpty)
                      Text(
                        AppStrings.receiptReplaces(current),
                        style: AppTextStyles.caption(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
