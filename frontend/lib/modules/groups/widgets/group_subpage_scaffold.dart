import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/groups/groups_repository.dart';
import '../../auth/state/auth_provider.dart';
import '../state/group_detail_provider.dart';
import '../state/group_display.dart';
import 'group_detail_layouts.dart';

/// Shell for the group's own pages (Balances, Totals, Group settings):
/// title with the group name under it, loading / error states for the
/// group, pull-to-refresh, and a content column that widens with the
/// screen — full width under 600px, 720px up to 1100px, 860px beyond.
class GroupSubpageScaffold extends ConsumerWidget {
  const GroupSubpageScaffold({
    super.key,
    required this.groupId,
    required this.title,
    required this.builder,
  });

  final String groupId;
  final String title;

  /// Builds the page's scrollable body; [padding] is the side gutter for
  /// the current width.
  final Widget Function(BuildContext context, GroupDetail detail, double pad)
  builder;

  void _back(BuildContext context) => context.canPop()
      ? context.pop()
      : context.go('/home/groups/$groupId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final (double pad, double maxWidth) = width < 600
        ? (0, double.infinity)
        : width < 1100
        ? (8, 720)
        : (16, 860);
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final detail = detailAsync.value;
    final myId = ref.watch(myIdProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.background(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
        leading: GlassIconButton.isGlass
            ? GlassBackButton(onPressed: () => _back(context))
            : BackButton(onPressed: () => _back(context)),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if (detail != null)
              Text(
                detail.group.displayTitle(myId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(isDark),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: detail == null
            ? detailAsync.hasError
                  ? ErrorStateWidget(
                      title: 'Failed to load group details',
                      message: detailAsync.error is GroupsApiException
                          ? (detailAsync.error as GroupsApiException).message
                          : detailAsync.error.toString(),
                      onRetry: () =>
                          ref.invalidate(groupDetailProvider(groupId)),
                    )
                  : const ShimmerList(itemCount: 6)
            : RefreshIndicator(
                onRefresh: () => refreshGroupDetail(groupId, ref),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: builder(context, detail, pad),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Grey section title in a flat list ("Group members", "Advanced
/// settings"). Same look as the month headers on group detail.
class GroupSectionTitle extends StatelessWidget {
  const GroupSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
