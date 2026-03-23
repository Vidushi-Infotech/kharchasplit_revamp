import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: screenWidth < 600
          ? _buildCompactLayout(isDark, themeMode, ref)
          : screenWidth < 1100
              ? _buildStandardLayout(isDark, themeMode, ref)
              : _buildLargeLayout(isDark, themeMode, ref),
    );
  }

  /// Compact layout for mobile (< 600px)
  Widget _buildCompactLayout(bool isDark, AppThemeMode themeMode, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildProfileHeader(isDark),
          const SizedBox(height: 40),
          _buildThemeSelector(isDark, themeMode, ref),
          const SizedBox(height: 32),
          _buildProfileMenu(isDark),
        ],
      ),
    );
  }

  /// Standard layout for tablets (600-1100px)
  Widget _buildStandardLayout(bool isDark, AppThemeMode themeMode, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildProfileHeader(isDark),
              const SizedBox(height: 48),
              _buildThemeSelector(isDark, themeMode, ref),
              const SizedBox(height: 40),
              _buildProfileMenu(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Large layout for desktop (> 1100px)
  Widget _buildLargeLayout(bool isDark, AppThemeMode themeMode, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildProfileHeader(isDark),
              const SizedBox(height: 56),
              _buildThemeSelector(isDark, themeMode, ref),
              const SizedBox(height: 48),
              _buildProfileMenu(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Profile header with avatar and name
  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tealDark.withOpacity(0.2),
          ),
          child: const Icon(Icons.person_rounded, size: 40),
        ),
        const SizedBox(height: 16),
        Text('You', style: AppTextStyles.headline2(isDark)),
        const SizedBox(height: 8),
        Text(
          'user@example.com',
          style: AppTextStyles.body2(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  /// Theme selector with System, Light, and Dark options
  Widget _buildThemeSelector(bool isDark, AppThemeMode themeMode, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: AppTextStyles.headline3(isDark).copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred theme',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          // System theme option
          _buildThemeOption(
            context: null,
            isDark: isDark,
            icon: Icons.brightness_auto_rounded,
            label: 'System',
            description: 'Follow device settings',
            isSelected: themeMode == AppThemeMode.system,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(AppThemeMode.system);
            },
          ),
          const SizedBox(height: 12),
          // Light theme option
          _buildThemeOption(
            context: null,
            isDark: isDark,
            icon: Icons.light_mode_rounded,
            label: 'Light',
            description: 'Always use light theme',
            isSelected: themeMode == AppThemeMode.light,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(AppThemeMode.light);
            },
          ),
          const SizedBox(height: 12),
          // Dark theme option
          _buildThemeOption(
            context: null,
            isDark: isDark,
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            description: 'Always use dark theme',
            isSelected: themeMode == AppThemeMode.dark,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(AppThemeMode.dark);
            },
          ),
        ],
      ),
    );
  }

  /// Individual theme option widget
  Widget _buildThemeOption({
    required BuildContext? context,
    required bool isDark,
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withOpacity(0.1)
              : AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.divider(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.brand.withOpacity(0.2)
                    : AppColors.surface(isDark),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.brand : AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.brand,
              ),
          ],
        ),
      ),
    );
  }

  /// Profile menu items
  Widget _buildProfileMenu(bool isDark) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Settings menu item - configure app preferences',
          child: ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Help and support menu item - view help documentation',
          child: ListTile(
            leading: const Icon(Icons.help_rounded),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Privacy policy menu item - read privacy terms',
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
        ),
        Semantics(
          button: true,
          label: 'Logout menu item - sign out and return to login',
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
