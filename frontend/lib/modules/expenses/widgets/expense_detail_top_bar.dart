import 'package:flutter/material.dart';
import '../../../components/system/page_status_bar.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// "←  … 🗑 ✏️ ⋮" app bar of the expense detail screen. Delete and Edit
/// only for the expense's payers (server rule — anyone else gets 403);
/// the ⋮ menu (edit history, open to every member) once it's loaded.
class ExpenseDetailTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ExpenseDetailTopBar({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.canEdit,
    this.onDelete,
    this.onEdit,
    this.onHistory,
  });

  final bool isDark;
  final VoidCallback onBack;
  final bool canEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  /// Null hides the ⋮ menu (expense not loaded yet).
  final VoidCallback? onHistory;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.textPrimary(isDark);
    return PageStatusBar(
      child: Material(
        color: AppColors.background(isDark),
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back_rounded, color: iconColor),
                ),
                const Spacer(),
                const DonateHeartButton(),
                if (canEdit && onDelete != null)
                  IconButton(
                    tooltip: AppStrings.deleteLabel,
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: iconColor),
                  ),
                if (canEdit && onEdit != null)
                  IconButton(
                    tooltip: AppStrings.editExpense,
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, color: iconColor),
                  ),
                if (onHistory != null)
                  PopupMenuButton<String>(
                    tooltip: AppStrings.moreOptions,
                    icon: Icon(Icons.more_vert_rounded, color: iconColor),
                    color: AppColors.cardBg(isDark),
                    onSelected: (v) {
                      if (v == 'history') onHistory!();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'history',
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: iconColor,
                            ),
                            const SizedBox(width: 10),
                            const Text(AppStrings.editHistory),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
