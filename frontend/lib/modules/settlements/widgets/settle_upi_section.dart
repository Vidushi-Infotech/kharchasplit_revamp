import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/state/connectivity_provider.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/users/users_repository.dart';
import '../state/payment_info_provider.dart';
import '../state/upi_pay.dart';
import 'upi_pay_button.dart';

/// Pay-by-UPI block on the Record payment screen (flag `upiPay`).
///
/// * payee's UPI ID visible + INR + amount within the UPI cap → "Pay ₹X with
///   UPI" ([UpiPayButton]);
/// * amount above the cap → a short warning instead of the button;
/// * payee has no UPI ID → "Ask {name} for their UPI ID".
///
/// Renders nothing when the flag is off, the group isn't in INR, or the
/// lookup fails — the manual "Record payment" below always works.
class SettleUpiSection extends ConsumerWidget {
  const SettleUpiSection({
    super.key,
    required this.recipientUserId,
    required this.recipientName,
    required this.currency,
    required this.groupName,
    required this.amountController,
    required this.onConfirmedPaid,
  });

  final String recipientUserId;
  final String recipientName;

  /// Group currency (ISO code or symbol).
  final String currency;
  final String groupName;

  /// The screen's amount field — the button follows what's typed.
  final TextEditingController amountController;
  final Future<void> Function() onConfirmedPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!watchFeature(ref, 'upiPay') || !isUpiCurrency(currency)) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // UPI needs the network (payment info, the UPI app, recording right
    // after); manual "Record payment" below still works offline.
    if (ref.watch(isOfflineProvider)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          AppStrings.upiNeedsInternet,
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
          ),
        ),
      );
    }
    final infoAsync = ref.watch(paymentInfoProvider(recipientUserId));

    return infoAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (info) {
        final name = info.name.isNotEmpty ? info.name : recipientName;
        final vpa = info.upiId;
        if (vpa != null) {
          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountController,
            builder: (context, value, _) {
              final amount = double.tryParse(value.text.trim()) ?? 0;
              if (amount > kUpiMaxAmount) {
                return _Warning(isDark: isDark);
              }
              if (!isUpiPayableAmount(amount)) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: UpiPayButton(
                  payeeVpa: vpa,
                  payeeName: name,
                  amount: double.parse(amount.toStringAsFixed(2)),
                  note: AppStrings.upiNote(groupName),
                  onConfirmedPaid: onConfirmedPaid,
                ),
              );
            },
          );
        }
        if (!info.hasUpiId) {
          return _AskForUpiIdButton(userId: recipientUserId, name: name);
        }
        // They have one but the server withheld it (nothing owed to them).
        return const SizedBox.shrink();
      },
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppStrings.upiLimitWarning,
              style: AppTextStyles.caption(
                isDark,
              ).copyWith(color: AppColors.textSecondary(isDark)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskForUpiIdButton extends ConsumerStatefulWidget {
  const _AskForUpiIdButton({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  ConsumerState<_AskForUpiIdButton> createState() =>
      _AskForUpiIdButtonState();
}

class _AskForUpiIdButtonState extends ConsumerState<_AskForUpiIdButton> {
  bool _sending = false;

  Future<void> _ask() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    String message;
    try {
      await ref.read(upiRequestControllerProvider).askForUpiId(widget.userId);
      message = AppStrings.upiIdRequested(widget.name);
    } on UsersApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = AppStrings.upiRequestFailed;
    }
    if (mounted) setState(() => _sending = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.askForUpiId(widget.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: OutlinedButton.icon(
          onPressed: _sending ? null : _ask,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
