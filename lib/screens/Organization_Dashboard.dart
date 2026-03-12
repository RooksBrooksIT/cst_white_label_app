import 'package:flutter/material.dart';
import 'package:demo_cst/screens/incentive_calculation.dart';
import 'package:demo_cst/screens/insights_dashboard.dart';
import 'package:demo_cst/screens/manager_expenses.dart';
import 'package:demo_cst/screens/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/material_report.dart';
import 'package:demo_cst/screens/org_site_supervisor_dailyWeek_report.dart';
import 'package:demo_cst/screens/organization_expenses.dart';
import 'package:demo_cst/screens/organization_site_entry.dart';
import 'package:demo_cst/screens/site_weekly_financial_report.dart';
import 'package:demo_cst/screens/tools_inventory_report.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'organisation_loginPage.dart';
import 'config_account_dashboard.dart';
import 'site_entry_page.dart';
import 'org_site_payment_screen.dart';
import 'manager_approval_screen.dart';

class OrganizationDashboard extends StatelessWidget {
  const OrganizationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF003768), Color(0xFF003768)],
            stops: [0.0, 0.6],
          ),
        ),
        child: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        "Organization Dashboard",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFF003768),
      leading: GestureDetector(
        onTap: () => _showLogoutConfirmation(context),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      actions: [
        GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Icon(Icons.logout, color: Colors.white),
          ),
        ),
      ],
    );
  }

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

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 50, bottom: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF772323),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 50, color: Color(0xFF2A5C8A)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Organization User",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "admin@organization.com",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItems(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerMenuItem(
            icon: Icons.dashboard,
            title: "Dashboard",
            isSelected: true,
          ),
          DrawerMenuItem(
            icon: Icons.settings,
            title: "Account Settings",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 129, 37, 30),
              Color.fromARGB(122, 230, 73, 73),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF4B2B).withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showLogoutConfirmation(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "LOGOUT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildDashboardSections(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back,",
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          "Organization User",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications feature coming soon')),
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

  void _navigateToSupervisorEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SiteEntryPage(userName: '', userDetails: {}),
      ),
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
