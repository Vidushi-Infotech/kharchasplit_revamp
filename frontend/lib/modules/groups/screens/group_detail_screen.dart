import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../components/components.dart';
import '../../../data/groups/groups_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Group Details'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'invite') {
                _showInviteDialog(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'invite', child: Text('Invite member')),
            ],
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const ShimmerList(type: ShimmerListType.group),
        error: (err, stack) => _buildErrorState(context, ref, err),
        data: (detail) {
          if (screenWidth < 600) {
            return _buildCompactLayout(context, isDark, detail, tab, ref);
          } else if (screenWidth < 1100) {
            return _buildStandardLayout(context, isDark, detail, tab, ref);
          } else {
            return _buildLargeLayout(context, isDark, detail, tab, ref);
          }
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
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return AlertDialog(
              title: const Text('Invite member'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone (10 digits or +<country><number>)',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Phone required';
                        if (!RegExp(r'^(\+\d{10,15}|\d{10})$').hasMatch(s)) {
                          return 'Use 10 digits or +91XXXXXXXXXX';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          setLocal(() => submitting = true);
                          try {
                            await ref.read(groupsRepositoryProvider).invitePhone(
                                  groupId: groupId,
                                  name: nameController.text.trim(),
                                  phoneNumber: phoneController.text.trim(),
                                );
                            ref.invalidate(groupDetailProvider(groupId));
                            ref.invalidate(groupsProvider);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invite sent.')),
                              );
                            }
                          } catch (e) {
                            setLocal(() => submitting = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Could not invite: $e')),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
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
            _buildBalancesList(context, isDark, detail),
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
            _buildBalancesList(context, isDark, detail),
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
                          : _buildBalancesList(context, isDark, detail),
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

  // Compact header: <600px - optimized for mobile (tight spacing 16-20px)
  Widget _buildCompactHeader(BuildContext context, bool isDark, GroupDetail detail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  detail.group.name,
                  style: AppTextStyles.headline3(isDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Statistics in a compact row
          Row(
            children: [
              Expanded(
                child: _buildCompactStatistic(
                  context,
                  isDark,
                  'Total',
                  CurrencyFormatter.format(detail.totalExpense),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatistic(
                  context,
                  isDark,
                  'Members',
                  '${detail.members.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatistic(
                  context,
                  isDark,
                  'Expenses',
                  '${detail.expenses.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Members list
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
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: detail.members.length,
        itemBuilder: (context, index) {
          final member = detail.members[index];
          return Padding(
            padding: EdgeInsets.only(right: 12),
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
          );
        },
      ),
    );
  }

  // Members section for large layout - compact list display
  Widget _buildMembersSection(BuildContext context, bool isDark, GroupDetail detail) {
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                            member.email ?? 'No email',
                            style: AppTextStyles.caption(isDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabs(
    BuildContext context,
    bool isDark,
    GroupTab tab,
    WidgetRef ref,
  ) {
    return Container(
      color: AppColors.surface(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Expenses tab${tab == GroupTab.expenses ? ' - selected' : ''}',
              onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.expenses,
              child: GestureDetector(
                onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.expenses,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == GroupTab.expenses ? AppColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Expenses',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: tab == GroupTab.expenses
                          ? AppColors.brand
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          tab == GroupTab.expenses ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Balances tab${tab == GroupTab.balances ? ' - selected' : ''}',
              onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.balances,
              child: GestureDetector(
                onTap: () => ref.read(groupTabProvider.notifier).state = GroupTab.balances,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == GroupTab.balances ? AppColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Balances',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: tab == GroupTab.balances
                          ? AppColors.brand
                          : AppColors.textSecondary(isDark),
                      fontWeight:
                          tab == GroupTab.balances ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
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

  Widget _buildBalancesList(BuildContext context, bool isDark, GroupDetail detail) {
    final sortedBalances = detail.memberBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final verticalSpacing = isCompact ? 8.0 : 12.0;

    return Consumer(builder: (context, ref, _) {
      final myId = ref.watch(authProvider).user?.id;

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedBalances.length,
        itemBuilder: (context, index) {
          final entry = sortedBalances[index];
          final member =
              detail.members.firstWhere((m) => m.id == entry.key);
          final balance = entry.value;
          final isMe = member.id == myId;
          final isOwed = balance > 0; // they're owed money (others owe them)

          return Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: verticalSpacing,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider(isDark), width: 1),
              ),
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: member.avatarUrl,
                    name: isMe ? 'You' : member.name,
                    radius: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? 'You' : member.name,
                          style: AppTextStyles.body2(isDark)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          balance.abs() < 0.01
                              ? 'Settled up'
                              : isOwed
                                  ? 'is owed'
                                  : 'owes',
                          style: AppTextStyles.caption(isDark),
                        ),
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
                          color: balance.abs() < 0.01
                              ? AppColors.textSecondary(isDark)
                                  .withValues(alpha: 0.1)
                              : (isOwed ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          CurrencyFormatter.format(balance.abs()),
                          style: AppTextStyles.body2(isDark).copyWith(
                            color: balance.abs() < 0.01
                                ? AppColors.textSecondary(isDark)
                                : (isOwed
                                    ? AppColors.success
                                    : AppColors.warning),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isMe && balance.abs() >= 0.01) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => context.push(
                            '/settle/${member.id}?groupId=$groupId',
                          ),
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
          );
        },
      );
    });
  }
}
