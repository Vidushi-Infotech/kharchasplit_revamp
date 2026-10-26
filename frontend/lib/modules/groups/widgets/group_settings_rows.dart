import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/user_model.dart';
import '../state/group_detail_provider.dart';
import '../state/group_display.dart';
import '../state/group_member_balances.dart';
import 'group_detail_cover.dart';
import 'member_actions_sheet.dart';

/// Round tinted icon used as the leading tile of settings rows.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: c, size: 20),
    );
  }
}

/// Plain action row: tinted icon and a label (optionally red / orange).
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  /// Tints the icon (danger actions use the error / warning color).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return KsListRow(
      dense: true,
      leading: SettingsIconTile(icon: icon, color: color),
      title: label,
      subtitles: [?subtitle],
      semanticsLabel: label,
      onTap: onTap,
    );
  }
}

/// Cover, name and an Edit button that opens the rename / cover sheet
/// (any member can edit, as in Splitwise).
class GroupSettingsHeader extends StatelessWidget {
  const GroupSettingsHeader({
    super.key,
    required this.detail,
    required this.myId,
    required this.onEdit,
  });

  final GroupDetail detail;
  final String? myId;

  /// Null hides the edit button.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return KsListRow(
      leading: GroupDetailCover(
        group: detail.group,
        myId: myId,
        size: 52,
        borderRadius: 12,
        emojiFontSize: 26,
        fallbackIconColor: AppColors.textSecondary(isDark),
      ),
      title: detail.group.displayTitle(myId),
      subtitles: [if (onEdit != null) AppStrings.editGroupHint],
      trailing: onEdit == null
          ? null
          : TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(AppStrings.editGroupDetails),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            ),
      onTap: onEdit,
    );
  }
}

/// A member in "Group members": avatar, name, email / phone, and their
/// balance in the group on the right. Tap opens the member's actions.
class GroupSettingsMemberRow extends ConsumerWidget {
  const GroupSettingsMemberRow({
    super.key,
    required this.detail,
    required this.member,
    required this.balance,
    required this.myId,
    required this.isAdmin,
  });

  final GroupDetail detail;
  final UserModel member;
  final MemberBalance? balance;
  final String? myId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = balance?.net ?? 0;
    final tone = BalanceTone.fromAmount(net);
    final amount = CurrencyFormatter.format(
      net.abs(),
      currency: detail.group.currency,
    );
    final label = switch (tone) {
      BalanceTone.owed => AppStrings.memberGetsBack,
      BalanceTone.owe => AppStrings.memberOwes,
      _ => AppStrings.settledUpLower,
    };
    final isSelf = member.id == myId;
    final name = member.name.trim().isEmpty
        ? AppStrings.invitedMember
        : member.name;
    final contact = member.isPlaceholder
        ? AppStrings.invitedMember
        : member.email.isNotEmpty
        ? member.email
        : member.phone;
    return KsListRow(
      leading: Opacity(
        opacity: member.isPlaceholder ? 0.5 : 1,
        child: AvatarWidget(
          imageUrl: member.avatarUrl,
          name: name,
          radius: 20,
        ),
      ),
      title: isSelf
          ? '$name (${AppStrings.balanceYouObject})'
          : name,
      subtitles: [if (contact.isNotEmpty) contact],
      trailing: BalanceAmountLabel(
        tone: tone,
        amount: net,
        currency: detail.group.currency,
        label: label,
      ),
      semanticsLabel:
          '$name, $label'
          '${tone == BalanceTone.settled ? '' : ' $amount'}',
      onTap: () => showMemberActionsSheet(
        groupId: detail.group.id,
        context: context,
        ref: ref,
        member: member,
        isAdmin: isAdmin,
        isSelf: isSelf,
        isDirect: detail.group.isDirect,
      ),
    );
  }
}
