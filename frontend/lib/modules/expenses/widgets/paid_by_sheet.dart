import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_sheet_header.dart';
import 'multi_payer_sheet.dart';

/// "Who paid?" bottom sheet. [context] and [ref] are the Add-expense
/// screen's own, so the sheet behaves exactly as when it lived there.
///
/// [allowMultiple] (the multiPayer flag) adds "Multiple people". An expense
/// that already has several payers always gets it, flag or not, so editing
/// never drops them.
void showPaidBySheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required AddExpenseState state,
  required List<UserModel> groupMembers,
  bool allowMultiple = false,
}) {
  final showMultiple = allowMultiple || state.payers.isNotEmpty;
  if (groupMembers.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No group selected.')));
    return;
  }
  showModalBottomSheet(
    context: context,
    // Above the floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
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
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(text: AppStrings.choosePayer, isDark: isDark),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: groupMembers.length + (showMultiple ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == groupMembers.length) {
                    return _MultiplePeopleRow(
                      isDark: isDark,
                      selected: state.payers.isNotEmpty,
                      onTap: () {
                        HapticService.instance.tap();
                        Navigator.pop(ctx);
                        showMultiPayerSheet(
                          context,
                          ref,
                          isDark: isDark,
                          groupMembers: groupMembers,
                        );
                      },
                    );
                  }
                  final m = groupMembers[i];
                  final isMe = me != null && m.id == me.id;
                  final label = isMe ? '${m.name} (Me)' : m.name;
                  final selected =
                      state.payers.isEmpty &&
                      (state.paidBy == null ? isMe : state.paidBy!.id == m.id);
                  return InkWell(
                    onTap: () {
                      HapticService.instance.tap();
                      // One payer again: forget any multiple payers.
                      ref.read(addExpenseProvider.notifier).state = state
                          .copyWith(paidBy: m, payers: const {});
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

/// "Multiple people" entry at the bottom of the payer list.
class _MultiplePeopleRow extends StatelessWidget {
  const _MultiplePeopleRow({
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AppStrings.multiplePeople,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected
              ? AppColors.tealDark.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.tealDark.withValues(alpha: 0.12),
                child: Icon(
                  Icons.group_rounded,
                  size: 18,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.multiplePeople,
                  style: AppTextStyles.body1(
                    isDark,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected
                    ? AppColors.tealDark
                    : AppColors.textSecondary(isDark),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
