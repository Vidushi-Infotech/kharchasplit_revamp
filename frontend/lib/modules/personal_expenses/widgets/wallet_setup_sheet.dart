import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/wallet_source_model.dart';
import '../state/wallet_provider.dart';

/// Bottom sheet for managing wallet sources.
/// - Lists existing sources with edit / delete
/// - "Add source" button reveals an inline add-form (cash or bank)
class WalletSetupSheet extends ConsumerStatefulWidget {
  const WalletSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const WalletSetupSheet(),
    );
  }

  @override
  ConsumerState<WalletSetupSheet> createState() => _WalletSetupSheetState();
}

class _WalletSetupSheetState extends ConsumerState<WalletSetupSheet> {
  bool _showAddForm = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value ?? WalletState.empty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Manage wallet',
                          style: AppTextStyles.headline2(isDark)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (wallet.sources.isEmpty && !_showAddForm)
                      _Empty(onAdd: () => setState(() => _showAddForm = true)),
                    for (final source in wallet.sources)
                      _SourceTile(source: source),
                    const SizedBox(height: 12),
                    if (_showAddForm)
                      _AddSourceForm(
                        onCancel: () => setState(() => _showAddForm = false),
                        onAdded: () => setState(() => _showAddForm = false),
                      )
                    else if (wallet.sources.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showAddForm = true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add another source'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('💰', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Set up your wallet',
            style: AppTextStyles.headline3(isDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Add cash or a bank account to track what\'s available '
            'before you log expenses.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark)
                .copyWith(color: AppColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a source'),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});
  final WalletSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.brand.withValues(alpha: 0.15),
              child: Icon(
                source.type == WalletSourceType.bank
                    ? Icons.account_balance_rounded
                    : Icons.payments_rounded,
                color: AppColors.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    style: AppTextStyles.body1(isDark)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    source.type == WalletSourceType.bank
                        ? 'Bank account'
                        : 'Cash',
                    style: AppTextStyles.caption(isDark),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(source.balance, currency: '₹'),
              style: AppTextStyles.body1(isDark)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _editBalance(context, ref),
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit',
            ),
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmRemove(context, ref),
              icon: Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorText(isDark)),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBalance(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: source.balance.toStringAsFixed(2));
    final newBalance = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit balance — ${source.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'New balance',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBalance != null) {
      await ref
          .read(walletProvider.notifier)
          .editSource(source.id, balance: newBalance);
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    // Block deletion if any expense is tagged to this source.
    final wallet = ref.read(walletProvider).value ?? WalletState.empty;
    final taggedCount =
        wallet.expenseSourceMap.values.where((v) => v == source.id).length;

    if (taggedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.lock_outline_rounded,
              color: AppColors.errorText(
                  Theme.of(ctx).brightness == Brightness.dark)),
          title: const Text("Can't delete this source"),
          content: Text(
            '${source.name} has $taggedCount expense'
            '${taggedCount == 1 ? '' : 's'} tagged to it. '
            'Delete those expenses first, then try again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Safe to delete — still confirm before doing so.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text('Remove ${source.name}?'),
        content: const Text(
            'This source will be removed from your wallet. You can add it '
            'back any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(walletProvider.notifier).removeSource(source.id);
    }
  }
}

class _AddSourceForm extends ConsumerStatefulWidget {
  const _AddSourceForm({required this.onCancel, required this.onAdded});
  final VoidCallback onCancel;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddSourceForm> createState() => _AddSourceFormState();
}

class _AddSourceFormState extends ConsumerState<_AddSourceForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  WalletSourceType _type = WalletSourceType.cash;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(walletProvider.notifier).addSource(
            name: _type == WalletSourceType.cash &&
                    _nameController.text.trim().isEmpty
                ? 'Cash'
                : _nameController.text.trim(),
            type: _type,
            balance: double.parse(_balanceController.text.trim()),
          );
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add source: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCash = _type == WalletSourceType.cash;
    return Card(
      elevation: 0,
      color: AppColors.cardBg(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider(isDark), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<WalletSourceType>(
                segments: const [
                  ButtonSegment(
                    value: WalletSourceType.cash,
                    label: Text('Cash'),
                    icon: Icon(Icons.payments_rounded),
                  ),
                  ButtonSegment(
                    value: WalletSourceType.bank,
                    label: Text('Bank'),
                    icon: Icon(Icons.account_balance_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: isCash ? 'Label (optional)' : 'Bank / account name',
                hint: isCash ? 'Cash' : 'e.g. HDFC ****1234',
                controller: _nameController,
                prefixIcon: isCash
                    ? Icons.label_outline_rounded
                    : Icons.account_balance_rounded,
                validator: (v) {
                  if (isCash) return null;
                  if ((v ?? '').trim().isEmpty) {
                    return 'Account name required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Available balance',
                hint: '0.00',
                controller: _balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.currency_rupee_rounded,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _handleSave,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
