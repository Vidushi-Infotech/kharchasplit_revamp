import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/recent_searches_provider.dart';

/// Recent searches (tap to search again, × to forget one, Clear for all),
/// or a short hint when there are none yet.
class SearchRecentList extends ConsumerWidget {
  const SearchRecentList({
    super.key,
    required this.isDark,
    required this.padding,
    required this.onPick,
  });

  final bool isDark;
  final EdgeInsets padding;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) {
      return SearchHintMessage(
        icon: Icons.search_rounded,
        message: AppStrings.searchStartHint,
        isDark: isDark,
      );
    }
    return ListView.builder(
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: recent.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    AppStrings.searchRecent.toUpperCase(),
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).clear(),
                child: const Text(AppStrings.searchClearRecent),
              ),
            ],
          );
        }
        final q = recent[index - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
            Icons.history_rounded,
            color: AppColors.textSecondary(isDark),
          ),
          title: Text(
            q,
            style: AppTextStyles.body1(isDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onPick(q),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textSecondary(isDark),
            tooltip: AppStrings.searchRemoveRecent(q),
            onPressed: () =>
                ref.read(recentSearchesProvider.notifier).remove(q),
          ),
        );
      },
    );
  }
}

/// Centred icon + one line: start hint, "type more", offline.
class SearchHintMessage extends StatelessWidget {
  const SearchHintMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.isDark,
  });

  final IconData icon;
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          liveRegion: true,
          label: message,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textSecondary(isDark)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body1(
                  isDark,
                ).copyWith(color: AppColors.textSecondary(isDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
