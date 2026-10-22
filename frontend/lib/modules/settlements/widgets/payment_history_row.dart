import 'package:flutter/material.dart';

import '../../../components/list/list_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/settlement_model.dart';
import '../state/payment_history_row_view.dart';
import 'not_received_button.dart';

/// One payment on the Payments page, flat like the group list:
/// [💵] "Test F. paid you ₹200.00" with the date and method, its status,
/// any note in gray, and the amount on the right. A confirmed payment made
/// to you keeps its "Not received" action.
class PaymentHistoryRow extends StatelessWidget {
  const PaymentHistoryRow({
    super.key,
    required this.settlement,
    required this.myId,
    required this.otherName,
    required this.groupId,
    this.showDivider = true,
  });

  final SettlementModel settlement;
  final String? myId;
  final String otherName;
  final String groupId;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final view = paymentHistoryRowView(
      settlement,
      myId: myId,
      otherName: otherName,
    );
    final statusColor = switch (view.statusKind) {
      PaymentStatusKind.pending => AppColors.textSecondary(isDark),
      PaymentStatusKind.failed => AppColors.errorText(isDark),
      PaymentStatusKind.confirmed => AppColors.owed,
    };
    final muted = view.tone == BalanceTone.settled;

    return KsListRow(
      showDivider: showDivider,
      leading: CategoryTile(
        icon: Icons.payments_outlined,
        color: muted ? AppColors.textSecondary(isDark) : AppColors.brand,
        size: 40,
      ),
      title: view.title,
      subtitles: [
        view.when,
        Text(
          view.status,
          style: textTheme.bodySmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        ?view.note,
        if (view.canMarkNotReceived)
          Align(
            alignment: Alignment.centerLeft,
            child: NotReceivedButton(settlement: settlement, groupId: groupId),
          ),
      ],
      trailing: Text(
        view.amount,
        style: textTheme.titleSmall?.copyWith(
          color: view.tone.color(isDark),
          fontWeight: FontWeight.w700,
        ),
      ),
      semanticsLabel: [
        view.title,
        view.when,
        view.status,
        ?view.note,
      ].join(', '),
    );
  }
}
