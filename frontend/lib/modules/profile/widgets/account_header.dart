import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/user_model.dart';

/// Top of the Account tab: avatar, name, email (with its verified chip)
/// and phone, flat on the page, with a pencil that opens Edit profile.
class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, required this.user, this.onVerifyEmail});

  final UserModel? user;

  /// Opens the verification sheet. Only wired when the user has an email.
  final VoidCallback? onVerifyEmail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?.name ?? 'Guest';
    final phone = user?.phone ?? '';
    final email = user?.email ?? '';
    final secondary = AppTextStyles.body2(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(imageUrl: user?.avatarUrl, name: name, radius: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headline3(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  // Verification is optional; we only highlight the gap.
                  EmailVerifiedBadge(
                    verified: user?.isEmailVerified ?? false,
                    isDark: isDark,
                    onVerify: onVerifyEmail,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.editProfile,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.textSecondary(isDark),
            onPressed: () => context.pushNamed('edit-profile'),
          ),
        ],
      ),
    );
  }
}

/// "Verified" (green tick) or a tappable amber "Not verified · Verify" chip
/// under the email on the profile card.
class EmailVerifiedBadge extends StatelessWidget {
  const EmailVerifiedBadge({
    super.key,
    required this.verified,
    required this.isDark,
    this.onVerify,
  });

  final bool verified;
  final bool isDark;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.success : AppColors.warning;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Not verified · Verify',
            style: AppTextStyles.caption(
              isDark,
            ).copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
    if (verified || onVerify == null) return chip;
    return Semantics(
      button: true,
      label: 'Verify email',
      child: InkWell(
        onTap: () {
          HapticService.instance.selection();
          onVerify!();
        },
        borderRadius: BorderRadius.circular(8),
        child: chip,
      ),
    );
  }
}
