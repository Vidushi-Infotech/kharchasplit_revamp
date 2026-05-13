import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../components/buttons/primary_button.dart';
import '../../../components/inputs/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/wallet_source_model.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../state/personal_expenses_provider.dart';
import '../state/wallet_provider.dart';
import '../widgets/wallet_setup_sheet.dart';

class AddPersonalExpenseScreen extends ConsumerStatefulWidget {
  const AddPersonalExpenseScreen({super.key});

  @override
  ConsumerState<AddPersonalExpenseScreen> createState() =>
      _AddPersonalExpenseScreenState();
}

class _AddPersonalExpenseScreenState
    extends ConsumerState<AddPersonalExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  CategoryModel _category = CategoryModel.other;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _submitting = false;
  String? _selectedSourceId;

  DateTime get _dateTime => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final wallet = ref.read(walletProvider).value ?? WalletState.empty;
    if (wallet.sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set up your wallet first.')),
      );
      return;
    }
    final sourceId = _selectedSourceId ??
        (wallet.sources.length == 1 ? wallet.sources.first.id : null);
    if (sourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a source to pay from.')),
      );
      return;
    }
    final amount = double.parse(_amountController.text.trim());

    setState(() => _submitting = true);
    try {
      final created =
          await ref.read(personalExpensesProvider.notifier).addExpense(
                description: _titleController.text.trim(),
                amount: amount,
                currency: 'INR',
                category: _category.id,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
                expenseDate: _dateTime,
              );
      // Deduct from the chosen wallet source AFTER the backend save succeeds.
      await ref.read(walletProvider.notifier).deductForExpense(
            sourceId: sourceId,
            expenseId: created.id,
            amount: amount,
          );
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Personal expense added')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxFormWidth = screenWidth < 600
        ? double.infinity
        : screenWidth < 1100
            ? 560.0
            : 720.0;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Add Personal Expense'),
        backgroundColor: AppColors.surface(isDark),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 20 : 32, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Amount',
                      hint: '0.00',
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: Icons.currency_rupee_rounded,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) {
                          return 'Enter an amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Description',
                      hint: 'e.g. Coffee, Fuel, Subscription',
                      controller: _titleController,
                      prefixIcon: Icons.edit_note_rounded,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _SourcePicker(
                      selectedId: _selectedSourceId,
                      onChanged: (id) =>
                          setState(() => _selectedSourceId = id),
                    ),
                    const SizedBox(height: 16),
                    _CategoryPicker(
                      value: _category,
                      onChanged: (c) => setState(() => _category = c),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerTile(
                            date: _date,
                            onTap: _pickDate,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimePickerTile(
                            time: _time,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Notes (optional)',
                      hint: 'Any extra context',
                      controller: _notesController,
                      maxLines: 3,
                      minLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: 'Save Expense',
                        onPressed: _submitting ? null : _handleSave,
                        isLoading: _submitting,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onChanged});
  final CategoryModel value;
  final ValueChanged<CategoryModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Category',
            style: AppTextStyles.body2(isDark)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CategoryModel.all.map((c) {
            final selected = c.id == value.id;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.icon,
                      size: 16,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary(isDark)),
                  const SizedBox(width: 4),
                  Text(c.name),
                ],
              ),
              selected: selected,
              onSelected: (_) => onChanged(c),
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : AppColors.textPrimary(isDark),
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SourcePicker extends ConsumerWidget {
  const _SourcePicker({required this.selectedId, required this.onChanged});

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallet = ref.watch(walletProvider).value ?? WalletState.empty;

    if (wallet.sources.isEmpty) {
      return Card(
        elevation: 0,
        color: AppColors.cardBg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No wallet sources yet',
                  style: AppTextStyles.body1(isDark)
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Add a cash or bank source to track this expense against your balance.',
                style: AppTextStyles.caption(isDark),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => WalletSetupSheet.show(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Set up wallet'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Auto-pick the only source.
    if (wallet.sources.length == 1 && selectedId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChanged(wallet.sources.first.id);
      });
    }
    final activeId = selectedId ?? wallet.sources.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Pay from',
            style: AppTextStyles.body2(isDark)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: wallet.sources.map((s) {
            final selected = s.id == activeId;
            final lowBalance = s.balance <= 0;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.type == WalletSourceType.bank
                        ? Icons.account_balance_rounded
                        : Icons.payments_rounded,
                    size: 14,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 6),
                  Text(s.name),
                  const SizedBox(width: 6),
                  Text(
                    CurrencyFormatter.format(s.balance, currency: '₹'),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (lowBalance
                              ? AppColors.errorText(isDark)
                              : AppColors.textSecondary(isDark)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              selected: selected,
              onSelected: (_) => onChanged(s.id),
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : AppColors.textPrimary(isDark),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.date,
    required this.onTap,
    required this.isDark,
  });
  final DateTime date;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: const Icon(Icons.event_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(DateFormat('MMM d, yyyy').format(date)),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({required this.time, required this.onTap});
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Time',
          prefixIcon: const Icon(Icons.schedule_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(time.format(context)),
      ),
    );
  }
}
