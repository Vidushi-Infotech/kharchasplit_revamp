import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../state/group_detail_provider.dart';
import 'add_member_button.dart';
import 'group_member_actions.dart';
import 'member_actions_sheet.dart';
import 'remove_member_actions.dart';

// Members section for the large layout's left pane — the phone moves
// these to Group settings.
Widget buildGroupMembersSection(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Members (${detail.members.length})',
              style: AppTextStyles.headline3(isDark),
            ),
          ),
          if (!detail.group.isDirect)
            AddMemberButton(
              onTap: () => showGroupInviteDialog(groupId, context, ref),
            ),
        ],
      ),
      const SizedBox(height: 12),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: detail.members.length,
        itemBuilder: (context, index) {
          final member = detail.members[index];
          final isSelf = member.id == myId;
          final canRemove = isAdmin && !isSelf;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showMemberActionsSheet(
                  groupId: groupId,
                  context: context,
                  ref: ref,
                  member: member,
                  isAdmin: isAdmin,
                  isSelf: isSelf,
                  isDirect: detail.group.isDirect,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.divider(isDark),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        imageUrl: member.avatarUrl,
                        name: member.name,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: AppTextStyles.body2(isDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              member.email.isEmpty ? 'No email' : member.email,
                              style: AppTextStyles.caption(isDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (canRemove)
                        IconButton(
                          tooltip: 'Remove from group',
                          icon: Icon(
                            Icons.person_remove_outlined,
                            color: AppColors.errorText(isDark),
                          ),
                          onPressed: () => confirmRemoveMember(
                            groupId,
                            context,
                            ref,
                            member,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
