import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkNavy = Color(0xFF0B1942);
    const Color vibrantOceanBlue = Color(0xFF1E88E5);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              children: [
                // Hero Logo Circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: vibrantOceanBlue.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: darkNavy.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/images/logo_main.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.construction_rounded,
                          size: 50,
                          color: vibrantOceanBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App Name
                ValueListenableBuilder<String>(
                  valueListenable: AppTheme.appName,
                  builder: (context, name, _) {
                    return Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A183D),
                        letterSpacing: 0.8,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Main Headline
                const Text(
                  'Manage Your Projects\nLike a Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle Description
                const Text(
                  'Plan, track, and manage your construction work\nseamlessly with professional tools.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5A759E),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Dark Navy Action Cards
                _buildDarkActionTile(
                  context: context,
                  label: 'Create Account',
                  subtitle: 'Register your organization',
                  icon: Icons.add_business_rounded,
                  accentColor: const Color(0xFF1E88E5),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/orgRegistrationForm',
                  ),
                ),
                _buildDarkActionTile(
                  context: context,
                  label: 'Login',
                  subtitle: 'Access your dashboard',
                  icon: Icons.login_rounded,
                  accentColor: const Color(0xFF42A5F5),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('temp_org_path');
                    if (context.mounted) {
                      Navigator.pushNamed(context, '/authSelection');
                    }
                  },
                ),
                _buildDarkActionTile(
                  context: context,
                  label: 'Join with Code',
                  subtitle: 'Join an existing organization',
                  icon: Icons.qr_code_scanner_rounded,
                  accentColor: const Color(0xFF0EA5E9),
                  onTap: () => Navigator.pushNamed(context, '/joinByReferral'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkActionTile({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    const Color darkNavy = Color(0xFF0B1942);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: darkNavy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: darkNavy.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
