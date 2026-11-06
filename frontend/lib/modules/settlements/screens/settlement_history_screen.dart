import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/widgets/group_member_actions.dart';
import '../../groups/widgets/group_subpage_scaffold.dart';
import '../state/payment_history_row_view.dart';
import '../state/payments_history_view.dart';
import '../widgets/payment_history_row.dart';
import '../widgets/payments_history_header.dart';

/// Payments between the viewer and one other person in one group,
/// Splitwise-style: the balance between you (from the group's own
/// numbers), Settle up / Remind…, then every payment by month.
///
/// [GroupSubpageScaffold] gives the AppBar with the group name, loading /
/// error states, pull-to-refresh and the width-based content column.
class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({
    super.key,
    required this.groupId,
    required this.otherUserId,
  });

  final String groupId;
  final String otherUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupSubpageScaffold(
      groupId: groupId,
      title: AppStrings.payments,
      builder: (context, detail, pad) => _PaymentsHistoryBody(
        groupId: groupId,
        otherUserId: otherUserId,
        pad: pad,
      ),
    );
  }
}

class _PaymentsHistoryBody extends ConsumerWidget {
  const _PaymentsHistoryBody({
    required this.groupId,
    required this.otherUserId,
    required this.pad,
  });

  final String groupId;
  final String otherUserId;
  final double pad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      paymentsHistoryProvider((groupId: groupId, otherId: otherUserId)),
    );
    if (view == null) return const SizedBox.shrink();
    final myId = ref.watch(myIdProvider);
    final items = groupPaymentsByMonth(view.payments);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
      // Header first, then month headers and payments (or the empty note).
      itemCount: 1 + (items.isEmpty ? 1 : items.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return PaymentsHistoryHeader(
            view: view,
            onSettle: (amount) => context.push(
              '/settle/$otherUserId?groupId=$groupId'
              '&amount=${amount.toStringAsFixed(2)}',
            ),
            onRemind: () =>
                sendGroupReminder(groupId, context, ref, view.other),
          );
        }
        if (items.isEmpty) return _NoPayments(name: view.shortName);
        return switch (items[index - 1]) {
          PaymentMonthItem(:final title) => MonthSectionHeader(title),
          PaymentRowItem(:final settlement, :final lastInMonth) =>
            PaymentHistoryRow(
              key: ValueKey(settlement.id),
              settlement: settlement,
              myId: myId,
              otherName: view.otherName,
              groupId: groupId,
              showDivider: !lastInMonth,
            ),
        };
      },
    );
  }
}

class _NoPayments extends StatelessWidget {
  const _NoPayments({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 40,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.historyNoPayments,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.historyNoPaymentsHint(name),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
