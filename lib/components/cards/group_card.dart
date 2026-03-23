import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../avatar/avatar_widget.dart';
import '../text/currency_text.dart';

/// Card widget for displaying a group
class GroupCard extends StatelessWidget {
  final GroupModel group;
  final VoidCallback? onTap;

  const GroupCard({
    Key? key,
    required this.group,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositiveBalance = group.myBalance >= 0;

    return GestureDetector(
      onTap: onTap,
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
            // Header: emoji and name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Emoji icon as group avatar
                      Text(
                        group.coverEmoji,
                        style: const TextStyle(fontSize: 44),
                      ),
                      const SizedBox(width: 16),
                      // Group name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: AppTextStyles.body1(isDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.categoryName,
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // My balance in this group
                Semantics(
                  label: isPositiveBalance
                      ? 'You are owed ${group.currency}${group.myBalance.abs().toStringAsFixed(0)} in this group'
                      : 'You owe ${group.currency}${group.myBalance.abs().toStringAsFixed(0)} in this group',
                  child: Tooltip(
                    message: isPositiveBalance ? 'You are owed' : 'You owe',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPositiveBalance
                            ? AppColors.greenLight.withOpacity(0.2)
                            : AppColors.warningOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CurrencyText(
                        group.myBalance,
                        currency: group.currency,
                        textStyle: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        showSign: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Members avatars
            StackedAvatarsWidget(
              names: group.members.map((m) => m.name).toList(),
              imageUrls: group.members.map((m) => m.avatarUrl).toList(),
              radius: 14,
              maxVisible: 4,
            ),
            const SizedBox(height: 8),
            // Member count
            Text(
              '${group.memberCount} members',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            // Total spent info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface(isDark) : const Color(0xFFF5F9F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Group Total',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  CurrencyText(
                    group.totalExpenses,
                    currency: group.currency,
                    textStyle: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable variant of GroupCard
class GroupCardHorizontal extends StatelessWidget {
  final GroupModel group;
  final VoidCallback? onTap;

  const GroupCardHorizontal({
    Key? key,
    required this.group,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositiveBalance = group.myBalance >= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
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
            // Large emoji
            Text(
              group.coverEmoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              group.name,
              style: AppTextStyles.body1(isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Category
            Text(
              group.categoryName,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            // Balance in group
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isPositiveBalance
                    ? AppColors.greenLight.withOpacity(0.2)
                    : AppColors.warningOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: CurrencyText(
                group.myBalance,
                currency: group.currency,
                textStyle: AppTextStyles.caption(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                showSign: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for adding new group (+ icon)
class AddGroupCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddGroupCard({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider(isDark),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 40,
                color: AppColors.textSecondary(isDark),
              ),
              const SizedBox(height: 8),
              Text(
                'New Group',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
