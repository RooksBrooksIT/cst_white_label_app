import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive.dart';
import 'migration_screen.dart';
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.15),
              primaryColor.withOpacity(0.05),
              Colors.white,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Hero Image
              GestureDetector(
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MigrationScreen()),
                  );
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.6),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.08),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/construction_hero.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ), // Close Container
              ), // Close GestureDetector
              
              const SizedBox(height: 36),

              // Headline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Manage Your Projects\nLike a Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 30),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Plan, track, and manage your construction\nwork seamlessly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    // Create Account - Primary
                    _buildActionCard(
                      context: context,
                      label: 'Create Account →',
                      icon: Icons.person_add_rounded,
                      isPrimary: true,
                      primaryColor: primaryColor,
                      onTap: () =>
                          Navigator.pushNamed(context, '/orgRegistrationForm'),
                    ),
                    const SizedBox(height: 14),

                    // Login
                    _buildActionCard(
                      context: context,
                      label: 'Login to your account',
                      icon: Icons.login_rounded,
                      isPrimary: false,
                      primaryColor: primaryColor,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('temp_org_path');
                        if (context.mounted) {
                          Navigator.pushNamed(context, '/authSelection');
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Join by Referral
                    _buildActionCard(
                      context: context,
                      label: 'Join using Referral Code',
                      icon: Icons.qr_code_2_rounded,
                      isPrimary: false,
                      primaryColor: primaryColor,
                      onTap: () =>
                          Navigator.pushNamed(context, '/joinByReferral'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isPrimary,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  )
                : null,
            color: isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? primaryColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isPrimary ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withOpacity(0.2)
                      : primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : const Color(0xFF334155),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isPrimary
                    ? Colors.white.withOpacity(0.7)
                    : const Color(0xFFCBD5E1),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
