import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  // Scale horizontally
  static double scaleH(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  // Scale vertically
  static double scaleV(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  // Font size responsive method
  static double fontSize(BuildContext context, double baseSize) {
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.2;
    return baseSize * 1.5;
  }
}
