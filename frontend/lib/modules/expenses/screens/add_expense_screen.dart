import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/invoice_scanner_service.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/dashboard/state/dashboard_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../../../modules/groups/state/groups_provider.dart';
import '../state/add_expense_provider.dart';
import '../widgets/amount_input_widget.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/split_selector_widget.dart';
import '../widgets/invoice_upload_widget.dart';
import '../widgets/split_breakdown_widget.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const AddExpenseScreen({Key? key, this.groupId}) : super(key: key);

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _equalSplitSearchController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _equalSplitSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _equalSplitSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final expenseState = ref.watch(addExpenseProvider);

    // Initialize with groupId if provided and not already set
    if (widget.groupId != null && expenseState.groupId != widget.groupId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addExpenseProvider.notifier).state =
            expenseState.copyWith(groupId: widget.groupId);
      });
    }

    // Get group members if groupId is set
    final groupAsync = expenseState.groupId != null
        ? ref.watch(groupDetailProvider(expenseState.groupId!))
        : null;
    final List<UserModel> groupMembers =
        groupAsync?.value?.members ?? [];

    // Auto-initialize or recalculate splits for equal split
    if (expenseState.splitType == SplitType.equal && groupMembers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Initialize with all members included by default
        Set<String> includedIds = expenseState.includedMemberIds;
        if (includedIds.isEmpty) {
          includedIds = Set<String>.from(groupMembers.map((m) => m.id));
        }

        if (expenseState.amount > 0) {
          final includedCount = includedIds.length;
          final equalShare = includedCount > 0
              ? (expenseState.amount / includedCount).toDouble()
              : 0.0;
          final newSplits = <String, double>{};

          // Calculate splits for included members only
          for (final member in groupMembers) {
            if (includedIds.contains(member.id)) {
              newSplits[member.id] = equalShare;
            } else {
              newSplits[member.id] = 0;
            }
          }

          // Update if splits or includedMemberIds changed
          if (newSplits != expenseState.splits ||
              includedIds != expenseState.includedMemberIds) {
            ref.read(addExpenseProvider.notifier).state = expenseState.copyWith(
              splits: newSplits,
              includedMemberIds: includedIds,
            );
          }
        } else if (includedIds != expenseState.includedMemberIds) {
          // Initialize includedMemberIds even if amount is 0
          ref.read(addExpenseProvider.notifier).state =
              expenseState.copyWith(includedMemberIds: includedIds);
        }
      });
    }

    // Responsive layout decision based on CLAUDE.md section 5
    if (screenWidth < 600) {
      return _buildCompactLayout(context, isDark, expenseState, groupMembers);
    } else if (screenWidth < 1100) {
      return _buildStandardLayout(context, isDark, expenseState, groupMembers);
    } else {
      return _buildLargeLayout(context, isDark, expenseState, groupMembers);
    }
  }

  // Compact: <600px - Mobile layout (16-20px padding)
  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeScreen();
      },
      child: Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        title: 'Add expense',
        onClose: _closeScreen,
        isDark: isDark,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                _buildInvoiceSection(isDark, state),
                const SizedBox(height: 24),
                _buildAmountSection(isDark, state),
                const SizedBox(height: 20),
                _buildMemberSection(isDark, state, groupMembers),
                const SizedBox(height: 20),
                _buildDescriptionSection(isDark),
                const SizedBox(height: 20),
                _buildCategorySection(isDark, state),
                const SizedBox(height: 20),
                _buildDateSection(isDark, state),
                const SizedBox(height: 20),
                _buildSplitSection(isDark, state),
                const SizedBox(height: 12),
                _buildSplitBreakdownSection(isDark, state, groupMembers),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(isDark, state),
      ),
    );
  }

  // Standard: 600-1100px - Tablet layout (24-32px padding)
  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        title: 'Add expense',
        onClose: _closeScreen,
        isDark: isDark,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
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
                    _buildMemberSection(isDark, state, groupMembers),
                    const SizedBox(height: 24),
                    _buildDescriptionSection(isDark),
                    const SizedBox(height: 24),
                    _buildCategorySection(isDark, state),
                    const SizedBox(height: 24),
                    _buildDateSection(isDark, state),
                    const SizedBox(height: 24),
                    _buildSplitSection(isDark, state),
                    const SizedBox(height: 12),
                    _buildSplitBreakdownSection(isDark, state, groupMembers),
                    const SizedBox(height: 120),
                  ],
                ),
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
    List<UserModel> groupMembers,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        title: 'Add expense',
        onClose: _closeScreen,
        isDark: isDark,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Invoice section
                        Expanded(
                          flex: 1,
                          child: _buildInvoiceSection(isDark, state),
                        ),
                        const SizedBox(width: 48),
                        // Right: Form fields stacked vertically
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildAmountSection(isDark, state),
                                const SizedBox(height: 20),
                                _buildMemberSection(isDark, state, groupMembers),
                                const SizedBox(height: 20),
                                _buildDescriptionSection(isDark),
                                const SizedBox(height: 20),
                                _buildCategorySection(isDark, state),
                                const SizedBox(height: 20),
                                _buildDateSection(isDark, state),
                                const SizedBox(height: 20),
                                _buildSplitSection(isDark, state),
                                const SizedBox(height: 12),
                                _buildSplitBreakdownSection(isDark, state, groupMembers),
                                const SizedBox(height: 32),
                                _buildSaveButtonLarge(isDark, state),
                              ],
                            ),
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
        _SectionTitle(label: 'AMOUNT', isDark: isDark),
        const SizedBox(height: 10),
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
        _SectionTitle(label: 'DESCRIPTION', isDark: isDark),
        const SizedBox(height: 10),
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
        _SectionTitle(label: 'CATEGORY', isDark: isDark),
        const SizedBox(height: 10),
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
        _SectionTitle(label: 'DATE', isDark: isDark),
        const SizedBox(height: 10),
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

  Widget _buildSplitBreakdownSection(bool isDark, AddExpenseState state, List<UserModel> members) {
    // Hide if no group selected
    if (state.groupId == null || members.isEmpty) {
      return const SizedBox.shrink();
    }

    // For equal split, show member selection list
    if (state.splitType == SplitType.equal) {
      final includedMembers = state.includedMemberIds.length;
      final searchQuery = _equalSplitSearchController.text.toLowerCase();
      final filteredMembers = members
          .where((m) => m.name.toLowerCase().contains(searchQuery))
          .toList();
      final totalIncluded = state.splits.entries
          .where((e) => state.includedMemberIds.contains(e.key))
          .fold<double>(0, (sum, e) => sum + e.value);

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background(isDark),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Split Breakdown ($includedMembers members)',
                      style: AppTextStyles.body2(isDark)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '✓ Balanced',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search box
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _equalSplitSearchController,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
                  prefixIcon: Icon(Icons.search, color: AppColors.brand, size: 20),
                  suffixIcon: _equalSplitSearchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _equalSplitSearchController.clear();
                            setState(() {});
                          },
                          child: Icon(Icons.close, color: AppColors.brand, size: 20),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            // Select All / Deselect All buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(addExpenseProvider.notifier).state = state.copyWith(
                        includedMemberIds: Set<String>.from(members.map((m) => m.id)),
                      );
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Select All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(addExpenseProvider.notifier).state =
                          state.copyWith(includedMemberIds: <String>{});
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Deselect All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Filtered members list
            Column(
              children: filteredMembers
                  .map((member) => _buildMemberEqualSplitRow(isDark, state, member))
                  .toList(),
            ),
            const Divider(height: 1),
            // Footer with total
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Included',
                    style: AppTextStyles.body2(isDark),
                  ),
                  Text(
                    '₹${totalIncluded.toStringAsFixed(2)}',
                    style: AppTextStyles.body2(isDark)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For other split types, show full breakdown widget
    return SplitBreakdownWidget(
      splitType: state.splitType,
      totalAmount: state.amount,
      members: members,
      splits: state.splits,
      includedMemberIds: state.includedMemberIds,
      onSplitsChanged: (splits) {
        ref.read(addExpenseProvider.notifier).state =
            state.copyWith(splits: splits);
      },
      onIncludedMembersChanged: (includedIds) {
        ref.read(addExpenseProvider.notifier).state =
            state.copyWith(includedMemberIds: includedIds);
      },
    );
  }

  Widget _buildMemberEqualSplitRow(
    bool isDark,
    AddExpenseState state,
    UserModel member,
  ) {
    final isIncluded = state.includedMemberIds.contains(member.id);
    final splitAmount = state.splits[member.id] ?? 0.0;

    return GestureDetector(
      onTap: () {
        final newSet = Set<String>.from(state.includedMemberIds);
        if (newSet.contains(member.id)) {
          newSet.remove(member.id);
        } else {
          newSet.add(member.id);
        }
        ref.read(addExpenseProvider.notifier).state =
            state.copyWith(includedMemberIds: newSet);
      },
      child: Container(
        color: isIncluded
            ? Colors.transparent
            : AppColors.textSecondary(isDark).withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: isIncluded,
              tristate: false,
              onChanged: (_) {
                final newSet = Set<String>.from(state.includedMemberIds);
                if (newSet.contains(member.id)) {
                  newSet.remove(member.id);
                } else {
                  newSet.add(member.id);
                }
                ref.read(addExpenseProvider.notifier).state =
                    state.copyWith(includedMemberIds: newSet);
              },
              activeColor: AppColors.brand,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brand.withValues(alpha: 0.2),
              child: Text(
                member.name.split(' ').map((e) => e[0]).join().toUpperCase(),
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: isIncluded
                          ? AppColors.textPrimary(isDark)
                          : AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isIncluded ? '✓ Selected' : '○ Not selected',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: isIncluded ? AppColors.success : AppColors.textSecondary(isDark),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Split amount
            if (isIncluded)
              Text(
                '₹${splitAmount.toStringAsFixed(2)}',
                style: AppTextStyles.body2(isDark).copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSection(bool isDark, AddExpenseState state, List<UserModel> groupMembers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: 'PAID BY', isDark: isDark),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Select member who paid',
          onTap: () => _showMemberPicker(context, isDark, state, groupMembers),
          child: GestureDetector(
            onTap: () => _showMemberPicker(context, isDark, state, groupMembers),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.inputBorder(isDark)),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.inputFill(isDark),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                    child: Text(
                      (state.expenseFor?.name ?? 'M')[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.expenseFor?.name ?? 'Me',
                      style: AppTextStyles.body2(isDark),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMemberPicker(BuildContext context, bool isDark, AddExpenseState state, List<UserModel> groupMembers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Who paid?',
                style: AppTextStyles.headline3(isDark),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildMemberListItem(
                    isDark,
                    'Me',
                    'M',
                    isSelected: state.expenseFor == null,
                    onTap: () {
                      ref.read(addExpenseProvider.notifier).state =
                          state.copyWith(expenseFor: null);
                      Navigator.pop(context);
                    },
                  ),
                  ...groupMembers.map((member) => _buildMemberListItem(
                    isDark,
                    member.name,
                    member.name.split(' ').map((e) => e[0]).join().toUpperCase(),
                    isSelected: state.expenseFor?.id == member.id,
                    onTap: () {
                      ref.read(addExpenseProvider.notifier).state =
                          state.copyWith(expenseFor: member);
                      Navigator.pop(context);
                    },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberListItem(
    bool isDark,
    String name,
    String initials,
    {required bool isSelected, required VoidCallback onTap}
  ) {
    return Semantics(
      button: true,
      label: '$name${isSelected ? ' - selected' : ''}',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: isSelected ? AppColors.brand.withValues(alpha: 0.05) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.body2(isDark),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: 'NOTES (OPTIONAL)', isDark: isDark),
        const SizedBox(height: 10),
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
    final enabled = state.isValid;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: Semantics(
          button: true,
          label: 'Save expense button',
          enabled: enabled,
          onTap: enabled ? _handleSave : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? _handleSave : null,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
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
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppColors.tealDark.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: enabled
                          ? Colors.white
                          : AppColors.textSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Save expense',
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary(isDark),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.1,
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

  Future<void> _handleSave() async {
    final state = ref.read(addExpenseProvider);
    if (state.groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a group before saving the expense.')),
      );
      return;
    }
    final groupId = state.groupId!;
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to save an expense.')),
      );
      return;
    }

    final groups = ref.read(groupsProvider).value ?? const <GroupModel>[];
    final group = groups
        .where((g) => g.id == groupId)
        .cast<GroupModel?>()
        .firstWhere((g) => true, orElse: () => null);
    final members = group?.members ?? const <UserModel>[];

    final paidBy = state.paidBy ??
        (members.where((m) => m.id == currentUser.id).isNotEmpty
            ? members.firstWhere((m) => m.id == currentUser.id)
            : UserModel(
                id: currentUser.id,
                name: currentUser.name,
                email: currentUser.email,
                phone: currentUser.phone,
                avatarUrl: currentUser.avatarUrl,
                createdAt: currentUser.createdAt,
              ));

    final memberById = {for (final m in members) m.id: m};
    final includedIds = state.includedMemberIds.isNotEmpty
        ? state.includedMemberIds.toList()
        : members.map((m) => m.id).toList();

    double shareFor(String id) {
      final raw = state.splits[id] ?? 0;
      switch (state.splitType) {
        case SplitType.equal:
          if (includedIds.isEmpty) return state.amount;
          return state.amount / includedIds.length;
        case SplitType.exact:
          return raw;
        case SplitType.percentage:
          return state.amount * raw / 100;
        case SplitType.shares:
          final totalShares = includedIds.fold<double>(
              0, (sum, mid) => sum + (state.splits[mid] ?? 0));
          if (totalShares <= 0) return 0;
          return state.amount * raw / totalShares;
        case SplitType.adjustment:
          final base = includedIds.isEmpty
              ? state.amount
              : state.amount / includedIds.length;
          return base + raw;
      }
    }

    // The backend's split_type CHECK constraint only accepts
    // ('equal', 'unequal', 'percentage', 'shares'). Map exact + adjustment
    // both to 'unequal' since we send concrete amounts in either case.
    String backendSplitType(SplitType t) {
      switch (t) {
        case SplitType.equal:
          return 'equal';
        case SplitType.percentage:
          return 'percentage';
        case SplitType.shares:
          return 'shares';
        case SplitType.exact:
        case SplitType.adjustment:
          return 'unequal';
      }
    }

    final participants = includedIds.isEmpty
        ? [
            ExpenseParticipant(
              userId: paidBy.id,
              name: paidBy.name,
              amount: state.amount,
            ),
          ]
        : includedIds.map((id) {
            final member = memberById[id];
            return ExpenseParticipant(
              userId: id,
              name: member?.name ?? id,
              amount: shareFor(id),
            );
          }).toList();

    ref.read(addExpenseProvider.notifier).state =
        state.copyWith(isLoading: true, error: null);

    try {
      await ref.read(expensesRepositoryProvider).create(
            groupId: groupId,
            description: (state.title == null || state.title!.trim().isEmpty)
                ? 'Untitled'
                : state.title!.trim(),
            amount: state.amount,
            currency: state.currency,
            category: (state.category ?? CategoryModel.other).id,
            paidById: paidBy.id,
            paidByName: paidBy.name,
            splitType: backendSplitType(state.splitType),
            notes: state.notes,
            expenseDate: state.date,
            participants: participants,
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(addExpenseProvider.notifier).state =
          state.copyWith(isLoading: false, error: e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save expense: $e')),
      );
      return;
    }

    ref.invalidate(dashboardProvider);
    ref.invalidate(groupDetailProvider(groupId));

    if (!mounted) return;
    ref.read(addExpenseProvider.notifier).state =
        AddExpenseState(date: DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Expense saved'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
    _closeScreen();
  }

  void _closeScreen() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/home/dashboard');
    }
  }
}

/// Uppercase overline-style label used as a section header in the form.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        label,
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Custom top bar — back arrow + title, no Material elevation, sits flush
/// against the background for a clean modern feel.
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.title,
    required this.onClose,
    required this.isDark,
  });

  final String title;
  final VoidCallback onClose;
  final bool isDark;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Close',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onClose,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
