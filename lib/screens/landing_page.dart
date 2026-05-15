import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'migration_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Hero Image with modern glass effect
                  GestureDetector(
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MigrationScreen(),
                        ),
                      );
                    },
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.1),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Hero(
                            tag: 'hero_image',
                            child: ClipOval(
                              child: Container(
                                width: 190,
                                height: 190,
                                color: Colors.white,
                                child: Image.asset(
                                  'assets/images/logo_main.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.construction_rounded,
                                        size: 100,
                                        color: primaryColor.withOpacity(0.5),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Headline & Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: AppTheme.appName,
                          builder: (context, name, _) {
                            return Text(
                              'Manage Your Projects\nLike a Pro',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                height: 1.1,
                                letterSpacing: -1.0,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Plan, track, and manage your construction\nwork seamlessly with professional tools.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Cards Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      children: [
                        _buildActionTile(
                          context: context,
                          label: 'Create Account',
                          subtitle: 'Register your organization',
                          icon: Icons.add_business_rounded,
                          isPrimary: true,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/orgRegistrationForm',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildActionTile(
                          context: context,
                          label: 'Login',
                          subtitle: 'Access your dashboard',
                          icon: Icons.login_rounded,
                          isPrimary: false,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('temp_org_path');
                            if (context.mounted) {
                              Navigator.pushNamed(context, '/authSelection');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildActionTile(
                          context: context,
                          label: 'Join with Code',
                          subtitle: 'Join an existing organization',
                          icon: Icons.qr_code_scanner_rounded,
                          isPrimary: false,
                          onTap: () =>
                              Navigator.pushNamed(context, '/joinByReferral'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? primaryColor : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? primaryColor : theme.dividerColor.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? primaryColor.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withOpacity(0.2)
                        : primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isPrimary
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isPrimary
                              ? Colors.white.withOpacity(0.8)
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isPrimary
                      ? Colors.white.withOpacity(0.5)
                      : theme.dividerColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
