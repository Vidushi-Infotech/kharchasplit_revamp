import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/models.dart';
import '../../../modules/auth/state/auth_provider.dart';
import '../state/add_expense_provider.dart';
import 'add_expense_sheet_header.dart';

/// "Who paid?" bottom sheet. [context] and [ref] are the Add-expense
/// screen's own, so the sheet behaves exactly as when it lived there.
void showPaidBySheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isDark,
  required AddExpenseState state,
  required List<UserModel> groupMembers,
}) {
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
            AddExpenseSheetHandle(isDark: isDark),
            AddExpenseSheetTitle(text: 'Who paid?', isDark: isDark),
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
