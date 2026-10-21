import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/components.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/state/connectivity_provider.dart';
import '../../../data/search/search_repository.dart';
import '../state/search_provider.dart';
import 'search_recent_list.dart';
import 'search_result_tiles.dart';

/// Everything under the search field: offline notice, recent searches,
/// "type more", loading, error, no results, or the results.
class SearchBody extends ConsumerWidget {
  const SearchBody({
    super.key,
    required this.isDark,
    required this.padding,
    required this.onPickRecent,
    required this.onOpen,
  });

  final bool isDark;
  final EdgeInsets padding;
  final ValueChanged<String> onPickRecent;

  /// Opens a tapped result's route (the screen also remembers the query).
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOfflineProvider)) {
      return SearchHintMessage(
        icon: Icons.wifi_off_rounded,
        message: AppStrings.searchNeedsInternet,
        isDark: isDark,
      );
    }
    final state = ref.watch(searchProvider);
    final results = state.results;
    if (results == null) {
      return state.query.isEmpty
          ? SearchRecentList(
              isDark: isDark,
              padding: padding,
              onPick: onPickRecent,
            )
          : SearchHintMessage(
              icon: Icons.keyboard_rounded,
              message: AppStrings.searchTypeMore,
              isDark: isDark,
            );
    }
    return results.when(
      loading: () => state.lastResults == null
          ? Padding(
              padding: padding,
              child: const ShimmerList(
                type: ShimmerListType.expense,
                itemCount: 6,
              ),
            )
          : Column(
              children: [
                const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Opacity(
                    opacity: 0.6,
                    child: _resultsList(state.lastResults!),
                  ),
                ),
              ],
            ),
      error: (e, _) => ErrorStateWidget(
        title: AppStrings.searchFailed,
        message: e is SearchApiException ? e.message : AppStrings.searchFailed,
        onRetry: () => ref.read(searchProvider.notifier).retry(),
      ),
      data: (r) => r.isEmpty
          ? EmptyStateWidget(
              icon: '🔍',
              iconSize: 56,
              title: AppStrings.searchNoResults(state.query),
              subtitle: AppStrings.searchNoResultsHint,
            )
          : _resultsList(r),
    );
  }

  Widget _resultsList(SearchResults r) {
    final rows = buildSearchRows(r);
    return ListView.builder(
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        SearchHeaderRow row => SearchSectionHeader(row: row, isDark: isDark),
        SearchGroupRow(:final hit) => SearchGroupTile(
          hit: hit,
          isDark: isDark,
          onTap: () => onOpen('/home/groups/${hit.id}'),
        ),
        SearchFriendRow(:final hit) => SearchFriendTile(
          hit: hit,
          isDark: isDark,
          onTap: () => onOpen('/home/friends/${hit.id}'),
        ),
        SearchExpenseRow(:final hit) => SearchExpenseTile(
          hit: hit,
          isDark: isDark,
          onTap: () => onOpen('/expense/${hit.id}'),
        ),
      },
    );
  }
}
