import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/wallet_source_model.dart';
import '../state/wallet_provider.dart';

/// Bottom sheet for managing wallet sources.
/// - Lists existing sources with edit / delete
/// - "Add source" reveals an inline add-form (cash or bank)
class WalletSetupSheet extends ConsumerStatefulWidget {
  const WalletSetupSheet({super.key});

  static Future<void> show(BuildContext context) {
    // DraggableScrollableSheet inside — must stay a bottom sheet. Capped so
    // it does not stretch across a desktop window.
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: context.widthTier.isWebTier
          ? const BoxConstraints(maxWidth: 720)
          : null,
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
    final hasSources = wallet.sources.isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background(isDark),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Manage wallet',
                              style: AppTextStyles.body1(isDark).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (hasSources) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${wallet.sources.length} ${wallet.sources.length == 1 ? 'source' : 'sources'} · '
                                'Available ${CurrencyFormatter.format(wallet.totalAvailable, currency: '₹')}',
                                style: AppTextStyles.caption(isDark).copyWith(
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cardBg(isDark),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.divider(isDark),
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      if (!hasSources && !_showAddForm)
                        _Empty(
                          isDark: isDark,
                          onAdd: () => setState(() => _showAddForm = true),
                        )
                      else if (hasSources) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 8),
                          child: Text(
                            'SOURCES',
                            style: AppTextStyles.caption(isDark).copyWith(
                              color: AppColors.textSecondary(isDark),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        _SourcesCard(
                          sources: wallet.sources,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_showAddForm)
                        _AddSourceForm(
                          isDark: isDark,
                          onCancel: () => setState(() => _showAddForm = false),
                          onAdded: () => setState(() => _showAddForm = false),
                        )
                      else if (hasSources)
                        _AddSourceButton(
                          isDark: isDark,
                          onTap: () => setState(() => _showAddForm = true),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isDark, required this.onAdd});
  final bool isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 28,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Set up your wallet',
            style: AppTextStyles.headline3(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Add cash or a bank account to track what's available "
            'before you log expenses.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _GradientButton(
            isDark: isDark,
            label: 'Add a source',
            icon: Icons.add_rounded,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.sources, required this.isDark});

  final List<WalletSource> sources;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sources.length; i++) ...[
            _SourceRow(source: sources[i], isDark: isDark),
            if (i < sources.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.source, required this.isDark});
  final WalletSource source;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCash = source.type == WalletSourceType.cash;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppColors.tealDark.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              isCash
                  ? Icons.payments_rounded
                  : Icons.account_balance_rounded,
              size: 18,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  source.name,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isCash ? 'Cash' : 'Bank account',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(source.balance, currency: '₹'),
            style: AppTextStyles.body1(isDark).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit balance',
            onPressed: () => _editBalance(context, ref),
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            onPressed: () => _confirmRemove(context, ref),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBalance(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: source.balance.toStringAsFixed(2));
    final newBalance = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark =
            Theme.of(sheetContext).brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background(isDark),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.divider(isDark)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.divider(isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Edit balance',
                    style: AppTextStyles.body1(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.name,
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: AppTextStyles.body1(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardBg(isDark),
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.currency_rupee_rounded,
                        size: 18,
                        color: AppColors.textSecondary(isDark),
                      ),
                      hintText: 'New balance',
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.divider(isDark)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.divider(isDark)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              AppColors.tealDark.withValues(alpha: 0.45),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                AppColors.textPrimary(isDark),
                            side: BorderSide(
                              color: AppColors.divider(isDark),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GradientButton(
                          isDark: isDark,
                          label: 'Save',
                          icon: Icons.check_rounded,
                          onTap: () {
                            final v =
                                double.tryParse(controller.text.trim());
                            if (v != null && v >= 0) {
                              Navigator.of(sheetContext).pop(v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (newBalance != null) {
      await ref
          .read(walletProvider.notifier)
          .editSource(source.id, balance: newBalance);
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final wallet = ref.read(walletProvider).value ?? WalletState.empty;
    final taggedCount =
        wallet.expenseSourceMap.values.where((v) => v == source.id).length;

    if (taggedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.errorText(isDark),
            ),
            title: const Text("Can't delete this source"),
            content: Text(
              '${source.name} has $taggedCount expense'
              '${taggedCount == 1 ? '' : 's'} tagged to it. '
              'Delete those expenses first, then try again.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        title: Text('Remove ${source.name}?'),
        content: const Text(
          'This source will be removed from your wallet. You can add it '
          'back any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
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

class _AddSourceButton extends StatelessWidget {
  const _AddSourceButton({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add another wallet source',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.tealDark.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.tealDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add another source',
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _AddSourceForm extends ConsumerStatefulWidget {
  const _AddSourceForm({
    required this.isDark,
    required this.onCancel,
    required this.onAdded,
  });
  final bool isDark;
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
        SnackBar(
          content: Text('Could not add source: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isCash = _type == WalletSourceType.cash;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      padding: const EdgeInsets.all(14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'NEW SOURCE',
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  fontSize: 11,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    isDark: isDark,
                    label: 'Cash',
                    icon: Icons.payments_rounded,
                    selected: _type == WalletSourceType.cash,
                    onTap: () => setState(() => _type = WalletSourceType.cash),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeButton(
                    isDark: isDark,
                    label: 'Bank',
                    icon: Icons.account_balance_rounded,
                    selected: _type == WalletSourceType.bank,
                    onTap: () => setState(() => _type = WalletSourceType.bank),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                isDark,
                hint: isCash ? 'Label (optional, e.g. Cash)' : 'e.g. HDFC ****1234',
                icon: isCash
                    ? Icons.label_outline_rounded
                    : Icons.account_balance_rounded,
              ),
              validator: (v) {
                if (isCash) return null;
                if ((v ?? '').trim().isEmpty) {
                  return 'Account name required';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: _inputDecoration(
                isDark,
                hint: 'Available balance · 0.00',
                icon: Icons.currency_rupee_rounded,
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(isDark),
                      side: BorderSide(color: AppColors.divider(isDark)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GradientButton(
                    isDark: isDark,
                    label: _saving ? 'Adding…' : 'Add',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onTap: _saving ? null : _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    bool isDark, {
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface(isDark),
      isDense: true,
      hintText: hint,
      hintStyle: AppTextStyles.body2(isDark).copyWith(
        color: AppColors.textSecondary(isDark),
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: AppColors.textSecondary(isDark),
      ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 40, minHeight: 40),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.tealDark.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.warning),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.warning, width: 1.4),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final bool isDark;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.tealDark : AppColors.textPrimary(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.tealDark.withValues(alpha: 0.10)
                : AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.tealDark.withValues(alpha: 0.45)
                  : AppColors.divider(isDark),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body1(isDark).copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final bool isDark;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.tealLight, AppColors.tealDark],
                  )
                : null,
            color: enabled ? null : AppColors.cardBg(isDark),
            border: enabled
                ? null
                : Border.all(color: AppColors.divider(isDark)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.tealDark.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: enabled
                          ? Colors.white
                          : AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
