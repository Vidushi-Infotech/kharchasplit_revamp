import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/payments_history_view.dart';

/// Top of the Payments page: your avatar and theirs with an arrow in the
/// direction money is owed, the balance between you in the group
/// ("Test F. owes you ₹200.00 in Goa trip"), pending payments in gray,
/// and only the actions that apply (Settle up / Remind…).
class PaymentsHistoryHeader extends StatelessWidget {
  const PaymentsHistoryHeader({
    super.key,
    required this.view,
    required this.onSettle,
    required this.onRemind,
  });

  final PaymentsHistoryView view;

  /// Settle up with the amount not already in a pending payment.
  final ValueChanged<double> onSettle;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final tone = view.tone;
    final sentence = paymentsHeaderLine(view);
    final amount = CurrencyFormatter.format(
      view.balance.abs(),
      currency: view.currency,
    );
    final pending = paymentsPendingLines(view);
    final actions = <ActionChipItem>[
      if (view.toSettle > 0)
        ActionChipItem(
          label: AppStrings.settleUp,
          primary: true,
          onTap: () => onSettle(view.toSettle),
        ),
      // Reminders only reach people still in the group.
      if (tone == BalanceTone.owed && view.otherIsMember)
        ActionChipItem(
          label: AppStrings.remindEllipsis,
          icon: Icons.notifications_none_rounded,
          onTap: onRemind,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Avatars(view: view, isDark: isDark),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              label: sentence,
              excludeSemantics: true,
              child: _toneSentence(
                sentence,
                tone == BalanceTone.settled ? null : amount,
                tone.color(isDark),
                textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (final line in pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                line,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ActionChipBar(items: actions),
          ],
        ],
      ),
    );
  }

  /// The sentence with its amount picked out in the tone color.
  Widget _toneSentence(
    String sentence,
    String? amount,
    Color color,
    TextStyle? base,
  ) {
    final at = amount == null ? -1 : sentence.indexOf(amount);
    if (at < 0) {
      return Text(sentence, style: base);
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: sentence.substring(0, at)),
          TextSpan(
            text: amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: sentence.substring(at + amount!.length)),
        ],
      ),
    );
  }
}

/// You on the left, them on the right; the arrow points from whoever owes
/// to whoever is owed (a two-way icon when you're even).
class _Avatars extends StatelessWidget {
  const _Avatars({required this.view, required this.isDark});

  final PaymentsHistoryView view;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final me = view.me;
    final myName = me?.name ?? AppStrings.balanceYou;
    final icon = switch (view.tone) {
      BalanceTone.owe => Icons.arrow_forward_rounded,
      BalanceTone.owed => Icons.arrow_back_rounded,
      _ => Icons.swap_horiz_rounded,
    };
    final flow = switch (view.tone) {
      BalanceTone.owe => AppStrings.historyBetween(
        AppStrings.balanceYouObject,
        view.shortName,
      ),
      BalanceTone.owed => AppStrings.historyBetween(
        view.shortName,
        AppStrings.balanceYouObject,
      ),
      _ => null,
    };
    return Semantics(
      label: flow,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            AvatarWidget(imageUrl: me?.avatarUrl, name: myName, radius: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(icon, size: 24, color: view.tone.color(isDark)),
            ),
            AvatarWidget(
              imageUrl: view.other.avatarUrl,
              name: view.otherName,
              radius: 28,
            ),
          ],
        ),
      ),
    );
  }
}
