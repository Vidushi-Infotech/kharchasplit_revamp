import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_split_math.dart';
import '../state/add_expense_validation.dart';
import '../state/split_summary_text.dart';
import 'split_adjustment_breakdown.dart';
import 'split_breakdown_widget.dart';
import 'split_default_hint.dart';
import 'split_people_toggle.dart';
import 'split_selector_widget.dart';
import 'split_summary_bar.dart';

/// "Split options": a full-height sheet with the five split methods as
/// icon tabs, the per-person editor for the picked one and a summary bar
/// ("₹500.00/person (2 people)", "₹300.00 of ₹500.00 — ₹200.00 left").
/// [context] and [ref] are the Add-expense screen's own.
void showSplitSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required List<UserModel> groupMembers,
}) {
  if (groupMembers.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No group selected.')));
    return;
  }
  showModalBottomSheet(
    context: context,
    // Above the floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _SplitOptionsView(isDark: isDark, members: groupMembers),
  );
}

class _SplitOptionsView extends ConsumerWidget {
  const _SplitOptionsView({required this.isDark, required this.members});

  final bool isDark;
  final List<UserModel> members;

  static const _heads = {
    AddExpenseSplitMode.equal: AppStrings.splitHeadEqually,
    AddExpenseSplitMode.exact: AppStrings.splitHeadExact,
    AddExpenseSplitMode.percentage: AppStrings.splitHeadPercent,
    AddExpenseSplitMode.shares: AppStrings.splitHeadShares,
    AddExpenseSplitMode.adjustment: AppStrings.splitHeadAdjustment,
  };
  static const _descriptions = {
    AddExpenseSplitMode.equal: AppStrings.splitDescEqually,
    AddExpenseSplitMode.exact: AppStrings.splitDescExact,
    AddExpenseSplitMode.percentage: AppStrings.splitDescPercent,
    AddExpenseSplitMode.shares: AppStrings.splitDescShares,
    AddExpenseSplitMode.adjustment: AppStrings.adjustmentHint,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(addExpenseProvider);
    final notifier = ref.read(addExpenseProvider.notifier);
    final myId = ref.watch(myIdProvider);
    final memberIds = members.map((m) => m.id).toSet();
    final mode = s.splitMode;
    // Empty = everyone, except for "By adjustment" (empty = nobody).
    final inSplit = s.includedMemberIds.isEmpty
        ? (mode == AddExpenseSplitMode.adjustment ? <String>{} : memberIds)
        : s.includedMemberIds.intersection(memberIds);
    final assigned = s.splits.entries
        .where((e) => inSplit.contains(e.key))
        .fold<double>(0, (t, e) => t + e.value);
    final summary = splitOptionsSummary(
      mode: mode,
      amount: s.amount,
      currency: s.currency,
      people: inSplit.length,
      assigned: assigned,
    );
    // A DraggableScrollableSheet-free full-height sheet doesn't resize for
    // the keyboard either: pad by its height so the summary bar sits on
    // top of it and a focused amount field can scroll into view.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          children: [
            _Header(isDark: isDark, canClose: s.isSplitValid),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SplitSelectorWidget(
                      mode: mode,
                      onModeChanged: (m) => notifier.state =
                          addExpenseSwitchSplitMode(notifier.state, m, memberIds),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _heads[mode]!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descriptions[mode]!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: AppColors.textSecondary(isDark)),
                    ),
                    if (s.usingGroupDefaultSplit)
                      SplitDefaultHint(
                        onSplitEqually: () => notifier.state =
                            addExpenseSplitEquallyForAll(notifier.state),
                      ),
                    const SizedBox(height: 8),
                    if (mode == AddExpenseSplitMode.adjustment)
                      SplitAdjustmentBreakdown(
                        totalAmount: s.amount,
                        members: members,
                        adjustments: s.adjustments,
                        includedMemberIds: s.includedMemberIds,
                        currentUserId: myId,
                        currency: s.currency,
                        onAdjustmentsChanged: (a) => notifier.state = notifier
                            .state
                            .copyWith(adjustments: a),
                        onIncludedMembersChanged: (ids) => notifier.state =
                            notifier.state.copyWith(includedMemberIds: ids),
                      )
                    else ...[
                      SplitPeopleToggle(
                        members: members,
                        includedMemberIds: s.includedMemberIds,
                      ),
                      SplitBreakdownWidget(
                        splitType: s.splitType,
                        totalAmount: s.amount,
                        members: members,
                        splits: s.splits,
                        includedMemberIds: s.includedMemberIds,
                        currentUserId: myId,
                        currency: s.currency,
                        // Read the live state, not the captured `s`: a
                        // toggle fires onIncludedMembersChanged right
                        // before this, and the stale `s` would undo it.
                        onSplitsChanged: (splits) => notifier.state = notifier
                            .state
                            .copyWith(splits: splits),
                        onIncludedMembersChanged: (included) =>
                            notifier.state = notifier.state.copyWith(
                              includedMemberIds: included,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SplitSummaryBar(
              isDark: isDark,
              summary: summary,
              allSelected: mode == AddExpenseSplitMode.equal
                  ? inSplit.length == memberIds.length
                  : null,
              // "Nobody" can't be stored for an equal split (empty means
              // everyone), so unticking All keeps just you; tick the
              // others from there.
              onAllChanged: (all) {
                HapticService.instance.selection();
                final mine = myId != null && memberIds.contains(myId)
                    ? myId
                    : members.first.id;
                notifier.state = notifier.state.copyWith(
                  includedMemberIds: all ? memberIds : {mine},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "←  Split options  Done". Done stays disabled until the split adds up,
/// so an invalid split isn't left behind by accident; the summary bar says
/// what's off.
class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.canClose});

  final bool isDark;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider(isDark), width: 0.6),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          Expanded(
            child: Text(
              AppStrings.splitOptions,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: canClose
                ? () {
                    HapticService.instance.success();
                    Navigator.pop(context);
                  }
                : null,
            style: TextButton.styleFrom(foregroundColor: AppColors.tealDark),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
