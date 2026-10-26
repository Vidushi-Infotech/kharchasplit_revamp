import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/group_model.dart';
import '../../../core/services/haptic_service.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';
import 'edit_group_sheet.dart';

/// Open the bottom sheet for editing the group's name + cover photo.
/// Admin-only at the call site; backend also enforces. Refreshes the
/// detail provider on save so the header re-renders with new data.
Future<void> openEditGroupSheet(
  BuildContext context,
  WidgetRef ref,
  GroupModel group,
) async {
  final updated = await EditGroupSheet.show(context, group: group);
  if (updated == null || !context.mounted) return;
  ref.invalidate(groupDetailProvider(group.id));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Group updated'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> confirmLeaveGroup(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  String? myId,
) async {
  if (myId == null) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave group?'),
      content: const Text(
        "You can only leave once you've settled all balances with other members.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  try {
    await ref
        .read(groupsRepositoryProvider)
        .leave(groupId: groupId, userId: myId);
    ref.invalidate(groupsProvider);
    ref.invalidate(groupDetailProvider(groupId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Left the group.')));
    context.go('/home/groups');
  } on GroupsApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not leave: $e')));
  }
}

/// Download the group's .xlsx ledger and hand it to the OS share sheet so
/// the user can save it anywhere (Drive, email, WhatsApp, Files…).
///
/// Flow:
///   1. Show a non-dismissible spinner so the user knows work is happening.
///   2. Fetch bytes from `/groups/:id/export` via the repository.
///   3. Write bytes to a temp file in the platform temp dir (Android/iOS
///      both support this; the OS reaps the file on its own schedule).
///   4. Dismiss the spinner and call `Share.shareXFiles` so the user picks
///      a destination.
///
/// Errors at any step surface as a snackbar — never crash, never silently
/// fail.
Future<void> exportGroup(
  String groupId,
  BuildContext context,
  WidgetRef ref,
  GroupModel group,
) async {
  HapticService.instance.selection();

  // 1. Spinner
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // 2. Download
    final result = await ref
        .read(groupsRepositoryProvider)
        .exportGroup(groupId);

    // 3. Write to temp
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${result.filename}');
    await file.writeAsBytes(result.bytes, flush: true);

    // 4. Dismiss spinner + share
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'KharchaSplit: ${group.name} ledger',
        text: 'Group ledger for "${group.name}", exported from KharchaSplit.',
      ),
    );
  } on GroupsApiException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not export: $e')));
  }
}

Future<void> confirmDeleteGroup(
  String groupId,
  BuildContext context,
  WidgetRef ref,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete group?'),
      content: const Text(
        'This permanently deletes the group for everyone. All expenses must already be settled.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.errorText(
              Theme.of(ctx).brightness == Brightness.dark,
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  HapticService.instance.destructive();
  try {
    await ref.read(groupsRepositoryProvider).delete(groupId);
    ref.invalidate(groupsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group deleted.')));
    context.go('/home/groups');
  } on GroupsApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
  }
}
