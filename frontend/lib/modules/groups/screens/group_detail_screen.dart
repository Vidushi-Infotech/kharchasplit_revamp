import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/components.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../data/settlements/settlements_repository.dart';
import '../../../models/settlement_model.dart';
import '../../../models/user_model.dart';
import '../../auth/state/auth_provider.dart';
import '../../settlements/state/pending_settlements_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';
import '../widgets/contacts_picker_sheet.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final tab = ref.watch(groupTabProvider);
    final myId = ref.watch(authProvider).user?.id;
    final loadedDetail = detailAsync.value;
    final isAdmin = loadedDetail != null &&
        myId != null &&
        loadedDetail.group.createdBy == myId;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _DetailTopBar(
        isDark: isDark,
        isAdmin: isAdmin,
        canManage: loadedDetail != null && myId != null,
        onClose: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home/groups');
          }
        },
        onAddMember: () => _showInviteDialog(context, ref),
        onLeaveGroup: () => _confirmLeaveGroup(context, ref, myId),
        onDeleteGroup: () => _confirmDeleteGroup(context, ref),
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.group),
        error: (err, stack) => _buildErrorState(context, ref, err),
        data: (detail) {
          final body = screenWidth < 600
              ? _buildCompactLayout(context, isDark, detail, tab, ref)
              : screenWidth < 1100
                  ? _buildStandardLayout(context, isDark, detail, tab, ref)
                  : _buildLargeLayout(context, isDark, detail, tab, ref);
          return RefreshIndicator(
            onRefresh: () async {
              // Invalidate the family entry for this group + the pending
              // settlement providers so the screen pulls fresh data on swipe.
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(pendingIncomingSettlementsProvider(groupId));
              ref.invalidate(pendingOutgoingSettlementsProvider(groupId));
              await ref.read(groupDetailProvider(groupId).future);
            },
            child: body,
          );
        },
      ),
      floatingActionButton: tab == GroupTab.expenses
          ? Semantics(
              button: true,
              label: 'Add expense button',
              onTap: () => _navigateToAddExpense(context),
              child: FloatingActionButton(
                onPressed: () => _navigateToAddExpense(context),
                backgroundColor: AppColors.brand,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            )
          : null,
    );
  }

  void _navigateToAddExpense(BuildContext context) {
    context.pushNamed('add-expense-to-group', pathParameters: {'groupId': groupId});
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

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    // Pull current members so the picker can mark them as already-added.
    final loaded = ref.read(groupDetailProvider(groupId)).value;
    final existingPhones = loaded?.members
            .map((m) => m.phone)
            .where((p) => p.isNotEmpty) ??
        const <String>[];

    final picked = await showContactsPicker(
      context,
      doneLabel: 'Add',
      existingMemberPhones: existingPhones,
    );
    if (picked.isEmpty || !context.mounted) return;

    final repo = ref.read(groupsRepositoryProvider);
    int added = 0;
    final failures = <String>[];

    for (final c in picked) {
      final phone = c.phones.isNotEmpty ? c.phones.first.number.trim() : '';
      if (phone.isEmpty) {
        failures.add('${c.displayName} (no phone)');
        continue;
      }
      final name = c.displayName.trim().isEmpty ? phone : c.displayName.trim();
      try {
        await repo.invitePhone(
          groupId: groupId,
          name: name,
          phoneNumber: phone,
        );
        added++;
      } catch (e) {
        failures.add('${c.displayName}: ${e is GroupsApiException ? e.message : e}');
      }
    }

    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(groupsProvider);

    if (!context.mounted) return;
    final msg = failures.isEmpty
        ? (added == 1 ? '1 member added.' : '$added members added.')
        : added == 0
            ? 'Could not add: ${failures.join(', ')}'
            : '$added added · ${failures.length} failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showMemberActionsSheet({
    required BuildContext context,
    required WidgetRef ref,
    required UserModel member,
    required bool isAdmin,
    required bool isSelf,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canRemove = isAdmin && !isSelf;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    AvatarWidget(
                      imageUrl: member.avatarUrl,
                      name: member.name,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSelf ? '${member.name} (you)' : member.name,
                            style: AppTextStyles.body1(isDark)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (member.phone.isNotEmpty)
                            Text(
                              member.phone,
                              style: AppTextStyles.caption(isDark).copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canRemove) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.errorText(isDark),
                      ),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Remove from group'),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _confirmRemoveMember(context, ref, member);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    UserModel member,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          "They'll lose access to this group's expenses. You can add them back any time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(
                Theme.of(ctx).brightness == Brightness.dark,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await ref.read(groupsRepositoryProvider).removeMember(
            groupId: groupId,
            userId: member.id,
          );
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removed from group.')),
      );
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    String? myId,
  ) async {
    if (myId == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          "You can only leave once you've settled all balances with other members.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await ref
          .read(groupsRepositoryProvider)
          .leave(groupId: groupId, userId: myId);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(groupId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left the group.')),
      );
      context.go('/home/groups');
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not leave: $e')),
      );
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text(
          'This permanently deletes the group for everyone. All expenses must already be settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText(
                Theme.of(ctx).brightness == Brightness.dark,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await ref.read(groupsRepositoryProvider).delete(groupId);
      ref.invalidate(groupsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted.')),
      );
      context.go('/home/groups');
    } on GroupsApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    // Compact: <600px - full width, single column, tight spacing (16-20px)
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCompactHeader(context, isDark, detail),
          _buildTabs(context, isDark, tab, ref),
          if (tab == GroupTab.expenses)
            _buildExpensesList(context, isDark, detail)
          else
            _buildBalancesTab(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    // Standard: 600-1100px - improved spacing (24-32px), better grouped layout
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStandardHeader(context, isDark, detail),
          _buildTabs(context, isDark, tab, ref),
          if (tab == GroupTab.expenses)
            _buildExpensesList(context, isDark, detail)
          else
            _buildBalancesTab(context, isDark, detail),
        ],
      ),
    );
  }

  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    GroupDetail detail,
    GroupTab tab,
    WidgetRef ref,
  ) {
    // Large: >1100px - generous spacing (32-48px), sidebar + content layout
    return Row(
      children: [
        // Left sidebar - Group info and members (32% width)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLargeHeader(context, isDark, detail),
                  const SizedBox(height: 32),
                  _buildMembersSection(context, isDark, detail),
                ],
              ),
            ),
          ),
        ),
        // Right content area - Tabs + Expenses/Balances (68% width)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              border: Border(
                left: BorderSide(
                  color: AppColors.divider(isDark),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildTabs(context, isDark, tab, ref),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: tab == GroupTab.expenses
                          ? _buildExpensesList(context, isDark, detail)
                          : _buildBalancesTab(context, isDark, detail),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Compact header: <600px — hero gradient card + members strip
  Widget _buildCompactHeader(BuildContext context, bool isDark, GroupDetail detail) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(detail: detail),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'MEMBERS · ${detail.members.length}',
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                fontSize: 11,
              ),
            ),
          ),
          _buildMembersList(context, isDark, detail),
        ],
      ),
    );
  }

  // Standard header: 600-1100px - improved spacing (24-32px)
  Widget _buildStandardHeader(BuildContext context, bool isDark, GroupDetail detail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider(isDark),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group title with emoji
          Row(
            children: [
              Text(
                detail.group.coverEmoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  detail.group.name,
                  style: AppTextStyles.headline2(isDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Statistics in a spacious row
          Row(
            children: [
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Total',
                  CurrencyFormatter.format(detail.totalExpense),
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Members',
                  '${detail.members.length}',
                ),
              ),
              Expanded(
                child: _buildStatistic(
                  context,
                  isDark,
                  'Expenses',
                  '${detail.expenses.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Members list
          _buildMembersList(context, isDark, detail),
        ],
      ),
    );
  }

  // Large header: >1100px - generous spacing (32-48px)
  Widget _buildLargeHeader(BuildContext context, bool isDark, GroupDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group title with large emoji
        Row(
          children: [
            Text(
              detail.group.coverEmoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.group.name,
                    style: AppTextStyles.headline1(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Statistics cards stacked vertically for desktop
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Amount',
          CurrencyFormatter.format(detail.totalExpense),
          Icons.account_balance_wallet_rounded,
          AppColors.brand,
        ),
        const SizedBox(height: 12),
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Members',
          '${detail.members.length}',
          Icons.people_rounded,
          AppColors.brand,
        ),
        const SizedBox(height: 12),
        _buildLargeStatisticCard(
          context,
          isDark,
          'Total Expenses',
          '${detail.expenses.length}',
          Icons.receipt_long_rounded,
          AppColors.success,
        ),
      ],
    );
  }

  // Desktop-style statistics card with icon
  Widget _buildLargeStatisticCard(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption(isDark),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.headline3(isDark).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact statistic for mobile (reduced font size)
  Widget _buildCompactStatistic(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(isDark).copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.body2(isDark).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Standard statistic for tablet/desktop
  Widget _buildStatistic(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption(isDark),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.headline3(isDark).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  // Responsive members list - horizontal scroll for compact/standard, grid for large
  Widget _buildMembersList(BuildContext context, bool isDark, GroupDetail detail) {
    return Consumer(builder: (context, ref, _) {
      final myId = ref.watch(authProvider).user?.id;
      final isAdmin = myId != null && detail.group.createdBy == myId;
      return SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: detail.members.length,
          itemBuilder: (context, index) {
            final member = detail.members[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () => _showMemberActionsSheet(
                  context: context,
                  ref: ref,
                  member: member,
                  isAdmin: isAdmin,
                  isSelf: member.id == myId,
                ),
                child: Column(
                  children: [
                    AvatarWidget(
                      imageUrl: member.avatarUrl,
                      name: member.name,
                      radius: 24,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 56,
                      child: Text(
                        member.name.split(' ')[0],
                        style: AppTextStyles.caption(isDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // Members section for large layout - compact list display
  Widget _buildMembersSection(BuildContext context, bool isDark, GroupDetail detail) {
    return Consumer(builder: (context, ref, _) {
      final myId = ref.watch(authProvider).user?.id;
      final isAdmin = myId != null && detail.group.createdBy == myId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members (${detail.members.length})',
            style: AppTextStyles.headline3(isDark),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: detail.members.length,
            itemBuilder: (context, index) {
              final member = detail.members[index];
              final isSelf = member.id == myId;
              final canRemove = isAdmin && !isSelf;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showMemberActionsSheet(
                      context: context,
                      ref: ref,
                      member: member,
                      isAdmin: isAdmin,
                      isSelf: isSelf,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.divider(isDark),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AvatarWidget(
                            imageUrl: member.avatarUrl,
                            name: member.name,
                            radius: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: AppTextStyles.body2(isDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  member.email.isEmpty ? 'No email' : member.email,
                                  style: AppTextStyles.caption(isDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (canRemove)
                            IconButton(
                              tooltip: 'Remove from group',
                              icon: Icon(
                                Icons.person_remove_outlined,
                                color: AppColors.errorText(isDark),
                              ),
                              onPressed: () => _confirmRemoveMember(
                                context, ref, member,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildTabs(
    BuildContext context,
    bool isDark,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          _TabButton(
            label: 'Expenses',
            count: ref.watch(groupDetailProvider(groupId)).value?.expenses.length,
            selected: tab == GroupTab.expenses,
            isDark: isDark,
            onTap: () =>
                ref.read(groupTabProvider.notifier).state = GroupTab.expenses,
          ),
          const SizedBox(width: 22),
          _TabButton(
            label: 'Balances',
            count: ref.watch(groupDetailProvider(groupId)).value?.members.length,
            selected: tab == GroupTab.balances,
            isDark: isDark,
            onTap: () =>
                ref.read(groupTabProvider.notifier).state = GroupTab.balances,
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(BuildContext context, bool isDark, GroupDetail detail) {
    if (detail.expenses.isEmpty) {
      return EmptyStateWidget.noExpenses();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final verticalSpacing = isCompact ? 8.0 : 12.0;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: detail.expenses.length,
      itemBuilder: (context, index) {
        final expense = detail.expenses[index];
        return Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: verticalSpacing,
          ),
          child: Semantics(
            button: true,
            label: 'Expense - ${expense.title} for ₹${expense.amount}',
            child: ExpenseCard(
              expense: expense,
              onTap: () {
                context.push('/expense/${expense.id}');
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(BuildContext context, bool isDark, GroupDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PendingIncomingSettlementsSection(groupId: groupId),
        _PendingOutgoingSettlementsSection(groupId: groupId),
        _buildBalancesList(context, isDark, detail),
      ],
    );
  }

  /// Pairwise debts from the current user's perspective:
  ///   pairwise[otherId] > 0  → I owe them that much
  ///   pairwise[otherId] < 0  → they owe me that much
  ///
  /// Built from expense splits + settlements, excluding failed settlements.
  Map<String, double> _pairwiseDebts({
    required String myId,
    required GroupDetail detail,
  }) {
    final pair = <String, double>{};
    for (final expense in detail.expenses) {
      final paidBy = expense.paidBy.id;
      if (paidBy == myId) {
        // I paid → each other split-user owes me their share.
        for (final split in expense.splits) {
          if (split.userId == myId) continue;
          pair[split.userId] = (pair[split.userId] ?? 0) - split.owedShare;
        }
      } else {
        // Someone else paid → if I'm in the splits, I owe them my share.
        for (final split in expense.splits) {
          if (split.userId != myId) continue;
          pair[paidBy] = (pair[paidBy] ?? 0) + split.owedShare;
        }
      }
    }
    for (final s in detail.settlements) {
      if (s.status == SettlementStatus.failed) continue;
      if (s.fromUser.id == myId) {
        // I paid them → my debt to them shrinks.
        pair[s.toUser.id] = (pair[s.toUser.id] ?? 0) - s.amount;
      } else if (s.toUser.id == myId) {
        // They paid me → effectively reduces what they owe me
        // (or, equivalently, increases my net debt to them).
        pair[s.fromUser.id] = (pair[s.fromUser.id] ?? 0) + s.amount;
      }
    }
    return pair;
  }

  Widget _buildBalancesList(BuildContext context, bool isDark, GroupDetail detail) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final verticalSpacing = isCompact ? 8.0 : 12.0;

    return Consumer(builder: (context, ref, _) {
      final myId = ref.watch(authProvider).user?.id;
      if (myId == null) return const SizedBox.shrink();

      final pair = _pairwiseDebts(myId: myId, detail: detail);
      final iOwe = pair.entries
          .where((e) => e.value > 0.01)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final owedToMe = pair.entries
          .where((e) => e.value < -0.01)
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      if (iOwe.isEmpty && owedToMe.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 32,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(isDark), width: 1),
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  'All settled up',
                  style: AppTextStyles.body1(isDark)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'No one owes anyone in this group.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(isDark).copyWith(
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (iOwe.isNotEmpty) ...[
            _buildSectionHeader(
              'You owe',
              isDark: isDark,
              padding: horizontalPadding,
            ),
            ...iOwe.map((e) => _buildPairRow(
                  context: context,
                  isDark: isDark,
                  detail: detail,
                  otherId: e.key,
                  amount: e.value, // positive
                  iOweThem: true,
                  horizontalPadding: horizontalPadding,
                  verticalSpacing: verticalSpacing,
                )),
          ],
          if (owedToMe.isNotEmpty) ...[
            _buildSectionHeader(
              'Owed to you',
              isDark: isDark,
              padding: horizontalPadding,
            ),
            ...owedToMe.map((e) => _buildPairRow(
                  context: context,
                  isDark: isDark,
                  detail: detail,
                  otherId: e.key,
                  amount: e.value.abs(),
                  iOweThem: false,
                  horizontalPadding: horizontalPadding,
                  verticalSpacing: verticalSpacing,
                )),
          ],
        ],
      );
    });
  }

  Widget _buildSectionHeader(
    String label, {
    required bool isDark,
    required double padding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 4, padding, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption(isDark).copyWith(
          color: AppColors.textSecondary(isDark),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildPairRow({
    required BuildContext context,
    required bool isDark,
    required GroupDetail detail,
    required String otherId,
    required double amount,
    required bool iOweThem,
    required double horizontalPadding,
    required double verticalSpacing,
  }) {
    final member = detail.members
        .where((m) => m.id == otherId)
        .cast<UserModel?>()
        .firstWhere((m) => true, orElse: () => null);
    if (member == null) return const SizedBox.shrink();

    final accent = iOweThem ? AppColors.warning : AppColors.success;
    final caption = iOweThem ? 'You owe' : 'Owes you';

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: verticalSpacing,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(
            '/home/groups/$groupId/settlements-with/${member.id}',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.divider(isDark), width: 1),
            ),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: member.avatarUrl,
                  name: member.name,
                  radius: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: AppTextStyles.body2(isDark)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(caption, style: AppTextStyles.caption(isDark)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        CurrencyFormatter.format(amount),
                        style: AppTextStyles.body2(isDark).copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (iOweThem) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          context.push(
                            '/settle/${member.id}?groupId=$groupId&amount=${amount.toStringAsFixed(2)}',
                          );
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: const Size(0, 28),
                        ),
                        child: const Text('Settle Up'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailTopBar({
    required this.isDark,
    required this.onClose,
    required this.onAddMember,
    required this.onLeaveGroup,
    required this.onDeleteGroup,
    required this.isAdmin,
    required this.canManage,
  });

  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onAddMember;
  final VoidCallback onLeaveGroup;
  final VoidCallback onDeleteGroup;

  /// True when the signed-in user is the group's admin/creator.
  final bool isAdmin;

  /// False while the group detail is still loading — hides Leave/Delete to
  /// avoid acting on stale state.
  final bool canManage;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                isDark: isDark,
                onTap: onClose,
                label: 'Back',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Group',
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'More options',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: PopupMenuButton<String>(
                    color: AppColors.cardBg(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.divider(isDark)),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'add_member':
                          onAddMember();
                          break;
                        case 'leave':
                          onLeaveGroup();
                          break;
                        case 'delete':
                          onDeleteGroup();
                          break;
                      }
                    },
                    icon: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'add_member',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 18,
                              color: AppColors.textPrimary(isDark),
                            ),
                            const SizedBox(width: 10),
                            const Text('Add member'),
                          ],
                        ),
                      ),
                      if (canManage)
                        PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 10),
                              const Text('Leave group'),
                            ],
                          ),
                        ),
                      if (canManage && isAdmin)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.errorText(isDark),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Delete group',
                                style: TextStyle(
                                  color: AppColors.errorText(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider(isDark)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail});
  final GroupDetail detail;

  static const String _defaultPeopleEmoji = '👥';

  @override
  Widget build(BuildContext context) {
    final emoji = detail.group.coverEmoji;
    final hasCustomEmoji =
        emoji.isNotEmpty && emoji != _defaultPeopleEmoji;
    final total = CurrencyFormatter.format(detail.totalExpense, currency: '₹');
    final memberCount = detail.members.length;
    final expenseCount = detail.expenses.length;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealLight, AppColors.tealDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -30,
              right: -20,
              child: _Orb(size: 140, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: hasCustomEmoji
                            ? Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              )
                            : const Icon(
                                Icons.group_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GROUP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          label: 'TOTAL SPENT',
                          value: total,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: 'MEMBERS',
                          value: '$memberCount',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: 'EXPENSES',
                          value: '$expenseCount',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.textPrimary(isDark)
        : AppColors.textSecondary(isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body1(isDark).copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 2,
              width: selected ? 24 : 0,
              decoration: BoxDecoration(
                color: AppColors.tealDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending settlements where the current user is the recipient.
/// Shown above the balances list; tap Confirm to flip status pending → completed.
class _PendingIncomingSettlementsSection extends ConsumerWidget {
  const _PendingIncomingSettlementsSection({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingIncomingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'Confirm payments received',
                  style: AppTextStyles.body2(isDark)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _PendingSettlementTile(
                settlement: s,
                groupId: groupId,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingSettlementTile extends ConsumerStatefulWidget {
  const _PendingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_PendingSettlementTile> createState() =>
      _PendingSettlementTileState();
}

class _PendingSettlementTileState
    extends ConsumerState<_PendingSettlementTile> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return; // anti-double-tap (rebuild can momentarily reset _busy)
    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .confirm(widget.settlement.id as String);
      ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement confirmed')),
      );
    } catch (e) {
      // "Settlement already confirmed / not found" means our intent already
      // succeeded — usually a duplicate tap that slipped past the rebuild.
      // Treat as success: refresh providers, no scary snackbar.
      final msg = e.toString().toLowerCase();
      final benign = msg.contains('already confirmed') ||
          msg.contains('not found');
      if (benign) {
        ref.invalidate(pendingIncomingSettlementsProvider(widget.groupId));
        ref.invalidate(groupDetailProvider(widget.groupId));
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final fromName = (s.fromUser.name as String).isEmpty
        ? 'Someone'
        : s.fromUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$fromName paid you ${CurrencyFormatter.format(s.amount as double)}',
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Pending settlements the current user *sent* (awaiting recipient confirmation).
/// Lets the sender withdraw via DELETE /settlements/:id.
class _PendingOutgoingSettlementsSection extends ConsumerWidget {
  const _PendingOutgoingSettlementsSection({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPending = ref.watch(pendingOutgoingSettlementsProvider(groupId));
    final items = asyncPending.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_send_rounded,
                    size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  'Awaiting confirmation',
                  style: AppTextStyles.body2(isDark)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in items)
              _OutgoingSettlementTile(
                settlement: s,
                groupId: groupId,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingSettlementTile extends ConsumerStatefulWidget {
  const _OutgoingSettlementTile({
    required this.settlement,
    required this.groupId,
    required this.isDark,
  });

  final dynamic settlement; // SettlementModel
  final String groupId;
  final bool isDark;

  @override
  ConsumerState<_OutgoingSettlementTile> createState() =>
      _OutgoingSettlementTileState();
}

class _OutgoingSettlementTileState
    extends ConsumerState<_OutgoingSettlementTile> {
  bool _busy = false;

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this pending settlement?'),
        content: const Text(
            'The recipient will no longer see this payment as pending. '
            'You can record it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(settlementsRepositoryProvider)
          .delete(widget.settlement.id as String);
      ref.invalidate(pendingOutgoingSettlementsProvider(widget.groupId));
      ref.invalidate(groupDetailProvider(widget.groupId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final toName = (s.toUser.name as String).isEmpty
        ? 'Someone'
        : s.toUser.name as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You sent $toName ${CurrencyFormatter.format(s.amount as double)}',
              style: AppTextStyles.body2(widget.isDark),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText(widget.isDark),
              side: BorderSide(color: AppColors.errorText(widget.isDark)),
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
