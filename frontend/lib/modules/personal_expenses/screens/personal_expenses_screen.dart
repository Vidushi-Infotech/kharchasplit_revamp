import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/personal_expense_model.dart';
import '../../../models/wallet_source_model.dart';
import '../state/personal_expenses_provider.dart';
import '../state/wallet_provider.dart';
import '../widgets/personal_expense_tile.dart';
import '../widgets/wallet_setup_sheet.dart';

class PersonalExpensesScreen extends ConsumerWidget {
  const PersonalExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final asyncExpenses = ref.watch(personalExpensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Personal Expenses'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: asyncExpenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          title: "Couldn't load personal expenses",
          message: err.toString(),
          onRetry: () =>
              ref.read(personalExpensesProvider.notifier).refresh(),
        ),
        data: (items) {
          final wallet = ref.watch(walletProvider).value ?? WalletState.empty;
          if (items.isEmpty && wallet.sources.isEmpty) {
            return _buildEmpty(context, isDark);
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(personalExpensesProvider.notifier).refresh(),
            child: screenWidth < 600
                ? _CompactLayout(items: items)
                : screenWidth < 1100
                    ? _StandardLayout(items: items)
                    : _LargeLayout(items: items),
          );
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'Add personal expense',
        child: FloatingActionButton(
          onPressed: () => context.push('/home/personal/new'),
          backgroundColor: AppColors.brand,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💸', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No personal expenses yet',
                style: AppTextStyles.headline3(isDark)),
            const SizedBox(height: 8),
            Text(
              'Track expenses that aren\'t shared with anyone — '
              'rent, fuel, subscriptions, the lot.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2(isDark)
                  .copyWith(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/home/personal/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletHeader extends ConsumerWidget {
  const _WalletHeader({required this.items});
  final List<PersonalExpenseModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value ?? WalletState.empty;
    final spent = ref.watch(personalExpensesTotalProvider);

    if (wallet.sources.isEmpty) {
      return _SetupCta(
        onTap: () => WalletSetupSheet.show(context),
      );
    }

    final available = wallet.totalAvailable;
    final inDeficit = available < 0;

    return InkWell(
      onTap: () => WalletSetupSheet.show(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: inDeficit
                ? [Colors.red.shade400, Colors.red.shade700]
                : [AppColors.brand, AppColors.tealDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Available balance',
                    style: AppTextStyles.body2(isDark)
                        .copyWith(color: Colors.white70),
                  ),
                ),
                const Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(available, currency: '₹'),
              style: AppTextStyles.headline1(isDark)
                  .copyWith(color: Colors.white, fontSize: 32),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final s in wallet.sources)
                  _SourceChip(
                    label: s.name,
                    amount: s.balance,
                    icon: s.type == WalletSourceType.bank
                        ? Icons.account_balance_rounded
                        : Icons.payments_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Spent: ${CurrencyFormatter.format(spent, currency: '₹')} '
              '· ${items.length} expense${items.length == 1 ? '' : 's'}',
              style: AppTextStyles.caption(isDark)
                  .copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCta extends StatelessWidget {
  const _SetupCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set up your wallet',
                      style: AppTextStyles.body1(isDark)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Add cash or a bank account to track your balance',
                    style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip(
      {required this.label, required this.amount, required this.icon});
  final String label;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label · ${CurrencyFormatter.format(amount, currency: '₹')}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.items});
  final List<PersonalExpenseModel> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _groupByDay(items);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: grouped.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) return _WalletHeader(items: items);
        final entry = grouped[idx - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(
                  entry.dateLabel,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...entry.expenses.map((e) => PersonalExpenseTile(expense: e)),
            ],
          ),
        );
      },
    );
  }
}

class _StandardLayout extends StatelessWidget {
  const _StandardLayout({required this.items});
  final List<PersonalExpenseModel> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _CompactLayout(items: items),
        ),
      ),
    );
  }
}

class _LargeLayout extends StatelessWidget {
  const _LargeLayout({required this.items});
  final List<PersonalExpenseModel> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _CompactLayout(items: items),
        ),
      ),
    );
  }
}

class _DayGroup {
  _DayGroup(this.dateLabel, this.expenses);
  final String dateLabel;
  final List<PersonalExpenseModel> expenses;
}

List<_DayGroup> _groupByDay(List<PersonalExpenseModel> items) {
  final sorted = [...items]
    ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  final byDay = <String, List<PersonalExpenseModel>>{};
  for (final e in sorted) {
    final key = DateFormat('yyyy-MM-dd').format(e.expenseDate);
    byDay.putIfAbsent(key, () => []).add(e);
  }
  return byDay.entries
      .map((e) => _DayGroup(
          DateFormatter.groupHeader(DateTime.parse(e.key)), e.value))
      .toList();
}
