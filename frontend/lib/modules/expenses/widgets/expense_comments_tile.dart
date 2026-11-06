import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/avatar/avatar_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/expenses/expense_extras_repository.dart';
import '../state/expense_comments_provider.dart';

/// One comment: avatar, name, relative time and the text. The author can
/// long-press (or use the ⋮ button) to delete it after a confirm.
class ExpenseCommentTile extends ConsumerWidget {
  const ExpenseCommentTile({
    super.key,
    required this.expenseId,
    required this.comment,
    required this.isDark,
    this.isFormerMember = false,
  });

  final String expenseId;
  final ExpenseComment comment;
  final bool isDark;

  /// The author is no longer in the group (or their account is gone).
  final bool isFormerMember;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    HapticService.instance.thresholdCrossed();
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteCommentTitle),
        content: const Text(AppStrings.deleteCommentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorText(isDark),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(expenseCommentsControllerProvider)
        .delete(expenseId, comment.id);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? AppStrings.commentDeleted)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverFormer = comment.userName == AppStrings.formerMember;
    final when = DateFormatter.relativeTime(comment.createdAt);
    final secondary = AppColors.textSecondary(isDark);

    return Semantics(
      label: '${comment.userName}, $when: ${comment.body}',
      onLongPressHint: comment.canDelete ? AppStrings.deleteCommentTitle : null,
      child: InkWell(
        onLongPress:
            comment.canDelete ? () => _confirmDelete(context, ref) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarWidget(
                name: comment.userName,
                imageUrl: comment.userAvatar,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: comment.userName,
                            style: AppTextStyles.body2(isDark).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isFormerMember && !serverFormer)
                            TextSpan(
                              text: ' · ${AppStrings.formerMember}',
                              style: AppTextStyles.caption(
                                isDark,
                              ).copyWith(color: secondary),
                            ),
                          TextSpan(
                            text: '  $when',
                            style: AppTextStyles.caption(
                              isDark,
                            ).copyWith(color: secondary),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      comment.body,
                      style: AppTextStyles.body2(
                        isDark,
                      ).copyWith(color: AppColors.textPrimary(isDark), height: 1.4),
                    ),
                  ],
                ),
              ),
              if (comment.canDelete)
                IconButton(
                  tooltip: AppStrings.deleteCommentTitle,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: secondary),
                  onPressed: () => _confirmDelete(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
