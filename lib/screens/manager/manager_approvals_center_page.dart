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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

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
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: widget.hideAppBar
                ? null
                : AppBar(
                    iconTheme: const IconThemeData(color: Colors.white),
                    automaticallyImplyLeading: false,
                    leading: (widget.showBackButton ||
                            widget.onBack != null ||
                            Navigator.canPop(context))
                        ? IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          )
                        : null,
                    title: const Text(
                      'Approvals',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
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
                  ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Responsive.maxContentWidth,
                  ),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      // Quick Search Bar
                      _buildSearchBar(primaryColor),
                      const SizedBox(height: 16),

                      // Section Title
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Select Approval Category',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4 Clean, Easily Findable Category Cards
                      _buildCategoryCardsList(context, primaryColor),
                      const SizedBox(height: 20),

                      // Recent Pending Requisitions Preview
                      _buildPendingQuickPreview(context, primaryColor),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- SEARCH BAR ---
  Widget _buildSearchBar(Color primaryColor) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() => _searchQuery = val.trim().toLowerCase());
        },
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search payment, material, tools, workforce...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: primaryColor,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
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
    );
  }

  // --- 4 CLEAN CATEGORY CARDS ---
  Widget _buildCategoryCardsList(BuildContext context, Color primaryColor) {
    final categories = [
      _ApprovalItem(
        title: 'Site Payment Requests',
        subtitle: 'Approve site expenses, contractor & supervisor payments',
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
      _ApprovalItem(
        title: 'Material Requests',
        subtitle: 'Authorize raw materials & supply orders for sites',
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
      _ApprovalItem(
        title: 'Tools Requests',
        subtitle: 'Approve equipment movements & tools return requests',
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
      _ApprovalItem(
        title: 'Workforce Requests',
        subtitle: 'Review labour allocation & contractor work schedules',
        icon: Icons.groups_rounded,
        color: const Color(0xFF6366F1), // Indigo
        stream: FirestoreService.siteSupervisorProjectStageSchedule.snapshots(),
        pendingCountCalc: (snap) => snap.docs.where((d) {
          final status = d.data()['status']?.toString() ?? d.data()['approvalStatus']?.toString();
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
    ];

    final filtered = categories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      return cat.title.toLowerCase().contains(_searchQuery) ||
          cat.subtitle.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'No matching approval category',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _buildSimpleCategoryCard(context, item);
      },
    );
  }

  Widget _buildSimpleCategoryCard(BuildContext context, _ApprovalItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
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
                const SizedBox(width: 10),

                // Live Pending Pill & Arrow
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: item.stream,
                  builder: (context, snapshot) {
                    final count = snapshot.hasData
                        ? item.pendingCountCalc(snapshot.data!)
                        : 0;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.color,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- RECENT PENDING PREVIEW ---
  Widget _buildPendingQuickPreview(BuildContext context, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Recent Pending Requests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.getCollection('siteMaterialsRequest')
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final pendingDocs = docs.where((doc) {
              final status =
                  (doc.data()['status'] ?? '').toString().toLowerCase();
              return status.contains('process') || status.contains('pending');
            }).toList();

            if (pendingDocs.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'All material & tool requests are up to date.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: pendingDocs.map((doc) {
                final data = doc.data();
                final reqId = data['matReqId'] ?? doc.id;
                final siteId = data['siteId'] ?? 'N/A';
                final stage = data['projectStage'] ?? 'N/A';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFFE11D48),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request $reqId',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Site: $siteId • $stage',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFFE11D48),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ManagerMaterialApprovalScreen(),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'Review',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ApprovalItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(QuerySnapshot<Map<String, dynamic>>) pendingCountCalc;
  final VoidCallback onTap;

  _ApprovalItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.stream,
    required this.pendingCountCalc,
    required this.onTap,
  });
}
