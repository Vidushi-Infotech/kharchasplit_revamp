import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/components.dart';
import '../state/group_detail_provider.dart';
import 'add_member_button.dart';
import 'group_cover_thumb.dart';
import 'group_member_actions.dart';
import 'member_actions_sheet.dart';
import 'remove_member_actions.dart';

// Large header: >1100px - generous spacing (32-48px)
Widget buildGroupLargeHeader(
  BuildContext context,
  bool isDark,
  GroupDetail detail,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Group title with large cover image (or emoji fallback)
      Row(
        children: [
          GroupCoverThumb(
            coverImageBase64: detail.group.coverImageBase64,
            coverEmoji: detail.group.coverEmoji,
            size: 64,
            borderRadius: 16,
            emojiFontSize: 42,
            fallbackIconColor: AppColors.textSecondary(isDark),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.group.name, style: AppTextStyles.headline1(isDark)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      // Statistics cards stacked vertically for desktop
      _buildLargeStatisticCard(
        context,
        isDark,
        'Total Amount',
        CurrencyFormatter.format(detail.totalExpense),
        Icons.account_balance_wallet_rounded,
        AppColors.brand,
      ),
      const SizedBox(height: 12),
      _buildLargeStatisticCard(
        context,
        isDark,
        'Total Members',
        '${detail.members.length}',
        Icons.people_rounded,
        AppColors.brand,
      ),
      const SizedBox(height: 12),
      _buildLargeStatisticCard(
        context,
        isDark,
        'Total Expenses',
        '${detail.expenses.length}',
        Icons.receipt_long_rounded,
        AppColors.success,
      ),
    ],
  );
}

// Desktop-style statistics card with icon
Widget _buildLargeStatisticCard(
  BuildContext context,
  bool isDark,
  String label,
  String value,
  IconData icon,
  Color iconColor,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface(isDark),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider(isDark), width: 1),
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption(isDark)),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.headline3(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Members section for large layout - compact list display.
// Same hoisting pattern as _buildMembersList.
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
