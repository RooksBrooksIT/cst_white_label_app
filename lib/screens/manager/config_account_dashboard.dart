import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/screens/manager/manager_site_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:demo_cst/services/firestore_service.dart';
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
  State<ConfigAccountDashboard> createState() => _ConfigAccountDashboardState();
}

class _ConfigAccountDashboardState extends State<ConfigAccountDashboard> {
  String _managerName = 'Manager';
  String _managerDesignation = 'Manager';
  UserRole _currentUserRole = UserRole.none;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  String _searchQuery = '';

  static final Map<String, Map<String, dynamic>> _categoryMetadata = {
    "Project Management": {
      "subtitle": "Projects, site setups, and master configurations",
      "icon": Icons.assignment_rounded,
      "color": const Color(0xFF0A183D),
    },
    "Material Management": {
      "subtitle": "Central stock database, sub-categories, and transfers",
      "icon": Icons.inventory_2_rounded,
      "color": const Color(0xFF10B981),
    },
    "Site & Operations": {
      "subtitle": "Supervisor profiles, site mappings, and daily logs",
      "icon": Icons.location_city_rounded,
      "color": const Color(0xFFEA580C),
    },
    "Labour & Contractors": {
      "subtitle": "Labour setup and contractor directory",
      "icon": Icons.engineering_rounded,
      "color": const Color(0xFF7C3AED),
    },
    "Workers Management": {
      "subtitle": "Worker configuration, site mapping, and attendance logs",
      "icon": Icons.people_rounded,
      "color": const Color(0xFFF57C00),
    },
    "Vehicle Fleet": {
      "subtitle": "Fleet specifications, vehicle details, and stock inventory",
      "icon": Icons.directions_car_rounded,
      "color": const Color(0xFFEF4444),
    },
    "Tools & Equipment": {
      "subtitle": "Equipment inventory database, movements, and stock",
      "icon": Icons.handyman_rounded,
      "color": const Color(0xFF3B82F6),
    },
    "Blueprints & Expenses": {
      "subtitle": "Project blueprints, schematics, and expenditure logs",
      "icon": Icons.account_balance_wallet_rounded,
      "color": const Color(0xFF06B6D4),
    },
    "Support & Info": {
      "subtitle": "Help desk, customer support, and legal policies",
      "icon": Icons.help_outline_rounded,
      "color": const Color(0xFF14B8A6),
    },
    "Coming Soon": {
      "subtitle": "Exciting new tools and features on the way",
      "icon": Icons.sentiment_very_satisfied_rounded,
      "color": const Color(0xFFF59E0B),
      "isStatic": true,
    },
  };

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
    _currentUserRole = auth.userRole;

    if (_currentUserRole == UserRole.organization) {
      final orgName = (auth.userData['org_name'] ??
              auth.userData['username'] ??
              'Organization Administrator')
          .toString();
      if (mounted) {
        setState(() {
          _managerName = orgName;
          _managerDesignation = 'Organization Administrator';
        });
      }
      return;
    }

    if (_currentUserRole == UserRole.manager) {
      final data = auth.userData;
      String name = (data['FullName'] ??
              data['fullName'] ??
              data['UserName'] ??
              data['username'] ??
              'Manager')
          .toString();
      String desig =
          (data['Designation'] ?? data['designation'] ?? '').toString();

      if (mounted) {
        setState(() {
          _managerName = name;
          if (desig.isNotEmpty) _managerDesignation = desig;
        });
      }

      // If designation or full name wasn't cached in userData, fetch from Firestore
      try {
        final username = (data['username'] ?? data['UserName'] ?? '')
            .toString()
            .trim();
        if (username.isNotEmpty) {
          // 1. Try 'manager' collection
          final managerQuery = await FirestoreService.getCollection('manager')
              .where('UserName', isEqualTo: username)
              .limit(1)
              .get();
          if (managerQuery.docs.isNotEmpty) {
            final docData = managerQuery.docs.first.data();
            final fetchedFullName = (docData['FullName'] ??
                    docData['fullName'] ??
                    '')
                .toString()
                .trim();
            final fetchedDesig = (docData['Designation'] ??
                    docData['designation'] ??
                    '')
                .toString()
                .trim();

            if (mounted) {
              setState(() {
                if (fetchedFullName.isNotEmpty) _managerName = fetchedFullName;
                if (fetchedDesig.isNotEmpty) _managerDesignation = fetchedDesig;
              });
            }
            return;
          }

          // 2. Try 'configUsers' collection
          final configQuery = await FirestoreService.configUsers
              .where('UserName', isEqualTo: username)
              .limit(1)
              .get();
          if (configQuery.docs.isNotEmpty) {
            final docData = configQuery.docs.first.data();
            final fetchedFullName = (docData['FullName'] ??
                    docData['fullName'] ??
                    '')
                .toString()
                .trim();
            final fetchedDesig = (docData['Designation'] ??
                    docData['designation'] ??
                    '')
                .toString()
                .trim();

            if (mounted) {
              setState(() {
                if (fetchedFullName.isNotEmpty) _managerName = fetchedFullName;
                if (fetchedDesig.isNotEmpty) _managerDesignation = fetchedDesig;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching manager details: $e');
      }
    }
  }

  // Dashboard items grouped by section with clean categories & icons
  final Map<String, List<DashboardItem>> groupedItems = {
    "Project Management": [
      DashboardItem(
        'Projects Configs',
        Icons.tune_rounded,
        const Color(0xFF0A183D),
        'Manage all 5 project settings in one place',
        const Color(0xFF0A183D),
      ),
      DashboardItem(
        'Project & Site Setup',
        Icons.location_city_rounded,
        const Color(0xFF10B981),
        'Manage active construction sites',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Update Project',
        Icons.work_rounded,
        Colors.indigo,
        'Oversee project details',
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
        'Material Sub Category',
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
        'Worker Configuration',
        Icons.people_rounded,
        const Color(0xFF8E24AA),
        'Worker profiles and roles',
        const Color(0xFF8E24AA),
      ),
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
    ],
    "Coming Soon": [],
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              _currentIndex == 0
                  ? 'Management Console'
                  : _currentIndex == 1
                  ? 'Projects'
                  : _currentIndex == 2
                  ? 'Daily Site Entry'
                  : 'Manager Expenses',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkAccent,
                    Color.alphaBlend(
                      primaryColor.withValues(alpha: 0.35),
                      darkAccent,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: _currentIndex == 0
                  ? () => Navigator.pop(context)
                  : () => setState(() => _currentIndex = 0),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
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
                      color: Colors.red.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () => _showLogoutConfirmation(context),
                  tooltip: 'Logout',
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
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
                  backgroundColor: darkAccent,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkAccent,
                  Color.alphaBlend(
                    primaryColor.withValues(alpha: 0.35),
                    darkAccent,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: BottomAppBar(
              elevation: 0,
              color: Colors.transparent,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
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
          ),
          body: Align(
            alignment: Alignment.topCenter,
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
                          // Live Operational Overview Header
                          SliverToBoxAdapter(
                            child: _buildOperationalOverview(context),
                          ),
                          // Search Box & Category Filters
                          SliverToBoxAdapter(
                            child: _buildSearchAndFilterBar(context),
                          ),
                          ..._buildGridSections(context, constraints.maxWidth),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 90),
                          ),
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
      },
    );
  }

  /// Professional Header Banner displaying manager profile & status or Organizer viewing mode
  Widget _buildManagerHeaderBanner(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isOrgUser = _currentUserRole == UserRole.organization;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOrgUser
                    ? primaryColor.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: isOrgUser ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOrgUser
                      ? primaryColor.withValues(alpha: 0.08)
                      : const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOrgUser
                            ? primaryColor.withValues(alpha: 0.12)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        isOrgUser
                            ? Icons.business_center_rounded
                            : Icons.badge_rounded,
                        color:
                            isOrgUser ? primaryColor : const Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOrgUser
                                ? 'Organization Administrator'
                                : 'Operational Management Console',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOrgUser
                                  ? primaryColor
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _managerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isOrgUser && _managerDesignation.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.work_outline_rounded,
                                  size: 13,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _managerDesignation,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isOrgUser
                            ? primaryColor.withValues(alpha: 0.12)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOrgUser
                              ? primaryColor.withValues(alpha: 0.3)
                              : const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOrgUser
                                ? Icons.verified_rounded
                                : Icons.verified_user_rounded,
                            color: isOrgUser
                                ? primaryColor
                                : const Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOrgUser ? 'Organizer' : 'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOrgUser
                                  ? primaryColor
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isOrgUser) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You are viewing this page as an Organizer / Organization user with administrative access.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live Operational Stats (Live Sites, Supervisors, Total Modules)
  Widget _buildOperationalOverview(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);

    // Compute total modules count across all categories
    int totalModules = 0;
    for (var list in groupedItems.values) {
      totalModules += list.length;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 14),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.getCollection('Site').snapshots(),
        builder: (context, sitesSnapshot) {
          final liveSitesCount = sitesSnapshot.hasData
              ? sitesSnapshot.data!.docs.length
              : 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getCollection('supervisor').snapshots(),
            builder: (context, superSnapshot) {
              final supervisorsCount = superSnapshot.hasData
                  ? superSnapshot.data!.docs.length
                  : 0;

              return Row(
                children: [
                  Expanded(
                    child: _buildOverviewMetricCard(
                      context: context,
                      title: 'Live Sites',
                      value: '$liveSitesCount',
                      subtitle: 'Active On Site',
                      icon: Icons.location_city_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOverviewMetricCard(
                      context: context,
                      title: 'Supervisors',
                      value: '$supervisorsCount',
                      subtitle: 'Active Staff',
                      icon: Icons.supervisor_account_rounded,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOverviewMetricCard(
                      context: context,
                      title: 'Modules',
                      value: '$totalModules',
                      subtitle: 'Config Tools',
                      icon: Icons.grid_view_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverviewMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A183D),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Interactive Search Bar, Category Filter Chips & View Mode Toggle
  Widget _buildSearchAndFilterBar(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? theme.primaryColor.withValues(alpha: 0.6)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A183D).withValues(alpha: 0.04),
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
            fontSize: 13.5,
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search modules, tools, settings...',
            hintStyle: TextStyle(
              fontSize: 12.5,
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
    );
  }

  List<Widget> _buildGridSections(BuildContext context, double availableWidth) {
    const headerTextColor = Color(0xFF0A183D);
    final hPad = Responsive.horizontalPadding(context);
    final crossAxisCount = availableWidth >= 900
        ? 5
        : (availableWidth >= 600 ? 4 : 3);
    final childAspectRatio = availableWidth >= 600 ? 1.05 : 0.88;

    List<Widget> slivers = [];

    // Header Title: "Modules & Settings" / "Search Results"
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _searchQuery.isNotEmpty
                    ? 'Search Results'
                    : 'Management Modules',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: headerTextColor,
                  letterSpacing: -0.4,
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Text(
                    'Clear Search',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // If NO search query, render smooth 2-column Category Grid
    if (_searchQuery.isEmpty) {
      final categoryCrossAxisCount = availableWidth >= 900
          ? 4
          : (availableWidth >= 600 ? 3 : 2);
      final categoryAspectRatio = availableWidth >= 600 ? 1.55 : 1.35;
      final categoryEntries = groupedItems.entries.toList();

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: categoryCrossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: categoryAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = categoryEntries[index];
                final meta = _categoryMetadata[entry.key];
                final isStatic = meta?["isStatic"] as bool? ?? false;

                return _buildCategoryGridTile(
                  context: context,
                  sectionTitle: entry.key,
                  items: entry.value,
                  onTap: isStatic
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConsoleCategoryDetailsPage(
                                sectionTitle: entry.key,
                                items: entry.value,
                                managerName: _managerName,
                                metadata: _categoryMetadata[entry.key],
                                navigateToScreen: (title) =>
                                    _navigateToScreen(context, title),
                                launchPrivacyPolicy: () =>
                                    _launchPrivacyPolicy(context),
                              ),
                            ),
                          );
                        },
                );
              },
              childCount: categoryEntries.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Active Search Filtering
    int totalRenderedItems = 0;

    for (var entry in groupedItems.entries) {
      final sectionTitle = entry.key;
      var items = entry.value.where((item) {
        return item.title.toLowerCase().contains(_searchQuery) ||
            item.subtitle.toLowerCase().contains(_searchQuery) ||
            sectionTitle.toLowerCase().contains(_searchQuery);
      }).toList();

      if (items.isEmpty) continue;
      totalRenderedItems += items.length;

      final meta = _categoryMetadata[sectionTitle] ?? {
        "subtitle": "Management options and settings",
        "icon": items.first.icon,
      };
      final IconData categoryIcon = meta["icon"] as IconData;

      // Category Header in search results
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(categoryIcon, color: Colors.white, size: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: headerTextColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${items.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Search results grid
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildQuickAccessCard(context, items[index]),
              childCount: items.length,
            ),
          ),
        ),
      );
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
                    'No results match "$_searchQuery"',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

  /// Category Grid Tile for Management Console
  Widget _buildCategoryGridTile({
    required BuildContext context,
    required String sectionTitle,
    required List<DashboardItem> items,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final meta = _categoryMetadata[sectionTitle] ?? {
      "subtitle": "Management options and settings",
      "icon": items.isNotEmpty ? items.first.icon : Icons.sentiment_satisfied_alt_rounded,
    };

    final String subtitle = meta["subtitle"] as String;
    final IconData categoryIcon = meta["icon"] as IconData;
    final bool isStatic = meta["isStatic"] as bool? ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isStatic ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Category Icon & Option Count / Stay Tuned Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(categoryIcon, color: Colors.white, size: 21),
                      ),
                    ),
                    isStatic
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sentiment_satisfied_alt_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Stay Tuned',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${items.length} ${items.length == 1 ? "Option" : "Options"}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                // Bottom: Title & Subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Individual Quick Access Card for Management Console
  Widget _buildQuickAccessCard(BuildContext context, DashboardItem item) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final cardBg = primaryColor.withValues(alpha: 0.08);
    final iconBg = primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconBg.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: iconBg.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Circular Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconBg.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Middle & Bottom: Title, Subtitle, Chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: iconBg.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
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
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 24,
                ),
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
      'Project & Site Setup': const SiteScreen(),
      'Projects Configs': const ProjectConfigurationScreen(initialIndex: 0),
      //  'Site & Project Setup': const ProjectSetupWizard(),
      'Project Category': const ProjectCategoryScreen(),
      'Project Sub Category': const ProjectSubCategoryScreen(),
      'Project Stage': const ProjectStageConfig(),
      'Project Contract': const ProjectContractScreen(),
      'Project Status': const ProjectStatusScreen(),
      'Site': const SiteScreen(),
      'Supervisor': const SiteSupervisorConfig(),
      'Site-Supervisor Map': SiteSupervisorMapScreen(),
      'Material': MaterialScreen(),
      'Update Project': const ProjectScreen(hideAppBar: false),
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
      'Material Sub Category': const MatlsSubCat(),
      'Material Movements': const MaterialInfoScreen(),
      "Material Availability": const MaterialAvailability(),
      'Contractor': const ContractorPage(),
      'Contractor Entry': ContractorEntryPage(
        userName: '',
        userDetails: const {},
      ),
      'Material Config': MaterialScreen(),
      'Worker Configuration': const WorkersConfigPage(),
      'Workers Configuration': const WorkersConfigPage(),
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
    } else {
      _showDummyFeatureSheet(context, title);
    }
  }

  void _showDummyFeatureSheet(BuildContext context, String title) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final primaryColor = theme.primaryColor;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Demo / Sample Module',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Module Overview',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a preview of the "$title" management module. Full operational workflows and custom configurations will be enabled for your organization.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Active Records',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '12 Logs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Sync Status',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Up to date',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close Preview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      centerX - notchRadius + 2,
      0,
      centerX - notchRadius + 4,
      notchRadius * 0.92,
      centerX,
      notchRadius * 0.92,
    );
    path.cubicTo(
      centerX + notchRadius - 4,
      notchRadius * 0.92,
      centerX + notchRadius - 2,
      0,
      centerX + notchRadius + 10,
      0,
    );

    path.lineTo(w - radius, 0);
    path.arcToPoint(Offset(w, radius), radius: const Radius.circular(radius));
    path.lineTo(w, h - radius);
    path.arcToPoint(
      Offset(w - radius, h),
      radius: const Radius.circular(radius),
    );
    path.lineTo(radius, h);
    path.arcToPoint(
      Offset(0, h - radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ConsoleCategoryDetailsPage extends StatefulWidget {
  final String sectionTitle;
  final List<DashboardItem> items;
  final String managerName;
  final Map<String, dynamic>? metadata;
  final void Function(String title) navigateToScreen;
  final VoidCallback launchPrivacyPolicy;

  const ConsoleCategoryDetailsPage({
    super.key,
    required this.sectionTitle,
    required this.items,
    required this.managerName,
    this.metadata,
    required this.navigateToScreen,
    required this.launchPrivacyPolicy,
  });

  @override
  State<ConsoleCategoryDetailsPage> createState() =>
      _ConsoleCategoryDetailsPageState();
}

class _ConsoleCategoryDetailsPageState
    extends State<ConsoleCategoryDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final meta = widget.metadata ?? {
      "subtitle": "Management options and settings",
      "icon": widget.items.isNotEmpty
          ? widget.items.first.icon
          : Icons.sentiment_satisfied_alt_rounded,
    };

    final String subtitle = meta["subtitle"] as String;
    final IconData categoryIcon = meta["icon"] as IconData;

    final rawQuery = _searchQuery.trim().toLowerCase();
    final filteredItems = rawQuery.isEmpty
        ? widget.items
        : widget.items.where((item) {
            return item.title.toLowerCase().contains(rawQuery) ||
                item.subtitle.toLowerCase().contains(rawQuery);
          }).toList();

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              widget.sectionTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkAccent,
                    Color.alphaBlend(
                      primaryColor.withValues(alpha: 0.35),
                      darkAccent,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final crossAxisCount = availableWidth >= 900
                  ? 5
                  : (availableWidth >= 600 ? 4 : 3);
              final childAspectRatio = availableWidth >= 600 ? 1.05 : 0.88;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Category Info Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  categoryIcon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.sectionTitle,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.items.length} ${widget.items.length == 1 ? "Option" : "Options"}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Bar inside Category if more than 2 items
                  if (widget.items.length > 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _searchQuery.isNotEmpty
                                  ? primaryColor.withValues(alpha: 0.6)
                                  : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search in ${widget.sectionTitle}...',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.cancel_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Empty Search State
                  if (filteredItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(hPad),
                        child: Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No matching options in ${widget.sectionTitle}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    // Grid of Category Options
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: childAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredItems[index];
                            return _buildOptionCard(context, item, primaryColor);
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    DashboardItem item,
    Color primaryColor,
  ) {
    final cardBg = primaryColor.withValues(alpha: 0.08);
    final iconBg = primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconBg.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: iconBg.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (item.title == 'Privacy Policy') {
              widget.launchPrivacyPolicy();
            } else {
              widget.navigateToScreen(item.title);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Circular Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconBg.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Middle & Bottom: Title, Subtitle, Chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: iconBg.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
