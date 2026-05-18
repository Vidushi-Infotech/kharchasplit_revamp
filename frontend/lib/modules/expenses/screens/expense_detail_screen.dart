import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../../groups/state/group_detail_provider.dart';
import '../state/expense_detail_provider.dart';

String _splitTypeLabel(SplitType t) {
  switch (t) {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final expenseAsync = ref.watch(expenseDetailProvider(expenseId));
    final myId = ref.watch(authProvider).user?.id;
    final canDelete = expenseAsync.value != null &&
        myId != null &&
        expenseAsync.value!.paidBy.id == myId;

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
            onRetry: () {},
          ),
          data: (expense) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth < 1100 ? 720 : 900,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _Hero(expense: expense, isDark: isDark),
                  const SizedBox(height: 22),
                  _SectionLabel(label: 'PAID BY', isDark: isDark),
                  const SizedBox(height: 8),
                  _PersonCard(
                    name: expense.paidBy.name,
                    imageUrl: expense.paidBy.avatarUrl,
                    amount: expense.amount,
                    currency: expense.currency,
                    accent: AppColors.success,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(
                    label:
                        'SPLIT AMONG · ${expense.splits.length} · ${_splitTypeLabel(expense.splitType).toUpperCase()}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _SplitsCard(
                    splits: expense.splits,
                    currency: expense.currency,
                    isDark: isDark,
                    splitType: expense.splitType,
                    totalAmount: expense.amount,
                  ),
                  if (expense.receiptBase64 != null &&
                      expense.receiptBase64!.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SectionLabel(label: 'RECEIPT', isDark: isDark),
                    const SizedBox(height: 8),
                    _ReceiptCard(
                      base64Data: expense.receiptBase64!,
                      isDark: isDark,
                    ),
                  ],
                  if (expense.notes != null &&
                      (expense.notes as String).isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SectionLabel(label: 'NOTES', isDark: isDark),
                    const SizedBox(height: 8),
                    _NotesCard(notes: expense.notes!, isDark: isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Delete this expense?'),
        content: const Text(
            'This will remove the expense from the group. Balances will '
            'recalculate for everyone. This can\'t be undone.'),
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
    final cachedExpense =
        ref.read(expenseDetailProvider(expenseId)).value;
    final groupId = cachedExpense?.groupId;

    try {
      await ref.read(expensesRepositoryProvider).delete(expenseId);
      ref.invalidate(dashboardProvider);
      if (groupId != null) {
        ref.invalidate(groupDetailProvider(groupId));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted')),
      );
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
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

  /// Hides the Delete item when the current user didn't add this expense.
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
                    // caller isn't the original payer.
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
            child: Icon(
              icon,
              size: 18,
              color: AppColors.textPrimary(isDark),
            ),
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.imageUrl,
    required this.amount,
    required this.currency,
    required this.accent,
    required this.isDark,
  });

  final String name;
  final String? imageUrl;
  final double amount;
  final String currency;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: currency,
      decimalDigits: 0,
    ).format(amount);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AvatarWidget(name: name, imageUrl: imageUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'paid the full amount',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+$formatted',
            style: AppTextStyles.body1(isDark).copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitsCard extends StatefulWidget {
  const _SplitsCard({
    required this.splits,
    required this.currency,
    required this.isDark,
    required this.splitType,
    required this.totalAmount,
  });

  final List<SplitModel> splits;
  final String currency;
  final bool isDark;
  final SplitType splitType;
  final double totalAmount;

  @override
  State<_SplitsCard> createState() => _SplitsCardState();
}

class _SplitsCardState extends State<_SplitsCard> {
  bool _expanded = false;

  bool get _hasWorking =>
      widget.splitType == SplitType.percentage ||
      widget.splitType == SplitType.shares;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final totalShares = widget.splitType == SplitType.shares
        ? widget.splits.fold<double>(0, (s, e) => s + e.shares)
        : 0.0;

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < widget.splits.length; i++) ...[
            _SplitRow(
              split: widget.splits[i],
              currency: widget.currency,
              isDark: isDark,
              splitType: widget.splitType,
              totalAmount: widget.totalAmount,
              totalShares: totalShares,
              showWorking: _expanded,
            ),
            if (i < widget.splits.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
          if (_hasWorking) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider(isDark).withValues(alpha: 0.6),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? 'Hide working' : 'Show working',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!_hasWorking) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: card,
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.currency,
    required this.isDark,
    required this.splitType,
    required this.totalAmount,
    required this.totalShares,
    required this.showWorking,
  });

  final SplitModel split;
  final String currency;
  final bool isDark;
  final SplitType splitType;
  final double totalAmount;
  final double totalShares;
  final bool showWorking;

  String _amount(double v) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: currency,
        decimalDigits: 0,
      ).format(v);

  /// Resolve percentage to display: prefer the value stored at create time,
  /// otherwise derive it from the resolved amount (works for legacy rows
  /// where the DB column is NULL).
  double? _resolvedPercentage() {
    if (split.percentage > 0) return split.percentage;
    if (totalAmount > 0 && split.owedShare >= 0) {
      return split.owedShare / totalAmount * 100;
    }
    return null;
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String? _inputChip() {
    switch (splitType) {
      case SplitType.percentage:
        final p = _resolvedPercentage();
        if (p == null) return null;
        return '${_trim(p)}%';
      case SplitType.shares:
        if (split.shares <= 0) return null;
        return '${_trim(split.shares)} ${split.shares == 1 ? 'share' : 'shares'}';
      case SplitType.equal:
      case SplitType.exact:
        return null;
    }
  }

  String? _workingLine() {
    switch (splitType) {
      case SplitType.percentage:
        final p = _resolvedPercentage();
        if (p == null) return null;
        return '${_trim(p)}%  ×  ${_amount(totalAmount)}  =  ${_amount(split.owedShare)}';
      case SplitType.shares:
        if (split.shares <= 0 || totalShares <= 0) return null;
        return '${_trim(split.shares)} / ${_trim(totalShares)}  ×  ${_amount(totalAmount)}  =  ${_amount(split.owedShare)}';
      case SplitType.equal:
      case SplitType.exact:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _amount(split.owedShare);
    final chip = _inputChip();
    final working = showWorking ? _workingLine() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AvatarWidget(
              name: split.userName,
              imageUrl: split.userAvatarUrl,
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  split.userName,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (working != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    working,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatted,
                style: AppTextStyles.body1(isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              if (chip != null) ...[
                const SizedBox(height: 2),
                Text(
                  chip,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ],
          ),
        ],
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
  /// drops frames. Done once here, refreshed only if the source string
  /// changes (rare — receipts are immutable per expense).
  Uint8List? _bytes;
  String? _decodedFor;

  void _decode() {
    if (_decodedFor == widget.base64Data) return;
    _decodedFor = widget.base64Data;
    try {
      final cleaned = widget.base64Data.contains(',')
          ? widget.base64Data.split(',').last
          : widget.base64Data;
      _bytes = base64Decode(cleaned);
    } catch (_) {
      _bytes = null;
    }
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
        onTap: canShow ? () => _showFullScreen(context, bytes!) : null,
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
                      canShow ? 'View receipt' : 'Receipt unavailable',
                      style: AppTextStyles.body1(isDark).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canShow
                          ? 'Tap to open the bill image'
                          : "Couldn't decode the saved image",
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
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
        style: AppTextStyles.body2(isDark).copyWith(
          color: AppColors.textPrimary(isDark),
          height: 1.45,
        ),
      ),
    );
  }
}
