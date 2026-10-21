import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/state/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/contacts/contact_name_resolver.dart';
import '../../../data/recurring/recurring_repository.dart';
import '../../../models/models.dart';
import '../../auth/state/auth_provider.dart';
import '../../expenses/state/recurring_rule_provider.dart';
import '../../expenses/state/recurring_rule_text.dart';
import '../../expenses/widgets/recurring_manage_flow.dart';
import '../state/group_detail_provider.dart';
import '../widgets/recurring_rule_tile.dart';

/// The group's recurring expenses (group ⋮ → "Recurring expenses", and the
/// RECURRING_PAUSED push). Open to every member; tapping a rule opens the
/// manage sheet for its creator or a group admin while the flag is on.
class RecurringExpensesScreen extends ConsumerWidget {
  const RecurringExpensesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    // Compact / standard / large: padding and content width scale up.
    final (double pad, double maxWidth) = width < 600
        ? (16, double.infinity)
        : width < 1100
        ? (24, 720)
        : (32, 860);
    final rulesAsync = ref.watch(groupRecurringRulesProvider(groupId));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text(AppStrings.recurringExpenses),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/home/groups/$groupId'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: rulesAsync.when(
          loading: () => const ShimmerList(itemCount: 4),
          error: (e, _) => ErrorStateWidget(
            title: AppStrings.recurringListLoadFailed,
            message: e is RecurringApiException
                ? e.message
                : AppStrings.recurringActionFailed,
            onRetry: () => ref.invalidate(groupRecurringRulesProvider(groupId)),
          ),
          data: (rules) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupRecurringRulesProvider(groupId));
              await ref.read(groupRecurringRulesProvider(groupId).future);
            },
            child: rules.isEmpty
                ? const _Empty()
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: _RuleList(
                        groupId: groupId,
                        rules: rules,
                        padding: pad,
                        isDark: isDark,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RuleList extends ConsumerWidget {
  const _RuleList({
    required this.groupId,
    required this.rules,
    required this.padding,
    required this.isDark,
  });

  final String groupId;
  final List<RecurringRule> rules;
  final double padding;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId)).value;
    final myId = ref.watch(myIdProvider);
    final flagOn = watchFeature(ref, 'recurring');
    final contactNameByPhone = ref.watch(contactNameByPhoneProvider);
    final memberById = <String, UserModel>{
      for (final m in detail?.members ?? const <UserModel>[]) m.id: m,
    };

    String nameOf(String id) {
      if (id == myId) return 'You';
      final m = memberById[id];
      if (m == null) return AppStrings.formerMember;
      return resolveDisplayName(
        backendName: m.name,
        phone: m.phone,
        contactNameByPhone: contactNameByPhone,
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom room so the last row clears the home indicator.
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
      itemCount: rules.length,
      itemBuilder: (context, i) {
        final rule = rules[i];
        final canManage =
            flagOn &&
            canManageRecurringRule(
              rule: rule,
              myId: myId,
              group: detail?.group,
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RecurringRuleTile(
            rule: rule,
            isDark: isDark,
            payerNames: [for (final id in recurringPayerIds(rule)) nameOf(id)],
            onTap: canManage
                ? () => manageRecurringRule(context, ref, rule)
                : null,
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on the empty state.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const EmptyStateWidget(
            icon: '🔁',
            iconSize: 56,
            title: AppStrings.recurringNone,
            subtitle: AppStrings.recurringNoneHint,
          ),
        ),
      ),
    );
  }
}
