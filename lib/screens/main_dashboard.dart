import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    const Color textColor = Color(0xFF1E293B);
    const Color labelColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.isMobile(context) ? 20 : 32,
                ),
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
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(_logoUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            size: 56,
                            color: colorScheme.primary,
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _orgName ?? 'Organization',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select your role to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      // Generic Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.construction_rounded,
                          size: 56,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Select Your Role',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose how you\'d like to sign in',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // Role Cards
                    if (!_isFromReferral) ...[
                      _buildRoleCard(
                        context: context,
                        title: 'Organization',
                        subtitle: 'Manage org details & data',
                        icon: Icons.account_balance_rounded,
                        accentColor: colorScheme.primary,
                        destination: const Organisation_LoginPage(),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                      accentColor: colorScheme.tertiary,
                      destination: const SupervisorLoginPage(),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      context: context,
                      title: 'Customer',
                      subtitle: 'View your project status',
                      icon: Icons.person_rounded,
                      accentColor: colorScheme.outline,
                      destination: const CustomerLoginPage(),
                    ),
                    const SizedBox(height: 40),
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
    required IconData icon,
    required Color accentColor,
    required Widget destination,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 20),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFCBD5E1),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
