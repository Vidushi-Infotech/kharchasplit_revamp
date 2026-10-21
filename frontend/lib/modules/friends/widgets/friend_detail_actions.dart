import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/groups/groups_repository.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';
import 'friend_group_picker_sheet.dart';

/// Settle up (primary, when you owe them in some group) and Remind
/// (secondary, when they owe you in some group). Multi-group balances ask
/// which group first. Renders nothing when everything is settled.
class FriendDetailActions extends ConsumerStatefulWidget {
  const FriendDetailActions({super.key, required this.friend});

  final FriendBalance friend;

  @override
  ConsumerState<FriendDetailActions> createState() =>
      _FriendDetailActionsState();
}

class _FriendDetailActionsState extends ConsumerState<FriendDetailActions> {
  // Local UI flag only — disables Remind while the request is in flight.
  bool _reminding = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settleGroups = widget.friend.groupsYouOwe;
    final remindGroups = widget.friend.groupsOwingYou;
    if (settleGroups.isEmpty && remindGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    final name = widget.friend.user.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (settleGroups.isNotEmpty)
            Semantics(
              button: true,
              label: '${AppStrings.settleUp} with $name',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(AppStrings.settleUp),
                onPressed: () => _settle(settleGroups),
              ),
            ),
          if (settleGroups.isNotEmpty && remindGroups.isNotEmpty)
            const SizedBox(height: 8),
          if (remindGroups.isNotEmpty)
            Semantics(
              button: true,
              label: '${AppStrings.remind} $name',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary(isDark),
                  side: BorderSide(color: AppColors.divider(isDark)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
                label: const Text(AppStrings.remind),
                onPressed: _reminding ? null : () => _remind(remindGroups),
              ),
            ),
        ],
      ),
    );
  }

  Future<FriendGroupBalance?> _pick(
    List<FriendGroupBalance> groups,
    String title,
  ) async {
    if (groups.length == 1) return groups.first;
    return showFriendGroupPicker(context, title: title, groups: groups);
  }

  Future<void> _settle(List<FriendGroupBalance> groups) async {
    final g = await _pick(groups, AppStrings.chooseGroupToSettle);
    if (g == null || !mounted) return;
    final amount = g.net.abs().toStringAsFixed(2);
    context.push(
      '/settle/${widget.friend.user.id}?groupId=${g.groupId}&amount=$amount',
    );
  }

  Future<void> _remind(List<FriendGroupBalance> groups) async {
    final g = await _pick(groups, AppStrings.chooseGroupToRemind);
    if (g == null || !mounted) return;
    setState(() => _reminding = true);
    String message;
    try {
      await ref
          .read(friendActionsProvider)
          .remind(groupId: g.groupId, friendId: widget.friend.user.id);
      message = AppStrings.reminderSent(widget.friend.user.name);
    } on GroupsApiException catch (e) {
      // 429 cooldown (one per 6h), 400 nothing owed… — show it verbatim.
      message = e.message;
    } catch (e) {
      message = 'Could not send reminder: $e';
    }
    if (!mounted) return;
    setState(() => _reminding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
