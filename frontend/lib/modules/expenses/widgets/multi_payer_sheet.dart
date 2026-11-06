import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../state/add_expense_provider.dart';
import '../state/add_expense_split_math.dart';
import 'add_expense_member_amount_row.dart';
import 'add_expense_sheet_header.dart';

/// "Multiple people" payer sheet: an amount per member, a live
/// "₹X of ₹Y left", and Save only once the amounts add up to the total
/// exactly (to the paisa). [context] and [ref] are the Add-expense screen's.
void showMultiPayerSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required List<UserModel> groupMembers,
}) {
  showModalBottomSheet(
    context: context,
    // Above the floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MultiPayerEditor(
      isDark: isDark,
      members: groupMembers,
      initial: ref.read(addExpenseProvider),
      myId: ref.read(myIdProvider),
      onSave: (amounts) {
        final notifier = ref.read(addExpenseProvider.notifier);
        notifier.state = addExpenseWithPayers(
          notifier.state,
          amounts,
          groupMembers,
        );
      },
    ),
  );
}

class _MultiPayerEditor extends StatefulWidget {
  const _MultiPayerEditor({
    required this.isDark,
    required this.members,
    required this.initial,
    required this.myId,
    required this.onSave,
  });

  final bool isDark;
  final List<UserModel> members;
  final AddExpenseState initial;
  final String? myId;
  final ValueChanged<Map<String, double>> onSave;

  @override
  State<_MultiPayerEditor> createState() => _MultiPayerEditorState();
}

class _MultiPayerEditorState extends State<_MultiPayerEditor> {
  final Map<String, TextEditingController> _controllers = {};

  /// Draft amounts. Starts from the expense's payers — including any who
  /// are no longer in the member list, so their share is kept, not dropped.
  late final Map<String, double> _draft = {...widget.initial.payers};

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      final v = _draft[m.id] ?? 0;
      _controllers[m.id] = TextEditingController(
        text: v <= 0
            ? ''
            : (v == v.roundToDouble()
                  ? v.toInt().toString()
                  : v.toStringAsFixed(2)),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged(String id) {
    setState(() {
      _draft[id] = double.tryParse(_controllers[id]!.text.trim()) ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final amount = widget.initial.amount;
    final currency = widget.initial.currency;
    String money(double v) => CurrencyFormatter.format(v, currency: currency);
    final left = payersLeftPaise(amount, _draft);
    final canSave =
        amount > 0 &&
        left == 0 &&
        _draft.values.every((v) => v >= 0) &&
        _draft.values.any((v) => v > 0);
    final status = left == 0
        ? '✓ ${money(amount)}'
        : left > 0
        ? AppStrings.amountOfTotalLeft(money(left / 100), money(amount))
        : AppStrings.amountOver(money(-left / 100));

    return Padding(
      // Keep the focused field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(
              text: AppStrings.howMuchEachPaid,
              isDark: isDark,
              trailing: TextButton(
                onPressed: canSave
                    ? () {
                        HapticService.instance.success();
                        widget.onSave(_draft);
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  'Save',
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: canSave
                        ? AppColors.tealDark
                        : AppColors.textSecondary(isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    style: AppTextStyles.body2(isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      color: left == 0 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                itemCount: widget.members.length,
                itemBuilder: (_, i) {
                  final m = widget.members[i];
                  return AddExpenseMemberAmountRow(
                    member: m,
                    label: m.id == widget.myId ? '${m.name} (Me)' : m.name,
                    controller: _controllers[m.id]!,
                    fieldLabel: AppStrings.paidAmountFor(m.name),
                    onChanged: () => _onChanged(m.id),
                    currency: widget.initial.currency,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
