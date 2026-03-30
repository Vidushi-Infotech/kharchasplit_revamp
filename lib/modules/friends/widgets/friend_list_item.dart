import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../../models/contact_model.dart';

class FriendListItem extends StatelessWidget {
  final ExtendedContactModel friend;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showRegistrationStatus;

  const FriendListItem({
    super.key,
    required this.friend,
    this.onTap,
    this.onDelete,
    this.showRegistrationStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '${friend.displayName} - ${friend.isRegistered ? 'Registered' : 'Not registered'}',
      button: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider(isDark),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                child: Text(
                  friend.initials,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name and phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PhoneFormatter.formatPhoneForDisplay(friend.primaryPhone ?? ''),
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Registration status badge
              if (showRegistrationStatus)
                Semantics(
                  label: friend.isRegistered
                      ? '${friend.displayName} is registered'
                      : '${friend.displayName} is not registered',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: friend.isRegistered
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      friend.isRegistered ? '✓ Active' : '○ Invite',
                      style: AppTextStyles.caption(isDark).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: friend.isRegistered
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ),

              // Delete button
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Semantics(
                    label: 'Remove ${friend.displayName}',
                    button: true,
                    onTap: onDelete,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
