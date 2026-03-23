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
import 'package:shared_preferences/shared_preferences.dart';

class ConfigAccountDashboard extends StatefulWidget {
  static const routeName = '/config-dashboard';

  const ConfigAccountDashboard({super.key});

  @override
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  final Color primaryColor = const Color(0xFF003768);
  // Color(0xFF003768),

  // 🟢 Dashboard Items with colors
  final Map<String, List<DashboardItem>> groupedItems = {
    "Project Configuration": [
      DashboardItem('Project Category', Icons.category_rounded, Colors.orange),
      DashboardItem(
        'Project Sub Category',
        Icons.subtitles_rounded,
        Colors.purple,
      ),
      DashboardItem('Project Stage', Icons.flag_rounded, Colors.red),
      DashboardItem('Project Contract', Icons.assignment_rounded, Colors.teal),
    ],
    "Material Configuration": [
      DashboardItem('Material Master', Icons.upload_file_rounded, Colors.green),
      DashboardItem(
        'Material Sub Category',
        Icons.category_rounded,
        Colors.blue,
      ),
      DashboardItem('Material Config', Icons.build_rounded, Colors.deepOrange),
      DashboardItem(
        'Material Movements',
        Icons.toggle_on_outlined,
        Colors.deepPurple,
      ),

      DashboardItem(
        'Material Availability',
        Icons.build_circle_outlined,
        Colors.deepPurple,
      ),
    ],
    "Tools Configuration": [
      DashboardItem('Tools', Icons.handyman_rounded, Colors.indigo),
    ],
    "Labour Configuration": [
      DashboardItem('Labour', Icons.engineering_rounded, Colors.brown),
    ],
    "Contractor Configuration": [
      DashboardItem('Contractor', Icons.person_4_rounded, Colors.deepPurple),
    ],
    "Diagrams Configuration": [
      DashboardItem(
        'Layout and Drawings',
        Icons.upload_file_rounded,
        Colors.cyan,
      ),
    ],
    "Site Configuration": [
      DashboardItem('Site', Icons.place_rounded, Colors.green),
      DashboardItem('Project', Icons.work_rounded, Colors.orangeAccent),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
      ),
      DashboardItem('Site-Supervisor Map', Icons.map_rounded, Colors.redAccent),
    ],
    "Tools Tracking": [
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
      ),
      DashboardItem('Tools Inventory', Icons.inventory_rounded, Colors.pink),
    ],
    "Expenses": [
      DashboardItem(
        'Manager Expenses',
        Icons.account_balance_wallet_rounded,
        Colors.blue,
      ),
    ],
    "Workers Management": [
      DashboardItem(
        'Workers Configuration',
        Icons.work_rounded,
        const Color.fromARGB(255, 130, 57, 179),
      ),
      DashboardItem(
        'Workers Site Mapping',
        Icons.work_history,
        const Color.fromARGB(255, 243, 145, 33),
      ),
      DashboardItem(
        'Workers Attendance',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
      ),
    ],
    "Vehicle Management": [
      DashboardItem(
        'Vehicle Configuration',
        Icons.fire_truck_sharp,
        Colors.red,
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        Icons.fire_truck_outlined,
        Colors.blue,
      ),
      DashboardItem(
        'Vehicle Details',
        Icons.directions_car_rounded,
        Colors.green,
      ),
      DashboardItem(
        'Vehicle Inventory',
        Icons.inventory_rounded,
        const Color.fromARGB(255, 185, 62, 223),
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromARGB(255, 1, 127, 223), Color(0xFF003768)],
            stops: [0.0, 0.6],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(context),
          body: _buildBody(context),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        "Configuration Dashboard",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
      backgroundColor: primaryColor,
      centerTitle: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => _showLogoutConfirmation(context),
        ),
      ],
    );
  }

  // 🟢 Show logout confirmation modal
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16, color: Colors.black87),
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

                // Navigate to ConfigLoginPage, replacing current routes
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConfigLoginPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
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
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildWelcomeSection(),
        const SizedBox(height: 24),
        ...groupedItems.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(entry.key),
              _buildItemList(context, entry.value),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Configuration Dashboard",
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
        SizedBox(height: 4),
        Text(
          "Manage All Settings",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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

  Widget _buildItemList(BuildContext context, List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        return AnimationConfiguration.staggeredList(
          position: items.indexOf(item),
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: _buildColorfulCard(context, item)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorfulCard(BuildContext context, DashboardItem item) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToScreen(context, item.title),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: item.color),
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
  final IconData icon;
  final Color color;
  const DashboardItem(this.title, this.icon, this.color);
}
