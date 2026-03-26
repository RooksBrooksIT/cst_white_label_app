import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'organisation_loginPage.dart';
import 'config_account_dashboard.dart';
import 'org_site_payment_screen.dart';
import 'incentive_calculation.dart';
import 'insights_dashboard.dart';
import 'manager_expenses.dart';
import 'manager_material_approval_screen.dart';
import 'material_report.dart';
import 'org_site_supervisor_dailyWeek_report.dart';
import 'organization_expenses.dart';
import 'organization_site_entry.dart';
import 'site_weekly_financial_report.dart';
import 'tools_inventory_report.dart';
import 'manager_approval_screen.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import 'org_menu_screen.dart';
import '../utils/responsive.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  _OrganizationDashboardState createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  String _orgName = 'Organization User';

  @override
  void initState() {
    super.initState();
    _fetchOrgData();
  }

  Future<void> _fetchOrgData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? name = prefs.getString('org_name');

      if (name != null) setState(() => _orgName = name);
    } catch (e) {
      debugPrint('Error fetching org data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      onBack: () => _showLogoutConfirmation(context),
      actions: [
        IconButton(
          icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OrgMenuScreen()),
          ),
        ),
      ],
      body: _buildBody(context),
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Organisation_LoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back,",
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _orgName,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 32),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.isMobile(context) ? 16 : 32,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 32),
          _buildDashboardSections(context),
        ],
      ),
    );
  }

  Widget _buildDashboardSections(BuildContext context) {
    return Column(
      children: [
        _buildSectionHeader("Configuration"),
        _buildMenuCard(
          context,
          title: "Manager Account",
          icon: Icons.settings,
          iconColor: Colors.blue[400]!,
          onTap: () => _navigateToConfiguration(context),
        ),

        _buildSectionHeader("Weekly Financial Balance Sheet"),
        _buildMenuCard(
          context,
          title: "Site Payment Entry",
          icon: Icons.payments,
          iconColor: Colors.green[400]!,
          onTap: () => _navigateToSitePaymentEntry(context),
        ),
        _buildMenuCard(
          context,
          title: "Site Payment Entry Report",
          icon: Icons.receipt,
          iconColor: Colors.purple[400]!,
          onTap: () => _navigateToDailyReport(context),
        ),
        _buildMenuCard(
          context,
          title: "Weekly Site Finance Report",
          icon: Icons.bar_chart,
          iconColor: Colors.orange[400]!,
          onTap: () => _navigateToSiteWeeklyFinancialReport(context),
        ),

        _buildSectionHeader("Expenses"),
        _buildMenuCard(
          context,
          title: "Organization Expenses",
          icon: Icons.account_balance_wallet,
          iconColor: Colors.red[400]!,
          onTap: () => _navigateToOrganizationExpenses(context),
        ),
        _buildMenuCard(
          context,
          title: "Manager Expenses",
          icon: Icons.attach_money,
          iconColor: Colors.teal[400]!,
          onTap: () => _navigateToManagerExpenses(context),
        ),
        _buildMenuCard(
          context,
          title: "Supervisor Expenses",
          icon: Icons.money,
          iconColor: Colors.indigo[400]!,
          onTap: () => _navigateToSiteExpenses(context),
        ),

        _buildSectionHeader("Approvals"),
        _buildMenuCard(
          context,
          title: "Supervisor Work Schedule Request Approval",
          icon: Icons.work,
          iconColor: Colors.deepPurple[400]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerApprovalScreen(),
            ),
          ),
        ),
        _buildMenuCard(
          context,
          title: "Supervisor Material Request Approval",
          icon: Icons.inventory,
          iconColor: Colors.blueGrey[400]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerMaterialApprovalScreen(),
            ),
          ),
        ),

        _buildSectionHeader("Supervisor Incentive Calculator"),
        _buildMenuCard(
          context,
          title: "Incentive Calculation",
          icon: Icons.calculate,
          iconColor: Colors.amber[400]!,
          onTap: () => _navigateToIncentiveCaliculation(context),
        ),

        _buildSectionHeader("Insights"),
        _buildMenuCard(
          context,
          title: "Project Financial Reports",
          icon: Icons.analytics,
          iconColor: Colors.pink[400]!,
          onTap: () => _navigateToInsights(context),
        ),
        _buildMenuCard(
          context,
          title: "Materials Inventory",
          icon: Icons.inventory_2,
          iconColor: Colors.deepOrange[400]!,
          onTap: () => _navigateToMaterialReport(context),
        ),
        _buildMenuCard(
          context,
          title: "Tools Inventory",
          icon: Icons.build,
          iconColor: Colors.cyan[400]!,
          onTap: () => _navigateToToolsInventory(context),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToConfiguration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigAccountDashboard()),
    );
  }

  void _navigateToDailyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DailySitePaymentReportScreen()),
    );
  }

  void _navigateToInsights(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InsightsDashboard()),
    );
  }

  void _navigateToSitePaymentEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SitePaymentScreen()),
    );
  }

  void _navigateToSiteWeeklyFinancialReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SiteWeeklyFinancialReports()),
    );
  }

  void _navigateToIncentiveCaliculation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IncentiveCalculation()),
    );
  }

  void _navigateToOrganizationExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrganizationExpenses()),
    );
  }

  void _navigateToManagerExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManagerExpenses()),
    );
  }

  void _navigateToMaterialReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MaterialReportPage()),
    );
  }

  void _navigateToToolsInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ToolsInventoryPage()),
    );
  }

  void _navigateToSiteExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const OrganizationSiteEntry(userName: '', userDetails: {}),
      ),
    );
  }
}
