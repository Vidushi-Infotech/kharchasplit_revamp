import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../components/avatar/avatar_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/dashboard/state/dashboard_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../../../modules/groups/state/groups_provider.dart';
import '../state/add_expense_provider.dart';
import '../state/expense_detail_provider.dart';
import '../widgets/amount_input_widget.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/split_selector_widget.dart';
import '../widgets/invoice_upload_widget.dart';
import '../widgets/split_breakdown_widget.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;

  /// When non-null, the screen runs in edit mode: it loads the existing
  /// expense, hydrates the form, and PUTs to /expenses/:id on save instead
  /// of POSTing a new one. The title bar also reads "Edit expense".
  final String? expenseId;

  const AddExpenseScreen({Key? key, this.groupId, this.expenseId})
      : super(key: key);

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _equalSplitSearchController;
  late ScrollController _scrollController;

  /// Anchor key on the split-breakdown section. Used by [_scrollToBreakdown]
  /// to slide the breakdown into view after the user picks Exact/%/Shares.
  final GlobalKey _breakdownKey = GlobalKey();

  /// Latch — set once the widget.groupId has been pushed into state. Stops
  /// the build() loop from re-scheduling the same write every frame.
  bool _groupIdSynced = false;

  /// Debounce on the title TextField. Each keystroke previously wrote
  /// straight to the provider, which rebuilds the entire 1300-line screen
  /// (split breakdown, member list, etc.) — visible lag on lower-end
  /// devices. 200 ms collapses a typed word into one rebuild.
  Timer? _titleDebounce;

  /// Edit-mode latches.
  ///   _hydrating    — true while the initial GET /expenses/:id is in flight;
  ///                   used to show the spinner overlay and block save.
  ///   _hydrateError — last hydration failure (rendered as inline error).
  bool _hydrating = false;
  String? _hydrateError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _equalSplitSearchController = TextEditingController();
    _scrollController = ScrollController();

    if (widget.isEditing) {
      _hydrating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromExpense());
    }
  }

  /// Fetch the existing expense and seed [addExpenseProvider] + the text
  /// controllers. Runs exactly once on entry to edit mode.
  Future<void> _hydrateFromExpense() async {
    final id = widget.expenseId;
    if (id == null) return;
    try {
      final expense = await ref.read(expensesRepositoryProvider).getById(id);
      if (!mounted) return;

      // Build the splits map in the same shape AddExpenseState uses:
      //   equal/exact → amount, percentage → percent, shares → share count.
      // includedMemberIds is everyone with a non-zero entry.
      final splits = <String, double>{};
      final included = <String>{};
      for (final s in expense.splits) {
        double value;
        switch (expense.splitType) {
          case SplitType.percentage:
            value = s.percentage;
            break;
          case SplitType.shares:
            value = s.shares;
            break;
          case SplitType.exact:
          case SplitType.equal:
            value = s.owedShare;
            break;
        }
        splits[s.userId] = value;
        if (value > 0) included.add(s.userId);
      }

      _titleController.text = expense.title;
      _notesController.text = expense.notes ?? '';

      ref.read(addExpenseProvider.notifier).state = AddExpenseState(
        title: expense.title,
        amount: expense.amount,
        currency: expense.currency,
        category: expense.category,
        paidBy: expense.paidBy,
        splitType: expense.splitType,
        splits: splits,
        includedMemberIds: included,
        date: expense.date,
        notes: expense.notes,
        groupId: expense.groupId,
        receiptBase64: expense.receiptBase64,
      );

      setState(() {
        _hydrating = false;
        // Edit mode reuses the equal-split auto-recalc path; setting the
        // groupId-synced latch prevents the build() block from re-pushing
        // widget.groupId (which is null in edit mode) over the loaded value.
        _groupIdSynced = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hydrating = false;
        _hydrateError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    _equalSplitSearchController.dispose();
    _scrollController.dispose();
    // Edit mode hydrates the shared provider with the expense being edited.
    // If the user pops without saving, that hydrated state would otherwise
    // bleed into the next Add Expense session — reset it on exit.
    if (widget.isEditing) {
      Future.microtask(() {
        ref.read(addExpenseProvider.notifier).state =
            AddExpenseState(date: DateTime.now());
      });
    }
    super.dispose();
  }

  void _scrollToBreakdown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _breakdownKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Edit mode short-circuits: spinner while the GET is in flight, error
    // page with retry if it failed. We never show the half-empty form.
    if (widget.isEditing && (_hydrating || _hydrateError != null)) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: _TopBar(
          title: 'Edit expense',
          onClose: _closeScreen,
          isDark: isDark,
        ),
        body: Center(
          child: _hydrateError != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load expense',
                        style: AppTextStyles.body1(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hydrateError!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hydrateError = null;
                            _hydrating = true;
                          });
                          _hydrateFromExpense();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final expenseState = ref.watch(addExpenseProvider);

    // Initialise expense.groupId from the route param exactly once.
    // The latch prevents re-scheduling the same write every rebuild even if
    // the comparison briefly regresses (e.g. provider invalidation).
    if (!_groupIdSynced &&
        widget.groupId != null &&
        expenseState.groupId != widget.groupId) {
      _groupIdSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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

    // Auto-initialise / recalculate splits for equal split.
    //
    // Critically: change-detection uses STRUCTURAL equality (`mapEquals`,
    // `setEquals`). Map/Set use reference equality by default, so the old
    // `newSplits != expenseState.splits` always evaluated true and scheduled
    // a state write every frame (= permanent rebuild loop, ~60 writes/sec).
    if (expenseState.splitType == SplitType.equal && groupMembers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Set<String> includedIds = expenseState.includedMemberIds;
        if (includedIds.isEmpty) {
          includedIds = Set<String>.from(groupMembers.map((m) => m.id));
        }

        if (expenseState.amount > 0) {
          final includedCount = includedIds.length;
          final equalShare = includedCount > 0
              ? (expenseState.amount / includedCount).toDouble()
              : 0.0;
          final newSplits = <String, double>{
            for (final member in groupMembers)
              member.id: includedIds.contains(member.id) ? equalShare : 0,
          };

          final splitsChanged =
              !mapEquals(newSplits, expenseState.splits);
          final includedChanged =
              !setEquals(includedIds, expenseState.includedMemberIds);

          if (splitsChanged || includedChanged) {
            ref.read(addExpenseProvider.notifier).state = expenseState.copyWith(
              splits: newSplits,
              includedMemberIds: includedIds,
            );
          }
        } else if (!setEquals(includedIds, expenseState.includedMemberIds)) {
          // Amount=0: still initialise includedMemberIds so the UI shows
          // every member checked.
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
        title: widget.isEditing ? 'Edit expense' : 'Add expense',
        onClose: _closeScreen,
        isDark: isDark,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                _buildInvoiceSection(isDark, state),
                const SizedBox(height: 24),
                _buildTitleSection(isDark),
                const SizedBox(height: 20),
                _buildAmountSection(isDark, state),
                const SizedBox(height: 20),
                _buildMemberSection(isDark, state, groupMembers),
                const SizedBox(height: 20),
                _buildCategorySection(isDark, state),
                const SizedBox(height: 20),
                _buildDateSection(isDark, state),
                const SizedBox(height: 20),
                _buildSplitSection(isDark, state),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: _breakdownKey,
                  child:
                      _buildSplitBreakdownSection(isDark, state, groupMembers),
                ),
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
        title: widget.isEditing ? 'Edit expense' : 'Add expense',
        onClose: _closeScreen,
        isDark: isDark,
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _buildInvoiceSection(isDark, state),
                    const SizedBox(height: 28),
                    _buildTitleSection(isDark),
                    const SizedBox(height: 24),
                    _buildAmountSection(isDark, state),
                    const SizedBox(height: 24),
                    _buildMemberSection(isDark, state, groupMembers),
                    const SizedBox(height: 24),
                    _buildCategorySection(isDark, state),
                    const SizedBox(height: 24),
                    _buildDateSection(isDark, state),
                    const SizedBox(height: 24),
                    _buildSplitSection(isDark, state),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _breakdownKey,
                      child: _buildSplitBreakdownSection(
                          isDark, state, groupMembers),
                    ),
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
        title: widget.isEditing ? 'Edit expense' : 'Add expense',
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
                                _buildTitleSection(isDark),
                                const SizedBox(height: 20),
                                _buildAmountSection(isDark, state),
                                const SizedBox(height: 20),
                                _buildMemberSection(isDark, state, groupMembers),
                                const SizedBox(height: 20),
                                _buildCategorySection(isDark, state),
                                const SizedBox(height: 20),
                                _buildDateSection(isDark, state),
                                const SizedBox(height: 20),
                                _buildSplitSection(isDark, state),
                                const SizedBox(height: 12),
                                KeyedSubtree(
                                  key: _breakdownKey,
                                  child: _buildSplitBreakdownSection(
                                      isDark, state, groupMembers),
                                ),
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

  // Receipt upload — picks an image and stores it as base64 to attach as
  // proof on save. (OCR scanning is intentionally disabled for now.)
  Widget _buildInvoiceSection(bool isDark, AddExpenseState state) {
    return Semantics(
      label: 'Receipt upload section',
      child: InvoiceUploadWidget(
        onImageSelected: (imagePath, file) async {
          // Read once → base64 once. Re-using the same bytes both for the
          // preview tile (handled by the widget) and the POST body.
          try {
            final bytes = await File(imagePath).readAsBytes();
            final encoded = base64Encode(bytes);
            ref.read(addExpenseProvider.notifier).state = state.copyWith(
              invoiceImagePath: imagePath,
              receiptBase64: encoded,
            );
          } catch (_) {
            // Fall back to just storing the path; save will skip the receipt.
            ref.read(addExpenseProvider.notifier).state =
                state.copyWith(invoiceImagePath: imagePath);
          }
        },
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
      ],
    );
  }

  Widget _buildTitleSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionTitle(label: 'TITLE', isDark: isDark),
            const SizedBox(width: 4),
            // Asterisk to flag required-ness; reads as '*' but uses the
            // app's warning color so it stands out without a wall of text.
            Text(
              '*',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Dinner, movie, groceries…',
            filled: true,
            fillColor: AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorder(isDark)),
            ),
          ),
          onChanged: (value) {
            // Debounce — see _titleDebounce field for rationale.
            _titleDebounce?.cancel();
            _titleDebounce = Timer(const Duration(milliseconds: 200), () {
              if (!mounted) return;
              ref.read(addExpenseProvider.notifier).state =
                  ref.read(addExpenseProvider).copyWith(title: value);
            });
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
        // When leaving Equal, reset per-member values to 0 so the
        // equal-split amount (e.g. 1200) doesn't get reinterpreted as a
        // percentage / share / exact amount.
        Map<String, double> nextSplits = state.splits;
        if (type != state.splitType && type != SplitType.equal) {
          nextSplits = {for (final id in state.splits.keys) id: 0};
        }
        ref.read(addExpenseProvider.notifier).state =
            state.copyWith(splitType: type, splits: nextSplits);

        // Picking a non-equal type means the user needs the breakdown next —
        // scroll to it so the keyboard / inputs are immediately reachable.
        if (type == SplitType.exact ||
            type == SplitType.percentage ||
            type == SplitType.shares) {
          _scrollToBreakdown();
        }
      },
    );
  }

  Widget _buildSplitBreakdownSection(bool isDark, AddExpenseState state, List<UserModel> members) {
    // Hide if no group selected
    if (state.groupId == null || members.isEmpty) {
      return const SizedBox.shrink();
    }

    // For equal split, show member selection list (redesigned to match
    // the 21st.dev aesthetic used elsewhere in the app).
    if (state.splitType == SplitType.equal) {
      final includedCount = state.includedMemberIds.length;
      final totalCount = members.length;
      final searchQuery = _equalSplitSearchController.text.toLowerCase();
      final filteredMembers = searchQuery.isEmpty
          ? members
          : members
              .where((m) => m.name.toLowerCase().contains(searchQuery))
              .toList();
      final perMember = (includedCount > 0 && state.amount > 0)
          ? state.amount / includedCount
          : 0.0;
      final showSearch = members.length > 4;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Row(
            children: [
              Expanded(
                child: Text(
                  'BREAKDOWN',
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Balanced',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$includedCount of $totalCount included',
                          style: AppTextStyles.body2(isDark).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final allIncluded =
                              state.includedMemberIds.length == members.length;
                          ref.read(addExpenseProvider.notifier).state =
                              state.copyWith(
                            includedMemberIds: allIncluded
                                ? <String>{}
                                : Set<String>.from(members.map((m) => m.id)),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.tealDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          state.includedMemberIds.length == members.length
                              ? 'Clear'
                              : 'Select all',
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
                if (showSearch) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _equalSplitSearchController,
                              onChanged: (_) => setState(() {}),
                              style: AppTextStyles.body2(isDark)
                                  .copyWith(fontSize: 13),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                hintText: 'Search members',
                                hintStyle: AppTextStyles.body2(isDark).copyWith(
                                  color: AppColors.textSecondary(isDark),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          if (_equalSplitSearchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _equalSplitSearchController.clear();
                                setState(() {});
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: AppColors.divider(isDark).withValues(alpha: 0.6),
                  ),
                ],
                for (int i = 0; i < filteredMembers.length; i++) ...[
                  _buildMemberEqualSplitRow(
                    isDark,
                    state,
                    filteredMembers[i],
                    perMember,
                  ),
                  if (i < filteredMembers.length - 1)
                    Container(
                      height: 1,
                      color: AppColors.divider(isDark).withValues(alpha: 0.6),
                    ),
                ],
                if (filteredMembers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No members match "$searchQuery"',
                      style: AppTextStyles.body2(isDark).copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                Container(
                  height: 1,
                  color: AppColors.divider(isDark).withValues(alpha: 0.6),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Each pays',
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${perMember.toStringAsFixed(2)}',
                        style: AppTextStyles.body2(isDark).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    double perMember,
  ) {
    final isIncluded = state.includedMemberIds.contains(member.id);
    final dim = !isIncluded;
    final initials = _initialsFor(member.name);

    void toggle() {
      final newSet = Set<String>.from(state.includedMemberIds);
      if (newSet.contains(member.id)) {
        newSet.remove(member.id);
      } else {
        newSet.add(member.id);
      }
      ref.read(addExpenseProvider.notifier).state =
          state.copyWith(includedMemberIds: newSet);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Toggle box
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isIncluded ? AppColors.tealDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isIncluded
                        ? AppColors.tealDark
                        : AppColors.divider(isDark),
                    width: 1.5,
                  ),
                ),
                child: isIncluded
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              // Avatar tile
              Opacity(
                opacity: dim ? 0.5 : 1.0,
                child: AvatarWidget(
                  name: member.name,
                  imageUrl: member.avatarUrl,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                child: Text(
                  member.name,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: dim
                        ? AppColors.textSecondary(isDark)
                        : AppColors.textPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Per-person amount (only when included)
              if (isIncluded)
                Text(
                  '₹${perMember.toStringAsFixed(2)}',
                  style: AppTextStyles.body2(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _buildMemberSection(bool isDark, AddExpenseState state, List<UserModel> groupMembers) {
    final me = ref.watch(authProvider).user;
    // Resolve display payer: explicit pick > the current user (default).
    final UserModel? payer = state.paidBy ??
        (me == null
            ? null
            : groupMembers.firstWhereOrNull((m) => m.id == me.id));
    final isMe = me != null && payer != null && payer.id == me.id;
    final displayName = payer == null
        ? 'Me'
        : (isMe ? '${payer.name} (Me)' : payer.name);
    final initial = (payer?.name.isNotEmpty ?? false)
        ? payer!.name[0].toUpperCase()
        : 'M';

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
                  AvatarWidget(
                    name: payer?.name ?? 'Me',
                    imageUrl: isMe ? me?.avatarUrl : payer?.avatarUrl,
                    radius: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
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
                  // One row per group member. The current user gets tagged
                  // with "(Me)" instead of being a separate redundant entry.
                  ...() {
                    final me = ref.read(authProvider).user;
                    return groupMembers.map((member) {
                      final isMe = me != null && member.id == me.id;
                      final label = isMe ? '${member.name} (Me)' : member.name;
                      final imageUrl = isMe ? me?.avatarUrl : member.avatarUrl;
                      // Selected when explicit pick matches, OR when nothing
                      // is picked yet and this is the current user (default).
                      final selected = state.paidBy == null
                          ? isMe
                          : state.paidBy!.id == member.id;
                      return _buildMemberListItem(
                        isDark,
                        label,
                        imageUrl: imageUrl,
                        isSelected: selected,
                        onTap: () {
                          ref.read(addExpenseProvider.notifier).state =
                              state.copyWith(paidBy: member);
                          Navigator.pop(context);
                        },
                      );
                    });
                  }(),
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
    {String? imageUrl, required bool isSelected, required VoidCallback onTap}
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
              AvatarWidget(
                name: name,
                imageUrl: imageUrl,
                radius: 20,
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
    // Defensive: the Save button is already gated by state.isValid, but a
    // bypass (hot reload, swipe gesture) could still hit this — surface a
    // clear message rather than letting the model send an empty title.
    if (state.title == null || state.title!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title before saving.')),
      );
      return;
    }
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
    final group = groups.firstWhereOrNull((g) => g.id == groupId);
    final members = group?.members ?? const <UserModel>[];

    final paidBy = state.paidBy ??
        members.firstWhereOrNull((m) => m.id == currentUser.id) ??
        UserModel(
          id: currentUser.id,
          name: currentUser.name,
          email: currentUser.email,
          phone: currentUser.phone,
          avatarUrl: currentUser.avatarUrl,
          createdAt: currentUser.createdAt,
        );

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
      }
    }

    // Backend's split_type CHECK accepts ('equal', 'unequal', 'percentage', 'shares').
    // Map 'exact' to 'unequal' since we send concrete amounts.
    String backendSplitType(SplitType t) {
      switch (t) {
        case SplitType.equal:
          return 'equal';
        case SplitType.percentage:
          return 'percentage';
        case SplitType.shares:
          return 'shares';
        case SplitType.exact:
          return 'unequal';
      }
    }

    // Pull the raw input (percentage / shares / exact-amount) the user typed
    // for this member, so we can persist it alongside the resolved amount.
    // This lets the detail screen later show the working ("30% × ₹X = ₹Y").
    double? percentageFor(String id) =>
        state.splitType == SplitType.percentage ? (state.splits[id] ?? 0) : null;
    int? sharesFor(String id) => state.splitType == SplitType.shares
        ? (state.splits[id] ?? 0).round()
        : null;

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
              percentage: percentageFor(id),
              shares: sharesFor(id),
            );
          }).toList();

    ref.read(addExpenseProvider.notifier).state =
        state.copyWith(isLoading: true, error: null);

    try {
      // Title is required and validated by state.isValid before reaching
      // here; trim defensively but never substitute "Untitled".
      final repo = ref.read(expensesRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(
          widget.expenseId!,
          description: state.title!.trim(),
          amount: state.amount,
          currency: state.currency,
          category: (state.category ?? CategoryModel.other).id,
          notes: state.notes,
          expenseDate: state.date,
          receiptBase64: state.receiptBase64,
          paidById: paidBy.id,
          splitType: backendSplitType(state.splitType),
          participants: participants,
        );
      } else {
        await repo.create(
          groupId: groupId,
          description: state.title!.trim(),
          amount: state.amount,
          currency: state.currency,
          category: (state.category ?? CategoryModel.other).id,
          paidById: paidBy.id,
          paidByName: paidBy.name,
          splitType: backendSplitType(state.splitType),
          notes: state.notes,
          expenseDate: state.date,
          receiptBase64: state.receiptBase64,
          participants: participants,
        );
      }
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
    if (widget.isEditing) {
      // Bust the detail-screen cache so the popped-to screen reflects edits.
      ref.invalidate(expenseDetailProvider(widget.expenseId!));
    }

    if (!mounted) return;
    ref.read(addExpenseProvider.notifier).state =
        AddExpenseState(date: DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEditing ? '✓ Expense updated' : '✓ Expense saved'),
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
