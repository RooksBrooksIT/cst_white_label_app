import 'package:flutter/material.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebricks/services/auth_service.dart';
import 'package:ebricks/services/location_service.dart';
import 'package:ebricks/services/notification_service.dart';
import 'package:ebricks/utils/terms_helper.dart';
import 'package:ebricks/widgets/glass_scaffold.dart';
import 'package:ebricks/screens/common/portal_loading_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _nameOpacity;
  late Animation<double> _logoScale;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
    _checkLoginAndSync();
  }

  Future<void> _checkLoginAndSync() async {
    final auth = AuthService();
    if (auth.isLoggedIn) {
      final data = auth.userData;
      final orgId = data['dynamicPath'] ?? data['orgId'];

      if (orgId != null && orgId.toString().isNotEmpty) {
        // Refresh branding from Firestore if logged in
        await AppTheme.syncWithFirestore(orgId.toString());
      }
    } else {
      // Also check if there's a temp org path from referral joining
      final prefs = await SharedPreferences.getInstance();
      final tempOrgPath = prefs.getString('temp_org_path');
      if (tempOrgPath != null && tempOrgPath.isNotEmpty) {
        await AppTheme.syncWithFirestore(tempOrgPath);
      }
    }

    // After animation and sync, navigate
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      final accepted = await TermsHelper.hasAcceptedTerms();
      if (!mounted) return;
      if (!accepted) {
        TermsHelper.showTermsDialog(
          context,
          onAccepted: () {
            _navigateToNext();
          },
        );
      } else {
        _navigateToNext();
      }
    });
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    // 1. Request Notification permission on app open
    await NotificationService.requestNotificationPermission();

    // 2. Request Location permission on app open
    if (mounted) {
      await LocationService.handleLocationPermission(context);
    }

    if (!mounted) return;
    final auth = AuthService();
    if (auth.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PortalLoadingScreen(
            initialStatusMessage: 'Loading your dashboard…',
          ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/landing');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calculateResponsiveFontSize(String text, double availableWidth) {
    final cleanLength = text.trim().length;
    if (cleanLength > 30) {
      return (availableWidth * 0.055).clamp(18.0, 22.0);
    } else if (cleanLength > 20) {
      return (availableWidth * 0.065).clamp(20.0, 26.0);
    } else if (cleanLength > 12) {
      return (availableWidth * 0.075).clamp(24.0, 30.0);
    } else {
      return (availableWidth * 0.085).clamp(26.0, 34.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final availableWidth = constraints.maxWidth;
            final isCompact = availableHeight < 600;

            // Responsive dimensions
            final logoSize = (availableHeight * 0.22).clamp(100.0, 180.0);
            final logoInnerPadding = (logoSize * 0.11).clamp(12.0, 20.0);
            final bottomPadding = (availableHeight * 0.06).clamp(20.0, 56.0);
            final contentSpacing = (availableHeight * 0.012).clamp(8.0, 14.0);

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableHeight,
                      maxWidth: availableWidth,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top padding to balance vertical rhythm
                          SizedBox(height: isCompact ? 12 : availableHeight * 0.04),

                          // Centered Logo Section
                          Expanded(
                            child: Center(
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Opacity(
                                  opacity: _logoOpacity.value,
                                  child: Container(
                                    width: logoSize,
                                    height: logoSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFF1E88E5)
                                            .withValues(alpha: 0.3),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0B1942)
                                              .withValues(alpha: 0.18),
                                          blurRadius: 24,
                                          spreadRadius: 3,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    padding: EdgeInsets.all(logoInnerPadding),
                                    child: Image.asset(
                                      'assets/images/logo_main.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Image.asset(
                                        'assets/images/splash_screen_logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // App Name & Tagline at bottom
                          SlideTransition(
                            position: _textSlide,
                            child: Opacity(
                              opacity: _nameOpacity.value,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  8,
                                  24,
                                  bottomPadding,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ValueListenableBuilder<String>(
                                      valueListenable: AppTheme.appName,
                                      builder: (context, name, _) {
                                        final effectiveName = name.trim().isNotEmpty
                                            ? name.trim()
                                            : 'eBricks';
                                        final fontSize =
                                            _calculateResponsiveFontSize(
                                          effectiveName,
                                          availableWidth,
                                        );

                                        return Text(
                                          effectiveName,
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF0A183D),
                                            letterSpacing: 0.6,
                                            height: 1.15,
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(height: contentSpacing),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: availableWidth * 0.85,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B1942),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0B1942)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Build smarter. Manage better.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
