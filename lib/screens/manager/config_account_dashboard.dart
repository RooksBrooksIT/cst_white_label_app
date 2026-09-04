import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

import 'package:demo_cst/screens/common/contact_support_screen.dart';
import 'package:demo_cst/screens/manager/config_layout_and_drawing.dart';
import 'package:demo_cst/screens/manager/config_material_information.dart';
import 'package:demo_cst/screens/manager/config_materialavailability.dart';
import 'package:demo_cst/screens/manager/contractor_entry_page.dart';
import 'package:demo_cst/screens/manager/contractor_page.dart';
import 'package:demo_cst/screens/manager/contractor_report_page.dart';
import 'package:demo_cst/screens/manager/labour_screen.dart';
import 'package:demo_cst/screens/manager/manager_approvals_center_page.dart';
import 'package:demo_cst/screens/manager/manager_expenses.dart';
import 'package:demo_cst/screens/manager/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/manager/manager_site_entry_page.dart';
import 'package:demo_cst/screens/manager/manager_sites_list_page.dart';
import 'package:demo_cst/screens/manager/material_screen.dart';
import 'package:demo_cst/screens/manager/project_category_screen.dart';
import 'package:demo_cst/screens/manager/project_configuration_screen.dart';
import 'package:demo_cst/screens/manager/project_contract_screen.dart';
import 'package:demo_cst/screens/manager/project_screen.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';
import 'package:demo_cst/screens/manager/project_stage_config.dart';
import 'package:demo_cst/screens/manager/project_status_screen.dart';
import 'package:demo_cst/screens/manager/project_sub_category_screen.dart';
import 'package:demo_cst/screens/manager/site_screen.dart';
import 'package:demo_cst/screens/manager/site_supervisor_config.dart';
import 'package:demo_cst/screens/manager/site_supervisor_map_screen.dart';
import 'package:demo_cst/screens/manager/tools_master_page.dart';
import 'package:demo_cst/screens/manager/vehicle_config_page.dart';
import 'package:demo_cst/screens/manager/vehicle_details_page.dart';
import 'package:demo_cst/screens/manager/vehicle_driver_config_page.dart';
import 'package:demo_cst/screens/manager/vehicle_inventory_page.dart';
import 'package:demo_cst/screens/manager/workers_config_page.dart';
import 'package:demo_cst/screens/manager/workers_site_mapping_page.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/manager/manager_notification_screen.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/screens/reports/material_report.dart';
import 'package:demo_cst/screens/reports/tools_inventory_report.dart';
import 'package:demo_cst/screens/reports/worker_summary_report_page.dart';
import 'package:demo_cst/screens/reports/workers_availability_report_page.dart';
import 'package:demo_cst/screens/supervisor/tools_movement_page.dart';

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
  final PageController _kpiPageController = PageController(
    initialPage: 400,
    viewportFraction: 0.92,
  );
  final ValueNotifier<int> _currentKpiPageNotifier = ValueNotifier<int>(0);
  int _currentIndex = 0;
  String _selectedKpiPeriod = 'Today';
  Timer? _carouselTimer;

  final TextEditingController _dashboardSearchController = TextEditingController();
  final FocusNode _dashboardSearchFocusNode = FocusNode();
  String _dashboardSearchQuery = '';
  bool _isDashboardSearchOpen = false;

  // Cached Stream handles to avoid repeated subscriptions on rebuilds
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sitesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _projectsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _siteSupervisorMapStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _materialRequestsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _siteScheduleStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _supervisorRequestsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _supervisorEntriesStream;

  static final Map<String, Map<String, dynamic>> _categoryMetadata = {
    "Blueprints & Expenses": {
      "subtitle": "Project blueprints, schematics, and expenditure logs",
      "icon": Icons.account_balance_wallet_rounded,
      "color": const Color(0xFF06B6D4),
    },
    "Materials & Tools Management": {
      "subtitle": "Materials catalogue, stocks, equipment master & movements",
      "icon": Icons.warehouse_rounded,
      "color": const Color(0xFF0D9488),
    },
    "Project Management": {
      "subtitle": "Projects, site setups, and master configurations",
      "icon": Icons.assignment_rounded,
      "color": const Color(0xFF0A183D),
    },
    "Site & Operations": {
      "subtitle": "Supervisor profiles, site mappings, and daily logs",
      "icon": Icons.location_city_rounded,
      "color": const Color(0xFFEA580C),
    },
    "Support & Info": {
      "subtitle": "Help desk, customer support, and legal policies",
      "icon": Icons.help_outline_rounded,
      "color": const Color(0xFF14B8A6),
    },
    "Vehicle Management": {
      "subtitle": "Fleet specifications, vehicle details, drivers & stock inventory",
      "icon": Icons.directions_car_rounded,
      "color": const Color(0xFFEF4444),
    },
    "Workforce Management": {
      "subtitle": "Workers, labour directory, contractor management & site mapping",
      "icon": Icons.people_rounded,
      "color": const Color(0xFFF57C00),
    },
    "Coming Soon": {
      "subtitle": "Exciting new tools and features on the way",
      "icon": Icons.sentiment_very_satisfied_rounded,
      "color": const Color(0xFFF59E0B),
      "isStatic": true,
    },
  };

  // Dashboard items grouped by section in strict alphabetical (A–Z) order
  final Map<String, List<DashboardItem>> groupedItems = {
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
    "Materials & Tools Management": [
      DashboardItem(
        'Material Availability',
        Icons.check_circle_rounded,
        const Color(0xFF84CC16),
        'Real-time stock status monitoring',
        const Color(0xFF84CC16),
      ),
      DashboardItem(
        'Material Configuration',
        Icons.inventory_2_rounded,
        const Color(0xFF10B981),
        'Centralized material catalog, subcategories & pricing',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Material Inventory',
        Icons.inventory_rounded,
        const Color(0xFF0284C7),
        'Company & site stock distribution reports',
        const Color(0xFF0284C7),
      ),
      DashboardItem(
        'Material Movements',
        Icons.swap_horiz_rounded,
        const Color(0xFF7C3AED),
        'Track material transfers between sites',
        const Color(0xFF7C3AED),
      ),
      DashboardItem(
        'Tools Inventory',
        Icons.inventory_rounded,
        Colors.pink,
        'Current stock status',
        Colors.pink,
      ),
      DashboardItem(
        'Tools Master',
        Icons.handyman_rounded,
        const Color(0xFF3B82F6),
        'Tools inventory database',
        const Color(0xFF3B82F6),
      ),
      DashboardItem(
        'Tools Movement',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
        'Track tool assignments',
        Colors.deepOrangeAccent,
      ),
    ],
    "Project Management": [
      DashboardItem(
        'Project & Site Setup',
        Icons.location_city_rounded,
        const Color(0xFF10B981),
        'Manage active construction sites',
        const Color(0xFF10B981),
      ),
      DashboardItem(
        'Projects Configs',
        Icons.tune_rounded,
        const Color(0xFF0A183D),
        'Manage all 5 project settings in one place',
        const Color(0xFF0A183D),
      ),
      DashboardItem(
        'Update Project',
        Icons.work_rounded,
        Colors.indigo,
        'Oversee project details',
        Colors.indigo,
      ),
    ],
    "Site & Operations": [
      DashboardItem(
        'Manager Daily Site Entry',
        Icons.edit_note_rounded,
        const Color(0xFFEA580C),
        'Log daily site progress and expenses',
        const Color(0xFFEA580C),
      ),
      DashboardItem(
        'Site-Supervisor Map',
        Icons.map_rounded,
        const Color(0xFFEF4444),
        'Assign supervisors to specific sites',
        const Color(0xFFEF4444),
      ),
      DashboardItem(
        'Supervisor',
        Icons.supervisor_account_rounded,
        const Color(0xFF64748B),
        'Supervisor profiles and credentials',
        const Color(0xFF64748B),
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
    "Vehicle Management": [
      DashboardItem(
        'Vehicle Details',
        Icons.directions_car_rounded,
        const Color(0xFF059669),
        'Fleet vehicle information',
        const Color(0xFF059669),
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        Icons.badge_rounded,
        const Color(0xFF2563EB),
        'Driver profiles, licenses & records',
        const Color(0xFF2563EB),
      ),
      DashboardItem(
        'Vehicle Fleet',
        Icons.settings_rounded,
        Colors.red,
        'Vehicle specifications & movement logs',
        Colors.red,
      ),
      DashboardItem(
        'Vehicle Inventory',
        Icons.inventory_2_rounded,
        const Color(0xFF9333EA),
        'Fleet stock and assignment status',
        const Color(0xFF9333EA),
      ),
    ],
    "Workforce Management": [
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
      DashboardItem(
        'Labour',
        Icons.engineering_rounded,
        Colors.brown,
        'Labour directory and wages setup',
        Colors.brown,
      ),
      DashboardItem(
        'Worker Configuration',
        Icons.people_rounded,
        const Color(0xFF8E24AA),
        'Worker profiles and roles',
        const Color(0xFF8E24AA),
      ),
      DashboardItem(
        'Workers Attendance',
        Icons.fact_check_rounded,
        const Color(0xFF475569),
        'Track attendance and wages',
        const Color(0xFF475569),
      ),
      DashboardItem(
        'Workers Availability',
        Icons.assessment_rounded,
        const Color(0xFF4F46E5),
        'Site worker availability reports',
        const Color(0xFF4F46E5),
      ),
      DashboardItem(
        'Workers Site Mapping',
        Icons.place_rounded,
        const Color(0xFFF57C00),
        'Assign workers to active sites',
        const Color(0xFFF57C00),
      ),
    ],
    "Coming Soon": [],
  };

  @override
  void initState() {
    super.initState();
    _initStreams();
    _fetchManagerData();
    _startAutoPlayCarousel();
  }

  void _initStreams() {
    _notificationsStream = NotificationService.streamForRole(role: 'manager');
    _sitesStream = FirestoreService.getCollection(
      'Site',
    ).snapshots();
    _projectsStream = FirestoreService.projects.snapshots();
    _siteSupervisorMapStream = FirestoreService.getCollection(
      'siteSupervisorMap',
    ).snapshots();
    _materialRequestsStream = FirestoreService.getCollection(
      'materialRequests',
    ).snapshots();
    _siteScheduleStream = FirestoreService.siteSupervisorProjectStageSchedule
        .snapshots();
    _supervisorRequestsStream = FirestoreService.getCollection(
      'supervisor_requests',
    ).snapshots();
    _expensesStream = FirestoreService.getCollection(
      'totalSiteExpensesPerDay',
    ).snapshots();
    _supervisorEntriesStream = FirestoreService.siteSupervisorEntries.snapshots();
  }

  void _startAutoPlayCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_kpiPageController.hasClients) return;
      _kpiPageController.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
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



  @override
  void dispose() {
    _carouselTimer?.cancel();
    _currentKpiPageNotifier.dispose();
    _scrollController.dispose();
    _kpiPageController.dispose();
    _dashboardSearchController.dispose();
    _dashboardSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final dynamicGradientColors = AppTheme.getBackgroundGradientColors(
          primaryColor,
        );

        return Theme(
          data: AppTheme.getTheme(primaryColor),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dynamicGradientColors,
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: PopScope(
              canPop: _currentIndex == 0 && !Navigator.canPop(context),
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                if (_currentIndex != 0) {
                  setState(() => _currentIndex = 0);
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
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
                        backgroundColor: primaryColor,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      )
                    : null,
                bottomNavigationBar: _buildBottomNavigationBar(context),
                body: SafeArea(
                  bottom: false,
                  child: Align(
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
                                  // 1. Top Executive Header
                                  SliverToBoxAdapter(
                                    child: _buildHeader(context, primaryColor),
                                  ),

                                  // 2. Operational KPIs Overview Carousel
                                  SliverToBoxAdapter(
                                    child: _buildKPIsCarousel(
                                      context,
                                      primaryColor,
                                      darkAccent,
                                    ),
                                  ),

                                  // 3. Management Modules / Quick Actions Section
                                  SliverToBoxAdapter(
                                    child: _buildManagementModulesSection(
                                      context,
                                      primaryColor,
                                      darkAccent,
                                      constraints.maxWidth,
                                    ),
                                  ),

                                  const SliverPadding(
                                    padding: EdgeInsets.only(bottom: 90),
                                  ),
                                ],
                              );
                            },
                          ),
                          ManagerSitesListPage(
                            initialFilter: 'All',
                            showBackButton: true,
                            onBack: () => setState(() => _currentIndex = 0),
                          ),
                          SiteScreen(
                            hideAppBar: false,
                            showBackButton: true,
                            onBack: () => setState(() => _currentIndex = 0),
                          ),
                          ManagerApprovalsCenterPage(
                            hideAppBar: false,
                            showBackButton: true,
                            onBack: () => setState(() => _currentIndex = 0),
                          ),
                          _buildMoreTab(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- 1. HEADER SECTION --------------------

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    final hPad = Responsive.horizontalPadding(context);
    final isOrgUser = _currentUserRole == UserRole.organization;
    final canGoBack = Navigator.canPop(context) || _currentIndex != 0;

    final roleLabel = isOrgUser
        ? 'Organization Admin'
        : (_managerDesignation.isNotEmpty ? _managerDesignation : 'Management Console');

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Optional back button if pushed or in non-zero tab
          if (canGoBack) ...[
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_currentIndex != 0) {
                  setState(() => _currentIndex = 0);
                } else {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ],

          // Greeting & User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _managerName.isNotEmpty ? _managerName : 'Manager',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right: Magnifier Icon, Notification Bell & Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Magnifier / Search Icon (Displayed on Management Module / Home page)
              if (_currentIndex == 0) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDashboardSearchOpen ? primaryColor : Colors.white,
                    border: Border.all(
                      color: _isDashboardSearchOpen
                          ? primaryColor
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isDashboardSearchOpen
                            ? primaryColor.withValues(alpha: 0.3)
                            : const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isDashboardSearchOpen = !_isDashboardSearchOpen;
                          if (!_isDashboardSearchOpen) {
                            _dashboardSearchController.clear();
                            _dashboardSearchQuery = '';
                          }
                        });
                        if (_isDashboardSearchOpen) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _dashboardSearchFocusNode.requestFocus();
                          });
                        }
                      },
                      child: Center(
                        child: Icon(
                          Icons.search_rounded,
                          color: _isDashboardSearchOpen
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Notification Bell with Badge
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _notificationsStream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData
                      ? snapshot.data!.docs
                          .where((d) => d.data()['isRead'] != true)
                          .length
                      : 0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0F172A,
                              ).withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ManagerNotificationScreen(),
                                ),
                              );
                            },
                            child: const Center(
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: Color(0xFF1E293B),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),

              // Profile Avatar
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrgMenuScreen(standalone: true),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        AppTheme.getDarkAccent(primaryColor),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _managerName.isNotEmpty
                          ? _managerName[0].toUpperCase()
                          : 'M',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------- 2. OPERATIONAL KPIS OVERVIEW CAROUSEL --------------------

  Widget _buildKPIsCarousel(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
  ) {
    final hPad = Responsive.horizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Filter Dropdown Row
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Operational Overview',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              // Filter Dropdown Pill
              PopupMenuButton<String>(
                initialValue: _selectedKpiPeriod,
                onSelected: (val) => setState(() => _selectedKpiPeriod = val),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedKpiPeriod,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Today', child: Text('Today')),
                  const PopupMenuItem(
                    value: 'This Week',
                    child: Text('This Week'),
                  ),
                  const PopupMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(
                    value: 'All Time',
                    child: Text('All Time'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Real-time Streams for KPIs
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sitesStream,
          builder: (context, siteSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _projectsStream,
              builder: (context, projSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _siteSupervisorMapStream,
                  builder: (context, mapSnap) {
                    final siteDocs = siteSnap.hasData
                        ? siteSnap.data!.docs
                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final projectDocs = projSnap.hasData
                        ? projSnap.data!.docs
                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final supervisorDocs = mapSnap.hasData
                        ? mapSnap.data!.docs
                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    final allSiteDocsMap = _buildUnifiedSiteDocs(
                      siteDocs: siteDocs,
                      projectDocs: projectDocs,
                      supervisorDocs: supervisorDocs,
                    );

                    int projectsInProgressCount = 0;
                    int planningCount = 0;
                    int liveSitesCount = 0;
                    int completedSitesCount = 0;
                    double totalAmountSpent = 0.0;

                    final now = DateTime.now();
                    for (var entry in allSiteDocsMap.entries) {
                      final data = entry.value;
                      final s = (data['currentStatus'] ?? data['status'] ?? 'OnProgress')
                          .toString()
                          .trim()
                          .toLowerCase();

                      final endDate = _parseFlexibleDate(
                        data['actualEndDate'] ??
                            data['plannedEndDate'] ??
                            data['endDate'] ??
                            data['expectedCompletionDate'] ??
                            data['contractEndDate'],
                      );

                      final isCompleted = s.contains('complete') ||
                          s.contains('finish') ||
                          s.contains('closed') ||
                          s.contains('done');
                      final isPlanning = !isCompleted &&
                          (s.contains('plan') ||
                              s.contains('draft') ||
                              s.contains('upcoming') ||
                              s.contains('setup'));
                      final isOnHold = !isCompleted &&
                          (s.contains('hold') ||
                              s.contains('pending') ||
                              s.contains('pause') ||
                              s.contains('suspend'));
                      final isOverdue = !isCompleted &&
                          (s.contains('delay') ||
                              s.contains('overdue') ||
                              (endDate != null &&
                                  endDate.isBefore(now) &&
                                  !isCompleted));

                      if (isCompleted) {
                        completedSitesCount++;
                      } else if (isOverdue) {
                        projectsInProgressCount++;
                      } else if (isPlanning) {
                        planningCount++;
                      } else if (isOnHold) {
                        // On hold sites
                      } else {
                        projectsInProgressCount++;
                        liveSitesCount++;
                      }

                      final sp = (data['amountSpent'] is num
                          ? (data['amountSpent'] as num).toDouble()
                          : (data['spent'] is num
                              ? (data['spent'] as num).toDouble()
                              : (double.tryParse(
                                      data['amountSpent']?.toString() ?? '') ??
                                  0.0)));
                      totalAmountSpent += sp;
                    }

                    final displayProjects = projectsInProgressCount < 10
                        ? '0$projectsInProgressCount'
                        : '$projectsInProgressCount';
                    final displayPlanning = planningCount < 10
                        ? '0$planningCount'
                        : '$planningCount';
                    final displayLive = liveSitesCount < 10
                        ? '0$liveSitesCount'
                        : '$liveSitesCount';
                    final displayCompleted = completedSitesCount < 10
                        ? '0$completedSitesCount'
                        : '$completedSitesCount';

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _materialRequestsStream,
                      builder: (context, matSnap) {
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _siteScheduleStream,
                          builder: (context, wsSnap) {
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _supervisorRequestsStream,
                              builder: (context, supSnap) {
                                int pendingApprovalsCount = 0;
                                if (matSnap.hasData) {
                                  pendingApprovalsCount += matSnap.data!.docs.where((d) {
                                    final s = (d.data()['status'] ?? 'Processing')
                                        .toString()
                                        .toLowerCase();
                                    return s.contains('pending') ||
                                        s.contains('processing');
                                  }).length;
                                }
                                if (wsSnap.hasData) {
                                  pendingApprovalsCount += wsSnap.data!.docs.where((d) {
                                    final s = (d.data()['approvalStatus'] ??
                                            d.data()['status'] ??
                                            'Pending')
                                        .toString()
                                        .toLowerCase();
                                    return s.contains('pending') ||
                                        s.contains('processing');
                                  }).length;
                                }
                                if (supSnap.hasData) {
                                  pendingApprovalsCount += supSnap.data!.docs.where((d) {
                                    final s = (d.data()['status'] ?? 'Pending')
                                        .toString()
                                        .toLowerCase();
                                    return s.contains('pending') ||
                                        s.contains('processing');
                                  }).length;
                                }

                                final displayPending = pendingApprovalsCount < 10
                                    ? '0$pendingApprovalsCount'
                                    : '$pendingApprovalsCount';

                                return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: _supervisorEntriesStream,
                                  builder: (context, entrySnap) {
                                    return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                      stream: _expensesStream,
                                      builder: (context, expSnap) {
                                        double computedExpenses = 0.0;

                                        // 1. Ingest detailed daily supervisor & site entries
                                        if (entrySnap.hasData &&
                                            entrySnap.data!.docs.isNotEmpty) {
                                          for (var doc in entrySnap.data!.docs) {
                                            final data = doc.data();
                                            double amount = 0.0;
                                            if (data['totalAmount'] is num) {
                                              amount = (data['totalAmount'] as num)
                                                  .toDouble();
                                            } else if (data['amount'] is num) {
                                              amount = (data['amount'] as num)
                                                  .toDouble();
                                            } else {
                                              amount = double.tryParse(
                                                      data['totalAmount']
                                                              ?.toString() ??
                                                          '') ??
                                                  (double.tryParse(data['amount']
                                                              ?.toString() ??
                                                          '') ??
                                                      0.0);
                                            }

                                            if (amount > 0) {
                                              final docDateStr =
                                                  (data['date'] ?? '').toString();
                                              final docDate = _parseFlexibleDate(
                                                data['updatedAt'] ??
                                                    data['createdAt'] ??
                                                    data['timestamp'] ??
                                                    docDateStr,
                                              );
                                              if (_isDateInPeriod(
                                                  docDate,
                                                  docDateStr,
                                                  _selectedKpiPeriod)) {
                                                computedExpenses += amount;
                                              }
                                            }
                                          }
                                        }

                                        // 2. Ingest totalSiteExpensesPerDay summaries
                                        if (expSnap.hasData &&
                                            expSnap.data!.docs.isNotEmpty) {
                                          for (var doc in expSnap.data!.docs) {
                                            final data = doc.data();
                                            double amount = 0.0;
                                            if (data['totalAllExpenses'] is num) {
                                              amount =
                                                  (data['totalAllExpenses'] as num)
                                                      .toDouble();
                                            } else {
                                              final sExp = (data['totalSiteExpense']
                                                      is num
                                                  ? (data['totalSiteExpense']
                                                          as num)
                                                      .toDouble()
                                                  : (double.tryParse(
                                                          data['totalSiteExpense']
                                                                  ?.toString() ??
                                                              '') ??
                                                      0.0));
                                              final mExp = (data['totalMgrExpense']
                                                      is num
                                                  ? (data['totalMgrExpense']
                                                          as num)
                                                      .toDouble()
                                                  : (double.tryParse(
                                                          data['totalMgrExpense']
                                                                  ?.toString() ??
                                                              '') ??
                                                      0.0));
                                              final oExp = (data['totalOrgExpense']
                                                      is num
                                                  ? (data['totalOrgExpense']
                                                          as num)
                                                      .toDouble()
                                                  : (double.tryParse(
                                                          data['totalOrgExpense']
                                                                  ?.toString() ??
                                                              '') ??
                                                      0.0));
                                              final cExp =
                                                  (data['totalContractorExpense']
                                                          is num
                                                      ? (data['totalContractorExpense']
                                                              as num)
                                                          .toDouble()
                                                      : (double.tryParse(data[
                                                                      'totalContractorExpense']
                                                                  ?.toString() ??
                                                              '') ??
                                                          0.0));
                                              final iExp = (data[
                                                          'totalIncentiveExpenses']
                                                      is num
                                                  ? (data['totalIncentiveExpenses']
                                                          as num)
                                                      .toDouble()
                                                  : (double.tryParse(data[
                                                                  'totalIncentiveExpenses']
                                                              ?.toString() ??
                                                          '') ??
                                                      0.0));
                                              amount = sExp +
                                                  mExp +
                                                  oExp +
                                                  cExp +
                                                  iExp;
                                            }

                                            if (amount > 0) {
                                              final docDateStr =
                                                  (data['date'] ?? '').toString();
                                              final docDate = _parseFlexibleDate(
                                                data['updatedAt'] ??
                                                    data['createdAt'] ??
                                                    data['timestamp'] ??
                                                    docDateStr,
                                              );
                                              if (_isDateInPeriod(
                                                  docDate,
                                                  docDateStr,
                                                  _selectedKpiPeriod)) {
                                                if (computedExpenses == 0.0) {
                                                  computedExpenses += amount;
                                                }
                                              }
                                            }
                                          }
                                        }

                                        if (computedExpenses == 0.0 &&
                                            _selectedKpiPeriod == 'All Time') {
                                          computedExpenses = totalAmountSpent;
                                        }



                                        // Carousel Slides (Approvals & Project Stages)
                                        final slides = [
                                          // Slide 1: Approvals & Workflow Tasks
                                          _buildApprovalsSlide(
                                            context,
                                            pendingCount: displayPending,
                                            primaryColor: primaryColor,
                                          ),

                                          // Slide 2: Project Status Breakdown
                                          _buildProjectLifecycleSlide(
                                            context,
                                            live: displayLive,
                                            inProgress: displayProjects,
                                            planning: displayPlanning,
                                            completed: displayCompleted,
                                            primaryColor: primaryColor,
                                          ),
                                        ];

                                        return Column(
                                          children: [
                                            SizedBox(
                                              height: 196,
                                              child: PageView.builder(
                                                controller: _kpiPageController,
                                                onPageChanged: (index) {
                                                  _currentKpiPageNotifier.value =
                                                      index % slides.length;
                                                  _startAutoPlayCarousel();
                                                },
                                                itemBuilder: (context, index) {
                                                  final slideIndex =
                                                      index % slides.length;
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                    child: slides[slideIndex],
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            // Modern Interactive Segmented Pill Indicator
                                            ValueListenableBuilder<int>(
                                              valueListenable:
                                                  _currentKpiPageNotifier,
                                              builder: (context, activeIndex, _) {
                                                final titles = [
                                                  'Approvals',
                                                  'Projects',
                                                ];
                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                      slides.length, (index) {
                                                    final isSelected =
                                                        activeIndex == index;
                                                    return GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback
                                                            .selectionClick();
                                                        if (_kpiPageController
                                                            .hasClients) {
                                                          final currentTotalPage =
                                                              (_kpiPageController
                                                                          .page ??
                                                                      400)
                                                                  .round();
                                                          final currentMod =
                                                              currentTotalPage %
                                                                  slides.length;
                                                          final targetPage =
                                                              currentTotalPage +
                                                                  (index -
                                                                      currentMod);
                                                          _kpiPageController
                                                              .animateToPage(
                                                            targetPage,
                                                            duration: const Duration(
                                                                milliseconds: 450),
                                                            curve: Curves
                                                                .easeInOutCubic,
                                                          );
                                                        }
                                                        _startAutoPlayCarousel();
                                                      },
                                                      child: AnimatedContainer(
                                                        duration: const Duration(
                                                            milliseconds: 280),
                                                        curve: Curves.easeOutCubic,
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 3),
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                          horizontal: isSelected
                                                              ? 12
                                                              : 6,
                                                          vertical: 5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? primaryColor
                                                              : Colors.white
                                                                  .withValues(
                                                                      alpha: 0.6),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? primaryColor
                                                                : const Color(
                                                                    0xFFE2E8F0),
                                                            width: 1,
                                                          ),
                                                          boxShadow: isSelected
                                                              ? [
                                                                  BoxShadow(
                                                                    color: primaryColor
                                                                        .withValues(
                                                                            alpha:
                                                                                0.25),
                                                                    blurRadius: 6,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 6,
                                                              height: 6,
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: isSelected
                                                                    ? Colors.white
                                                                    : const Color(
                                                                        0xFF94A3B8),
                                                              ),
                                                            ),
                                                            if (isSelected) ...[
                                                              const SizedBox(
                                                                  width: 5),
                                                              Text(
                                                                titles[index],
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  letterSpacing:
                                                                      0.2,
                                                                ),
                                                             ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Slide 1: Workflow Approvals
  Widget _buildApprovalsSlide(
    BuildContext context, {
    required String pendingCount,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerMaterialApprovalScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Workflow Approvals',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle Info
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFEF3C7),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      pendingCount,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action Required',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Supervisor & site material requests are awaiting manager authorization.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Alert Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notification_important_rounded,
                    color: Color(0xFFD97706),
                    size: 13,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Prompt approvals keep site schedules on track',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
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

  // Slide 2: Project Lifecycle Breakdown Slide
  Widget _buildProjectLifecycleSlide(
    BuildContext context, {
    required String live,
    required String inProgress,
    required String planning,
    required String completed,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: Color(0xFF059669),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Project Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _navigateToSitesList(context, 'All'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 11,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Status Pillars
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildLifecycleStatusTile(
                    title: 'Live',
                    count: live,
                    icon: Icons.sensors_rounded,
                    accentColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    borderColor: const Color(0xFFA7F3D0),
                    onTap: () => _navigateToSitesList(context, 'Live'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildLifecycleStatusTile(
                    title: 'Active',
                    count: inProgress,
                    icon: Icons.engineering_rounded,
                    accentColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    onTap: () => _navigateToSitesList(context, 'In Progress'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildLifecycleStatusTile(
                    title: 'Planning',
                    count: planning,
                    icon: Icons.architecture_rounded,
                    accentColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    onTap: () => _navigateToSitesList(context, 'Planning'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildLifecycleStatusTile(
                    title: 'Done',
                    count: completed,
                    icon: Icons.task_alt_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                    borderColor: const Color(0xFFDDD6FE),
                    onTap: () => _navigateToSitesList(context, 'Completed'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleStatusTile({
    required String title,
    required String count,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(child: Icon(icon, color: accentColor, size: 17)),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- 3. MANAGEMENT MODULES & ACTIONS SECTION --------------------

  Widget _buildManagementModulesSection(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
    double availableWidth,
  ) {
    final hPad = Responsive.horizontalPadding(context);

    final crossAxisCount = availableWidth >= 900
        ? 4
        : (availableWidth >= 600 ? 3 : 2);
    final childAspectRatio = availableWidth >= 600 ? 1.25 : 1.16;

    final categoryEntries = groupedItems.entries.toList()
      ..sort((a, b) {
        final isStaticA =
            _categoryMetadata[a.key]?["isStatic"] as bool? ?? false;
        final isStaticB =
            _categoryMetadata[b.key]?["isStatic"] as bool? ?? false;
        if (isStaticA != isStaticB) {
          return isStaticA ? 1 : -1;
        }
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    final isSearching = _dashboardSearchQuery.isNotEmpty;
    final filteredCategoryEntries = categoryEntries.where((entry) {
      if (!isSearching) return true;
      if (entry.key.toLowerCase().contains(_dashboardSearchQuery)) return true;
      final meta = _categoryMetadata[entry.key];
      final subtitle = meta?["subtitle"] as String? ?? '';
      if (subtitle.toLowerCase().contains(_dashboardSearchQuery)) return true;
      for (var item in entry.value) {
        if (item.title.toLowerCase().contains(_dashboardSearchQuery) ||
            item.subtitle.toLowerCase().contains(_dashboardSearchQuery)) {
          return true;
        }
      }
      return false;
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header: Brand Indicator Bar + Title + Shortcuts Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSearching ? 'Search Results' : 'Management Modules',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSearching
                          ? Icons.search_rounded
                          : Icons.dashboard_customize_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isSearching
                          ? '${filteredCategoryEntries.length} Found'
                          : '${categoryEntries.length} Categories',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Expandable Search Bar under Management Modules Header
          if (_isDashboardSearchOpen) ...[
            const SizedBox(height: 12),
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _dashboardSearchQuery.isNotEmpty
                      ? primaryColor.withValues(alpha: 0.6)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _dashboardSearchController,
                focusNode: _dashboardSearchFocusNode,
                autofocus: true,
                onChanged: (val) {
                  setState(() {
                    _dashboardSearchQuery = val.trim().toLowerCase();
                  });
                },
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search modules, materials, tools, sites...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_dashboardSearchQuery.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                          onPressed: () {
                            _dashboardSearchController.clear();
                            setState(() => _dashboardSearchQuery = '');
                          },
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                        tooltip: 'Close search',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isDashboardSearchOpen = false;
                            _dashboardSearchController.clear();
                            _dashboardSearchQuery = '';
                          });
                        },
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 2-column Grid of Executive Category Action Cards
          if (filteredCategoryEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 38,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No module matches "$_dashboardSearchQuery"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategoryEntries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final entry = filteredCategoryEntries[index];
              final meta = _categoryMetadata[entry.key] ?? {
                "subtitle": "Management options and settings",
                "icon": entry.value.isNotEmpty
                    ? entry.value.first.icon
                    : Icons.sentiment_satisfied_alt_rounded,
                "color": primaryColor,
              };
              final isStatic = meta["isStatic"] as bool? ?? false;
              final IconData categoryIcon = meta["icon"] as IconData;
              final String subtitle = meta["subtitle"] as String;
              final Color accentColor =
                  (meta["color"] as Color?) ?? primaryColor;

              return _buildConstructionActionCard(
                title: entry.key,
                subtitle: isStatic
                    ? subtitle
                    : '${entry.value.length} options • $subtitle',
                icon: categoryIcon,
                accentColor: accentColor,
                count: isStatic ? null : entry.value.length,
                isStatic: isStatic,
                onTap: isStatic
                    ? () {}
                    : () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConsoleCategoryDetailsPage(
                              sectionTitle: entry.key,
                              items: entry.value,
                              managerName: _managerName,
                              metadata: meta,
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
          ),
        ],
      ),
    );
  }

  // Executive Construction Action Card with Modern Bento Glassmorphic Design
  Widget _buildConstructionActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isStatic = false,
    int? count,
  }) {
    return InkWell(
      onTap: isStatic
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color.alphaBlend(
                accentColor.withValues(alpha: 0.04),
                Colors.white,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Vibrant Colored Solid Gradient Icon + Modern Count/Action Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Prominent Vibrant Icon Badge with Drop Shadow
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor,
                        Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.15),
                          accentColor,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                ),

                // Top-Right Pill Badge
                if (isStatic)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFEF3C7)),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.16),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count != null) ...[
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 8.5,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Bottom Block: Bold Title + Clean Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- 4. MORE TAB & BOTTOM BAR --------------------

  Widget _buildBottomNavigationBar(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    darkAccent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.38),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: _currentIndex == 0
                        ? Icons.home_rounded
                        : Icons.home_outlined,
                    label: 'Home',
                    primaryColor: primaryColor,
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _buildNavItem(
                    icon: _currentIndex == 1
                        ? Icons.assignment_rounded
                        : Icons.assignment_outlined,
                    label: 'Sites',
                    primaryColor: primaryColor,
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _buildNavItem(
                    icon: _currentIndex == 2
                        ? Icons.architecture_rounded
                        : Icons.architecture_outlined,
                    label: 'Project',
                    primaryColor: primaryColor,
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _buildNavItem(
                    icon: _currentIndex == 3
                        ? Icons.fact_check_rounded
                        : Icons.fact_check_outlined,
                    label: 'Approvals',
                    primaryColor: primaryColor,
                    isSelected: _currentIndex == 3,
                    onTap: () => setState(() => _currentIndex = 3),
                  ),
                  _buildNavItem(
                    icon: _currentIndex == 4
                        ? Icons.grid_view_rounded
                        : Icons.menu_rounded,
                    label: 'More',
                    primaryColor: primaryColor,
                    isSelected: _currentIndex == 4,
                    onTap: () => setState(() => _currentIndex = 4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required Color primaryColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? primaryColor
                  : Colors.white.withValues(alpha: 0.85),
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.9),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTab(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final primaryColor = AppTheme.primaryColor.value;

    final List<Map<String, dynamic>> sections = [
      {
        'title': 'Management & Approvals',
        'tag': 'Operations',
        'icon': Icons.admin_panel_settings_rounded,
        'items': [
          {
            'title': 'Material Approvals',
            'subtitle': 'Review supervisor material requests',
            'icon': Icons.fact_check_rounded,
            'color': const Color(0xFF10B981),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagerMaterialApprovalScreen(),
                  ),
                ),
          },
          {
            'title': 'Supervisor Setup',
            'subtitle': 'Manage supervisors and access permissions',
            'icon': Icons.badge_rounded,
            'color': const Color(0xFF6366F1),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SiteSupervisorConfig(),
                  ),
                ),
          },
          {
            'title': 'Site-Supervisor Map',
            'subtitle': 'Assign supervisors to active sites',
            'icon': Icons.map_rounded,
            'color': const Color(0xFFEC4899),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteSupervisorMapScreen(),
                  ),
                ),
          },
          {
            'title': 'New Project Setup',
            'subtitle': 'Create new sites, clients, and blueprints',
            'icon': Icons.add_business_rounded,
            'color': const Color(0xFF0284C7),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProjectSetupWizard(),
                  ),
                ),
          },
        ],
      },
      {
        'title': 'Inventory & Resources',
        'tag': 'Logistics',
        'icon': Icons.inventory_2_rounded,
        'items': [
          {
            'title': 'Material Config',
            'subtitle': 'Central material catalogue & stocks',
            'icon': Icons.inventory_2_rounded,
            'color': const Color(0xFF059669),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaterialScreen(),
                  ),
                ),
          },
          {
            'title': 'Tools Master',
            'subtitle': 'Equipment catalog and asset IDs',
            'icon': Icons.handyman_rounded,
            'color': const Color(0xFF3B82F6),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ToolMasterPage(),
                  ),
                ),
          },
          {
            'title': 'Tools Movement',
            'subtitle': 'Track tool transfers between sites',
            'icon': Icons.sync_alt_rounded,
            'color': const Color(0xFF8B5CF6),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ToolsMovementPage(),
                  ),
                ),
          },
          {
            'title': 'Labour Directory',
            'subtitle': 'Labour profiles & contractor setups',
            'icon': Icons.engineering_rounded,
            'color': const Color(0xFFF59E0B),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LabourScreen(),
                  ),
                ),
          },
          {
            'title': 'Workers Config',
            'subtitle': 'Workers directory & site allocations',
            'icon': Icons.groups_rounded,
            'color': const Color(0xFFEA580C),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkersConfigPage(),
                  ),
                ),
          },
          {
            'title': 'Vehicle Fleet',
            'subtitle': 'Vehicles, drivers & maintenance logs',
            'icon': Icons.directions_car_rounded,
            'color': const Color(0xFFEF4444),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VehicleDetailsPage(),
                  ),
                ),
          },
        ],
      },
      {
        'title': 'Configurations & Settings',
        'tag': 'System',
        'icon': Icons.tune_rounded,
        'items': [
          {
            'title': 'Master Configs',
            'subtitle': 'Project categories, stages & contracts',
            'icon': Icons.tune_rounded,
            'color': const Color(0xFF475569),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ProjectConfigurationScreen(initialIndex: 0),
                  ),
                ),
          },
          {
            'title': 'Contractor Reports',
            'subtitle': 'Export contractor expense logs & PDFs',
            'icon': Icons.picture_as_pdf_rounded,
            'color': const Color(0xFFDC2626),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContractorReportPage(),
                  ),
                ),
          },
          if (_currentUserRole == UserRole.organization)
            {
              'title': 'Organization Portal',
              'subtitle': 'Switch to master organization hub',
              'icon': Icons.admin_panel_settings_rounded,
              'color': const Color(0xFF0F172A),
              'action': () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrgMenuScreen(standalone: true),
                    ),
                  ),
            },
          {
            'title': 'Contact Support',
            'subtitle': 'Get technical assistance or report issues',
            'icon': Icons.support_agent_rounded,
            'color': const Color(0xFF0D9488),
            'action': () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                ),
          },
        ],
      },
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 115),
      physics: const BouncingScrollPhysics(),
      children: [
        // Executive Profile Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          AppTheme.getDarkAccent(primaryColor),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _managerName.isNotEmpty
                            ? _managerName.substring(0, 1).toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _managerName,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _managerDesignation,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showLogout)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLogoutConfirmation(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Operations Hub',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Workspace Desk',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bento Sections
        ...sections.map((section) {
          final items = section['items'] as List<Map<String, dynamic>>;
          final title = section['title'] as String;
          final tag = section['tag'] as String;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTwoCol = constraints.maxWidth >= 340;
                  final itemWidth = isTwoCol
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items.map((item) {
                      final color = item['color'] as Color;
                      final action = item['action'] as VoidCallback?;

                      return SizedBox(
                        width: itemWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.07),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                action?.call();
                              },
                              borderRadius: BorderRadius.circular(18),
                              splashColor: color.withValues(alpha: 0.1),
                              highlightColor: color.withValues(alpha: 0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                color.withValues(alpha: 0.18),
                                                color.withValues(alpha: 0.08),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: color.withValues(alpha: 0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            item['icon'] as IconData,
                                            color: color,
                                            size: 20,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 13,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      item['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item['subtitle'] as String,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          );
        }),
      ],
    );
  }

  // -------------------- 5. NAVIGATION & ACTIONS --------------------

  void _navigateToSitesList(BuildContext context, [String filter = 'All']) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerSitesListPage(initialFilter: filter),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, String title) {
    final routeMap = <String, Widget>{
      'Project & Site Setup': const SiteScreen(),
      'Projects Configs': const ProjectConfigurationScreen(initialIndex: 0),
      'Project Category': const ProjectCategoryScreen(),
      'Project Sub Category': const ProjectSubCategoryScreen(),
      'Project Stage': const ProjectStageConfig(),
      'Project Contract': const ProjectContractScreen(),
      'Project Status': const ProjectStatusScreen(),
      'Site': const SiteScreen(),
      'Supervisor': const SiteSupervisorConfig(),
      'Site-Supervisor Map': SiteSupervisorMapScreen(),
      'Material': const MaterialScreen(),
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
      'Material Configuration': const MaterialScreen(),
      'Material Master': const MaterialScreen(),
      'Material Sub Category': const MaterialScreen(),
      'Material Movements': const MaterialInfoScreen(),
      'Material Inventory': const MaterialReportPage(),
      "Material Availability": const MaterialAvailability(),
      'Contractor': const ContractorPage(),
      'Contractor Entry': ContractorEntryPage(
        userName: '',
        userDetails: const {},
      ),
      'Material Config': const MaterialScreen(),
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
                    '/landing',
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

  Map<String, Map<String, dynamic>> _buildUnifiedSiteDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> projectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> supervisorDocs,
  }) {
    final unifiedMap = <String, Map<String, dynamic>>{};

    String? findMatchingKey(String siteId, String docId, String siteName) {
      final cleanSiteId = siteId.trim().toLowerCase();
      final cleanDocId = docId.trim().toLowerCase();
      final cleanName = siteName.trim().toLowerCase();

      for (var key in unifiedMap.keys) {
        final k = key.trim().toLowerCase();
        final data = unifiedMap[key]!;
        final sId = (data['siteId'] ?? '').toString().trim().toLowerCase();
        final sName = (data['siteName'] ?? data['projectName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (k == cleanDocId || k == cleanSiteId) {
          return key;
        }
        if (cleanSiteId.isNotEmpty &&
            (sId == cleanSiteId ||
                k.startsWith(cleanSiteId) ||
                cleanDocId.startsWith(sId))) {
          return key;
        }
        if (cleanDocId.isNotEmpty &&
            (cleanDocId == k || cleanDocId.contains(k) || k.contains(cleanDocId))) {
          return key;
        }
        if (cleanName.isNotEmpty && sName.isNotEmpty && cleanName == sName) {
          return key;
        }
      }
      return null;
    }

    // 1. Ingest Site collection docs
    for (var doc in siteDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['docId'] = doc.id;
      final sId = (data['siteId'] ?? '').toString();
      final sName = (data['siteName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      if (existingKey != null) {
        unifiedMap[existingKey]!.addAll(data);
      } else {
        unifiedMap[doc.id] = data;
      }
    }

    // 2. Ingest / Merge projects collection docs
    for (var doc in projectDocs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['projectDocId'] = doc.id;
      final sId = (data['siteId'] ?? data['site'] ?? '').toString();
      final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      if (existingKey != null) {
        data.forEach((k, v) {
          if (v != null) {
            unifiedMap[existingKey]![k] = v;
          }
        });
      } else {
        unifiedMap[sId.isNotEmpty ? sId : doc.id] = data;
      }
    }

    // 3. Ingest / Merge siteSupervisorMap collection docs
    for (var doc in supervisorDocs) {
      final data = doc.data();
      final sId = (data['siteId'] ?? data['site'] ?? '').toString();
      final sName = (data['siteName'] ?? data['projectName'] ?? '').toString();
      final existingKey = findMatchingKey(sId, doc.id, sName);
      final target = existingKey != null ? unifiedMap[existingKey] : null;

      if (target != null) {
        final sSupervisor = data['supervisor'] ?? data['supervisorName'];
        if (sSupervisor != null && target['supervisor'] == null) {
          target['supervisor'] = sSupervisor;
        }
        if (data['amountSpent'] != null && target['amountSpent'] == null) {
          target['amountSpent'] = data['amountSpent'];
        }
      }
    }

    return unifiedMap;
  }

  DateTime? _parseFlexibleDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.trim().isNotEmpty) {
      final s = val.trim();
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
      try {
        return DateFormat('yyyy-MM-dd').parseLoose(s);
      } catch (_) {}
      try {
        return DateFormat('dd-MM-yyyy').parseLoose(s);
      } catch (_) {}
      try {
        return DateFormat('dd/MM/yyyy').parseLoose(s);
      } catch (_) {}
      try {
        return DateFormat('d-M-yyyy').parseLoose(s);
      } catch (_) {}
      try {
        return DateFormat('d/M/yyyy').parseLoose(s);
      } catch (_) {}
    }
    return null;
  }

  bool _isDateInPeriod(DateTime? docDate, String docDateStr, String period) {
    final now = DateTime.now();
    final todayStr1 = DateFormat('yyyy-MM-dd').format(now);
    final todayStr2 = DateFormat('dd-MM-yyyy').format(now);
    final todayStr3 = DateFormat('d-M-yyyy').format(now);
    final todayStr4 = DateFormat('dd/MM/yyyy').format(now);
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    DateTime? effectiveDate = docDate ?? _parseFlexibleDate(docDateStr);

    if (period == 'Today') {
      if (docDateStr == todayStr1 ||
          docDateStr == todayStr2 ||
          docDateStr == todayStr3 ||
          docDateStr == todayStr4) {
        return true;
      }
      if (effectiveDate != null) {
        return effectiveDate.year == now.year &&
            effectiveDate.month == now.month &&
            effectiveDate.day == now.day;
      }
      return false;
    } else if (period == 'This Week') {
      if (effectiveDate != null) {
        return effectiveDate
            .isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
      }
      return true;
    } else if (period == 'This Month') {
      if (effectiveDate != null) {
        return effectiveDate
            .isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
      }
      return true;
    }
    return true; // 'All Time'
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

// -------------------- CATEGORY DETAILS PAGE --------------------

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
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_isSearchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
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
    final filteredItems = (rawQuery.isEmpty
        ? List<DashboardItem>.from(widget.items)
        : widget.items.where((item) {
            return item.title.toLowerCase().contains(rawQuery) ||
                item.subtitle.toLowerCase().contains(rawQuery);
          }).toList())
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final dynamicGradientColors =
            AppTheme.getBackgroundGradientColors(primaryColor);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dynamicGradientColors,
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: _isSearchExpanded
                  ? Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Search in ${widget.sectionTitle}...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    )
                  : Text(
                      widget.sectionTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
              centerTitle: !_isSearchExpanded,
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
                onPressed: () {
                  if (_isSearchExpanded) {
                    setState(() {
                      _isSearchExpanded = false;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              actions: [
                if (!_isSearchExpanded)
                  IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Search options',
                    onPressed: _toggleSearch,
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Close search',
                    onPressed: _toggleSearch,
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final crossAxisCount = availableWidth >= 900
                    ? 4
                    : (availableWidth >= 600 ? 3 : 2);
                final childAspectRatio = availableWidth >= 600 ? 1.25 : 1.16;

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
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.04),
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
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primaryColor.withValues(alpha: 0.16),
                                      primaryColor.withValues(alpha: 0.07),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.24),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    categoryIcon,
                                    color: primaryColor,
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
                                        color: Color(0xFF0F172A),
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
                                  '${filteredItems.length} ${filteredItems.length == 1 ? "Option" : "Options"}',
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

                    if (filteredItems.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 48,
                            horizontal: 24,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A)
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No options found matching "$_searchQuery"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try searching with different keywords.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      // 2-column Grid of Executive Item Action Cards
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 30),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: childAspectRatio,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = filteredItems[index];
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (item.title == 'Privacy Policy') {
                                    widget.launchPrivacyPolicy();
                                  } else {
                                    widget.navigateToScreen(item.title);
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Color.alphaBlend(
                                          item.color.withValues(alpha: 0.04),
                                          Colors.white,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: item.color.withValues(alpha: 0.16),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A)
                                            .withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: item.color.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Top Row: Vibrant Colored Solid Gradient Icon + Arrow Pill
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  item.color,
                                                  Color.alphaBlend(
                                                    Colors.black
                                                        .withValues(alpha: 0.15),
                                                    item.color,
                                                  ),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: item.color
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                item.icon,
                                                color: Colors.white,
                                                size: 21,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: item.color
                                                  .withValues(alpha: 0.09),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: item.color
                                                    .withValues(alpha: 0.16),
                                                width: 1,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 8.5,
                                              color: item.color,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Bottom Text
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.subtitle,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: filteredItems.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
