import 'dart:async';
import 'package:demo_cst/screens/site_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'config_account_dashboard.dart';
import 'org_site_payment_screen.dart';
import 'incentive_calculation.dart';
import 'insights_dashboard.dart';
import 'manager_expenses.dart';
import 'manager_site_entry_page.dart';
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
import '../utils/responsive.dart';
import 'org_sub_menu_screen.dart';
import 'org_menu_screen.dart';
import 'manager_config_screen.dart';
import 'org_subscription_page.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  _OrganizationDashboardState createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;
  String _userName = '';
  String _userRole = 'Organization';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkSubscription();
    _startSubscriptionListener();
  }

  Future<void> _loadUserData() async {
    final userData = AuthService().userData;
    setState(() {
      _userName =
          userData['org_name'] ?? userData['username'] ?? 'Organization';
      _userRole = userData['role'] ?? 'Organization';
    });
  }

  void _startSubscriptionListener() {
    _subscriptionListener = FirestoreService.subscriptionDoc.snapshots().listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          final isActive = data['isSubscriptionActive'] as bool? ?? true;
          final endDate = data['subscriptionEndDate'] as Timestamp?;
          bool isExpired = false;
          if (endDate != null)
            isExpired = DateTime.now().isAfter(
              endDate.toDate().add(const Duration(hours: 1)),
            );
          if (!isActive || isExpired) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationSubscriptionPage(),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _checkSubscription() async {
    final isValid = await AuthService().checkSubscriptionStatus();
    if (!isValid && mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OrganizationSubscriptionPage(),
        ),
      );
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return ValueListenableBuilder<String>(
                valueListenable: AppTheme.appName,
                builder: (context, appName, _) {
                  return GlassScaffold(
                    title: appName.isNotEmpty
                        ? "$appName's Dashboard"
                        : 'Organization Dashboard',
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Menu',
                        onPressed: () => _navigateToOrgMenu(context),
                      ),
                    ],
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.maxContentWidth,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                ..._buildGridSections(
                                  context,
                                  theme,
                                  constraints.maxWidth,
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildGridSections(
    BuildContext context,
    ThemeData theme,
    double availableWidth,
  ) {
    final crossAxisCount = Responsive.gridCrossAxisCount(availableWidth);
    final childAspectRatio = Responsive.gridChildAspectRatio(availableWidth);
    final hPad = Responsive.horizontalPadding(context);
    final categories = _getCategories(theme);
    List<Widget> slivers = [];

    for (var category in categories) {
      if (category.items.isEmpty) continue;

      // Section Header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [category.color, category.color.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 16),
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 11),
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${category.items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Items Grid for this section
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = category.items[index];
              return _buildGridItem(context, item);
            }, childCount: category.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: childAspectRatio,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildGridItem(BuildContext context, SubMenuItem item) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.cardColor,
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [item.color, item.color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_CategoryData> _getCategories(ThemeData theme) {
    final primary = theme.primaryColor;
    final secondary = theme.colorScheme.secondary;

    return [
      _CategoryData(
        title: "Administrative & Config",
        subtitle: "Manage accounts and system settings",
        icon: Icons.admin_panel_settings_rounded,
        color: primary,
        gradientColors: [primary, primary.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Manager Account",
            subtitle: "Configure profiles and access permissions",
            icon: Icons.admin_panel_settings_rounded,
            color: primary,
            onTap: () => _navigateToConfiguration(context),
          ),
          SubMenuItem(
            title: "Manager Config",
            subtitle: "Create and manage manager profiles",
            icon: Icons.manage_accounts_rounded,
            color: primary,
            onTap: () => _navigateToManagerConfig(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Finance & Balance Sheets",
        subtitle: "Site payments, entries, and financial reports",
        icon: Icons.account_balance_wallet_rounded,
        color: primary.withBlue(150),
        gradientColors: [
          primary.withBlue(150),
          primary.withBlue(150).withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: "Site Payment Entry",
            subtitle: "Record daily site transactions",
            icon: Icons.payments_rounded,
            color: primary.withBlue(150),
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          SubMenuItem(
            title: "Site Payment Report",
            subtitle: "Daily site-level financial reports",
            icon: Icons.receipt_long_rounded,
            color: primary.withBlue(180),
            onTap: () => _navigateToDailyReport(context),
          ),
          SubMenuItem(
            title: "Weekly Finance Report",
            subtitle: "Weekly financial health overview",
            icon: Icons.account_balance_rounded,
            color: primary.withBlue(210),
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Expense Management",
        subtitle: "Track organization and field expenses",
        icon: Icons.money_rounded,
        color: secondary,
        gradientColors: [secondary, secondary.withOpacity(0.7)],
        items: [
          SubMenuItem(
            title: "Organization Expenses",
            subtitle: "Central operational cost monitoring",
            icon: Icons.corporate_fare_rounded,
            color: secondary,
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          SubMenuItem(
            title: "Manager Expenses",
            subtitle: "Project management expenditures",
            icon: Icons.person_search_rounded,
            color: secondary.withOpacity(0.9),
            onTap: () => _navigateToManagerExpenses(context),
          ),
          SubMenuItem(
            title: "Organisation Daily Entry",
            subtitle: "Log daily project progress and expenses",
            icon: Icons.edit_note_rounded,
            color: secondary.withOpacity(0.8),
            onTap: () => _navigateToManagerDailyEntry(context),
          ),
          SubMenuItem(
            title: "Supervisor Daily Entry",
            subtitle: "Daily field-level operational expenses",
            icon: Icons.engineering_rounded,
            color: secondary.withOpacity(0.7),
            onTap: () => _navigateToSiteExpenses(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Review & Approvals",
        subtitle: "Approve schedules, materials, and incentives",
        icon: Icons.fact_check_rounded,
        color: primary.withGreen(150),
        gradientColors: [
          primary.withGreen(150),
          primary.withGreen(150).withOpacity(0.7),
        ],
        items: [
          SubMenuItem(
            title: "Schedule Request Approval",
            subtitle: "Approve project work schedules",
            icon: Icons.event_available_rounded,
            color: primary.withGreen(150),
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
            color: primary.withGreen(180),
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
            color: primary.withGreen(210),
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Reports & Insights",
        subtitle: "Stock monitoring and tool analytics",
        icon: Icons.bar_chart_rounded,
        color: primary.withOpacity(0.8),
        gradientColors: [primary.withOpacity(0.8), primary.withOpacity(0.5)],
        items: [
          SubMenuItem(
            title: "Advanced Financial Analytics",
            subtitle: "Detailed performance insights",
            icon: Icons.query_stats_rounded,
            color: primary.withOpacity(0.8),
            onTap: () => _navigateToInsights(context),
          ),
          SubMenuItem(
            title: "Materials Inventory",
            subtitle: "Real-time stock monitoring",
            icon: Icons.inventory_rounded,
            color: primary.withOpacity(0.7),
            onTap: () => _navigateToMaterialReport(context),
          ),
          SubMenuItem(
            title: "Tools Inventory",
            subtitle: "Track field equipment usage",
            icon: Icons.construction_rounded,
            color: primary.withOpacity(0.6),
            onTap: () => _navigateToToolsInventory(context),
          ),
        ],
      ),
    ];
  }

  // Navigation methods
  void _navigateToConfiguration(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ConfigAccountDashboard(showLogout: false),
    ),
  );

  void _navigateToManagerConfig(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ManagerConfigScreen()),
  );

  void _navigateToDailyReport(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => DailySitePaymentReportScreen()),
  );

  void _navigateToInsights(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => InsightsDashboard()),
  );

  void _navigateToSitePaymentEntry(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => SitePaymentScreen()),
  );

  void _navigateToSiteWeeklyFinancialReport(BuildContext context) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SiteWeeklyFinancialReports()),
      );

  void _navigateToIncentiveCaliculation(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => IncentiveCalculation()),
  );

  void _navigateToOrganizationExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => OrganizationExpenses()),
  );

  void _navigateToManagerExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ManagerExpenses()),
  );

  void _navigateToMaterialReport(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const MaterialReportPage()),
  );

  void _navigateToToolsInventory(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ToolsInventoryPage()),
  );

  void _navigateToManagerDailyEntry(BuildContext context) {
    final userData = AuthService().userData;
    final userName = userData['username'] ?? userData['org_name'] ?? 'Admin';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrganizationSiteEntry(userName: userName, userDetails: userData),
      ),
    );
  }

  void _navigateToSiteExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          const SiteEntryPage(userName: '', userDetails: {}),
    ),
  );

  void _navigateToOrgMenu(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const OrgMenuScreen(standalone: true),
    ),
  );
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

class SubMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  SubMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
