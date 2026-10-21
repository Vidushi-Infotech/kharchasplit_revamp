import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/friends_provider.dart';
import 'friend_balance_label.dart';

/// Bottom sheet listing [groups] with their balance; resolves to the picked
/// group, or `null` if dismissed. Used when a Settle up / Remind action
/// spans more than one group.
Future<FriendGroupBalance?> showFriendGroupPicker(
  BuildContext context, {
  required String title,
  required List<FriendGroupBalance> groups,
}) {
  return showModalBottomSheet<FriendGroupBalance>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: AppTextStyles.headline3(isDark)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final amount = formatFriendAmount(g.net, g.currency);
                    return ListTile(
                      leading: Icon(
                        g.isDirect
                            ? Icons.person_outline_rounded
                            : Icons.group_outlined,
                        color: AppColors.textSecondary(isDark),
                      ),
                      title: Text(
                        g.isDirect ? AppStrings.nonGroupExpenses : g.groupName,
                      ),
                      trailing: Text(
                        amount,
                        style: AppTextStyles.body1(isDark).copyWith(
                          color: friendBalanceColor(g.net, isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(g),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
