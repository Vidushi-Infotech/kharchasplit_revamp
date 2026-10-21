import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/group_display.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_archived_notice.dart';

/// Top of the Add/Edit expense form: the archived notice (when the group
/// is archived) and a line saying where the expense goes — "In Goa trip",
/// or "With Priya · Non-group" for the hidden two-person group.
///
/// The group is fixed by the route (or by the expense being edited), so
/// this is a label, not a picker. Paid-by and split only ever offer this
/// group's members — for non-group expenses that's just the two of you.
class AddExpenseGroupContext extends ConsumerWidget {
  const AddExpenseGroupContext({
    super.key,
    required this.isDark,
    required this.archived,
  });

  final bool isDark;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(addExpenseProvider.select((s) => s.groupId));
    final group = id == null
        ? null
        : ref.watch(groupDetailProvider(id)).value?.group;
    final myId = ref.watch(myIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (archived) AddExpenseArchivedNotice(isDark: isDark),
        // Nothing while loading — the line just appears once known.
        if (group != null)
          Semantics(
            label: group.isDirect
                ? '${group.expenseContextLabel(myId)}, '
                      '${AppStrings.nonGroupExpenses}'
                : group.expenseContextLabel(myId),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Icon(
                    group.isDirect
                        ? Icons.person_outline_rounded
                        : Icons.group_outlined,
                    size: 16,
                    color: AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      group.isDirect
                          ? '${group.expenseContextLabel(myId)} · '
                                '${AppStrings.nonGroup}'
                          : group.expenseContextLabel(myId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
