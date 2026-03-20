import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: AppColors.surface(isDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.tealDark.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.person_rounded, size: 40),
                ),
                const SizedBox(height: 16),
                Text('You', style: AppTextStyles.headline2(isDark)),
                const SizedBox(height: 8),
                Text('user@example.com',
                    style: AppTextStyles.body2(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
