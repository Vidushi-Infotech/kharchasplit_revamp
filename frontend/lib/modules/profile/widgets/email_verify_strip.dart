import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import 'email_verify_sheet.dart';

/// Slim dashboard strip shown only while the signed-in user's email is
/// unverified. Tapping anywhere starts the same confirm → OTP flow as the
/// profile chip. Renders nothing (zero height) once verified or when the
/// user has no email, so callers can place it unconditionally.
class EmailVerifyStrip extends ConsumerWidget {
  const EmailVerifyStrip({super.key, this.bottomSpacing = 16});

  /// Gap added below the strip when it is visible.
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((a) => a.user));
    if (user == null || user.email.trim().isEmpty || user.isEmailVerified) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = user.email.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Semantics(
        button: true,
        label: 'Verify your email',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticService.instance.selection();
              EmailVerifySheet.confirmAndShow(context, email: email);
            },
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verify your email to secure your account',
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verify',
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.warning),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
