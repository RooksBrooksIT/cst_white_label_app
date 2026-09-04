import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/organization/org_site_payment_menu_page.dart';
import 'package:demo_cst/screens/organization/org_supervisor_in_site_page.dart';
import 'package:demo_cst/screens/organization/organization_expenses.dart';
import 'package:demo_cst/screens/organization/org_approvals_menu_page.dart';
import 'package:demo_cst/screens/organization/org_materials_tools_inventory_page.dart';
import 'package:demo_cst/screens/organization/org_notification_page.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/organization/org_sites_list_page.dart';
import 'package:demo_cst/screens/manager/manager_config_screen.dart';
import 'package:demo_cst/widgets/bottom_nav.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  State<OrganizationDashboard> createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  final PageController _kpiPageController = PageController(
    initialPage: 400,
    viewportFraction: 0.92,
  );
  final ValueNotifier<int> _currentKpiPageNotifier = ValueNotifier<int>(0);
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;
  String _userName = '';
  String _userRole = 'Organization Head';
  String _selectedKpiPeriod = 'Today';
  DateTime? _lastBackPressTime;
  Timer? _carouselTimer;

  // Cached Stream handles to avoid repeated subscriptions on rebuilds
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sitesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _projectsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _siteSupervisorMapStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _materialRequestsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _siteScheduleStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _supervisorRequestsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _supervisorEntriesStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadUserData();
    _startAutoPlayCarousel();
  }

  void _initStreams() {
    _notificationsStream = NotificationService.streamForRole(role: 'organisation');
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

  Future<void> _loadUserData() async {
    final userData = AuthService().userData;
    final fbUser = FirebaseAuth.instance.currentUser;
    String name =
        (userData['username'] ??
                userData['name'] ??
                userData['userName'] ??
                fbUser?.displayName ??
                userData['org_name'] ??
                userData['orgName'] ??
                '')
            .toString()
            .trim();

    if (name.isEmpty) {
      try {
        final adminDoc = await FirestoreService.orgDataDoc.get();
        if (adminDoc.exists) {
          final data = adminDoc.data();
          name =
              (data?['username'] ??
                      data?['name'] ??
                      data?['userName'] ??
                      data?['org_name'] ??
                      '')
                  .toString()
                  .trim();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _userName = name.isNotEmpty ? name : 'User';
        _userRole = userData['role'] ?? 'Organization Head';
      });
    }
  }

  String _formatCurrency(num value) {
    if (value == 0) return '0';
    final isNegative = value < 0;
    final absVal = value.abs().round();
    final str = absVal.toString();
    if (str.length <= 3) {
      return isNegative ? '-$str' : str;
    }

    final last3 = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    final formatted = buffer.toString();
    return isNegative ? '-$formatted' : formatted;
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _currentKpiPageNotifier.dispose();
    _subscriptionListener?.cancel();
    _scrollController.dispose();
    _kpiPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Press back again to exit',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF0A183D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              ),
            );
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<Color>(
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
              child: Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                bottomNavigationBar: const BottomNav(currentIndex: 0),
                body: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Responsive.maxContentWidth,
                      ),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // 1. Top Header
                          SliverToBoxAdapter(
                            child: _buildHeader(context, primaryColor),
                          ),

                          // 2. Dashboard KPIs Overview Carousel (includes Site Status tab)
                          SliverToBoxAdapter(
                            child: _buildKPIsCarousel(
                              context,
                              primaryColor,
                              darkAccent,
                            ),
                          ),

                          // 3. Quick Actions Bento Section
                          SliverToBoxAdapter(
                            child: _buildQuickActionsBentoSection(
                              context,
                              primaryColor,
                              darkAccent,
                            ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------- 1. HEADER SECTION --------------------

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _userRole,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _userName.isNotEmpty ? _userName : 'User',
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

          // Right: Notification Bell & Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                                      const OrgNotificationPage(),
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
              const SizedBox(width: 10),

              // Profile Avatar
              GestureDetector(
                onTap: () => _navigateToOrgMenu(context),
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
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
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

  // -------------------- 2. KPIS OVERVIEW CAROUSEL --------------------

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
                    'KPIs Overview',
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

        // Real-time Streams (using cached stream subscriptions across Site, projects, and mapping)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sitesStream,
          builder: (context, siteSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _projectsStream,
              builder: (context, projSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _siteSupervisorMapStream,
                  builder: (context, mapSnap) {
                    final siteDocs = siteSnap.hasData ? siteSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final projectDocs = projSnap.hasData ? projSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final supervisorDocs = mapSnap.hasData ? mapSnap.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    final allSiteDocsMap = _buildUnifiedSiteDocs(
                      siteDocs: siteDocs,
                      projectDocs: projectDocs,
                      supervisorDocs: supervisorDocs,
                    );

                    int totalSitesCount = allSiteDocsMap.length;
                    int projectsInProgressCount = 0;
                    int planningCount = 0;
                    int overdueCount = 0;
                    int pendingSitesCount = 0;
                    double totalAmountSpent = 0.0;
                    double totalAmountBalance = 0.0;
                    double totalAmountPaid = 0.0;
                    double totalBudget = 0.0;

                    final now = DateTime.now();
                    for (var entry in allSiteDocsMap.entries) {
                      final data = entry.value;
                      final s = (data['currentStatus'] ?? data['status'] ?? 'OnProgress')
                          .toString()
                          .trim()
                          .toLowerCase();

                      final endDate = _parseFlexibleDate(
                        data['actualEndDate'] ?? data['plannedEndDate'] ?? data['endDate'] ?? data['expectedCompletionDate'] ?? data['contractEndDate'],
                      );

                      final isCompleted = s.contains('complete') || s.contains('finish') || s.contains('closed') || s.contains('done');
                      final isPlanning = !isCompleted && (s.contains('plan') || s.contains('draft') || s.contains('upcoming') || s.contains('setup'));
                      final isOnHold = !isCompleted && (s.contains('hold') || s.contains('pending') || s.contains('pause') || s.contains('suspend'));
                      final isOverdue = !isCompleted && (s.contains('delay') || s.contains('overdue') || (endDate != null && endDate.isBefore(now) && !isCompleted));

                      if (isCompleted) {
                        // Completed site
                      } else if (isOverdue) {
                        overdueCount++;
                      } else if (isPlanning) {
                        planningCount++;
                      } else if (isOnHold) {
                        pendingSitesCount++;
                      } else {
                        projectsInProgressCount++;
                      }

                      final b = (data['projectBudget'] is num ? (data['projectBudget'] as num).toDouble() : (data['budget'] is num ? (data['budget'] as num).toDouble() : (double.tryParse(data['projectBudget']?.toString() ?? '') ?? 0.0)));
                      final sp = (data['amountSpent'] is num ? (data['amountSpent'] as num).toDouble() : (data['spent'] is num ? (data['spent'] as num).toDouble() : (double.tryParse(data['amountSpent']?.toString() ?? '') ?? 0.0)));
                      final pd = (data['amountPaid'] is num ? (data['amountPaid'] as num).toDouble() : (data['paid'] is num ? (data['paid'] as num).toDouble() : (double.tryParse(data['amountPaid']?.toString() ?? '') ?? 0.0)));
                      final bal = (data['amountBalance'] is num ? (data['amountBalance'] as num).toDouble() : (data['balance'] is num ? (data['balance'] as num).toDouble() : (b > 0 ? (b - sp) : 0.0)));

                      totalBudget += b;
                      totalAmountSpent += sp;
                      totalAmountPaid += pd;
                      totalAmountBalance += bal;
                    }

                    final displayTotalSites = totalSitesCount < 10
                        ? '0$totalSitesCount'
                        : '$totalSitesCount';
                    final displayProjects = projectsInProgressCount < 10
                        ? '0$projectsInProgressCount'
                        : '$projectsInProgressCount';
                    final displayPlanning = planningCount < 10
                        ? '0$planningCount'
                        : '$planningCount';
                    final displayOverdue = overdueCount < 10
                        ? '0$overdueCount'
                        : '$overdueCount';
                    final displayPendingSites = pendingSitesCount < 10
                        ? '0$pendingSitesCount'
                        : '$pendingSitesCount';

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
                                    final s = (d.data()['status'] ?? 'Processing').toString().toLowerCase();
                                    return s.contains('pending') || s.contains('processing');
                                  }).length;
                                }
                                if (wsSnap.hasData) {
                                  pendingApprovalsCount += wsSnap.data!.docs.where((d) {
                                    final s = (d.data()['approvalStatus'] ?? d.data()['status'] ?? 'Pending').toString().toLowerCase();
                                    return s.contains('pending') || s.contains('processing');
                                  }).length;
                                }
                                if (supSnap.hasData) {
                                  pendingApprovalsCount += supSnap.data!.docs.where((d) {
                                    final s = (d.data()['status'] ?? 'Pending').toString().toLowerCase();
                                    return s.contains('pending') || s.contains('processing');
                                  }).length;
                                }

                                final displayPending = pendingApprovalsCount < 10
                                    ? '0$pendingApprovalsCount'
                                    : '$pendingApprovalsCount';

                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: _supervisorEntriesStream,
                                  builder: (context, entrySnap) {
                                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                      stream: _expensesStream,
                                      builder: (context, expSnap) {
                                        double computedExpenses = 0.0;

                                        // 1. Ingest detailed daily supervisor & site entries
                                        if (entrySnap.hasData && entrySnap.data!.docs.isNotEmpty) {
                                          for (var doc in entrySnap.data!.docs) {
                                            final data = doc.data();
                                            double amount = 0.0;
                                            if (data['totalAmount'] is num) {
                                              amount = (data['totalAmount'] as num).toDouble();
                                            } else if (data['amount'] is num) {
                                              amount = (data['amount'] as num).toDouble();
                                            } else {
                                              amount = double.tryParse(data['totalAmount']?.toString() ?? '') ??
                                                  (double.tryParse(data['amount']?.toString() ?? '') ?? 0.0);
                                            }

                                            if (amount > 0) {
                                              final docDateStr = (data['date'] ?? '').toString();
                                              final docDate = _parseFlexibleDate(
                                                data['updatedAt'] ?? data['createdAt'] ?? data['timestamp'] ?? docDateStr,
                                              );
                                              if (_isDateInPeriod(docDate, docDateStr, _selectedKpiPeriod)) {
                                                computedExpenses += amount;
                                              }
                                            }
                                          }
                                        }

                                        // 2. Ingest totalSiteExpensesPerDay summaries
                                        if (expSnap.hasData && expSnap.data!.docs.isNotEmpty) {
                                          for (var doc in expSnap.data!.docs) {
                                            final data = doc.data();
                                            double amount = 0.0;
                                            if (data['totalAllExpenses'] is num) {
                                              amount = (data['totalAllExpenses'] as num).toDouble();
                                            } else {
                                              final sExp = (data['totalSiteExpense'] is num ? (data['totalSiteExpense'] as num).toDouble() : (double.tryParse(data['totalSiteExpense']?.toString() ?? '') ?? 0.0));
                                              final mExp = (data['totalMgrExpense'] is num ? (data['totalMgrExpense'] as num).toDouble() : (double.tryParse(data['totalMgrExpense']?.toString() ?? '') ?? 0.0));
                                              final oExp = (data['totalOrgExpense'] is num ? (data['totalOrgExpense'] as num).toDouble() : (double.tryParse(data['totalOrgExpense']?.toString() ?? '') ?? 0.0));
                                              final cExp = (data['totalContractorExpense'] is num ? (data['totalContractorExpense'] as num).toDouble() : (double.tryParse(data['totalContractorExpense']?.toString() ?? '') ?? 0.0));
                                              final iExp = (data['totalIncentiveExpenses'] is num ? (data['totalIncentiveExpenses'] as num).toDouble() : (double.tryParse(data['totalIncentiveExpenses']?.toString() ?? '') ?? 0.0));
                                              amount = sExp + mExp + oExp + cExp + iExp;
                                            }

                                            if (amount > 0) {
                                              final docDateStr = (data['date'] ?? '').toString();
                                              final docDate = _parseFlexibleDate(
                                                data['updatedAt'] ?? data['createdAt'] ?? data['timestamp'] ?? docDateStr,
                                              );
                                              if (_isDateInPeriod(docDate, docDateStr, _selectedKpiPeriod)) {
                                                if (computedExpenses == 0.0) {
                                                  computedExpenses += amount;
                                                }
                                              }
                                            }
                                          }
                                        }

                                        if (computedExpenses == 0.0 && _selectedKpiPeriod == 'All Time') {
                                          computedExpenses = totalAmountSpent;
                                        }

                                        double availableBalance = totalAmountBalance;
                                        if (availableBalance <= 0.0 && totalAmountPaid > 0.0) {
                                          availableBalance = totalAmountPaid - totalAmountSpent;
                                        } else if (availableBalance <= 0.0 && totalBudget > 0.0) {
                                          availableBalance = totalBudget - totalAmountSpent;
                                        }

                                        final expenseLabel = _selectedKpiPeriod == 'Today'
                                            ? "Today's Expenses"
                                            : (_selectedKpiPeriod == 'This Week'
                                                ? "This Week's Expenses"
                                                : (_selectedKpiPeriod == 'This Month'
                                                    ? "Monthly Expenses"
                                                    : "Total Expenses"));

                                        final displayExpenses = _formatCurrency(computedExpenses);
                                        final displayBalance = _formatCurrency(availableBalance);

                                        // Build Carousel Slides
                                        final slides = [
                                          // Slide 1: Financial Overview (Hero Gradient Card)
                                          _buildHeroBalanceSlide(
                                            context,
                                            balance: displayBalance,
                                            expenses: displayExpenses,
                                            expenseLabel: expenseLabel,
                                            primaryColor: primaryColor,
                                            darkAccent: darkAccent,
                                          ),

                                          // Slide 2: Site Status & Progress (All Site Statuses)
                                          _buildSiteStatusSlide(
                                            context,
                                            totalSites: displayTotalSites,
                                            planning: displayPlanning,
                                            inProgress: displayProjects,
                                            overdue: displayOverdue,
                                            pending: displayPendingSites,
                                            primaryColor: primaryColor,
                                          ),

                                          // Slide 3: Approvals & Tasks
                                          _buildApprovalsSlide(
                                            context,
                                            pendingCount: displayPending,
                                            primaryColor: primaryColor,
                                          ),

                                          // Slide 4: Expense Breakdown
                                          _buildExpensesSlide(
                                            context,
                                            expenses: displayExpenses,
                                            expenseLabel: expenseLabel,
                                            period: _selectedKpiPeriod,
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
                                                  _currentKpiPageNotifier.value = index % slides.length;
                                                  _startAutoPlayCarousel();
                                                },
                                                itemBuilder: (context, index) {
                                                  final slideIndex = index % slides.length;
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: slides[slideIndex],
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            // Modern Interactive Segmented Pill Indicator
                                            ValueListenableBuilder<int>(
                                              valueListenable: _currentKpiPageNotifier,
                                              builder: (context, activeIndex, _) {
                                                final titles = [
                                                  'Treasury',
                                                  'Operations',
                                                  'Approvals',
                                                  'Expenses',
                                                ];
                                                return Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: List.generate(slides.length, (index) {
                                                    final isSelected = activeIndex == index;
                                                    return GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        if (_kpiPageController.hasClients) {
                                                          final currentTotalPage = (_kpiPageController.page ?? 400).round();
                                                          final currentMod = currentTotalPage % slides.length;
                                                          final targetPage = currentTotalPage + (index - currentMod);
                                                          _kpiPageController.animateToPage(
                                                            targetPage,
                                                            duration: const Duration(milliseconds: 450),
                                                            curve: Curves.easeInOutCubic,
                                                          );
                                                        }
                                                        _startAutoPlayCarousel();
                                                      },
                                                      child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 280),
                                                        curve: Curves.easeOutCubic,
                                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: isSelected ? 12 : 6,
                                                          vertical: 5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.6),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                                                            width: 1,
                                                          ),
                                                          boxShadow: isSelected
                                                              ? [
                                                                  BoxShadow(
                                                                    color: primaryColor.withValues(alpha: 0.25),
                                                                    blurRadius: 6,
                                                                    offset: const Offset(0, 2),
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 6,
                                                              height: 6,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                                              ),
                                                            ),
                                                            if (isSelected) ...[
                                                              const SizedBox(width: 5),
                                                              Text(
                                                                titles[index],
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w800,
                                                                  letterSpacing: 0.2,
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

  // Slide 1: Treasury & Available Balance
  Widget _buildHeroBalanceSlide(
    BuildContext context, {
    required String balance,
    required String expenses,
    required String expenseLabel,
    required Color primaryColor,
    required Color darkAccent,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToSitePaymentMenu(context);
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
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Financial Treasury',
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
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage Funds',
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

            // Middle Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Net Available Balance',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹ $balance',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Outflow',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹ $expenses',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Progress / Sync Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live Balance Sync Active',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    expenseLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
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

  // Slide 2: Operations Center Modal (2x2 Matrix)
  Widget _buildSiteStatusSlide(
    BuildContext context, {
    required String totalSites,
    required String planning,
    required String inProgress,
    required String overdue,
    required String pending,
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.domain_rounded,
                      color: Color(0xFF2563EB),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Site Operations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      'Total: $totalSites',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
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
                        'All Sites',
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

          // 2x2 Grid of Status Tiles filling the card
          Expanded(
            child: Column(
              children: [
                // Row 1: Planning & In Progress
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSiteStatusTile(
                          title: 'Planning',
                          count: planning,
                          icon: Icons.architecture_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFDBEAFE),
                          onTap: () =>
                              _navigateToSitesList(context, 'Planning'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSiteStatusTile(
                          title: 'In Progress',
                          count: inProgress,
                          icon: Icons.engineering_rounded,
                          accentColor: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          borderColor: const Color(0xFFDCFCE7),
                          onTap: () =>
                              _navigateToSitesList(context, 'In Progress'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Row 2: Overdue & On Hold
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSiteStatusTile(
                          title: 'Overdue',
                          count: overdue,
                          icon: Icons.access_time_filled_rounded,
                          accentColor: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFFFBEB),
                          borderColor: const Color(0xFFFEF3C7),
                          onTap: () => _navigateToSitesList(context, 'On Hold'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSiteStatusTile(
                          title: 'On Hold',
                          count: pending,
                          icon: Icons.hourglass_top_rounded,
                          accentColor: const Color(0xFFDC2626),
                          bgColor: const Color(0xFFFEF2F2),
                          borderColor: const Color(0xFFFEE2E2),
                          onTap: () => _navigateToSitesList(context, 'On Hold'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteStatusTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(child: Icon(icon, color: accentColor, size: 17)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: accentColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 3: Workflow Approvals
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
          MaterialPageRoute(builder: (context) => const OrgApprovalsMenuPage()),
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
                        'Supervisor & material requests are awaiting organizational authorization.',
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

  // Slide 4: Expense Intelligence
  Widget _buildExpensesSlide(
    BuildContext context, {
    required String expenses,
    required String expenseLabel,
    required String period,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToOrganizationExpenses(context);
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
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Expense Intelligence',
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
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
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

            // Middle Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expenseLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹ $expenses',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF991B1B),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
              ],
            ),

            // Bottom Period Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categorized site, mgr & vendor expenses',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
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

  // -------------------- 3. QUICK ACTIONS 2-COLUMN SECTION (EXECUTIVE WHITE LABEL) --------------------

  Widget _buildQuickActionsBentoSection(
    BuildContext context,
    Color primaryColor,
    Color darkAccent,
  ) {
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
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
                    Icon(Icons.bolt_rounded, size: 13, color: primaryColor),
                    const SizedBox(width: 3),
                    Text(
                      'Shortcuts',
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
          const SizedBox(height: 14),

          // 2-Column Grid (1 1 / 1 1 / 1 1) with executive construction white cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.16,
            children: [
              // 1. Record Expense
              _buildConstructionActionCard(
                title: 'Expense Entry',
                subtitle: 'Bills & site expenses',
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFFEF4444),
                onTap: () => _navigateToOrganizationExpenses(context),
              ),

              // 2. Site Payment
              _buildConstructionActionCard(
                title: 'Site Payment',
                subtitle: 'Entry & reports',
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFF2563EB),
                onTap: () => _navigateToSitePaymentMenu(context),
              ),

              // 3. Approvals
              _buildConstructionActionCard(
                title: 'Approvals',
                subtitle: 'Materials, tools & payments',
                icon: Icons.fact_check_rounded,
                accentColor: const Color(0xFFD97706),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrgApprovalsMenuPage(),
                  ),
                ),
              ),

              // 4. Supervisor in Site
              _buildConstructionActionCard(
                title: 'Supervisor in Site',
                subtitle: 'Staff & site allocations',
                icon: Icons.engineering_rounded,
                accentColor: const Color(0xFFE11D48),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrgSupervisorInSitePage(),
                  ),
                ),
              ),

              // 5. Materials & Tools Inventory
              _buildConstructionActionCard(
                title: 'Materials & Tools Inventory',
                subtitle: 'Stock levels & equipment',
                icon: Icons.warehouse_rounded,
                accentColor: const Color(0xFF0D9488),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrgMaterialsToolsInventoryPage(),
                  ),
                ),
              ),

              // 6. Manager Config
              _buildConstructionActionCard(
                title: 'Manager Config',
                subtitle: 'Roles & permissions',
                icon: Icons.manage_accounts_rounded,
                accentColor: const Color(0xFF4F46E5),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagerConfigScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstructionActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Soft Tinted Icon Badge + Top-Right Action Arrow Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Tinted Icon Badge with Layered Depth
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: 0.16),
                        accentColor.withValues(alpha: 0.07),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.24),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: accentColor, size: 23),
                  ),
                ),

                // Top-Right Glass Outward Arrow Pill
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
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
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    height: 1.15,
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

  // -------------------- NAVIGATION HELPERS --------------------

  void _navigateToSitesList(BuildContext context, [String filter = 'All']) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrgSitesListPage(initialFilter: filter),
      ),
    );
  }

  void _navigateToSitePaymentMenu(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const OrgSitePaymentMenuPage()),
  );

  void _navigateToOrganizationExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => OrganizationExpenses()),
  );

  void _navigateToOrgMenu(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const OrgMenuScreen(standalone: true),
    ),
  );

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
        final sName = (data['siteName'] ?? data['projectName'] ?? '').toString().trim().toLowerCase();

        if (k == cleanDocId || k == cleanSiteId) return key;
        if (cleanSiteId.isNotEmpty && (sId == cleanSiteId || k.startsWith(cleanSiteId) || cleanDocId.startsWith(sId))) return key;
        if (cleanDocId.isNotEmpty && (cleanDocId == k || cleanDocId.contains(k) || k.contains(cleanDocId))) return key;
        if (cleanName.isNotEmpty && sName.isNotEmpty && cleanName == sName) return key;
      }
      return null;
    }

    // 1. Ingest Site collection docs (Primary created via Wizard)
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
        if (data['projectBudget'] != null && (target['projectBudget'] == null || target['projectBudget'] == 0)) {
          target['projectBudget'] = data['projectBudget'];
        }
        if (data['amountSpent'] != null && target['amountSpent'] == null) {
          target['amountSpent'] = data['amountSpent'];
        }
        if (data['amountPaid'] != null && (target['amountPaid'] == null || target['amountPaid'] == 0)) {
          target['amountPaid'] = data['amountPaid'];
        }
        if (data['amountBalance'] != null && target['amountBalance'] == null) {
          target['amountBalance'] = data['amountBalance'];
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
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
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
        return effectiveDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
      }
      return true;
    } else if (period == 'This Month') {
      if (effectiveDate != null) {
        return effectiveDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
      }
      return true;
    }
    return true; // 'All Time'
  }
}

