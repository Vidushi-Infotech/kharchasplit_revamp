import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/web/responsive_grid.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_sheet_header.dart';

/// Category grid bottom sheet. [context] and [ref] are the Add-expense
/// screen's own.
void showCategorySheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required AddExpenseState state,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final categories = CategoryModel.all;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(text: 'Pick a category', isDark: isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                // Fixed at 4 columns the tiles stretch to ~170px each once
                // the sheet becomes a desktop dialog. Sizing by extent keeps
                // them the size they were designed at, at any width.
                gridDelegate: ResponsiveGrid.delegate(
                  maxItemExtent: 96,
                  aspectRatio: 0.95,
                  spacing: 10,
                ),
                itemBuilder: (_, i) {
                  final c = categories[i];
                  final selected = state.category?.id == c.id;
                  final color =
                      addExpenseHexToColor(c.colorHex) ?? AppColors.tealDark;
                  return InkWell(
                    onTap: () {
                      HapticService.instance.selection();
                      // A hand-picked category is never auto-replaced.
                      ref.read(addExpenseProvider.notifier).state = state
                          .copyWith(category: c, categoryTouched: true);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.18)
                            : AppColors.cardBg(isDark),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? color : AppColors.divider(isDark),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(c.icon, size: 20, color: color),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(isDark).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? color
                                  : AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Date picker for the "When" row. [context] and [ref] are the Add-expense
/// screen's own.
Future<void> pickExpenseDate(
  BuildContext context,
  WidgetRef ref,
  AddExpenseState state,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: state.date,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now(),
  );
  if (picked != null) {
    HapticService.instance.selection();
    ref.read(addExpenseProvider.notifier).state = state.copyWith(date: picked);
  }
}
