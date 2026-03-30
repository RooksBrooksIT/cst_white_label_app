import 'package:flutter/material.dart';
import 'package:demo_cst/screens/config_material_information.dart';
import 'package:demo_cst/screens/Site_Supervisor_Config.dart';
import 'package:demo_cst/screens/config_mat_sub_cat.dart';
import 'package:demo_cst/screens/config_materialavailability.dart';
import 'package:demo_cst/screens/conflig_Materials.dart';
import 'package:demo_cst/screens/config_layout_and_drawing.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/contractor_page.dart';
import 'package:demo_cst/screens/labour_screen.dart';
import 'package:demo_cst/screens/main_dashboard.dart';
import 'package:demo_cst/screens/manager_config_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';

class ConfigAccountDashboard extends StatefulWidget {
  static const routeName = '/config-dashboard';

  const ConfigAccountDashboard({super.key});

  @override
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  String _managerName = 'Manager';

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
  }

  Future<void> _fetchManagerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? name = prefs.getString('manager_name') ?? prefs.getString('org_name');
      if (name != null && name.isNotEmpty) setState(() => _managerName = name);
    } catch (e) {
      debugPrint('Error fetching manager data: $e');
    }
  }

  // Dashboard items grouped by section
  final Map<String, List<DashboardItem>> groupedItems = {
    "Project Configuration": [
      DashboardItem(
        'Project Category',
        Icons.category_rounded,
        Colors.orange,
        'Manage project categories',
      ),
      DashboardItem(
        'Project Sub Category',
        Icons.subtitles_rounded,
        Colors.purple,
        'Define project sub-categories',
      ),
      DashboardItem(
        'Project Stage',
        Icons.flag_rounded,
        Colors.red,
        'Configure project stages',
      ),
      DashboardItem(
        'Project Contract',
        Icons.assignment_rounded,
        Colors.teal,
        'Manage project contracts',
      ),
    ],
    "Material Configuration": [
      DashboardItem(
        'Material Master',
        Icons.upload_file_rounded,
        Colors.green,
        'Master list of materials',
      ),
      DashboardItem(
        'Material Sub Category',
        Icons.category_rounded,
        Colors.blue,
        'Categorize materials further',
      ),
      DashboardItem(
        'Material Config',
        Icons.build_rounded,
        Colors.deepOrange,
        'Configure material properties',
      ),
      DashboardItem(
        'Material Movements',
        Icons.toggle_on_outlined,
        Colors.deepPurple,
        'Track material transfers',
      ),
      DashboardItem(
        'Material Availability',
        Icons.build_circle_outlined,
        Colors.deepPurple,
        'Check material stock',
      ),
    ],
    "Tools Configuration": [
      DashboardItem(
        'Tools',
        Icons.handyman_rounded,
        Colors.indigo,
        'Manage tools inventory',
      ),
    ],
    "Labour Configuration": [
      DashboardItem(
        'Labour',
        Icons.engineering_rounded,
        Colors.brown,
        'Configure labour details',
      ),
    ],
    "Contractor Configuration": [
      DashboardItem(
        'Contractor',
        Icons.person_4_rounded,
        Colors.deepPurple,
        'Manage contractor information',
      ),
    ],
    "Diagrams Configuration": [
      DashboardItem(
        'Layout and Drawings',
        Icons.upload_file_rounded,
        Colors.cyan,
        'Manage project layouts and drawings',
      ),
    ],
    "Site Configuration": [
      DashboardItem(
        'Site',
        Icons.place_rounded,
        Colors.green,
        'Configure site details',
      ),
      DashboardItem(
        'Project',
        Icons.work_rounded,
        Colors.orangeAccent,
        'Manage projects',
      ),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
        'Configure supervisor accounts',
      ),
      DashboardItem(
        'Site-Supervisor Map',
        Icons.map_rounded,
        Colors.redAccent,
        'Map supervisors to sites',
      ),
      DashboardItem(
        'Manager',
        Icons.admin_panel_settings_rounded,
        Colors.indigo,
        'Configure manager accounts',
      ),
    ],
    "Tools Tracking": [
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
        'Track tool movements',
      ),
      DashboardItem(
        'Tools Inventory',
        Icons.inventory_rounded,
        Colors.pink,
        'View tools inventory',
      ),
    ],
    "Expenses": [
      DashboardItem(
        'Manager Expenses',
        Icons.account_balance_wallet_rounded,
        Colors.blue,
        'Manage manager expenses',
      ),
    ],
    "Workers Management": [
      DashboardItem(
        'Workers Configuration',
        Icons.work_rounded,
        const Color.fromARGB(255, 130, 57, 179),
        'Configure worker details',
      ),
      DashboardItem(
        'Workers Site Mapping',
        Icons.work_history,
        const Color.fromARGB(255, 243, 145, 33),
        'Map workers to sites',
      ),
      DashboardItem(
        'Workers Attendance',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
        'Manage worker attendance',
      ),
    ],
    "Vehicle Management": [
      DashboardItem(
        'Vehicle Configuration',
        Icons.fire_truck_sharp,
        Colors.red,
        'Configure vehicle details',
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        Icons.fire_truck_outlined,
        Colors.blue,
        'Configure vehicle driver details',
      ),
      DashboardItem(
        'Vehicle Details',
        Icons.directions_car_rounded,
        Colors.green,
        'View vehicle details',
      ),
      DashboardItem(
        'Vehicle Inventory',
        Icons.inventory_rounded,
        const Color.fromARGB(255, 185, 62, 223),
        'Manage vehicle inventory',
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
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => _showLogoutConfirmation(context),
          tooltip: 'Logout',
        ),
      ],
      body: _buildBody(context),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
              child: Text(
                'CANCEL',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(this.context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainDashboard(),
                  ),
                  (route) => false,
                );
              },
              child: Text(
                'LOGOUT',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
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
        Text(
          _managerName,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
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
      children: groupedItems.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(entry.key, theme),
            buildGrid(
              entry.value.map((item) {
                return _buildMenuCard(
                  context,
                  title: item.title,
                  icon: item.icon,
                  iconColor: theme.primaryColor,
                  onTap: () => _navigateToScreen(context, item.title),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
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
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
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
      'Manager': const ManagerConfigScreen(),
      'Material': MaterialScreen(),
      'Project': ProjectScreen(),
      'Labour': LabourScreen(),
      'Tools': ToolMasterPage(),
      'Tools Movement': ToolsMovementPage(),
      'Manager Expenses': const ManagerExpensesHomeScreen(),
      'Layout and Drawings': const LayoutAndDrawingsPage(),
      'Tools Inventory': const ToolsInventoryPage(),
      'Material Master': const MatlsScreen(),
      'Material Sub Category': const MatlsSubCat(),
      'Material Movements': const MaterialInfoScreen(),
      "Material Availability": const MaterialAvailability(),
      'Contractor': const ContractorPage(),
      'Contractor Entry': ContractorEntryPage(
        userName: '',
        userDetails: const {},
      ),
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
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }
  }
}

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const DashboardItem(this.title, this.icon, this.color, this.subtitle);
}
