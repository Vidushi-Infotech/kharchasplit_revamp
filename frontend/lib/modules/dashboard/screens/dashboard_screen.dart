import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../state/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/group_mini_card.dart';
import '../widgets/recent_expenses_section.dart';

/// Main dashboard screen showing balance, groups, and recent expenses
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        bottom: false,
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _DashboardError(
            message: err.toString(),
            onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
            child: screenWidth < 600
                ? _buildCompactLayout(context, isDark, data)
                : screenWidth < 1100
                    ? _buildStandardLayout(context, isDark, data)
                    : _buildLargeLayout(context, isDark, data),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardHeader(),
          const SizedBox(height: 24),
          _buildBalanceCard(context, isDark, data),
          const SizedBox(height: 32),
          _buildRecentGroupsSection(context, isDark, data),
          const SizedBox(height: 32),
          _buildRecentExpensesSection(isDark, data),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildBalanceCard(context, isDark, data),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context, bool isDark, DashboardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildBalanceCard(context, isDark, data),
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
            ],
          ),
        ),
      ),
    );
  }

  DashboardHeader _buildHeader(BuildContext context) {
    return DashboardHeader(
      onOwedTap: () => context.pushNamed('owed-to-me'),
      onOweTap: () => context.pushNamed('i-owe'),
    );
  }

  Widget _buildBalanceCard(BuildContext context, bool isDark, DashboardData data) {
    return BalanceCard(
      totalBalance: data.totalBalance,
      currency: '₹',
    );
  }

  Widget _buildRecentGroupsSection(BuildContext context, bool isDark, DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Your Groups',
          onAdd: () => context.pushNamed('create-group'),
          addLabel: 'Create new group',
          onSeeAll: () => context.go('/home/groups'),
        ),
        const SizedBox(height: 12),
        if (data.recentGroups.isEmpty)
          _EmptyGroupsCard(
            isDark: isDark,
            onTap: () => context.pushNamed('create-group'),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: data.recentGroups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final group = data.recentGroups[index];
                return GroupMiniCard(
                  group: group,
                  onTap: () => context.push('/home/groups/${group.id}'),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentExpensesSection(bool isDark, DashboardData data) {
    return RecentExpensesSection(
      expenses: data.recentExpenses,
      groups: data.recentGroups,
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.errorText(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load your dashboard",
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body2(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onAdd,
    this.addLabel,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onAdd;
  final String? addLabel;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headline3(isDark).copyWith(
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAdd != null)
              Semantics(
                button: true,
                label: addLabel ?? 'Add',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.tealDark.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ),
              ),
            if (onSeeAll != null) ...[
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'See all',
                child: TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See all',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EmptyGroupsCard extends StatelessWidget {
  const _EmptyGroupsCard({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.divider(isDark),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealDark.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_add_rounded,
                  color: AppColors.tealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No groups yet',
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create one to start splitting',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
