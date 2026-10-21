import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/settlement_model.dart';
import '../state/not_received_controller.dart';

/// Small secondary "Not received" action on a payment made to the current
/// user. Confirms first, then removes the payment so the amount shows as
/// owed again; the payer is notified by the server.
class NotReceivedButton extends ConsumerStatefulWidget {
  const NotReceivedButton({
    super.key,
    required this.settlement,
    required this.groupId,
  });

  final SettlementModel settlement;
  final String groupId;

  @override
  ConsumerState<NotReceivedButton> createState() => _NotReceivedButtonState();
}

class _NotReceivedButtonState extends ConsumerState<NotReceivedButton> {
  bool _busy = false;

  String get _payerName => widget.settlement.fromUser.name.isEmpty
      ? 'Someone'
      : widget.settlement.fromUser.name;

  Future<void> _onTap() async {
    final s = widget.settlement;
    final amount = CurrencyFormatter.format(s.amount, currency: s.currency);
    final confirmed = await _confirm(amount);
    if (!confirmed || !mounted) return;

    // The row disappears once the group refetches, so grab the messenger
    // before awaiting.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String message;
    try {
      await ref
          .read(notReceivedControllerProvider)
          .markNotReceived(settlementId: s.id, groupId: widget.groupId);
      message = AppStrings.markedNotReceived(_payerName);
    } on SettlementsApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = AppStrings.notReceivedFailed;
    }
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String amount) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(AppStrings.markNotReceivedTitle),
        content: Text(
          AppStrings.markNotReceivedBody(amount, _payerName),
          style: AppTextStyles.body2(isDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary(isDark),
            ),
            child: const Text(AppStrings.keepPayment),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text(AppStrings.markNotReceived),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '${AppStrings.notReceived}: payment from $_payerName',
      excludeSemantics: true,
      child: TextButton(
        onPressed: _busy ? null : _onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary(isDark),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppTextStyles.caption(
            isDark,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        child: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(AppStrings.notReceived),
      ),
    );
  }
}
