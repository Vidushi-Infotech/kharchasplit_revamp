import 'package:flutter/material.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import '../state/groups_list_view.dart';
import 'group_cover_thumb.dart';

/// Flat Groups-list row: square cover, name, up to two gray per-person
/// balance lines, and "you are owed / you owe / settled up" on the right.
class GroupRowCard extends StatelessWidget {
  const GroupRowCard({
    super.key,
    required this.group,
    this.people = const [],
    this.onTap,
    this.showDivider = true,
  });

  final GroupModel group;

  /// Who owes whom in this group (from [groupPersonBalancesProvider]).
  final List<GroupPersonBalance> people;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = BalanceTone.fromAmount(group.myBalance);
    final noExpenses =
        tone == BalanceTone.settled && group.totalExpenses.abs() < 0.005;
    final lines = groupBalanceLines(group, people);
    // Archived groups keep their status visible in the list.
    final status = group.isArchived
        ? (group.isCompleted ? AppStrings.completed : AppStrings.archived)
        : null;

    final trailing = BalanceAmountLabel(
      tone: tone,
      amount: group.myBalance,
      currency: group.currency,
      label: noExpenses ? AppStrings.noExpenses : null,
    );

    return KsListRow(
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.inputFill(isDark),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GroupCoverThumb(
          coverImageBase64: group.coverImageBase64,
          coverEmoji: group.coverEmoji,
          size: 52,
          borderRadius: 10,
          emojiFontSize: 26,
          fallbackIconColor: AppColors.brand,
        ),
      ),
      title: group.name,
      subtitles: [?status, ...lines],
      trailing: trailing,
      onTap: onTap,
      showDivider: showDivider,
      semanticsLabel: [group.name, ?status, ...lines].join(', '),
    );
  }
}
