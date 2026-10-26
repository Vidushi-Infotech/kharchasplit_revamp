import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/buttons/donate_heart_button.dart';
import '../../../components/list/list_components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/state/dashboard_provider.dart';
import '../state/groups_list_view.dart';
import '../../../components/buttons/glass_icon_button.dart';
import 'groups_notifications_button.dart';

/// "Groups" title with the bell, donate heart, search and create-group
/// actions. Shows a back arrow only when the screen was pushed.
class GroupsTopBar extends StatelessWidget {
  const GroupsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          if (canPop) const GlassBackButton() else const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                AppStrings.groups,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const GroupsNotificationsButton(size: 36),
          const SizedBox(width: 6),
          const DonateHeartButton(size: 36, iconSize: 17),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.search_rounded,
            sfSymbol: 'magnifyingglass',
            tooltip: AppStrings.search,
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.group_add_outlined,
            sfSymbol: 'person.badge.plus',
            tooltip: AppStrings.createGroupTooltip,
            onPressed: () => context.push('/home/create-group'),
          ),
        ],
      ),
    );
  }
}

/// "Overall, you are owed ₹X" with the filter menu on the right. When
/// money flows both ways a second line splits it ("You are owed ₹A ·
/// You owe ₹B"); each half opens its drill-down screen.
class GroupsOverallHeader extends ConsumerWidget {
  const GroupsOverallHeader({super.key});

  static const double _epsilon = 0.005;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = ref.watch(dashboardProvider).value;
    // First load: keep the line's height without claiming "settled up".
    if (data == null) {
      return Column(
        children: [
          const SizedBox(height: 48),
          Divider(height: 1, color: AppColors.divider(isDark)),
        ],
      );
    }
    final net = data.totalBalance;
    final owed = data.youAreOwed;
    final owe = data.youOwe;
    final hasOwed = owed > _epsilon;
    final hasOwe = owe > _epsilon;

    void open(String location) {
      HapticService.instance.selection();
      context.push(location);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverallBalanceHeader(
          net: net,
          trailing: const _GroupsFilterButton(),
          onTap: hasOwed && !hasOwe
              ? () => open('/home/owed-to-me')
              : hasOwe && !hasOwed
              ? () => open('/home/i-owe')
              : null,
        ),
        if (hasOwed && hasOwe)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SplitLink(
                  text: '${AppStrings.youAreOwed} ${_money(owed)}',
                  color: BalanceTone.owed.color(isDark),
                  onTap: () => open('/home/owed-to-me'),
                ),
                Text(
                  ' · ',
                  style: TextStyle(color: AppColors.textSecondary(isDark)),
                ),
                _SplitLink(
                  text: '${AppStrings.youOwe} ${_money(owe)}',
                  color: BalanceTone.owe.color(isDark),
                  onTap: () => open('/home/i-owe'),
                ),
              ],
            ),
          ),
        Divider(height: 1, color: AppColors.divider(isDark)),
      ],
    );
  }

  static String _money(double amount) => CurrencyFormatter.format(amount.abs());
}

class _SplitLink extends StatelessWidget {
  const _SplitLink({
    required this.text,
    required this.color,
    required this.onTap,
  });

  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// All groups / Outstanding balances / Groups you owe / Groups that owe you.
class _GroupsFilterButton extends ConsumerWidget {
  const _GroupsFilterButton();

  static const _options = <(GroupsListFilter, String)>[
    (GroupsListFilter.all, AppStrings.groupsFilterAll),
    (GroupsListFilter.outstanding, AppStrings.groupsFilterOutstanding),
    (GroupsListFilter.youOwe, AppStrings.groupsFilterYouOwe),
    (GroupsListFilter.oweYou, AppStrings.groupsFilterOweYou),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.watch(groupsListFilterProvider);
    final active = current != GroupsListFilter.all;
    return PopupMenuButton<GroupsListFilter>(
      tooltip: AppStrings.filterGroups,
      initialValue: current,
      onSelected: ref.read(groupsListFilterProvider.notifier).set,
      icon: Icon(
        active ? Icons.filter_alt_rounded : Icons.tune_rounded,
        color: active ? AppColors.brand : AppColors.textSecondary(isDark),
      ),
      itemBuilder: (_) => [
        for (final (value, label) in _options)
          CheckedPopupMenuItem<GroupsListFilter>(
            value: value,
            checked: value == current,
            child: Text(label),
          ),
      ],
    );
  }
}
