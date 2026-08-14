import 'package:demo_cst/screens/manager/manager_site_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:demo_cst/screens/manager/labour_screen.dart';
import 'package:demo_cst/screens/manager/manager_expenses.dart';
import 'package:demo_cst/screens/manager/material_screen.dart';
import 'package:demo_cst/screens/manager/project_category_screen.dart';
import 'package:demo_cst/screens/manager/project_contract_screen.dart';
import 'package:demo_cst/screens/manager/project_screen.dart';
import 'package:demo_cst/screens/manager/project_stage_config.dart';
import 'package:demo_cst/screens/manager/project_sub_category_screen.dart';
import 'package:demo_cst/screens/manager/project_status_screen.dart';
import 'package:demo_cst/screens/manager/project_configuration_screen.dart';
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
  State<ConfigAccountDashboard> createState() =>
      _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  String _managerName = 'Manager';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isGridView = false;

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

  // Dashboard items grouped by section with clean categories & icons
  final Map<String, List<DashboardItem>> groupedItems = {
    "Project Configurations": [
      DashboardItem(
        'Project Configuration',
        Icons.tune_rounded,
        const Color(0xFF0A183D),
        'Manage all 5 project settings in one place',
        const Color(0xFF0A183D),
      ),
    ],
    "Project Management": [
      DashboardItem(
        'Project',
        Icons.work_rounded,
        Colors.indigo,
        'Oversee project portfolio',
        Colors.indigo,
      ),
    ],
    "Material Management": [
      DashboardItem(
        'Material Master',
        Icons.inventory_2_rounded,
        const Color(0xFF10B981),
        'Central material database',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Material Sub Category Master',
        Icons.category_outlined,
        Colors.blue,
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
        'Material Movements',
        Icons.swap_horiz_rounded,
        const Color(0xFF7C3AED),
        'Track material transfers between sites',
        const Color(0xFF7C3AED),
      ),
    ],
    "Site & Operations": [
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
    "Labour & Contractors": [
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
        'Support',
        Icons.help_outline_rounded,
        Colors.teal,
        'Get support and help',
        Colors.teal,
      ),
      DashboardItem(
        'Privacy Policy',
        Icons.privacy_tip_rounded,
        Colors.blueGrey,
        'View privacy policy',
        Colors.blueGrey,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      extendBody: true,
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
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0A183D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF0A183D),
              size: 18,
            ),
          ),
          tooltip: 'Refresh Console',
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {});
          },
        ),
        if (widget.showLogout) ...[
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 18,
              ),
            ),
            onPressed: () => _showLogoutConfirmation(context),
            tooltip: 'Logout',
          ),
        ],
        const SizedBox(width: 8),
      ],
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
              backgroundColor: const Color(0xFF0A183D),
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFF0A183D),
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
                const SizedBox(width: 40),
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
                      // Manager Header Banner
                      SliverToBoxAdapter(
                        child: _buildManagerHeaderBanner(context),
                      ),
                      // Search Box & Category Filters
                      SliverToBoxAdapter(
                        child: _buildSearchAndFilterBar(context),
                      ),
                      ..._buildGridSections(context, constraints.maxWidth),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
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

  /// Professional Header Banner displaying manager profile & status
  Widget _buildManagerHeaderBanner(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final theme = Theme.of(context);
    final darkAccent = AppTheme.getDarkAccent(theme.primaryColor);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkAccent,
              Color.alphaBlend(
                theme.primaryColor.withValues(alpha: 0.35),
                darkAccent,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: darkAccent.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Management Console',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _managerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF34D399),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Search Bar, Category Filter Chips & View Mode Toggle
  Widget _buildSearchAndFilterBar(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final theme = Theme.of(context);

    final categories = ['All', ...groupedItems.keys];

    // Compute total items for current filter
    int totalFilteredItems = 0;
    for (var entry in groupedItems.entries) {
      if (_selectedCategory == 'All' || _selectedCategory == entry.key) {
        if (_searchQuery.isEmpty) {
          totalFilteredItems += entry.value.length;
        } else {
          totalFilteredItems += entry.value
              .where((item) =>
                  item.title.toLowerCase().contains(_searchQuery) ||
                  item.subtitle.toLowerCase().contains(_searchQuery))
              .length;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box & View Mode Toggle Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A183D).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0A183D),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search modules, tools, settings...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade600,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // View mode switch button (Grid vs List)
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A183D).withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: _isGridView
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                  icon: Icon(
                    _isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: theme.primaryColor,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isGridView = !_isGridView);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(cat),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0A183D),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                    selectedColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? theme.primaryColor
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    onSelected: (selected) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Quick status indicator line
          Row(
            children: [
              Text(
                _searchQuery.isNotEmpty
                    ? 'Found $totalFilteredItems matching module(s)'
                    : 'Showing $totalFilteredItems module(s)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
              if (_selectedCategory != 'All' || _searchQuery.isNotEmpty) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = 'All';
                    });
                  },
                  child: Text(
                    'Reset Filters',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGridSections(
      BuildContext context, double availableWidth) {
    const headerTextColor = Color(0xFF0A183D);
    final hPad = Responsive.horizontalPadding(context);

    final int crossAxisCount =
        availableWidth < 600 ? 2 : availableWidth < 1024 ? 3 : 4;

    final double childAspectRatio = availableWidth < 600
        ? 1.08
        : availableWidth < 1024
            ? 1.15
            : 1.25;

    List<Widget> slivers = [];
    int totalRenderedItems = 0;

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
      totalRenderedItems += items.length;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: items.first.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: headerTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: items.first.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: items.first.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (_isGridView) {
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
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildListItem(context, items[index]),
                ),
                childCount: items.length,
              ),
            ),
          ),
        );
      }
    }

    if (totalRenderedItems == 0) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No configurations found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your search query or selecting "All" category',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildListItem(
    BuildContext context,
    DashboardItem item,
  ) {
    const cardBg = Colors.white;
    const titleColor = Color(0xFF0A183D);
    final subtitleColor = Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withValues(alpha: 0.12),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: item.color,
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

  Widget _buildGridItem(DashboardItem item) {
    const cardBg = Colors.white;
    const titleColor = Color(0xFF0A183D);
    final subtitleColor = Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
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
            borderRadius: BorderRadius.circular(20),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout from the Management Console?',
            style: theme.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
    final activeIconColor = Colors.white;
    final activeBgColor = Colors.white.withValues(alpha: 0.22);
    final inactiveColor = Colors.white.withValues(alpha: 0.65);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? activeBgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isActive ? activeIconColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeIconColor : inactiveColor,
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
    final routeMap = <String, Widget>{
      'Project Configuration': const ProjectConfigurationScreen(initialIndex: 0),
      'Project Category': const ProjectCategoryScreen(),
      'Project Sub Category': const ProjectSubCategoryScreen(),
      'Project Stage': const ProjectStageConfig(),
      'Project Contract': const ProjectContractScreen(),
      'Project Status': const ProjectStatusScreen(),
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
