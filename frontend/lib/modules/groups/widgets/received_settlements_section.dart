import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/settlement_model.dart';

/// Settlements other members have made to the current user. Settlements are
/// final on creation (no confirm step), so this is how the recipient sees who
/// has settled — the balance cards above show who still owes.
class ReceivedSettlementsSection extends StatelessWidget {
  const ReceivedSettlementsSection({
    super.key,
    required this.groupId,
    required this.myId,
    required this.settlements,
    required this.padding,
  });

  final String groupId;
  final String myId;
  final List<SettlementModel> settlements;
  final double padding;

  static const _maxItems = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final received =
        settlements
            .where(
              (s) =>
                  s.status == SettlementStatus.completed &&
                  s.toUser.id == myId &&
                  s.fromUser.id != myId,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    if (received.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'SETTLED WITH YOU',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                for (final s in received.take(_maxItems))
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(
                      '/home/groups/$groupId/settlements-with/${s.fromUser.id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${s.fromUser.name.isEmpty ? 'Someone' : s.fromUser.name} '
                              'settled ${CurrencyFormatter.format(s.amount, currency: s.currency)}',
                              style: AppTextStyles.body2(isDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('d MMM').format(s.date.toLocal()),
                            style: AppTextStyles.caption(
                              isDark,
                            ).copyWith(color: AppColors.textSecondary(isDark)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
