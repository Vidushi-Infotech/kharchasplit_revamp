import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';

/// Quiet, content-forward grid tile for a group. Visual hierarchy mirrors
/// the registry-card pattern used on sites like 21st.dev: preview icon
/// → title → metadata, with the key metric right-aligned at the bottom.
class GroupGridCard extends StatelessWidget {
  const GroupGridCard({super.key, required this.group, this.onTap});

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

    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: group.currency,
      decimalDigits: 0,
    ).format(balance.abs());

    final amountLabel = isSettled
        ? 'Settled'
        : '${isPositive ? '+' : '-'}$formatted';

    return Semantics(
      button: true,
      label: 'Group ${group.name}, ${group.memberCount} members, $amountLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.divider(isDark),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconTile(emoji: group.coverEmoji, isDark: isDark),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusDot(color: accent),
                          Flexible(
                            child: Text(
                              amountLabel,
                              style: AppTextStyles.body2(isDark).copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

class _IconTile extends StatelessWidget {
  const _IconTile({required this.emoji, required this.isDark});

  final String emoji;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasCustomEmoji =
        emoji.isNotEmpty && emoji != GroupGridCard._defaultPeopleEmoji;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.divider(isDark).withValues(alpha: 0.6),
        ),
      ),
      child: hasCustomEmoji
          ? Text(emoji, style: const TextStyle(fontSize: 20))
          : Icon(
              Icons.group_rounded,
              size: 20,
              color: AppColors.textSecondary(isDark),
            ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
