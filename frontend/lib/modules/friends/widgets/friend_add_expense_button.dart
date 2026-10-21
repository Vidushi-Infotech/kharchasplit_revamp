import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';

/// "Add expense" with this friend, outside any group: gets (or creates) the
/// hidden non-group group, opens the normal add-expense screen for it, and
/// refreshes balances + shared expenses on return.
///
/// [prominent] = filled brand button (nothing else to do with this friend);
/// otherwise a tonal one, so it doesn't compete with a filled Settle up.
class FriendAddExpenseButton extends ConsumerStatefulWidget {
  const FriendAddExpenseButton({
    super.key,
    required this.friend,
    this.prominent = true,
  });

  final FriendBalance friend;
  final bool prominent;

  @override
  ConsumerState<FriendAddExpenseButton> createState() =>
      _FriendAddExpenseButtonState();
}

class _FriendAddExpenseButtonState
    extends ConsumerState<FriendAddExpenseButton> {
  // Local UI flag only — spinner while the group id is fetched.
  bool _opening = false;

  Future<void> _open() async {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = _opening
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.prominent ? Colors.white : AppColors.brand,
            ),
          )
        : const Icon(Icons.receipt_long_rounded);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Semantics(
      button: true,
      label: '${AppStrings.addExpense} with ${widget.friend.user.name}',
      child: widget.prominent
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: shape,
              ),
              icon: icon,
              label: const Text(AppStrings.addExpense),
              onPressed: _opening ? null : _open,
            )
          : FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand.withValues(
                  alpha: isDark ? 0.22 : 0.12,
                ),
                foregroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: shape,
              ),
              icon: icon,
              label: const Text(AppStrings.addExpense),
              onPressed: _opening ? null : _open,
            ),
    );
  }
}
