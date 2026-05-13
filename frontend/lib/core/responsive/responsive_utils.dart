import 'package:flutter/material.dart';

/// Responsive breakpoints following CLAUDE.md guidelines
class ResponsiveBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1100;
  static const double desktopMin = 1100;
}

/// Extension to easily check device type
extension ResponsiveContext on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < ResponsiveBreakpoints.mobileMax;

  bool get isTablet =>
      MediaQuery.of(this).size.width >= ResponsiveBreakpoints.mobileMax &&
      MediaQuery.of(this).size.width < ResponsiveBreakpoints.tabletMax;

  bool get isWeb => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.desktopMin;

  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;

  double get screenWidth => MediaQuery.of(this).size.width;

  double get screenHeight => MediaQuery.of(this).size.height;
}

/// Helper class for responsive sizing
class ResponsiveSize {
  static double width(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double height(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  static double responsiveFontSize(BuildContext context, double size) {
    double scaleFactor = 1.0;
    if (context.isMobile) {
      scaleFactor = 0.9;
    } else if (context.isTablet) {
      scaleFactor = 1.0;
    } else {
      scaleFactor = 1.1;
    }
    return size * scaleFactor;
  }
}
