import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base64_async.dart';
import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/contacts/contact_name_resolver.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/models.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_balance_helpers.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/expense_comments_provider.dart';
import '../state/expense_detail_provider.dart';
import '../state/expense_error_message.dart';
import '../state/recurring_rule_provider.dart';
import '../widgets/expense_comments_input.dart';
import '../widgets/expense_comments_section.dart';
import '../widgets/expense_detail_history_row.dart';
import '../widgets/expense_detail_paid_by.dart';
import '../widgets/expense_detail_splits_card.dart';
import '../widgets/recurring_info_card.dart';

String _splitTypeLabel(ExpenseModel e) {
  if (e.isAdjustmentSplit) return AppStrings.splitAdjustment;
  switch (e.splitType) {
    case SplitType.equal:
      return 'Equal share';
    case SplitType.exact:
      return 'Split unequally';
    case SplitType.percentage:
      return 'By percentage';
    case SplitType.shares:
      return 'By shares';
  }
}

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxContentWidth = screenWidth < 1100 ? 720.0 : 900.0;
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final myId = ref.watch(myIdProvider);
    // Any payer of the expense may edit or delete it (server rule).
    final canDelete =
        expenseAsync.value != null &&
        myId != null &&
        expenseAsync.value!.isPayer(myId);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        canDelete: canDelete,
        onBack: () => context.pop(),
        onMenuSelected: (value) async {
          if (value == 'delete') {
            await _confirmAndDelete(context, ref);
          } else if (value == 'edit') {
            context.push('/expense/$expenseId/edit');
          }
        },
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
            // Some split rows arrive from the backend with an empty
            // userName (and no avatar URL) — they'd render a "?" avatar
            // and a blank name. Build a userId → member lookup from the
            // group so the rows can fall back to the member's real name
            // and avatar.
            final groupDetail = expense.groupId != null
                ? ref.watch(groupDetailProvider(expense.groupId!)).value
                : null;
            final members = groupDetail?.members ?? const <UserModel>[];
            final memberById = <String, UserModel>{
              for (final m in members) m.id: m,
            };

            // Net balance with each person, so the Settle Up / Remind
            // buttons reflect the OUTSTANDING net (not this one expense's
            // share) — simplified in a "Simplify group debts" group, same as
            // the Balances tab. Once settled, the button disappears.
            final netByUserId = (myId != null && groupDetail != null)
                ? groupVisibleDebts(myId: myId, detail: groupDetail)
                : const <String, double>{};
            // Already in-flight (pending) settlements I've sent — so Settle Up
            // only asks for the remainder.
            final pendingOutByUserId = (myId != null && groupDetail != null)
                ? computePendingOutgoing(
                    myId: myId,
                    settlements: groupDetail.settlements,
                  )
                : const <String, double>{};

            // Names that arrive blank (or as a bare phone number) from the
            // backend — users who registered by phone and never set a display
            // name — are upgraded to the name saved for that phone in the
            // device address book, matched via the group member's phone.
            final contactNameByPhone = ref.watch(contactNameByPhoneProvider);

            // Per-split display names, resolved the same way.
            final splitDisplayNames = <String, String>{
              for (final s in expense.splits)
                s.userId: resolveDisplayName(
                  backendName: s.userName,
                  phone: memberById[s.userId]?.phone ?? '',
                  contactNameByPhone: contactNameByPhone,
                ),
            };

            void settleWith(String payerId, double amount) {
              final gid = expense.groupId;
              if (gid == null) return;
              context.push(
                '/settle/$payerId?groupId=$gid'
                '&amount=${amount.toStringAsFixed(2)}',
              );
            }

            final details = <Widget>[
              _Hero(expense: expense, isDark: isDark),
              if (expense.isRecurring) ...[
                const SizedBox(height: 12),
                RecurringInfoCard(expense: expense, isDark: isDark),
              ],
              const SizedBox(height: 22),
              _SectionLabel(label: 'PAID BY', isDark: isDark),
              const SizedBox(height: 8),
              ExpenseDetailPaidBy(
                expense: expense,
                isDark: isDark,
                myId: myId,
                memberById: memberById,
                contactNameByPhone: contactNameByPhone,
                netByUserId: netByUserId,
                pendingOutByUserId: pendingOutByUserId,
                onSettle: settleWith,
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                label:
                    'SPLIT AMONG · ${expense.splits.length} · ${_splitTypeLabel(expense).toUpperCase()}',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              ExpenseDetailSplitsCard(
                splits: expense.splits,
                currency: expense.currency,
                isDark: isDark,
                splitType: expense.splitType,
                totalAmount: expense.amount,
                currentUserId: myId,
                memberById: memberById,
                displayNames: splitDisplayNames,
                payerIds: {for (final p in expense.payers) p.userId},
                groupId: expense.groupId,
                netByUserId: netByUserId,
                pendingOutByUserId: pendingOutByUserId,
                onSettle: settleWith,
                onRemind: (userId) =>
                    _sendReminder(context, ref, expense.groupId, userId),
              ),
              if (expense.receiptBase64 != null &&
                  expense.receiptBase64!.isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionLabel(label: 'RECEIPT', isDark: isDark),
                const SizedBox(height: 8),
                _ReceiptCard(base64Data: expense.receiptBase64!, isDark: isDark),
              ],
              if (expense.notes != null &&
                  (expense.notes as String).isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionLabel(label: 'NOTES', isDark: isDark),
                const SizedBox(height: 8),
                _NotesCard(notes: expense.notes!, isDark: isDark),
              ],
              const SizedBox(height: 22),
              ExpenseDetailHistoryRow(
                expense: expense,
                canEdit: myId != null && expense.isPayer(myId),
                isDark: isDark,
              ),
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
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
    try {
      await ref
          .read(groupsRepositoryProvider)
          .sendReminder(groupId: groupId, userId: userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reminder sent')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send reminder: $e')));
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Capture groupId BEFORE the expense is gone — we need it to invalidate
    // the right group detail provider after the delete succeeds.
    final cachedExpense = ref.read(expenseDetailProvider(expenseId)).value;
    final groupId = cachedExpense?.groupId;

    try {
      await ref.read(expensesRepositoryProvider).delete(expenseId, groupId: groupId);
      ref.invalidate(dashboardProvider);
      if (groupId != null) {
        ref.invalidate(groupDetailProvider(groupId));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense deleted')));
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(expenseErrorMessage(e, fallback: 'Could not delete')),
        ),
      );
    }
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.isDark,
    required this.onBack,
    required this.onMenuSelected,
    required this.canDelete,
  });

  final bool isDark;
  final VoidCallback onBack;
  final ValueChanged<String> onMenuSelected;

  /// Hides the menu when the current user isn't one of the payers.
  final bool canDelete;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _CircleIcon(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: onBack,
                label: 'Back',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Expense',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DonateHeartButton(),
              const SizedBox(width: 8),
              // Only the payers of the expense see the three-dots menu at
              // all — other members get no menu button.
              if (canDelete)
                Semantics(
                  button: true,
                  label: 'More options',
                  child: PopupMenuButton<String>(
                    onSelected: onMenuSelected,
                    color: AppColors.cardBg(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.divider(isDark)),
                    ),
                    icon: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    itemBuilder: (_) => [
                      // Edit gates on the same payer-only rule as Delete: the
                      // backend rejects PUT /expenses/:id with 403 if the
                      // caller isn't one of the payers.
                      if (canDelete)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: AppColors.textPrimary(isDark),
                              ),
                              const SizedBox(width: 10),
                              const Text('Edit'),
                            ],
                          ),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Delete',
                                style: TextStyle(color: AppColors.warning),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(icon, size: 18, color: AppColors.textPrimary(isDark)),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.expense, required this.isDark});

  final dynamic expense;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: expense.currency as String,
      decimalDigits: 0,
    ).format(expense.amount as num);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealLight, AppColors.tealDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -30,
              right: -20,
              child: _Orb(size: 140, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Icon(
                          expense.category.icon as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'EXPENSE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.title as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${expense.category.name as String} · ${DateFormatter.fullDateTime(expense.date as DateTime)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatefulWidget {
  const _ReceiptCard({required this.base64Data, required this.isDark});

  final String base64Data;
  final bool isDark;

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  /// Cached decoded bytes — base64-decoding a multi-MB receipt every build
  /// (which happened on every theme tick / parent rebuild) burns CPU and
  /// drops frames. Done once here, off the main isolate, refreshed only if
  /// the source string changes (rare — receipts are immutable per expense).
  Uint8List? _bytes;
  String? _decodedFor;
  bool _decoding = true;

  Future<void> _decode() async {
    final source = widget.base64Data;
    if (_decodedFor == source) return;
    _decodedFor = source;
    _decoding = true;
    final bytes = await base64DecodeAsync(source);
    // Widget may have gone away, or the source may have changed again
    // while we were decoding — drop a stale result.
    if (!mounted || _decodedFor != source) return;
    setState(() {
      _bytes = bytes;
      _decoding = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_ReceiptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Data != widget.base64Data) {
      _decode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bytes = _bytes;
    final canShow = bytes != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canShow ? () => _showFullScreen(context, bytes) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canShow
                          ? 'View receipt'
                          : (_decoding
                              ? 'Loading receipt…'
                              : 'Receipt unavailable'),
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canShow
                          ? 'Tap to open the bill image'
                          : "Couldn't decode the saved image",
                      style: AppTextStyles.caption(
                        isDark,
                      ).copyWith(color: AppColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
              if (canShow)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.isDark});
  final String notes;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        notes,
        style: AppTextStyles.body2(
          isDark,
        ).copyWith(color: AppColors.textPrimary(isDark), height: 1.45),
      ),
    );
  }
}
