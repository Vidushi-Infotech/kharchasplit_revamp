import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/bottom_navigation_bar.dart';
import '../../../components/cards/balance_card.dart';
import '../../../models/models.dart';
import '../state/dashboard_provider.dart';
import '../widgets/dashboard_header.dart';

/// Navigation index provider for sidebar/bottom nav
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

/// Home screen with dashboard
class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasCompactWidth = screenWidth < 600; // Mobile, Folded Foldables
    final dashboardData =
        ref.watch(dashboardProvider).value ?? DashboardData.empty;
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: hasCompactWidth
          ? _buildMobileLayout(isDark, dashboardData, ref)
          : _buildSidebarLayout(isDark, dashboardData, ref),
      bottomNavigationBar: hasCompactWidth
          ? CustomBottomNavigationBar(
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                ref.read(selectedNavIndexProvider.notifier).state = index;
                _navigateToPage(context, index);
              },
            )
          : null,
    );
  }

  Widget _buildMobileLayout(
    bool isDark,
    DashboardData data,
    WidgetRef ref,
  ) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          const DashboardHeader(),
          const SizedBox(height: 24),
          BalanceCard(totalBalance: data.totalBalance),
          const SizedBox(height: 32),
          _buildGroupsSection(isDark, data),
        ],
      ),
    );
  }

  Widget _buildSidebarLayout(
    bool isDark,
    DashboardData data,
    WidgetRef ref,
  ) {
    return SafeArea(
      child: Row(
        children: [
          // Sidebar (for tablet and web) - responsive width
          SizedBox(
            width: 240,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                border: Border(
                  right: BorderSide(
                    color: AppColors.divider(isDark),
                    width: 1,
                  ),
                ),
              ),
              child: _buildSidebar(isDark, ref),
            ),
          ),
          // Main content - responsive
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                const DashboardHeader(),
                const SizedBox(height: 40),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: BalanceCard(totalBalance: data.totalBalance),
                  ),
                ),
                const SizedBox(height: 48),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: _buildGroupsSection(isDark, data),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsSection(
    bool isDark,
    DashboardData data,
  ) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Groups',
            style: AppTextStyles.headline3(isDark),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.recentGroups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = data.recentGroups[index];
              return _buildGroupCard(isDark, group);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(bool isDark, GroupModel group) {
    final isPositive = group.myBalance >= 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to group details
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          group.coverEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            group.name,
                            style: AppTextStyles.body1(isDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}₹${group.myBalance.toStringAsFixed(0)}',
                    style: AppTextStyles.body1(isDark).copyWith(
                      color: isPositive ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${group.members.length} members',
                style: AppTextStyles.caption(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Kharcha Split',
            style: AppTextStyles.headline2(isDark),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: [
              _buildSidebarItem(
                isDark,
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () {
                  ref.read(selectedNavIndexProvider.notifier).state = 0;
                },
              ),
              _buildSidebarItem(
                isDark,
                icon: Icons.group_rounded,
                label: 'Groups',
                isSelected: selectedIndex == 1,
                onTap: () {
                  ref.read(selectedNavIndexProvider.notifier).state = 1;
                },
              ),
              _buildSidebarItem(
                isDark,
                icon: Icons.receipt_long_rounded,
                label: 'Expenses',
                isSelected: selectedIndex == 2,
                onTap: () {
                  ref.read(selectedNavIndexProvider.notifier).state = 2;
                },
              ),
              _buildSidebarItem(
                isDark,
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () {
                  ref.read(selectedNavIndexProvider.notifier).state = 3;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(
    bool isDark, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.tealDark : AppColors.textSecondary(isDark),
      ),
      title: Text(
        label,
        style: AppTextStyles.body2(isDark).copyWith(
          color: isSelected ? AppColors.tealDark : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      selectedTileColor: AppColors.tealDark.withValues(alpha: 0.1),
      selected: isSelected,
    );
  }

  void _navigateToPage(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Home (already here)
        break;
      case 1:
        // Groups page
        context.go('/home/groups');
        break;
      case 2:
        // Add expense page
        context.go('/add-expense');
        break;
      case 3:
        // Profile page
        context.go('/home/profile');
        break;
    }
  }
}
