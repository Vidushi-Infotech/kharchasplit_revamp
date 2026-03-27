import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';

class ProfileActionsWidget extends ConsumerWidget {
  final VoidCallback onHelp;
  final VoidCallback onPrivacy;
  final VoidCallback onLogout;

  const ProfileActionsWidget({
    super.key,
    required this.onHelp,
    required this.onPrivacy,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentTheme = ref.watch(themeModeProvider);

    final isLarge = screenWidth > 1100;
    final gap = isLarge ? 16.0 : 12.0;

    return Semantics(
      label: 'Profile actions menu',
      child: Column(
        children: [
          // Theme selector
          isLarge
              ? Row(
                  children: [
                    Expanded(
                      child: _buildThemeSelector(isDark, currentTheme, ref),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _buildActionButton(
                        isDark,
                        icon: Icons.help_rounded,
                        label: 'Help & Support',
                        description: 'Get help and support',
                        color: AppColors.brand,
                        onTap: onHelp,
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _buildActionButton(
                        isDark,
                        icon: Icons.privacy_tip_rounded,
                        label: 'Privacy Policy',
                        description: 'Read our privacy terms',
                        color: AppColors.success,
                        onTap: onPrivacy,
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _buildActionButton(
                        isDark,
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        description: 'Sign out of your account',
                        color: AppColors.warning,
                        onTap: onLogout,
                        isDestructive: true,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildThemeSelector(isDark, currentTheme, ref),
                    SizedBox(height: gap),
                    _buildActionButton(
                      isDark,
                      icon: Icons.help_rounded,
                      label: 'Help & Support',
                      description: 'Get help and support',
                      color: AppColors.brand,
                      onTap: onHelp,
                    ),
                    SizedBox(height: gap),
                    _buildActionButton(
                      isDark,
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy Policy',
                      description: 'Read our privacy terms',
                      color: AppColors.success,
                      onTap: onPrivacy,
                    ),
                    SizedBox(height: gap),
                    _buildActionButton(
                      isDark,
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      description: 'Sign out of your account',
                      color: AppColors.warning,
                      onTap: onLogout,
                      isDestructive: true,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    bool isDark,
    AppThemeMode currentTheme,
    WidgetRef ref,
  ) {
    return GestureDetector(
      onTap: () {},
      child: Semantics(
        label: 'Theme selector',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 20,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getThemeLabel(currentTheme),
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<AppThemeMode>(
                initialValue: currentTheme,
                onSelected: (AppThemeMode newTheme) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newTheme);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<AppThemeMode>>[
                  PopupMenuItem<AppThemeMode>(
                    value: AppThemeMode.system,
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_rounded,
                          size: 18,
                          color: currentTheme == AppThemeMode.system
                              ? AppColors.brand
                              : AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 12),
                        const Text('System'),
                      ],
                    ),
                  ),
                  PopupMenuItem<AppThemeMode>(
                    value: AppThemeMode.light,
                    child: Row(
                      children: [
                        Icon(
                          Icons.light_mode_rounded,
                          size: 18,
                          color: currentTheme == AppThemeMode.light
                              ? AppColors.brand
                              : AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 12),
                        const Text('Light'),
                      ],
                    ),
                  ),
                  PopupMenuItem<AppThemeMode>(
                    value: AppThemeMode.dark,
                    child: Row(
                      children: [
                        Icon(
                          Icons.dark_mode_rounded,
                          size: 18,
                          color: currentTheme == AppThemeMode.dark
                              ? AppColors.brand
                              : AppColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 12),
                        const Text('Dark'),
                      ],
                    ),
                  ),
                ],
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light mode';
      case AppThemeMode.dark:
        return 'Dark mode';
    }
  }

  Widget _buildActionButton(
    bool isDark, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.warning.withValues(alpha: 0.1)
                : AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.divider(isDark),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? AppColors.warning : null,
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
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
