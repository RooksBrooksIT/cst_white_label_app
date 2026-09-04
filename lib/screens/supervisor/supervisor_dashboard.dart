import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/common/notification_page.dart';
import 'package:demo_cst/screens/supervisor/supervisor_verification_page.dart';
import 'package:demo_cst/screens/supervisor/material_request_form.dart';
import 'package:demo_cst/screens/supervisor/supervisor_material_view_request_screen.dart';
import 'package:demo_cst/screens/supervisor/supervisor_work_schedule_page.dart';
import 'package:demo_cst/screens/supervisor/supervisor_view_request_screen.dart';
import 'package:demo_cst/screens/supervisor/supervisor_worker_att_page.dart';
import 'package:demo_cst/screens/supervisor/material_at_site_entry_page.dart';
import 'package:demo_cst/screens/supervisor/tools_at_site_page.dart';
import 'package:demo_cst/screens/supervisor/supervisor_material_information.dart';
import 'package:demo_cst/screens/supervisor/tools_movement_page.dart';
import 'package:demo_cst/screens/common/construction_documents.dart';
import 'package:demo_cst/screens/organization/org_sub_menu_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorDashboard({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required String username,
  });

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<SubMenuItem> items;

  _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastBackPressTime;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your active supervisor session and log out?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'LOGOUT',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final availableWidth = MediaQuery.of(context).size.width;
    final isMobile = availableWidth < 600;
    final crossAxisCount = availableWidth >= 900
        ? 4
        : (availableWidth >= 600 ? 3 : 2);
    final childAspectRatio = availableWidth >= 600 ? 1.25 : 1.16;
    final categories = _getCategories();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (mounted) {
            AppTheme.showSuccessToast(context, 'Press back again to exit');
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Supervisor Portal',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
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
            // Notifications Bell Icon
            StreamBuilder<int>(
              stream: NotificationService.unreadCountForSupervisor(
                widget.supervisorName,
              ),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: 'Notifications',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationPage(
                              supervisorName: widget.supervisorName,
                            ),
                          ),
                        );
                      },
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
              tooltip: 'Logout',
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 920),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Supervisor Profile Header Banner
                  SliverToBoxAdapter(
                    child: _buildProfileHeaderBanner(context, darkAccent),
                  ),

                  // 2. Metrics & Project Status Summary
                  SliverToBoxAdapter(
                    child: _buildSupervisorMetricsAndStatus(context, darkAccent),
                  ),

                  // 3. Categorized Quick Action Modules Grid
                  ..._buildGridSections(
                    context,
                    darkAccent,
                    categories,
                    crossAxisCount,
                    childAspectRatio,
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. PROFILE HEADER BANNER
  // ---------------------------------------------------------------------------

  Widget _buildProfileHeaderBanner(BuildContext context, Color darkAccent) {
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkAccent,
              Color.alphaBlend(primaryColor.withValues(alpha: 0.45), darkAccent),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: darkAccent.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.supervisor_account_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Site Operations Supervisor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.supervisorName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
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
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ID: ${widget.supervisorId.isNotEmpty ? widget.supervisorId : "SUP-ACTIVE"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    color: Color(0xFF34D399),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
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

  // ---------------------------------------------------------------------------
  // 2. METRICS & STATUS BREAKDOWN
  // ---------------------------------------------------------------------------

  Widget _buildSupervisorMetricsAndStatus(BuildContext context, Color darkAccent) {
    final hPad = Responsive.horizontalPadding(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection('Site').snapshots(),
      builder: (context, sitesSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.getCollection('siteSupervisorMap').snapshots(),
          builder: (context, mapSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.getCollection('supervisor_requests').snapshots(),
              builder: (context, reqSnap) {
                final Set<String> assignedSiteNames = {};
                final List<Map<String, dynamic>> assignedSiteDocs = [];

                if (mapSnap.hasData) {
                  for (var doc in mapSnap.data!.docs) {
                    final data = doc.data();
                    final supName = data['supervisor']?.toString() ?? '';
                    final supId = data['supervisorId']?.toString() ?? '';
                    if (supName == widget.supervisorName || supId == widget.supervisorId) {
                      final site = data['site']?.toString() ?? '';
                      if (site.isNotEmpty) assignedSiteNames.add(site);
                    }
                  }
                }

                if (sitesSnap.hasData) {
                  for (var doc in sitesSnap.data!.docs) {
                    final data = doc.data();
                    final docId = doc.id;
                    final siteName = data['siteName']?.toString() ?? docId;
                    final supName = data['assignedSupervisor']?.toString() ?? data['supervisor']?.toString() ?? '';
                    final supId = data['supervisorId']?.toString() ?? '';

                    if (supName == widget.supervisorName ||
                        supId == widget.supervisorId ||
                        assignedSiteNames.contains(docId) ||
                        assignedSiteNames.contains(siteName)) {
                      assignedSiteDocs.add(data);
                      assignedSiteNames.add(siteName);
                    }
                  }
                }

                int totalAssignedSites = assignedSiteDocs.length;
                int inProgressCount = 0;
                int notStartedCount = 0;
                int onHoldCount = 0;
                int completedCount = 0;

                for (var doc in assignedSiteDocs) {
                  final rawStatus = (doc['currentStatus'] ?? doc['status'] ?? 'In Progress')
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (rawStatus.contains('progress') ||
                      rawStatus.contains('active') ||
                      rawStatus.contains('ongoing') ||
                      rawStatus.contains('execution')) {
                    inProgressCount++;
                  } else if (rawStatus.contains('complete') ||
                      rawStatus.contains('finish') ||
                      rawStatus.contains('done') ||
                      rawStatus.contains('closed')) {
                    completedCount++;
                  } else if (rawStatus.contains('plan') ||
                      rawStatus.contains('start') ||
                      rawStatus.contains('draft') ||
                      rawStatus.contains('upcoming')) {
                    notStartedCount++;
                  } else if (rawStatus.contains('hold') ||
                      rawStatus.contains('pause') ||
                      rawStatus.contains('delay') ||
                      rawStatus.contains('suspend')) {
                    onHoldCount++;
                  } else {
                    inProgressCount++;
                  }
                }

                int pendingRequestsCount = 0;
                if (reqSnap.hasData) {
                  for (var doc in reqSnap.data!.docs) {
                    final data = doc.data();
                    final supName = data['supervisorName']?.toString() ?? '';
                    final supId = data['supervisorId']?.toString() ?? '';
                    final status = data['status']?.toString() ?? 'Pending';
                    if ((supName == widget.supervisorName || supId == widget.supervisorId) &&
                        status == 'Pending') {
                      pendingRequestsCount++;
                    }
                  }
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4 KPI Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricKpiCard(
                              title: 'Sites',
                              value: '$totalAssignedSites',
                              subtitle: 'Allocated',
                              icon: Icons.location_city_rounded,
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricKpiCard(
                              title: 'Progress',
                              value: '$inProgressCount',
                              subtitle: 'Active',
                              icon: Icons.engineering_rounded,
                              accentColor: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricKpiCard(
                              title: 'Pending',
                              value: '$pendingRequestsCount',
                              subtitle: 'Requests',
                              icon: Icons.pending_actions_rounded,
                              accentColor: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricKpiCard(
                              title: 'Finished',
                              value: '$completedCount',
                              subtitle: 'Completed',
                              icon: Icons.task_alt_rounded,
                              accentColor: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Project Status Summary Progress Bar & Chips
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0A183D).withValues(alpha: 0.04),
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
                                const Icon(
                                  Icons.pie_chart_outline_rounded,
                                  color: Color(0xFF0A183D),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Site Status Distribution',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A183D),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$totalAssignedSites Total Sites',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Segmented Status Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 8,
                                width: double.infinity,
                                color: const Color(0xFFF1F5F9),
                                child: Row(
                                  children: [
                                    if (inProgressCount > 0)
                                      Expanded(
                                        flex: inProgressCount,
                                        child: Container(color: const Color(0xFF3B82F6)),
                                      ),
                                    if (notStartedCount > 0)
                                      Expanded(
                                        flex: notStartedCount,
                                        child: Container(color: const Color(0xFF94A3B8)),
                                      ),
                                    if (onHoldCount > 0)
                                      Expanded(
                                        flex: onHoldCount,
                                        child: Container(color: const Color(0xFFF59E0B)),
                                      ),
                                    if (completedCount > 0)
                                      Expanded(
                                        flex: completedCount,
                                        child: Container(color: const Color(0xFF10B981)),
                                      ),
                                    if (totalAssignedSites == 0)
                                      Expanded(
                                        child: Container(color: const Color(0xFFCBD5E1)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Status Details Pills Row
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildStatusSummaryPill(
                                  label: 'In Progress',
                                  count: inProgressCount,
                                  color: const Color(0xFF3B82F6),
                                ),
                                _buildStatusSummaryPill(
                                  label: 'Not Started',
                                  count: notStartedCount,
                                  color: const Color(0xFF64748B),
                                ),
                                _buildStatusSummaryPill(
                                  label: 'On Hold',
                                  count: onHoldCount,
                                  color: const Color(0xFFF59E0B),
                                ),
                                _buildStatusSummaryPill(
                                  label: 'Completed',
                                  count: completedCount,
                                  color: const Color(0xFF10B981),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricKpiCard({
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
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 15),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0A183D),
              letterSpacing: -0.4,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9.5,
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

  Widget _buildStatusSummaryPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CATEGORIZED QUICK ACTION MODULES GRID
  // ---------------------------------------------------------------------------

  List<Widget> _buildGridSections(
    BuildContext context,
    Color darkAccent,
    List<_CategoryData> categories,
    int crossAxisCount,
    double childAspectRatio,
  ) {
    final hPad = Responsive.horizontalPadding(context);
    List<Widget> slivers = [];

    for (var category in categories) {
      if (category.items.isEmpty) continue;

      // Section Header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: category.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              category.subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        category.icon,
                        size: 13,
                        color: category.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${category.items.length} ${category.items.length == 1 ? 'Action' : 'Actions'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: category.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Grid Items for this section (matches Manager Console Action Card design language)
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = category.items[index];
              return _buildConstructionActionCard(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                accentColor: item.color,
                onTap: item.onTap,
              );
            }, childCount: category.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  // Executive Construction Action Card (matches Manager Console design language)
  Widget _buildConstructionActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isStatic = false,
  }) {
    return InkWell(
      onTap: isStatic
          ? null
          : () {
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

                // Top-Right Glass Outward Arrow Pill / Stay Tuned Pill
                isStatic
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
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
                    : Container(
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

  List<_CategoryData> _getCategories() {
    return [
      _CategoryData(
        title: "Expenses & Finance",
        subtitle: "Manage site expenses & verifications",
        icon: Icons.account_balance_wallet_rounded,
        color: primaryColor,
        items: [
          SubMenuItem(
            title: 'Supervisor Expenses',
            subtitle: 'Log and verify daily expenses',
            icon: Icons.monetization_on_rounded,
            color: primaryColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorVerificationPage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Material Requests",
        subtitle: "Request and track materials & supplies",
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF0284C7),
        items: [
          SubMenuItem(
            title: 'Materials Request Form',
            subtitle: 'Submit new material requests',
            icon: Icons.add_shopping_cart_rounded,
            color: const Color(0xFF0284C7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialRequestForm(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Material Approvals',
            subtitle: 'Check material request statuses',
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF0EA5E9),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorMaterialViewRequestScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Site Operations",
        subtitle: "Schedules, approvals & labour attendance",
        icon: Icons.engineering_rounded,
        color: const Color(0xFF10B981),
        items: [
          SubMenuItem(
            title: 'Work Schedule Request',
            subtitle: 'Manage site work timelines',
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF10B981),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupervisorWorkSchedulePage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Site Approvals',
            subtitle: 'View pending operational approvals',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF059669),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewApprovalScreen(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Workers Attendance',
            subtitle: 'Track worker daily attendance',
            icon: Icons.people_rounded,
            color: const Color(0xFF34D399),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceManagementPage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
        ],
      ),
      _CategoryData(
        title: "Inventory & Drawings",
        subtitle: "Manage materials, tools & construction plans",
        icon: Icons.construction_rounded,
        color: const Color(0xFF8B5CF6),
        items: [
          SubMenuItem(
            title: 'Materials at Site',
            subtitle: 'Live stock & materials inventory',
            icon: Icons.warehouse_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialAtSiteEntryPage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Tools at Site',
            subtitle: 'Live tool stock available at site',
            icon: Icons.home_repair_service_rounded,
            color: const Color(0xFF06B6D4),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ToolsAtSitePage(
                  supervisorId: widget.supervisorId,
                  supervisorName: widget.supervisorName,
                ),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Materials Info',
            subtitle: 'Material specifications catalog',
            icon: Icons.info_rounded,
            color: const Color(0xFFA855F7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorMaterialInfoScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Tools Movement',
            subtitle: 'Move tools between sites & company',
            icon: Icons.handyman_rounded,
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ToolsMovementPage(),
              ),
            ),
          ),
          SubMenuItem(
            title: 'Construction Drawings',
            subtitle: 'View architectural & layout plans',
            icon: Icons.architecture_rounded,
            color: const Color(0xFF6D28D9),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConstructionDocuments(),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
