import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/screens/org_sub_menu_screen.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/responsive.dart';
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
import 'package:demo_cst/screens/manager_expenses.dart';
import 'package:demo_cst/screens/manager_site_entry_page.dart';
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
import 'package:demo_cst/screens/workers_availability_report_page.dart';
import 'package:demo_cst/screens/contact_support_screen.dart';
import '../services/auth_service.dart';
import 'package:demo_cst/screens/project_setup_wizard.dart';

class ConfigAccountDashboard extends StatefulWidget {
  static const routeName = '/config-dashboard';

  final bool showLogout;
  const ConfigAccountDashboard({super.key, this.showLogout = true});

  @override
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  String _managerName = 'Manager';
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
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
    "Configuration": [
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
        'Material Master',
        Icons.inventory_2_rounded,
        Colors.green,
        'Central material database',
        Colors.green,
      ),
      DashboardItem(
        'Material Sub Category Master',
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
        'Material Availability',
        Icons.check_circle_rounded,
        Colors.lightGreen,
        'Real-time stock status',
        Colors.lightGreen,
      ),
      DashboardItem(
        'Labour',
        Icons.engineering_rounded,
        Colors.brown,
        'Labour management',
        Colors.brown,
      ),
      DashboardItem(
        'Workers Configuration',
        Icons.people_rounded,
        const Color(0xFF8E24AA),
        'Worker profiles and roles',
        const Color(0xFF8E24AA),
      ),
      DashboardItem(
        'Vehicle Configuration',
        Icons.settings_rounded,
        Colors.red,
        'Vehicle specifications',
        Colors.red,
      ),
    ],
    "Project Configuration": [
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
        'Material Movements',
        Icons.swap_horiz_rounded,
        Colors.deepPurple,
        'Track material transfers',
        Colors.deepPurple,
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
      DashboardItem(
        'Manager Daily Site Entry',
        Icons.edit_note_rounded,
        Colors.deepOrange,
        'Log daily site progress and expenses',
        Colors.deepOrange,
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
        'Workers Site Mapping',
        Icons.place_rounded,
        const Color(0xFFF57C00),
        'Assign workers to sites',
        const Color(0xFFF57C00),
      ),
      DashboardItem(
        'Workers Availability',
        Icons.assessment_rounded,
        Colors.indigo,
        'Site worker availability report',
        Colors.indigo,
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
    "Support & Info": [
      DashboardItem(
        'Privacy Policy',
        Icons.privacy_tip_rounded,
        Colors.blueGrey,
        'View our privacy policy',
        Colors.blueGrey,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassScaffold(
      title: _currentIndex == 0
          ? 'Management Console'
          : _currentIndex == 1
          ? 'Projects'
          : _currentIndex == 2
          ? 'Daily Site Entry'
          : 'Manager Expenses',
      onBack: _currentIndex == 0
          ? () => Navigator.pop(context)
          : () => setState(() => _currentIndex = 0),
      actions: widget.showLogout
          ? [
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => _showLogoutConfirmation(context),
                tooltip: 'Logout',
              ),
              const SizedBox(width: 8),
            ]
          : null,
      padding: EdgeInsets.zero,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectSetupWizard(),
                  ),
                );
              },
              backgroundColor: theme.primaryColor,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: theme.cardColor,
        elevation: 8,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Responsive.maxContentWidth,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  context,
                  Icons.dashboard_rounded,
                  'Dashboard',
                  _currentIndex == 0,
                  () => setState(() => _currentIndex = 0),
                ),
                _buildNavItem(
                  context,
                  Icons.work_rounded,
                  'Projects',
                  _currentIndex == 1,
                  () => setState(() => _currentIndex = 1),
                ),
                const SizedBox(width: 40), // Space for FAB
                _buildNavItem(
                  context,
                  Icons.edit_note_rounded,
                  'Daily Entry',
                  _currentIndex == 2,
                  () => setState(() => _currentIndex = 2),
                ),
                _buildNavItem(
                  context,
                  Icons.account_balance_wallet_rounded,
                  'Expenses',
                  _currentIndex == 3,
                  () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.maxContentWidth,
          ),
          child: IndexedStack(
            index: _currentIndex,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      ..._buildGridSections(context, constraints.maxWidth),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                    ],
                  );
                },
              ),
              const ProjectScreen(hideAppBar: true),
              ManagerSiteEntryPage(
                userName: _managerName,
                userDetails: AuthService().userData,
                hideAppBar: true,
              ),
              const ManagerExpenses(hideAppBar: true),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGridSections(BuildContext context, double availableWidth) {
    final crossAxisCount = Responsive.gridCrossAxisCount(availableWidth);
    final childAspectRatio = Responsive.gridChildAspectRatio(availableWidth);
    final hPad = Responsive.horizontalPadding(context);
    List<Widget> slivers = [];

    for (var entry in groupedItems.entries) {
      final sectionTitle = entry.key;
      final items = entry.value;

      if (items.isEmpty) continue;

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
                      colors: [
                        items.first.color,
                        items.first.color.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: items.first.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: items.first.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridItem(items[index]),
              childCount: items.length,
            ),
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

  Widget _buildGridItem(DashboardItem item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (item.title == 'Privacy Policy') {
            _launchPrivacyPolicy(context);
          } else {
            _navigateToScreen(context, item.title);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
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
                      colors: [item.color, item.color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.2),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: Colors.red.withValues(alpha: 0.1),
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
                    '/authSelection',
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

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final color = isActive ? theme.primaryColor : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
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
      'Material': MaterialScreen(),
      'Project': const ProjectScreen(hideAppBar: false),
      'Labour': LabourScreen(),
      'Tools Master': ToolMasterPage(),
      'Tools Movement': ToolsMovementPage(),
      'Manager Expenses': const ManagerExpenses(hideAppBar: false),
      'Manager Daily Site Entry': ManagerSiteEntryPage(
        userName: _managerName,
        userDetails: AuthService().userData,
        hideAppBar: false,
      ),
      'Layout and Drawings': const LayoutAndDrawingsPage(),
      'Tools Inventory': const ToolsInventoryPage(),
      'Material Master': const ConfigMaterialsScreen(),
      'Material Sub Category Master': const MatlsSubCat(),
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
      'Workers Availability': const WorkersAvailabilityReportPage(),
      'Workers Attendance': WorkerAttendanceSalaryPage(),
      'Vehicle Configuration': AddVehicleLogPage(),
      'Vehicle Driver Configuration': VehicleDriverConfigPage(),
      "Vehicle Details": VehicleDetailsPage(),
      "Vehicle Inventory": VehicleInventoryReportPage(),
      'Support': const ContactSupportScreen(),
    };

    final screen = routeMap[title];
    if (screen != null) {
      HapticFeedback.lightImpact();
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }
  }

  void _launchPrivacyPolicy(BuildContext context) async {
    final Uri url = Uri.parse(
      'https://sites.google.com/view/cst-whitelabel-app/home',
    );
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy')),
        );
      }
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
