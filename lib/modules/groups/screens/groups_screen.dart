import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../state/groups_provider.dart';

/// Groups list screen
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final groupsData = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Groups'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: screenWidth < 600
          ? _buildCompactLayout(isDark, groupsData)
          : _buildWideLayout(isDark, groupsData),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.brand,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildCompactLayout(bool isDark, GroupsData data) {
    if (data.groups.isEmpty) {
      return EmptyStateWidget.noGroups(onCreateGroup: () {});
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = data.groups[index];
        return GroupCard(
          group: group,
          onTap: () => GoRouter.of(context).go('/home/groups/${group.id}'),
        );
      },
    );
  }

  Widget _buildWideLayout(bool isDark, GroupsData data) {
    if (data.groups.isEmpty) {
      return EmptyStateWidget.noGroups(onCreateGroup: () {});
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: data.groups.length,
            itemBuilder: (context, index) {
              final group = data.groups[index];
              return GroupCard(
                group: group,
                onTap: () =>
                    GoRouter.of(context).go('/home/groups/${group.id}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
