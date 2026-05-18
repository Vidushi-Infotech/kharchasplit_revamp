import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import 'group_cover_thumb.dart';

/// Full-width compact list row for the Groups screen.
class GroupRowCard extends StatelessWidget {
  const GroupRowCard({super.key, required this.group, this.onTap});

  final GroupModel group;
  final VoidCallback? onTap;

  static const String _defaultPeopleEmoji = '👥';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = group.myBalance;
    final isSettled = balance == 0;
    final isPositive = balance > 0;

    final accent = isSettled
        ? AppColors.textSecondary(isDark)
        : isPositive
            ? AppColors.success
            : AppColors.warning;

    final amountText = isSettled
        ? 'Settled'
        : '${isPositive ? '+' : '-'}${NumberFormat.currency(
            locale: 'en_IN',
            symbol: group.currency,
            decimalDigits: 0,
          ).format(balance.abs())}';

    final amountIcon = isSettled
        ? Icons.check_circle_rounded
        : isPositive
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;

    return Semantics(
      button: true,
      label: 'Group ${group.name}, ${group.memberCount} members, $amountText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  _GroupIcon(group: group, isDark: isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.name,
                          style: AppTextStyles.body1(isDark).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(amountIcon, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        amountText,
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.group, required this.isDark});

  final GroupModel group;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark).withValues(alpha: 0.6),
        ),
      ),
      child: GroupCoverThumb(
        coverImageBase64: group.coverImageBase64,
        coverEmoji: group.coverEmoji,
        size: 42,
        borderRadius: 12,
        emojiFontSize: 22,
        fallbackIconColor: AppColors.textSecondary(isDark),
      ),
    );
  }
}
