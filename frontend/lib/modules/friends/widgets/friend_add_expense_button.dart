import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_provider.dart';
import '../state/friend_detail_view.dart';
import '../state/friends_provider.dart';

/// How [FriendAddExpenseButton] looks.
enum FriendAddExpenseStyle {
  /// Extended floating button (phones and tablets), as on group detail.
  fab,

  /// Filled pill, for the empty state and the desktop list header.
  pill,
}

/// "Add expense" with this friend, outside any group: gets (or creates) the
/// hidden non-group group, opens the normal add-expense screen for it, and
/// refreshes balances + shared expenses on return.
class FriendAddExpenseButton extends ConsumerStatefulWidget {
  const FriendAddExpenseButton({
    super.key,
    required this.friend,
    this.style = FriendAddExpenseStyle.fab,
  });

  final FriendBalance friend;
  final FriendAddExpenseStyle style;

  @override
  ConsumerState<FriendAddExpenseButton> createState() =>
      _FriendAddExpenseButtonState();
}

class _FriendAddExpenseButtonState
    extends ConsumerState<FriendAddExpenseButton> {
  // Local UI flag only — spinner while the group id is fetched.
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    final friendId = widget.friend.user.id;
    final actions = ref.read(friendActionsProvider);
    setState(() => _opening = true);
    String groupId;
    try {
      groupId = await actions.directGroupFor(
        friendId,
        knownId: widget.friend.directGroupId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.couldNotOpenNonGroup('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    await context.push('/add-expense/$groupId');
    // The friend's balances and the expense list; the actions provider
    // outlives this widget, so refresh even if we were disposed meanwhile.
    try {
      await actions.refresh(friendId);
    } catch (_) {
      // The detail screen's error branch shows a failed refetch.
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _opening
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.receipt_long_rounded);
    final label =
        '${AppStrings.addExpense} with ${friendDisplayName(widget.friend.user.name)}';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: _open,
      child: switch (widget.style) {
        FriendAddExpenseStyle.fab => FloatingActionButton.extended(
            heroTag: null,
            onPressed: _open,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            icon: icon,
            label: const Text(AppStrings.addExpense),
          ),
        FriendAddExpenseStyle.pill => FilledButton.icon(
            onPressed: _open,
            icon: icon,
            label: const Text(AppStrings.addExpense),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
      },
    );
  }
}
