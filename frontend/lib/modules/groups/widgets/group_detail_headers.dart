import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/group_detail_provider.dart';
import 'add_member_button.dart';
import 'group_cover_thumb.dart';
import 'group_hero_card.dart';
import 'group_member_actions.dart';
import 'group_members_strip.dart';

// Compact header: <600px — hero gradient card + members strip
Widget buildGroupCompactHeader(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupHeroCard(detail: detail),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'MEMBERS · ${detail.members.length}',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    fontSize: 11,
                  ),
                ),
              ),
              AddMemberButton(
                onTap: () => showGroupInviteDialog(groupId, context, ref),
              ),
            ],
          ),
        ),
        buildGroupMembersList(
          groupId,
          context,
          isDark,
          detail,
          ref,
          myId,
          isAdmin,
        ),
      ],
    ),
  );
}

// Standard header: 600-1100px - improved spacing (24-32px)
Widget buildGroupStandardHeader(
  String groupId,
  BuildContext context,
  bool isDark,
  GroupDetail detail,
  WidgetRef ref,
  String? myId,
  bool isAdmin,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    decoration: BoxDecoration(
      color: AppColors.surface(isDark),
      border: Border(
        bottom: BorderSide(color: AppColors.divider(isDark), width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group title with cover image (or emoji fallback)
        Row(
          children: [
            GroupCoverThumb(
              coverImageBase64: detail.group.coverImageBase64,
              coverEmoji: detail.group.coverEmoji,
              size: 52,
              borderRadius: 14,
              emojiFontSize: 32,
              fallbackIconColor: AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                detail.group.name,
                style: AppTextStyles.headline2(isDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Statistics in a spacious row
        Row(
          children: [
            Expanded(
              child: _buildStatistic(
                context,
                isDark,
                'Total',
                CurrencyFormatter.format(detail.totalExpense),
              ),
            ),
            Expanded(
              child: _buildStatistic(
                context,
                isDark,
                'Members',
                '${detail.members.length}',
              ),
            ),
            Expanded(
              child: _buildStatistic(
                context,
                isDark,
                'Expenses',
                '${detail.expenses.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'MEMBERS · ${detail.members.length}',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  fontSize: 11,
                ),
              ),
            ),
            AddMemberButton(
              onTap: () => showGroupInviteDialog(groupId, context, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Members list
        buildGroupMembersList(
          groupId,
          context,
          isDark,
          detail,
          ref,
          myId,
          isAdmin,
        ),
      ],
    ),
  );
}

// Standard statistic for tablet/desktop
Widget _buildStatistic(
  BuildContext context,
  bool isDark,
  String label,
  String value,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.caption(isDark)),
      const SizedBox(height: 4),
      Text(
        value,
        style: AppTextStyles.headline3(
          isDark,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 18),
      ),
    ],
  );
}
