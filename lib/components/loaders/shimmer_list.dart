import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

/// Shimmer loading skeleton for lists
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final ShimmerListType type;
  final double height;

  const ShimmerList({
    Key? key,
    this.itemCount = 5,
    this.type = ShimmerListType.expense,
    this.height = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        switch (type) {
          case ShimmerListType.expense:
            return _buildExpenseShimmer(isDark);
          case ShimmerListType.group:
            return _buildGroupShimmer(isDark);
          case ShimmerListType.friend:
            return _buildFriendShimmer(isDark);
          case ShimmerListType.activity:
            return _buildActivityShimmer(isDark);
        }
      },
    );
  }

  Widget _buildExpenseShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface(isDark).withValues(alpha: 0.8),
      highlightColor: AppColors.surface(isDark).withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Category icon placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 150,
                    color: AppColors.divider(isDark),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    color: AppColors.divider(isDark),
                  ),
                ],
              ),
            ),
            // Amount placeholder
            Container(
              height: 20,
              width: 80,
              color: AppColors.divider(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface(isDark).withValues(alpha: 0.8),
      highlightColor: AppColors.surface(isDark).withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Emoji placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            // Name and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 120,
                    color: AppColors.divider(isDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Balance placeholder
            Container(
              height: 20,
              width: 70,
              color: AppColors.divider(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface(isDark).withValues(alpha: 0.8),
      highlightColor: AppColors.surface(isDark).withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            // Name and balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 120,
                    color: AppColors.divider(isDark),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 80,
                    color: AppColors.divider(isDark),
                  ),
                ],
              ),
            ),
            // Button placeholder
            Container(
              height: 36,
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.divider(isDark),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface(isDark).withValues(alpha: 0.8),
      highlightColor: AppColors.surface(isDark).withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Text placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    color: AppColors.divider(isDark),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 100,
                    color: AppColors.divider(isDark),
                  ),
                ],
              ),
            ),
            // Time placeholder
            Container(
              height: 12,
              width: 50,
              color: AppColors.divider(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Types of shimmer loaders
enum ShimmerListType {
  expense,
  group,
  friend,
  activity,
}
