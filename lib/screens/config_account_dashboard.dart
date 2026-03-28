import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';

class ConfigAccountDashboard extends StatefulWidget {
  static const routeName = '/config-dashboard';

  const ConfigAccountDashboard({super.key});

  @override
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  // 🟢 Dashboard Items with colors
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
    return GlassScaffold(
      title: 'Management Console',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          onPressed: () => _showLogoutConfirmation(context),
          tooltip: 'Logout',
        ),
      ],
      body: _buildBody(context),
    );
  }

  // 🟢 Show logout confirmation modal
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
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainDashboard(),
                    ),
                    (route) => false,
                  );
                }
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
          _buildInfoSection(theme),
          const SizedBox(height: 12),
          _buildManagementSection(context, theme),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Management Console",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Configure and manage various aspects of your projects.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedItems.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(theme, entry.key),
            _buildItemList(context, theme, entry.value),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
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

  Widget _buildItemList(BuildContext context, ThemeData theme, List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        return AnimationConfiguration.staggeredList(
          position: items.indexOf(item),
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: _buildColorfulCard(
                context,
                theme: theme,
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                iconColor: item.color,
                onTap: () => _navigateToScreen(context, item.title),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorfulCard(
    BuildContext context, {
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
              size: 24,
            ),
          ],
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
