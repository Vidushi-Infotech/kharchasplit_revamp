import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/components.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../data/groups/groups_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/group_member_balances.dart';
import '../widgets/group_detail_action_chips.dart';
import '../widgets/group_detail_layouts.dart';
import '../widgets/group_detail_top_bar.dart';

/// A group: cover banner, your balance in it, action chips (Settle up,
/// Balances, Totals, Export, Recurring) and every expense and payment in
/// one month-grouped list. Members and admin actions live in Group
/// settings (⚙); Balances and Totals are their own pages.
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home/groups');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final myId = ref.watch(myIdProvider);
    final recurringOn = watchFeature(ref, 'recurring');
    final detail = detailAsync.value;

    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background(isDark),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.background(isDark),
          leading: GlassIconButton.isGlass
              ? GlassBackButton(onPressed: () => _back(context))
              : BackButton(onPressed: () => _back(context)),
        ),
        body: detailAsync.hasError
            ? _buildErrorState(context, ref, detailAsync.error!)
            : const ShimmerList(type: ShimmerListType.group),
      );
    }

    final isAdmin = isGroupAdmin(detail, myId);
    final topBar = GroupDetailSliverBar(
      detail: detail,
      myId: myId,
      onBack: () => _back(context),
      // A direct (non-group) group has no members to manage or admin, so
      // it has no settings page.
      onSettings: detail.group.isDirect
          ? null
          : () => openGroupPage(context, groupId, 'settings'),
      onRecurring: recurringOn
          ? () => openGroupPage(context, groupId, 'recurring')
          : null,
      onMenuExport: (value) => runGroupExport(context, ref, detail, value),
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: screenWidth < 1100
          ? GroupDetailScrollLayout(
              detail: detail,
              myId: myId,
              isAdmin: isAdmin,
              topBar: topBar,
            )
          : GroupDetailLargeLayout(
              detail: detail,
              myId: myId,
              isAdmin: isAdmin,
              topBar: topBar,
            ),
      // On web the create action sits in the list pane header instead; a
      // floating button over a desktop layout reads as a phone app.
      floatingActionButton: context.widthTier.isWebTier || screenWidth >= 1100
          ? null
          : _AddExpenseFab(
              archived: detail.group.isArchived,
              onTap: () => navigateToAddGroupExpense(
                groupId,
                context,
                archived: detail.group.isArchived,
              ),
            ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object err) {
    final status = err is GroupsApiException ? err.statusCode : null;
    final isAccessDenied = status == 403;
    final isMissing = status == 404;

    final title = isAccessDenied
        ? "You don't have access to this group"
        : isMissing
        ? 'This group no longer exists'
        : 'Failed to load group details';
    final message = isAccessDenied
        ? "It looks like you're no longer a member, or this group belongs to a different account."
        : isMissing
        ? "The group may have been deleted. Pick another from your list."
        : (err is GroupsApiException ? err.message : err.toString());

    final showRetry = !isAccessDenied && !isMissing;

    return ErrorStateWidget(
      title: title,
      message: message,
      onRetry: showRetry
          ? () => ref.invalidate(groupDetailProvider(groupId))
          : null,
      onSecondaryAction: () => context.go('/home/groups'),
      secondaryActionLabel: 'Back to Groups',
    );
  }
}

/// Extended "Add expense" button. Archived groups take no new expenses: it
/// stays visible but greyed out, and tapping it explains why.
class _AddExpenseFab extends StatelessWidget {
  const _AddExpenseFab({required this.archived, required this.onTap});

  final bool archived;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: archived ? AppStrings.addExpenseArchived : AppStrings.addExpense,
      excludeSemantics: true,
      onTap: onTap,
      child: FloatingActionButton.extended(
        onPressed: onTap,
        backgroundColor: archived
            ? AppColors.textSecondary(isDark)
            : AppColors.brand,
        foregroundColor: Colors.white,
        icon: Icon(
          archived ? Icons.lock_outline_rounded : Icons.receipt_long_rounded,
        ),
        label: const Text(AppStrings.addExpense),
      ),
    );
  }
}
