import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/expense_comments_provider.dart';
import 'expense_comments_tile.dart';

/// "Comments" section of the expense detail screen, as slivers so the list
/// builds lazily inside the screen's scroll view. The input box lives at
/// the bottom of the screen ([ExpenseCommentInput]).
class ExpenseCommentsSliver extends ConsumerWidget {
  const ExpenseCommentsSliver({
    super.key,
    required this.expenseId,
    required this.isDark,
    this.memberIds,
  });

  final String expenseId;
  final bool isDark;

  /// Current group members; authors outside it are tagged "Former member".
  /// Null while the group is still loading (no tag shown).
  final Set<String>? memberIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseCommentsProvider(expenseId));
    final comments = async.value;

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 22, bottom: 4),
        child: Text(
          comments == null || comments.isEmpty
              ? AppStrings.comments.toUpperCase()
              : '${AppStrings.comments.toUpperCase()} · ${comments.length}',
          style: AppTextStyles.caption(isDark).copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            fontSize: 11,
          ),
        ),
      ),
    );

    final Widget body;
    if (comments != null && comments.isNotEmpty) {
      body = SliverList.builder(
        itemCount: comments.length,
        itemBuilder: (_, i) {
          final c = comments[i];
          return ExpenseCommentTile(
            key: ValueKey(c.id),
            expenseId: expenseId,
            comment: c,
            isDark: isDark,
            isFormerMember:
                memberIds != null && !memberIds!.contains(c.userId),
          );
        },
      );
    } else if (comments != null) {
      body = SliverToBoxAdapter(
        child: _Note(
          isDark: isDark,
          icon: Icons.chat_bubble_outline_rounded,
          title: AppStrings.noCommentsYet,
          subtitle: AppStrings.noCommentsYetHint,
        ),
      );
    } else if (async.hasError) {
      body = SliverToBoxAdapter(
        child: _Note(
          isDark: isDark,
          icon: Icons.cloud_off_rounded,
          title: AppStrings.commentsLoadFailed,
          action: TextButton(
            onPressed: () => ref.invalidate(expenseCommentsProvider(expenseId)),
            child: const Text(AppStrings.retry),
          ),
        ),
      );
    } else {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(slivers: [header, body]);
  }
}

/// Compact empty / error card for the section.
class _Note extends StatelessWidget {
  const _Note({
    required this.isDark,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body2(
                    isDark,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption(
                      isDark,
                    ).copyWith(color: AppColors.textSecondary(isDark)),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
