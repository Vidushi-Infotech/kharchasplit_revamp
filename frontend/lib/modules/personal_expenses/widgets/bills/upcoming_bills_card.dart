import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/personal_bill_model.dart';
import '../../state/personal_bills_provider.dart';
import '../insights/insights_card.dart';
import 'bill_editor_sheet.dart';
import 'bill_row.dart';
import 'pay_bill_sheet.dart';

/// On the Personal home: the next few bills (overdue and due soon first)
/// with Pay, and a way to all bills. Without any, a one-line invitation.
class UpcomingBillsCard extends ConsumerWidget {
  const UpcomingBillsCard({super.key});

  static const _shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bills = ref.watch(personalBillsProvider).value;
    if (bills == null) return const SizedBox.shrink();

    if (bills.isEmpty) {
      return Material(
        color: AppColors.cardBg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.divider(isDark)),
        ),
        child: ListTile(
          onTap: () => context.push('/personal/bills'),
          leading: const Icon(
            Icons.event_repeat_rounded,
            color: AppColors.brand,
          ),
          title: Text(
            AppStrings.bills,
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            AppStrings.billNameHint,
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
          ),
          trailing: TextButton(
            onPressed: () => BillEditorSheet.show(context),
            child: const Text(AppStrings.billAdd),
          ),
        ),
      );
    }

    final pressing = bills.where((b) => b.status != BillStatus.upcoming);
    return InsightsCard(
      title: AppStrings.billsUpcoming,
      note: pressing.isEmpty
          ? null
          : '${pressing.length} ${AppStrings.billsDueSoon.toLowerCase()}',
      child: Column(
        children: [
          for (final b in bills.take(_shown))
            BillRow(
              bill: b,
              onTap: () => BillEditorSheet.show(context, bill: b),
              onPay: () => PayBillSheet.show(context, b),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/personal/bills'),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: Text(
                bills.length > _shown
                    ? '${AppStrings.billsSeeAll} (${bills.length})'
                    : AppStrings.billsSeeAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
