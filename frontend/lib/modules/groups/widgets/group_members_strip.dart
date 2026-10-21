import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../state/group_detail_provider.dart';
import 'member_actions_sheet.dart';

// Responsive members list - horizontal scroll for compact/standard, grid for large.
//
// Auth state (myId, isAdmin) is hoisted from the screen-level build via the
// signature so this method doesn't open a second authProvider subscription
// — every auth change rebuilds the whole tree once, not per-section.
Widget buildGroupMembersList(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  return SizedBox(
    height: 80,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: detail.members.length,
      itemBuilder: (context, index) {
        final member = detail.members[index];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => showMemberActionsSheet(
              groupId: groupId,
              context: context,
              ref: ref,
              member: member,
              isAdmin: isAdmin,
              isSelf: member.id == myId,
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Opacity(
                      opacity: member.isPlaceholder ? 0.5 : 1.0,
                      child: AvatarWidget(
                        imageUrl: member.avatarUrl,
                        name: member.name,
                        radius: 24,
                      ),
                    ),
                    if (member.isPlaceholder)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.background(isDark),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 56,
                  child: Text(
                    member.name.split(' ')[0],
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: member.isPlaceholder
                          ? AppColors.textSecondary(isDark)
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
