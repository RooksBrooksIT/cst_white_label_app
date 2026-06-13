import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import 'Organisation_LoginPage.dart';
import 'config_login.dart';
import 'customer_login_page.dart';
import 'supervisor_login_page.dart';
import '../utils/responsive.dart';
import '../utils/app_theme.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isLoading = true;
  String? _orgName;
  String? _logoUrl;
  String? _referralRole;
  bool _isFromReferral = false;

  @override
  void initState() {
    super.initState();
    _checkReferralState();
  }

  Future<void> _checkReferralState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempOrgPath = prefs.getString('temp_org_path');
      final referralRole = prefs.getString('temp_referral_role');

      if (tempOrgPath != null && tempOrgPath.isNotEmpty) {
        _isFromReferral = true;

        // Sync branding for referral users immediately
        await AppTheme.syncWithFirestore(tempOrgPath);

        // Fetch org details
        final doc = await FirebaseFirestore.instance
            .collection('organisation')
            .doc(tempOrgPath)
            .collection('admin')
            .doc('data')
            .get();

        if (doc.exists && mounted) {
          final orgName = doc.data()?['orgName'] as String?;
          final logoUrl = doc.data()?['logoUrl'] as String?;

          setState(() {
            _orgName = orgName;
            _logoUrl = logoUrl;
            _referralRole = referralRole;
          });

          // Save org details for login pages to display
          if (orgName != null) await prefs.setString('temp_org_name', orgName);
          if (logoUrl != null) await prefs.setString('temp_logo_url', logoUrl);
        }
      }
    } catch (e) {
      debugPrint('Error fetching org details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1024;
    bool isDesktop = screenWidth >= 1024;

    double horizontalPadding = isDesktop ? 40 : (isTablet ? 32 : 20);
    double maxContentWidth = 1000;

    return GlassScaffold(
      onBack: () => Navigator.of(context).pop(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: isDesktop ? 16 : (isTablet ? 14 : 12)),
                        // Header
                        if (_isFromReferral) ...[
                          // Organization Logo
                          if (_logoUrl != null && _logoUrl!.isNotEmpty)
                            Container(
                              width: isDesktop ? 140 : (isTablet ? 125 : 110),
                              height: isDesktop ? 140 : (isTablet ? 125 : 110),
                              padding: EdgeInsets.all(
                                isDesktop ? 6 : (isTablet ? 5 : 4),
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: colorScheme.outline,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.all(
                                isDesktop ? 34 : (isTablet ? 31 : 28),
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business_rounded,
                                size: isDesktop ? 72 : (isTablet ? 66 : 60),
                                color: colorScheme.primary,
                              ),
                            ),
                          SizedBox(
                            height: isDesktop ? 30 : (isTablet ? 27 : 24),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: AppTheme.appName,
                            builder: (context, name, _) {
                              return Text(
                                name,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontSize: isDesktop
                                      ? 34
                                      : (isTablet ? 31 : 28),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              );
                            },
                          ),
                          SizedBox(
                            height: isDesktop ? 12 : (isTablet ? 10 : 8),
                          ),
                          Text(
                            'Select your role to continue',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
                          // Generic Header
                          Container(
                            width: isDesktop ? 150 : (isTablet ? 135 : 120),
                            height: isDesktop ? 150 : (isTablet ? 135 : 120),
                            padding: EdgeInsets.all(
                              isDesktop ? 6 : (isTablet ? 5 : 4),
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 75 : (isTablet ? 67 : 60),
                              ),
                              child: Image.asset(
                                'assets/images/logo_main.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: isDesktop ? 34 : (isTablet ? 31 : 28),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: AppTheme.appName,
                            builder: (context, name, _) {
                              return Text(
                                name,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontSize: isDesktop
                                      ? 34
                                      : (isTablet ? 31 : 28),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              );
                            },
                          ),
                        ],

                        SizedBox(height: isDesktop ? 56 : (isTablet ? 52 : 48)),

                        // Role Cards
                        _buildRoleCard(
                          context: context,
                          title: 'Organization',
                          subtitle: 'Manage org details & data',
                          icon: Icons.business_center_rounded,
                          accentColor: colorScheme.primary,
                          destination: const Organisation_LoginPage(),
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                        _buildRoleCard(
                          context: context,
                          title: 'Manager',
                          subtitle: 'Configure settings & control',
                          icon: Icons.manage_accounts_rounded,
                          accentColor: colorScheme.secondary,
                          destination: const ConfigLoginPage(),
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                        _buildRoleCard(
                          context: context,
                          title: 'Supervisor',
                          subtitle: 'Manage site activities',
                          icon: Icons.supervisor_account_rounded,
                          accentColor: const Color(0xFF0EA5E9),
                          destination: const SupervisorLoginPage(),
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                        _buildRoleCard(
                          context: context,
                          title: 'Customer',
                          subtitle: 'View your project status',
                          icon: Icons.person_rounded,
                          accentColor: const Color(0xFF10B981),
                          destination: const CustomerLoginPage(),
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
                        SizedBox(
                          height: isDesktop ? 48 : (isTablet ? 44 : 40),
                        ), // Extra bottom padding
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

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    IconData? icon,
    String? logoPath,
    required Color accentColor,
    required Widget destination,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 18 : (isTablet ? 16 : 14),
          horizontal: isDesktop ? 20 : (isTablet ? 18 : 16),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: isDesktop ? 68 : (isTablet ? 62 : 56),
              height: isDesktop ? 68 : (isTablet ? 62 : 56),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentColor, accentColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(
                  isDesktop ? 20 : (isTablet ? 18 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: logoPath != null
                  ? Padding(
                      padding: EdgeInsets.all(
                        isDesktop ? 5 : (isTablet ? 4.5 : 4.0),
                      ),
                      child: Image.asset(logoPath, fit: BoxFit.contain),
                    )
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: isDesktop ? 34 : (isTablet ? 31 : 28),
                    ),
            ),
            SizedBox(width: isDesktop ? 24 : (isTablet ? 22 : 20)),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 20 : (isTablet ? 19 : 18),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 6 : (isTablet ? 5 : 4)),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: isDesktop ? 15 : (isTablet ? 14.5 : 14),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: isDesktop ? 20 : (isTablet ? 18 : 16),
            ),
          ],
        ),
      ),
    );
  }
}
