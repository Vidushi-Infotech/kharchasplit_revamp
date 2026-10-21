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

/// Pending settlements where the current user is the recipient.
/// Shown above the balances list; tap Confirm to flip status pending → completed.
class PendingIncomingSettlementsSection extends ConsumerWidget {
  const PendingIncomingSettlementsSection({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingIncomingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.handshake_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirm payments received',
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _PendingSettlementTile(
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

class _PendingSettlementTile extends ConsumerStatefulWidget {
  const _PendingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_PendingSettlementTile> createState() =>
      _PendingSettlementTileState();
}

class _PendingSettlementTileState
    extends ConsumerState<_PendingSettlementTile> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return; // anti-double-tap (rebuild can momentarily reset _busy)
    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .confirm(widget.settlement.id as String);
      ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment confirmed')));
    } catch (e) {
      // "Settlement already confirmed / not found" means our intent already
      // succeeded — usually a duplicate tap that slipped past the rebuild.
      // Treat as success: refresh providers, no scary snackbar.
      final msg = e.toString().toLowerCase();
      final benign =
          msg.contains('already confirmed') || msg.contains('not found');
      if (benign) {
        ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
        ref.invalidate(groupDetailProvider(widget.groupId));
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final fromName = (s.fromUser.name as String).isEmpty
        ? 'Someone'
        : s.fromUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              withPaymentMethod(
                '$fromName paid you ${CurrencyFormatter.format(s.amount as double)}',
                s.method as SettlementMethod?,
              ),
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
