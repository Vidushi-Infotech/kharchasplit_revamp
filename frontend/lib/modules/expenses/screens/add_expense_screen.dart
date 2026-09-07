import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/base64_async.dart';
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
import '../widgets/invoice_upload_widget.dart';
import '../widgets/split_breakdown_widget.dart';
import '../widgets/split_selector_widget.dart';

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

  /// Latch — set once widget.groupId has been pushed into state.
  bool _groupIdSynced = false;

  /// Debounce on the title TextField to avoid rebuilding the whole tree
  /// on every keystroke.
  Timer? _titleDebounce;

  bool _hydrating = false;
  String? _hydrateError;

  /// Flipped on once the user taps the (disabled) Save bar with an invalid
  /// form. Drives the red highlighting on the amount / title / split so the
  /// user can see *which* field is blocking the save.
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();

    if (widget.isEditing) {
      _hydrating = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _hydrateFromExpense(),
      );
    }
  }

  Future<void> _hydrateFromExpense() async {
    final id = widget.expenseId;
    if (id == null) return;
    try {
      final expense = await ref.read(expensesRepositoryProvider).getById(id);
      if (!mounted) return;

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
    // No manual provider reset here: addExpenseProvider is autoDispose, so it
    // tears down and re-creates fresh state once this screen stops watching
    // it. (Mutating it via a post-dispose microtask was unreliable — `ref` is
    // already invalid by then.)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep addExpenseProvider (autoDispose) alive from the very first frame.
    // In edit mode the fetched expense is written into it while the loading
    // branch below is on screen; with no listener yet Riverpod dropped that
    // state before the form ever read it, so the user saw amount 0, no
    // category/date and "Pick a group before saving the expense".
    ref.watch(addExpenseProvider);

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
                        style: AppTextStyles.body1(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hydrateError!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body2(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
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

    // Sync route param → provider once.
    if (!_groupIdSynced &&
        widget.groupId != null &&
        expenseState.groupId != widget.groupId) {
      _groupIdSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(addExpenseProvider.notifier).state = expenseState.copyWith(
          groupId: widget.groupId,
        );
      });
    }

    final groupAsync = expenseState.groupId != null
        ? ref.watch(groupDetailProvider(expenseState.groupId!))
        : null;
    final List<UserModel> groupMembers = groupAsync?.value?.members ?? [];

    // Equal-split write-back. The derivation lives in
    // [equalSplitDerivedProvider] — a pure function of (amount,
    // splitType, includedMemberIds, members). `ref.listen` fires only
    // when the EqualSplitDerived value structurally changes (the class
    // implements ==).
    //
    // The state write is deferred to a post-frame callback because the
    // derived provider watches addExpenseProvider — writing back
    // synchronously inside the listener dirties the dependency, and
    // Riverpod refuses to recompute the same provider twice in one
    // frame ("Bad state: Tried to rebuild Provider<EqualSplitDerived?>
    // multiple times in the same frame"). Posting the write to the
    // next frame lets Riverpod's per-frame bookkeeping reset; the
    // structural `==` on EqualSplitDerived then short-circuits the
    // next listener fire (prev == next) and the loop terminates.
    ref.listen<EqualSplitDerived?>(
      equalSplitDerivedProvider(expenseState.groupId),
      (prev, next) {
        if (next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(addExpenseProvider);
          if (mapEquals(current.splits, next.splits) &&
              setEquals(current.includedMemberIds, next.includedMemberIds)) {
            return;
          }
          ref.read(addExpenseProvider.notifier).state = current.copyWith(
            splits: next.splits,
            includedMemberIds: next.includedMemberIds,
          );
        });
      },
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final double maxFormWidth = screenWidth < 600
        ? double.infinity
        : screenWidth < 1100
        ? 600
        : 700;
    final double horizontalPad = screenWidth < 600
        ? 16
        : screenWidth < 1100
        ? 24
        : 32;

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
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    16,
                    horizontalPad,
                    20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxFormWidth),
                      child: _buildFormBody(isDark, expenseState, groupMembers),
                    ),
                  ),
                ),
              ),
              _StickyCreateBar(
                isDark: isDark,
                enabled: expenseState.isValid && !expenseState.isLoading,
                loading: expenseState.isLoading,
                horizontalPad: horizontalPad,
                maxFormWidth: maxFormWidth,
                label: widget.isEditing ? 'Save changes' : 'Save expense',
                disabledHint: _missingFieldHint(expenseState),
                onTap: _handleSave,
                // Tapping the bar while it's disabled reveals which fields are
                // wrong (red highlights) instead of doing nothing.
                onDisabledTap: () {
                  HapticService.instance.error();
                  if (!_showValidation) {
                    setState(() => _showValidation = true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(isDark, state),
        const SizedBox(height: 28),
        _buildQuickRows(isDark, state, groupMembers),
        const SizedBox(height: 20),
        _buildMoreOptions(isDark, state),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHero(bool isDark, AddExpenseState state) {
    final titleError = _showValidation && (state.title ?? '').trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          Semantics(
            label:
                'Enter amount in ${state.currency}, currently ${CurrencyFormatter.format(state.amount)}',
            child: AmountInputWidget(
              amount: state.amount,
              currency: state.currency,
              autoFocus: !widget.isEditing,
              hasError: _showValidation && state.amount <= 0,
              onChanged: (amount) {
                ref.read(addExpenseProvider.notifier).state = state.copyWith(
                  amount: amount,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            color: AppColors.divider(isDark).withValues(alpha: 0.5),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _titleController,
              textAlign: TextAlign.center,
              style: AppTextStyles.body1(
                isDark,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: titleError ? 'Add a title' : "What's this for?",
                hintStyle: AppTextStyles.body1(isDark).copyWith(
                  color: titleError
                      ? AppColors.errorText(isDark)
                      : AppColors.textSecondary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                _titleDebounce?.cancel();
                _titleDebounce = Timer(const Duration(milliseconds: 200), () {
                  if (!mounted) return;
                  ref.read(addExpenseProvider.notifier).state = ref
                      .read(addExpenseProvider)
                      .copyWith(title: value);
                });
              },
            ),
          ),
          if (titleError) ...[
            const SizedBox(height: 2),
            Text(
              'Title is required',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.errorText(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickRows(
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    final me = ref.watch(authProvider).user;
    final UserModel? payer =
        state.paidBy ??
        (me == null
            ? null
            : groupMembers.firstWhereOrNull((m) => m.id == me.id));
    final isMe = me != null && payer != null && payer.id == me.id;
    final paidByText = payer == null ? 'You' : (isMe ? 'You' : payer.name);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          _QuickRow(
            icon: Icons.person_outline_rounded,
            iconColor: AppColors.tealDark,
            label: 'Paid by',
            value: paidByText,
            isDark: isDark,
            onTap: () => _showPaidBySheet(isDark, state, groupMembers),
          ),
          _RowDivider(isDark: isDark),
          _QuickRow(
            icon: Icons.pie_chart_outline_rounded,
            iconColor: AppColors.tealDark,
            label: 'Split',
            value: _splitSummary(state, groupMembers),
            isDark: isDark,
            errorText: (_showValidation && !state.isSplitValid)
                ? (state.splitError ?? 'Split doesn\'t add up')
                : null,
            onTap: () => _showSplitSheet(isDark, state, groupMembers),
          ),
          _RowDivider(isDark: isDark),
          _QuickRow(
            icon: Icons.event_outlined,
            iconColor: AppColors.tealDark,
            label: 'When',
            value: _formatDate(state.date),
            isDark: isDark,
            onTap: () => _pickDate(state),
          ),
          _RowDivider(isDark: isDark),
          _QuickRow(
            icon: state.category?.icon ?? Icons.local_offer_outlined,
            iconColor:
                _hexToColor(state.category?.colorHex) ?? AppColors.tealDark,
            label: 'Category',
            value: state.category?.name ?? 'Choose',
            isDark: isDark,
            onTap: () => _showCategorySheet(isDark, state),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptions(bool isDark, AddExpenseState state) {
    final hasReceipt =
        state.invoiceImagePath != null ||
        (state.receiptBase64 != null && state.receiptBase64!.isNotEmpty);
    final notes = state.notes ?? '';
    final hasNotes = notes.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Column(
        children: [
          _QuickRow(
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.tealDark,
            label: 'Receipt',
            value: hasReceipt ? 'Added' : 'Optional',
            valueIsMuted: !hasReceipt,
            isDark: isDark,
            onTap: () => _showReceiptSheet(isDark, state),
          ),
          _RowDivider(isDark: isDark),
          _QuickRow(
            icon: Icons.notes_rounded,
            iconColor: AppColors.tealDark,
            label: 'Notes',
            value: hasNotes
                ? (notes.length > 24 ? '${notes.substring(0, 22)}…' : notes)
                : 'Optional',
            valueIsMuted: !hasNotes,
            isDark: isDark,
            onTap: () => _showNotesSheet(isDark),
          ),
        ],
      ),
    );
  }

  // -- Helpers --

  String _splitSummary(AddExpenseState state, List<UserModel> members) {
    final count = state.includedMemberIds.isEmpty
        ? members.length
        : state.includedMemberIds.length;
    if (count == 0) return 'Equally';
    switch (state.splitType) {
      case SplitType.equal:
        return 'Equally · $count ${count == 1 ? 'person' : 'people'}';
      case SplitType.exact:
        return 'By amounts · $count';
      case SplitType.percentage:
        return 'By percent · $count';
      case SplitType.shares:
        return 'By shares · $count';
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(d.year, d.month, d.day);
    final diff = today.difference(picked).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return '$diff days ago';
    return '${picked.day}/${picked.month}/${picked.year}';
  }

  Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var s = hex.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final value = int.tryParse(s, radix: 16);
    return value == null ? null : Color(value);
  }

  /// Returns a short, actionable hint describing what's missing to enable
  /// Save. `null` when the form is ready to submit. Used as the disabled
  /// button label so users immediately see *why* they can't save yet.
  String? _missingFieldHint(AddExpenseState state) {
    if (state.isValid) return null;
    final hasTitle = (state.title ?? '').trim().isNotEmpty;
    final hasAmount = state.amount > 0;
    if (!hasTitle && !hasAmount) return 'Enter amount and title';
    if (!hasAmount) return 'Enter amount';
    if (!hasTitle) return 'Enter title';
    if (state.groupId == null) return 'Pick a group';
    if (!state.isSplitValid) return 'Fix the split';
    return 'Complete required fields';
  }

  Future<void> _pickDate(AddExpenseState state) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      HapticService.instance.selection();
      ref.read(addExpenseProvider.notifier).state = state.copyWith(
        date: picked,
      );
    }
  }

  // -- Bottom sheets --

  void _showPaidBySheet(
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    if (groupMembers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No group selected.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final me = ref.read(authProvider).user;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(isDark: isDark),
              _SheetTitle(text: 'Who paid?', isDark: isDark),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: groupMembers.length,
                  itemBuilder: (_, i) {
                    final m = groupMembers[i];
                    final isMe = me != null && m.id == me.id;
                    final label = isMe ? '${m.name} (Me)' : m.name;
                    final selected = state.paidBy == null
                        ? isMe
                        : state.paidBy!.id == m.id;
                    return InkWell(
                      onTap: () {
                        HapticService.instance.tap();
                        ref.read(addExpenseProvider.notifier).state = state
                            .copyWith(paidBy: m);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        color: selected
                            ? AppColors.tealDark.withValues(alpha: 0.06)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              name: m.name,
                              imageUrl: isMe ? me.avatarUrl : m.avatarUrl,
                              radius: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: AppTextStyles.body1(isDark).copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.tealDark,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSplitSheet(
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    if (groupMembers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No group selected.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) {
            // Keyboard height. A DraggableScrollableSheet does NOT resize
            // when the keyboard opens (unlike a Scaffold body), so we
            // shrink the scroll viewport by this amount below — that puts
            // the viewport's bottom edge at the keyboard's top, letting
            // Flutter's auto-reveal scroll a focused split-amount field
            // (which lives mid-list) above the keyboard instead of behind
            // it.
            final keyboardInset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  _SheetHandle(isDark: isDark),
                  _SheetTitle(
                    text: 'Split',
                    isDark: isDark,
                    // Done stays disabled until the split adds up correctly,
                    // so the user can't leave an invalid split behind. The
                    // breakdown widget below shows the live "remaining /
                    // over by" status so they know what to fix.
                    trailing: Consumer(
                      builder: (_, ref, __) {
                        final canClose = ref.watch(
                          addExpenseProvider.select((s) => s.isSplitValid),
                        );
                        return TextButton(
                          onPressed: canClose
                              ? () {
                                  HapticService.instance.success();
                                  Navigator.pop(ctx);
                                }
                              : null,
                          child: Text(
                            'Done',
                            style: AppTextStyles.body1(isDark).copyWith(
                              color: canClose
                                  ? AppColors.tealDark
                                  : AppColors.textSecondary(isDark),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: keyboardInset),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Consumer(
                          builder: (_, ref, __) {
                            final s = ref.watch(addExpenseProvider);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SplitSelectorWidget(
                                  splitType: s.splitType,
                                  amount: s.amount,
                                  onSplitTypeChanged: (type) {
                                    ref
                                        .read(addExpenseProvider.notifier)
                                        .state = s.copyWith(
                                      splitType: type,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                SplitBreakdownWidget(
                                  splitType: s.splitType,
                                  totalAmount: s.amount,
                                  members: groupMembers,
                                  splits: s.splits,
                                  includedMemberIds: s.includedMemberIds,
                                  currentUserId: ref.watch(myIdProvider),
                                  onSplitsChanged: (splits) {
                                    // Read the live state, not the captured `s`
                                    // snapshot. _toggleMember fires this right
                                    // after onIncludedMembersChanged; using the
                                    // stale `s` here would clobber the just-set
                                    // includedMemberIds back to its old value.
                                    final notifier = ref.read(
                                      addExpenseProvider.notifier,
                                    );
                                    notifier.state = notifier.state.copyWith(
                                      splits: splits,
                                    );
                                  },
                                  onIncludedMembersChanged: (included) {
                                    final notifier = ref.read(
                                      addExpenseProvider.notifier,
                                    );
                                    notifier.state = notifier.state.copyWith(
                                      includedMemberIds: included,
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategorySheet(bool isDark, AddExpenseState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final categories = CategoryModel.all;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(isDark: isDark),
              _SheetTitle(text: 'Pick a category', isDark: isDark),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    final selected = state.category?.id == c.id;
                    final color = _hexToColor(c.colorHex) ?? AppColors.tealDark;
                    return InkWell(
                      onTap: () {
                        HapticService.instance.selection();
                        ref.read(addExpenseProvider.notifier).state = state
                            .copyWith(category: c);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.18)
                              : AppColors.cardBg(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? color : AppColors.divider(isDark),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(c.icon, size: 20, color: color),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(isDark).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? color
                                    : AppColors.textPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReceiptSheet(bool isDark, AddExpenseState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(isDark: isDark),
              _SheetTitle(text: 'Receipt', isDark: isDark),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: InvoiceUploadWidget(
                  onImageSelected: (imagePath, file) async {
                    try {
                      final bytes = await File(imagePath).readAsBytes();
                      // Off the main isolate — a full-size receipt is a
                      // multi-MB encode that would freeze the sheet.
                      final encoded = await base64EncodeAsync(bytes);
                      ref.read(addExpenseProvider.notifier).state = ref
                          .read(addExpenseProvider)
                          .copyWith(
                            invoiceImagePath: imagePath,
                            receiptBase64: encoded,
                          );
                    } catch (_) {
                      ref.read(addExpenseProvider.notifier).state = ref
                          .read(addExpenseProvider)
                          .copyWith(invoiceImagePath: imagePath);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotesSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHandle(isDark: isDark),
                _SheetTitle(
                  text: 'Notes',
                  isDark: isDark,
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Done',
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextField(
                    controller: _notesController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Add any details…',
                      filled: true,
                      fillColor: AppColors.cardBg(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.divider(isDark),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.divider(isDark),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.tealDark.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      ref.read(addExpenseProvider.notifier).state = ref
                          .read(addExpenseProvider)
                          .copyWith(notes: value);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- Save --

  Future<void> _handleSave() async {
    final state = ref.read(addExpenseProvider);
    if (state.title == null || state.title!.trim().isEmpty) {
      HapticService.instance.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title before saving.')),
      );
      return;
    }
    if (state.groupId == null) {
      HapticService.instance.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a group before saving the expense.'),
        ),
      );
      return;
    }
    final groupId = state.groupId!;
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) {
      HapticService.instance.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to save an expense.'),
        ),
      );
      return;
    }

    final groups = ref.read(groupsProvider).value ?? const <GroupModel>[];
    final group = groups.firstWhereOrNull((g) => g.id == groupId);
    final members = group?.members ?? const <UserModel>[];

    final paidBy =
        state.paidBy ??
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
            0,
            (sum, mid) => sum + (state.splits[mid] ?? 0),
          );
          if (totalShares <= 0) return 0;
          return state.amount * raw / totalShares;
      }
    }

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

    double? percentageFor(String id) => state.splitType == SplitType.percentage
        ? (state.splits[id] ?? 0)
        : null;
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

    ref.read(addExpenseProvider.notifier).state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
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
      HapticService.instance.error();
      ref.read(addExpenseProvider.notifier).state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save expense: $e')));
      return;
    }

    ref.invalidate(dashboardProvider);
    ref.invalidate(groupDetailProvider(groupId));
    // Re-fetch the groups list so the dashboard "Your Groups" carousel picks
    // up the new recency order (this group jumps to the front now that the
    // backend bumped its updated_at).
    ref.invalidate(groupsProvider);
    if (widget.isEditing) {
      ref.invalidate(expenseDetailProvider(widget.expenseId!));
    }

    if (!mounted) return;
    HapticService.instance.success();
    ref.read(addExpenseProvider.notifier).state = AddExpenseState(
      date: DateTime.now(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing ? '✓ Expense updated' : '✓ Expense saved',
        ),
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

/// Single-line quick-row used in the form body for Paid by / Split / When /
/// Category / Receipt / Notes. Icon + label + value + chevron, fully tappable.
class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
    this.valueIsMuted = false,
    this.errorText,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final bool valueIsMuted;
  final VoidCallback onTap;

  /// When non-null, the row is in an error state: the value renders red and
  /// this message is shown beneath the row so the user knows what to fix.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final errorColor = AppColors.errorText(isDark);
    final valueColor = hasError
        ? errorColor
        : (valueIsMuted
              ? AppColors.textSecondary(isDark)
              : AppColors.textPrimary(isDark));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.instance.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTextStyles.body2(isDark).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: valueColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasError
                        ? errorColor
                        : AppColors.textSecondary(isDark),
                  ),
                ],
              ),
              if (hasError) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: errorColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          errorText!,
                          style: AppTextStyles.caption(isDark).copyWith(
                            color: errorColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.divider(isDark).withValues(alpha: 0.6),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider(isDark),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.text, required this.isDark, this.trailing});
  final String text;
  final bool isDark;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StickyCreateBar extends StatelessWidget {
  const _StickyCreateBar({
    required this.isDark,
    required this.enabled,
    required this.loading,
    required this.horizontalPad,
    required this.maxFormWidth,
    required this.label,
    required this.onTap,
    this.disabledHint,
    this.onDisabledTap,
  });

  final bool isDark;
  final bool enabled;
  final bool loading;
  final double horizontalPad;
  final double maxFormWidth;
  final String label;
  final String? disabledHint;
  final VoidCallback onTap;

  /// Called when the user taps the bar while it's disabled (not loading) —
  /// used to surface validation errors rather than silently ignoring the tap.
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(isDark).withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: label,
                child: Opacity(
                  opacity: (enabled || loading) ? 1 : 0.6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled ? onTap : (loading ? null : onDisabledTap),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.tealLight, AppColors.tealDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (enabled || loading)
                              ? [
                                  BoxShadow(
                                    color: AppColors.tealDark.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (loading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                enabled
                                    ? Icons.check_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                loading
                                    ? 'Saving…'
                                    : (enabled
                                          ? label
                                          : (disabledHint ?? label)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body1(isDark).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
                        Icons.close_rounded,
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
