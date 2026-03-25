import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:demo_cst/screens/config_material_information.dart';
import 'package:demo_cst/screens/Site_Supervisor_Config.dart';
import 'package:demo_cst/screens/config_login.dart';
import 'package:demo_cst/screens/config_mat_sub_cat.dart';
import 'package:demo_cst/screens/config_materialavailability.dart';
import 'package:demo_cst/screens/conflig_Materials.dart';
import 'package:demo_cst/screens/config_layout_and_drawing.dart';
import 'package:demo_cst/screens/contractor_entry_page.dart';
import 'package:demo_cst/screens/contractor_page.dart';
import 'package:demo_cst/screens/labour_screen.dart';
import 'package:demo_cst/screens/main_dashboard.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';
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
      DashboardItem('Project Category', Icons.category_rounded, Colors.orange, 'Manage project categories'),
      DashboardItem(
        'Project Sub Category',
        Icons.subtitles_rounded,
        Colors.purple,
        'Define project sub-categories',
      ),
      DashboardItem('Project Stage', Icons.flag_rounded, Colors.red, 'Configure project stages'),
      DashboardItem('Project Contract', Icons.assignment_rounded, Colors.teal, 'Manage project contracts'),
    ],
    "Material Configuration": [
      DashboardItem('Material Master', Icons.upload_file_rounded, Colors.green, 'Master list of materials'),
      DashboardItem(
        'Material Sub Category',
        Icons.category_rounded,
        Colors.blue,
        'Categorize materials further',
      ),
      DashboardItem('Material Config', Icons.build_rounded, Colors.deepOrange, 'Configure material properties'),
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
      DashboardItem('Tools', Icons.handyman_rounded, Colors.indigo, 'Manage tools inventory'),
    ],
    "Labour Configuration": [
      DashboardItem('Labour', Icons.engineering_rounded, Colors.brown, 'Configure labour details'),
    ],
    "Contractor Configuration": [
      DashboardItem('Contractor', Icons.person_4_rounded, Colors.deepPurple, 'Manage contractor information'),
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
      DashboardItem('Site', Icons.place_rounded, Colors.green, 'Configure site details'),
      DashboardItem('Project', Icons.work_rounded, Colors.orangeAccent, 'Manage projects'),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
        'Configure supervisor accounts',
      ),
      DashboardItem('Site-Supervisor Map', Icons.map_rounded, Colors.redAccent, 'Map supervisors to sites'),
    ],
    "Tools Tracking": [
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
        'Track tool movements',
      ),
      DashboardItem('Tools Inventory', Icons.inventory_rounded, Colors.pink, 'View tools inventory'),
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
      body: _buildBody(context),
    );
  }


  // 🟢 Show logout confirmation modal
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 20),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          actions: [
            // No Button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'No',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Yes Button
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog first
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all stored preferences for logout
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConfigLoginPage(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(context),
          const SizedBox(height: 32),
          _buildManagementSection(context),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome to",
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 18),
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Management Console",
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 28),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Configure and manage various aspects of your projects.",
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedItems.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, entry.key),
            _buildItemList(context, entry.value),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 20),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildItemList(BuildContext context, List<DashboardItem> items) {
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
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 16),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        color: Colors.white70,
                      ),
                    ),
                  ],
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
