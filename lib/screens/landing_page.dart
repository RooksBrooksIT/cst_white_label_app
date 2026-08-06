import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/terms_helper.dart';
import '../widgets/irregular_background.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;

    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1024;
    bool isDesktop = screenWidth >= 1024;

    double horizontalPadding = isDesktop ? 40 : (isTablet ? 32 : 20);
    double maxContentWidth = 1000;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IrregularBackground(
        color: primaryColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 600,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      // ---------- Compact Hero Section ----------
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: isDesktop ? 160 : (isTablet ? 145 : 130),
                              height: isDesktop ? 160 : (isTablet ? 145 : 130),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.15),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Hero(
                              tag: 'hero_image',
                              child: ClipOval(
                                child: Container(
                                  width: isDesktop
                                      ? 130
                                      : (isTablet ? 115 : 100),
                                  height: isDesktop
                                      ? 130
                                      : (isTablet ? 115 : 100),
                                  color: Colors.white,
                                  child: Image.asset(
                                    'assets/images/logo_main.png',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.construction_rounded,
                                          size: isDesktop
                                              ? 60
                                              : (isTablet ? 55 : 50),
                                          color: primaryColor.withOpacity(0.6),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isDesktop ? 24 : (isTablet ? 20 : 16)),

                      // ---------- Headline & Subtitle (more compact) ----------
                      ValueListenableBuilder<String>(
                        valueListenable: AppTheme.appName,
                        builder: (context, name, _) {
                          return Column(
                            children: [
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isDesktop
                                      ? 22
                                      : (isTablet ? 20 : 18),
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(
                                height: isDesktop ? 12 : (isTablet ? 10 : 8),
                              ),
                              Text(
                                'Manage Your Projects\nLike a Pro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isDesktop
                                      ? 32
                                      : (isTablet ? 29 : 26),
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: isDesktop ? 14 : (isTablet ? 12 : 10)),
                      Text(
                        'Plan, track, and manage your construction work\nseamlessly with professional tools.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 40 : (isTablet ? 36 : 32)),

                      // ---------- Three Action Cards (now primary focus) ----------
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
                        isMobile: isMobile,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: isDesktop ? 18 : (isTablet ? 16 : 14)),
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
                        isMobile: isMobile,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      SizedBox(height: isDesktop ? 18 : (isTablet ? 16 : 14)),
                      _buildActionTile(
                        context: context,
                        label: 'Join with Code',
                        subtitle: 'Join an existing organization',
                        icon: Icons.qr_code_scanner_rounded,
                        isPrimary: false,
                        onTap: () =>
                            Navigator.pushNamed(context, '/joinByReferral'),
                        isMobile: isMobile,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                      // const SizedBox(height: 24),
                      // TextButton(
                      //   onPressed: () {
                      //     TermsHelper.showTermsDialog(context, onAccepted: () {});
                      //   },
                      //   child: Text(
                      //     'Terms & Conditions',
                      //     style: TextStyle(
                      //       color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      //       fontSize: 13,
                      //       fontWeight: FontWeight.w600,
                      //       decoration: TextDecoration.underline,
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final colorScheme = theme.colorScheme;

    // Enhanced design: bigger icon container, bolder typography, refined shadows
    return Container(
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPrimary ? primaryColor : theme.dividerColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? primaryColor.withOpacity(0.35)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 18 : (isTablet ? 16 : 14),
              horizontal: isDesktop ? 20 : (isTablet ? 18 : 16),
            ),
            child: Row(
              children: [
                // Icon container – larger & more impactful
                Container(
                  width: isDesktop ? 84 : (isTablet ? 78 : 72),
                  height: isDesktop ? 84 : (isTablet ? 78 : 72),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withOpacity(0.2)
                        : primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : primaryColor,
                    size: isDesktop ? 40 : (isTablet ? 36 : 32),
                  ),
                ),
                SizedBox(width: isDesktop ? 22 : (isTablet ? 20 : 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : (isTablet ? 19 : 18),
                          fontWeight: FontWeight.w800,
                          color: isPrimary
                              ? Colors.white
                              : colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 6 : (isTablet ? 5 : 4)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : (isTablet ? 14 : 13),
                          color: isPrimary
                              ? Colors.white.withOpacity(0.85)
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isPrimary
                      ? Colors.white.withOpacity(0.7)
                      : theme.dividerColor.withOpacity(0.6),
                  size: isDesktop ? 22 : (isTablet ? 20 : 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
