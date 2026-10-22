import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_sentence.dart';
import 'add_expense_archived_notice.dart';

/// Top of the Add/Edit expense form: the archived notice (when the group
/// is archived) and "With you and: [Goa trip ▾]" — the group, or the friend
/// for the hidden two-person group.
///
/// [onPick] opens the group/friend picker (new expenses only); null when
/// editing, since an expense can't move to another group.
class AddExpenseGroupContext extends ConsumerWidget {
  const AddExpenseGroupContext({
    super.key,
    required this.isDark,
    required this.archived,
    this.onPick,
  });

  final bool isDark;
  final bool archived;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(addExpenseProvider.select((s) => s.groupId));
    final group = id == null
        ? null
        : ref.watch(groupDetailProvider(id)).value?.group;
    final myId = ref.watch(myIdProvider);
    final String? label = group == null
        ? (id == null ? null : '…')
        : addExpenseGroupLabel(group, myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (archived) AddExpenseArchivedNotice(isDark: isDark),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                AppStrings.withYouAnd,
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              _GroupChip(
                isDark: isDark,
                label: label ?? AppStrings.chooseGroupOrFriend,
                isDirect: group?.isDirect ?? false,
                placeholder: label == null,
                onTap: onPick,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.isDark,
    required this.label,
    required this.isDirect,
    required this.placeholder,
    required this.onTap,
  });

  final bool isDark;
  final String label;
  final bool isDirect;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = placeholder
        ? AppColors.tealDark
        : AppColors.textPrimary(isDark);
    return Semantics(
      button: onTap != null,
      label: '${AppStrings.withYouAnd} $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface(isDark),
        shape: StadiumBorder(
          side: BorderSide(
            color: placeholder
                ? AppColors.tealDark
                : AppColors.divider(isDark),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDirect
                      ? Icons.person_outline_rounded
                      : Icons.group_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body2(
                      isDark,
                    ).copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
