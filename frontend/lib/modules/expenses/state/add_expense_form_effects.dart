import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/feature_flags_provider.dart';
import '../../../data/expenses/expenses_repository.dart';
import '../../../models/models.dart';
import '../../groups/state/group_detail_provider.dart';
import '../screens/add_expense_screen.dart';
import '../widgets/repeat_sheet.dart';
import 'add_expense_category_suggest.dart';
import 'add_expense_provider.dart';
import 'add_expense_split_math.dart';

/// Things the Add expense form does on its own while the user fills it in:
/// suggest a category from the description, start a new expense from the
/// group's default split, and which optional rows (feature flags) it shows. A mixin on the screen's `ConsumerState` (like
/// AddExpenseSaveFlow) so it shares the screen's `ref` / `mounted`; the
/// decisions themselves are the pure functions it calls.
mixin AddExpenseFormEffects on ConsumerState<AddExpenseScreen> {
  CategoryAutoSuggester? _categorySuggester;

  /// Group whose default split was already considered — once per group, so
  /// the user's own split choice is never overwritten afterwards.
  String? _defaultSplitCheckedFor;

  /// Feeds the description into the category suggester (new expenses only:
  /// editing never auto-changes the category).
  void suggestCategoryFor(String description) {
    if (widget.isEditing) return;
    _categorySuggester ??= CategoryAutoSuggester(
      fetchRemote: ref.read(expensesRepositoryProvider).suggestCategory,
      apply: _applySuggestedCategory,
    );
    _categorySuggester!.onDescriptionChanged(description);
  }

  void _applySuggestedCategory(CategoryModel category) {
    if (!mounted) return;
    final current = ref.read(addExpenseProvider);
    if (current.categoryTouched || current.category == category) return;
    ref.read(addExpenseProvider.notifier).state = current.copyWith(
      category: category,
    );
  }

  /// New expense in a group with a default split → start from it instead of
  /// equally. Call from `build` with the group detail the form watches.
  void applyGroupDefaultSplitOnce(GroupDetail? detail) {
    if (widget.isEditing || detail == null) return;
    if (_defaultSplitCheckedFor == detail.group.id) return;
    _defaultSplitCheckedFor = detail.group.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(addExpenseProvider);
      // Only replace the untouched "equally" start.
      if (current.groupId != detail.group.id ||
          current.splitMode != AddExpenseSplitMode.equal) {
        return;
      }
      final next = addExpenseStateWithGroupDefault(
        current,
        detail.group.defaultSplit,
        detail.members,
      );
      if (next != null) ref.read(addExpenseProvider.notifier).state = next;
    });
  }

  /// The `multiPayer` flag: "Multiple people" in the Paid by sheet.
  bool get multiPayerEnabled =>
      ref.read(featureFlagsProvider).value?.contains('multiPayer') ?? false;

  /// Opens the Repeat sheet. null (no Repeat row) when editing — a recurring
  /// expense's repeat is managed from its detail screen — or while the
  /// `recurring` flag is off. Call from `build` (it watches the flags).
  VoidCallback? repeatTapHandler(bool isDark) {
    if (widget.isEditing || !watchFeature(ref, 'recurring')) return null;
    return () => showRepeatSheet(context, ref, isDark: isDark);
  }

  void disposeFormEffects() => _categorySuggester?.dispose();
}
