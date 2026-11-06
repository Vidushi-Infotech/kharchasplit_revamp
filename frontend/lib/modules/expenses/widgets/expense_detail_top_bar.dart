import 'package:flutter/material.dart';
import '../../../components/system/page_status_bar.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/buttons/glass_icon_button.dart';
import '../../../components/buttons/glass_menu_button.dart';
import '../../../core/constants/app_strings.dart';
import '../../../components/menus/glass_menu.dart';
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
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  sfSymbol: 'chevron.left',
                  tooltip: 'Back',
                  color: iconColor,
                  onPressed: onBack,
                ),
                const Spacer(),
                const DonateHeartButton(),
                if (canEdit && onDelete != null) ...[
                  const GlassGap(),
                  GlassIconButton(
                    icon: Icons.delete_outline_rounded,
                    sfSymbol: 'trash',
                    tooltip: AppStrings.deleteLabel,
                    color: iconColor,
                    onPressed: onDelete,
                  ),
                ],
                if (canEdit && onEdit != null) ...[
                  const GlassGap(),
                  GlassIconButton(
                    icon: Icons.edit_outlined,
                    sfSymbol: 'pencil',
                    tooltip: AppStrings.editExpense,
                    color: iconColor,
                    onPressed: onEdit,
                  ),
                ],
                if (onHistory != null) const GlassGap(),
                if (onHistory != null)
                  GlassMenuButton<String>(
                    glassItems: const [
                      GlassMenuItem(
                        value: 'history',
                        label: AppStrings.editHistory,
                        icon: Icons.history_rounded,
                      ),
                    ],
                    menu: PopupMenuButton<String>(
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
                  ),
                const SizedBox(width: 4),
                const GlassGap(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
