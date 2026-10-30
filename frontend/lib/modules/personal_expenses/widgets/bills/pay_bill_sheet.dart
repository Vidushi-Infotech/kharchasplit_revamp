import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/inputs/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/personal_bill_model.dart';
import '../../../../models/wallet_source_model.dart';
import '../../state/personal_bills_provider.dart';
import '../../state/wallet_provider.dart';
import '../account_style.dart';
import 'bill_style.dart';

/// Pay a bill: confirm the amount (it can differ, e.g. this month's
/// electricity) and the account, or skip this due date.
class PayBillSheet extends ConsumerStatefulWidget {
  const PayBillSheet({super.key, required this.bill});

  final PersonalBill bill;

  static Future<void> show(BuildContext context, PersonalBill bill) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: AppColors.surface(
        Theme.of(context).brightness == Brightness.dark,
      ),
      builder: (_) => PayBillSheet(bill: bill),
    );
  }

  @override
  ConsumerState<PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<PayBillSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.bill.amount == widget.bill.amount.roundToDouble()
        ? widget.bill.amount.toStringAsFixed(0)
        : widget.bill.amount.toStringAsFixed(2),
  );
  late String? _accountId = widget.bill.accountId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      HapticService.instance.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppStrings.billFailed;
        });
      }
    }
  }

  void _pay() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amount.text.trim());
    _run(
      () => ref
          .read(personalBillsProvider.notifier)
          .pay(widget.bill.id, amount: amount, accountId: _accountId),
      AppStrings.billPaid,
    );
  }

  void _skip() => _run(
    () => ref.read(personalBillsProvider.notifier).skip(widget.bill.id),
    AppStrings.billSkipped,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value;
    final List<WalletSource> accounts = wallet?.onServer == true
        ? wallet!.sources
        : const [];
    final b = widget.bill;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              b.name,
              style: AppTextStyles.headline2(
                isDark,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              billDueText(b),
              style: AppTextStyles.body2(isDark).copyWith(
                color: billDueColor(b, isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: AppStrings.billAmount,
              hint: '0',
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.currency_rupee_rounded,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return n == null || n <= 0
                    ? 'Enter an amount greater than 0'
                    : null;
              },
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                AppStrings.billPayFrom,
                style: AppTextStyles.body2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in accounts)
                    ChoiceChip(
                      avatar: Icon(
                        s.type.icon,
                        size: 16,
                        color: s.id == _accountId
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                      ),
                      label: Text('${s.name} · ${accountBalanceText(s)}'),
                      selected: s.id == _accountId,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: s.id == _accountId
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                      onSelected: (_) => setState(
                        () => _accountId = s.id == _accountId ? null : s.id,
                      ),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: AppColors.errorText(isDark)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _pay,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text(AppStrings.billMarkPaid),
            ),
            TextButton(
              onPressed: _busy ? null : _skip,
              child: const Text(AppStrings.billSkip),
            ),
          ],
        ),
      ),
    );
  }
}
