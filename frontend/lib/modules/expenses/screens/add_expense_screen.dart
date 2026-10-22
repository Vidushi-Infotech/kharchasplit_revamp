import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../../../modules/groups/state/group_detail_provider.dart';
import '../state/add_expense_form_effects.dart';
import '../state/add_expense_form_helpers.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_save_flow.dart';
import '../state/add_expense_sentence.dart';
import '../state/add_expense_submit.dart';
import '../state/add_expense_validation.dart';
import '../widgets/add_expense_bottom_bar.dart';
import '../widgets/add_expense_extras_summary.dart';
import '../widgets/add_expense_form_scaffold.dart';
import '../widgets/add_expense_group_context.dart';
import '../widgets/add_expense_hydrate_view.dart';
import '../widgets/add_expense_main_fields.dart';
import '../widgets/add_expense_paid_split_line.dart';
import '../widgets/add_expense_top_bar.dart';
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

  /// Set once the user taps Save while it can't save: red-highlights the
  /// amount / description / split that block it.
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

      final hydrated = hydratedStateFor(expense);
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

    final w = MediaQuery.sizeOf(context).width;
    // One centred column on every tier, a little wider on the web tier.
    final double maxFormWidth = w < 600
        ? double.infinity
        : (w < 1100 ? 560 : 640);
    final double horizontalPad = w < 600 ? 16 : (w < 1100 ? 24 : 32);
    final myId = ref.watch(authProvider).user?.id;
    final groupLabel = addExpenseGroupLabel(groupAsync?.value?.group, myId);
    final onPickGroup = widget.isEditing
        ? null
        : () => pickGroupForNewExpense(isDark);
    final onRepeatTap = repeatTapHandler(isDark);
    void onReceiptTap() => openReceiptSheet(isDark, _titleController);
    void onNotesTap() => showNotesSheet(
      context,
      ref,
      isDark: isDark,
      notesController: _notesController,
    );

    return AddExpenseFormScaffold(
      isDark: isDark,
      onClose: closeScreen,
      horizontalPad: horizontalPad,
      maxFormWidth: maxFormWidth,
      topBar: AddExpenseTopBar(
        title: widget.isEditing
            ? AppStrings.editExpense
            : AppStrings.addAnExpense,
        onClose: closeScreen,
        isDark: isDark,
        saveEnabled: !archived && expenseState.isValid,
        saving: expenseState.isLoading,
        onSave: handleSave,
        // Tapping Save while it can't save says why, and red-highlights the
        // fields that block it.
        onSaveBlocked: () => explainBlockedSave(
          archived: archived,
          state: expenseState,
          revealErrors: () {
            if (!_showValidation) setState(() => _showValidation = true);
          },
        ),
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AddExpenseGroupContext(
            isDark: isDark,
            archived: archived,
            onPick: onPickGroup,
          ),
          AddExpenseMainFields(
            isDark: isDark,
            state: expenseState,
            autoFocus: !widget.isEditing,
            showValidation: _showValidation,
            titleController: _titleController,
            onAmountChanged: (amount) {
              ref.read(addExpenseProvider.notifier).state = ref
                  .read(addExpenseProvider)
                  .copyWith(amount: amount);
            },
            onTitleChanged: _onTitleChanged,
            onCategoryTap: () => showCategorySheet(
              context,
              ref,
              isDark: isDark,
              state: expenseState,
            ),
          ),
          const SizedBox(height: 28),
          AddExpensePaidSplitLine(
            isDark: isDark,
            state: expenseState,
            groupMembers: groupMembers,
            myId: myId,
            showValidation: _showValidation,
            onPaidByTap: () => showPaidBySheet(
              context,
              ref,
              isDark: isDark,
              state: expenseState,
              groupMembers: groupMembers,
              allowMultiple: multiPayerEnabled,
            ),
            onSplitTap: () => showSplitSheet(
              context,
              ref,
              isDark: isDark,
              groupMembers: groupMembers,
            ),
          ),
          AddExpenseExtrasSummary(
            isDark: isDark,
            state: expenseState,
            onReceiptTap: onReceiptTap,
            onNotesTap: onNotesTap,
            onRepeatTap: onRepeatTap,
          ),
        ],
      ),
      bottomBar: AddExpenseBottomBar(
        isDark: isDark,
        maxWidth: maxFormWidth,
        dateLabel: formatAddExpenseDate(expenseState.date),
        groupLabel: groupLabel,
        onDateTap: () => pickExpenseDate(context, ref, expenseState),
        onGroupTap: onPickGroup,
        onRepeatTap: onRepeatTap,
        onReceiptTap: onReceiptTap,
        onNotesTap: onNotesTap,
        hasReceipt: AddExpenseExtrasSummary.hasReceiptIn(expenseState),
        hasNotes: (expenseState.notes ?? '').trim().isNotEmpty,
        repeatOn: expenseState.repeat.isOn,
      ),
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
