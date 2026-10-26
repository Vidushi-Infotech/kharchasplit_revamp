import 'package:flutter/material.dart';
import '../../../components/system/page_status_bar.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Flat "✕  Add an expense  ✓" app bar of the Add/Edit expense screen (and
/// the Record payment screen). Save lives here: [onSave] runs when the form
/// can be saved; otherwise a tap goes to [onSaveBlocked], which says what's
/// missing. No Save button at all when both are null (loading views).
class AddExpenseTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AddExpenseTopBar({
    super.key,
    required this.title,
    required this.onClose,
    required this.isDark,
    this.onSave,
    this.onSaveBlocked,
    this.saveEnabled = true,
    this.saving = false,
    this.saveLabel = AppStrings.saveLabel,
  });

  final String title;
  final VoidCallback onClose;
  final bool isDark;
  final VoidCallback? onSave;
  final VoidCallback? onSaveBlocked;
  final bool saveEnabled;
  final bool saving;

  /// The button's text; Record a payment uses "Settle up" / "Record".
  final String saveLabel;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final showSave = onSave != null || onSaveBlocked != null;
    final ready = saveEnabled && !saving;
    return PageStatusBar(
      child: Material(
        color: AppColors.background(isDark),
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider(isDark),
                  width: 0.6,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close',
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.body1(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showSave)
                  Semantics(
                    button: true,
                    enabled: ready,
                    label: saving
                        ? AppStrings.savingLabel
                        : saveLabel,
                    excludeSemantics: true,
                    child: saving
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            // Still tappable while not ready: the tap explains
                            // what's missing instead of doing nothing.
                            onPressed: ready ? onSave : onSaveBlocked,
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(saveLabel),
                            style: TextButton.styleFrom(
                              foregroundColor: ready
                                  ? AppColors.tealDark
                                  : AppColors.textSecondary(isDark),
                              textStyle: AppTextStyles.body1(
                                isDark,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
