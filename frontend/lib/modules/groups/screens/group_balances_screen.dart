import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/group_balances_tab.dart';
import '../widgets/group_subpage_scaffold.dart';

/// Everyone's balance in the group (Balances chip on group detail):
/// pending payments first, then one expandable row per member with
/// Remind… / Settle up on the lines that involve you.
class GroupBalancesScreen extends StatelessWidget {
  const GroupBalancesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return GroupSubpageScaffold(
      groupId: groupId,
      title: AppStrings.balances,
      builder: (context, detail, _) => GroupBalancesBody(detail: detail),
    );
  }
}
