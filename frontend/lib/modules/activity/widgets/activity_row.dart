import 'package:flutter/material.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/activity_model.dart';
import '../../../models/category_model.dart';
import '../../expenses/state/add_expense_category_suggest.dart';
import '../state/activity_sentence.dart';

/// One Activity row, Splitwise-style: a category tile with the actor's
/// avatar on its corner, the sentence (names in bold), an optional money
/// line, and the time. Unread rows get a faint tint and a dot. Tapping
/// opens the expense or group.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.activity,
    required this.sentence,
    required this.badgeName,
    required this.onTap,
    this.showDivider = true,
  });

  final ActivityModel activity;
  final ActivitySentence sentence;

  /// Real name for the avatar initials ("You" has none of its own).
  final String badgeName;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final unread = !activity.isRead;
    final secondary = AppColors.textSecondary(isDark);
    final base = textTheme.bodyMedium?.copyWith(
      color: AppColors.textPrimary(isDark),
      height: 1.35,
    );
    final amountColor = switch (sentence.amountTone) {
      ActivityAmountTone.paid => AppColors.owe,
      ActivityAmountTone.received => AppColors.owed,
      ActivityAmountTone.neutral => secondary,
    };
    final time = activityTimeLabel(activity.timestamp);

    return Semantics(
      button: onTap != null,
      label: [
        if (unread) AppStrings.unread,
        sentence.text,
        ?sentence.amountLine,
        time,
      ].join('. '),
      excludeSemantics: true,
      child: Material(
        color: unread
            ? AppColors.brand.withValues(alpha: isDark ? 0.10 : 0.05)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: AppColors.divider(isDark),
                        width: 0.6,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityTile(activity: activity, badgeName: badgeName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              for (final s in sentence.spans)
                                TextSpan(
                                  text: s.text,
                                  style: s.bold
                                      ? const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        )
                                      : null,
                                ),
                            ],
                          ),
                          style: base,
                        ),
                        if (sentence.amountLine != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              sentence.amountLine!,
                              style: textTheme.bodySmall?.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            time,
                            style: textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unread)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 6),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Category (or event) tile with the actor's avatar badge.
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.badgeName});

  final ActivityModel activity;
  final String badgeName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = AvatarWidget(
      name: badgeName,
      radius: 9,
      borderWidth: 1.5,
      borderColor: AppColors.background(isDark),
    );
    final (icon, color) = _iconFor(activity, isDark);
    return CategoryTile(icon: icon, color: color, size: 42, badge: badge);
  }

  static (IconData, Color) _iconFor(ActivityModel a, bool isDark) {
    switch (a.type) {
      case ActivityType.expenseAdded:
      case ActivityType.expenseEdited:
      case ActivityType.expenseDeleted:
      case ActivityType.commentAdded:
        // The expense's own category; older servers don't send it, so the
        // title's keywords pick one.
        final title = a.metadata['expenseDescription']?.toString() ?? '';
        final c =
            (a.category == null ? null : CategoryModel.fromId(a.category!)) ??
            categoryFromKeywords(title) ??
            CategoryModel.other;
        return (c.icon, CategoryTile.colorFromHex(c.colorHex));
      case ActivityType.settled:
      case ActivityType.settlementConfirmed:
      case ActivityType.settlementDeleted:
        return (Icons.payments_rounded, AppColors.owed);
      case ActivityType.groupCreated:
      case ActivityType.groupUpdated:
      case ActivityType.groupArchived:
      case ActivityType.groupDeleted:
        return (Icons.group_rounded, AppColors.brand);
      case ActivityType.memberAdded:
      case ActivityType.memberRoleUpdated:
        return (Icons.person_add_alt_1_rounded, AppColors.brand);
      case ActivityType.memberRemoved:
        return (Icons.person_remove_alt_1_rounded, AppColors.brand);
      case ActivityType.other:
        return (
          Icons.notifications_none_rounded,
          BalanceTone.settled.color(isDark),
        );
    }
  }
}
