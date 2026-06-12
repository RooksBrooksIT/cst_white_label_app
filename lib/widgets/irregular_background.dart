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
    return Stack(
      children: [
        // Top-right blob
        Positioned(
          top: -120,
          right: -100,
          child: CustomPaint(
            size: const Size(400, 400),
            painter: _BlobPainter(color.withOpacity(0.08)),
          ),
        ),
        // Bottom-left blob
        Positioned(
          bottom: -100,
          left: -80,
          child: CustomPaint(
            size: const Size(300, 300),
            painter: _BlobPainter(color.withOpacity(0.06)),
          ),
        ),
        // Bottom-right blob (Added for full page coverage)
        Positioned(
          bottom: -50,
          right: -60,
          child: CustomPaint(
            size: const Size(200, 200),
            painter: _BlobPainter(color.withOpacity(0.04)),
          ),
        ),
        // Middle-right subtle blob
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          right: -80,
          child: CustomPaint(
            size: const Size(180, 180),
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
