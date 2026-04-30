import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class OrganisationLandingPage extends StatelessWidget {
  const OrganisationLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 28, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Content Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2), // Positioned slightly higher

                  // Logo with soft glow
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.05),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),

                    padding: const EdgeInsets.all(8), // Restored original-style padding
                    child: Image.asset(
                      'assets/images/logo_main.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.business_rounded,
                        size: 100,
                        color: theme.primaryColor.withOpacity(0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Name (Serif style for premium look)
                  ValueListenableBuilder<String>(
                    valueListenable: AppTheme.appName,
                    builder: (context, name, _) {
                      return Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'serif',
                          color: textColor,
                          letterSpacing: 0.8,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Streamlining Construction Excellence',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: secondaryTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const Spacer(flex: 7),

                  // Login Button (Dynamic Primary Color)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/orgLogin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register Button (Surface-based)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/orgRegistrationForm'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surfaceVariant.withOpacity(
                          0.3,
                        ),
                        side: BorderSide(
                          color: colorScheme.outline,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: textColor,
                      ),
                      child: const Text(
                        'REGISTER ORGANIZATION',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Referral Link
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/joinByReferral'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 22,
                          color: textColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Join using referral code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),

                  // Version
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: secondaryTextColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
