import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptic_service.dart';
import '../../../components/web/web_form_row.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_save_flow.dart';
import '../state/add_expense_submit.dart';
import '../widgets/add_expense_form_cards.dart';
import '../widgets/add_expense_hero_card.dart';
import '../widgets/add_expense_hydrate_view.dart';
import '../widgets/add_expense_save_bar.dart';
import '../widgets/add_expense_form_scaffold.dart';
import '../widgets/category_sheet.dart';
import '../widgets/paid_by_sheet.dart';
import '../widgets/receipt_notes_sheets.dart';
import '../widgets/split_sheet.dart';

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

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen>
    with AddExpenseSaveFlow {
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

      final hydrated = addExpenseStateFromExpense(expense);
      _titleController.text = expense.title;
      _notesController.text = expense.notes ?? '';
      ref.read(addExpenseProvider.notifier).state = hydrated;

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
      return AddExpenseHydrateView(
        isDark: isDark,
        hydrateError: _hydrateError,
        onClose: closeScreen,
        onRetry: () {
          setState(() {
            _hydrateError = null;
            _hydrating = true;
          });
          _hydrateFromExpense();
        },
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

    // Equal-split write-back — see [listenEqualSplitWriteBack].
    listenEqualSplitWriteBack(
      ref,
      expenseState.groupId,
      isMounted: () => mounted,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Wider on the web tier because the two option cards sit side by side
    // there rather than stacked — see _buildFormBody.
    final double maxFormWidth = screenWidth < 600
        ? double.infinity
        : screenWidth < 1100
        ? 600
        : 920;
    final double horizontalPad = screenWidth < 600
        ? 16
        : screenWidth < 1100
        ? 24
        : 32;

    return AddExpenseFormScaffold(
      isDark: isDark,
      title: widget.isEditing ? 'Edit expense' : 'Add expense',
      onClose: closeScreen,
      horizontalPad: horizontalPad,
      maxFormWidth: maxFormWidth,
      form: _buildFormBody(isDark, expenseState, groupMembers),
      saveBar: AddExpenseSaveBar(
        isDark: isDark,
        enabled: expenseState.isValid && !expenseState.isLoading,
        loading: expenseState.isLoading,
        horizontalPad: horizontalPad,
        maxFormWidth: maxFormWidth,
        label: widget.isEditing ? 'Save changes' : 'Save expense',
        disabledHint: addExpenseMissingFieldHint(expenseState),
        onTap: handleSave,
        // Tapping the bar while it's disabled reveals which fields are
        // wrong (red highlights) instead of doing nothing.
        onDisabledTap: () {
          HapticService.instance.error();
          if (!_showValidation) {
            setState(() => _showValidation = true);
          }
        },
      ),
    );
  }

  Widget _buildFormBody(
    bool isDark,
    AddExpenseState state,
    List<UserModel> groupMembers,
  ) {
    final me = ref.watch(authProvider).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddExpenseHeroCard(
          isDark: isDark,
          state: state,
          autoFocus: !widget.isEditing,
          showValidation: _showValidation,
          titleController: _titleController,
          onAmountChanged: (amount) {
            ref.read(addExpenseProvider.notifier).state = state.copyWith(
              amount: amount,
            );
          },
          onTitleChanged: _onTitleChanged,
        ),
        const SizedBox(height: 28),
        // Stacked on touch, side by side on the web tier. Six full-width rows
        // in a column push the submit button below the fold on a laptop for
        // no reason — the two cards are independent, so they can share a row.
        WebFormRow(
          spacing: 20,
          flex: const [3, 2],
          children: [
            AddExpenseQuickRowsCard(
              isDark: isDark,
              state: state,
              groupMembers: groupMembers,
              me: me,
              showValidation: _showValidation,
              onPaidByTap: () => showPaidBySheet(
                context,
                ref,
                isDark: isDark,
                state: state,
                groupMembers: groupMembers,
              ),
              onSplitTap: () => showSplitSheet(
                context,
                ref,
                isDark: isDark,
                groupMembers: groupMembers,
              ),
              onDateTap: () => pickExpenseDate(context, ref, state),
              onCategoryTap: () =>
                  showCategorySheet(context, ref, isDark: isDark, state: state),
            ),
            AddExpenseMoreOptionsCard(
              isDark: isDark,
              state: state,
              onReceiptTap: () =>
                  showReceiptSheet(context, ref, isDark: isDark),
              onNotesTap: () => showNotesSheet(
                context,
                ref,
                isDark: isDark,
                notesController: _notesController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _onTitleChanged(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(addExpenseProvider.notifier).state = ref
          .read(addExpenseProvider)
          .copyWith(title: value);
    });
  }
}
