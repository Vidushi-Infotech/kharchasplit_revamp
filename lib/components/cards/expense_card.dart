import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../text/currency_text.dart';

/// Card widget for displaying a single expense
class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showGroup;

  const ExpenseCard({
    Key? key,
    required this.expense,
    this.onTap,
    this.onDelete,
    this.showGroup = false,
  }) : super(key: key);

  /// Get user's share in this expense
  double _getUserShare() {
    try {
      return expense.splits.firstWhere((s) => true).owedShare;
    } catch (e) {
      return 0;
    }
  }

  /// Get badge text based on expense status
  String _getBadgeText() {
    if (expense.isSettled) {
      return 'Settled';
    } else if (expense.paidBy.id == 'currentUserId') {
      // You paid
      final othersOwe = _getUserShare() == 0
          ? expense.amount
          : expense.amount - _getUserShare();
      return 'You paid';
    } else {
      // You owe
      return 'You owe';
    }
  }

  Color _getBadgeColor() {
    if (expense.isSettled) {
      return AppColors.greyLight;
    } else if (expense.paidBy.id == 'currentUserId') {
      return AppColors.greenLight;
    } else {
      return AppColors.warningOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Dismissible(
        key: Key(expense.id),
        onDismissed: (_) => onDelete?.call(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.errorText(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider(isDark),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _parseColor(expense.category.colorHex)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    expense.category.icon,
                    color: _parseColor(expense.category.colorHex),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Title and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: AppTextStyles.body1(isDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormatter.display(expense.date),
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                          if (showGroup) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'In ${expense.groupId ?? 'personal'}',
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount and badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      _getUserShare(),
                      currency: expense.currency,
                      textStyle: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getBadgeColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getBadgeText(),
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: _getBadgeColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parse hex color string to Color
  Color _parseColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
    } else {
      buffer.write(hexString.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
