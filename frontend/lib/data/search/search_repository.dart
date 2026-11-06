import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class SearchApiException implements Exception {
  SearchApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Shortest query the server searches for; shorter ones return nothing.
const searchMinQueryLength = 2;

/// Longest query the server accepts.
const searchMaxQueryLength = 100;

class SearchExpenseHit {
  const SearchExpenseHit({
    required this.id,
    required this.description,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    required this.groupId,
    required this.groupName,
    required this.isDirect,
  });

  final String id;
  final String description;
  final double amount;

  /// ISO code, e.g. `INR`.
  final String currency;

  /// Category id; null for expenses without one.
  final String? category;

  /// Calendar date (`YYYY-MM-DD`, local midnight), null if unparsable.
  final DateTime? date;
  final String? groupId;
  final String? groupName;

  /// A non-group expense with one friend (hidden "direct" group).
  final bool isDirect;

  factory SearchExpenseHit.fromJson(Map<String, dynamic> j) => SearchExpenseHit(
    id: j['id'].toString(),
    description: (j['description'] as String?) ?? '',
    amount: (j['amount'] is num)
        ? (j['amount'] as num).toDouble()
        : double.tryParse(j['amount']?.toString() ?? '') ?? 0,
    currency: (j['currency'] as String?) ?? 'INR',
    category: j['category'] as String?,
    date: DateTime.tryParse(j['date']?.toString() ?? ''),
    groupId: j['groupId'] as String?,
    groupName: j['groupName'] as String?,
    isDirect: j['isDirect'] == true,
  );
}

class SearchGroupHit {
  const SearchGroupHit({
    required this.id,
    required this.name,
    required this.currency,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String currency;
  final bool isArchived;

  factory SearchGroupHit.fromJson(Map<String, dynamic> j) => SearchGroupHit(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    currency: (j['currency'] as String?) ?? 'INR',
    isArchived: j['isArchived'] == true,
  );
}

class SearchFriendHit {
  const SearchFriendHit({
    required this.id,
    required this.name,
    this.avatarBase64,
  });

  final String id;
  final String name;
  final String? avatarBase64;

  factory SearchFriendHit.fromJson(Map<String, dynamic> j) => SearchFriendHit(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    avatarBase64: j['profileImageBase64'] as String?,
  );
}

class SearchResults {
  const SearchResults({
    this.expenses = const [],
    this.groups = const [],
    this.friends = const [],
  });

  final List<SearchExpenseHit> expenses;
  final List<SearchGroupHit> groups;
  final List<SearchFriendHit> friends;

  bool get isEmpty => expenses.isEmpty && groups.isEmpty && friends.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((j[key] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(parse)
            .toList();
    return SearchResults(
      expenses: list('expenses', SearchExpenseHit.fromJson),
      groups: list('groups', SearchGroupHit.fromJson),
      friends: list('friends', SearchFriendHit.fromJson),
    );
  }
}

/// GET /search — up to 20 expenses, groups and friends whose description /
/// notes / name contain the query (case-insensitive). Never cached for
/// offline use (see CachePolicy).
class SearchRepository {
  SearchRepository(this._client);
  final ApiClient _client;

  Future<SearchResults> search(String query) async {
    final q = query.trim();
    if (q.length < searchMinQueryLength) return const SearchResults();
    final res = await _client.dio.get(
      '/search',
      queryParameters: {
        'q': q.length > searchMaxQueryLength
            ? q.substring(0, searchMaxQueryLength)
            : q,
      },
    );
    final body = res.data;
    if (body is! Map || body['success'] != true) {
      final msg =
          (body is Map ? body['error'] : null)?.toString() ??
          'Search failed (status ${res.statusCode})';
      throw SearchApiException(msg, statusCode: res.statusCode);
    }
    final data = body['data'];
    return data is Map<String, dynamic>
        ? SearchResults.fromJson(data)
        : const SearchResults();
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);
