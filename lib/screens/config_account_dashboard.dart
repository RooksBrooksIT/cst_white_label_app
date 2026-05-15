import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../widgets/glass_scaffold.dart';

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
    final colorScheme = theme.colorScheme;
    return GlassScaffold(
      title: 'Management Console',
      appBarBackgroundColor: colorScheme.primary,
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: theme.cardColor,
        elevation: 20,
        surfaceTintColor: theme.cardColor,
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.dashboard_rounded,
                    'Console',
                    true,
                    () {},
                  ),
                ),
                const SizedBox(width: 80), // Reserve space for the docked FAB
                Expanded(
                  child: _buildNavItem(
                    context,
                    Icons.support_agent_rounded,
                    'Support',
                    false,
                    () => _navigateToScreen(context, 'Support'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  // _buildQuickStats(context),
                  // const SizedBox(height: 32),
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
        onTap: () {
          if (item.title == 'Privacy Policy') {
            _launchPrivacyPolicy(context);
          } else {
            _navigateToScreen(context, item.title);
          }
        },
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
    final colorScheme = theme.colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  void _showAddOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Quick Actions",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Site',
                      'Manage construction sites',
                      Icons.location_city_rounded,
                      Colors.green,
                      () {
                        Navigator.pop(context);
                        _navigateToScreen(context, 'Site');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Project',
                      'Configure project details',
                      Icons.work_rounded,
                      Colors.orangeAccent,
                      () {
                        Navigator.pop(context);
                        _navigateToScreen(context, 'Project');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
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
      'Tools Master': ToolMasterPage(),
      'Tools Movement': ToolsMovementPage(),
      'Manager Expenses': const ManagerExpensesHomeScreen(),
      'Manager Daily Site Entry': ManagerSiteEntryPage(
        userName: _managerName,
        userDetails: AuthService().userData,
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
