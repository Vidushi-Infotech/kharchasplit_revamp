import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/avatar_generator_service.dart';
import '../state/profile_provider.dart';
import 'avatar_picker_widget.dart';

class ProfileAvatarWidget extends ConsumerStatefulWidget {
  final String name;
  final VoidCallback? onPhotoSelected;

  const ProfileAvatarWidget({
    super.key,
    required this.name,
    this.onPhotoSelected,
  });

  @override
  ConsumerState<ProfileAvatarWidget> createState() => _ProfileAvatarWidgetState();
}

class _ProfileAvatarWidgetState extends ConsumerState<ProfileAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _isHovered = true);
    _animationController.forward();
  }

  void _onHoverExit() {
    setState(() => _isHovered = false);
    _animationController.reverse();
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(Theme.of(context).brightness == Brightness.dark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AvatarPickerWidget(
        userName: widget.name,
        onGenerateAvatar: () {
          Navigator.pop(context);
          widget.onPhotoSelected?.call();
        },
        onPickImage: () {
          Navigator.pop(context);
          // Image picker logic here
          widget.onPhotoSelected?.call();
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileState = ref.watch(profileProvider);

    final initials = widget.name
        .split(' ')
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    final colors = AvatarGeneratorService.getGradientColors(
      widget.name,
      profileState.selectedAvatarStyle ?? AvatarStyle.gradient,
    );

    return Semantics(
      label: 'User profile avatar for ${widget.name}',
      child: Center(
        child: MouseRegion(
          onEnter: (_) => _onHoverEnter(),
          onExit: (_) => _onHoverExit(),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.05).animate(
              CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
            ),
            child: Stack(
              children: [
                // Avatar Circle with Generated Avatar or Photo
                if (profileState.photoPath != null)
                  // Show uploaded photo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(profileState.photoPath!),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? 20 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  )
                else
                  // Show generated avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.3),
                          blurRadius: _isHovered ? 20 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AvatarGeneratorService.generateAvatarPreview(
                      initials: initials,
                      style: profileState.selectedAvatarStyle ?? AvatarStyle.gradient,
                      colors: colors,
                      size: 120,
                    ),
                  ),
                // Overlay on Hover
                if (_isHovered)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _showAvatarPicker,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Edit profile avatar',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Change Avatar',
                                style: AppTextStyles.caption(isDark).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Status Badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      border: Border.all(
                        color: AppColors.background(isDark),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
