import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../components/components.dart';
import '../state/dashboard_provider.dart';

/// Main dashboard screen showing balance, groups, and recent expenses
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dashboardData = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: screenWidth < 600
          ? _buildCompactLayout(context, isDark, dashboardData)
          : screenWidth < 1100
              ? _buildStandardLayout(context, isDark, dashboardData)
              : _buildLargeLayout(context, isDark, dashboardData),
    );
  }

  Widget _buildCompactLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(context, isDark),
          const SizedBox(height: 24),
          _buildBalanceCard(isDark, data),
          const SizedBox(height: 32),
          _buildRecentGroupsSection(context, isDark, data),
          const SizedBox(height: 32),
          _buildRecentExpensesSection(isDark, data),
          const SizedBox(height: 32),
          _buildQuickSettleSection(isDark, data),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, isDark),
              const SizedBox(height: 32),
              _buildBalanceCard(isDark, data),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRecentGroupsSection(context, isDark, data),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildRecentExpensesSection(isDark, data),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildQuickSettleSection(isDark, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, isDark),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildBalanceCard(isDark, data),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 1,
                    child: _buildRecentGroupsSection(context, isDark, data),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 1,
                    child: _buildRecentExpensesSection(isDark, data),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _buildQuickSettleSection(isDark, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormatter.getGreeting()}, You 👋',
                style: isCompact
                    ? AppTextStyles.body1(isDark).copyWith(fontWeight: FontWeight.w700)
                    : AppTextStyles.headline2(isDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your expenses',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Notifications button',
              child: SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, size: 20),
                  onPressed: () {},
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Profile button',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark.withOpacity(0.2),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.teal, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(bool isDark, DashboardData data) {
    return BalanceCard(
      totalBalance: data.totalBalance,
      youAreOwed: data.youAreOwed,
      youOwe: data.youOwe,
      currency: '₹',
    );
  }

  Widget _buildRecentGroupsSection(BuildContext context, bool isDark, DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Groups',
              style: AppTextStyles.headline3(isDark),
            ),
            Semantics(
              button: true,
              label: 'See all groups button',
              child: TextButton(
                onPressed: () => context.go('/home/groups'),
                child: const Text('See all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...data.recentGroups.map(
          (group) => Semantics(
            button: true,
            label: 'Group card - ${group.name} with balance ₹${group.myBalance}',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GroupCard(
                group: group,
                onTap: () => context.go('/home/groups/${group.id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentExpensesSection(bool isDark, DashboardData data) {
    // Group expenses by date
    final groupedExpenses = <String, List<dynamic>>{};
    for (final expense in data.recentExpenses) {
      final dateHeader = DateFormatter.groupHeader(expense.date);
      groupedExpenses.putIfAbsent(dateHeader, () => []);
      groupedExpenses[dateHeader]!.add(expense);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Expenses',
              style: AppTextStyles.headline3(isDark),
            ),
            Semantics(
              button: true,
              label: 'See all expenses button',
              child: TextButton(
                onPressed: () {},
                child: const Text('See all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...groupedExpenses.entries.expand((entry) {
          final dateHeader = entry.key;
          final expenses = entry.value;

          return [
            Text(
              dateHeader,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...expenses.map((expense) {
              return Semantics(
                button: true,
                label: 'Expense card - ${expense.title} for ₹${expense.amount}',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ExpenseCard(
                    expense: expense,
                    onTap: () {},
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ];
        }),
      ],
    );
  }

  Widget _buildQuickSettleSection(bool isDark, DashboardData data) {
    if (data.youOwe <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warningOrange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Settle',
            style: AppTextStyles.headline3(isDark),
          ),
          const SizedBox(height: 12),
          Text(
            'You have unsettled debts',
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Settle up button - pay your outstanding debts',
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Settle Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
