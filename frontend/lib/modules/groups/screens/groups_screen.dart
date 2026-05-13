import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/group_model.dart';
import '../state/groups_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Groups'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(groupsProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.read(groupsProvider.notifier).refresh(),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return EmptyStateWidget.noGroups(
              onCreateGroup: () => context.push('/home/create-group'),
            );
          }
          if (screenWidth < 600) return _CompactList(groups: groups);
          if (screenWidth < 1100) return _Grid(groups: groups, columns: 2);
          return _Grid(groups: groups, columns: 3, maxWidth: 1200);
        },
      ),
    );
  }
}

class _CompactList extends StatelessWidget {
  const _CompactList({required this.groups});
  final List<GroupModel> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        return Semantics(
          button: true,
          label: 'Group - ${group.name}',
          child: GroupCard(
            group: group,
            onTap: () => context.push('/home/groups/${group.id}'),
          ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.groups,
    required this.columns,
    this.maxWidth = 800,
  });

  final List<GroupModel> groups;
  final int columns;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(columns >= 3 ? 32 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: columns >= 3 ? 24 : 16,
              mainAxisSpacing: columns >= 3 ? 24 : 16,
              childAspectRatio: 1.2,
            ),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Semantics(
                button: true,
                label: 'Group - ${group.name}',
                child: GroupCard(
                  group: group,
                  onTap: () => context.push('/home/groups/${group.id}'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.errorText(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load groups",
              style: AppTextStyles.headline3(isDark),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.body2(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
