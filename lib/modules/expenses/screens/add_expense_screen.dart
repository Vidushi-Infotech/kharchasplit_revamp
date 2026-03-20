import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/components.dart';
import '../state/add_expense_provider.dart';
import '../widgets/amount_input_widget.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/split_selector_widget.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Add Expense'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: screenWidth < 600
          ? _buildMobileLayout(isDark, expenseState)
          : _buildWideLayout(isDark, expenseState),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: expenseState.isValid ? () => _handleSave() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              disabledBackgroundColor: AppColors.textSecondary(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save Expense',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark, AddExpenseState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isDark, AddExpenseState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              _buildAmountSection(isDark, state),
              const SizedBox(height: 32),
              _buildDescriptionSection(isDark),
              const SizedBox(height: 24),
              _buildCategorySection(isDark, state),
              const SizedBox(height: 24),
              _buildDateSection(isDark, state),
              const SizedBox(height: 24),
              _buildSplitSection(isDark, state),
              const SizedBox(height: 24),
              _buildNotesSection(isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection(bool isDark, AddExpenseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amount', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        AmountInputWidget(
          amount: state.amount,
          currency: state.currency,
          onChanged: (amount) {
            ref
                .read(addExpenseProvider.notifier)
                .state = state.copyWith(amount: amount);
          },
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
        Text('Category', style: AppTextStyles.body2(isDark)),
        const SizedBox(height: 12),
        CategorySelectorWidget(
          selectedCategory: state.category,
          onCategorySelected: (category) {
            ref.read(addExpenseProvider.notifier).state =
                state.copyWith(category: category);
          },
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

  void _handleSave() {
    // TODO: Save expense to backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense saved!')),
    );
    GoRouter.of(context).pop();
  }
}
