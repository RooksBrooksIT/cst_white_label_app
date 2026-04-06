import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../utils/app_theme.dart';
import 'org_sub_menu_screen.dart';
import 'org_menu_screen.dart';
import 'manager_config_screen.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  _OrganizationDashboardState createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppTheme.appName,
      builder: (context, appName, _) {
        return GlassScaffold(
          title: appName.isNotEmpty ? appName : 'Organization Dashboard',
          onBack: () => _showLogoutConfirmation(context),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu',
              color: Theme.of(context).colorScheme.onPrimary,
              onPressed: () => _navigateToOrgMenu(context),
            ),
          ],
          body: _buildBody(context),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[300], size: 28),
            const SizedBox(width: 12),
            const Text(
              'Confirm Logout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await AuthService().logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('org_isLoggedIn');
      await prefs.remove('org_username');

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.1),
                  theme.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.waving_hand_rounded,
                  size: 18,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  "Welcome back,",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: AppTheme.appName,
            builder: (context, appName, _) {
              return Text(
                appName,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -1.0,
                  fontSize: 34,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            "Manage your organization efficiently",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(theme),
                const SizedBox(height: 32),
                _buildQuickStats(context, theme),
                const SizedBox(height: 32),
                _buildDashboardSections(context, theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, ThemeData theme) {
    final stats = [
      {
        'icon': Icons.payments_rounded,
        'label': 'Pending',
        'value': '12',
        'color': Colors.orange,
      },
      {
        'icon': Icons.check_circle_rounded,
        'label': 'Approved',
        'value': '45',
        'color': Colors.green,
      },
      {
        'icon': Icons.pending_actions_rounded,
        'label': 'Requests',
        'value': '8',
        'color': Colors.blue,
      },
      {
        'icon': Icons.trending_up_rounded,
        'label': 'Revenue',
        'value': '₹2.4L',
        'color': Colors.purple,
      },
    ];

    return Container(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            width: (MediaQuery.of(context).size.width - 64) / 2.2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (stat['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    stat['icon'] as IconData,
                    color: stat['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat['value'] as String,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        stat['label'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardSections(BuildContext context, ThemeData theme) {
    final categories = [
      _CategoryData(
        title: "Administrative & Config",
        subtitle: "Manage accounts and system settings",
        icon: Icons.admin_panel_settings_rounded,
        color: theme.primaryColor,
        gradientColors: [
          theme.primaryColor,
          theme.primaryColor.withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: "Manager Account",
            subtitle: "Configure profiles and access permissions",
            icon: Icons.admin_panel_settings_rounded,
            color: theme.primaryColor,
            onTap: () => _navigateToConfiguration(context),
          ),
          SubMenuItem(
            title: "Manager Config",
            subtitle: "Create and manage manager profiles",
            icon: Icons.manage_accounts_rounded,
            color: theme.primaryColor,
            onTap: () => _navigateToManagerConfig(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Finance & Balance Sheets",
        subtitle: "Site payments, entries, and financial reports",
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.blueAccent,
        gradientColors: [Colors.blueAccent, Colors.blueAccent.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Site Payment Entry",
            subtitle: "Record daily site transactions",
            icon: Icons.payments_rounded,
            color: Colors.blueAccent,
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          SubMenuItem(
            title: "Site Payment Report",
            subtitle: "Daily site-level financial reports",
            icon: Icons.receipt_long_rounded,
            color: Colors.indigoAccent,
            onTap: () => _navigateToDailyReport(context),
          ),
          SubMenuItem(
            title: "Weekly Finance Report",
            subtitle: "Weekly financial health overview",
            icon: Icons.account_balance_rounded,
            color: Colors.teal,
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Expense Management",
        subtitle: "Track organization and field expenses",
        icon: Icons.money_rounded,
        color: Colors.orange,
        gradientColors: [Colors.orange, Colors.orange.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Organization Expenses",
            subtitle: "Central operational cost monitoring",
            icon: Icons.corporate_fare_rounded,
            color: Colors.orange,
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          SubMenuItem(
            title: "Manager Expenses",
            subtitle: "Project management expenditures",
            icon: Icons.person_search_rounded,
            color: Colors.deepOrange,
            onTap: () => _navigateToManagerExpenses(context),
          ),
          SubMenuItem(
            title: "Supervisor Expenses",
            subtitle: "Daily field-level operational expenses",
            icon: Icons.engineering_rounded,
            color: Colors.amber[800]!,
            onTap: () => _navigateToSiteExpenses(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Review & Approvals",
        subtitle: "Approve schedules, materials, and incentives",
        icon: Icons.fact_check_rounded,
        color: Colors.green,
        gradientColors: [Colors.green, Colors.green.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Schedule Request Approval",
            subtitle: "Approve project work schedules",
            icon: Icons.event_available_rounded,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Material Request Approval",
            subtitle: "Authorize material procurement",
            icon: Icons.inventory_2_rounded,
            color: Colors.lightGreen[700]!,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerMaterialApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Incentive Calculation",
            subtitle: "Process performance-based rewards",
            icon: Icons.calculate_rounded,
            color: Colors.purple,
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Reports & Insights",
        subtitle: "Stock monitoring and tool analytics",
        icon: Icons.bar_chart_rounded,
        color: Colors.blueGrey,
        gradientColors: [Colors.blueGrey, Colors.blueGrey.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Advanced Financial Analytics",
            subtitle: "Detailed performance insights",
            icon: Icons.query_stats_rounded,
            color: Colors.blueGrey,
            onTap: () => _navigateToInsights(context),
          ),
          SubMenuItem(
            title: "Materials Inventory",
            subtitle: "Real-time stock monitoring",
            icon: Icons.inventory_rounded,
            color: Colors.brown,
            onTap: () => _navigateToMaterialReport(context),
          ),
          SubMenuItem(
            title: "Tools Inventory",
            subtitle: "Track field equipment usage",
            icon: Icons.construction_rounded,
            color: Colors.blue[900]!,
            onTap: () => _navigateToToolsInventory(context),
          ),
        ],
      ),
    ];

    return Column(
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildCategoryTile(context, category: category),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required _CategoryData category,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrgSubMenuScreen(
                title: category.title,
                items: category.items,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: category.gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: category.color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(category.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontSize: 17,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${category.items.length} options',
                          style: TextStyle(
                            color: category.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Navigation methods remain the same
  void _navigateToConfiguration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigAccountDashboard()),
    );
  }

  void _navigateToManagerConfig(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManagerConfigScreen()),
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

  void _navigateToOrgMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrgMenuScreen(standalone: true),
      ),
    );
  }
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<SubMenuItem> items;

  _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.items,
  });
}
