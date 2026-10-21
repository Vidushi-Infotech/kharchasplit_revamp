import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/components.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../data/groups/groups_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../widgets/group_admin_actions.dart';
import '../widgets/group_detail_layouts.dart';
import '../widgets/group_detail_top_bar.dart';
import '../widgets/group_lifecycle_actions.dart';
import '../widgets/group_member_actions.dart';
import '../widgets/group_simplify_debts.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final myId = ref.watch(myIdProvider);
    final loadedDetail = detailAsync.value;
    // A direct (non-group) group has no admin: the server rejects every
    // admin action on it, so none of them is offered.
    final isDirect = loadedDetail?.group.isDirect ?? false;
    final isAdmin =
        loadedDetail != null &&
        myId != null &&
        !isDirect &&
        loadedDetail.group.createdBy == myId;

    // NOTE on the inner Consumers below: `tab` deliberately is NOT
    // watched here in the outer build. Tab switches are the most
    // frequent state change on this screen; without the inner scoping
    // every switch would rebuild the entire 2946-line widget tree
    // (including GroupDetailTopBar, layout switches, and the refresh
    // indicator). Confining the tab watch to the body + FAB Consumers
    // means tab changes only repaint those two regions.
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: GroupDetailTopBar(
        isDark: isDark,
        isAdmin: isAdmin,
        isDirect: isDirect,
        canManage: loadedDetail != null && myId != null,
        onClose: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home/groups');
          }
        },
        onAddMember: () => showGroupInviteDialog(groupId, context, ref),
        onEditGroup: loadedDetail == null
            ? null
            : () => openEditGroupSheet(context, ref, loadedDetail.group),
        onLeaveGroup: () => confirmLeaveGroup(groupId, context, ref, myId),
        onDeleteGroup: () => confirmDeleteGroup(groupId, context, ref),
        onExportGroup: loadedDetail == null
            ? null
            : () => exportGroup(groupId, context, ref, loadedDetail.group),
        lifecycleItems: loadedDetail == null
            ? const []
            : [
                ...buildGroupLifecycleMenuItems(isDark, loadedDetail.group),
                // The flag only hides the switch; a group simplified on a
                // newer build still shows simplified balances.
                if (watchFeature(ref, 'simplifyDebts'))
                  buildSimplifyDebtsMenuItem(isDark, loadedDetail.group),
              ],
        onLifecycleAction: loadedDetail == null
            ? null
            : (value) => value == simplifyDebtsMenuValue
                  ? showSimplifyDebtsSheet(context, groupId)
                  : handleGroupLifecycleAction(
                      value,
                      context,
                      ref,
                      loadedDetail,
                    ),
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.group),
        error: (err, stack) => _buildErrorState(context, ref, err),
        data: (detail) => Consumer(
          builder: (context, ref, _) {
            final tab = ref.watch(groupTabProvider);
            final body = screenWidth < 600
                ? buildGroupCompactLayout(
                    groupId,
                    context,
                    isDark,
                    detail,
                    tab,
                    ref,
                    myId,
                    isAdmin,
                  )
                : screenWidth < 1100
                ? buildGroupStandardLayout(
                    groupId,
                    context,
                    isDark,
                    detail,
                    tab,
                    ref,
                    myId,
                    isAdmin,
                  )
                : buildGroupLargeLayout(
                    groupId,
                    context,
                    isDark,
                    detail,
                    tab,
                    ref,
                    myId,
                    isAdmin,
                  );
            // Outer RefreshIndicator catches pulls from the very TOP of the
            // header (above the sticky tab bar). Each tab body below also
            // has its own RefreshIndicator so the swipe works from inside
            // the list / scroll view — see _buildTabBody. All three call
            // the same _refreshAllTabs so any pull always reloads the
            // group's full state (balances, expenses, members, activity,
            // pending settlements).
            return RefreshIndicator(
              onRefresh: () => refreshAllGroupTabs(groupId, ref),
              child: body,
            );
          },
        ),
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final tab = ref.watch(groupTabProvider);
          if (tab != GroupTab.expenses) return const SizedBox.shrink();
          // On web the create action sits in the content pane header instead;
          // a floating circle over a desktop layout reads as a phone app.
          if (context.widthTier.isWebTier) return const SizedBox.shrink();
          // Archived groups take no new expenses: the FAB stays visible but
          // greyed out, and tapping it explains why.
          final archived = loadedDetail?.group.isArchived ?? false;
          void onAdd() =>
              navigateToAddGroupExpense(groupId, context, archived: archived);
          return Semantics(
            button: true,
            label: archived
                ? 'Add expense unavailable, group archived'
                : 'Add expense button',
            onTap: onAdd,
            child: FloatingActionButton(
              onPressed: onAdd,
              backgroundColor: archived
                  ? AppColors.textSecondary(isDark)
                  : AppColors.brand,
              child: Icon(
                archived ? Icons.lock_outline_rounded : Icons.add_rounded,
                color: Colors.white,
              ),
            ),
          );
        },
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
