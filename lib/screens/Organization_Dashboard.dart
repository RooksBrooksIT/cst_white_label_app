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
    final colorScheme = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: _orgName.isNotEmpty ? _orgName : 'Organization Dashboard',
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: Colors.white,
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

  Widget _buildWelcomeSection(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back,",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _orgName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (isMobile
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineLarge)
              ?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 400 ? 12.0 : (screenWidth < 600 ? 16.0 : 24.0);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(context, theme),
          const SizedBox(height: 24),
          _buildDashboardSections(context, theme),
        ],
      ),
    );
  }

  Widget _buildDashboardSections(BuildContext context, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 1200
        ? 5
        : (screenWidth > 900
            ? 4
            : (screenWidth > 600
                ? 3
                : (screenWidth > 380 ? 2 : 2)));

    // Taller aspect ratio on small screens so text never overflows the card.
    final double childAspectRatio = screenWidth < 380
        ? 0.85
        : (screenWidth < 600
            ? 0.95
            : (screenWidth < 900 ? 1.0 : 1.1));

    final double spacing = screenWidth < 400 ? 10.0 : 16.0;

    Widget buildGrid(List<Widget> children) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Configuration", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Manager Account",
            icon: Icons.settings,
            iconColor: Colors.blue[600]!,
            onTap: () => _navigateToConfiguration(context),
          ),
        ]),

        _buildSectionHeader("Weekly Financial Balance Sheet", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Site Payment Entry",
            icon: Icons.payments,
            iconColor: Colors.green[600]!,
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          _buildMenuCard(
            context,
            title: "Site Payment Report",
            icon: Icons.receipt,
            iconColor: Colors.purple[600]!,
            onTap: () => _navigateToDailyReport(context),
          ),
          _buildMenuCard(
            context,
            title: "Weekly Finance Report",
            icon: Icons.bar_chart,
            iconColor: Colors.orange[600]!,
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
        ]),

        _buildSectionHeader("Expenses", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Organization Expenses",
            icon: Icons.account_balance_wallet,
            iconColor: Colors.red[600]!,
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          _buildMenuCard(
            context,
            title: "Manager Expenses",
            icon: Icons.attach_money,
            iconColor: Colors.teal[600]!,
            onTap: () => _navigateToManagerExpenses(context),
          ),
          _buildMenuCard(
            context,
            title: "Supervisor Expenses",
            icon: Icons.money,
            iconColor: Colors.indigo[600]!,
            onTap: () => _navigateToSiteExpenses(context),
          ),
        ]),

        _buildSectionHeader("Approvals", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Schedule Request Approval",
            icon: Icons.work,
            iconColor: Colors.deepPurple[600]!,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerApprovalScreen(),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            title: "Material Request Approval",
            icon: Icons.inventory,
            iconColor: Colors.blueGrey[600]!,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerMaterialApprovalScreen(),
              ),
            ),
          ),
        ]),

        _buildSectionHeader("Supervisor Incentive Calculator", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Incentive Calculation",
            icon: Icons.calculate,
            iconColor: Colors.amber[600]!,
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ]),

        _buildSectionHeader("Insights", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Financial Reports",
            icon: Icons.analytics,
            iconColor: Colors.pink[600]!,
            onTap: () => _navigateToInsights(context),
          ),
          _buildMenuCard(
            context,
            title: "Materials Inventory",
            icon: Icons.inventory_2,
            iconColor: Colors.deepOrange[600]!,
            onTap: () => _navigateToMaterialReport(context),
          ),
          _buildMenuCard(
            context,
            title: "Tools Inventory",
            icon: Icons.build,
            iconColor: Colors.cyan[600]!,
            onTap: () => _navigateToToolsInventory(context),
          ),
        ]),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 120;
              final iconSize = isCompact ? 28.0 : 36.0;
              final iconPad = isCompact ? 10.0 : 14.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 10 : 14,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPad),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: iconSize),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (isCompact
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
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
