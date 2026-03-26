import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileActionsWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'Profile actions menu',
      child: Column(
        children: [
          _buildActionButton(
            isDark,
            icon: Icons.help_rounded,
            label: 'Help & Support',
            description: 'Get help and support',
            color: AppColors.brand,
            onTap: onHelp,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            isDark,
            icon: Icons.privacy_tip_rounded,
            label: 'Privacy Policy',
            description: 'Read our privacy terms',
            color: AppColors.success,
            onTap: onPrivacy,
          ),
          const SizedBox(height: 12),
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
    );
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
