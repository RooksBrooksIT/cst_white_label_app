import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/screens/org_sub_menu_screen.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/screens/config_material_information.dart';
import 'package:demo_cst/screens/Site_Supervisor_Config.dart';
import 'package:demo_cst/screens/config_mat_sub_cat.dart';
import 'package:demo_cst/screens/config_materialavailability.dart';
import 'package:demo_cst/screens/config_materials.dart';
import 'package:demo_cst/screens/config_layout_and_drawing.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/contractor_page.dart';
import 'package:demo_cst/screens/labour_screen.dart';
import 'package:demo_cst/screens/manager_expenses_homescreen.dart';
import 'package:demo_cst/screens/material_screen.dart';
import 'package:demo_cst/screens/project_category_screen.dart';
import 'package:demo_cst/screens/project_contract_screen.dart';
import 'package:demo_cst/screens/project_screen.dart';
import 'package:demo_cst/screens/project_stage_config.dart';
import 'package:demo_cst/screens/project_sub_category_screen.dart';
import 'package:demo_cst/screens/site_screen.dart';
import 'package:demo_cst/screens/site_supervisor_map_screen.dart';
import 'package:demo_cst/screens/tools_inventory_report.dart';
import 'package:demo_cst/screens/tools_master_page.dart';
import 'package:demo_cst/screens/tools_movement_page.dart';
import 'package:demo_cst/screens/vehicle_config_page.dart';
import 'package:demo_cst/screens/vehicle_details_page.dart';
import 'package:demo_cst/screens/vehicle_driver_config_page.dart';
import 'package:demo_cst/screens/vehicle_inventory_page.dart';
import 'package:demo_cst/screens/worker_summary_report_page.dart';
import 'package:demo_cst/screens/workers_config_page.dart';
import 'package:demo_cst/screens/workers_site_mapping_page.dart';
import '../services/auth_service.dart';
import '../widgets/glass_scaffold.dart';

class ConfigAccountDashboard extends StatefulWidget {
  static const routeName = '/config-dashboard';

  const ConfigAccountDashboard({super.key});

  @override
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  String _managerName = 'Manager';
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
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

  Future<void> _fetchManagerData() async {
    final auth = AuthService();
    if (auth.isLoggedIn && auth.userRole == UserRole.manager) {
      final String? name =
          auth.userData['username'] ?? auth.userData['org_name'];
      if (name != null) setState(() => _managerName = name);
    }
  }

  // Dashboard items grouped by section with enhanced data
  final Map<String, List<DashboardItem>> groupedItems = {
    "Project Configuration": [
      DashboardItem(
        'Project Category',
        Icons.category_rounded,
        Colors.orange,
        'Define and manage project categories',
        Colors.orange,
      ),
      DashboardItem(
        'Project Sub Category',
        Icons.subtitles_rounded,
        Colors.purple,
        'Create detailed sub-categories',
        Colors.purple,
      ),
      DashboardItem(
        'Project Stage',
        Icons.flag_rounded,
        Colors.red,
        'Configure project milestones',
        Colors.red,
      ),
      DashboardItem(
        'Project Contract',
        Icons.assignment_rounded,
        Colors.teal,
        'Manage legal agreements',
        Colors.teal,
      ),
      DashboardItem(
        'Project',
        Icons.work_rounded,
        Colors.orangeAccent,
        'Oversee project portfolios',
        Colors.orangeAccent,
      ),
    ],
    "Material Configuration": [
      DashboardItem(
        'Material Master',
        Icons.inventory_2_rounded,
        Colors.green,
        'Central material database',
        Colors.green,
      ),
      DashboardItem(
        'Material Sub Category',
        Icons.category_rounded,
        Colors.blue,
        'Organize material types',
        Colors.blue,
      ),
      DashboardItem(
        'Material Config',
        Icons.settings_applications_rounded,
        Colors.deepOrange,
        'Material specifications',
        Colors.deepOrange,
      ),
      DashboardItem(
        'Material Movements',
        Icons.swap_horiz_rounded,
        Colors.deepPurple,
        'Track material transfers',
        Colors.deepPurple,
      ),
      DashboardItem(
        'Material Availability',
        Icons.check_circle_rounded,
        Colors.lightGreen,
        'Real-time stock status',
        Colors.lightGreen,
      ),
    ],
    "Site & Supervisor": [
      DashboardItem(
        'Site',
        Icons.location_city_rounded,
        Colors.green,
        'Manage construction sites',
        Colors.green,
      ),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
        'Supervisor profiles',
        Colors.blueGrey,
      ),
      DashboardItem(
        'Site-Supervisor Map',
        Icons.map_rounded,
        Colors.redAccent,
        'Assign supervisors to sites',
        Colors.redAccent,
      ),
    ],
    "Tools & Equipment": [
      DashboardItem(
        'Tools Master',
        Icons.handyman_rounded,
        Colors.indigo,
        'Tools inventory database',
        Colors.indigo,
      ),
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
        'Track tool assignments',
        Colors.deepOrangeAccent,
      ),
      DashboardItem(
        'Tools Inventory',
        Icons.inventory_rounded,
        Colors.pink,
        'Current stock status',
        Colors.pink,
      ),
    ],
    "Labour & Contractor": [
      DashboardItem(
        'Labour',
        Icons.engineering_rounded,
        Colors.brown,
        'Labour management',
        Colors.brown,
      ),
      DashboardItem(
        'Contractor',
        Icons.person_4_rounded,
        Colors.deepPurple,
        'Contractor profiles',
        Colors.deepPurple,
      ),
      DashboardItem(
        'Contractor Entry',
        Icons.person_add_rounded,
        Colors.deepPurpleAccent,
        'Register new contractors',
        Colors.deepPurpleAccent,
      ),
    ],
    "Workers Management": [
      DashboardItem(
        'Workers Configuration',
        Icons.people_rounded,
        const Color(0xFF8E24AA),
        'Worker profiles and roles',
        const Color(0xFF8E24AA),
      ),
      DashboardItem(
        'Workers Site Mapping',
        Icons.place_rounded,
        const Color(0xFFF57C00),
        'Assign workers to sites',
        const Color(0xFFF57C00),
      ),
      DashboardItem(
        'Workers Attendance',
        Icons.fact_check_rounded,
        Colors.blueGrey,
        'Track attendance records',
        Colors.blueGrey,
      ),
    ],
    "Vehicle Fleet": [
      DashboardItem(
        'Vehicle Configuration',
        Icons.settings_rounded,
        Colors.red,
        'Vehicle specifications',
        Colors.red,
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        Icons.person_rounded,
        Colors.blue,
        'Driver profiles',
        Colors.blue,
      ),
      DashboardItem(
        'Vehicle Details',
        Icons.directions_car_rounded,
        Colors.green,
        'Fleet information',
        Colors.green,
      ),
      DashboardItem(
        'Vehicle Inventory',
        Icons.inventory_2_rounded,
        const Color(0xFF9C27B0),
        'Fleet stock status',
        const Color(0xFF9C27B0),
      ),
    ],
    "Diagrams & Expenses": [
      DashboardItem(
        'Layout and Drawings',
        Icons.upload_file_rounded,
        Colors.cyan,
        'Project blueprints',
        Colors.cyan,
      ),
      DashboardItem(
        'Manager Expenses',
        Icons.account_balance_wallet_rounded,
        Colors.blue,
        'Expense tracking',
        Colors.blue,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: 'Management Console',
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.account_circle_rounded,
            color: Colors.white,
            size: 28,
          ),
          color: Theme.of(context).cardColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _showLogoutConfirmation(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  const Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(context),
                  const SizedBox(height: 28),
                  _buildQuickStats(context),
                  const SizedBox(height: 32),
                  _buildDashboardSections(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  "Configuration Panel",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Welcome back,",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _managerName,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: -1.0,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Configure and manage your organization settings",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final theme = Theme.of(context);
    final stats = [
      {
        'icon': Icons.category_rounded,
        'label': 'Categories',
        'value': '12',
        'color': Colors.orange,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'label': 'Materials',
        'value': '156',
        'color': Colors.green,
      },
      {
        'icon': Icons.people_rounded,
        'label': 'Workers',
        'value': '89',
        'color': Colors.blue,
      },
      {
        'icon': Icons.engineering_rounded,
        'label': 'Sites',
        'value': '8',
        'color': Colors.purple,
      },
    ];

    return SizedBox(
      height: 90,
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

  Widget _buildDashboardSections(BuildContext context) {
    return Column(
      children: groupedItems.entries.map((entry) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuint,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildCategoryCard(context, entry.key, entry.value),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    List<DashboardItem> items,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstItem = items.first;
    final color = firstItem.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openCategorySubMenu(context, title),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon with Gradient Background
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(firstItem.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${items.length} Configuration Options",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress/Status indicator hint
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'General Settings',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow Action
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCategorySubMenu(BuildContext context, String categoryName) {
    final items = groupedItems[categoryName] ?? [];
    if (items.isEmpty) return;

    _triggerHapticFeedback();

    final subMenuItems = items.map((item) {
      return SubMenuItem(
        title: item.title,
        subtitle: item.subtitle,
        icon: item.icon,
        color: item.color,
        onTap: () => _navigateToScreen(context, item.title),
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrgSubMenuScreen(title: categoryName, items: subMenuItems),
      ),
    );
  }

  void _triggerHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  void _showLogoutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: theme.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/landing',
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToScreen(BuildContext context, String title) {
    final routeMap = {
      'Project Category': const ProjectCategoryScreen(),
      'Project Sub Category': const ProjectSubCategoryScreen(),
      'Project Stage': const ProjectStageConfig(),
      'Project Contract': const ProjectContractScreen(),
      'Site': const SiteScreen(),
      'Supervisor': const SiteSupervisorConfig(),
      'Site-Supervisor Map': SiteSupervisorMapScreen(),
      'Material': MaterialScreen(),
      'Project': ProjectScreen(),
      'Labour': LabourScreen(),
      'Tools Master': ToolMasterPage(),
      'Tools Movement': ToolsMovementPage(),
      'Manager Expenses': const ManagerExpensesHomeScreen(),
      'Layout and Drawings': const LayoutAndDrawingsPage(),
      'Tools Inventory': const ToolsInventoryPage(),
      'Material Master': const ConfigMaterialsScreen(),
      'Material Sub Category': const MatlsSubCat(),
      'Material Movements': const MaterialInfoScreen(),
      "Material Availability": const MaterialAvailability(),
      'Contractor': const ContractorPage(),
      'Contractor Entry': ContractorEntryPage(
        userName: '',
        userDetails: const {},
      ),
      'Material Config': MaterialScreen(),
      'Workers Configuration': WorkersConfigPage(),
      'Workers Site Mapping': WorkerMappingPage(),
      'Workers Attendance': WorkerAttendanceSalaryPage(),
      'Vehicle Configuration': AddVehicleLogPage(),
      'Vehicle Driver Configuration': VehicleDriverConfigPage(),
      "Vehicle Details": VehicleDetailsPage(),
      "Vehicle Inventory": VehicleInventoryReportPage(),
    };

    final screen = routeMap[title];
    if (screen != null) {
      HapticFeedback.lightImpact();
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final Color gradientColor;

  const DashboardItem(
    this.title,
    this.icon,
    this.color,
    this.subtitle,
    this.gradientColor,
  );
}
