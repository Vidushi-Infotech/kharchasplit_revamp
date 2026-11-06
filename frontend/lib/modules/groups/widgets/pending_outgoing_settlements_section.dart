import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/settlement_model.dart';
import '../../settlements/state/payment_method_format.dart';
import '../../settlements/state/pending_settlements_provider.dart';
import '../state/group_detail_provider.dart';

/// Pending settlements the current user *sent* (awaiting recipient confirmation).
/// Lets the sender withdraw via DELETE /settlements/:id.
class PendingOutgoingSettlementsSection extends ConsumerWidget {
  const PendingOutgoingSettlementsSection({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingOutgoingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_send_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
                Text(
                  'Awaiting confirmation',
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _OutgoingSettlementTile(
                settlement: s,
                groupId: groupId,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingSettlementTile extends ConsumerStatefulWidget {
  const _OutgoingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_OutgoingSettlementTile> createState() =>
      _OutgoingSettlementTileState();
}

class _OutgoingSettlementTileState
    extends ConsumerState<_OutgoingSettlementTile> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this pending payment?'),
        content: const Text(
          'The recipient will no longer see this payment as pending. '
          'You can record it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .delete(widget.settlement.id as String);
      ref.invalidate(pendingOutgoingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final toName = (s.toUser.name as String).isEmpty
        ? 'Someone'
        : s.toUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              withPaymentMethod(
                'You sent $toName ${CurrencyFormatter.format(s.amount as double, currency: s.currency as String)}',
                s.method as SettlementMethod?,
              ),
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText(widget.isDark),
              side: BorderSide(color: AppColors.errorText(widget.isDark)),
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
