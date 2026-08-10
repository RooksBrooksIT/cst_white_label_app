import 'package:demo_cst/screens/manager/manager_site_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/screens/manager/labour_screen.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/manager/config_material_information.dart';
import 'package:demo_cst/screens/manager/site_supervisor_config.dart';
import 'package:demo_cst/screens/manager/config_mat_sub_cat.dart';
import 'package:demo_cst/screens/manager/config_materialavailability.dart';
import 'package:demo_cst/screens/manager/config_materials.dart';
import 'package:demo_cst/screens/manager/config_layout_and_drawing.dart';
import 'package:demo_cst/screens/manager/contractor_entry_page.dart';
import 'package:demo_cst/screens/manager/contractor_page.dart';
import 'package:demo_cst/screens/manager/manager_expenses.dart';
import 'package:demo_cst/screens/manager/material_screen.dart';
import 'package:demo_cst/screens/manager/project_category_screen.dart';
import 'package:demo_cst/screens/manager/project_contract_screen.dart';
import 'package:demo_cst/screens/manager/project_screen.dart';
import 'package:demo_cst/screens/manager/project_stage_config.dart';
import 'package:demo_cst/screens/manager/project_sub_category_screen.dart';
import 'package:demo_cst/screens/manager/site_screen.dart';
import 'package:demo_cst/screens/manager/site_supervisor_map_screen.dart';
import 'package:demo_cst/screens/reports/tools_inventory_report.dart';
import 'package:demo_cst/screens/manager/tools_master_page.dart';
import 'package:demo_cst/screens/supervisor/tools_movement_page.dart';
import 'package:demo_cst/screens/manager/vehicle_config_page.dart';
import 'package:demo_cst/screens/manager/vehicle_details_page.dart';
import 'package:demo_cst/screens/manager/vehicle_driver_config_page.dart';
import 'package:demo_cst/screens/manager/vehicle_inventory_page.dart';
import 'package:demo_cst/screens/reports/worker_summary_report_page.dart';
import 'package:demo_cst/screens/manager/workers_config_page.dart';
import 'package:demo_cst/screens/manager/workers_site_mapping_page.dart';
import 'package:demo_cst/screens/reports/workers_availability_report_page.dart';
import 'package:demo_cst/screens/common/contact_support_screen.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';

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
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchManagerData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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

  final Map<String, List<DashboardItem>> groupedItems = {
    "Configuration": [
      DashboardItem(
        'Project Category',
        Icons.category_rounded,
        const Color(0xFFF97316),
        'Define and manage project categories',
        const Color(0xFFF97316),
      ),
      DashboardItem(
        'Project Sub Category',
        Icons.subtitles_rounded,
        const Color(0xFF8B5CF6),
        'Create detailed sub-categories',
        const Color(0xFF8B5CF6),
      ),
      DashboardItem(
        'Project Stage',
        Icons.flag_rounded,
        const Color(0xFFEF4444),
        'Configure project milestones',
        const Color(0xFFEF4444),
      ),
      DashboardItem(
        'Project Contract',
        Icons.assignment_rounded,
        const Color(0xFF06B6D4),
        'Manage legal agreements',
        const Color(0xFF06B6D4),
      ),
      DashboardItem(
        'Material Master',
        Icons.inventory_2_rounded,
        const Color(0xFF10B981),
        'Central material database',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Material Sub Category Master',
        Icons.category_rounded,
        const Color(0xFF3B82F6),
        'Organize material types',
        const Color(0xFF3B82F6),
      ),
      DashboardItem(
        'Material Config',
        Icons.settings_applications_rounded,
        const Color(0xFFF59E0B),
        'Material specifications and rules',
        const Color(0xFFF59E0B),
      ),
      DashboardItem(
        'Material Availability',
        Icons.check_circle_rounded,
        const Color(0xFF84CC16),
        'Real-time stock status monitoring',
        const Color(0xFF84CC16),
      ),
      DashboardItem(
        'Labour',
        Icons.engineering_rounded,
        const Color(0xFF8D6E63),
        'Labour management and rates',
        const Color(0xFF8D6E63),
      ),
      DashboardItem(
        'Workers Configuration',
        Icons.people_rounded,
        const Color(0xFF9333EA),
        'Worker profiles and roles',
        const Color(0xFF9333EA),
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        Icons.person_rounded,
        Colors.blue,
        'Driver profiles',
        Colors.blue,
      ),
    ],
    "Project Configuration": [
      DashboardItem(
        'Project',
        Icons.work_rounded,
        const Color(0xFFF59E0B),
        'Oversee project portfolios',
        const Color(0xFFF59E0B),
      ),
      DashboardItem(
        'Material Movements',
        Icons.swap_horiz_rounded,
        const Color(0xFF7C3AED),
        'Track material transfers between sites',
        const Color(0xFF7C3AED),
      ),
    ],
    "Site & Supervisor": [
      DashboardItem(
        'Site',
        Icons.location_city_rounded,
        const Color(0xFF10B981),
        'Manage active construction sites',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        const Color(0xFF64748B),
        'Supervisor profiles and credentials',
        const Color(0xFF64748B),
      ),
      DashboardItem(
        'Site-Supervisor Map',
        Icons.map_rounded,
        const Color(0xFFEF4444),
        'Assign supervisors to specific sites',
        const Color(0xFFEF4444),
      ),
      DashboardItem(
        'Manager Daily Site Entry',
        Icons.edit_note_rounded,
        const Color(0xFFEA580C),
        'Log daily site progress and expenses',
        const Color(0xFFEA580C),
      ),
    ],
    "Tools & Equipment": [
      DashboardItem(
        'Tools Master',
        Icons.handyman_rounded,
        const Color(0xFF4F46E5),
        'Tools inventory master database',
        const Color(0xFF4F46E5),
      ),
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        const Color(0xFFF97316),
        'Track tool assignments and transfers',
        const Color(0xFFF97316),
      ),
      DashboardItem(
        'Tools Inventory',
        Icons.inventory_rounded,
        const Color(0xFFEC4899),
        'Current equipment stock status',
        const Color(0xFFEC4899),
      ),
    ],
    "Labour & Contractor": [
      DashboardItem(
        'Contractor',
        Icons.person_4_rounded,
        const Color(0xFF7C3AED),
        'Contractor directory and agreements',
        const Color(0xFF7C3AED),
      ),
      DashboardItem(
        'Contractor Entry',
        Icons.person_add_rounded,
        const Color(0xFF8B5CF6),
        'Register new contractors',
        const Color(0xFF8B5CF6),
      ),
    ],
    "Workers Management": [
      DashboardItem(
        'Workers Site Mapping',
        Icons.place_rounded,
        const Color(0xFFF57C00),
        'Assign workers to active sites',
        const Color(0xFFF57C00),
      ),
      DashboardItem(
        'Workers Availability',
        Icons.assessment_rounded,
        const Color(0xFF4F46E5),
        'Site worker availability reports',
        const Color(0xFF4F46E5),
      ),
      DashboardItem(
        'Workers Attendance',
        Icons.fact_check_rounded,
        const Color(0xFF475569),
        'Track attendance and wages',
        const Color(0xFF475569),
      ),
    ],
    "Vehicle Fleet": [
      DashboardItem(
        'Vehicle Fleet',
        Icons.settings_rounded,
        Colors.red,
        'Vehicle specifications',
        Colors.red,
      ),
      DashboardItem(
        'Vehicle Details',
        Icons.directions_car_rounded,
        const Color(0xFF059669),
        'Fleet vehicle information',
        const Color(0xFF059669),
      ),
      DashboardItem(
        'Vehicle Inventory',
        Icons.inventory_2_rounded,
        const Color(0xFF9333EA),
        'Fleet stock and assignment status',
        const Color(0xFF9333EA),
      ),
    ],
    "Blueprints & Expenses": [
      DashboardItem(
        'Layout and Drawings',
        Icons.upload_file_rounded,
        const Color(0xFF06B6D4),
        'Project blueprints and schematics',
        const Color(0xFF06B6D4),
      ),
      DashboardItem(
        'Manager Expenses',
        Icons.account_balance_wallet_rounded,
        const Color(0xFF2563EB),
        'Track manager expenditure logs',
        const Color(0xFF2563EB),
      ),
    ],
    "Support & Info": [
      DashboardItem(
        'Privacy Policy',
        Icons.privacy_tip_rounded,
        const Color(0xFF64748B),
        'View our privacy policy',
        const Color(0xFF64748B),
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
                  color: Color(0xFF0A183D),
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
        color: AppTheme.getDarkAccent(theme.primaryColor),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.3),
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
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // Header Search & Filter Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search Input Box
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(
                                    color: Color(0xFF0A183D),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.trim().toLowerCase();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search configuration tools...',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Icon(
                                        Icons.search_rounded,
                                        color: Color(0xFF1E88E5),
                                        size: 22,
                                      ),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFF64748B),
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Filter Category Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildFilterChip('All'),
                                    ...groupedItems.keys.map((cat) => _buildFilterChip(cat)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      ..._buildListSections(context, constraints.maxWidth),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
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

  Widget _buildFilterChip(String categoryName) {
    final bool isSelected = _selectedCategory == categoryName;
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = categoryName;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? darkCardBg : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? darkCardBg : Colors.white,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: darkCardBg.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            categoryName,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF0A183D),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildListSections(BuildContext context, double availableWidth) {
    final hPad = Responsive.horizontalPadding(context);
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    List<Widget> slivers = [];

    for (var entry in groupedItems.entries) {
      final sectionTitle = entry.key;

      if (_selectedCategory != 'All' && _selectedCategory != sectionTitle) {
        continue;
      }

      var items = entry.value;

      if (_searchQuery.isNotEmpty) {
        items = items.where((item) {
          return item.title.toLowerCase().contains(_searchQuery) ||
              item.subtitle.toLowerCase().contains(_searchQuery);
        }).toList();
      }

      if (items.isEmpty) continue;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: darkCardBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: const Color(0xFF0A183D),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: darkCardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildListItem(context, item, darkCardBg),
              );
            }, childCount: items.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildGridItem(DashboardItem item) {
    final darkCardBg = AppTheme.getDarkAccent(Theme.of(context).primaryColor);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: darkCardBg,
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
            color: darkCardBg,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: darkCardBg.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFFCBD5E1),
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
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
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
    bool isActive,
    VoidCallback onTap,
  ) {
    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withValues(alpha: 0.6);
    final color = isActive ? activeColor : inactiveColor;

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
              style: TextStyle(
                color: color,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 10.5,
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
      'Vehicle Fleet': AddVehicleLogPage(),
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

class FloatingNotchedShadowPainter extends CustomPainter {
  final Color shadowColor;
  final double elevation;

  FloatingNotchedShadowPainter({
    required this.shadowColor,
    required this.elevation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = FloatingNotchedClipper();
    final path = clipper.getClip(size);

    canvas.drawShadow(path, shadowColor, elevation, true);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FloatingNotchedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    const double radius = 28.0;
    const double notchRadius = 34.0;
    final double centerX = w / 2;

    final path = Path();
    path.moveTo(radius, 0);

    path.lineTo(centerX - notchRadius - 10, 0);

    path.cubicTo(
      centerX - notchRadius + 2, 0,
      centerX - notchRadius + 4, notchRadius * 0.92,
      centerX, notchRadius * 0.92,
    );
    path.cubicTo(
      centerX + notchRadius - 4, notchRadius * 0.92,
      centerX + notchRadius - 2, 0,
      centerX + notchRadius + 10, 0,
    );

    path.lineTo(w - radius, 0);
    path.arcToPoint(Offset(w, radius), radius: const Radius.circular(radius));
    path.lineTo(w, h - radius);
    path.arcToPoint(Offset(w - radius, h), radius: const Radius.circular(radius));
    path.lineTo(radius, h);
    path.arcToPoint(Offset(0, h - radius), radius: const Radius.circular(radius));
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
