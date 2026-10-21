import 'package:flutter/material.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../state/upi_pay.dart';
import 'upi_fallback_sheet.dart';
import 'upi_paid_confirm_dialog.dart';

/// "Pay ₹X with UPI" — runs the whole pay flow:
///
/// 1. opens the user's UPI app with a prefilled `upi://pay` link (or, when
///    no app takes it / on web & desktop, a sheet with the UPI ID + QR);
/// 2. when the app returns to the foreground, asks "Did your ₹X payment to
///    {name} go through?";
/// 3. calls [onConfirmedPaid] only after the user taps "Yes".
///
/// The UPI app's own result is never trusted. If the resume event is missed
/// (web, or the OS kept us in the foreground) an "I've paid — record it"
/// button stays visible after the launch so the user can still confirm.
class UpiPayButton extends StatefulWidget {
  const UpiPayButton({
    super.key,
    required this.payeeVpa,
    required this.payeeName,
    required this.amount,
    required this.note,
    required this.onConfirmedPaid,
  });

  final String payeeVpa;
  final String payeeName;

  /// Rupees. Callers keep it within (0, [kUpiMaxAmount]].
  final double amount;

  /// Free-text note shown in the UPI app; clipped to 50 characters.
  final String note;

  /// Records the payment (method UPI). Errors are the caller's to show.
  final Future<void> Function() onConfirmedPaid;

  @override
  State<UpiPayButton> createState() => _UpiPayButtonState();
}

class _UpiPayButtonState extends State<UpiPayButton> {
  late final AppLifecycleListener _lifecycle;

  /// Set just before launching so a resume that races the launch future
  /// (iOS completes `openURL` late) still triggers the question.
  bool _awaitingReturn = false;

  /// A UPI app was opened at least once — keeps the manual confirm visible.
  bool _launched = false;
  bool _busy = false;
  bool _asking = false;

  String get _amountLabel =>
      CurrencyFormatter.format(widget.amount, currency: 'INR');

  String get _uri => buildUpiPayUri(
    payeeVpa: widget.payeeVpa,
    payeeName: widget.payeeName,
    amount: widget.amount,
    note: widget.note,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_awaitingReturn || !mounted) return;
    _awaitingReturn = false;
    _confirmAndRecord();
  }

  Future<void> _pay() async {
    if (_busy) return;
    final uri = _uri;
    if (!canLaunchUpiApps) {
      await _fallback(launchFailed: false);
      return;
    }
    _awaitingReturn = true;
    final opened = await launchUpiUri(uri);
    if (!mounted) return;
    if (opened) {
      setState(() => _launched = true);
      return;
    }
    _awaitingReturn = false;
    await _fallback(launchFailed: true);
  }

  Future<void> _fallback({required bool launchFailed}) async {
    final paid = await showUpiFallbackSheet(
      context,
      payeeVpa: widget.payeeVpa,
      payeeName: widget.payeeName,
      amountLabel: _amountLabel,
      upiUri: _uri,
      launchFailed: launchFailed,
    );
    if (!mounted) return;
    if (!paid) {
      // They may still pay from another phone and come back to confirm.
      setState(() => _launched = true);
      return;
    }
    await _confirmAndRecord();
  }

  Future<void> _confirmAndRecord() async {
    if (_asking || _busy) return;
    _asking = true;
    final yes = await showUpiPaidConfirmDialog(
      context,
      amountLabel: _amountLabel,
      payeeName: widget.payeeName,
    );
    _asking = false;
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirmedPaid();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.payWithUpi(_amountLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: PrimaryButton(
            label: label,
            isLoading: _busy,
            onPressed: _busy ? null : _pay,
          ),
        ),
        if (_launched && !_busy) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _confirmAndRecord,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text(AppStrings.iHavePaidRecordIt),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          ),
        ],
      ],
    );
  }
}
