import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_cst/screens/customer/customer_login_page.dart';
import 'package:demo_cst/screens/organization/organisation_login_page.dart';
import 'package:demo_cst/screens/supervisor/supervisor_login_page.dart';
import 'package:demo_cst/screens/common/config_login.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isLoading = true;
  String? _orgName;
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
    const Color vibrantOceanBlue = Color(0xFF1E88E5);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: vibrantOceanBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Custom Header Row (Back Button & Centered App Name)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Text(
                          _isFromReferral ? (_orgName ?? 'eBricks') : 'eBricks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 40), // Balance spacing for centering
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Role Portals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Select your workspace role to log in',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5A759E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Full Screen Width Edge-to-Edge Dark Navy Role Cards
                  _buildDarkRoleCard(
                    context: context,
                    title: 'Organization',
                    subtitle: 'Manage org details, subscriptions & data',
                    icon: Icons.business_center_rounded,
                    accentColor: const Color(0xFF1E88E5),
                    destination: const Organisation_LoginPage(),
                  ),
                  _buildDarkRoleCard(
                    context: context,
                    title: 'Manager',
                    subtitle: 'Configure settings, workers & sites',
                    icon: Icons.manage_accounts_rounded,
                    accentColor: const Color(0xFF42A5F5),
                    destination: const ConfigLoginPage(),
                  ),
                  _buildDarkRoleCard(
                    context: context,
                    title: 'Supervisor',
                    subtitle: 'Manage daily site activities & materials',
                    icon: Icons.supervisor_account_rounded,
                    accentColor: const Color(0xFF0EA5E9),
                    destination: const SupervisorLoginPage(),
                  ),
                  _buildDarkRoleCard(
                    context: context,
                    title: 'Customer',
                    subtitle: 'View your live project status & reports',
                    icon: Icons.person_rounded,
                    accentColor: const Color(0xFF10B981),
                    destination: const CustomerLoginPage(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDarkRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget destination,
  }) {
    const Color darkNavy = Color(0xFF0B1942);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
                          title,
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
