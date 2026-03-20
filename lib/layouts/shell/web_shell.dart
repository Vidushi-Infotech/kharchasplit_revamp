import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'shell_state.dart';

/// Web shell with fixed sidebar 240px
class WebShell extends ConsumerWidget {
  final Widget child;

  const WebShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);

    return Scaffold(
      body: Row(
        children: [
          // Fixed sidebar
          Container(
            width: 240,
            color: AppColors.surface(isDark),
            child: Column(
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.brand, AppColors.tealDark],
                          ),
                        ),
                        child: const Icon(Icons.receipt_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Kharcha Split',
                          style: AppTextStyles.headline3(isDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(
                        context,
                        isDark,
                        index: 0,
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: selectedIndex == 0,
                        onTap: () => _navigateTo(context, ref, 0, '/home/dashboard'),
                      ),
                      _buildNavItem(
                        context,
                        isDark,
                        index: 1,
                        icon: Icons.group_rounded,
                        label: 'Groups',
                        isSelected: selectedIndex == 1,
                        onTap: () => _navigateTo(context, ref, 1, '/home/groups'),
                      ),
                      _buildNavItem(
                        context,
                        isDark,
                        index: 3,
                        icon: Icons.people_alt_rounded,
                        label: 'Friends',
                        isSelected: selectedIndex == 3,
                        onTap: () => _navigateTo(context, ref, 3, '/home/friends'),
                      ),
                      _buildNavItem(
                        context,
                        isDark,
                        index: 4,
                        icon: Icons.notifications_rounded,
                        label: 'Activity',
                        isSelected: selectedIndex == 4,
                        badge: unreadCount > 0 ? '$unreadCount' : null,
                        onTap: () => _navigateTo(context, ref, 4, '/home/activity'),
                      ),
                      const Divider(),
                      _buildNavItem(
                        context,
                        isDark,
                        index: 5,
                        icon: Icons.bar_chart_rounded,
                        label: 'Reports',
                        isSelected: false,
                        onTap: () => context.go('/reports'),
                      ),
                      _buildNavItem(
                        context,
                        isDark,
                        index: 6,
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        isSelected: false,
                        onTap: () => context.go('/home/profile'),
                      ),
                    ],
                  ),
                ),
                // Bottom divider
                const Divider(),
                // Settings
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/home/profile/settings'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.divider(isDark),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.settings_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Settings',
                              style: AppTextStyles.body2(isDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    bool isDark, {
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brand.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.brand
                    : AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: isSelected
                        ? AppColors.brand
                        : AppColors.textPrimary(isDark),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(
    BuildContext context,
    WidgetRef ref,
    int index,
    String path,
  ) {
    ref.read(selectedNavIndexProvider.notifier).state = index;
    context.go(path);
  }
}
