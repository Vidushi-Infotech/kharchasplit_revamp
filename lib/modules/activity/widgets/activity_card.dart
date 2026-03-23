import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/activity_model.dart';
import '../../../components/avatar/avatar_widget.dart';

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;

  const ActivityCard({
    Key? key,
    required this.activity,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or icon
              if (activity.actorUser != null)
                AvatarWidget(
                  imageUrl: activity.actorUser!.avatarUrl,
                  name: activity.actorUser!.name,
                  radius: 20,
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brand.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      activity.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.description,
                            style: AppTextStyles.body2(isDark).copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(isDark),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!activity.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.unread,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Timestamp
                    Text(
                      DateFormatter.relativeTime(activity.timestamp),
                      style: AppTextStyles.caption(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
