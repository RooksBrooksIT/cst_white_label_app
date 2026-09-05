import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';
import 'package:demo_cst/services/approval_workflow_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/manager_material_approval_screen.dart';
import 'package:demo_cst/screens/manager/manager_tools_approval_screen.dart';
import 'package:demo_cst/screens/manager/manager_site_payment_approval_page.dart';
import 'package:demo_cst/screens/manager/manager_approval_screen.dart';
import 'package:demo_cst/screens/manager/manager_petty_cash_page.dart';

class ManagerApprovalsCenterPage extends StatefulWidget {
  final bool hideAppBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ManagerApprovalsCenterPage({
    super.key,
    this.hideAppBar = false,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<ManagerApprovalsCenterPage> createState() =>
      _ManagerApprovalsCenterPageState();
}

class _ManagerApprovalsCenterPageState
    extends State<ManagerApprovalsCenterPage> {
  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final dynamicGradientColors =
            AppTheme.getBackgroundGradientColors(primaryColor);

        return PopScope(
          canPop: widget.onBack == null && Navigator.canPop(context),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
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
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 680,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Executive Header
                        if (!widget.hideAppBar)
                          _buildHeader(context, primaryColor),

                        // Main Scrollable Content
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 115),
                            children: [
                              // Hero Stat Overview Banner
                              _buildApprovalSummaryBanner(primaryColor),
                              const SizedBox(height: 18),

                              // Section Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Approval Modules',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.grid_view_rounded,
                                          size: 13,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '4 Workflows',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 2x2 Bento Cards Grid / Modules
                              _buildCategoryBentoGrid(context, primaryColor),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
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

  // --- HEADER ---
  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if ((widget.showBackButton && Navigator.canPop(context)) ||
              widget.onBack != null)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Approvals',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Desk',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review & authorize site operational requests',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EXECUTIVE SUMMARY STATS BANNER ---
  Widget _buildApprovalSummaryBanner(Color primaryColor) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection('siteMaterialsRequest').snapshots(),
      builder: (context, matSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.getCollection('siteSupervisorEntries').snapshots(),
          builder: (context, paySnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.getCollection('siteToolsRequest').snapshots(),
              builder: (context, toolSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.siteSupervisorProjectStageSchedule.snapshots(),
                  builder: (context, wfSnap) {
                    int matCount = 0;
                    if (matSnap.hasData) {
                      matCount = matSnap.data!.docs.where((d) {
                        final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
                        return stage == ApprovalStage.pendingManagerReview ||
                            stage == ApprovalStage.pendingManagerClearance;
                      }).length;
                    }

                    int payCount = 0;
                    if (paySnap.hasData) {
                      payCount = paySnap.data!.docs.where((d) {
                        final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
                        return stage == ApprovalStage.pendingManagerReview ||
                            stage == ApprovalStage.pendingManagerClearance;
                      }).length;
                    }

                    int toolCount = 0;
                    if (toolSnap.hasData) {
                      toolCount = toolSnap.data!.docs.where((d) {
                        final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
                        return stage == ApprovalStage.pendingManagerReview ||
                            stage == ApprovalStage.pendingManagerClearance;
                      }).length;
                    }

                    int wfCount = 0;
                    if (wfSnap.hasData) {
                      wfCount = wfSnap.data!.docs.where((d) {
                        final status = d.data()['status']?.toString() ??
                            d.data()['approvalStatus']?.toString();
                        final stage = ApprovalWorkflowService.parseStatus(status);
                        return stage == ApprovalStage.pendingManagerReview ||
                            stage == ApprovalStage.pendingManagerClearance;
                      }).length;
                    }

                    final totalPending = matCount + payCount + toolCount + wfCount;

                    return Container(
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
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      AppTheme.getDarkAccent(primaryColor),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Pending Requisitions',
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: totalPending > 0
                                                ? const Color(0xFFEF4444)
                                                    .withValues(alpha: 0.12)
                                                : const Color(0xFF10B981)
                                                    .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            totalPending > 0
                                                ? '$totalPending Action Required'
                                                : 'All Cleared',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: totalPending > 0
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      totalPending > 0
                                          ? 'Total $totalPending requests awaiting managerial approval'
                                          : 'No overdue requests pending review right now',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // 4 Quick Mini Stat Chips
                          Row(
                            children: [
                              _buildMiniStatBadge(
                                label: 'Payment',
                                count: payCount,
                                color: const Color(0xFF059669),
                              ),
                              const SizedBox(width: 8),
                              _buildMiniStatBadge(
                                label: 'Material',
                                count: matCount,
                                color: const Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 8),
                              _buildMiniStatBadge(
                                label: 'Tools',
                                count: toolCount,
                                color: const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              _buildMiniStatBadge(
                                label: 'Workforce',
                                count: wfCount,
                                color: const Color(0xFF6366F1),
                              ),
                            ],
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
      },
    );
  }

  Widget _buildMiniStatBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    final hasPending = count > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: hasPending
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPending
                ? color.withValues(alpha: 0.25)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: hasPending ? color : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: hasPending ? color : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- 2X2 BENTO CARDS GRID ---
  Widget _buildCategoryBentoGrid(BuildContext context, Color primaryColor) {
    final categories = [
      _ApprovalCategoryData(
        id: 'Payments',
        title: 'Site Payments',
        categoryTag: 'Finance',
        subtitle: 'Expenses, contractor invoices & supervisor claims',
        icon: Icons.payments_rounded,
        color: const Color(0xFF059669), // Emerald
        stream: FirestoreService.getCollection('siteSupervisorEntries').snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
          return stage == ApprovalStage.pendingManagerReview ||
              stage == ApprovalStage.pendingManagerClearance;
        }).length,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerSitePaymentApprovalPage(),
            ),
          );
        },
      ),
      _ApprovalCategoryData(
        id: 'Materials',
        title: 'Material Orders',
        categoryTag: 'Supplies',
        subtitle: 'Authorize cement, steel, sand & raw requisitions',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFE11D48), // Rose Red
        stream: FirestoreService.getCollection('siteMaterialsRequest').snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
          return stage == ApprovalStage.pendingManagerReview ||
              stage == ApprovalStage.pendingManagerClearance;
        }).length,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerMaterialApprovalScreen(),
            ),
          );
        },
      ),
      _ApprovalCategoryData(
        id: 'Tools',
        title: 'Tools & Plant',
        categoryTag: 'Machinery',
        subtitle: 'Equipment allocation, machine dispatch & returns',
        icon: Icons.construction_rounded,
        color: const Color(0xFFD97706), // Amber
        stream: FirestoreService.getCollection('siteToolsRequest').snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final stage = ApprovalWorkflowService.parseStatus(d.data()['status']);
          return stage == ApprovalStage.pendingManagerReview ||
              stage == ApprovalStage.pendingManagerClearance;
        }).length,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerToolsApprovalScreen(),
            ),
          );
        },
      ),
      _ApprovalCategoryData(
        id: 'Workforce',
        title: 'Workforce & Stages',
        categoryTag: 'Operations',
        subtitle: 'Labour allocation, contractors & stage sign-offs',
        icon: Icons.groups_rounded,
        color: const Color(0xFF6366F1), // Indigo
        stream: FirestoreService.siteSupervisorProjectStageSchedule.snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final status = d.data()['status']?.toString() ??
              d.data()['approvalStatus']?.toString();
          final stage = ApprovalWorkflowService.parseStatus(status);
          return stage == ApprovalStage.pendingManagerReview ||
              stage == ApprovalStage.pendingManagerClearance;
        }).length,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerApprovalScreen(),
            ),
          );
        },
      ),
      _ApprovalCategoryData(
        id: 'PettyCash',
        title: 'Petty Cash',
        categoryTag: 'Finance',
        subtitle: 'Review supervisor requests & allocate petty cash',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981), // Emerald
        stream: FirestoreService.pettyCashRequests.snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final status = d.data()['status']?.toString();
          final stage = ApprovalWorkflowService.parseStatus(status);
          return stage == ApprovalStage.pendingManagerReview ||
              stage == ApprovalStage.pendingManagerClearance ||
              status == 'org_approved';
        }).length,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerPettyCashPage(),
            ),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCol = constraints.maxWidth >= 340;
        final itemWidth = isTwoCol
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: categories.map((cat) {
            return SizedBox(
              width: itemWidth,
              child: _buildBentoCardModule(context, cat),
            );
          }).toList(),
        );
      },
    );
  }

  // --- MODERN BENTO CARD MODULE ---
  Widget _buildBentoCardModule(
    BuildContext context,
    _ApprovalCategoryData item,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: item.color.withValues(alpha: 0.1),
          highlightColor: item.color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Icon Box + Live Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.color.withValues(alpha: 0.18),
                            item.color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color,
                        size: 22,
                      ),
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: item.stream,
                      builder: (context, snapshot) {
                        final count = snapshot.hasData
                            ? item.pendingCountCalc(snapshot.data!)
                            : 0;

                        if (count == 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                item.color,
                                item.color.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count Pending',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Subtitle
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Action Footer Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.categoryTag,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: item.color,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: item.color,
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

class _ApprovalCategoryData {
  final String id;
  final String title;
  final String categoryTag;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(QuerySnapshot<Map<String, dynamic>>) pendingCountCalc;
  final VoidCallback onTap;

  _ApprovalCategoryData({
    required this.id,
    required this.title,
    required this.categoryTag,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.stream,
    required this.pendingCountCalc,
    required this.onTap,
  });
}
