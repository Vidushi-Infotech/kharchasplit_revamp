import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../modules/friends/state/friend_detail_provider.dart';
import '../../modules/friends/state/friends_provider.dart';
import '../../modules/friends/widgets/friend_balance_label.dart';

/// "Groups" / "Friends" heading inside the ➕ sheet, with an optional hint
/// line under it.
class PickSheetSectionHeader extends StatelessWidget {
  const PickSheetSectionHeader({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The ➕ sheet's Friends section as slivers: a header with the "more than
/// one person? Create a group" hint, then one row per friend. Tapping a
/// friend gets (or creates) the non-group group with them, closes the sheet
/// and opens add-expense for it. Renders nothing when [friends] is empty.
class PickFriendForExpenseSliver extends ConsumerStatefulWidget {
  const PickFriendForExpenseSliver({super.key, required this.friends});

  /// Already filtered by the sheet's search query.
  final List<FriendBalance> friends;

  @override
  ConsumerState<PickFriendForExpenseSliver> createState() =>
      _PickFriendForExpenseSliverState();
}

class _PickFriendForExpenseSliverState
    extends ConsumerState<PickFriendForExpenseSliver> {
  // Local UI state only: the row being opened, and a failure to show under
  // it (a SnackBar would sit behind the modal sheet).
  String? _openingId;
  String? _errorId;
  String? _error;

  Future<void> _open(FriendBalance friend) async {
    if (_openingId != null) return;
    HapticService.instance.tap();
    final friendId = friend.user.id;
    final actions = ref.read(friendActionsProvider);
    setState(() {
      _openingId = friendId;
      _errorId = null;
      _error = null;
    });
    String groupId;
    try {
      groupId = await actions.directGroupFor(
        friendId,
        knownId: friend.directGroupId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingId = null;
        _errorId = friendId;
        _error = AppStrings.couldNotOpenNonGroup('$e');
      });
      return;
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    await router.pushNamed(
      'add-expense-to-group',
      pathParameters: {'groupId': groupId},
    );
    // The sheet is gone; the actions provider isn't.
    try {
      await actions.refresh(friendId);
    } catch (_) {
      // The Friends tab shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friends = widget.friends;
    if (friends.isEmpty) return const SliverToBoxAdapter();

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: PickSheetSectionHeader(
            title: AppStrings.friends,
            hint: AppStrings.splitWithMoreCreateGroup,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          sliver: SliverList.builder(
            itemCount: friends.length,
            itemBuilder: (context, i) {
              final f = friends[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FriendRow(
                  friend: f,
                  isDark: isDark,
                  opening: _openingId == f.user.id,
                  error: _errorId == f.user.id ? _error : null,
                  onTap: () => _open(f),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.isDark,
    required this.opening,
    required this.error,
    required this.onTap,
  });

  final FriendBalance friend;
  final bool isDark;
  final bool opening;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = friend.user;
    return Semantics(
      button: true,
      label: '${AppStrings.addExpense} with ${user.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: opening ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AvatarWidget(
                      imageUrl: user.avatarUrl,
                      name: user.name,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (opening)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      FriendBalanceLabel(friend: friend),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error!,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: AppColors.errorText(isDark)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
