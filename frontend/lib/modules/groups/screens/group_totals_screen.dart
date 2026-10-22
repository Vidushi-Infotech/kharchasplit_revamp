import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../widgets/group_subpage_scaffold.dart';
import '../widgets/group_totals_tab.dart';

/// Spending totals for the group in a period (Totals chip on group
/// detail): group spending, what you paid and owe, payments, and the
/// breakdowns by category, month and member.
class GroupTotalsScreen extends StatelessWidget {
  const GroupTotalsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return GroupSubpageScaffold(
      groupId: groupId,
      title: AppStrings.totals,
      builder: (context, detail, _) =>
          GroupTotalsBody(groupId: groupId, currency: detail.group.currency),
    );
  }
}
