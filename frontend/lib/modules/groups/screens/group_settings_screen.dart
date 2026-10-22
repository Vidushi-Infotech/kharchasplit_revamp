import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/group_member_balances.dart';
import '../widgets/group_admin_actions.dart';
import '../widgets/group_default_split_sheet.dart';
import '../widgets/group_lifecycle_actions.dart';
import '../widgets/group_member_actions.dart';
import '../widgets/group_settings_rows.dart';
import '../widgets/group_simplify_debts.dart';
import '../widgets/group_subpage_scaffold.dart';

/// Group settings (⚙ on group detail): name and cover, the members with
/// their balances and "Add people to group", advanced settings (simplify
/// debts, default split, recurring) and the archive / complete / leave /
/// delete actions at the bottom. Direct groups never open this page.
class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return GroupSubpageScaffold(
      groupId: groupId,
      title: AppStrings.groupSettings,
      builder: (context, detail, _) => _SettingsList(detail: detail),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myId = ref.watch(myIdProvider);
    final groupId = detail.group.id;
    final group = detail.group;
    final isAdmin = isGroupAdmin(detail, myId);
    final balances = {
      for (final b
          in ref.watch(groupMemberBalancesProvider(groupId)) ?? const [])
        b.member.id: b,
    };
    final simplifyOn = watchFeature(ref, 'simplifyDebts');
    final recurringOn = watchFeature(ref, 'recurring');
    final danger = AppColors.errorText(isDark);

    // Fixed rows before and after the member rows; the member rows in
    // between are built lazily by index.
    final before = <WidgetBuilder>[
      (_) => GroupSettingsHeader(
        detail: detail,
        myId: myId,
        onEdit: isAdmin ? () => openEditGroupSheet(context, ref, group) : null,
      ),
      (_) => const GroupSectionTitle(AppStrings.groupMembers),
      if (!group.isDirect)
        (_) => SettingsActionRow(
          icon: Icons.person_add_alt_1_rounded,
          label: AppStrings.addPeopleToGroup,
          onTap: () => showGroupInviteDialog(groupId, context, ref),
        ),
    ];
    final after = <WidgetBuilder>[
      (_) => const GroupSectionTitle(AppStrings.advancedSettings),
      // The flag only hides the switch for admins; a group simplified on a
      // newer build still shows that it is on.
      if (simplifyOn || group.simplifyDebts)
        (_) => GroupSimplifyDebtsTile(
          groupId: groupId,
          canEdit: isAdmin && simplifyOn,
        ),
      if (isAdmin)
        (_) => SettingsActionRow(
          icon: Icons.pie_chart_outline_rounded,
          label: AppStrings.defaultSplit,
          onTap: () => showGroupDefaultSplitSheet(context, group),
        ),
      if (recurringOn)
        (_) => SettingsActionRow(
          icon: Icons.repeat_rounded,
          label: AppStrings.recurringExpenses,
          onTap: () => context.push('/home/groups/$groupId/recurring'),
        ),
      (_) => const SizedBox(height: 24),
      if (isAdmin) ...[
        (_) => group.isArchived
            ? SettingsActionRow(
                icon: Icons.unarchive_outlined,
                label: AppStrings.unarchiveGroup,
                onTap: () => unarchiveGroup(context, ref, groupId),
              )
            : SettingsActionRow(
                icon: Icons.archive_outlined,
                label: AppStrings.archiveGroup,
                color: AppColors.warning,
                onTap: () => confirmArchiveGroup(context, ref, detail),
              ),
        if (!group.isCompleted)
          (_) => SettingsActionRow(
            icon: Icons.task_alt_rounded,
            label: AppStrings.markComplete,
            onTap: () => confirmCompleteGroup(context, ref, detail),
          ),
        (_) => SettingsActionRow(
          icon: Icons.delete_outline_rounded,
          label: AppStrings.deleteGroup,
          color: danger,
          onTap: () => confirmDeleteGroup(groupId, context, ref),
        ),
      ] else
        // The admin can't leave their own group — they delete it instead.
        (_) => SettingsActionRow(
          icon: Icons.logout_rounded,
          label: AppStrings.leaveGroup,
          color: AppColors.warning,
          onTap: () => confirmLeaveGroup(groupId, context, ref, myId),
        ),
    ];
    final members = detail.members;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: before.length + members.length + after.length,
      itemBuilder: (context, i) {
        if (i < before.length) return before[i](context);
        final m = i - before.length;
        if (m < members.length) {
          final member = members[m];
          return GroupSettingsMemberRow(
            key: ValueKey(member.id),
            detail: detail,
            member: member,
            balance: balances[member.id],
            myId: myId,
            isAdmin: isAdmin,
          );
        }
        return after[m - members.length](context);
      },
    );
  }
}
