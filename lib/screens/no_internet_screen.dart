import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:demo_cst/utils/app_theme.dart';

class NoInternetScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _armAnimation;
  late Animation<double> _bucketRotation;
  late Animation<double> _dustOpacity;
  late Animation<double> _cloudOffset;
  late Animation<double> _wifiIconScale;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _armAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _bucketRotation = Tween<double>(
      begin: -0.2,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _dustOpacity = Tween<double>(
      begin: 0.1,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _cloudOffset = Tween<double>(
      begin: -100.0,
      end: 100.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _wifiIconScale = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, child) {
        final isDark = false;
        final bgColor = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtextColor = isDark
            ? Colors.grey[400]
            : const Color(0xFF64748B);

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated WiFi Icon
                      AnimatedBuilder(
                        animation: _wifiIconScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _wifiIconScale.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 80,
                                  color: primaryColor.withOpacity(0.2),
                                ),
                                Icon(
                                  Icons.wifi_off,
                                  size: 60,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // JCB Animation
                      SizedBox(
                        width: 320,
                        height: 280,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _armAnimation,
                            _bucketRotation,
                            _dustOpacity,
                            _cloudOffset,
                          ]),
                          builder: (context, child) {
                            return CustomPaint(
                              painter: ProfessionalJCBPainter(
                                primaryColor: primaryColor,
                                armProgress: _armAnimation.value,
                                bucketRotation: _bucketRotation.value,
                                dustOpacity: _dustOpacity.value,
                                cloudOffset: _cloudOffset.value,
                                random: _random,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Oops! No Internet',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Looks like your connection took a break.\nPlease check your Wi-Fi or mobile data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: subtextColor,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: FilledButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text(
                            'Retry Connection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: AppTheme.getForegroundFor(
                              primaryColor,
                            ),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProfessionalJCBPainter extends CustomPainter {
  final Color primaryColor;
  final double armProgress;
  final double bucketRotation;
  final double dustOpacity;
  final double cloudOffset;
  final math.Random random;

  ProfessionalJCBPainter({
    required this.primaryColor,
    required this.armProgress,
    required this.bucketRotation,
    required this.dustOpacity,
    required this.cloudOffset,
    required this.random,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.8;

    _drawBackground(canvas, size);
    _drawClouds(canvas, size, cloudOffset);
    _drawGround(canvas, size, groundY);
    _drawTracks(canvas, centerX, groundY);
    _drawBody(canvas, centerX, groundY, primaryColor);
    _drawCabin(canvas, centerX, groundY);
    _drawArm(
      canvas,
      centerX,
      groundY,
      primaryColor,
      armProgress,
      bucketRotation,
    );
    _drawBucket(
      canvas,
      centerX,
      groundY,
      primaryColor,
      armProgress,
      bucketRotation,
    );
    _drawSoilInBucket(
      canvas,
      centerX,
      groundY,
      primaryColor,
      armProgress,
      bucketRotation,
    );
    _drawSoilParticles(canvas, centerX, groundY, armProgress);
    _drawDust(canvas, centerX, groundY, armProgress, dustOpacity);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFE0F2FE), const Color(0xFFF8FAFC)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawClouds(Canvas canvas, Size size, double offset) {
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.7);

    // Cloud 1
    _drawCloud(canvas, Offset(offset + 50, 40), 40, cloudPaint);
    // Cloud 2
    _drawCloud(
      canvas,
      Offset(offset - 80, 70),
      30,
      cloudPaint..color = Colors.white.withOpacity(0.5),
    );
    // Cloud 3
    _drawCloud(
      canvas,
      Offset(offset + 120, 55),
      25,
      cloudPaint..color = Colors.white.withOpacity(0.6),
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center.translate(radius * 0.7, 0), radius * 0.8, paint);
    canvas.drawCircle(
      center.translate(-radius * 0.6, radius * 0.1),
      radius * 0.7,
      paint,
    );
  }

  void _drawGround(Canvas canvas, Size size, double groundY) {
    final groundPaint = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..style = PaintingStyle.fill;

    final groundPath = Path()
      ..moveTo(0, groundY - 10)
      ..quadraticBezierTo(
        size.width * 0.25,
        groundY + 5,
        size.width * 0.5,
        groundY - 5,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        groundY + 8,
        size.width,
        groundY - 3,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(groundPath, groundPaint);

    // Ground details
    final detailPaint = Paint()..color = const Color(0xFF6B4226);
    for (int i = 0; i < 15; i++) {
      final x = (i / 14) * size.width;
      final y = groundY + 10 + random.nextDouble() * 30;
      canvas.drawCircle(Offset(x, y), 2 + random.nextDouble() * 3, detailPaint);
    }
  }

  void _drawTracks(Canvas canvas, double centerX, double groundY) {
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    // Left track
    final leftTrack = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - 80, groundY - 35, 55, 35),
      const Radius.circular(10),
    );
    canvas.drawRRect(leftTrack, trackPaint);

    // Right track
    final rightTrack = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX + 25, groundY - 35, 55, 35),
      const Radius.circular(10),
    );
    canvas.drawRRect(rightTrack, trackPaint);

    // Track details
    final wheelPaint = Paint()..color = const Color(0xFF334155);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(centerX - 80 + 15 + i * 15, groundY - 17.5),
        6,
        wheelPaint,
      );
      canvas.drawCircle(
        Offset(centerX + 25 + 15 + i * 15, groundY - 17.5),
        6,
        wheelPaint,
      );
    }
  }

  void _drawBody(Canvas canvas, double centerX, double groundY, Color color) {
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - 70, groundY - 95, 140, 60),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Body highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 65, groundY - 90, 130, 20),
        const Radius.circular(8),
      ),
      highlightPaint,
    );
  }

  void _drawCabin(Canvas canvas, double centerX, double groundY) {
    final cabinPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - 30, groundY - 130, 60, 40),
      const Radius.circular(8),
    );
    canvas.drawRRect(cabinRect, cabinPaint);

    // Cabin windows
    final windowPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 22, groundY - 122, 20, 25),
        const Radius.circular(4),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 2, groundY - 122, 20, 25),
        const Radius.circular(4),
      ),
      windowPaint,
    );
  }

  void _drawArm(
    Canvas canvas,
    double centerX,
    double groundY,
    Color color,
    double progress,
    double bucketRot,
  ) {
    final armPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pivotX = centerX - 35;
    final pivotY = groundY - 100;
    final armAngle = -math.pi / 4 + (progress * math.pi / 2);
    final armLength = 120;
    final elbowX = pivotX + math.cos(armAngle) * (armLength * 0.6);
    final elbowY = pivotY + math.sin(armAngle) * (armLength * 0.6);
    final endX = elbowX + math.cos(armAngle - 0.3) * (armLength * 0.4);
    final endY = elbowY + math.sin(armAngle - 0.3) * (armLength * 0.4);

    // First segment
    canvas.drawLine(Offset(pivotX, pivotY), Offset(elbowX, elbowY), armPaint);

    // Second segment
    canvas.drawLine(Offset(elbowX, elbowY), Offset(endX, endY), armPaint);

    // Hydraulic cylinders
    final hydraulicPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX - 45, groundY - 85),
      Offset(elbowX - 10, elbowY - 10),
      hydraulicPaint,
    );
  }

  Offset _getBucketPosition(double centerX, double groundY, double progress) {
    final pivotX = centerX - 35;
    final pivotY = groundY - 100;
    final armAngle = -math.pi / 4 + (progress * math.pi / 2);
    final armLength = 120;
    final elbowX = pivotX + math.cos(armAngle) * (armLength * 0.6);
    final elbowY = pivotY + math.sin(armAngle) * (armLength * 0.6);
    final endX = elbowX + math.cos(armAngle - 0.3) * (armLength * 0.4);
    final endY = elbowY + math.sin(armAngle - 0.3) * (armLength * 0.4);
    return Offset(endX, endY);
  }

  double _getBucketAngle(
    double centerX,
    double groundY,
    double progress,
    double bucketRot,
  ) {
    final armAngle = -math.pi / 4 + (progress * math.pi / 2);
    return armAngle - 0.3 + bucketRot;
  }

  void _drawBucket(
    Canvas canvas,
    double centerX,
    double groundY,
    Color color,
    double progress,
    double bucketRot,
  ) {
    final bucketPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final bucketPos = _getBucketPosition(centerX, groundY, progress);
    final bucketAngle = _getBucketAngle(centerX, groundY, progress, bucketRot);

    // Bucket
    canvas.save();
    canvas.translate(bucketPos.dx, bucketPos.dy);
    canvas.rotate(bucketAngle);

    final bucketPath = Path()
      ..moveTo(-5, 0)
      ..lineTo(-25, 30)
      ..lineTo(20, 30)
      ..lineTo(10, 0)
      ..close();
    canvas.drawPath(bucketPath, bucketPaint);

    // Bucket teeth
    final teethPaint = Paint()..color = const Color(0xFF475569);
    for (int i = -2; i <= 2; i++) {
      canvas.drawRect(Rect.fromLTWH(i * 9 - 4, 25, 6, 8), teethPaint);
    }

    canvas.restore();
  }

  void _drawSoilInBucket(
    Canvas canvas,
    double centerX,
    double groundY,
    Color color,
    double progress,
    double bucketRot,
  ) {
    final bucketPos = _getBucketPosition(centerX, groundY, progress);
    final bucketAngle = _getBucketAngle(centerX, groundY, progress, bucketRot);

    // Soil in bucket
    canvas.save();
    canvas.translate(bucketPos.dx, bucketPos.dy);
    canvas.rotate(bucketAngle);

    final soilColors = [
      const Color(0xFF8B5A2B),
      const Color(0xFFA0522D),
      const Color(0xFFCD853F),
    ];

    for (int i = 0; i < 8; i++) {
      final paint = Paint()..color = soilColors[i % soilColors.length];
      final x = -15.0 + (i * 5.0);
      final y = 15.0 + (random.nextDouble() * 10);
      final radius = 3.0 + random.nextDouble() * 2;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    canvas.restore();
  }

  void _drawSoilParticles(
    Canvas canvas,
    double centerX,
    double groundY,
    double progress,
  ) {
    final bucketPos = _getBucketPosition(centerX, groundY, progress);

    final soilColors = [
      const Color(0xFF8B5A2B),
      const Color(0xFFA0522D),
      const Color(0xFFCD853F),
      const Color(0xFFD2691E),
    ];

    for (int i = 0; i < 15; i++) {
      final paint = Paint()..color = soilColors[i % soilColors.length];
      final offsetX = bucketPos.dx + (random.nextDouble() - 0.5) * 50;
      final offsetY = bucketPos.dy + (random.nextDouble() - 0.5) * 50 + 20;
      final radius = 1.5 + random.nextDouble() * 3;
      canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
    }
  }

  void _drawDust(
    Canvas canvas,
    double centerX,
    double groundY,
    double progress,
    double opacity,
  ) {
    final bucketPos = _getBucketPosition(centerX, groundY, progress);

    for (int i = 0; i < 8; i++) {
      final dustPaint = Paint()
        ..color = Colors.grey.withOpacity(
          opacity * (0.3 + random.nextDouble() * 0.4),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      final dx = (random.nextDouble() - 0.5) * 70;
      final dy = (random.nextDouble() - 0.5) * 70 + 30;
      final radius = 15 + random.nextDouble() * 25;
      canvas.drawCircle(
        Offset(bucketPos.dx + dx, bucketPos.dy + dy),
        radius,
        dustPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProfessionalJCBPainter oldDelegate) {
    return oldDelegate.armProgress != armProgress ||
        oldDelegate.bucketRotation != bucketRotation ||
        oldDelegate.dustOpacity != dustOpacity ||
        oldDelegate.cloudOffset != cloudOffset ||
        oldDelegate.primaryColor != primaryColor;
  }
}
