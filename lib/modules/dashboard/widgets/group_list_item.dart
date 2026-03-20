import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/dashboard_provider.dart';

/// Group list item widget
class GroupListItem extends StatelessWidget {
  final GroupInfo group;
  final VoidCallback onTap;

  const GroupListItem({
    Key? key,
    required this.group,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = group.balance >= 0;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Group name
                    Expanded(
                      child: Text(
                        group.name,
                        style: AppTextStyles.body1(isDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Balance
                    Text(
                      '${isPositive ? '+' : ''}₹${group.balance.toStringAsFixed(2)}',
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: isPositive
                            ? AppColors.greenLight
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Member avatars
                    SizedBox(
                      width: 100,
                      height: 32,
                      child: Stack(
                        children: List.generate(
                          group.memberAvatars.length > 3
                              ? 3
                              : group.memberAvatars.length,
                          (index) => Positioned(
                            left: index * 20.0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.tealDark
                                  .withOpacity(0.1 + (index * 0.1)),
                              child: Text(
                                group.memberAvatars[index],
                                style: AppTextStyles.caption(isDark).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tealDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Member count
                    Text(
                      '${group.memberCount} members',
                      style: AppTextStyles.caption(isDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
