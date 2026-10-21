import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_totals_calculator.dart';
import '../state/group_totals_provider.dart';
import 'group_totals_breakdown.dart';
import 'group_totals_cards.dart';
import 'group_totals_members.dart';

/// Splitwise-style "Totals" tab: spending in a period, what you paid and
/// owe, payments, and breakdowns by category, month and member. All maths
/// is in group_totals_calculator.dart; this only lays it out.
///
/// One lazy ListView (same NestedScrollView body pattern as the other
/// tabs): the fixed sections first, then one row per member.
class GroupTotalsTab extends ConsumerWidget {
  const GroupTotalsTab({
    super.key,
    required this.groupId,
    required this.currency,
    required this.onRefresh,
  });

  final String groupId;

  /// The group's currency (ISO code or symbol) — every amount is in it.
  final String currency;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 16.0 : (width < 1100 ? 24.0 : 32.0);
    final totals = ref.watch(groupTotalsProvider(groupId));
    final period = ref.watch(groupTotalsPeriodProvider(groupId));
    final myId = ref.watch(myIdProvider);

    if (totals == null) {
      return const ShimmerList(type: ShimmerListType.expense, itemCount: 4);
    }

    final sections = <WidgetBuilder>[
      (_) => GroupTotalsPeriodChips(
        selected: period,
        isDark: isDark,
        onSelected: (p) =>
            ref.read(groupTotalsPeriodProvider(groupId).notifier).state = p,
      ),
      if (totals.pendingExcluded > 0)
        (_) => _PendingNote(count: totals.pendingExcluded, isDark: isDark),
      if (!totals.hasActivity)
        (_) => _EmptyPeriodCard(isDark: isDark)
      else
        (_) => GroupTotalsSummaryCards(
          totals: totals,
          currency: currency,
          isDark: isDark,
        ),
      if (totals.categories.isNotEmpty)
        (_) => GroupTotalsCategorySection(
          categories: totals.categories,
          currency: currency,
          isDark: isDark,
        ),
      if (totals.months.length > 1 && totals.expenseCount > 0)
        (_) => GroupTotalsMonthSection(
          months: totals.months,
          currency: currency,
          isDark: isDark,
        ),
      if (totals.expenseCount > 0)
        (_) => GroupTotalsMembersHeader(isDark: isDark),
    ];
    final memberRows = totals.expenseCount > 0
        ? totals.members
        : const <MemberTotal>[];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
        itemCount: sections.length + memberRows.length,
        itemBuilder: (context, index) {
          if (index < sections.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: sections[index](context),
            );
          }
          final member = memberRows[index - sections.length];
          return GroupTotalsMemberRow(
            member: member,
            currency: currency,
            isDark: isDark,
            isMe: member.userId == myId,
          );
        },
      ),
    );
  }
}

class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.count, required this.isDark});

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 16,
          color: AppColors.textSecondary(isDark),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.totalsPendingExcluded(count),
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
          ),
        ),
      ],
    );
  }
}

class _EmptyPeriodCard extends StatelessWidget {
  const _EmptyPeriodCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GroupTotalsSection(
      isDark: isDark,
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 36,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.totalsNoExpenses,
            style: AppTextStyles.body1(
              isDark,
            ).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.totalsNoExpensesHint,
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: AppColors.textSecondary(isDark)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
