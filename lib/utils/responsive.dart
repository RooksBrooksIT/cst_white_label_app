import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  static bool isSmallMobile(BuildContext context) => width(context) < 360;
  static bool isMobile(BuildContext context) => width(context) < 600;
  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1200;
  static bool isDesktop(BuildContext context) => width(context) >= 1200;

  // Scale horizontally based on screen width relative to design width (375)
  static double scaleH(BuildContext context, double value) {
    return (width(context) / 375) * value;
  }

  // Scale vertically based on screen height relative to design height (812)
  static double scaleV(BuildContext context, double value) {
    return (height(context) / 812) * value;
  }

  // Font size responsive method
  static double fontSize(BuildContext context, double baseSize) {
    if (isSmallMobile(context)) return baseSize * 0.9;
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.15;
    return baseSize * 1.3;
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

