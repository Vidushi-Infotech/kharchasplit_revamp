import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for selected navigation index
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for unread activity count (badge)
final unreadActivityCountProvider = StateProvider<int>((ref) => 3);
