import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../components/inputs/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/category_model.dart';
import '../../../../models/personal_bill_model.dart';
import '../../../../models/wallet_source_model.dart';
import '../../state/personal_bills_provider.dart';
import '../../state/wallet_provider.dart';
import '../account_style.dart';
import 'bill_style.dart';

/// Add or change a bill: name, amount, category, how often, the next due
/// date, when to be reminded and (with accounts) which account pays it.
class BillEditorSheet extends ConsumerStatefulWidget {
  const BillEditorSheet({super.key, this.bill});

  /// Null to add a new bill.
  final PersonalBill? bill;

  static Future<void> show(BuildContext context, {PersonalBill? bill}) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      // Tall ones stop below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: AppColors.surface(
        Theme.of(context).brightness == Brightness.dark,
      ),
      builder: (_) => BillEditorSheet(bill: bill),
    );
  }

  @override
  ConsumerState<BillEditorSheet> createState() => _BillEditorSheetState();
}

class _BillEditorSheetState extends ConsumerState<BillEditorSheet> {
  static const _remindOptions = [0, 1, 2, 3, 7];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bill?.name);
  late final _amount = TextEditingController(
    text: widget.bill == null
        ? ''
        : widget.bill!.amount == widget.bill!.amount.roundToDouble()
        ? widget.bill!.amount.toStringAsFixed(0)
        : widget.bill!.amount.toStringAsFixed(2),
  );
  late String _category = widget.bill?.category ?? CategoryModel.utilities.id;
  late BillFrequency _frequency =
      widget.bill?.frequency ?? BillFrequency.monthly;
  late DateTime _due = widget.bill?.nextDue ?? _today();
  late int _remind = widget.bill?.remindDays ?? 2;
  late String? _accountId = widget.bill?.accountId;
  bool _busy = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: _today().subtract(const Duration(days: 365)),
      lastDate: _today().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _due = picked);
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _run(
      () => ref
          .read(personalBillsProvider.notifier)
          .save(
            id: widget.bill?.id,
            name: _name.text.trim(),
            amount: double.parse(_amount.text.trim()),
            category: _category,
            // Unchanged ones are left out: they'd restart the schedule.
            frequency: _frequency == widget.bill?.frequency ? null : _frequency,
            dueDate: _due == widget.bill?.nextDue ? null : _due,
            remindDays: _remind,
            accountId: _accountId,
          ),
      AppStrings.billSaved,
    );
  }

  void _remove() => _run(
    () => ref.read(personalBillsProvider.notifier).archive(widget.bill!.id),
    AppStrings.billRemoved,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value;
    final List<WalletSource> accounts = wallet?.onServer == true
        ? wallet!.sources
        : const [];
    final label = AppTextStyles.body2(
      isDark,
    ).copyWith(fontWeight: FontWeight.w600);

    Widget chip({
      required String text,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
    }) => ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textSecondary(isDark),
            ),
      label: Text(text),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary(isDark),
      ),
      onSelected: (_) => setState(onTap),
    );

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.bill == null ? AppStrings.billAdd : AppStrings.billEdit,
                style: AppTextStyles.headline2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: AppStrings.billName,
                hint: AppStrings.billNameHint,
                controller: _name,
                prefixIcon: Icons.receipt_long_rounded,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              Text(AppStrings.billRepeats, style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in BillFrequency.values)
                    chip(
                      text: f.label,
                      selected: f == _frequency,
                      onTap: () => _frequency = f,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(AppStrings.billNextDue, style: label),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.textPrimary(isDark),
                  side: BorderSide(color: AppColors.divider(isDark)),
                ),
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_due)),
              ),
              const SizedBox(height: 14),
              Text(AppStrings.billRemind, style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _remindOptions)
                    chip(
                      text: AppStrings.billRemindDays(d),
                      selected: d == _remind,
                      onTap: () => _remind = d,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('CATEGORY', style: label.copyWith(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CategoryModel.all)
                    chip(
                      text: c.name,
                      icon: c.icon,
                      selected: c.id == _category,
                      onTap: () => _category = c.id,
                    ),
                ],
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(AppStrings.billPayFrom, style: label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in accounts)
                      chip(
                        text: s.name,
                        icon: s.type.icon,
                        selected: s.id == _accountId,
                        onTap: () =>
                            _accountId = s.id == _accountId ? null : s.id,
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
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.billSave),
              ),
              if (widget.bill != null)
                TextButton(
                  onPressed: _busy ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorText(isDark),
                  ),
                  child: const Text(AppStrings.billRemove),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
