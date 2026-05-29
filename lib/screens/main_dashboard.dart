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

    return GlassScaffold(
      onBack: () => Navigator.of(context).pop(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    // Header
                    if (_isFromReferral) ...[
                      // Organization Logo
                      if (_logoUrl != null && _logoUrl!.isNotEmpty)
                        Container(
                          width: 110,
                          height: 110,
                          padding: const EdgeInsets.all(4),
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
                          child: Image.network(_logoUrl!, fit: BoxFit.contain),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            size: 60,
                            color: colorScheme.primary,
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _orgName ?? 'Organization',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: Responsive.fontSize(context, 28),
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your role to continue',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: Responsive.fontSize(context, 14),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      // Generic Header
                      Container(
                        width: Responsive.scaleH(context, 120),
                        height: Responsive.scaleH(context, 120),
                        padding: const EdgeInsets.all(4),
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
                          borderRadius: BorderRadius.circular(60),
                          child: Image.asset(
                            'assets/images/logo_main.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Select Your Role',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: Responsive.fontSize(context, 28),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Role Cards
                      _buildRoleCard(
                        context: context,
                        title: 'Organization',
                        subtitle: 'Manage org details & data',
                        icon: Icons.business_center_rounded,
                        accentColor: colorScheme.primary,
                        destination: const Organisation_LoginPage(),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleCard(
                        context: context,
                        title: 'Manager',
                        subtitle: 'Configure settings & control',
                        icon: Icons.manage_accounts_rounded,
                        accentColor: colorScheme.secondary,
                        destination: const ConfigLoginPage(),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleCard(
                        context: context,
                        title: 'Supervisor',
                        subtitle: 'Manage site activities',
                        icon: Icons.supervisor_account_rounded,
                        accentColor: const Color(0xFF0EA5E9),
                        destination: const SupervisorLoginPage(),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleCard(
                        context: context,
                        title: 'Customer',
                        subtitle: 'View your project status',
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF10B981),
                        destination: const CustomerLoginPage(),
                      ),
                      const SizedBox(height: 40), // Extra bottom padding
                    ],
                  ],
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
  }) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor, accentColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(logoPath, fit: BoxFit.contain),
                  )
                : Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.fontSize(context, 18),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: Responsive.fontSize(context, 14),
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
            size: 16,
          ),
        ],
      ),
    );
  }
}
