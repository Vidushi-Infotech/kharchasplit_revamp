import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/settlement_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_detail_provider.dart';

/// History of settlements between the current user and one other member,
/// scoped to a single group.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = ref.watch(authProvider).user;
    final detailAsync = ref.watch(groupDetailProvider(groupId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Settlement history'),
        backgroundColor: AppColors.surface(isDark),
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (detail) {
          final other = detail.members
              .where((m) => m.id == otherUserId)
              .cast<dynamic>()
              .firstWhere((_) => true, orElse: () => null);
          final pair = detail.settlements.where((s) {
            final involvesPair =
                (s.fromUser.id == me?.id && s.toUser.id == otherUserId) ||
                    (s.fromUser.id == otherUserId && s.toUser.id == me?.id);
            return involvesPair && me != null;
          }).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              await ref.read(groupDetailProvider(groupId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _Header(
                  groupName: detail.group.name,
                  otherName: other?.name as String? ?? 'this person',
                  pairCount: pair.length,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                if (pair.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'No settlements yet between you and ${other?.name ?? 'them'}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body2(isDark).copyWith(
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...pair.map((s) => _SettlementTile(
                        settlement: s,
                        myId: me?.id ?? '',
                        isDark: isDark,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.groupName,
    required this.otherName,
    required this.pairCount,
    required this.isDark,
  });

  final String groupName;
  final String otherName;
  final int pairCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You ↔ $otherName',
            style: AppTextStyles.headline3(isDark),
          ),
          const SizedBox(height: 4),
          Text(
            'In $groupName · $pairCount settlement${pairCount == 1 ? '' : 's'}',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.settlement,
    required this.myId,
    required this.isDark,
  });

  final SettlementModel settlement;
  final String myId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iPaid = settlement.fromUser.id == myId;
    final counterpartName = iPaid ? settlement.toUser.name : settlement.fromUser.name;
    final dirIcon = iPaid ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final dirColor = iPaid ? AppColors.warning : AppColors.success;
    final headline = iPaid
        ? 'You paid $counterpartName'
        : '$counterpartName paid you';
    final dateLine = DateFormat('MMM d, yyyy · h:mm a').format(settlement.date);
    final statusInfo = _statusInfo(settlement.status, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: dirColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(dirIcon, color: dirColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTextStyles.body1(isDark)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(dateLine, style: AppTextStyles.caption(isDark)),
                if ((settlement.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    settlement.note!,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(settlement.amount,
                    currency: settlement.currency),
                style: AppTextStyles.body1(isDark).copyWith(
                  color: dirColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusInfo.$2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusInfo.$1,
                  style: TextStyle(
                    color: statusInfo.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(SettlementStatus s, bool isDark) {
    switch (s) {
      case SettlementStatus.completed:
        return ('Confirmed', AppColors.success);
      case SettlementStatus.pending:
        return ('Pending', AppColors.warning);
      case SettlementStatus.failed:
        return ('Failed', AppColors.errorText(isDark));
    }
  }
}
