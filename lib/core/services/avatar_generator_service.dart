import 'package:flutter/material.dart';

enum AvatarStyle {
  gradient,
  pixel,
  geometric,
  minimal,
  colorful,
}

class AvatarStyle_Data {
  final AvatarStyle style;
  final String name;
  final String description;
  final IconData icon;

  AvatarStyle_Data({
    required this.style,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class AvatarGeneratorService {
  static final List<Color> colorPalette = [
    const Color(0xFF6366f1),
    const Color(0xFF8b5cf6),
    const Color(0xFFec4899),
    const Color(0xFFf97316),
    const Color(0xFFeab308),
    const Color(0xFF10b981),
    const Color(0xFF06b6d4),
    const Color(0xFF3b82f6),
    const Color(0xFFf43f5e),
    const Color(0xFF14b8a6),
  ];

  static List<AvatarStyle_Data> getAvatarStyles() {
    return [
      AvatarStyle_Data(
        style: AvatarStyle.gradient,
        name: 'Gradient',
        description: 'Smooth color gradients',
        icon: Icons.gradient,
      ),
      AvatarStyle_Data(
        style: AvatarStyle.pixel,
        name: 'Pixel Art',
        description: 'Retro pixel style',
        icon: Icons.layers,
      ),
      AvatarStyle_Data(
        style: AvatarStyle.geometric,
        name: 'Geometric',
        description: 'Abstract shapes',
        icon: Icons.category_rounded,
      ),
      AvatarStyle_Data(
        style: AvatarStyle.minimal,
        name: 'Minimal',
        description: 'Clean & simple',
        icon: Icons.rectangle_outlined,
      ),
      AvatarStyle_Data(
        style: AvatarStyle.colorful,
        name: 'Colorful',
        description: 'Multi-color blend',
        icon: Icons.palette,
      ),
    ];
  }

  static Color getRandomColor() {
    return colorPalette[(DateTime.now().microsecond) % colorPalette.length];
  }

  static List<Color> getGradientColors(String name, AvatarStyle style) {
    final hash = name.codeUnits.fold(0, (p, c) => p + c);
    final color1 = colorPalette[hash % colorPalette.length];
    final color2 = colorPalette[(hash + 1) % colorPalette.length];

    return [color1, color2];
  }

  static Widget generateAvatarPreview({
    required String initials,
    required AvatarStyle style,
    required List<Color> colors,
    double size = 120,
  }) {
    switch (style) {
      case AvatarStyle.gradient:
        return _buildGradientAvatar(initials, colors, size);
      case AvatarStyle.pixel:
        return _buildPixelAvatar(initials, colors, size);
      case AvatarStyle.geometric:
        return _buildGeometricAvatar(initials, colors, size);
      case AvatarStyle.minimal:
        return _buildMinimalAvatar(initials, colors, size);
      case AvatarStyle.colorful:
        return _buildColorfulAvatar(initials, colors, size);
    }
  }

  static Widget _buildGradientAvatar(
    String initials,
    List<Color> colors,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static Widget _buildPixelAvatar(
    String initials,
    List<Color> colors,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[0],
        border: Border.all(color: colors[1], width: 3),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  static Widget _buildGeometricAvatar(
    String initials,
    List<Color> colors,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: colors),
      ),
      child: Center(
        child: Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildMinimalAvatar(
    String initials,
    List<Color> colors,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[0].withValues(alpha: 0.8),
        border: Border.all(color: colors[1], width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colors[1],
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static Widget _buildColorfulAvatar(
    String initials,
    List<Color> colors,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors[0], colors[1]],
          stops: const [0.3, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
