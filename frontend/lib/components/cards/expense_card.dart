import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../web/hoverable.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../modules/auth/state/auth_provider.dart';
import '../text/currency_text.dart';

/// Card widget for displaying a single expense
class ExpenseCard extends ConsumerWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showGroup;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
    this.showGroup = false,
  });

  // Per-user view of this expense:
  //   iPaid       : current user is the payer
  //   myShare     : amount the current user owes for this expense (0 if not in splits)
  //   othersOwe   : amount others owe the current user (only if iPaid)
  ({bool iPaid, double myShare, double othersOwe}) _myView(String? meId) {
    if (meId == null || meId.isEmpty) {
      return (iPaid: false, myShare: 0, othersOwe: 0);
    }
    final iPaid = expense.paidBy.id == meId;
    double myShare = 0;
    for (final s in expense.splits) {
      if (s.userId == meId) {
        myShare = s.owedShare;
        break;
      }
    }
    final othersOwe = iPaid ? (expense.amount - myShare) : 0.0;
    return (iPaid: iPaid, myShare: myShare, othersOwe: othersOwe);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meId = ref.watch(myIdProvider);
    final view = _myView(meId);

    // Compute the headline amount + badge based on this user's relation to
    // the expense.
    late final String badgeText;
    late final Color badgeColor;
    late final double headlineAmount;
    if (expense.isSettled) {
      badgeText = 'Settled';
      badgeColor = AppColors.greyLight;
      headlineAmount = view.myShare;
    } else if (view.iPaid && view.othersOwe > 0.005) {
      badgeText = 'You are owed';
      badgeColor = AppColors.success;
      headlineAmount = view.othersOwe;
    } else if (view.iPaid) {
      // Paid but everything is for me, or all splits are 0 → no debt either way.
      badgeText = 'You paid';
      badgeColor = AppColors.greyLight;
      headlineAmount = expense.amount;
    } else if (view.myShare > 0.005) {
      badgeText = 'You owe';
      badgeColor = AppColors.warningOrange;
      headlineAmount = view.myShare;
    } else {
      // Not involved in this expense (e.g. excluded from splits).
      badgeText = 'Not involved';
      badgeColor = AppColors.greyLight;
      headlineAmount = expense.amount;
    }

    // Only the person who added (paid for) the expense can swipe to delete it.
    final canDelete = view.iPaid && onDelete != null;

    final card = RepaintBoundary(
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
                      headlineAmount,
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
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: badgeColor,
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
        );

    final wrapped = canDelete
        ? Dismissible(
            key: Key(expense.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              // Fire the threshold haptic the instant the swipe commits —
              // before the modal animation runs — so the user feels the
              // gesture engaged.
              HapticService.instance.thresholdCrossed();
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete expense?'),
                      content: Text(
                        'Are you sure you want to delete "${expense.title}"? '
                        'This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.errorText(isDark),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              // Destructive confirm — heavier haptic to underline gravity.
              if (confirmed) HapticService.instance.destructive();
              return confirmed;
            },
            onDismissed: (_) => onDelete?.call(),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.errorText(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white),
            ),
            child: card,
          )
        : card;

    // Hoverable is a plain tap target below the web shell breakpoint, so the
    // touch behaviour here is unchanged; on web it adds the hover tint, the
    // click cursor and a keyboard focus ring this card never had.
    return Hoverable(
      onTap: onTap,
      borderRadius: 14,
      hoverElevation: false,
      child: wrapped,
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
