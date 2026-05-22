import 'package:flutter/material.dart';
import '../core/services/haptic_service.dart';
import '../core/theme/app_colors.dart';

/// Custom bottom navigation bar
class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          border: Border(
            top: BorderSide(
              color: AppColors.divider(isDark),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (i) {
            // Only buzz when the tab actually changes — re-tapping the
            // current tab shouldn't fire a haptic.
            if (i != selectedIndex) HapticService.instance.selection();
            onItemSelected(i);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface(isDark),
          selectedItemColor: AppColors.tealDark,
          unselectedItemColor: AppColors.textSecondary(isDark),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_rounded),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
