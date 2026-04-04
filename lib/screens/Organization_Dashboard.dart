import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
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
import '../utils/app_theme.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  _OrganizationDashboardState createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<String>(
        valueListenable: AppTheme.appName,
        builder: (context, appName, _) {
          return GlassScaffold(
            title: appName.isNotEmpty ? appName : 'Organization Dashboard',
            onBack: () => _showLogoutConfirmation(context),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: IconButton(
                  icon: Icon(
                    Icons.menu,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrgMenuScreen(),
                    ),
                  ),
                ),
              ),
            ],
            body: _buildBody(context),
          );
        },
      ),
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
      await AuthService().logout();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/landing',
          (route) => false,
        );
      }
    }
  }

  Widget _buildWelcomeSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
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
        ValueListenableBuilder<String>(
          valueListenable: AppTheme.appName,
          builder: (context, appName, _) {
            return Text(
              appName,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -1.0,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(theme),
          const SizedBox(height: 32),
          _buildDashboardSections(context, theme),
        ],
      ),
    );
  }

  Widget _buildDashboardSections(BuildContext context, ThemeData theme) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200
        ? 5
        : (screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2));

    double childAspectRatio = screenWidth < 400
        ? 0.85
        : (screenWidth < 600 ? 0.95 : 1.1);

    Widget buildGrid(List<Widget> children) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
            iconColor: theme.primaryColor,
            onTap: () => _navigateToConfiguration(context),
          ),
        ]),

        _buildSectionHeader("Weekly Financial Balance Sheet", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Site Payment Entry",
            icon: Icons.payments,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          _buildMenuCard(
            context,
            title: "Site Payment Report",
            icon: Icons.receipt,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToDailyReport(context),
          ),
          _buildMenuCard(
            context,
            title: "Weekly Finance Report",
            icon: Icons.bar_chart,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
        ]),

        _buildSectionHeader("Expenses", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Organization Expenses",
            icon: Icons.account_balance_wallet,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          _buildMenuCard(
            context,
            title: "Manager Expenses",
            icon: Icons.attach_money,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToManagerExpenses(context),
          ),
          _buildMenuCard(
            context,
            title: "Supervisor Expenses",
            icon: Icons.money,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToSiteExpenses(context),
          ),
        ]),

        _buildSectionHeader("Approvals", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Schedule Request Approval",
            icon: Icons.work,
            iconColor: theme.primaryColor,
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
            iconColor: theme.primaryColor,
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
            iconColor: theme.primaryColor,
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ]),

        _buildSectionHeader("Insights", theme),
        buildGrid([
          _buildMenuCard(
            context,
            title: "Financial Reports",
            icon: Icons.analytics,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToInsights(context),
          ),
          _buildMenuCard(
            context,
            title: "Materials Inventory",
            icon: Icons.inventory_2,
            iconColor: theme.primaryColor,
            onTap: () => _navigateToMaterialReport(context),
          ),
          _buildMenuCard(
            context,
            title: "Tools Inventory",
            icon: Icons.build,
            iconColor: theme.primaryColor,
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
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                letterSpacing: 2.0,
              ),
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.1,
                  ),
                ),
              ],
            ),
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
