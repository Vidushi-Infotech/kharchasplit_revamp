import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../components/web/web_form_row.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../state/add_expense_form_effects.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_save_flow.dart';
import '../state/add_expense_submit.dart';
import '../state/add_expense_validation.dart';
import '../widgets/add_expense_form_cards.dart';
import '../widgets/add_expense_group_context.dart';
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
    with AddExpenseSaveFlow, AddExpenseFormEffects {
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  /// Latch — set once widget.groupId has been pushed into state.
  bool _groupIdSynced = false;

  /// Title debounce — no full-tree rebuild on every keystroke.
  Timer? _titleDebounce;

  bool _hydrating = false;
  String? _hydrateError;

  /// Set once the user taps the disabled Save bar: red-highlights the
  /// amount / title / split that block the save.
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
    disposeFormEffects();
    _titleController.dispose();
    _notesController.dispose();
    // No manual provider reset: addExpenseProvider is autoDispose (a
    // post-dispose microtask reset was unreliable — `ref` is invalid then).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep addExpenseProvider (autoDispose) alive from the first frame: in
    // edit mode the fetched expense is written into it while the loading
    // branch is on screen; unwatched, Riverpod dropped it (amount 0 etc.).
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
    // Archived groups reject expense writes (409 GROUP_ARCHIVED): say so up
    // front and keep Save disabled.
    final archived = groupAsync?.value?.group.isArchived ?? false;
    // New expense in a group with a default split → start from it.
    applyGroupDefaultSplitOnce(groupAsync?.value);

    // Equal-split write-back — see [listenEqualSplitWriteBack].
    listenEqualSplitWriteBack(
      ref,
      expenseState.groupId,
      isMounted: () => mounted,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Wider on the web tier: the two option cards sit side by side there.
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
      form: _buildFormBody(isDark, expenseState, groupMembers, archived),
      saveBar: AddExpenseSaveBar(
        isDark: isDark,
        enabled: !archived && expenseState.isValid && !expenseState.isLoading,
        loading: expenseState.isLoading,
        horizontalPad: horizontalPad,
        maxFormWidth: maxFormWidth,
        label: widget.isEditing ? 'Save changes' : 'Save expense',
        disabledHint: archived
            ? AppStrings.groupArchived
            : addExpenseMissingFieldHint(expenseState),
        onTap: handleSave,
        // Tapping it while disabled reveals which fields are wrong.
        onDisabledTap: () {
          if (archived) return blockArchivedSave();
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
    bool archived,
  ) {
    final me = ref.watch(authProvider).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddExpenseGroupContext(isDark: isDark, archived: archived),
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
        // Stacked on touch, side by side on the web tier (six full-width
        // rows would push Save below the fold on a laptop).
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
                allowMultiple: multiPayerEnabled,
              ),
              onSplitTap: () => showSplitSheet(
                context,
                ref,
                isDark: isDark,
                groupMembers: groupMembers,
              ),
              onDateTap: () => pickExpenseDate(context, ref, state),
              onRepeatTap: repeatTapHandler(isDark),
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
    suggestCategoryFor(value);
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(addExpenseProvider.notifier).state = ref
          .read(addExpenseProvider)
          .copyWith(title: value);
    });
  }
}
