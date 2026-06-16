import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/expense_model.dart';
import '../../../models/settlement_model.dart';
import 'group_detail_provider.dart';

/// Unified feed item shown in the group's "Activity" tab. A feed is a
/// flat list of [ExpenseFeedItem] and [SettlementFeedItem] sorted by
/// [createdAt] descending — the row UI dispatches off the runtime type
/// (sealed) to render the expense card vs. the settlement card.
sealed class GroupFeedItem {
  String get id;
  DateTime get createdAt;
  String get actorName;
}

class ExpenseFeedItem extends GroupFeedItem {
  ExpenseFeedItem(this.expense);
  final ExpenseModel expense;
  @override
  String get id => 'expense:${expense.id}';
  @override
  DateTime get createdAt => expense.createdAt;
  @override
  String get actorName => expense.paidBy.name;
}

class SettlementFeedItem extends GroupFeedItem {
  SettlementFeedItem(this.settlement);
  final SettlementModel settlement;
  @override
  String get id => 'settlement:${settlement.id}';
  @override
  DateTime get createdAt => settlement.createdAt;
  @override
  String get actorName => settlement.fromUser.name;
}

/// Filter-chip selection at the top of the Activity tab.
enum FeedFilter { all, expenses, settlements }

/// Persisted across rebuilds of the tab so the user's filter / query
/// survives expanding / scrolling. Not family-keyed: switching groups
/// resets to defaults via dispose-on-leave handled by the consuming widget.
final groupFeedFilterProvider = StateProvider<FeedFilter>(
  (ref) => FeedFilter.all,
);
final groupFeedSearchProvider = StateProvider<String>((ref) => '');

/// Builds the merged, sorted, filtered feed for a group. Reads the
/// already-fetched data from [groupDetailProvider] so we don't refire
/// the same expense / settlement list calls.
///
/// AsyncValue is forwarded so the UI can render loading + error states
/// uniformly with the rest of the screen.
final groupFeedProvider =
    Provider.family<AsyncValue<List<GroupFeedItem>>, String>((ref, groupId) {
  final detailAsync = ref.watch(groupDetailProvider(groupId));
  final filter = ref.watch(groupFeedFilterProvider);
  final query = ref.watch(groupFeedSearchProvider).trim().toLowerCase();

  return detailAsync.whenData((detail) {
    final items = <GroupFeedItem>[];
    if (filter == FeedFilter.all || filter == FeedFilter.expenses) {
      items.addAll(detail.expenses.map(ExpenseFeedItem.new));
    }
    if (filter == FeedFilter.all || filter == FeedFilter.settlements) {
      items.addAll(detail.settlements.map(SettlementFeedItem.new));
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (query.isEmpty) return items;
    return items.where((item) => _matchesQuery(item, query)).toList();
  });
});

bool _matchesQuery(GroupFeedItem item, String query) {
  switch (item) {
    case ExpenseFeedItem(:final expense):
      if (expense.title.toLowerCase().contains(query)) return true;
      if (expense.paidBy.name.toLowerCase().contains(query)) return true;
      if (expense.category.name.toLowerCase().contains(query)) return true;
      // Amount match — let the user type "500" to find ₹500 expenses.
      if (expense.amount.toStringAsFixed(0).contains(query)) return true;
      return false;
    case SettlementFeedItem(:final settlement):
      if (settlement.fromUser.name.toLowerCase().contains(query)) return true;
      if (settlement.toUser.name.toLowerCase().contains(query)) return true;
      if (settlement.amount.toStringAsFixed(0).contains(query)) return true;
      return false;
  }
}
