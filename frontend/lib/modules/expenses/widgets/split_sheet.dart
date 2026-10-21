import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_split_math.dart';
import '../state/add_expense_validation.dart';
import 'add_expense_sheet_header.dart';
import 'split_adjustment_breakdown.dart';
import 'split_breakdown_widget.dart';
import 'split_default_hint.dart';
import 'split_people_toggle.dart';
import 'split_selector_widget.dart';

/// Split-type + per-member breakdown bottom sheet. [context] and [ref] are
/// the Add-expense screen's own.
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
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollController) {
          // Keyboard height. A DraggableScrollableSheet does NOT resize
          // when the keyboard opens (unlike a Scaffold body), so we
          // shrink the scroll viewport by this amount below — that puts
          // the viewport's bottom edge at the keyboard's top, letting
          // Flutter's auto-reveal scroll a focused split-amount field
          // (which lives mid-list) above the keyboard instead of behind
          // it.
          final keyboardInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
          return SafeArea(
            top: false,
            child: Column(
              children: [
                AddExpenseSheetHandle(isDark: isDark),
                AddExpenseSheetTitle(
                  text: 'Split',
                  isDark: isDark,
                  // Done stays disabled until the split adds up correctly,
                  // so the user can't leave an invalid split behind. The
                  // breakdown widget below shows the live "remaining /
                  // over by" status so they know what to fix.
                  trailing: Consumer(
                    builder: (_, ref, __) {
                      final canClose = ref.watch(
                        addExpenseProvider.select((s) => s.isSplitValid),
                      );
                      return TextButton(
                        onPressed: canClose
                            ? () {
                                HapticService.instance.success();
                                Navigator.pop(ctx);
                              }
                            : null,
                        child: Text(
                          'Done',
                          style: AppTextStyles.body1(isDark).copyWith(
                            color: canClose
                                ? AppColors.tealDark
                                : AppColors.textSecondary(isDark),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Consumer(
                        builder: (_, ref, __) {
                          final s = ref.watch(addExpenseProvider);
                          final notifier = ref.read(
                            addExpenseProvider.notifier,
                          );
                          final memberIds = groupMembers.map((m) => m.id);
                          final myId = ref.watch(myIdProvider);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SplitSelectorWidget(
                                mode: s.splitMode,
                                amount: s.amount,
                                onModeChanged: (mode) {
                                  notifier.state = addExpenseSwitchSplitMode(
                                    notifier.state,
                                    mode,
                                    memberIds,
                                  );
                                },
                              ),
                              if (s.usingGroupDefaultSplit)
                                SplitDefaultHint(
                                  onSplitEqually: () => notifier.state =
                                      addExpenseSplitEquallyForAll(
                                        notifier.state,
                                      ),
                                ),
                              const SizedBox(height: 12),
                              if (s.adjustmentMode)
                                SplitAdjustmentBreakdown(
                                  totalAmount: s.amount,
                                  members: groupMembers,
                                  adjustments: s.adjustments,
                                  includedMemberIds: s.includedMemberIds,
                                  currentUserId: myId,
                                  currency: s.currency,
                                  onAdjustmentsChanged: (a) => notifier.state =
                                      notifier.state.copyWith(adjustments: a),
                                  onIncludedMembersChanged: (ids) =>
                                      notifier.state = notifier.state.copyWith(
                                        includedMemberIds: ids,
                                      ),
                                )
                              else ...[
                                SplitPeopleToggle(
                                  members: groupMembers,
                                  includedMemberIds: s.includedMemberIds,
                                ),
                                SplitBreakdownWidget(
                                  splitType: s.splitType,
                                  totalAmount: s.amount,
                                  members: groupMembers,
                                  splits: s.splits,
                                  includedMemberIds: s.includedMemberIds,
                                  currentUserId: myId,
                                  currency: s.currency,
                                  onSplitsChanged: (splits) {
                                    // Read the live state, not the captured `s`
                                    // snapshot. _toggleMember fires this right
                                    // after onIncludedMembersChanged; using the
                                    // stale `s` here would clobber the just-set
                                    // includedMemberIds back to its old value.
                                    notifier.state = notifier.state.copyWith(
                                      splits: splits,
                                    );
                                  },
                                  onIncludedMembersChanged: (included) {
                                    notifier.state = notifier.state.copyWith(
                                      includedMemberIds: included,
                                    );
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
