import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OrgMenuScreen()),
          ),
        ),
      ],
      body: _buildBody(context),
    );
  }

  // _buildAppBar removed - GlassScaffold handles header

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
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
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login and clear all routes
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
        const Text(
          "Welcome back,",
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          _orgName,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
        // Configuration Section
        _buildSectionHeader("Configuration"),
        _buildColorfulCard(
          context,
          title: "Manager Account",
          icon: Icons.settings,
          iconColor: Colors.blue[800]!,
          onTap: () => _navigateToConfiguration(context),
        ),

        // Weekly Financial Balance Sheet Section
        _buildSectionHeader("Weekly Financial Balance Sheet"),
        _buildColorfulCard(
          context,
          title: "Site Payment Entry",
          icon: Icons.payments,
          iconColor: Colors.green[800]!,
          onTap: () => _navigateToSitePaymentEntry(context),
        ),
        _buildColorfulCard(
          context,
          title: "Site Payment Entry Report",
          icon: Icons.receipt,
          iconColor: Colors.purple[800]!,
          onTap: () => _navigateToDailyReport(context),
        ),
        _buildColorfulCard(
          context,
          title: "Weekly Site Finance Report",
          icon: Icons.bar_chart,
          iconColor: Colors.orange[800]!,
          onTap: () => _navigateToSiteWeeklyFinancialReport(context),
        ),

        // Expenses Section
        _buildSectionHeader("Expenses"),
        _buildColorfulCard(
          context,
          title: "Organization Expenses",
          icon: Icons.account_balance_wallet,
          iconColor: Colors.red[800]!,
          onTap: () => _navigateToOrganizationExpenses(context),
        ),
        _buildColorfulCard(
          context,
          title: "Manager Expenses",
          icon: Icons.attach_money,
          iconColor: Colors.teal[800]!,
          onTap: () => _navigateToManagerExpenses(
            context,
          ), // Add navigation for Manager Expenses
        ),
        _buildColorfulCard(
          context,
          title: "Supervisor Expenses",
          icon: Icons.money,
          iconColor: Colors.indigo[800]!,
          onTap: () => _navigateToSiteExpenses(
            context,
          ), // Add navigation for Supervisor Expenses
        ),

        // Approvals Section
        _buildSectionHeader("Approvals"),
        _buildColorfulCard(
          context,
          title: "Supervisor Work Schedule Request Approval",
          icon: Icons.work,
          iconColor: Colors.deepPurple[800]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ManagerApprovalScreen()),
          ),
        ),
        _buildColorfulCard(
          context,
          title: "Supervisor Material Request Approval",
          icon: Icons.inventory,
          iconColor: Colors.blueGrey[800]!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManagerMaterialApprovalScreen(),
            ),
          ),
        ),

        // Incentive Calculator
        _buildSectionHeader("Supervisor Incentive Calculator"),
        _buildColorfulCard(
          context,
          title: "Incentive Calculation",
          icon: Icons.calculate,
          iconColor: Colors.amber[800]!,
          onTap: () => _navigateToIncentiveCaliculation(context),
        ),

        // Insights Section
        _buildSectionHeader("Insights"),
        _buildColorfulCard(
          context,
          title: "Project Financial Reports",
          icon: Icons.analytics,
          iconColor: Colors.pink[800]!,
          onTap: () => _navigateToInsights(context),
        ),
        _buildColorfulCard(
          context,
          title: "Materials Inventory",
          icon: Icons.inventory_2,
          iconColor: Colors.deepOrange[800]!,
          onTap: () => _navigateToMaterialReport(context),
        ),
        _buildColorfulCard(
          context,
          title: "Tools Inventory",
          icon: Icons.build,
          iconColor: Colors.cyan[800]!,
          onTap: () => _navigateToToolsInventory(
            context,
          ), // Add navigation for Tools Inventory
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildColorfulCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ],
          ),
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

class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onTap;

  const DrawerMenuItem({
    required this.icon,
    required this.title,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2A5C8A).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF2A5C8A) : Colors.grey[700],
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF2A5C8A) : Colors.grey[700],
        ),
      ),
      onTap: onTap,
    );
  }
}
