import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../state/add_expense_form_helpers.dart';

/// "Everyone except Ravi" line for the split sheet, with optional All / None
/// buttons: tap None, then tick the few who are in — or All, then untick
/// the few who aren't.
class SplitPeopleToggle extends StatelessWidget {
  const SplitPeopleToggle({
    super.key,
    required this.members,
    required this.includedMemberIds,
    this.onChanged,
  });

  final List<UserModel> members;
  final Set<String> includedMemberIds;

  /// Null hides the All / None buttons (the breakdown has its own).
  final ValueChanged<Set<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onChanged = this.onChanged;
    final summary = addExpenseWhoIsIn(
      members,
      includedMemberIds,
      emptyMeansNobody: onChanged != null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.group_outlined,
            size: 16,
            color: AppColors.textSecondary(isDark),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (onChanged != null) ...[
            TextButton(
              onPressed: () {
                HapticService.instance.selection();
                onChanged(members.map((m) => m.id).toSet());
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text(AppStrings.selectAllPeople),
            ),
            TextButton(
              onPressed: () {
                HapticService.instance.selection();
                onChanged(<String>{});
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text(AppStrings.selectNoPeople),
            ),
          ],
        ],
      ),
    );
  }
}
