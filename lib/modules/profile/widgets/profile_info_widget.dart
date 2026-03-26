import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileInfoWidget extends StatefulWidget {
  final String name;
  final String email;
  final String? phone;
  final VoidCallback onEditName;
  final VoidCallback onEditEmail;
  final VoidCallback onEditPhone;

  const ProfileInfoWidget({
    super.key,
    required this.name,
    required this.email,
    this.phone,
    required this.onEditName,
    required this.onEditEmail,
    required this.onEditPhone,
  });

  @override
  State<ProfileInfoWidget> createState() => _ProfileInfoWidgetState();
}

class _ProfileInfoWidgetState extends State<ProfileInfoWidget> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'User profile information',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(isDark)),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              isDark,
              icon: Icons.person_rounded,
              label: 'Full Name',
              value: widget.name,
              onEdit: widget.onEditName,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              isDark,
              icon: Icons.email_rounded,
              label: 'Email',
              value: widget.email,
              onEdit: widget.onEditEmail,
            ),
            if (widget.phone != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                isDark,
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: widget.phone!,
                onEdit: widget.onEditPhone,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption(isDark).copyWith(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.body2(isDark),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onEdit,
          child: Semantics(
            button: true,
            label: 'Edit $label',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
