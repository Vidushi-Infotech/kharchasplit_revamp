import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../data/groups/groups_repository.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';
import 'friend_group_picker_sheet.dart';

/// Action chips under the friend's balance: Settle up (orange, when you owe
/// them in some group) and Remind… (when they owe you in some group).
/// Multi-group balances ask which group first. With the `settleAll` flag,
/// owing them overall across several groups makes "Settle all balances"
/// the orange chip and "Settle up one group" a plain one. Nothing to show
/// when everything is settled — Add expense is the floating button.
class FriendDetailActions extends ConsumerStatefulWidget {
  const FriendDetailActions({super.key, required this.friend});

  final FriendBalance friend;

  @override
  ConsumerState<FriendDetailActions> createState() =>
      _FriendDetailActionsState();
}

class _FriendDetailActionsState extends ConsumerState<FriendDetailActions> {
  // Local UI flag only — ignores Remind taps while the request is in flight.
  bool _reminding = false;

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final settleGroups = friend.groupsYouOwe;
    final remindGroups = friend.groupsOwingYou;
    // "Settle all balances" (flag `settleAll`): one per currency you owe in
    // overall across 2+ groups. Per-group Settle up then becomes secondary.
    final settleAllCurrencies = watchFeature(ref, 'settleAll')
        ? friend.settleAllCurrencies
        : const <String>[];
    final multiCurrency = friend.netByCurrency.length > 1;

    final items = <ActionChipItem>[
      for (final currency in settleAllCurrencies)
        ActionChipItem(
          label: multiCurrency
              ? AppStrings.settleAllBalancesIn(currency)
              : AppStrings.settleAllBalances,
          icon: Icons.done_all_rounded,
          primary: true,
          onTap: () => context.push(
            '/settle-all/${friend.user.id}?currency=$currency',
          ),
        ),
      if (settleGroups.isNotEmpty)
        ActionChipItem(
          label: settleAllCurrencies.isEmpty
              ? AppStrings.settleUp
              : AppStrings.settleUpOneGroup,
          primary: settleAllCurrencies.isEmpty,
          onTap: () => _settle(settleGroups),
        ),
      if (remindGroups.isNotEmpty)
        ActionChipItem(
          label: AppStrings.remindEllipsis,
          icon: Icons.notifications_none_rounded,
          onTap: () => _remind(remindGroups),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ActionChipBar(items: items),
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
    if (_reminding) return;
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
