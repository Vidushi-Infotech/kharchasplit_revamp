import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileAvatarWidget extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onUpload;
  final VoidCallback onRegenerate;

  const ProfileAvatarWidget({
    super.key,
    required this.name,
    this.photoUrl,
    required this.onUpload,
    required this.onRegenerate,
  });

  @override
  State<ProfileAvatarWidget> createState() => _ProfileAvatarWidgetState();
}

class _ProfileAvatarWidgetState extends State<ProfileAvatarWidget>
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

  Color _getGradientColorForName(int index) {
    final colors = [
      const Color(0xFF6366f1),
      const Color(0xFF8b5cf6),
      const Color(0xFFec4899),
      const Color(0xFFf97316),
      const Color(0xFFeab308),
      const Color(0xFF10b981),
      const Color(0xFF06b6d4),
      const Color(0xFF3b82f6),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = widget.name
        .split(' ')
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    final colorIndex = widget.name.codeUnitAt(0);
    final gradientColor1 = _getGradientColorForName(colorIndex);
    final gradientColor2 = _getGradientColorForName(colorIndex + 1);

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
                // Avatar Circle with Gradient
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gradientColor1, gradientColor2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColor1.withValues(alpha: 0.3),
                        blurRadius: _isHovered ? 20 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.headline1(isDark).copyWith(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // Overlay on Hover
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: widget.onUpload,
                              child: Semantics(
                                button: true,
                                label: 'Upload profile photo',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: widget.onRegenerate,
                              child: Semantics(
                                button: true,
                                label: 'Regenerate avatar color',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  child: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
