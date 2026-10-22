import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Toolbar pinned under the Add/Edit expense form (rides up with the
/// keyboard): 📅 date | 👥 group … 🔁 repeat · 📷 receipt · 📝 notes.
/// A dot on an icon means that extra is already set.
class AddExpenseBottomBar extends StatelessWidget {
  const AddExpenseBottomBar({
    super.key,
    required this.isDark,
    required this.dateLabel,
    required this.groupLabel,
    required this.maxWidth,
    required this.onDateTap,
    required this.onReceiptTap,
    required this.onNotesTap,
    this.onGroupTap,
    this.onRepeatTap,
    this.hasReceipt = false,
    this.hasNotes = false,
    this.repeatOn = false,
  });

  final bool isDark;
  final String dateLabel;

  /// Group or friend name; null while loading / not picked.
  final String? groupLabel;
  final double maxWidth;
  final VoidCallback onDateTap;
  final VoidCallback onReceiptTap;
  final VoidCallback onNotesTap;

  /// Null when editing (the group is fixed).
  final VoidCallback? onGroupTap;

  /// Null hides Repeat (editing, or the `recurring` flag is off).
  final VoidCallback? onRepeatTap;
  final bool hasReceipt;
  final bool hasNotes;
  final bool repeatOn;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      height: 22,
      color: AppColors.divider(isDark),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.divider(isDark), width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  Flexible(
                    child: _TextAction(
                      icon: Icons.calendar_today_outlined,
                      label: dateLabel,
                      semanticsLabel: AppStrings.dateTapLabel(dateLabel),
                      isDark: isDark,
                      onTap: onDateTap,
                    ),
                  ),
                  divider,
                  Flexible(
                    flex: 2,
                    child: _TextAction(
                      icon: Icons.group_outlined,
                      label: groupLabel ?? AppStrings.chooseGroupOrFriend,
                      semanticsLabel:
                          '${AppStrings.withYouAnd} '
                          '${groupLabel ?? AppStrings.chooseGroupOrFriend}',
                      isDark: isDark,
                      onTap: onGroupTap,
                    ),
                  ),
                  const Spacer(),
                  if (onRepeatTap != null)
                    _IconAction(
                      icon: Icons.event_repeat_rounded,
                      tooltip: AppStrings.repeatRowLabel,
                      isDark: isDark,
                      marked: repeatOn,
                      onTap: onRepeatTap!,
                    ),
                  _IconAction(
                    icon: Icons.photo_camera_outlined,
                    tooltip: AppStrings.addOrScanReceipt,
                    isDark: isDark,
                    marked: hasReceipt,
                    onTap: onReceiptTap,
                  ),
                  _IconAction(
                    icon: Icons.edit_note_rounded,
                    tooltip: AppStrings.addNotesLabel,
                    isDark: isDark,
                    marked: hasNotes,
                    onTap: onNotesTap,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.tealDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: AppColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.marked,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: marked,
        smallSize: 8,
        backgroundColor: AppColors.tealDark,
        child: Icon(
          icon,
          color: marked ? AppColors.tealDark : AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}
