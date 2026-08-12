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
import 'package:demo_cst/screens/manager/manager_expenses.dart';
import 'package:demo_cst/screens/supervisor/site_entry_page.dart';
import 'package:demo_cst/screens/manager/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/reports/material_report.dart';
import 'package:demo_cst/screens/organization/org_site_supervisor_daily_week_report.dart';
import 'package:demo_cst/screens/organization/organization_expenses.dart';
import 'package:demo_cst/screens/organization/organization_site_entry.dart';
import 'package:demo_cst/screens/reports/site_weekly_financial_report.dart';
import 'package:demo_cst/screens/reports/tools_inventory_report.dart';
import 'package:demo_cst/screens/manager/manager_approval_screen.dart';
import 'package:demo_cst/screens/organization/org_notification_page.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/manager/manager_config_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  _OrganizationDashboardState createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;
  String _userName = '';
  String _userRole = 'Organization Administrator';
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkSubscription();
    _startSubscriptionListener();
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

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
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

                  return GlassScaffold(
                    title: titleText,
                    actions: [
                      // Refresh / Sync Action Button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF0A183D),
                            size: 18,
                          ),
                        ),
                        tooltip: 'Sync Dashboard',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {});
                        },
                      ),
                      // Notifications Action Button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFF0A183D),
                            size: 18,
                          ),
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
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A183D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          tooltip: 'Main Menu',
                          onPressed: () => _navigateToOrgMenu(context),
                        ),
                      ),
                    ],
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

                                // 3. Quick Category Filter Bar
                                SliverToBoxAdapter(
                                  child: _buildCategoryFilterBar(
                                    context,
                                    theme,
                                  ),
                                ),

                                // 4. Categorized Feature Cards
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
    );
  }

  /// Header Banner showcasing User Welcome & Organization Status Pill
  Widget _buildWelcomeHeader(BuildContext context, ThemeData theme) {
    final hPad = Responsive.horizontalPadding(context);
    final darkAccent = AppTheme.getDarkAccent(theme.primaryColor);

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
              Color.alphaBlend(
                theme.primaryColor.withValues(alpha: 0.4),
                darkAccent,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: darkAccent.withValues(alpha: 0.3),
              blurRadius: 16,
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
            // Live Status Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.sensors_rounded,
                    color: Color(0xFF34D399),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
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
              // Section Title Header
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
                  if (isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A183D),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A183D).withValues(alpha: 0.08),
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
                ],
              ),
              const SizedBox(height: 12),

              // Stat Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 550;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 1.4 : 1.35,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // 1. Total Projects Stat Card
                      _buildStatCard(
                        title: 'Total Projects',
                        value: '$totalProjects',
                        subtitle: 'Registered portfolio',
                        icon: Icons.apartment_rounded,
                        accentColor: const Color(0xFF3B82F6), // Vibrant Blue
                        bgColor: const Color(0xFFEFF6FF),
                        textColor: const Color(0xFF1E40AF),
                      ),
                      // 2. Active / Ongoing Stat Card
                      _buildStatCard(
                        title: 'Ongoing / Active',
                        value: '$ongoingCount',
                        subtitle: 'In active execution',
                        icon: Icons.play_circle_fill_rounded,
                        accentColor: const Color(0xFF10B981), // Emerald Green
                        bgColor: const Color(0xFFECFDF5),
                        textColor: const Color(0xFF065F46),
                      ),
                      // 3. Completed Stat Card
                      _buildStatCard(
                        title: 'Completed',
                        value: '$completedCount',
                        subtitle: 'Successfully closed',
                        icon: Icons.check_circle_rounded,
                        accentColor: const Color(0xFF6366F1), // Indigo
                        bgColor: const Color(0xFFEEF2FF),
                        textColor: const Color(0xFF3730A3),
                      ),
                      // 4. Planning / On Hold Stat Card
                      _buildStatCard(
                        title: 'Planning / Hold',
                        value: '${planningCount + onHoldCount}',
                        subtitle: '$planningCount plan • $onHoldCount hold',
                        icon: Icons.pending_actions_rounded,
                        accentColor: const Color(0xFFF59E0B), // Amber
                        bgColor: const Color(0xFFFFFBEB),
                        textColor: const Color(0xFF92400E),
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
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 18,
                ),
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
              _buildLegendItem('Ongoing', '${(ongoingPct * 100).toStringAsFixed(0)}%', const Color(0xFF10B981)),
              _buildLegendItem('Completed', '${(completedPct * 100).toStringAsFixed(0)}%', const Color(0xFF3B82F6)),
              _buildLegendItem('Planning', '${(planningPct * 100).toStringAsFixed(0)}%', const Color(0xFFF59E0B)),
              _buildLegendItem('On Hold', '${(onHoldPct * 100).toStringAsFixed(0)}%', const Color(0xFFEF4444)),
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

  /// Quick Filter Bar for categories (All, Admin, Finance, Expenses, Approvals, Reports)
  Widget _buildCategoryFilterBar(BuildContext context, ThemeData theme) {
    final hPad = Responsive.horizontalPadding(context);
    final filters = [
      'All',
      'Administrative & Config',
      'Finance & Balance Sheets',
      'Expense Management',
      'Review & Approvals',
      'Reports & Insights',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedCategoryFilter == filter;
            final filterLabel = filter == 'All'
                ? 'All Categories'
                : filter.split(' ')[0]; // Shortened label for chips

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  filterLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF0A183D),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF0A183D),
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                elevation: isSelected ? 3 : 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0A183D)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategoryFilter = filter;
                    });
                  }
                },
              ),
            );
          }).toList(),
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
    final filteredCategories = _selectedCategoryFilter == 'All'
        ? allCategories
        : allCategories
            .where((c) => c.title == _selectedCategoryFilter)
            .toList();

    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    List<Widget> slivers = [];

    for (var category in filteredCategories) {
      if (category.items.isEmpty) continue;

      // Section Header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              Responsive.spacing(context, 16),
              hPad,
              Responsive.spacing(context, 10),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: darkCardBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A759E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: darkCardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${category.items.length}',
                    style: const TextStyle(
                      fontSize: 12,
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

      // Items List for this section
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = category.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildListItem(context, item),
              );
            }, childCount: category.items.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildListItem(BuildContext context, SubMenuItem item) {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: darkCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkCardBg.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Badge
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
                const SizedBox(width: 14),
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFCBD5E1),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Trailing Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_CategoryData> _getCategories(ThemeData theme) {
    final primary = theme.primaryColor;
    final secondary = theme.colorScheme.secondary;

    return [
      _CategoryData(
        title: "Administrative & Config",
        subtitle: "Manage accounts and system settings",
        icon: Icons.admin_panel_settings_rounded,
        color: primary,
        gradientColors: [primary, primary.withValues(alpha: 0.7)],
        items: [
          SubMenuItem(
            title: "Manager Account",
            subtitle: "Configure profiles and access permissions",
            icon: Icons.admin_panel_settings_rounded,
            color: primary,
            onTap: () => _navigateToConfiguration(context),
          ),
          SubMenuItem(
            title: "Manager Config",
            subtitle: "Create and manage manager profiles",
            icon: Icons.manage_accounts_rounded,
            color: primary,
            onTap: () => _navigateToManagerConfig(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Finance & Balance Sheets",
        subtitle: "Site payments, entries, and financial reports",
        icon: Icons.account_balance_wallet_rounded,
        color: primary.withBlue(150),
        gradientColors: [
          primary.withBlue(150),
          primary.withBlue(150).withValues(alpha: 0.7),
        ],
        items: [
          SubMenuItem(
            title: "Site Payment Entry",
            subtitle: "Record daily site transactions",
            icon: Icons.payments_rounded,
            color: primary.withBlue(150),
            onTap: () => _navigateToSitePaymentEntry(context),
          ),
          SubMenuItem(
            title: "Site Payment Report",
            subtitle: "Daily site-level financial reports",
            icon: Icons.receipt_long_rounded,
            color: primary.withBlue(180),
            onTap: () => _navigateToDailyReport(context),
          ),
          SubMenuItem(
            title: "Weekly Finance Report",
            subtitle: "Weekly financial health overview",
            icon: Icons.account_balance_rounded,
            color: primary.withBlue(210),
            onTap: () => _navigateToSiteWeeklyFinancialReport(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Expense Management",
        subtitle: "Track organization and field expenses",
        icon: Icons.money_rounded,
        color: secondary,
        gradientColors: [secondary, secondary.withValues(alpha: 0.7)],
        items: [
          SubMenuItem(
            title: "Organization Expenses",
            subtitle: "Central operational cost monitoring",
            icon: Icons.corporate_fare_rounded,
            color: secondary,
            onTap: () => _navigateToOrganizationExpenses(context),
          ),
          SubMenuItem(
            title: "Manager Expenses",
            subtitle: "Project management expenditures",
            icon: Icons.person_search_rounded,
            color: secondary.withValues(alpha: 0.9),
            onTap: () => _navigateToManagerExpenses(context),
          ),
          SubMenuItem(
            title: "Organisation Daily Entry",
            subtitle: "Log daily project progress and expenses",
            icon: Icons.edit_note_rounded,
            color: secondary.withValues(alpha: 0.8),
            onTap: () => _navigateToManagerDailyEntry(context),
          ),
          SubMenuItem(
            title: "Supervisor Daily Entry",
            subtitle: "Daily field-level operational expenses",
            icon: Icons.engineering_rounded,
            color: secondary.withValues(alpha: 0.7),
            onTap: () => _navigateToSiteExpenses(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Review & Approvals",
        subtitle: "Approve schedules, materials, and incentives",
        icon: Icons.fact_check_rounded,
        color: primary.withGreen(150),
        gradientColors: [
          primary.withGreen(150),
          primary.withGreen(150).withValues(alpha: 0.7),
        ],
        items: [
          SubMenuItem(
            title: "Schedule Request Approval",
            subtitle: "Approve project work schedules",
            icon: Icons.event_available_rounded,
            color: primary.withGreen(150),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Material Request Approval",
            subtitle: "Authorize material procurement",
            icon: Icons.inventory_2_rounded,
            color: primary.withGreen(180),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManagerMaterialApprovalScreen(),
              ),
            ),
          ),
          SubMenuItem(
            title: "Incentive Calculation",
            subtitle: "Process performance-based rewards",
            icon: Icons.calculate_rounded,
            color: primary.withGreen(210),
            onTap: () => _navigateToIncentiveCaliculation(context),
          ),
        ],
      ),
      _CategoryData(
        title: "Reports & Insights",
        subtitle: "Stock monitoring and tool analytics",
        icon: Icons.bar_chart_rounded,
        color: primary.withValues(alpha: 0.8),
        gradientColors: [primary.withValues(alpha: 0.8), primary.withValues(alpha: 0.5)],
        items: [
          SubMenuItem(
            title: "Advanced Financial Analytics",
            subtitle: "Detailed performance insights",
            icon: Icons.query_stats_rounded,
            color: primary.withValues(alpha: 0.8),
            onTap: () => _navigateToInsights(context),
          ),
          SubMenuItem(
            title: "Materials Inventory",
            subtitle: "Real-time stock monitoring",
            icon: Icons.inventory_rounded,
            color: primary.withValues(alpha: 0.7),
            onTap: () => _navigateToMaterialReport(context),
          ),
          SubMenuItem(
            title: "Tools Inventory",
            subtitle: "Track field equipment usage",
            icon: Icons.construction_rounded,
            color: primary.withValues(alpha: 0.6),
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

  void _navigateToManagerExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ManagerExpenses()),
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

  void _navigateToSiteExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const SiteEntryPage(userName: '', userDetails: {}),
    ),
  );

  void _navigateToOrgMenu(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const OrgMenuScreen(standalone: true),
    ),
  );
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<SubMenuItem> items;

  _CategoryData({
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
  final VoidCallback onTap;

  SubMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

