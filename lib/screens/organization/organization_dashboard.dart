import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/organization/org_site_payment_screen.dart';
import 'package:demo_cst/screens/reports/insights_dashboard.dart';
import 'package:demo_cst/screens/manager/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/organization/organization_expenses.dart';
import 'package:demo_cst/screens/reports/tools_inventory_report.dart';
import 'package:demo_cst/screens/manager/manager_approval_screen.dart';
import 'package:demo_cst/screens/organization/org_notification_page.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/screens/organization/org_menu_screen.dart';
import 'package:demo_cst/screens/organization/org_subscription_page.dart';
import 'package:demo_cst/screens/organization/org_sites_list_page.dart';
import 'package:demo_cst/screens/manager/manager_config_screen.dart';
import 'package:demo_cst/screens/manager/project_setup_wizard.dart';

class OrganizationDashboard extends StatefulWidget {
  const OrganizationDashboard({super.key});

  @override
  State<OrganizationDashboard> createState() => _OrganizationDashboardState();
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _subscriptionListener;
  String _userName = '';
  String _userRole = 'Organization Head';
  int _selectedNavIndex = 0;
  String _selectedKpiPeriod = 'Today';
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    setState(() {
      final name = userData['org_name'] ??
          userData['username'] ??
          userData['name'] ??
          fbUser?.displayName ??
          '';
      _userName = name.toString();
      _userRole = userData['role'] ?? 'Organization Head';
    });
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
    _subscriptionListener?.cancel();
    _scrollController.dispose();
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
                final darkAccent = AppTheme.getDarkAccent(primaryColor);

                return Scaffold(
                  backgroundColor: const Color(0xFFF9FAFC),
                  bottomNavigationBar: _buildBottomNavigationBar(
                    primaryColor,
                    darkAccent,
                  ),
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
                            // 1. Top Header (Greeting, User Name, Role, Notification, Avatar)
                            SliverToBoxAdapter(
                              child: _buildHeader(context, primaryColor),
                            ),

                            // 2. Dashboard KPIs Overview (Real-time dynamic data)
                            SliverToBoxAdapter(
                              child: _buildKPIsOverview(context, primaryColor),
                            ),

                            // 3. Site Status (Planning, In Progress, Overdue, Pending)
                            SliverToBoxAdapter(
                              child: _buildSiteStatusSection(
                                context,
                                primaryColor,
                              ),
                            ),

                            // 4. Quick Actions (8 shortcuts)
                            SliverToBoxAdapter(
                              child: _buildQuickActionsSection(
                                context,
                                primaryColor,
                              ),
                            ),

                            const SliverToBoxAdapter(
                              child: SizedBox(height: 30),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Greeting, Name, Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName.isNotEmpty ? _userName : 'Organization',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _userRole,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
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
                stream: FirestoreService.getCollection(
                  'notifications',
                ).snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

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
                              color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
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
                                  fontSize: 10,
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
              const SizedBox(width: 12),

              // Profile Avatar
              GestureDetector(
                onTap: () => _navigateToOrgMenu(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'O',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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

  // -------------------- 2. KPIS OVERVIEW --------------------

  Widget _buildKPIsOverview(BuildContext context, Color primaryColor) {
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Dropdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'KPIs Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              // Filter Dropdown Pill
              PopupMenuButton<String>(
                initialValue: _selectedKpiPeriod,
                onSelected: (val) => setState(() => _selectedKpiPeriod = val),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
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
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                  const PopupMenuItem(value: 'This Week', child: Text('This Week')),
                  const PopupMenuItem(value: 'This Month', child: Text('This Month')),
                  const PopupMenuItem(value: 'All Time', child: Text('All Time')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Streams for real-time project metrics & financial metrics
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.projects.snapshots(),
            builder: (context, projSnap) {
              final projDocs = projSnap.hasData ? projSnap.data!.docs : [];
              int activeSitesCount = 0;
              int projectsInProgressCount = 0;
              double totalAmountSpent = 0.0;
              double totalAmountBalance = 0.0;
              double totalAmountPaid = 0.0;

              for (var doc in projDocs) {
                final data = doc.data();
                final status =
                    (data['currentStatus'] ?? data['status'] ?? 'Ongoing')
                        .toString()
                        .toLowerCase();

                if (status.contains('ongoing') ||
                    status.contains('active') ||
                    status.contains('progress') ||
                    status.contains('execution')) {
                  projectsInProgressCount++;
                  activeSitesCount++;
                } else if (!status.contains('complete') &&
                    !status.contains('finish') &&
                    !status.contains('closed')) {
                  activeSitesCount++;
                }

                if (data['amountSpent'] is num) {
                  totalAmountSpent += (data['amountSpent'] as num).toDouble();
                }
                if (data['amountBalance'] is num) {
                  totalAmountBalance += (data['amountBalance'] as num).toDouble();
                }
                if (data['amountPaid'] is num) {
                  totalAmountPaid += (data['amountPaid'] as num).toDouble();
                }
              }

              final displayActiveSites = activeSitesCount < 10
                  ? '0$activeSitesCount'
                  : '$activeSitesCount';
              final displayProjects = projectsInProgressCount < 10
                  ? '0$projectsInProgressCount'
                  : '$projectsInProgressCount';

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService.getCollection('materialRequests').snapshots(),
                builder: (context, matSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirestoreService.siteSupervisorProjectStageSchedule.snapshots(),
                    builder: (context, wsSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirestoreService.getCollection('supervisor_requests').snapshots(),
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

                          // Real-time Expense Stream
                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirestoreService.getCollection('totalSiteExpensesPerDay').snapshots(),
                            builder: (context, expSnap) {
                              double computedExpenses = 0.0;
                              final now = DateTime.now();
                              final todayStr1 = DateFormat('yyyy-MM-dd').format(now);
                              final todayStr2 = DateFormat('dd-MM-yyyy').format(now);
                              final todayStr3 = DateFormat('d-M-yyyy').format(now);
                              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                              final startOfMonth = DateTime(now.year, now.month, 1);

                              if (expSnap.hasData) {
                                for (var doc in expSnap.data!.docs) {
                                  final data = doc.data();
                                  double amount = 0.0;
                                  if (data['totalAllExpenses'] is num) {
                                    amount = (data['totalAllExpenses'] as num).toDouble();
                                  } else {
                                    final sExp = (data['totalSiteExpense'] is num ? (data['totalSiteExpense'] as num).toDouble() : 0.0);
                                    final mExp = (data['totalMgrExpense'] is num ? (data['totalMgrExpense'] as num).toDouble() : 0.0);
                                    final oExp = (data['totalOrgExpense'] is num ? (data['totalOrgExpense'] as num).toDouble() : 0.0);
                                    final cExp = (data['totalContractorExpense'] is num ? (data['totalContractorExpense'] as num).toDouble() : 0.0);
                                    final iExp = (data['totalIncentiveExpenses'] is num ? (data['totalIncentiveExpenses'] as num).toDouble() : 0.0);
                                    amount = sExp + mExp + oExp + cExp + iExp;
                                  }

                                  final docDateStr = (data['date'] ?? '').toString();
                                  DateTime? docDate;
                                  if (data['updatedAt'] is Timestamp) {
                                    docDate = (data['updatedAt'] as Timestamp).toDate();
                                  } else if (data['timestamp'] is Timestamp) {
                                    docDate = (data['timestamp'] as Timestamp).toDate();
                                  } else if (docDateStr.isNotEmpty) {
                                    try {
                                      docDate = DateTime.tryParse(docDateStr);
                                    } catch (_) {}
                                  }

                                  if (_selectedKpiPeriod == 'Today') {
                                    if (docDateStr == todayStr1 ||
                                        docDateStr == todayStr2 ||
                                        docDateStr == todayStr3 ||
                                        (docDate != null &&
                                            docDate.year == now.year &&
                                            docDate.month == now.month &&
                                            docDate.day == now.day)) {
                                      computedExpenses += amount;
                                    }
                                  } else if (_selectedKpiPeriod == 'This Week') {
                                    if (docDate != null && docDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                                      computedExpenses += amount;
                                    } else if (docDate == null) {
                                      computedExpenses += amount;
                                    }
                                  } else if (_selectedKpiPeriod == 'This Month') {
                                    if (docDate != null && docDate.isAfter(startOfMonth.subtract(const Duration(days: 1)))) {
                                      computedExpenses += amount;
                                    } else if (docDate == null) {
                                      computedExpenses += amount;
                                    }
                                  } else {
                                    // 'All Time'
                                    computedExpenses += amount;
                                  }
                                }
                              }

                              if (computedExpenses == 0.0 && _selectedKpiPeriod == 'All Time') {
                                computedExpenses = totalAmountSpent;
                              }

                              double availableBalance = totalAmountBalance;
                              if (availableBalance <= 0.0 && totalAmountPaid > 0.0) {
                                availableBalance = totalAmountPaid - totalAmountSpent;
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

                              return Column(
                                children: [
                                  // 2x2 Grid Summary Cards
                                  Row(
                                    children: [
                                      // Card 1: Active Sites (Soft Blue)
                                      Expanded(
                                        child: _buildKpiCard(
                                          value: displayActiveSites,
                                          label: 'Active Sites',
                                          valueColor: const Color(0xFF2563EB),
                                          labelColor: const Color(0xFF2563EB),
                                          bgColor: const Color(0xFFEEF5FF),
                                          borderColor: const Color(0xFFDBEAFE),
                                          onTap: () => _navigateToSitesList(context, 'All'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Card 2: Projects In Progress (Soft Grey/Ice)
                                      Expanded(
                                        child: _buildKpiCard(
                                          value: displayProjects,
                                          label: 'Projects In Progress',
                                          valueColor: const Color(0xFF0F172A),
                                          labelColor: const Color(0xFF64748B),
                                          bgColor: const Color(0xFFF8FAFC),
                                          borderColor: const Color(0xFFE2E8F0),
                                          onTap: () => _navigateToSitesList(context, 'In Progress'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Card 3: Pending Approvals (Soft Amber)
                                      Expanded(
                                        child: _buildKpiCard(
                                          value: displayPending,
                                          label: 'Pending Approvals',
                                          valueColor: const Color(0xFF0F172A),
                                          labelColor: const Color(0xFFD97706),
                                          bgColor: const Color(0xFFFFFBEB),
                                          borderColor: const Color(0xFFFEF3C7),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const ManagerApprovalScreen(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Card 4: Expenses (Soft Rose/Pink)
                                      Expanded(
                                        child: _buildKpiCard(
                                          value: displayExpenses,
                                          prefix: '₹ ',
                                          prefixColor: const Color(0xFFDC2626),
                                          label: expenseLabel,
                                          valueColor: const Color(0xFF0F172A),
                                          labelColor: const Color(0xFF64748B),
                                          bgColor: const Color(0xFFFEF2F2),
                                          borderColor: const Color(0xFFFEE2E2),
                                          onTap: () => _navigateToOrganizationExpenses(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Full-Width Card: Available Balance (Soft Mint)
                                  InkWell(
                                    onTap: () => _navigateToSitePaymentEntry(context),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFDCFCE7),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                const TextSpan(
                                                  text: '₹ ',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: displayBalance,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF16A34A),
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Available Balance',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF22C55E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String value,
    String? prefix,
    Color? prefixColor,
    required String label,
    required Color valueColor,
    required Color labelColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  if (prefix != null)
                    TextSpan(
                      text: prefix,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: prefixColor ?? valueColor,
                      ),
                    ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- 3. SITE STATUS SECTION --------------------

  Widget _buildSiteStatusSection(BuildContext context, Color primaryColor) {
    final hPad = Responsive.horizontalPadding(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.projects.snapshots(),
      builder: (context, snapshot) {
        int planningCount = 0;
        int inProgressCount = 0;
        int overdueCount = 0;
        int pendingCount = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final s = (data['currentStatus'] ?? data['status'] ?? '').toString().toLowerCase();

            DateTime? endDate;
            if (data['endDate'] is Timestamp) {
              endDate = (data['endDate'] as Timestamp).toDate();
            } else if (data['expectedCompletionDate'] is Timestamp) {
              endDate = (data['expectedCompletionDate'] as Timestamp).toDate();
            }

            final isDelayed = s.contains('delay') ||
                s.contains('overdue') ||
                (endDate != null && endDate.isBefore(now) && !s.contains('complete') && !s.contains('finish'));

            if (isDelayed) {
              overdueCount++;
            } else if (s.contains('plan') || s.contains('draft') || s.contains('upcoming') || s.contains('setup')) {
              planningCount++;
            } else if (s.contains('progress') || s.contains('ongoing') || s.contains('active') || s.contains('execution')) {
              inProgressCount++;
            } else if (s.contains('hold') || s.contains('pending') || s.contains('pause') || s.contains('suspend')) {
              pendingCount++;
            } else if (!s.contains('complete') && !s.contains('finish')) {
              inProgressCount++;
            }
          }
        }

        final planStr = planningCount < 10 ? '0$planningCount' : '$planningCount';
        final progStr = inProgressCount < 10 ? '0$inProgressCount' : '$inProgressCount';
        final overStr = overdueCount < 10 ? '0$overdueCount' : '$overdueCount';
        final pendStr = pendingCount < 10 ? '0$pendingCount' : '$pendingCount';

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Site Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  InkWell(
                    onTap: () => _navigateToSitesList(context, 'All'),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4 Status Cards Row (Real-time computed data)
              Row(
                children: [
                  Expanded(
                    child: _buildStatusCard(
                      title: 'Planning',
                      count: planStr,
                      icon: Icons.architecture_rounded,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      countColor: const Color(0xFF2563EB),
                      onTap: () => _navigateToSitesList(context, 'Planning'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusCard(
                      title: 'In Progress',
                      count: progStr,
                      icon: Icons.engineering_rounded,
                      iconBgColor: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      countColor: const Color(0xFF16A34A),
                      onTap: () => _navigateToSitesList(context, 'In Progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusCard(
                      title: 'Overdue',
                      count: overStr,
                      icon: Icons.access_time_filled_rounded,
                      iconBgColor: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                      countColor: const Color(0xFFD97706),
                      onTap: () => _navigateToSitesList(context, 'On Hold'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusCard(
                      title: 'Pending',
                      count: pendStr,
                      icon: Icons.hourglass_top_rounded,
                      iconBgColor: const Color(0xFFFEF2F2),
                      iconColor: const Color(0xFFDC2626),
                      countColor: const Color(0xFFDC2626),
                      onTap: () => _navigateToSitesList(context, 'On Hold'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String count,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color countColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A183D).withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: countColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- 4. QUICK ACTIONS SECTION --------------------

  Widget _buildQuickActionsSection(BuildContext context, Color primaryColor) {
    final hPad = Responsive.horizontalPadding(context);

    final actions = [
      {
        'title': 'Add Expense',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFFEF4444),
        'bgColor': const Color(0xFFFEF2F2),
        'onTap': () => _navigateToOrganizationExpenses(context),
      },
      {
        'title': 'Site Payment',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEFF6FF),
        'onTap': () => _navigateToSitePaymentEntry(context),
      },
      {
        'title': 'Approvals',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFFF97316),
        'bgColor': const Color(0xFFFFF7ED),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerApprovalScreen(),
          ),
        ),
      },
      {
        'title': 'Add Site',
        'icon': Icons.person_pin_circle_rounded,
        'color': const Color(0xFFA855F7),
        'bgColor': const Color(0xFFFAF5FF),
        'onTap': () => _navigateToCreateProject(context),
      },
      {
        'title': 'Manager Account',
        'icon': Icons.manage_accounts_rounded,
        'color': const Color(0xFF4F46E5),
        'bgColor': const Color(0xFFEEF2FF),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerConfigScreen(),
          ),
        ),
      },
      {
        'title': 'Material Request',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFFF43F5E),
        'bgColor': const Color(0xFFFFF1F2),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerMaterialApprovalScreen(),
          ),
        ),
      },
      {
        'title': 'Workforce Request',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF0D9488),
        'bgColor': const Color(0xFFF0FDFA),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerApprovalScreen(),
          ),
        ),
      },
      {
        'title': 'Tool Movement',
        'icon': Icons.construction_rounded,
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFEFCE8),
        'onTap': () => _navigateToToolsInventory(context),
      },
      {
        'title': 'More',
        'icon': Icons.more_horiz_rounded,
        'color': const Color(0xFF475569),
        'bgColor': const Color(0xFFF1F5F9),
        'onTap': () => _navigateToOrgMenu(context),
      },
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final item = actions[index];
              return _buildQuickActionButton(
                title: item['title'] as String,
                icon: item['icon'] as IconData,
                iconColor: item['color'] as Color,
                bgColor: item['bgColor'] as Color,
                onTap: item['onTap'] as VoidCallback,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------- 5. BOTTOM NAVIGATION BAR --------------------

  Widget _buildBottomNavigationBar(Color primaryColor, Color darkAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: () => setState(() => _selectedNavIndex = 0),
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.domain_rounded,
                label: 'Sites',
                onTap: () => _navigateToSitesList(context),
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Finance',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _navigateToSitePaymentEntry(context);
                },
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _navigateToInsights(context);
                },
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.grid_view_rounded,
                label: 'More',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _navigateToOrgMenu(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedNavIndex == index;
    const activeColor = Color(0xFF1E40AF); // Deep modern blue matching image

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
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

  void _navigateToInsights(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => InsightsDashboard()),
  );

  void _navigateToSitePaymentEntry(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => SitePaymentScreen()),
  );

  void _navigateToOrganizationExpenses(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => OrganizationExpenses()),
  );

  void _navigateToToolsInventory(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ToolsInventoryPage()),
  );

  void _navigateToCreateProject(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProjectSetupWizard(),
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
