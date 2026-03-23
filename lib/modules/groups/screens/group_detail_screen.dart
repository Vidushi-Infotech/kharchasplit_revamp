import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/group_model.dart';
import '../../../components/components.dart';
import '../state/group_detail_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final tab = ref.watch(groupTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Group Details'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              // Show menu
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.group),
        error: (err, stack) => ErrorStateWidget(
          title: 'Failed to load group details',
          message: 'Unable to fetch group information. Please try again.',
          onRetry: () {
            // Trigger refresh
          },
        ),
        data: (detail) {
          if (screenWidth < 600) {
            return _buildCompactLayout(context, isDark, detail, tab, ref);
          } else if (screenWidth < 1100) {
            return _buildStandardLayout(context, isDark, detail, tab, ref);
          } else {
            return _buildLargeLayout(context, isDark, detail, tab, ref);
          }
        },
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, isDark, detail),
          _buildTabs(context, isDark, tab, ref),
          if (tab == GroupTab.expenses)
            _buildExpensesList(context, isDark, detail)
          else
            _buildBalancesList(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, isDark, detail),
          _buildTabs(context, isDark, tab, ref),
          if (tab == GroupTab.expenses)
            _buildExpensesList(context, isDark, detail)
          else
            _buildBalancesList(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, isDark, detail),
                _buildMembersList(context, isDark, detail),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildTabs(context, isDark, tab, ref),
              Expanded(
                child: SingleChildScrollView(
                  child: tab == GroupTab.expenses
                      ? _buildExpensesList(context, isDark, detail)
                      : _buildBalancesList(context, isDark, detail),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, GroupDetail detail) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                detail.group.coverEmoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.group.name,
                      style: AppTextStyles.headline3(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Total',
                  CurrencyFormatter.format(detail.totalExpense),
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Members',
                  '${detail.members.length}',
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Expenses',
                  '${detail.expenses.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMembersList(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildStatistic(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(isDark),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.headline3(isDark).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList(BuildContext context, bool isDark, GroupDetail detail) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: detail.members.length,
        itemBuilder: (context, index) {
          final member = detail.members[index];
          return Padding(
            padding: EdgeInsets.only(right: index == detail.members.length - 1 ? 0 : 8),
            child: Column(
              children: [
                AvatarWidget(
                  imageUrl: member.avatarUrl,
                  name: member.name,
                  radius: 20,
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    member.name.split(' ')[0],
                    style: AppTextStyles.caption(isDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs(
    BuildContext context,
    bool isDark,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return Container(
      color: AppColors.surface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Expenses tab${tab == GroupTab.expenses ? ' - selected' : ''}',
              onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.expenses,
              child: GestureDetector(
                onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.expenses,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == GroupTab.expenses ? AppColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Expenses',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: tab == GroupTab.expenses
                          ? AppColors.brand
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          tab == GroupTab.expenses ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Balances tab${tab == GroupTab.balances ? ' - selected' : ''}',
              onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.balances,
              child: GestureDetector(
                onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.balances,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == GroupTab.balances ? AppColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Balances',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: tab == GroupTab.balances
                          ? AppColors.brand
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          tab == GroupTab.balances ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(BuildContext context, bool isDark, GroupDetail detail) {
    if (detail.expenses.isEmpty) {
      return EmptyStateWidget.noExpenses();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: detail.expenses.length,
      itemBuilder: (context, index) {
        final expense = detail.expenses[index];
        return Semantics(
          button: true,
          label: 'Expense - ${expense.title} for ₹${expense.amount}',
          child: ExpenseCard(
            expense: expense,
            onTap: () {
              context.go('/expense/${expense.id}');
            },
          ),
        );
      },
    );
  }

  Widget _buildBalancesList(BuildContext context, bool isDark, GroupDetail detail) {
    final sortedBalances = detail.memberBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedBalances.length,
      itemBuilder: (context, index) {
        final entry = sortedBalances[index];
        final member = detail.members.firstWhere((m) => m.id == entry.key);
        final balance = entry.value;
        final isNegative = balance < 0;

        return Semantics(
          label: '${member.name} ${isNegative ? 'is owed' : 'owes'} ₹${balance.abs()}',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider(isDark),
                width: 1,
              ),
            ),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: member.avatarUrl,
                name: member.name,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.body2(isDark),
                    ),
                    Text(
                      isNegative ? 'is owed' : 'owes',
                      style: AppTextStyles.caption(isDark),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(balance.abs()),
                style: AppTextStyles.body2(isDark).copyWith(
                  color: isNegative ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
