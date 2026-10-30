import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/inputs/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/wallet_source_model.dart';
import '../../state/wallet_provider.dart';
import '../account_style.dart';

/// Move money between two accounts (an ATM withdrawal, paying off a card,
/// topping up a wallet). Not spending or income: both balances change.
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key, this.fromId});

  final String? fromId;

  static Future<void> show(BuildContext context, {String? fromId}) {
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
      builder: (_) => TransferSheet(fromId: fromId),
    );
  }

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String? _from = widget.fromId;
  String? _to;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final sources = ref.read(walletProvider).value?.sources ?? const [];
    _from ??= sources.firstOrNull?.id;
    _to = sources.where((s) => s.id != _from).firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_from == null || _to == null || _from == _to) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(walletProvider.notifier)
          .transfer(
            fromId: _from!,
            toId: _to!,
            amount: double.parse(_amount.text.trim()),
            note: _note.text.trim(),
          );
      HapticService.instance.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.accountTransferDone)),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppStrings.accountTransferFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(walletProvider).value?.sources ?? const [];
    final label = AppTextStyles.body2(
      isDark,
    ).copyWith(fontWeight: FontWeight.w600);

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
                AppStrings.accountTransferTitle,
                style: AppTextStyles.headline2(
                  isDark,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.accountTransferFrom, style: label),
              const SizedBox(height: 8),
              _AccountChips(
                sources: sources,
                selected: _from,
                onSelected: (id) => setState(() {
                  if (_to == id) _to = _from;
                  _from = id;
                }),
              ),
              const SizedBox(height: 14),
              Text(AppStrings.accountTransferTo, style: label),
              const SizedBox(height: 8),
              _AccountChips(
                sources: sources.where((s) => s.id != _from).toList(),
                selected: _to,
                onSelected: (id) => setState(() => _to = id),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Amount',
                hint: '0.00',
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
              const SizedBox(height: 12),
              AppTextField(
                label: AppStrings.accountTransferNote,
                hint: '',
                controller: _note,
                prefixIcon: Icons.edit_note_rounded,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: AppColors.errorText(isDark)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy || _from == null || _to == null ? null : _save,
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
                    : const Icon(Icons.swap_horiz_rounded),
                label: const Text(AppStrings.accountTransfer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({
    required this.sources,
    required this.selected,
    required this.onSelected,
  });

  final List<WalletSource> sources;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in sources)
          ChoiceChip(
            avatar: Icon(
              s.type.icon,
              size: 16,
              color: s.id == selected
                  ? Colors.white
                  : AppColors.textSecondary(isDark),
            ),
            label: Text('${s.name} · ${accountBalanceText(s)}'),
            selected: s.id == selected,
            showCheckmark: false,
            selectedColor: AppColors.brand,
            labelStyle: TextStyle(
              color: s.id == selected
                  ? Colors.white
                  : AppColors.textPrimary(isDark),
            ),
            onSelected: (_) => onSelected(s.id),
          ),
      ],
    );
  }
}
