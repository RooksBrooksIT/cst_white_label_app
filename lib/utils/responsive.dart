import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  // Scale horizontally based on screen width
  // If value <= 1.0, treat as percentage of screen width
  // Otherwise, scale relative to 375 design width
  static double scaleH(BuildContext context, double value) {
    if (value <= 1.0) {
      return MediaQuery.of(context).size.width * value;
    }
    return (MediaQuery.of(context).size.width / 375) * value;
  }

  // Scale vertically based on screen height
  // If value <= 1.0, treat as percentage of screen height
  // Otherwise, scale relative to 812 design height
  static double scaleV(BuildContext context, double value) {
    if (value <= 1.0) {
      return MediaQuery.of(context).size.height * value;
    }
    return (MediaQuery.of(context).size.height / 812) * value;
  }

  // Font size responsive method
  static double fontSize(BuildContext context, double baseSize) {
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.15;
    return baseSize * 1.3;
  }
}

