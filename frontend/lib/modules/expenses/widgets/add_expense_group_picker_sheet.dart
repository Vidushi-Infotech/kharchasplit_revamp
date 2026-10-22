import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../../friends/state/friend_detail_provider.dart';
import '../../friends/state/friends_provider.dart';
import '../../groups/state/groups_provider.dart';
import 'add_expense_sheet_header.dart';

/// "Add expense to" sheet behind the "With you and:" chip of a new expense:
/// the user's groups, then their friends (a friend = the hidden non-group
/// group with them, created on first use). [onPicked] gets the group id;
/// the sheet closes itself.
void showAddExpenseGroupPicker(
  BuildContext context, {
  required bool isDark,
  required String? currentGroupId,
  required ValueChanged<String> onPicked,
}) {
  showModalBottomSheet(
    context: context,
    // Above the floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
      child: _PickerBody(
        isDark: isDark,
        currentGroupId: currentGroupId,
        onPicked: (id) {
          Navigator.pop(ctx);
          onPicked(id);
        },
      ),
    ),
  );
}

class _PickerBody extends ConsumerStatefulWidget {
  const _PickerBody({
    required this.isDark,
    required this.currentGroupId,
    required this.onPicked,
  });

  final bool isDark;
  final String? currentGroupId;
  final ValueChanged<String> onPicked;

  @override
  ConsumerState<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends ConsumerState<_PickerBody> {
  // Local UI state only: the friend row being opened and its error (a
  // SnackBar would sit behind the sheet).
  String? _openingId;
  String? _error;

  Future<void> _pickFriend(FriendBalance friend) async {
    if (_openingId != null) return;
    HapticService.instance.tap();
    setState(() {
      _openingId = friend.user.id;
      _error = null;
    });
    try {
      final id = await ref
          .read(friendActionsProvider)
          .directGroupFor(friend.user.id, knownId: friend.directGroupId);
      if (mounted) widget.onPicked(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingId = null;
        _error = AppStrings.couldNotOpenNonGroup('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final groups = (ref.watch(groupsProvider).value ?? const <GroupModel>[])
        .where((g) => !g.isArchived && !g.isDirect)
        .toList();
    final friends =
        ref.watch(friendsProvider).value ?? const <FriendBalance>[];
    // Flat item list: [header, groups…, header, friends…].
    final items = <Object>[
      if (groups.isNotEmpty) AppStrings.groups,
      ...groups,
      if (friends.isNotEmpty) AppStrings.friends,
      ...friends,
    ];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AddExpenseSheetHandle(isDark: isDark),
          AddExpenseSheetTitle(text: AppStrings.addExpenseTo, isDark: isDark),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _error!,
                style: AppTextStyles.caption(
                  isDark,
                ).copyWith(color: AppColors.errorText(isDark)),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is String) return _Header(item, isDark: isDark);
                  if (item is GroupModel) {
                    return KsListRow(
                      dense: true,
                      leading: CategoryTile(
                        icon: Icons.group_rounded,
                        color: AppColors.tealDark,
                        size: 40,
                      ),
                      title: item.name,
                      trailing: item.id == widget.currentGroupId
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.tealDark,
                            )
                          : null,
                      onTap: () {
                        HapticService.instance.tap();
                        widget.onPicked(item.id);
                      },
                    );
                  }
                  final f = item as FriendBalance;
                  final opening = _openingId == f.user.id;
                  return KsListRow(
                    dense: true,
                    leading: AvatarWidget(
                      name: f.user.name,
                      imageUrl: f.user.avatarUrl,
                    ),
                    title: f.user.name,
                    trailing: opening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (f.directGroupId != null &&
                              f.directGroupId == widget.currentGroupId)
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.tealDark,
                          )
                        : null,
                    onTap: () => _pickFriend(f),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
