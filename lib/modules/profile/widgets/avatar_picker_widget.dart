import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/avatar_generator_service.dart';

class AvatarPickerWidget extends StatefulWidget {
  final String userName;
  final VoidCallback onGenerateAvatar;
  final VoidCallback onPickImage;
  final VoidCallback onClose;

  const AvatarPickerWidget({
    super.key,
    required this.userName,
    required this.onGenerateAvatar,
    required this.onPickImage,
    required this.onClose,
  });

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  int _selectedStyleIndex = 0;
  late List<AvatarStyle_Data> _avatarStyles;

  @override
  void initState() {
    super.initState();
    _avatarStyles = AvatarGeneratorService.getAvatarStyles();
  }

  String get _initials => widget.userName
      .split(' ')
      .take(2)
      .map((e) => e[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Your Avatar',
                  style: AppTextStyles.headline2(isDark).copyWith(fontSize: 20),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(Icons.close_rounded, color: AppColors.textSecondary(isDark)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Two Options
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    isDark,
                    icon: Icons.stars_rounded,
                    title: 'AI Avatar',
                    description: 'Generate stylish avatar',
                    isSelected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    isDark,
                    icon: Icons.image_rounded,
                    title: 'Upload Photo',
                    description: 'Use your own image',
                    isSelected: false,
                    onTap: widget.onPickImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Avatar Style Preview
            Text(
              'Avatar Styles',
              style: AppTextStyles.body1(isDark).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // Style Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _avatarStyles.length,
              itemBuilder: (context, index) {
                final style = _avatarStyles[index];
                final isSelected = _selectedStyleIndex == index;
                final colors = AvatarGeneratorService.getGradientColors(
                  widget.userName,
                  style.style,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStyleIndex = index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : AppColors.divider(isDark),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: AvatarGeneratorService.generateAvatarPreview(
                            initials: _initials,
                            style: style.style,
                            colors: colors,
                            size: 70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          style.name,
                          style: AppTextStyles.caption(isDark).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Action Button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: widget.onGenerateAvatar,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Use Selected Avatar',
                      style: AppTextStyles.body1(isDark).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildOptionCard(
    bool isDark, {
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.divider(isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: isSelected ? AppColors.brand : AppColors.textSecondary(isDark)),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.body2(isDark).copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.brand : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.caption(isDark).copyWith(
                fontSize: 11,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
