import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../components/components.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Friends'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: EmptyStateWidget.noFriends(onAddFriend: () {}),
    );
  }
}
