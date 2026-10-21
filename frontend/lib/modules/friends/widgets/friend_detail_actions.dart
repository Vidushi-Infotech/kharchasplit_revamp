import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/groups/groups_repository.dart';
import '../state/friend_detail_provider.dart';
import '../state/friends_provider.dart';
import 'friend_group_picker_sheet.dart';

/// Settle up (primary, when you owe them in some group) and Remind
/// (secondary, when they owe you in some group). Multi-group balances ask
/// which group first. With the `settleAll` flag, owing them overall across
/// several groups makes "Settle all balances" the primary action and the
/// per-group Settle up secondary. Renders nothing when everything is
/// settled.
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
    // "Settle all balances" (flag `settleAll`): one per currency you owe in
    // overall across 2+ groups. Per-group Settle up then becomes secondary.
    final settleAllCurrencies = watchFeature(ref, 'settleAll')
        ? widget.friend.settleAllCurrencies
        : const <String>[];
    final multiCurrency = widget.friend.netByCurrency.length > 1;

    final buttons = <Widget>[
      for (final currency in settleAllCurrencies)
        _primary(
          label: multiCurrency
              ? AppStrings.settleAllBalancesIn(currency)
              : AppStrings.settleAllBalances,
          semantics: '${AppStrings.settleAllBalances} with $name, $currency',
          icon: Icons.done_all_rounded,
          onPressed: () => context.push(
            '/settle-all/${widget.friend.user.id}?currency=$currency',
          ),
        ),
      if (settleGroups.isNotEmpty)
        settleAllCurrencies.isEmpty
            ? _primary(
                label: AppStrings.settleUp,
                semantics: '${AppStrings.settleUp} with $name',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => _settle(settleGroups),
              )
            : _secondary(
                isDark,
                label: AppStrings.settleUpOneGroup,
                semantics: '${AppStrings.settleUpOneGroup} with $name',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => _settle(settleGroups),
              ),
      if (remindGroups.isNotEmpty)
        _secondary(
          isDark,
          label: AppStrings.remind,
          semantics: '${AppStrings.remind} $name',
          icon: Icons.notifications_none_rounded,
          onPressed: _reminding ? null : () => _remind(remindGroups),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }

  Widget _primary({
    required String label,
    required String semantics,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }

  Widget _secondary(
    bool isDark, {
    required String label,
    required String semantics,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary(isDark),
          side: BorderSide(color: AppColors.divider(isDark)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
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
