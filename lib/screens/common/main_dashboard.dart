import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final roleItems = [
      _RoleItem(
        title: 'Organization',
        subtitle: 'Manage org details, subscriptions & data',
        icon: Icons.business_center_rounded,
        accentColor: const Color(0xFF3B82F6),
        destination: const Organisation_LoginPage(),
      ),
      _RoleItem(
        title: 'Manager',
        subtitle: 'Configure settings, workers & sites',
        icon: Icons.manage_accounts_rounded,
        accentColor: const Color(0xFF8B5CF6),
        destination: const ConfigLoginPage(),
      ),
      _RoleItem(
        title: 'Supervisor',
        subtitle: 'Manage daily site activities & materials',
        icon: Icons.supervisor_account_rounded,
        accentColor: const Color(0xFF10B981),
        destination: const SupervisorLoginPage(),
      ),
      _RoleItem(
        title: 'Customer',
        subtitle: 'View your live project status & reports',
        icon: Icons.person_rounded,
        accentColor: const Color(0xFF06B6D4),
        destination: const CustomerLoginPage(),
      ),
    ];

    final appTitle = _isFromReferral ? (_orgName ?? 'eBricks') : 'eBricks';

    return GlassScaffold(
      title: appTitle,
      onBack: () => Navigator.of(context).pop(),
      toolbarHeight: 52,
      padding: EdgeInsets.zero,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: vibrantOceanBlue),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isDesktop = screenWidth >= 900;
                final isTablet = screenWidth >= 600 && screenWidth < 900;
                final crossAxisCount = isDesktop ? 4 : (isTablet ? 4 : 2);
                final containerMaxWidth = isDesktop
                    ? 960.0
                    : (isTablet ? 760.0 : 500.0);

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: containerMaxWidth),
                    child: SingleChildScrollView(
                      primary: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header Row: Title on Left, Status Pill on Right
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Role Portals',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0A183D),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Select your portal to continue',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF5A759E),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A183D).withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '4 Portals',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0A183D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Compact Grid of Role Cards
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              mainAxisExtent: 148,
                            ),
                            itemCount: roleItems.length,
                            itemBuilder: (context, index) {
                              final item = roleItems[index];
                              return _buildGridRoleCard(context, item);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Individual 2-Column Grid Card matching the reference design
  Widget _buildGridRoleCard(BuildContext context, _RoleItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: item.accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => item.destination),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Centered Soft Pastel Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: item.accentColor.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.accentColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Role Title
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),

                // Role Subtitle
                Text(
                  item.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget destination;

  const _RoleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.destination,
  });
}
