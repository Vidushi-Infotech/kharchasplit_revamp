import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/search/search_repository.dart';

/// Wait after the last keystroke before asking the server.
const searchDebounce = Duration(milliseconds: 350);

class SearchState {
  const SearchState({this.query = '', this.results, this.lastResults});

  /// Trimmed query the [results] are for (or being fetched for).
  final String query;

  /// Null while idle (query shorter than [searchMinQueryLength]).
  final AsyncValue<SearchResults>? results;

  /// The previous successful results, kept on screen (dimmed) while the
  /// next query loads so the list doesn't flash to a skeleton per word.
  final SearchResults? lastResults;

  bool get isIdle => results == null;
}

/// Debounced global search. Out-of-order responses are dropped: only the
/// latest request may write the state.
class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;
  int _seq = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < searchMinQueryLength) {
      _seq++; // a response still in flight is now stale
      state = SearchState(query: q);
      return;
    }
    if (q == state.query && state.results is AsyncData) return;
    _debounce = Timer(searchDebounce, () => _run(q));
  }

  /// Keyboard "search" / tapping a recent search: no debounce.
  void submit(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length >= searchMinQueryLength) _run(q);
  }

  void retry() => submit(state.query);

  Future<void> _run(String q) async {
    final seq = ++_seq;
    final previous = state.results?.value ?? state.lastResults;
    state = SearchState(
      query: q,
      results: const AsyncLoading<SearchResults>(),
      lastResults: previous,
    );
    try {
      final results = await ref.read(searchRepositoryProvider).search(q);
      if (!ref.mounted || seq != _seq) return;
      state = SearchState(query: q, results: AsyncData(results));
    } catch (e, st) {
      if (!ref.mounted || seq != _seq) return;
      state = SearchState(query: q, results: AsyncError(e, st));
    }
  }
}

/// Released when the search screen closes, so it reopens empty.
final searchProvider =
    NotifierProvider.autoDispose<SearchNotifier, SearchState>(
      SearchNotifier.new,
    );

/// One row of the flattened results list (headers + hits), so the screen
/// can render every section with a single lazy ListView.builder.
sealed class SearchRow {
  const SearchRow();
}

enum SearchSection { groups, friends, expenses }

class SearchHeaderRow extends SearchRow {
  const SearchHeaderRow(this.section, this.count);
  final SearchSection section;
  final int count;
}

class SearchGroupRow extends SearchRow {
  const SearchGroupRow(this.hit);
  final SearchGroupHit hit;
}

class SearchFriendRow extends SearchRow {
  const SearchFriendRow(this.hit);
  final SearchFriendHit hit;
}

class SearchExpenseRow extends SearchRow {
  const SearchExpenseRow(this.hit);
  final SearchExpenseHit hit;
}

/// Groups and friends first (few, and usually what a name search is
/// after), then expenses. Empty sections are left out.
List<SearchRow> buildSearchRows(SearchResults r) => [
  if (r.groups.isNotEmpty) ...[
    SearchHeaderRow(SearchSection.groups, r.groups.length),
    for (final g in r.groups) SearchGroupRow(g),
  ],
  if (r.friends.isNotEmpty) ...[
    SearchHeaderRow(SearchSection.friends, r.friends.length),
    for (final f in r.friends) SearchFriendRow(f),
  ],
  if (r.expenses.isNotEmpty) ...[
    SearchHeaderRow(SearchSection.expenses, r.expenses.length),
    for (final e in r.expenses) SearchExpenseRow(e),
  ],
];
