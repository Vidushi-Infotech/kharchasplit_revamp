import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/group_model.dart';
import '../state/group_detail_provider.dart';
import '../state/group_lifecycle_controller.dart';
import 'group_archived_banner.dart';

/// Popup-menu values for the archive / complete entries in the group's ⋮
/// menu. Kept here so the top bar only forwards the selection.
abstract final class GroupLifecycleMenu {
  static const archive = 'lifecycle_archive';
  static const unarchive = 'lifecycle_unarchive';
  static const complete = 'lifecycle_complete';

  static bool handles(String value) =>
      value == archive || value == unarchive || value == complete;
}

/// Admin-only menu entries for [group]:
///   * active    → Archive group, Mark as complete
///   * archived  → Unarchive group, Mark as complete
///   * completed → Unarchive group
List<PopupMenuEntry<String>> buildGroupLifecycleMenuItems(
  bool isDark,
  GroupModel group,
) {
  PopupMenuItem<String> item(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );

  return [
    if (group.isArchived)
      item(
        GroupLifecycleMenu.unarchive,
        Icons.unarchive_outlined,
        AppStrings.unarchiveGroup,
      )
    else
      item(
        GroupLifecycleMenu.archive,
        Icons.archive_outlined,
        AppStrings.archiveGroup,
      ),
    if (!group.isCompleted)
      item(
        GroupLifecycleMenu.complete,
        Icons.task_alt_rounded,
        AppStrings.markComplete,
      ),
  ];
}

/// Archived / completed banner for the detail headers, with [bottomGap]
/// below it. Collapses to nothing for an active group.
Widget buildGroupArchivedBanner(
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
  bool isAdmin, {
  double bottomGap = 14,
}) {
  if (!detail.group.isArchived) return const SizedBox.shrink();
  return Padding(
    padding: EdgeInsets.only(bottom: bottomGap),
    child: GroupArchivedBanner(
      group: detail.group,
      isAdmin: isAdmin,
      onUnarchive: () => unarchiveGroup(context, ref, detail.group.id),
    ),
  );
}

/// Dispatches a [GroupLifecycleMenu] value picked from the ⋮ menu.
Future<void> handleGroupLifecycleAction(
  String value,
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
) {
  switch (value) {
    case GroupLifecycleMenu.archive:
      return confirmArchiveGroup(context, ref, detail);
    case GroupLifecycleMenu.unarchive:
      return unarchiveGroup(context, ref, detail.group.id);
    case GroupLifecycleMenu.complete:
      return confirmCompleteGroup(context, ref, detail);
  }
  return Future.value();
}

Future<void> confirmArchiveGroup(
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
) async {
  final open = groupOpenAmount(detail);
  final go = await _confirm(
    context,
    title: '${AppStrings.archiveGroup}?',
    message: open > 0.01
        ? AppStrings.archiveWithOpenBalance(CurrencyFormatter.format(open))
        : 'Archiving hides the group and stops new expenses. You can '
              'unarchive it any time.',
    action: 'Archive',
  );
  if (go != true || !context.mounted) return;
  await _run(
    context,
    () => ref.read(groupLifecycleControllerProvider).archive(detail.group.id),
    success: 'Group archived',
  );
}

Future<void> unarchiveGroup(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) {
  return _run(
    context,
    () => ref.read(groupLifecycleControllerProvider).unarchive(groupId),
    success: 'Group unarchived',
  );
}

Future<void> confirmCompleteGroup(
  BuildContext context,
  WidgetRef ref,
  GroupDetail detail,
) async {
  final open = groupOpenAmount(detail);
  if (open > 0.01) {
    return showSettleUpFirstDialog(context, detail.group.id, open);
  }
  final go = await _confirm(
    context,
    title: '${AppStrings.markComplete}?',
    message:
        'Everyone is settled up. Completing archives the group so no new '
        'expenses can be added. You can unarchive it later.',
    action: 'Complete',
  );
  if (go != true || !context.mounted) return;
  try {
    await ref.read(groupLifecycleControllerProvider).complete(detail.group.id);
    if (!context.mounted) return;
    HapticService.instance.success();
    _snack(context, 'Group marked as complete');
  } on GroupNotSettledException catch (e) {
    if (!context.mounted) return;
    await showSettleUpFirstDialog(context, detail.group.id, e.openAmount);
  } catch (e) {
    if (!context.mounted) return;
    _snack(context, _message(e));
  }
}

/// "Settle up first" — the group can't be completed while [openAmount] is
/// still owed. Offers a jump to the Balances page.
Future<void> showSettleUpFirstDialog(
  BuildContext context,
  String groupId,
  double openAmount,
) async {
  final goToBalances = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.settleUpFirst),
      content: Text(
        AppStrings.completeNeedsSettle(CurrencyFormatter.format(openAmount)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('View balances'),
        ),
      ],
    ),
  );
  if (goToBalances == true && context.mounted) {
    context.push('/home/groups/$groupId/balances');
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() call, {
  required String success,
}) async {
  try {
    await call();
    if (!context.mounted) return;
    HapticService.instance.success();
    _snack(context, success);
  } catch (e) {
    if (!context.mounted) return;
    HapticService.instance.error();
    _snack(context, _message(e));
  }
}

String _message(Object e) =>
    e is GroupsApiException ? e.message : 'Something went wrong: $e';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
