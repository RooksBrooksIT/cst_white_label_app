import 'package:flutter/material.dart';

class OrganisationLandingPage extends StatelessWidget {
  const OrganisationLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF0F172A);
    const secondaryTextColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Content Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo with soft glow
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo_main.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business_rounded,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // App Name (Serif style for premium look)
                  const Text(
                    'CONSTRUCT PRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
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

                  // Login Button (Amber/Orange)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/orgLogin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
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

                  // Register Button (Light Grey with black border)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/orgRegistrationForm'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5E7EB),
                        side: const BorderSide(color: Colors.black, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Colors.black,
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 22,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Join using referral code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),

                  // Version
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
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
