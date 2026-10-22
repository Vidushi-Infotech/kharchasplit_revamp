import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/contacts/contact_name_resolver.dart';
import '../../../models/models.dart';
import '../../auth/state/auth_provider.dart';
import '../../groups/state/group_balance_helpers.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/expense_comments_provider.dart';
import '../state/expense_detail_actions.dart';
import '../state/expense_detail_provider.dart';
import '../state/expense_error_message.dart';
import '../state/recurring_rule_provider.dart';
import '../widgets/expense_comments_input.dart';
import '../widgets/expense_comments_section.dart';
import '../widgets/expense_detail_header.dart';
import '../widgets/expense_detail_people.dart';
import '../widgets/expense_detail_receipt.dart';
import '../widgets/expense_detail_top_bar.dart';
import '../widgets/expense_history_sheet.dart';
import '../widgets/recurring_info_card.dart';

/// One expense, flat (Splitwise style): category tile + description +
/// amount, a line per person ("Asha K. paid ₹600.00 and owes ₹400.00"),
/// repeat / receipt / notes, then the comments with the input pinned below.
class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Compact < 600 / standard 600–1100 / large > 1100.
    final maxContentWidth = screenWidth < 1100 ? 720.0 : 900.0;
    final pad = screenWidth < 600 ? 16.0 : (screenWidth < 1100 ? 24.0 : 32.0);
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final expense = expenseAsync.value;
    final myId = ref.watch(myIdProvider);
    // Any payer of the expense may edit or delete it (server rule).
    final canEdit = expense != null && myId != null && expense.isPayer(myId);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: ExpenseDetailTopBar(
        isDark: isDark,
        canEdit: canEdit,
        onBack: () => context.pop(),
        onDelete: () => _confirmAndDelete(context, ref),
        onEdit: () => context.push('/expense/$expenseId/edit'),
        onHistory: expense == null
            ? null
            : () => showExpenseHistorySheet(
                context,
                expense: expense,
                canRestore: canEdit,
              ),
      ),
      body: SafeArea(
        bottom: false,
        child: expenseAsync.when(
          loading: () => const Center(child: ShimmerList(itemCount: 3)),
          error: (error, _) => ErrorStateWidget(
            title: 'Failed to load expense',
            message: 'Unable to fetch expense details. Please try again.',
            onRetry: () => ref.invalidate(expenseDetailProvider(expenseId)),
          ),
          data: (expense) {
            // Split rows can arrive with an empty userName / no avatar:
            // the group's members fill those in.
            final groupDetail = expense.groupId != null
                ? ref.watch(groupDetailProvider(expense.groupId!)).value
                : null;
            final members = groupDetail?.members ?? const <UserModel>[];
            final memberById = <String, UserModel>{
              for (final m in members) m.id: m,
            };
            // Net balance with each person, so Settle up / Remind reflect
            // the OUTSTANDING net (simplified in a "Simplify group debts"
            // group, same as the Balances tab) — not this expense's share.
            final netByUserId = (myId != null && groupDetail != null)
                ? groupVisibleDebts(myId: myId, detail: groupDetail)
                : const <String, double>{};
            // Already in-flight settlements I've sent — Settle up only asks
            // for the remainder.
            final pendingOutByUserId = (myId != null && groupDetail != null)
                ? computePendingOutgoing(
                    myId: myId,
                    settlements: groupDetail.settlements,
                  )
                : const <String, double>{};

            void settleWith(String payerId, double amount) {
              final gid = expense.groupId;
              if (gid == null) return;
              context.push(
                '/settle/$payerId?groupId=$gid'
                '&amount=${amount.toStringAsFixed(2)}',
              );
            }

            final notes = (expense.notes ?? '').trim();
            final hasReceipt =
                expense.receiptBase64 != null &&
                expense.receiptBase64!.isNotEmpty;
            final details = <Widget>[
              ExpenseDetailHeader(expense: expense, isDark: isDark, myId: myId),
              Divider(height: 1, color: AppColors.divider(isDark)),
              const SizedBox(height: 8),
              ExpenseDetailPeople(
                expense: expense,
                isDark: isDark,
                myId: myId,
                memberById: memberById,
                // Blank / phone-only names → the device contact's name.
                contactNameByPhone: ref.watch(contactNameByPhoneProvider),
                netByUserId: netByUserId,
                pendingOutByUserId: pendingOutByUserId,
                onSettle: settleWith,
                onRemind: (userId) =>
                    _sendReminder(context, ref, expense.groupId, userId),
              ),
              if (expense.isRecurring) ...[
                const SizedBox(height: 12),
                RecurringInfoCard(expense: expense, isDark: isDark),
              ],
              if (hasReceipt) ...[
                const SizedBox(height: 8),
                ExpenseDetailReceipt(
                  base64Data: expense.receiptBase64!,
                  isDark: isDark,
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppStrings.notes.toUpperCase(),
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: AppTextStyles.body2(isDark).copyWith(
                    color: AppColors.textPrimary(isDark),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.divider(isDark)),
              const SizedBox(height: 8),
            ];

            // Comments scroll with the details (lazily, as slivers); the
            // input box stays pinned below and rides up with the keyboard.
            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(expenseDetailProvider(expenseId));
                      ref.invalidate(expenseCommentsProvider(expenseId));
                      final ruleId = expense.recurringRuleId;
                      if (ruleId != null) {
                        ref.invalidate(recurringRuleProvider(ruleId));
                      }
                      await ref.read(expenseDetailProvider(expenseId).future);
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
                              sliver: SliverMainAxisGroup(
                                slivers: [
                                  SliverList.list(children: details),
                                  ExpenseCommentsSliver(
                                    expenseId: expenseId,
                                    isDark: isDark,
                                    memberIds: groupDetail == null
                                        ? null
                                        : memberById.keys.toSet(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ExpenseCommentInput(
                  expenseId: expenseId,
                  isDark: isDark,
                  maxWidth: maxContentWidth,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendReminder(
    BuildContext context,
    WidgetRef ref,
    String? groupId,
    String userId,
  ) async {
    if (groupId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(expenseDetailActionsProvider)
          .remind(groupId: groupId, userId: userId);
      messenger.showSnackBar(const SnackBar(content: Text('Reminder sent')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send reminder: $e')),
      );
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Delete this expense?'),
        content: const Text(
          'This will remove the expense from the group. Balances will '
          'recalculate for everyone. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(false),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.deleteLabel),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expenseDetailActionsProvider).delete(expenseId);
      messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
      if (context.mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(expenseErrorMessage(e, fallback: 'Could not delete')),
        ),
      );
    }
  }
}
