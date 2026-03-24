import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/invoice_scanner_service.dart';
import '../../../models/category_model.dart';
import '../state/add_expense_provider.dart';
import '../widgets/amount_input_widget.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/split_selector_widget.dart';
import '../widgets/invoice_upload_widget.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const AddExpenseScreen({Key? key, this.groupId}) : super(key: key);

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final expenseState = ref.watch(addExpenseProvider);

    // Responsive layout decision based on CLAUDE.md section 5
    if (screenWidth < 600) {
      return _buildCompactLayout(context, isDark, expenseState);
    } else if (screenWidth < 1100) {
      return _buildStandardLayout(context, isDark, expenseState);
    } else {
      return _buildLargeLayout(context, isDark, expenseState);
    }
  }

  // Compact: <600px - Mobile layout (16-20px padding)
  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    AddExpenseState state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Add Expense'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        leading: Semantics(
          button: true,
          label: 'Close',
          onTap: () => context.pop(),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              _buildInvoiceSection(isDark, state),
              const SizedBox(height: 24),
              _buildAmountSection(isDark, state),
              const SizedBox(height: 20),
              _buildDescriptionSection(isDark),
              const SizedBox(height: 20),
              _buildCategorySection(isDark, state),
              const SizedBox(height: 20),
              _buildDateSection(isDark, state),
              const SizedBox(height: 20),
              _buildSplitSection(isDark, state),
              const SizedBox(height: 20),
              _buildNotesSection(isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(isDark, state),
    );
  }

  // Standard: 600-1100px - Tablet layout (24-32px padding)
  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    AddExpenseState state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Add Expense'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _buildInvoiceSection(isDark, state),
                  const SizedBox(height: 28),
                  _buildAmountSection(isDark, state),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(isDark),
                  const SizedBox(height: 24),
                  _buildCategorySection(isDark, state),
                  const SizedBox(height: 24),
                  _buildDateSection(isDark, state),
                  const SizedBox(height: 24),
                  _buildSplitSection(isDark, state),
                  const SizedBox(height: 24),
                  _buildNotesSection(isDark),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(isDark, state),
    );
  }

  // Large: >1100px - Desktop layout (32-48px padding)
  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    AddExpenseState state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Add Expense'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildInvoiceSection(isDark, state),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildAmountSection(isDark, state),
                            const SizedBox(height: 28),
                            _buildDescriptionSection(isDark),
                            const SizedBox(height: 28),
                            _buildCategorySection(isDark, state),
                            const SizedBox(height: 28),
                            _buildDateSection(isDark, state),
                            const SizedBox(height: 28),
                            _buildSplitSection(isDark, state),
                            const SizedBox(height: 28),
                            _buildNotesSection(isDark),
                            const SizedBox(height: 32),
                            _buildSaveButtonLarge(isDark, state),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Invoice upload section - first step in streamlined flow
  Widget _buildInvoiceSection(bool isDark, AddExpenseState state) {
    return Semantics(
      label: 'Invoice upload section',
      child: InvoiceUploadWidget(
        onImageSelected: (imagePath, file) {
          ref
              .read(addExpenseProvider.notifier)
              .state = state.copyWith(invoiceImagePath: imagePath);
        },
        onProcessing: () {
          ref.read(addExpenseProvider.notifier).state =
              state.copyWith(isScanning: true);
        },
        onComplete: () async {
          // Mock invoice scanning
          if (state.invoiceImagePath != null) {
            final result = await InvoiceScannerService.scanInvoiceImage(
              state.invoiceImagePath!,
            );

            if (mounted) {
              ref.read(addExpenseProvider.notifier).state = state.copyWith(
                amount: result.amount,
                category: CategoryModel(
                  id: result.category,
                  name: result.category,
                  icon: Icons.receipt_long_rounded,
                  colorHex: '#FF6B6B',
                ),
                date: result.date,
                title: result.description,
                isScanning: false,
                invoiceScanned: true,
              );
            }
          }
        },
        isLoading: state.isScanning,
      ),
    );
  }

  Widget _buildAmountSection(bool isDark, AddExpenseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Amount input field',
          child: Text(
            'Amount',
            style: AppTextStyles.body2(isDark),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label:
              'Enter amount in ${state.currency}, currently ${CurrencyFormatter.format(state.amount)}',
          child: AmountInputWidget(
            amount: state.amount,
            currency: state.currency,
            onChanged: (amount) {
              ref.read(addExpenseProvider.notifier).state =
                  state.copyWith(amount: amount);
            },
          ),
        ),
        if (state.invoiceScanned && state.amount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Auto-detected from invoice',
                  style: AppTextStyles.caption(isDark)
                      .copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What was this for?', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Dinner, movie, groceries...',
            filled: true,
            fillColor: AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
            ),
          ),
          onChanged: (value) {
            ref.read(addExpenseProvider.notifier).state =
                ref.read(addExpenseProvider).copyWith(title: value);
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection(bool isDark, AddExpenseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Category selector',
          child: Text('Category', style: AppTextStyles.body2(isDark)),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label:
              'Select category, currently ${state.category?.name ?? 'None selected'}',
          child: CategorySelectorWidget(
            selectedCategory: state.category,
            onCategorySelected: (category) {
              ref.read(addExpenseProvider.notifier).state =
                  state.copyWith(category: category);
            },
          ),
        ),
        if (state.invoiceScanned && state.category != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Auto-detected from invoice',
                  style: AppTextStyles.caption(isDark)
                      .copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateSection(bool isDark, AddExpenseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.date,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ref.read(addExpenseProvider.notifier).state =
                  state.copyWith(date: picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.inputBorder(isDark)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.date.toString().split(' ')[0],
                  style: AppTextStyles.body2(isDark),
                ),
                const Icon(Icons.calendar_today_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitSection(bool isDark, AddExpenseState state) {
    return SplitSelectorWidget(
      splitType: state.splitType,
      amount: state.amount,
      onSplitTypeChanged: (type) {
        ref.read(addExpenseProvider.notifier).state =
            state.copyWith(splitType: type);
      },
    );
  }

  Widget _buildNotesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes (optional)', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add any details...',
            filled: true,
            fillColor: AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
            ),
          ),
          onChanged: (value) {
            ref.read(addExpenseProvider.notifier).state =
                ref.read(addExpenseProvider).copyWith(notes: value);
          },
        ),
      ],
    );
  }

  // Save button for mobile/tablet
  Widget _buildSaveButton(bool isDark, AddExpenseState state) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Semantics(
        button: true,
        label: 'Save expense button',
        enabled: state.isValid,
        onTap: state.isValid ? () => _handleSave() : null,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: state.isValid ? () => _handleSave() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              disabledBackgroundColor: AppColors.textSecondary(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save Expense',
              style: AppTextStyles.body2(isDark).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Save button for desktop
  Widget _buildSaveButtonLarge(bool isDark, AddExpenseState state) {
    return Semantics(
      button: true,
      label: 'Save expense button',
      enabled: state.isValid,
      onTap: state.isValid ? () => _handleSave() : null,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: state.isValid ? () => _handleSave() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            disabledBackgroundColor: AppColors.textSecondary(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Save Expense',
            style: AppTextStyles.body2(isDark).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    // TODO: Save expense to backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Expense saved successfully!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
    GoRouter.of(context).pop();
  }
}
