import 'package:flutter/material.dart';

class IrregularBackground extends StatelessWidget {
  final Color color;
  final Widget child;

  const IrregularBackground({
    super.key,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    double blobSize1 = isDesktop ? 600 : (isTablet ? 500 : 400);
    double blobSize2 = isDesktop ? 450 : (isTablet ? 375 : 300);
    double blobSize3 = isDesktop ? 300 : (isTablet ? 250 : 200);
    double blobSize4 = isDesktop ? 270 : (isTablet ? 225 : 180);

    return Stack(
      children: [
        // Top-right blob
        Positioned(
          top: -blobSize1 * 0.3,
          right: -blobSize1 * 0.25,
          child: CustomPaint(
            size: Size(blobSize1, blobSize1),
            painter: _BlobPainter(color.withOpacity(0.08)),
          ),
        ),
        // Bottom-left blob
        Positioned(
          bottom: -blobSize2 * 0.33,
          left: -blobSize2 * 0.27,
          child: CustomPaint(
            size: Size(blobSize2, blobSize2),
            painter: _BlobPainter(color.withOpacity(0.06)),
          ),
        ),
        // Bottom-right blob
        Positioned(
          bottom: -blobSize3 * 0.25,
          right: -blobSize3 * 0.3,
          child: CustomPaint(
            size: Size(blobSize3, blobSize3),
            painter: _BlobPainter(color.withOpacity(0.04)),
          ),
        ),
        // Middle-right subtle blob
        Positioned(
          top: screenHeight * 0.35,
          right: -blobSize4 * 0.44,
          child: CustomPaint(
            size: Size(blobSize4, blobSize4),
            painter: _BlobPainter(color.withOpacity(0.03)),
          ),
        ),
        // Ensure child is on top and fills the area
        Positioned.fill(child: child),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  _BlobPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    final path = Path();
    // Create an irregular organic shape
    path.moveTo(size.width * 0.3, 0);
    path.quadraticBezierTo(
        size.width * 0.85, size.height * 0.05, size.width, size.height * 0.4);
    path.quadraticBezierTo(
        size.width * 0.95, size.height * 0.85, size.width * 0.4, size.height);
    path.quadraticBezierTo(
        size.width * 0.05, size.height * 0.9, 0, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.05, size.height * 0.1, size.width * 0.3, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
