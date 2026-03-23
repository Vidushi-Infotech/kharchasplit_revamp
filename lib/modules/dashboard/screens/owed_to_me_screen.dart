import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../components/components.dart';
import '../state/balance_detail_provider.dart';

/// Screen showing all groups where user is owed money
class OwedToMeScreen extends ConsumerWidget {
  const OwedToMeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final groups = ref.watch(owedToMeGroupsProvider);
    final total = ref.watch(totalOwedToMeProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'Go back',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You Are Owed',
              style: AppTextStyles.headline3(isDark),
            ),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.greenLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColors.cardBg(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
      ),
      body: screenWidth < 600
          ? _buildCompactLayout(context, isDark, groups)
          : screenWidth < 1100
              ? _buildStandardLayout(context, isDark, groups)
              : _buildLargeLayout(context, isDark, groups),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    bool isDark,
    List<dynamic> groups,
  ) {
    return groups.isEmpty
        ? _buildEmptyState(isDark)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: groups
                  .map((group) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGroupRow(context, isDark, group),
                      ))
                  .toList(),
            ),
          );
  }

  Widget _buildStandardLayout(
    BuildContext context,
    bool isDark,
    List<dynamic> groups,
  ) {
    return groups.isEmpty
        ? _buildEmptyState(isDark)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: groups
                      .map((group) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGroupRow(context, isDark, group),
                          ))
                      .toList(),
                ),
              ),
            ),
          );
  }

  Widget _buildLargeLayout(
    BuildContext context,
    bool isDark,
    List<dynamic> groups,
  ) {
    return groups.isEmpty
        ? _buildEmptyState(isDark)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: groups
                      .map((group) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGroupRow(context, isDark, group),
                          ))
                      .toList(),
                ),
              ),
            ),
          );
  }

  Widget _buildGroupRow(BuildContext context, bool isDark, dynamic group) {
    return Semantics(
      button: true,
      label:
          'Group ${group.name} - you are owed ₹${group.myBalance.toStringAsFixed(2)}',
      child: GestureDetector(
        onTap: () {
          context.pushNamed(
            'group-detail',
            pathParameters: {'groupId': group.id},
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider(isDark),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      group.coverEmoji ?? '🏠',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: AppTextStyles.body1(isDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.categoryName} • ${group.memberCount} members',
                            style: AppTextStyles.caption(isDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+₹${group.myBalance.toStringAsFixed(2)}',
                    style: AppTextStyles.body1(isDark).copyWith(
                      color: AppColors.greenLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.textSecondary(isDark),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🎉',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'All Settled Up!',
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 8),
            Text(
              'No one owes you money right now.',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
