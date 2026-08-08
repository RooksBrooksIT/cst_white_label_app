import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  static bool isSmallMobile(BuildContext context) => width(context) < 360;
  static bool isMobile(BuildContext context) => width(context) < 600;
  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1024;
  static bool isDesktop(BuildContext context) => width(context) >= 1024;

  /// Maximum content width used for centering on large screens.
  static const double maxContentWidth = 1100.0;

  /// Horizontal padding that scales with screen size.
  /// Mobile: 12 | Tablet: 20 | Desktop: 40
  static double horizontalPadding(BuildContext context) {
    if (isMobile(context)) return 12.0;
    if (isTablet(context)) return 20.0;
    return 40.0;
  }

  /// Responsive grid cross-axis count for dashboard grids.
  /// Mobile (<600): 3 | Tablet (600–1024): 4 | Desktop (>1024): 5
  static int gridCrossAxisCount(double availableWidth) {
    if (availableWidth < 600) return 3;
    if (availableWidth < 1024) return 4;
    return 5;
  }

  /// Responsive child aspect ratio for dashboard grid cards.
  static double gridChildAspectRatio(double availableWidth) {
    if (availableWidth < 600) return 0.95;
    if (availableWidth < 1024) return 1.0;
    return 1.1;
  }

  // Scale horizontally based on screen width relative to design width (375)
  // Capped at 1.2x on tablet/desktop to prevent oversized elements on web
  static double scaleH(BuildContext context, double value) {
    final scale = width(context) / 375;
    final cappedScale = scale > 1.2 ? 1.2 : scale;
    return cappedScale * value;
  }

  // Scale vertically based on screen height relative to design height (812)
  // Capped at 1.2x on tablet/desktop to prevent oversized elements on web
  static double scaleV(BuildContext context, double value) {
    final scale = height(context) / 812;
    final cappedScale = scale > 1.2 ? 1.2 : scale;
    return cappedScale * value;
  }

  // Font size responsive method
  static double fontSize(BuildContext context, double baseSize) {
    if (isSmallMobile(context)) return baseSize * 0.9;
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.1;
    return baseSize * 1.2;
  }

  // Safe area padding
  static double topPadding(BuildContext context) => MediaQuery.of(context).padding.top;
  static double bottomPadding(BuildContext context) => MediaQuery.of(context).padding.bottom;

  // Responsive padding/margin
  static double spacing(BuildContext context, double baseSpacing) {
    if (isSmallMobile(context)) return baseSpacing * 0.8;
    if (isMobile(context)) return baseSpacing;
    return baseSpacing * 1.2;
  }
}

