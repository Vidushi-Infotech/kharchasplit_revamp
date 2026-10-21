import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../notifications/state/notifications_inbox_provider.dart';

/// Bell with an unread badge for the Groups header. The notifications inbox
/// used to be reachable only from the Home dashboard's header; Groups is the
/// home tab now, so the bell moved here with the overall balance.
class GroupsNotificationsButton extends ConsumerWidget {
  const GroupsNotificationsButton({super.key, this.size = 38});

  /// Matches the round header actions next to it.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unread > 0;

    return Semantics(
      button: true,
      label: hasUnread
          ? '${AppStrings.notifications}, $unread unread'
          : AppStrings.notifications,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => context.pushNamed('notifications-inbox'),
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBg(isDark),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: AppColors.textPrimary(isDark),
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.background(isDark),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(isDark).copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
