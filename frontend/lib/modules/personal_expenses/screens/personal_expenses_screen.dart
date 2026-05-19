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

enum _DateFilter { all, today, week, month }

class PersonalExpensesScreen extends ConsumerStatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  ConsumerState<PersonalExpensesScreen> createState() =>
      _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState
    extends ConsumerState<PersonalExpensesScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  _DateFilter _dateFilter = _DateFilter.all;
  String _query = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  List<PersonalExpenseModel> _applyFilters(List<PersonalExpenseModel> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return items.where((e) {
      final matchesQuery = _query.isEmpty ||
          e.title.toLowerCase().contains(_query.toLowerCase()) ||
          e.category.name.toLowerCase().contains(_query.toLowerCase());
      final matchesDate = switch (_dateFilter) {
        _DateFilter.all => true,
        _DateFilter.today => !e.expenseDate.isBefore(todayStart),
        _DateFilter.week => !e.expenseDate.isBefore(weekStart),
        _DateFilter.month => !e.expenseDate.isBefore(monthStart),
      };
      return matchesQuery && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final asyncExpenses = ref.watch(personalExpensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: asyncExpenses.when(
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ShimmerList(type: ShimmerListType.expense, itemCount: 6),
          ),
          error: (err, _) => ErrorStateWidget(
            title: "Couldn't load personal expenses",
            message: err.toString(),
            onRetry: () =>
                ref.read(personalExpensesProvider.notifier).refresh(),
          ),
          data: (items) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(personalExpensesProvider.notifier).refresh(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth < 1100 ? 720 : 900,
                  ),
                  child: _Body(
                    allItems: items,
                    visibleItems: _applyFilters(items),
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    query: _query,
                    onSearchChanged: (q) => setState(() => _query = q),
                    dateFilter: _dateFilter,
                    onDateFilterChanged: (f) =>
                        setState(() => _dateFilter = f),
                    isSearching: _isSearching,
                    onOpenSearch: _openSearch,
                    onCloseSearch: _closeSearch,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.allItems,
    required this.visibleItems,
    required this.searchController,
    required this.searchFocus,
    required this.query,
    required this.onSearchChanged,
    required this.dateFilter,
    required this.onDateFilterChanged,
    required this.isSearching,
    required this.onOpenSearch,
    required this.onCloseSearch,
  });

  final List<PersonalExpenseModel> allItems;
  final List<PersonalExpenseModel> visibleItems;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final _DateFilter dateFilter;
  final ValueChanged<_DateFilter> onDateFilterChanged;
  final bool isSearching;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value ?? WalletState.empty;
    final spent = ref.watch(personalExpensesTotalProvider);
    final grouped = _groupByDay(visibleItems);
    final hasAnyExpenses = allItems.isNotEmpty;
    final isFilteringEmpty = hasAnyExpenses && visibleItems.isEmpty;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            isDark: isDark,
            onAdd: () => context.push('/home/personal/new'),
            onSearch: hasAnyExpenses ? onOpenSearch : null,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: wallet.sources.isEmpty
                ? _SetupCta(
                    isDark: isDark,
                    onTap: () => WalletSetupSheet.show(context),
                  )
                : _WalletCard(
                    wallet: wallet,
                    spent: spent,
                    expenseCount: allItems.length,
                    onTap: () => WalletSetupSheet.show(context),
                  ),
          ),
        ),
        if (!hasAnyExpenses)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              isDark: isDark,
              onAdd: () => context.push('/home/personal/new'),
            ),
          )
        else ...[
          if (isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: _InlineSearchBar(
                  controller: searchController,
                  focusNode: searchFocus,
                  query: query,
                  onChanged: onSearchChanged,
                  onClose: onCloseSearch,
                  isDark: isDark,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, isSearching ? 4 : 16, 20, 10),
              child: _FilterStrip(
                filter: dateFilter,
                onChanged: onDateFilterChanged,
                isDark: isDark,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(
                'EXPENSES',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          if (isFilteringEmpty)
            SliverToBoxAdapter(
              child: _NoResultsCard(isDark: isDark, query: query),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList.builder(
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final group = grouped[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DateCard(
                      isDark: isDark,
                      dateLabel: group.dateLabel,
                      expenses: group.expenses,
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _InlineSearchBar extends StatelessWidget {
  const _InlineSearchBar({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClose,
    required this.isDark,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body2(isDark).copyWith(fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.cardBg(isDark),
        isDense: true,
        hintText: 'Search expenses',
        hintStyle: AppTextStyles.body2(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.textSecondary(isDark),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.textSecondary(isDark),
          onPressed: onClose,
          tooltip: 'Close search',
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.tealDark.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filter,
    required this.onChanged,
    required this.isDark,
  });

  final _DateFilter filter;
  final ValueChanged<_DateFilter> onChanged;
  final bool isDark;

  static const _options = <(_DateFilter, String)>[
    (_DateFilter.all, 'All'),
    (_DateFilter.today, 'Today'),
    (_DateFilter.week, 'Week'),
    (_DateFilter.month, 'Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (value, label) = opt;
        final selected = filter == value;
        return Padding(
          padding: const EdgeInsets.only(right: 18),
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: selected
                          ? AppColors.textPrimary(isDark)
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    width: selected ? 18 : 0,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NoResultsCard extends StatelessWidget {
  const _NoResultsCard({required this.isDark, required this.query});
  final bool isDark;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(height: 10),
          Text(
            query.isEmpty
                ? 'No expenses match this filter'
                : 'No expenses match "$query"',
            style: AppTextStyles.body1(isDark).copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different filter or search term',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isDark,
    required this.onAdd,
    this.onSearch,
  });

  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSONAL',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wallet',
                  style: AppTextStyles.headline1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onSearch != null) ...[
            _IconButton(
              isDark: isDark,
              icon: Icons.search_rounded,
              onTap: onSearch!,
              label: 'Search expenses',
            ),
            const SizedBox(width: 8),
          ],
          _IconButton(
            isDark: isDark,
            icon: Icons.add_rounded,
            onTap: onAdd,
            label: 'Add personal expense',
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.spent,
    required this.expenseCount,
    required this.onTap,
  });

  final WalletState wallet;
  final double spent;
  final int expenseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = wallet.totalAvailable;
    final inDeficit = available < 0;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: inDeficit
                    ? const [Color(0xFFE57373), Color(0xFFC62828)]
                    : const [AppColors.tealLight, AppColors.tealDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: (inDeficit
                          ? const Color(0xFFC62828)
                          : AppColors.tealDark)
                      .withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -20,
                  child: _Orb(size: 120, opacity: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AVAILABLE BALANCE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.white.withValues(alpha: 0.78),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(available, currency: '₹'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
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
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Spent ${CurrencyFormatter.format(spent, currency: '₹')} '
                        '· $expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label · ${CurrencyFormatter.format(amount, currency: '₹')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.isDark,
    required this.dateLabel,
    required this.expenses,
  });

  final bool isDark;
  final String dateLabel;
  final List<PersonalExpenseModel> expenses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(
            dateLabel.toUpperCase(),
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < expenses.length; i++)
                PersonalExpenseTile(
                  expense: expenses[i],
                  showDivider: i < expenses.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupCta extends StatelessWidget {
  const _SetupCta({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.tealDark.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tealDark.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.tealDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Set up your wallet',
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add cash or a bank account to track your balance',
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark, required this.onAdd});
  final bool isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.tealDark,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No personal expenses yet',
            style: AppTextStyles.headline3(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Track expenses that aren't shared — rent, fuel, subscriptions.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealDark,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add your first expense'),
          ),
        ],
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
            DateFormatter.groupHeader(DateTime.parse(e.key)),
            e.value,
          ))
      .toList();
}
