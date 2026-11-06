import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../buttons/primary_button.dart';

/// Styled error state widget for displaying errors across the app
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData icon;

  const ErrorStateWidget({
    Key? key,
    required this.message,
    this.title,
    this.onRetry,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.icon = Icons.error_outline_rounded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 24 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorBg(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.errorText(isDark),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            // Error title
            if (title != null)
              Text(
                title!,
                style: AppTextStyles.headline3(isDark),
                textAlign: TextAlign.center,
              ),
            if (title != null) const SizedBox(height: 12),

            // Error message
            Text(
              message,
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),

            // Retry button
            if (onRetry != null)
              SizedBox(
                width: isCompact ? double.infinity : 200,
                child: PrimaryButton(
                  label: 'Retry',
                  onPressed: onRetry!,
                ),
              ),
            if (onSecondaryAction != null) ...[
              if (onRetry != null) const SizedBox(height: 12),
              SizedBox(
                width: isCompact ? double.infinity : 200,
                child: TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel ?? 'Go back'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
