import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/data/search/search_repository.dart';
import 'package:kharchasplit/modules/search/state/recent_searches_provider.dart';
import 'package:kharchasplit/modules/search/state/search_provider.dart';

void main() {
  group('recent searches', () {
    test('newest first, case-insensitive dedupe, trimmed', () {
      expect(pushRecentSearch(['tea', 'goa'], ' Goa '), ['Goa', 'tea']);
    });

    test('capped at 8', () {
      final list = [for (var i = 0; i < 8; i++) 'q$i'];
      final next = pushRecentSearch(list, 'new');
      expect(next.length, maxRecentSearches);
      expect(next.first, 'new');
      expect(next.contains('q7'), isFalse);
    });

    test('blank queries are ignored', () {
      expect(pushRecentSearch(['a'], '   '), ['a']);
    });
  });

  test('parses the /search payload', () {
    final r = SearchResults.fromJson({
      'expenses': [
        {
          'id': 'e1',
          'description': 'Tea',
          'amount': 300,
          'currency': 'INR',
          'category': null,
          'date': '2026-10-19',
          'groupId': 'g1',
          'groupName': 'Settle Flow Test',
          'isDirect': false,
        },
      ],
      'groups': [
        {
          'id': 'g1',
          'name': 'Settle Flow Test',
          'currency': 'INR',
          'isArchived': true,
        },
      ],
      'friends': [
        {'id': 'u1', 'name': 'Test Receiver', 'profileImageBase64': null},
      ],
    });
    expect(r.expenses.single.amount, 300);
    expect(r.expenses.single.date, DateTime(2026, 10, 19));
    expect(r.expenses.single.category, isNull);
    expect(r.groups.single.isArchived, isTrue);
    expect(r.friends.single.name, 'Test Receiver');
  });

  test('rows: groups, friends, expenses; empty sections skipped', () {
    const r = SearchResults(
      expenses: [
        SearchExpenseHit(
          id: 'e',
          description: 'd',
          amount: 1,
          currency: 'INR',
          category: null,
          date: null,
          groupId: null,
          groupName: null,
          isDirect: true,
        ),
      ],
      groups: [
        SearchGroupHit(id: 'g', name: 'G', currency: 'INR', isArchived: false),
      ],
    );
    final rows = buildSearchRows(r);
    expect(rows.map((r) => r.runtimeType), [
      SearchHeaderRow,
      SearchGroupRow,
      SearchHeaderRow,
      SearchExpenseRow,
    ]);
    expect((rows.first as SearchHeaderRow).section, SearchSection.groups);
    expect(buildSearchRows(const SearchResults()), isEmpty);
  });
}
