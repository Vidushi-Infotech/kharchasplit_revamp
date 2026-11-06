import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Social authentication buttons (Google + Facebook)
class SocialAuthButtons extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final bool isLoading;

  const SocialAuthButtons({
    Key? key,
    this.onGooglePressed,
    this.onFacebookPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Divider with text
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.divider(isDark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.divider(isDark),
                ),
              ),
            ],
          ),
        ),
        // Social buttons
        Row(
          children: [
            // Google button
            Expanded(
              child: _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Google',
                onPressed: isLoading ? null : onGooglePressed,
                isGoogle: true,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            // Facebook button
            Expanded(
              child: _SocialButton(
                icon: Icons.facebook_rounded,
                label: 'Facebook',
                onPressed: isLoading ? null : onFacebookPressed,
                isFacebook: true,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual social button
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isGoogle;
  final bool isFacebook;
  final bool isDark;

  const _SocialButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isGoogle = false,
    this.isFacebook = false,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isGoogleButton = isGoogle;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: isFacebook
              ? AppColors.facebookBrand
              : (isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder),
        ),
        foregroundColor: isFacebook
            ? AppColors.facebookBrand
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        backgroundColor: isFacebook
            ? AppColors.facebookBrand.withValues(alpha: 0.1)
            : AppColors.surface(isDark),
      ),
    );
  }
}
