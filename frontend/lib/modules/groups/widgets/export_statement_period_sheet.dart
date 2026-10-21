import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/group_totals_calculator.dart';
import 'group_totals_cards.dart';

/// Asks which period the PDF statement covers. Null when dismissed.
///
/// Root navigator: the floating tab bar would otherwise cover the sheet's
/// button. SafeArea + scrollable so "Create PDF" stays reachable on short
/// screens and with large text.
Future<TotalsPeriod?> showExportStatementPeriodSheet(
  BuildContext context, {
  required TotalsPeriod initial,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<TotalsPeriod>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface(isDark),
    builder: (_) => _PeriodSheet(initial: initial, isDark: isDark),
  );
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.initial, required this.isDark});

  final TotalsPeriod initial;
  final bool isDark;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late TotalsPeriod _period = widget.initial;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.exportStatementPeriod,
                    style: AppTextStyles.headline3(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.exportStatementPeriodHint,
                  style: AppTextStyles.caption(
                    isDark,
                  ).copyWith(color: AppColors.textSecondary(isDark)),
                ),
                const SizedBox(height: 16),
                GroupTotalsPeriodChips(
                  selected: _period,
                  isDark: isDark,
                  onSelected: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: AppStrings.exportCreate,
                  excludeSemantics: true,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_period),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text(AppStrings.exportCreate),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      minimumSize: const Size.fromHeight(48),
                    ),
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
