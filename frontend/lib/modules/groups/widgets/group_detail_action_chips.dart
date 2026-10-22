import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/group_member_balances.dart';
import 'export_group_menu.dart';
import 'group_admin_actions.dart';

/// Pushes one of the group's sub-pages (`settings`, `balances`, `totals`,
/// `recurring`).
void openGroupPage(BuildContext context, String groupId, String page) {
  HapticService.instance.selection();
  context.push('/home/groups/$groupId/$page');
}

/// Settle up: straight to the payment screen when you owe exactly one
/// person, otherwise to Balances to pick who.
void settleUpInGroup(BuildContext context, GroupDetail detail, String? myId) {
  final target = singleSettleTarget(detail, myId);
  if (target == null) {
    openGroupPage(context, detail.group.id, 'balances');
    return;
  }
  context.push(
    '/settle/${target.userId}?groupId=${detail.group.id}'
    '&amount=${target.amount.toStringAsFixed(2)}',
  );
}

/// Runs an export picked from the chip's sheet or the ⋮ menu.
Future<void> runGroupExport(
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
  String value,
) {
  if (value == exportExcelMenuValue) {
    return exportGroup(detail.group.id, context, ref, detail.group);
  }
  return handleGroupExportMenuValue(context, value, groupId: detail.group.id);
}

/// Settle up · Balances · Totals · Export · Recurring under the header.
class GroupDetailActionChips extends ConsumerWidget {
  const GroupDetailActionChips({super.key, required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myIdProvider);
    final groupId = detail.group.id;
    final recurring = watchFeature(ref, 'recurring');
    return ActionChipBar(
      items: [
        ActionChipItem(
          label: AppStrings.settleUp,
          primary: true,
          onTap: () => settleUpInGroup(context, detail, myId),
        ),
        ActionChipItem(
          label: AppStrings.balances,
          onTap: () => openGroupPage(context, groupId, 'balances'),
        ),
        ActionChipItem(
          label: AppStrings.totals,
          onTap: () => openGroupPage(context, groupId, 'totals'),
        ),
        ActionChipItem(
          label: AppStrings.groupExport,
          onTap: () async {
            final value = await showGroupExportSheet(context);
            if (value == null || !context.mounted) return;
            await runGroupExport(context, ref, detail, value);
          },
        ),
        if (recurring)
          ActionChipItem(
            label: AppStrings.groupRecurring,
            onTap: () => openGroupPage(context, groupId, 'recurring'),
          ),
      ],
    );
  }
}
