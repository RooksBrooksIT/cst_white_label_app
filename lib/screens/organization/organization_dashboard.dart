import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/config_account_dashboard.dart';
import 'package:demo_cst/screens/organization/org_site_payment_screen.dart';
import 'package:demo_cst/screens/reports/incentive_calculation.dart';
import 'package:demo_cst/screens/reports/insights_dashboard.dart';
import 'package:demo_cst/screens/manager/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/reports/material_report.dart';
import 'package:demo_cst/screens/organization/org_site_supervisor_daily_week_report.dart';
import 'package:demo_cst/screens/organization/organization_expenses.dart';
import 'package:demo_cst/screens/organization/organization_site_entry.dart';
import 'package:demo_cst/screens/reports/site_weekly_financial_report.dart';
import 'package:demo_cst/screens/reports/tools_inventory_report.dart';
import 'package:demo_cst/screens/manager/manager_approval_screen.dart';
import 'package:demo_cst/screens/organization/org_notification_page.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/manager/manager_config_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  State<OrganizationDashboard> createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  final PageController _statCardsPageController = PageController(
    viewportFraction: 0.88,
  );
  final TextEditingController _searchController = TextEditingController();
  int _currentStatCardIndex = 0;
  Timer? _statCardsAutoScrollTimer;
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;
  String _userName = '';
  String _userRole = 'Organization Administrator';
  String _searchQuery = '';
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkSubscription();
    _startSubscriptionListener();
    _startStatCardsAutoScroll();
  }

  void _startStatCardsAutoScroll() {
    _statCardsAutoScrollTimer?.cancel();
    _statCardsAutoScrollTimer = Timer.periodic(
      const Duration(seconds: 3, milliseconds: 500),
      (timer) {
        if (!mounted || !_statCardsPageController.hasClients) return;
        final nextPage = (_currentStatCardIndex + 1) % 4;
        _statCardsPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  void _resetAutoScrollTimer() {
    _startStatCardsAutoScroll();
  }

  Future<void> _loadUserData() async {
    final userData = AuthService().userData;
    setState(() {
      _userName =
          userData['org_name'] ?? userData['username'] ?? 'Organization';
      _userRole = userData['role'] ?? 'Organization Administrator';
    });
  }

  void _startSubscriptionListener() {
    _subscriptionListener = FirestoreService.subscriptionDoc.snapshots().listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          final isActive = data['isSubscriptionActive'] as bool? ?? true;
          final endDate = data['subscriptionEndDate'] as Timestamp?;
          bool isExpired = false;
          if (endDate != null) {
            isExpired = DateTime.now().isAfter(
              endDate.toDate().add(const Duration(hours: 1)),
            );
          }
          if (!isActive || isExpired) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizationSubscriptionPage(),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _checkSubscription() async {
    final isValid = await AuthService().checkSubscriptionStatus();
    if (!isValid && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OrganizationSubscriptionPage(),
        ),
      );
    }
  }

  /// Real-time Pending Material Requests Count Stream
  Stream<int> _getPendingMaterialRequestsCount() {
    return FirestoreService.getCollection(
      'siteMaterialsRequest',
    ).snapshots().map((snap) {
      return snap.docs.where((doc) {
        final status = (doc.data()['status'] ?? 'Processing').toString();
        return status.toLowerCase().contains('processing') ||
            status.toLowerCase().contains('pending');
      }).length;
    });
  }

  /// Real-time Pending Work Schedule / Worker Requests Count Stream
  Stream<int> _getPendingScheduleRequestsCount() {
    return FirestoreService.siteSupervisorProjectStageSchedule.snapshots().map((
      snap,
    ) {
      return snap.docs.where((doc) {
        final status =
            (doc.data()['approvalStatus'] ?? doc.data()['status'] ?? 'Pending')
                .toString();
        return status.toLowerCase().contains('pending') ||
            status.toLowerCase().contains('processing');
      }).length;
    });
  }

  @override
  void dispose() {
    _statCardsAutoScrollTimer?.cancel();
    _subscriptionListener?.cancel();
    _scrollController.dispose();
    _statCardsPageController.dispose();
    _searchController.dispose();
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
          return Theme(
            data: AppTheme.getTheme(primaryColor),
            child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return ValueListenableBuilder<String>(
                valueListenable: AppTheme.appName,
                builder: (context, appName, _) {
                  final titleText = appName.isNotEmpty
                      ? "$appName Overview"
                      : 'Organization Dashboard';

                  final darkAccent = AppTheme.getDarkAccent(primaryColor);

                  return Scaffold(
                    backgroundColor: const Color(0xFFF1F5F9),
                    appBar: AppBar(
                      iconTheme: const IconThemeData(color: Colors.white),
                      title: Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
                      actions: [
                        // Refresh / Sync Action Button
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Sync Dashboard',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {});
                          },
                        ),
                        // Notifications Action Button
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Notifications',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const OrgNotificationPage(),
                              ),
                            );
                          },
                        ),
                        // Org Menu Action Button
                        IconButton(
                          icon: const Icon(
                            Icons.grid_view_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Main Menu',
                          onPressed: () => _navigateToOrgMenu(context),
                        ),
                      ],
                    ),
                    body: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.maxContentWidth,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                // 1. Top Header Welcome Banner
                                SliverToBoxAdapter(
                                  child: _buildWelcomeHeader(context, theme),
                                ),

                                // 2. Real-time Project Statistics & Status Metrics Section
                                SliverToBoxAdapter(
                                  child: _buildProjectMetricsSection(
                                    context,
                                    theme,
                                  ),
                                ),

                                // 2.5. Real-time Supervisor Requests Announcements Section
                                SliverToBoxAdapter(
                                  child:
                                      _buildSupervisorRequestsAnnouncementSection(
                                        context,
                                        theme,
                                      ),
                                ),

                                // 2.7. Quick Access Search & User Discovery Bar
                                SliverToBoxAdapter(
                                  child: _buildQuickAccessSearchBar(
                                    context,
                                    theme,
                                  ),
                                ),

                                // 3. Categorized Feature Cards
                                ..._buildListSections(
                                  context,
                                  theme,
                                  constraints.maxWidth,
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 120),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    ),
  );
  }

  /// Header Banner showcasing User Welcome & Organization Status Pill
  Widget _buildWelcomeHeader(BuildContext context, ThemeData theme) {
    final hPad = Responsive.horizontalPadding(context);
    final primary = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primary);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkAccent,
              Color.alphaBlend(primary.withValues(alpha: 0.55), darkAccent),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar / Icon Container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.corporate_fare_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // User Greeting Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // Emerald green pulse
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _userRole,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Real-time Project Statistics Section displaying total project metrics & status breakdown
  Widget _buildProjectMetricsSection(BuildContext context, ThemeData theme) {
    final hPad = Responsive.horizontalPadding(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.projects.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Project Stream Error: ${snapshot.error}');
        }

        final docs = snapshot.hasData ? snapshot.data!.docs : [];

        int totalProjects = docs.length;
        int ongoingCount = 0;
        int completedCount = 0;
        int planningCount = 0;
        int onHoldCount = 0;

        for (var doc in docs) {
          final data = doc.data();
          final rawStatus =
              (data['currentStatus'] ?? data['status'] ?? 'Ongoing')
                  .toString()
                  .trim()
                  .toLowerCase();

          if (rawStatus.contains('ongoing') ||
              rawStatus.contains('active') ||
              rawStatus.contains('progress') ||
              rawStatus.contains('execution')) {
            ongoingCount++;
          } else if (rawStatus.contains('complete') ||
              rawStatus.contains('finish') ||
              rawStatus.contains('done') ||
              rawStatus.contains('closed')) {
            completedCount++;
          } else if (rawStatus.contains('plan') ||
              rawStatus.contains('upcoming') ||
              rawStatus.contains('draft') ||
              rawStatus.contains('setup')) {
            planningCount++;
          } else if (rawStatus.contains('hold') ||
              rawStatus.contains('pause') ||
              rawStatus.contains('delay') ||
              rawStatus.contains('suspend')) {
            onHoldCount++;
          } else {
            // Default to ongoing if unspecified
            ongoingCount++;
          }
        }

        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title Header with Navigation Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.dashboard_customize_rounded,
                        size: 20,
                        color: Color(0xFF0A183D),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Project Portfolio & Status',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0A183D),
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0A183D,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalProjects Total',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A183D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Scroll Arrows
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0A183D,
                            ).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _currentStatCardIndex > 0
                                    ? () {
                                        _resetAutoScrollTimer();
                                        _statCardsPageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    : null,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: _currentStatCardIndex > 0
                                        ? const Color(0xFF0A183D)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 12,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              InkWell(
                                onTap: _currentStatCardIndex < 3
                                    ? () {
                                        _resetAutoScrollTimer();
                                        _statCardsPageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    : null,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _currentStatCardIndex < 3
                                        ? const Color(0xFF0A183D)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stat Cards Horizontal Scroll (One by One)
              LayoutBuilder(
                builder: (context, constraints) {
                  final List<Map<String, dynamic>> statCards = [
                    {
                      'title': 'Total Projects',
                      'value': '$totalProjects',
                      'subtitle': 'Registered portfolio',
                      'icon': Icons.apartment_rounded,
                      'accentColor': const Color(0xFF3B82F6),
                      'bgColor': const Color(0xFFEFF6FF),
                      'textColor': const Color(0xFF1E40AF),
                    },
                    {
                      'title': 'Ongoing / Active',
                      'value': '$ongoingCount',
                      'subtitle': 'In active execution',
                      'icon': Icons.play_circle_fill_rounded,
                      'accentColor': const Color(0xFF10B981),
                      'bgColor': const Color(0xFFECFDF5),
                      'textColor': const Color(0xFF065F46),
                    },
                    {
                      'title': 'Completed',
                      'value': '$completedCount',
                      'subtitle': 'Successfully closed',
                      'icon': Icons.check_circle_rounded,
                      'accentColor': const Color(0xFF6366F1),
                      'bgColor': const Color(0xFFEEF2FF),
                      'textColor': const Color(0xFF3730A3),
                    },
                    {
                      'title': 'Planning / Hold',
                      'value': '${planningCount + onHoldCount}',
                      'subtitle': '$planningCount plan • $onHoldCount hold',
                      'icon': Icons.pending_actions_rounded,
                      'accentColor': const Color(0xFFF59E0B),
                      'bgColor': const Color(0xFFFFFBEB),
                      'textColor': const Color(0xFF92400E),
                    },
                  ];

                  return Column(
                    children: [
                      SizedBox(
                        height: 125,
                        child: PageView.builder(
                          controller: _statCardsPageController,
                          itemCount: statCards.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentStatCardIndex = index;
                            });
                            _resetAutoScrollTimer();
                          },
                          itemBuilder: (context, index) {
                            final stat = statCards[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: _buildStatCard(
                                title: stat['title'] as String,
                                value: stat['value'] as String,
                                subtitle: stat['subtitle'] as String,
                                icon: stat['icon'] as IconData,
                                accentColor: stat['accentColor'] as Color,
                                bgColor: stat['bgColor'] as Color,
                                textColor: stat['textColor'] as Color,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Animated Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(statCards.length, (index) {
                          final isSelected = _currentStatCardIndex == index;
                          final cardAccent =
                              statCards[index]['accentColor'] as Color;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: isSelected ? 22 : 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cardAccent
                                  : cardAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              // Visual Status Distribution Progress Bar
              if (totalProjects > 0)
                _buildStatusProgressBar(
                  total: totalProjects,
                  ongoing: ongoingCount,
                  completed: completedCount,
                  planning: planningCount,
                  onHold: onHoldCount,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Real-time Supervisor Requests Announcement Section (Material & Work Schedule Requests)
  Widget _buildSupervisorRequestsAnnouncementSection(
    BuildContext context,
    ThemeData theme,
  ) {
    final hPad = Responsive.horizontalPadding(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection('materialRequests').snapshots(),
      builder: (context, matSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.siteSupervisorProjectStageSchedule
              .snapshots(),
          builder: (context, wsSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.getCollection(
                'supervisor_requests',
              ).snapshots(),
              builder: (context, genSnap) {
                final List<Map<String, dynamic>> incomingAnnouncements = [];

                // 1. Process Material Requests (Processing / Pending)
                if (matSnap.hasData) {
                  for (var doc in matSnap.data!.docs) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'Processing').toString();
                    if (status.toLowerCase().contains('processing') ||
                        status.toLowerCase().contains('pending')) {
                      incomingAnnouncements.add({
                        'docId': doc.id,
                        'requestType': 'Material Request',
                        'typeKey': 'material_request',
                        'icon': Icons.inventory_2_rounded,
                        'accentColor': const Color(0xFFEA580C),
                        'supervisorName':
                            data['supervisorName']?.toString() ?? 'Supervisor',
                        'requestId': data['matReqId']?.toString() ?? doc.id,
                        'siteName':
                            data['siteId']?.toString() ??
                            data['projectName']?.toString() ??
                            'Site',
                        'date': data['date']?.toString() ?? 'Recent',
                      });
                    }
                  }
                }

                // 2. Process Work Schedule Requests (Pending)
                if (wsSnap.hasData) {
                  for (var doc in wsSnap.data!.docs) {
                    final data = doc.data();
                    final status =
                        (data['approvalStatus'] ?? data['status'] ?? 'Pending')
                            .toString();
                    if (status.toLowerCase().contains('pending') ||
                        status.toLowerCase().contains('processing')) {
                      incomingAnnouncements.add({
                        'docId': doc.id,
                        'requestType': 'Work Schedule Request',
                        'typeKey': 'work_schedule',
                        'icon': Icons.event_available_rounded,
                        'accentColor': const Color(0xFF10B981),
                        'supervisorName':
                            data['supervisorName']?.toString() ?? 'Supervisor',
                        'requestId': data['wsReqId']?.toString() ?? doc.id,
                        'siteName':
                            data['siteId']?.toString() ??
                            data['projectName']?.toString() ??
                            'Site',
                        'date': 'Pending Approval',
                      });
                    }
                  }
                }

                // 3. Process General Supervisor Requests (Pending)
                if (genSnap.hasData) {
                  for (var doc in genSnap.data!.docs) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'Pending').toString();
                    if (status.toLowerCase() == 'pending') {
                      incomingAnnouncements.add({
                        'docId': doc.id,
                        'requestType':
                            data['category']?.toString() ??
                            'Supervisor Request',
                        'typeKey': 'general',
                        'icon': Icons.rate_review_rounded,
                        'accentColor': const Color(0xFF3B82F6),
                        'supervisorName':
                            data['supervisorName']?.toString() ?? 'Supervisor',
                        'requestId': data['title']?.toString() ?? doc.id,
                        'siteName': data['site']?.toString() ?? 'Site',
                        'date': 'Pending Approval',
                      });
                    }
                  }
                }

                if (incomingAnnouncements.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A183D), Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0A183D,
                          ).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
                                color: Colors.orange.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.orangeAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Supervisor Requests Announcements',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${incomingAnnouncements.length} Pending',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 145,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: incomingAnnouncements.length,
                            itemBuilder: (context, index) {
                              final item = incomingAnnouncements[index];
                              final String reqType = item['requestType'];
                              final String supName = item['supervisorName'];
                              final String reqId = item['requestId'];
                              final String siteName = item['siteName'];
                              final Color accent = item['accentColor'];
                              final IconData icon = item['icon'];
                              final String typeKey = item['typeKey'];

                              return Container(
                                width: 280,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            color: accent,
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            reqType,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: accent,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Supervisor: $supName',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0A183D),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'ID: $reqId',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '• Site: $siteName',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          if (typeKey == 'material_request') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const ManagerMaterialApprovalScreen(),
                                              ),
                                            );
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const ManagerApprovalScreen(),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0A183D,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'View Request',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Individual Stat Summary Card Widget
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Segmented Progress Bar showcasing Project Status Percentages
  Widget _buildStatusProgressBar({
    required int total,
    required int ongoing,
    required int completed,
    required int planning,
    required int onHold,
  }) {
    final double ongoingPct = total > 0 ? (ongoing / total) : 0;
    final double completedPct = total > 0 ? (completed / total) : 0;
    final double planningPct = total > 0 ? (planning / total) : 0;
    final double onHoldPct = total > 0 ? (onHold / total) : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0A183D).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Status Breakdown Ratio',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              Text(
                '100% Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Multi-color Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (ongoingPct > 0)
                    Expanded(
                      flex: (ongoingPct * 100).round(),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (completedPct > 0)
                    Expanded(
                      flex: (completedPct * 100).round(),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (planningPct > 0)
                    Expanded(
                      flex: (planningPct * 100).round(),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (onHoldPct > 0)
                    Expanded(
                      flex: (onHoldPct * 100).round(),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(
                'Ongoing',
                '${(ongoingPct * 100).toStringAsFixed(0)}%',
                const Color(0xFF10B981),
              ),
              _buildLegendItem(
                'Completed',
                '${(completedPct * 100).toStringAsFixed(0)}%',
                const Color(0xFF3B82F6),
              ),
              _buildLegendItem(
                'Planning',
                '${(planningPct * 100).toStringAsFixed(0)}%',
                const Color(0xFFF59E0B),
              ),
              _buildLegendItem(
                'On Hold',
                '${(onHoldPct * 100).toStringAsFixed(0)}%',
                const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String pct, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $pct',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// Quick Access Search Bar & Instant Discovery
  Widget _buildQuickAccessSearchBar(BuildContext context, ThemeData theme) {
    final hPad = Responsive.horizontalPadding(context);
    final primary = theme.primaryColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? primary.withValues(alpha: 0.6)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
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
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Search manager, financial, supervisor, tools...',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Category Grid Tile for Organization Dashboard Quick Access
  Widget _buildCategoryGridTile({
    required BuildContext context,
    required OrgCategoryData category,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).primaryColor;

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
            color: color.withValues(alpha: 0.06),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Category Icon & Option Count Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(category.icon, color: Colors.white, size: 19),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${category.items.length} ${category.items.length == 1 ? "Option" : "Options"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: color,
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
                      category.title,
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
                      category.subtitle,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.1,
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

  /// Category Heading Banner (Shown during active search / filtering)
  Widget _buildCategoryHeading({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int itemCount,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final hPad = Responsive.horizontalPadding(context);
    final brandingColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? brandingColor.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
                width: isExpanded ? 1.4 : 1.0,
              ),
              boxShadow: isExpanded
                  ? [
                      BoxShadow(
                        color: brandingColor.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brandingColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: brandingColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(child: Icon(icon, color: Colors.white, size: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandingColor.withValues(alpha: isExpanded ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? "Option" : "Options"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: brandingColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: isExpanded ? 0.5 : 0.0,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: brandingColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildListSections(
    BuildContext context,
    ThemeData theme,
    double availableWidth,
  ) {
    final hPad = Responsive.horizontalPadding(context);
    final allCategories = _getCategories(theme);
    final rawQuery = _searchQuery.trim().toLowerCase();

    final crossAxisCount = availableWidth >= 900
        ? 5
        : (availableWidth >= 600 ? 4 : 3);
    final childAspectRatio = availableWidth >= 600 ? 1.05 : 0.88;

    List<Widget> slivers = [];

    // Header Title: "Quick Access" on Left, "View All" on Right
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            Responsive.spacing(context, 8),
            hPad,
            Responsive.spacing(context, 4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                rawQuery.isNotEmpty ? 'Search Results' : 'Quick Access',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.4,
                ),
              ),
              if (rawQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: const Text(
                    'Clear Search',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // When NO search query is active, display categories in the smooth 2-Column Grid!
    if (rawQuery.isEmpty) {
      final categoryCrossAxisCount = availableWidth >= 900
          ? 4
          : (availableWidth >= 600 ? 3 : 2);
      final categoryAspectRatio = availableWidth >= 600 ? 1.55 : 1.35;

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
                final cat = allCategories[index];
                return _buildCategoryGridTile(
                  context: context,
                  category: cat,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrgCategoryDetailsPage(
                          category: cat,
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: allCategories.length,
            ),
          ),
        ),
      );
      return slivers;
    }

    // Determine matching categories and their items for active search
    final List<Map<String, dynamic>> categoriesToDisplay = [];

    for (var cat in allCategories) {
      final matchingItems = cat.items.where((item) {
        final titleMatch = item.title.toLowerCase().contains(rawQuery);
        final subtitleMatch = item.subtitle.toLowerCase().contains(rawQuery);
        final tagMatch =
            item.tags?.any((tag) => tag.toLowerCase().contains(rawQuery)) ??
            false;
        return titleMatch || subtitleMatch || tagMatch;
      }).toList();

      if (cat.title.toLowerCase().contains(rawQuery) ||
          cat.subtitle.toLowerCase().contains(rawQuery) ||
          matchingItems.isNotEmpty) {
        categoriesToDisplay.add({
          'category': cat,
          'items': matchingItems.isNotEmpty ? matchingItems : cat.items,
        });
      }
    }

    if (categoriesToDisplay.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(hPad),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No features found for "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Try searching for approvals, report, sites, etc.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    for (var catMap in categoriesToDisplay) {
      final OrgCategoryData cat = catMap['category'];
      final List<SubMenuItem> items = catMap['items'];

      slivers.add(
        SliverToBoxAdapter(
          child: _buildCategoryHeading(
            context: context,
            title: cat.title,
            subtitle: cat.subtitle,
            icon: cat.icon,
            color: cat.color,
            itemCount: items.length,
            isExpanded: true,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrgCategoryDetailsPage(
                    category: cat,
                  ),
                ),
              );
            },
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return _buildQuickAccessCard(context, item);
              },
              childCount: items.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildQuickAccessCard(BuildContext context, SubMenuItem item) {
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = primaryColor.withValues(alpha: 0.08);
    final iconBg = primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
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
            item.onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (item.countStream != null)
                      StreamBuilder<int>(
                        stream: item.countStream,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count NEW',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: primaryColor,
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

  List<OrgCategoryData> _getCategories(ThemeData theme) {
    final primary = theme.primaryColor;

    return [
      OrgCategoryData(
        title: "Configuration",
        subtitle: "System setup, workers, sites, stages & users",
        icon: Icons.tune_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Master Console",
            subtitle: "Full organization controls",
            icon: Icons.admin_panel_settings_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'config',
              'setup',
              'console',
              'admin',
              'master',
              'dashboard',
              'system',
            ],
            onTap: () => _navigateToConfiguration(context),
          ),
          SubMenuItem(
            title: "Manager Settings",
            subtitle: "Site workers & materials config",
            icon: Icons.manage_accounts_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'config',
              'manager',
              'settings',
              'workers',
              'materials',
              'sites',
              'setup',
            ],
            onTap: () => _navigateToManagerConfig(context),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Daily Operations",
        subtitle: "Payment records, site progress & daily logs",
        icon: Icons.calendar_today_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Daily Payment Entry",
            subtitle: "Record daily site payments",
            icon: Icons.payments_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['daily', 'payment', 'entry', 'finance', 'site', 'expense'],
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          SubMenuItem(
            title: "Daily Site Payment Report",
            subtitle: "Daily site ledger breakdown",
            icon: Icons.receipt_long_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'daily',
              'payment',
              'report',
              'finance',
              'site',
              'statement',
            ],
            onTap: () => _navigateToDailyReport(context),
          ),
          SubMenuItem(
            title: "Organisation Daily Entry",
            subtitle: "Daily project progress & expenses",
            icon: Icons.edit_note_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['entry', 'daily', 'progress', 'site', 'expense'],
            onTap: () => _navigateToManagerDailyEntry(context),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Financial Ledger",
        subtitle: "Expense logs, weekly reports & incentive calculations",
        icon: Icons.account_balance_wallet_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Organization Expenses",
            subtitle: "Central operational costs",
            icon: Icons.corporate_fare_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'expense',
              'cost',
              'spend',
              'operational',
              'organization',
              'central',
            ],
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          SubMenuItem(
            title: "Daily Site Payment Report",
            subtitle: "Daily site transaction logs",
            icon: Icons.receipt_long_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'finance',
              'daily',
              'payment',
              'report',
              'transaction',
              'statement',
            ],
            onTap: () => _navigateToDailyReport(context),
          ),
          SubMenuItem(
            title: "Weekly Finance Report",
            subtitle: "Weekly financial health overview",
            icon: Icons.account_balance_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'finance',
              'financial',
              'weekly',
              'health',
              'overview',
              'report',
            ],
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
          SubMenuItem(
            title: "Financial Analytics",
            subtitle: "Financial metrics & insights",
            icon: Icons.query_stats_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'finance',
              'financial',
              'analytics',
              'insights',
              'charts',
              'report',
            ],
            onTap: () => _navigateToInsights(context),
          ),
          SubMenuItem(
            title: "Incentive Calculation",
            subtitle: "Performance-based rewards",
            icon: Icons.calculate_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'finance',
              'financial',
              'incentive',
              'reward',
              'calculation',
              'bonus',
              'worker',
            ],
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Supervisor Operations",
        subtitle: "Supervisor work schedule approvals",
        icon: Icons.supervisor_account_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Schedule Approval",
            subtitle: "Supervisor work schedule approvals",
            icon: Icons.event_available_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'approval',
              'schedule',
              'workers',
              'supervisor',
              'review',
              'pending',
              'user',
            ],
            countStream: _getPendingScheduleRequestsCount(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerApprovalScreen(),
              ),
            ),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Expense Management",
        subtitle: "Track organization and field expenditures",
        icon: Icons.monetization_on_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Organization Expenses",
            subtitle: "Central operational costs",
            icon: Icons.corporate_fare_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'expense',
              'cost',
              'spend',
              'operational',
              'organization',
              'central',
            ],
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          SubMenuItem(
            title: "Organisation Daily Entry",
            subtitle: "Daily project progress & expenses",
            icon: Icons.edit_note_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['entry', 'daily', 'progress', 'site', 'expense'],
            onTap: () => _navigateToManagerDailyEntry(context),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Review & Approvals",
        subtitle: "Approve schedules, materials, and incentives",
        icon: Icons.fact_check_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Schedule Approval",
            subtitle: "Work schedules & workers",
            icon: Icons.event_available_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'approval',
              'schedule',
              'workers',
              'review',
              'pending',
              'user',
            ],
            countStream: _getPendingScheduleRequestsCount(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Material Approval",
            subtitle: "Material procurement authorization",
            icon: Icons.inventory_2_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['approval', 'material', 'procurement', 'review', 'pending'],
            countStream: _getPendingMaterialRequestsCount(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerMaterialApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Incentive Calculation",
            subtitle: "Performance-based rewards",
            icon: Icons.calculate_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: [
              'incentive',
              'reward',
              'calculation',
              'bonus',
              'worker',
              'user',
            ],
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ],
      ),
      OrgCategoryData(
        title: "Reports & Analytics",
        subtitle: "Stock monitoring, equipment & performance analytics",
        icon: Icons.bar_chart_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.85)],
        items: [
          SubMenuItem(
            title: "Financial Analytics",
            subtitle: "Performance insights & charts",
            icon: Icons.query_stats_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['analytics', 'insights', 'charts', 'report', 'financial'],
            onTap: () => _navigateToInsights(context),
          ),
          SubMenuItem(
            title: "Materials Inventory",
            subtitle: "Real-time stock monitoring",
            icon: Icons.inventory_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['material', 'inventory', 'stock', 'report'],
            onTap: () => _navigateToMaterialReport(context),
          ),
          SubMenuItem(
            title: "Tools Inventory",
            subtitle: "Field equipment usage",
            icon: Icons.construction_rounded,
            color: primary,
            cardBgColor: primary.withValues(alpha: 0.08),
            tags: ['tools', 'equipment', 'inventory', 'report'],
            onTap: () => _navigateToToolsInventory(context),
          ),
        ],
      ),
    ];
  }

  // Navigation methods
  void _navigateToConfiguration(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ConfigAccountDashboard(showLogout: false),
    ),
  );

  void _navigateToManagerConfig(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ManagerConfigScreen()),
  );

  void _navigateToDailyReport(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => DailySitePaymentReportScreen()),
  );

  void _navigateToInsights(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => InsightsDashboard()),
  );

  void _navigateToSitePaymentEntry(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => SitePaymentScreen()),
  );

  void _navigateToSiteWeeklyFinancialReport(BuildContext context) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SiteWeeklyFinancialReports()),
      );

  void _navigateToIncentiveCaliculation(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => IncentiveCalculation()),
  );

  void _navigateToOrganizationExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => OrganizationExpenses()),
  );

  void _navigateToMaterialReport(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const MaterialReportPage()),
  );

  void _navigateToToolsInventory(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ToolsInventoryPage()),
  );

  void _navigateToManagerDailyEntry(BuildContext context) {
    final userData = AuthService().userData;
    final userName = userData['username'] ?? userData['org_name'] ?? 'Admin';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrganizationSiteEntry(userName: userName, userDetails: userData),
      ),
    );
  }

  void _navigateToOrgMenu(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const OrgMenuScreen(standalone: true),
    ),
  );
}

class OrgCategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<SubMenuItem> items;

  OrgCategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.items,
  });
}

class SubMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? cardBgColor;
  final VoidCallback onTap;
  final Stream<int>? countStream;
  final List<String>? tags;

  SubMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.cardBgColor,
    required this.onTap,
    this.countStream,
    this.tags,
  });
}

/// Dedicated Details Screen for displaying options of an individual category
class OrgCategoryDetailsPage extends StatefulWidget {
  final OrgCategoryData category;

  const OrgCategoryDetailsPage({
    super.key,
    required this.category,
  });

  @override
  State<OrgCategoryDetailsPage> createState() => _OrgCategoryDetailsPageState();
}

class _OrgCategoryDetailsPageState extends State<OrgCategoryDetailsPage> {
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
    final cat = widget.category;

    final rawQuery = _searchQuery.trim().toLowerCase();
    final items = rawQuery.isEmpty
        ? cat.items
        : cat.items.where((item) {
            final titleMatch = item.title.toLowerCase().contains(rawQuery);
            final subtitleMatch =
                item.subtitle.toLowerCase().contains(rawQuery);
            final tagMatch =
                item.tags?.any((tag) => tag.toLowerCase().contains(rawQuery)) ??
                false;
            return titleMatch || subtitleMatch || tagMatch;
          }).toList();

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, appPrimary, _) {
        final primaryColor = appPrimary;
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              cat.title,
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
                      primaryColor.withValues(alpha: 0.45),
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
                            color: primaryColor.withValues(alpha: 0.2),
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
                                  cat.icon,
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
                                    cat.title,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A183D),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cat.subtitle,
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
                                '${cat.items.length} ${cat.items.length == 1 ? "Option" : "Options"}',
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

                  // Search Bar inside Category (if more than 2 items)
                  if (cat.items.length > 2)
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
                              hintText: 'Search in ${cat.title}...',
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
                  if (items.isEmpty)
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
                                'No matching options in ${cat.title}',
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
                            final item = items[index];
                            return _buildOptionCard(context, item, primaryColor);
                          },
                          childCount: items.length,
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
    SubMenuItem item,
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
          color: primaryColor.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
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
            item.onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Circular Icon & Optional Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (item.countStream != null)
                      StreamBuilder<int>(
                        stream: item.countStream,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count NEW',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
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
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: primaryColor,
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
