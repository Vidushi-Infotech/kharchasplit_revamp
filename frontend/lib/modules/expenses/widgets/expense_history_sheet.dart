import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/states/empty_state_widget.dart';
import '../../../components/states/error_state_widget.dart';
import '../../../components/web/adaptive_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../../../models/expense_model.dart';
import '../state/expense_detail_provider.dart';
import '../state/expense_history_provider.dart';
import 'expense_history_tile.dart';

/// Opens the edit history of [expense]. [canRestore] = the viewer may edit
/// it (a payer) — only they see "Restore this version".
Future<void> showExpenseHistorySheet(
  BuildContext context, {
  required ExpenseModel expense,
  required bool canRestore,
}) {
  // Refetch the expense so the sheet (and the screen behind it) compare
  // against what's on the server now.
  ProviderScope.containerOf(context).invalidate(expenseDetailProvider(expense.id));
  return showAdaptiveSheet<void>(
    context: context,
    size: AdaptiveSheetSize.large,
    // Above any floating tab bar, whichever shell the screen is in.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        ExpenseHistorySheet(expense: expense, canRestore: canRestore),
  );
}

class ExpenseHistorySheet extends ConsumerWidget {
  const ExpenseHistorySheet({
    super.key,
    required this.expense,
    required this.canRestore,
  });

  final ExpenseModel expense;
  final bool canRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(expenseHistoryProvider(expense.id));
    // Compare the newest version with the expense as it is now on the
    // server, not the copy the screen was opened with (it may be stale if
    // someone else edited it meanwhile).
    final live = ref.watch(expenseDetailProvider(expense.id)).value ?? expense;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: AppColors.background(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.tealDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.editHistory,
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.cancel,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SingleChildScrollView(
                    child: ErrorStateWidget(
                      title: AppStrings.editHistoryLoadFailed,
                      message: '$e',
                      onRetry: () =>
                          ref.invalidate(expenseHistoryProvider(expense.id)),
                    ),
                  ),
                  data: (history) => history.revisions.isEmpty
                      ? const EmptyStateWidget(
                          icon: '🕘',
                          iconSize: 48,
                          title: AppStrings.noEditsYet,
                          subtitle: AppStrings.noEditsYetHint,
                        )
                      : _list(history, live, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(ExpenseHistory history, ExpenseModel live, bool isDark) {
    final current = ExpenseSnapshot.fromExpense(live);
    final payerNames = {for (final p in live.payers) p.userId: p.name};
    final splitNames = {for (final s in live.splits) s.userId: s.userName};
    String nameOf(String id) =>
        history.userNames[id] ??
        payerNames[id] ??
        splitNames[id] ??
        AppStrings.formerMember;

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: history.revisions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final rev = history.revisions[i];
        // Newest first: what replaced revision i is revision i-1, and the
        // newest one was replaced by the live expense.
        final next = i == 0 ? current : history.revisions[i - 1].snapshot;
        return ExpenseHistoryTile(
          key: ValueKey(rev.id),
          revision: rev,
          changes: summarizeRevision(
            version: rev.snapshot,
            next: next,
            nameOf: nameOf,
          ),
          expenseId: expense.id,
          groupId: expense.groupId,
          canRestore: canRestore,
          isDark: isDark,
        );
      },
    );
  }
}
