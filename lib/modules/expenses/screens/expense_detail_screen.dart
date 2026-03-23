import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../components/components.dart';
import '../state/expense_detail_provider.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({Key? key, required this.expenseId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Expense'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: expenseAsync.when(
        loading: () => Center(
          child: ShimmerList(itemCount: 3),
        ),
        error: (error, _) => ErrorStateWidget(
          title: 'Failed to load expense',
          message: 'Unable to fetch expense details. Please try again.',
          onRetry: () {
            // Trigger refresh
          },
        ),
        data: (expense) => screenWidth < 600
            ? _buildCompactLayout(isDark, expense)
            : _buildWideLayout(isDark, expense),
      ),
    );
  }

  Widget _buildCompactLayout(bool isDark, dynamic expense) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, expense),
          const SizedBox(height: 24),
          _buildPaidBySection(isDark, expense),
          const SizedBox(height: 24),
          _buildSplitSection(isDark, expense),
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNotesSection(isDark, expense),
          ],
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isDark, dynamic expense) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, expense),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPaidBySection(isDark, expense),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _buildSplitSection(isDark, expense),
                  ),
                ],
              ),
              if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildNotesSection(isDark, expense),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, dynamic expense) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.tealDark.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  expense.category.icon,
                  color: AppColors.tealDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: AppTextStyles.headline3(isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.fullDateTime(expense.date),
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CurrencyText(
            expense.amount,
            currency: expense.currency,
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySection(bool isDark, dynamic expense) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paid By', style: AppTextStyles.headline3(isDark)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Row(
            children: [
              AvatarWidget(
                name: expense.paidBy.name,
                imageUrl: expense.paidBy.avatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.paidBy.name,
                      style: AppTextStyles.body1(isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'paid',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              CurrencyText(
                expense.amount,
                currency: expense.currency,
                textStyle: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitSection(bool isDark, dynamic expense) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split Among', style: AppTextStyles.headline3(isDark)),
        const SizedBox(height: 12),
        ...expense.splits.map((split) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider(isDark)),
              ),
              child: Row(
                children: [
                  AvatarWidget(
                    name: split.userName,
                    imageUrl: split.userAvatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      split.userName,
                      style: AppTextStyles.body2(isDark),
                    ),
                  ),
                  CurrencyText(
                    split.owedShare,
                    currency: expense.currency,
                    textStyle: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesSection(bool isDark, dynamic expense) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: AppTextStyles.headline3(isDark)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Text(
            expense.notes ?? '',
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }
}
