import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_rules.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/outbox_provider.dart';

/// One unsent change: what it is, where, and its state, with Retry /
/// Discard (and "Open expense" when someone else changed it meanwhile).
class UnsyncedItemTile extends ConsumerWidget {
  const UnsyncedItemTile({
    super.key,
    required this.item,
    required this.groupName,
    required this.isDark,
  });

  final OutboxItem item;
  final String? groupName;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = item.body ?? const {};
    final amount = (b['amount'] as num?)?.toDouble();
    final money = amount == null
        ? ''
        : CurrencyFormatter.format(amount, currency: (b['currency'] as String?) ?? 'INR');
    final title = switch (item.kind) {
      OutboxKind.createExpense => '${b['description'] ?? ''} · $money',
      OutboxKind.updateExpense => 'Edit: ${b['description'] ?? 'expense'} · $money',
      OutboxKind.deleteExpense => 'Delete expense',
      OutboxKind.createSettlement => 'Payment · $money',
    };
    final where = [
      switch (item.kind) {
        OutboxKind.createExpense => 'New expense',
        OutboxKind.updateExpense => 'Edited expense',
        OutboxKind.deleteExpense => 'Deleted expense',
        OutboxKind.createSettlement => 'Recorded payment',
      },
      ?groupName,
    ].join(' · ');
    final status = item.isFailed ? (item.error ?? AppStrings.notSynced) : AppStrings.waitingForConnection;
    final statusColor = item.isFailed ? AppColors.errorText(isDark) : AppColors.textSecondary(isDark);
    final notifier = ref.read(outboxProvider.notifier);
    final canOpen = item.errorCode == 'EDIT_CONFLICT' &&
        item.expenseId != null &&
        !OutboxRules.isLocalId(item.expenseId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.body1(isDark).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(where, style: AppTextStyles.caption(isDark)),
            const SizedBox(height: 6),
            Text(status, style: AppTextStyles.body2(isDark).copyWith(color: statusColor)),
            if (item.receiptDropped)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Receipt photo was too large to keep offline',
                    style: AppTextStyles.caption(isDark)),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (canOpen)
                  TextButton(
                    onPressed: () => context.push('/expense/${item.expenseId}'),
                    child: const Text(AppStrings.openExpense),
                  ),
                if (item.isFailed && item.errorCode != 'EDIT_CONFLICT')
                  TextButton(
                    onPressed: () => notifier.retry(item.id),
                    child: const Text(AppStrings.retrySync),
                  ),
                TextButton(
                  onPressed: () => _confirmDiscard(context, notifier),
                  style: TextButton.styleFrom(foregroundColor: AppColors.errorText(isDark)),
                  child: const Text(AppStrings.discardChange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, OutboxNotifier notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.discardChangeTitle),
        content: const Text(AppStrings.discardChangeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.discardChange)),
        ],
      ),
    );
    if (ok == true) await notifier.discard(item.id);
  }
}
