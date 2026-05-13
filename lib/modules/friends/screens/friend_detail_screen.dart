import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../components/components.dart';
import '../state/friend_detail_provider.dart';

class FriendDetailScreen extends ConsumerWidget {
  final String friendId;

  const FriendDetailScreen({
    Key? key,
    required this.friendId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final detailAsync = ref.watch(friendDetailProvider(friendId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Friend Details'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.friend),
        error: (err, stack) => ErrorStateWidget(
          title: 'Failed to load friend details',
          message: 'Unable to fetch friend information. Please try again.',
          onRetry: () {
            // Trigger refresh
          },
        ),
        data: (detail) {
          if (screenWidth < 600) {
            return _buildCompactLayout(context, isDark, detail);
          } else if (screenWidth < 1100) {
            return _buildStandardLayout(context, isDark, detail);
          } else {
            return _buildLargeLayout(context, isDark, detail);
          }
        },
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, bool isDark, FriendDetail detail) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, isDark, detail),
          _buildBalanceCard(context, isDark, detail),
          _buildSettleButton(context, isDark, detail),
          _buildSharedExpensesList(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, bool isDark, FriendDetail detail) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, isDark, detail),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildBalanceCard(context, isDark, detail),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSettleButton(context, isDark, detail),
                ),
              ],
            ),
          ),
          _buildSharedExpensesList(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context, bool isDark, FriendDetail detail) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, isDark, detail),
                _buildBalanceCard(context, isDark, detail),
                _buildSettleButton(context, isDark, detail),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _buildSharedExpensesList(context, isDark, detail),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, FriendDetail detail) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            AvatarWidget(
              imageUrl: detail.friend.avatarUrl,
              name: detail.friend.name,
              radius: 40,
            ),
            const SizedBox(height: 12),
            Text(
              detail.friend.name,
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 4),
            Text(
              detail.friend.email,
              style: AppTextStyles.caption(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, bool isDark, FriendDetail detail) {
    final owesYou = detail.balanceYouOwe < 0;
    final amount = detail.balanceYouOwe.abs();
    final bgColor = owesYou
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final textColor = owesYou ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            owesYou ? '${detail.friend.name} owes you' : 'You owe ${detail.friend.name}',
            style: AppTextStyles.body2(isDark).copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          CurrencyText(
            amount,
            textStyle: AppTextStyles.headline2(isDark).copyWith(
              color: textColor,
            ),
            overrideColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettleButton(BuildContext context, bool isDark, FriendDetail detail) {
    return Semantics(
      button: true,
      enabled: detail.balanceYouOwe != 0,
      label: detail.balanceYouOwe == 0
          ? 'All settled with ${detail.friend.name}'
          : 'Settle up button - pay ${detail.friend.name}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: detail.balanceYouOwe != 0
                ? () {
                    context.go('/settle/${detail.friend.id}');
                  }
                : null,
            child: Text(
              detail.balanceYouOwe == 0 ? 'All settled' : 'Settle Up',
              style: AppTextStyles.button(isDark).copyWith(
                color: detail.balanceYouOwe == 0
                    ? AppColors.textSecondary(isDark)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedExpensesList(BuildContext context, bool isDark, FriendDetail detail) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Shared Expenses (${detail.sharedExpenses.length})',
              style: AppTextStyles.headline3(isDark).copyWith(fontSize: 18),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: detail.sharedExpenses.length,
            itemBuilder: (context, index) {
              final expense = detail.sharedExpenses[index];
              return Semantics(
                button: true,
                label: 'Expense - ${expense.title} for ₹${expense.amount} on ${DateFormatter.display(expense.date)}',
                child: ExpenseCard(
                  expense: expense,
                  onTap: () {
                    context.push('/expense/${expense.id}');
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
