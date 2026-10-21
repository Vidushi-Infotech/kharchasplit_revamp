import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../state/expense_history_provider.dart';

/// One earlier version of an expense: who replaced it and when, what was
/// different, and "Restore this version" for people who can edit.
class ExpenseHistoryTile extends ConsumerStatefulWidget {
  const ExpenseHistoryTile({
    super.key,
    required this.revision,
    required this.changes,
    required this.expenseId,
    required this.groupId,
    required this.canRestore,
    required this.isDark,
  });

  final ExpenseRevision revision;

  /// Field-level lines from [summarizeRevision].
  final List<String> changes;
  final String expenseId;
  final String? groupId;
  final bool canRestore;
  final bool isDark;

  @override
  ConsumerState<ExpenseHistoryTile> createState() => _ExpenseHistoryTileState();
}

class _ExpenseHistoryTileState extends ConsumerState<ExpenseHistoryTile> {
  // Local UI flag only: spinner on the button while the restore runs.
  bool _restoring = false;

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.restoreVersionTitle),
        content: const Text(AppStrings.restoreVersionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.restore),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _restoring = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await ref.read(expenseHistoryControllerProvider).restore(
          expenseId: widget.expenseId,
          revisionId: widget.revision.id,
          groupId: widget.groupId,
        );
    if (error == null) {
      HapticService.instance.success();
      // Back to the refreshed expense.
      if (navigator.canPop()) navigator.pop();
    } else if (mounted) {
      setState(() => _restoring = false);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? AppStrings.versionRestored)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final rev = widget.revision;
    final secondary = AppColors.textSecondary(isDark);
    final editedBy = AppStrings.editedByName(
      rev.editorName ?? AppStrings.formerMember,
      DateFormatter.relativeTime(rev.createdAt),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  editedBy,
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormatter.fullDateTime(rev.createdAt),
            style: AppTextStyles.caption(isDark).copyWith(color: secondary),
          ),
          const SizedBox(height: 10),
          for (final line in widget.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: secondary)),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.canRestore) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _restoring ? null : _restore,
                icon: _restoring
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded, size: 16),
                label: const Text(AppStrings.restoreThisVersion),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tealDark,
                  side: BorderSide(
                    color: AppColors.tealDark.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
