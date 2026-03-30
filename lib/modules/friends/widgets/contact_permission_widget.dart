import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ContactPermissionWidget extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final bool isLoading;

  const ContactPermissionWidget({
    super.key,
    required this.onRequestPermission,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 1100 ? 48 : (screenWidth > 600 ? 32 : 16),
          vertical: 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contacts_rounded,
                size: 48,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Access Your Contacts',
              style: AppTextStyles.headline2(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Allow access to your contacts to find and invite friends who are already using KharchaSplit.',
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Permission button
            Semantics(
              button: true,
              label: 'Request contact permission',
              onTap: isLoading ? null : onRequestPermission,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onRequestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    disabledBackgroundColor: AppColors.textSecondary(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.background(isDark),
                            ),
                          ),
                        )
                      : Text(
                          'Allow Access',
                          style: AppTextStyles.body2(isDark).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
