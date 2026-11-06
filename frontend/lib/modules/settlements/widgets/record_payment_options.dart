import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../../../models/settlement_model.dart';
import 'payment_method_selector.dart';

/// [📅 Today] [👥 Goa trip] [💳 Cash] [📝 Note] under the amount on the
/// Record a payment screen; each opens a picker. The date can go back up
/// to a year, for a payment recorded later.
class RecordPaymentOptions extends StatelessWidget {
  const RecordPaymentOptions({
    super.key,
    required this.isDark,
    required this.groups,
    required this.selectedGroup,
    required this.method,
    required this.paidOn,
    required this.onPaidOnChanged,
    required this.notesController,
    required this.onGroupChanged,
    required this.onMethodChanged,
  });

  final bool isDark;

  /// Groups shared with the person being paid.
  final List<GroupModel> groups;
  final GroupModel? selectedGroup;
  final SettlementMethod? method;
  final DateTime paidOn;
  final ValueChanged<DateTime> onPaidOnChanged;

  /// Owned by the screen.
  final TextEditingController notesController;
  final ValueChanged<GroupModel> onGroupChanged;
  final ValueChanged<SettlementMethod?> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: notesController,
      builder: (context, notes, _) => ActionChipBar(
        items: [
          ActionChipItem(
            icon: Icons.calendar_today_outlined,
            label: DateUtils.isSameDay(paidOn, DateTime.now())
                ? AppStrings.todayLabel
                : DateFormat('d MMM').format(paidOn),
            onTap: () => _pickDate(context),
          ),
          ActionChipItem(
            icon: Icons.group_outlined,
            label: selectedGroup?.name ?? AppStrings.inWhichGroup,
            onTap: () => _pickGroup(context),
          ),
          ActionChipItem(
            icon: Icons.payments_outlined,
            label: method?.label ?? AppStrings.methodLabel,
            onTap: () => _pickMethod(context),
          ),
          ActionChipItem(
            icon: Icons.edit_note_rounded,
            label: notes.text.trim().isEmpty
                ? AppStrings.noteLabel
                : (notes.text.trim().length > 18
                      ? '${notes.text.trim().substring(0, 16)}…'
                      : notes.text.trim()),
            onTap: () => _editNote(context),
          ),
        ],
      ),
    );
  }

  Future<T?> _sheet<T>(BuildContext context, String title, Widget body) {
    return showModalBottomSheet<T>(
      context: context,
      // Above the floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  title,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Flexible(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: paidOn,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked != null) {
      HapticService.instance.selection();
      onPaidOnChanged(picked);
    }
  }

  void _pickGroup(BuildContext context) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.noSharedGroups)));
      return;
    }
    _sheet<void>(
      context,
      AppStrings.inWhichGroup,
      Builder(
        builder: (ctx) => ListView.builder(
          shrinkWrap: true,
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final g = groups[i];
            return KsListRow(
              dense: true,
              leading: const CategoryTile(
                icon: Icons.group_rounded,
                color: AppColors.tealDark,
                size: 40,
              ),
              title: g.name,
              trailing: g.id == selectedGroup?.id
                  ? const Icon(Icons.check_rounded, color: AppColors.tealDark)
                  : null,
              onTap: () {
                HapticService.instance.tap();
                Navigator.pop(ctx);
                onGroupChanged(g);
              },
            );
          },
        ),
      ),
    );
  }

  void _pickMethod(BuildContext context) {
    _sheet<void>(
      context,
      AppStrings.paymentMethod,
      Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: PaymentMethodSelector(
            showLabel: false,
            selected: method,
            onChanged: (m) {
              Navigator.pop(ctx);
              onMethodChanged(m);
            },
          ),
        ),
      ),
    );
  }

  void _editNote(BuildContext context) {
    _sheet<void>(
      context,
      AppStrings.notesOptional,
      Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: notesController,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Dinner share',
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.tealDark,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
