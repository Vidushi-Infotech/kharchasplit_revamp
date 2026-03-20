import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard state model
class DashboardData {
  final double totalBalance;
  final int groupCount;
  final List<GroupInfo> groups;

  const DashboardData({
    required this.totalBalance,
    required this.groupCount,
    required this.groups,
  });

  DashboardData copyWith({
    double? totalBalance,
    int? groupCount,
    List<GroupInfo>? groups,
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      groupCount: groupCount ?? this.groupCount,
      groups: groups ?? this.groups,
    );
  }
}

/// Group info model
class GroupInfo {
  final String id;
  final String name;
  final double balance;
  final List<String> memberAvatars;
  final int memberCount;

  const GroupInfo({
    required this.id,
    required this.name,
    required this.balance,
    required this.memberAvatars,
    required this.memberCount,
  });
}

/// Mock dashboard provider
final dashboardProvider = StateProvider<DashboardData>((ref) {
  return const DashboardData(
    totalBalance: 1745.50,
    groupCount: 5,
    groups: [
      GroupInfo(
        id: '1',
        name: 'Office Hangouts',
        balance: 245.50,
        memberAvatars: ['A', 'B', 'C'],
        memberCount: 8,
      ),
      GroupInfo(
        id: '2',
        name: 'Trip to Goa',
        balance: -450.00,
        memberAvatars: ['D', 'E', 'F'],
        memberCount: 5,
      ),
      GroupInfo(
        id: '3',
        name: 'Hostel Expenses',
        balance: 125.75,
        memberAvatars: ['G', 'H'],
        memberCount: 3,
      ),
      GroupInfo(
        id: '4',
        name: 'Movie Night',
        balance: 89.25,
        memberAvatars: ['I', 'J', 'K', 'L'],
        memberCount: 6,
      ),
      GroupInfo(
        id: '5',
        name: 'Apartment Rent',
        balance: 1285.00,
        memberAvatars: ['M', 'N'],
        memberCount: 4,
      ),
    ],
  );
});

/// Selected navigation index
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);
