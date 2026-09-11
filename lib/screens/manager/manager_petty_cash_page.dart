import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../services/auth_service.dart';
import '../../services/approval_workflow_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class ManagerPettyCashPage extends StatefulWidget {
  final int initialTabIndex;
  const ManagerPettyCashPage({super.key, this.initialTabIndex = 0});

  @override
  State<ManagerPettyCashPage> createState() => _ManagerPettyCashPageState();
}

class _ManagerPettyCashPageState extends State<ManagerPettyCashPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PettyCashService _pettyCashService = PettyCashService();

  String _searchQuery = '';
  String _reportPeriod = 'This Month';

  // Site-Wise Filter States
  String _siteSearchQuery = '';
  String _selectedSiteFilter = 'All';
  String _selectedProjectFilter = 'All';
  String _selectedSupervisorFilter = 'All';
  String _selectedCategoryFilter = 'All';
  String _selectedTimeframe = 'All Time'; // 'All Time', 'Today', 'This Month', 'Custom'
  DateTime? _siteFromDate;
  DateTime? _siteToDate;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  String get _currentManagerName {
    final ud = AuthService().userData;
    return (ud['name'] ?? ud['userName'] ?? ud['username'] ?? 'Manager').toString();
  }

  String get _currentManagerId {
    final ud = AuthService().userData;
    return (ud['userId'] ?? ud['id'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manager Petty Cash Portal',
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.rate_review_rounded, size: 18), text: 'Reviews'),
            Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Allocations'),
            Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'Site-Wise'),
            Tab(icon: Icon(Icons.supervisor_account_rounded, size: 18), text: 'Supervisors'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Ledger'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Reports'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualAllocationDialog(context),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text(
          'Manual Allocation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KPI Summary Header
            _buildExecutiveSummaryBanner(),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReviewsTab(),
                  _buildAllocationsTab(),
                  _buildSiteWiseTab(),
                  _buildSupervisorsTab(),
                  _buildLedgerTab(),
                  _buildReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. EXECUTIVE KPI SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildExecutiveSummaryBanner() {
    return StreamBuilder<List<PettyCashAccount>>(
      stream: _pettyCashService.streamAllAccounts(),
      builder: (context, accSnap) {
        return StreamBuilder<List<PettyCashRequest>>(
          stream: _pettyCashService.streamAllRequests(),
          builder: (context, reqSnap) {
            final accounts = accSnap.data ?? [];
            final requests = reqSnap.data ?? [];

            double totalAllocated = 0.0;
            double totalUsed = 0.0;
            double totalRemaining = 0.0;
            int lowBalanceCount = 0;

            for (final a in accounts) {
              totalAllocated += a.totalAllocated;
              totalUsed += a.totalUsed;
              totalRemaining += a.availableBalance;
              if (a.isLowBalance) lowBalanceCount++;
            }

            final pendingReviews = requests.where((r) =>
                r.status == ApprovalWorkflowService.statusPendingManagerReview ||
                ApprovalWorkflowService.parseStatus(r.status) == ApprovalStage.pendingManagerReview).length;
            final readyForAlloc = requests.where((r) =>
                r.status == ApprovalWorkflowService.statusPendingManagerClearance ||
                r.status == 'org_approved' ||
                ApprovalWorkflowService.parseStatus(r.status) == ApprovalStage.pendingManagerClearance).length;

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniKpi(
                          label: 'Allocated',
                          amount: PettyCashService.formatCurrency(totalAllocated),
                          color: const Color(0xFF2563EB),
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniKpi(
                          label: 'Consumed',
                          amount: PettyCashService.formatCurrency(totalUsed),
                          color: const Color(0xFFF59E0B),
                          icon: Icons.shopping_cart_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniKpi(
                          label: 'Balance',
                          amount: PettyCashService.formatCurrency(totalRemaining),
                          color: const Color(0xFF10B981),
                          icon: Icons.savings_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Pill indicators for Pending Reviews, Allocations, and Low Balance
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (pendingReviews > 0)
                          _buildStatusPill(
                            label: '$pendingReviews Awaiting Review',
                            color: const Color(0xFFEF4444),
                            onTap: () => _tabController.animateTo(0),
                          ),
                        if (readyForAlloc > 0) ...[
                          const SizedBox(width: 6),
                          _buildStatusPill(
                            label: '$readyForAlloc Ready to Allocate',
                            color: const Color(0xFF10B981),
                            onTap: () => _tabController.animateTo(1),
                          ),
                        ],
                        if (lowBalanceCount > 0) ...[
                          const SizedBox(width: 6),
                          _buildStatusPill(
                            label: '$lowBalanceCount Low Balance',
                            color: const Color(0xFFD97706),
                            onTap: () => _tabController.animateTo(2),
                          ),
                        ],
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
  }

  Widget _buildMiniKpi({
    required String label,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TAB 1: PENDING REVIEWS (STAGE 1 -> STAGE 2)
  // ---------------------------------------------------------------------------

  Widget _buildReviewsTab() {
    return StreamBuilder<List<PettyCashRequest>>(
      stream: _pettyCashService.streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        final pendingReviews = requests
            .where((r) =>
                r.status == ApprovalWorkflowService.statusPendingManagerReview ||
                ApprovalWorkflowService.parseStatus(r.status) == ApprovalStage.pendingManagerReview)
            .toList();

        if (pendingReviews.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No pending requests for review',
            subtitle: 'All supervisor petty cash requests have been reviewed.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pendingReviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = pendingReviews[index];
            return _buildReviewCard(req);
          },
        );
      },
    );
  }

  Widget _buildReviewCard(PettyCashRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        req.supervisorName.isNotEmpty ? req.supervisorName[0].toUpperCase() : 'S',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.supervisorName,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${req.supervisorId}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PettyCashService.formatCurrency(req.requestedAmount > 0 ? req.requestedAmount : req.allocatedAmount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    req.isManualManager
                        ? 'Manager Allocation'
                        : (req.isReplenishment ? 'Replenishment' : 'Supervisor Request'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: req.isManualManager
                          ? const Color(0xFF7E22CE)
                          : (req.isReplenishment ? const Color(0xFF0F766E) : const Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Site & Project Badges
          if (req.siteName != null || req.siteId != null || req.projectName != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (req.siteName != null || req.siteId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${req.siteName ?? req.siteId}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                if (req.projectName != null && req.projectName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          req.projectName!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (req.isSitePaymentLinked || (req.siteName != null && req.siteName!.isNotEmpty)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Linked Site Payment: ${req.linkedSitePaymentTitle ?? req.siteName ?? req.siteId}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Context Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Current Bal: ${PettyCashService.formatCurrency(req.currentBalanceAtRequest)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total Alloc: ${PettyCashService.formatCurrency(req.totalAllocatedAtRequest)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Justification: ${req.reason}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
          ),
          if (req.remarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Remarks: ${req.remarks}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),

          // Action Buttons: Approve & Forward vs Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(req),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showForwardDialog(req),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Verify & Forward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TAB 2: APPROVED ALLOCATIONS (STAGE 3 -> STAGE 4)
  // ---------------------------------------------------------------------------

  Widget _buildAllocationsTab() {
    return StreamBuilder<List<PettyCashRequest>>(
      stream: _pettyCashService.streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        final approvedForClearance = requests
            .where((r) =>
                r.status == ApprovalWorkflowService.statusPendingManagerClearance ||
                r.status == 'org_approved')
            .toList();

        if (approvedForClearance.isEmpty) {
          return _buildEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No pending allocations',
            subtitle: 'Requests authorized by Organization HQ will appear here for fund release.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: approvedForClearance.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = approvedForClearance[index];
            return _buildAllocationCard(req);
          },
        );
      },
    );
  }

  Widget _buildAllocationCard(PettyCashRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Approved badge, Source Badge & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'HQ AUTHORIZED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: req.isManualManager ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: req.isManualManager ? const Color(0xFFE9D5FF) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Text(
                      req.isManualManager ? 'MANUAL' : 'REQUEST',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: req.isManualManager ? const Color(0xFF7E22CE) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                PettyCashService.formatCurrency(req.approvedAmount > 0 ? req.approvedAmount : req.requestedAmount),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            'Supervisor: ${req.supervisorName} (${req.supervisorId})',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          // Site & Project Badges
          if (req.siteName != null || req.siteId != null || req.projectName != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (req.siteName != null || req.siteId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${req.siteName ?? req.siteId}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                if (req.projectName != null && req.projectName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          req.projectName!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'Reason: ${req.reason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          if (req.isSitePaymentLinked || (req.siteName != null && req.siteName!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Linked Site Payment: ${req.linkedSitePaymentTitle ?? req.siteName ?? req.siteId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (req.orgApprovalRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'HQ Remarks: ${req.orgApprovalRemarks}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
            ),
          ],
          const SizedBox(height: 14),

          // Release Cash Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAllocateConfirmationDialog(req),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Confirm & Allocate Cash', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TAB 2: SITE-WISE PETTY CASH TRACKING & BALANCES
  // ---------------------------------------------------------------------------

  Widget _buildSiteWiseTab() {
    return StreamBuilder<List<PettyCashRequest>>(
      stream: _pettyCashService.streamAllRequests(),
      builder: (context, reqSnap) {
        return StreamBuilder<List<PettyCashTransaction>>(
          stream: _pettyCashService.streamAllTransactions(),
          builder: (context, txnSnap) {
            if (reqSnap.connectionState == ConnectionState.waiting ||
                txnSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allRequests = reqSnap.data ?? [];
            final allTransactions = txnSnap.data ?? [];

            // Compute Date Range from Timeframe
            DateTime? filterFromDate = _siteFromDate;
            DateTime? filterToDate = _siteToDate;

            final now = DateTime.now();
            if (_selectedTimeframe == 'Today') {
              filterFromDate = DateTime(now.year, now.month, now.day);
              filterToDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            } else if (_selectedTimeframe == 'This Month') {
              filterFromDate = DateTime(now.year, now.month, 1);
              filterToDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            } else if (_selectedTimeframe == 'All Time') {
              filterFromDate = null;
              filterToDate = null;
            }

            // Extract dynamic filter lists
            final Set<String> siteNames = {'All'};
            final Set<String> projectNames = {'All'};
            final Set<String> supervisorNames = {'All'};
            final Set<String> categories = {
              'All',
              'Office & Site Supplies',
              'Transport & Travel',
              'Loading & Unloading',
              'Refreshments & Meals',
              'Hardware & Fasteners',
              'Fuel & Utilities',
              'Emergency Repairs',
              'Other / Miscellaneous',
            };

            for (final r in allRequests) {
              if (r.siteName != null && r.siteName!.isNotEmpty) {
                siteNames.add(r.siteName!);
              } else if (r.siteId != null && r.siteId!.isNotEmpty) {
                siteNames.add(r.siteId!);
              }
              if (r.projectName != null && r.projectName!.isNotEmpty) {
                projectNames.add(r.projectName!);
              }
              if (r.supervisorName.isNotEmpty) {
                supervisorNames.add(r.supervisorName);
              }
            }

            for (final t in allTransactions) {
              if (t.siteName != null && t.siteName!.isNotEmpty) {
                siteNames.add(t.siteName!);
              } else if (t.siteId != null && t.siteId!.isNotEmpty) {
                siteNames.add(t.siteId!);
              }
              if (t.projectName != null && t.projectName!.isNotEmpty) {
                projectNames.add(t.projectName!);
              }
              if (t.supervisorName.isNotEmpty) {
                supervisorNames.add(t.supervisorName);
              }
              if (t.expenseCategory.isNotEmpty) {
                categories.add(t.expenseCategory);
              }
            }

            // Calculate Site Summaries
            final siteSummaries = _pettyCashService.calculateSiteWiseSummaries(
              requests: allRequests,
              transactions: allTransactions,
              fromDate: filterFromDate,
              toDate: filterToDate,
              siteFilter: _selectedSiteFilter != 'All' ? _selectedSiteFilter : null,
              supervisorFilter: _selectedSupervisorFilter != 'All' ? _selectedSupervisorFilter : null,
              projectFilter: _selectedProjectFilter != 'All' ? _selectedProjectFilter : null,
              categoryFilter: _selectedCategoryFilter != 'All' ? _selectedCategoryFilter : null,
            );

            // Filter by search query
            final filteredSummaries = siteSummaries.where((s) {
              if (_siteSearchQuery.isNotEmpty) {
                final q = _siteSearchQuery.toLowerCase();
                final matchSite = s.siteName.toLowerCase().contains(q) || s.siteId.toLowerCase().contains(q);
                final matchProj = (s.projectName ?? '').toLowerCase().contains(q);
                final matchSup = s.supervisorName.toLowerCase().contains(q);
                if (!matchSite && !matchProj && !matchSup) return false;
              }
              return true;
            }).toList();

            // Compute Filtered Aggregate Totals
            double filteredTotalReceived = 0.0;
            double filteredTotalExpenses = 0.0;
            double filteredOtherExpenses = 0.0;
            double filteredRemainingBalance = 0.0;

            for (final s in filteredSummaries) {
              filteredTotalReceived += s.totalReceived;
              filteredTotalExpenses += s.totalExpenses;
              filteredOtherExpenses += s.otherExpenses;
              filteredRemainingBalance += s.remainingBalance;
            }

            return Column(
              children: [
                // Top Filter Controls & Search Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      TextField(
                        onChanged: (val) => setState(() => _siteSearchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search site, project, or supervisor...',
                          hintStyle: const TextStyle(fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // Timeframe Filter
                            _buildFilterDropdown<String>(
                              label: 'Period',
                              value: _selectedTimeframe,
                              items: const ['All Time', 'Today', 'This Month', 'Custom'],
                              onChanged: (val) async {
                                if (val == 'Custom') {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    initialDateRange: _siteFromDate != null && _siteToDate != null
                                        ? DateTimeRange(start: _siteFromDate!, end: _siteToDate!)
                                        : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedTimeframe = 'Custom';
                                      _siteFromDate = picked.start;
                                      _siteToDate = picked.end;
                                    });
                                  }
                                } else {
                                  setState(() => _selectedTimeframe = val ?? 'All Time');
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Site Filter
                            _buildFilterDropdown<String>(
                              label: 'Site',
                              value: _selectedSiteFilter,
                              items: siteNames.toList()..sort(),
                              onChanged: (val) => setState(() => _selectedSiteFilter = val ?? 'All'),
                            ),
                            const SizedBox(width: 8),

                            // Project Filter
                            _buildFilterDropdown<String>(
                              label: 'Project',
                              value: _selectedProjectFilter,
                              items: projectNames.toList()..sort(),
                              onChanged: (val) => setState(() => _selectedProjectFilter = val ?? 'All'),
                            ),
                            const SizedBox(width: 8),

                            // Supervisor Filter
                            _buildFilterDropdown<String>(
                              label: 'Supervisor',
                              value: _selectedSupervisorFilter,
                              items: supervisorNames.toList()..sort(),
                              onChanged: (val) => setState(() => _selectedSupervisorFilter = val ?? 'All'),
                            ),
                            const SizedBox(width: 8),

                            // Category Filter
                            _buildFilterDropdown<String>(
                              label: 'Category',
                              value: _selectedCategoryFilter,
                              items: categories.toList()..sort(),
                              onChanged: (val) => setState(() => _selectedCategoryFilter = val ?? 'All'),
                            ),
                            if (_selectedTimeframe == 'Custom' && _siteFromDate != null && _siteToDate != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  '${DateFormat('dd MMM').format(_siteFromDate!)} - ${DateFormat('dd MMM').format(_siteToDate!)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                onDeleted: () => setState(() => _selectedTimeframe = 'All Time'),
                                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Aggregated KPI Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFF1F5F9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInlineKpi('Sites', '${filteredSummaries.length} active'),
                      _buildInlineKpi('Received', PettyCashService.formatCurrency(filteredTotalReceived), color: const Color(0xFF2563EB)),
                      _buildInlineKpi('Spent', PettyCashService.formatCurrency(filteredTotalExpenses), color: const Color(0xFFE11D48)),
                      _buildInlineKpi('Other Exp', PettyCashService.formatCurrency(filteredOtherExpenses), color: const Color(0xFF7C3AED)),
                      _buildInlineKpi('Balance', PettyCashService.formatCurrency(filteredRemainingBalance), color: const Color(0xFF059669)),
                    ],
                  ),
                ),

                // Site Cards List
                Expanded(
                  child: filteredSummaries.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.location_city_outlined,
                          title: 'No sites match the filters',
                          subtitle: 'Try adjusting your site, supervisor, date, or category filters.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: filteredSummaries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final site = filteredSummaries[index];
                            return _buildSitePettyCashCard(site);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                '$label: $item',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInlineKpi(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSitePettyCashCard(SitePettyCashSummary s) {
    Color statusBg = const Color(0xFFECFDF5);
    Color statusColor = const Color(0xFF059669);

    if (s.status == 'Low Balance') {
      statusBg = const Color(0xFFFEF2F2);
      statusColor = const Color(0xFFEF4444);
    } else if (s.status == 'Fully Utilized') {
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF475569);
    } else if (s.status == 'Pending Receipt') {
      statusBg = const Color(0xFFFFFBEB);
      statusColor = const Color(0xFFD97706);
    }

    final double progress = s.totalReceived > 0
        ? (s.totalExpenses / s.totalReceived).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.isLowBalance ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: s.isLowBalance ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Site Name, Project, & Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_city_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.siteName,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.projectName != null && s.projectName!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Project: ${s.projectName}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          s.supervisorName,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  s.status.toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Balance Breakdown Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSiteBalanceMetric('Received Amount', PettyCashService.formatCurrency(s.totalReceived), const Color(0xFF2563EB)),
                    _buildSiteBalanceMetric('Total Spent', PettyCashService.formatCurrency(s.totalExpenses), const Color(0xFFE11D48)),
                    _buildSiteBalanceMetric('Other Expenses', PettyCashService.formatCurrency(s.otherExpenses), const Color(0xFF7C3AED)),
                    _buildSiteBalanceMetric(
                      'Remaining',
                      PettyCashService.formatCurrency(s.remainingBalance),
                      s.isLowBalance ? const Color(0xFFEF4444) : const Color(0xFF059669),
                      isHighlight: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Utilization Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Budget Utilization', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress > 0.9 ? const Color(0xFFEF4444) : (progress > 0.7 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action: Inspect Site Ledger
          InkWell(
            onTap: () => _openSiteLedgerModal(s),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 15, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Inspect Site Ledger (${s.transactionCount} expenses)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primaryColor),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteBalanceMetric(String label, String value, Color color, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 13.5 : 12,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  void _openSiteLedgerModal(SitePettyCashSummary s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Pill
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
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.siteName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Supervisor: ${s.supervisorName} • ${s.transactions.length} total entries',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mini Summary Strip inside modal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSiteBalanceMetric('Received', PettyCashService.formatCurrency(s.totalReceived), const Color(0xFF2563EB)),
                    _buildSiteBalanceMetric('Spent', PettyCashService.formatCurrency(s.totalExpenses), const Color(0xFFE11D48)),
                    _buildSiteBalanceMetric('Other', PettyCashService.formatCurrency(s.otherExpenses), const Color(0xFF7C3AED)),
                    _buildSiteBalanceMetric('Remaining', PettyCashService.formatCurrency(s.remainingBalance), const Color(0xFF059669), isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'SITE TRANSACTION & EXPENSE LEDGER',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              // Ledger Transactions List
              Expanded(
                child: s.transactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No expenses recorded yet against this site allocation.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: s.transactions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final t = s.transactions[idx];
                          final isExp = t.isExpense;
                          final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(t.transactionDate);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: t.isOtherExpense
                                            ? const Color(0xFFFAF5FF)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: t.isOtherExpense ? const Color(0xFFE9D5FF) : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        t.expenseCategory,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: t.isOtherExpense ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${isExp ? '-' : '+'}${PettyCashService.formatCurrency(t.amount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isExp ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.description,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                if (t.vendorName != null && t.vendorName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Payee/Vendor: ${t.vendorName}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    Text(
                                      'Bal: ${PettyCashService.formatCurrency(t.previousBalance)} → ${PettyCashService.formatCurrency(t.newBalance)}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. TAB 3: SUPERVISORS DIRECTORY & BALANCES
  // ---------------------------------------------------------------------------

  Widget _buildSupervisorsTab() {
    return StreamBuilder<List<PettyCashAccount>>(
      stream: _pettyCashService.streamAllAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data ?? [];

        if (accounts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No supervisor petty cash accounts',
            subtitle: 'Accounts will appear when supervisors are allocated petty cash.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final a = accounts[index];
            return _buildSupervisorAccountCard(a);
          },
        );
      },
    );
  }

  Widget _buildSupervisorAccountCard(PettyCashAccount a) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isLowBalance ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  a.supervisorName.isNotEmpty ? a.supervisorName[0].toUpperCase() : 'S',
                  style: TextStyle(fontWeight: FontWeight.w800, color: primaryColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.supervisorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('ID: ${a.supervisorId}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (a.isLowBalance)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Text(
                    'LOW BALANCE',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Balance metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniBalanceCell('Allocated', PettyCashService.formatCurrency(a.totalAllocated)),
              _buildMiniBalanceCell('Used', PettyCashService.formatCurrency(a.totalUsed)),
              _buildMiniBalanceCell(
                'Available',
                PettyCashService.formatCurrency(a.availableBalance),
                isBold: true,
                color: a.isLowBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBalanceCell(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. TAB 4: TRANSACTIONS MASTER LEDGER
  // ---------------------------------------------------------------------------

  Widget _buildLedgerTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];

        final filtered = txns.where((t) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchDesc = t.description.toLowerCase().contains(q);
            final matchSup = t.supervisorName.toLowerCase().contains(q);
            final matchSite = (t.siteName ?? t.siteId ?? '').toLowerCase().contains(q);
            if (!matchDesc && !matchSup && !matchSite) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search description, supervisor, site...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Ledger List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No matching transactions',
                      subtitle: 'Try changing your search query or filter.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        return _buildManagerLedgerTile(t);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManagerLedgerTile(PettyCashTransaction t) {
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(t.transactionDate);
    final isExp = t.isExpense;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.supervisorName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              Text(
                '${isExp ? '-' : '+'}${PettyCashService.formatCurrency(t.amount)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isExp ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            t.description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.expenseCategory,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              if (t.isSiteExpense) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.siteName ?? t.siteId ?? 'Site',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Bal: ${PettyCashService.formatCurrency(t.previousBalance)} → ${PettyCashService.formatCurrency(t.newBalance)}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. TAB 5: REPORTS & ANALYTICS
  // ---------------------------------------------------------------------------

  Widget _buildReportsTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snap.data ?? [];

        // Aggregate reports
        final Map<String, double> supervisorExpenses = {};
        final Map<String, double> siteExpenses = {};
        final List<PettyCashTransaction> otherExpenses = [];
        double totalExpenseSum = 0.0;
        double totalAllocSum = 0.0;

        for (final t in txns) {
          if (t.isExpense) {
            totalExpenseSum += t.amount;
            supervisorExpenses[t.supervisorName] =
                (supervisorExpenses[t.supervisorName] ?? 0.0) + t.amount;

            if (t.isSiteExpense) {
              final siteKey = t.siteName ?? t.siteId ?? 'Site';
              siteExpenses[siteKey] = (siteExpenses[siteKey] ?? 0.0) + t.amount;
            } else {
              otherExpenses.add(t);
            }
          } else {
            totalAllocSum += t.amount;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expense Summary Reports',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                DropdownButton<String>(
                  value: _reportPeriod,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                  items: const [
                    DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                  ],
                  onChanged: (val) => setState(() => _reportPeriod = val ?? 'This Month'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Disbursed',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PettyCashService.formatCurrency(totalAllocSum),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Spent',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PettyCashService.formatCurrency(totalExpenseSum),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFE11D48)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Site-wise Summary
            _buildReportSectionTitle('Site-wise Expenses Breakdown', Icons.location_city_rounded),
            const SizedBox(height: 8),
            siteExpenses.isEmpty
                ? const Text('No site-wise expenses recorded yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
                : Column(
                    children: siteExpenses.entries.map((e) {
                      final pct = totalExpenseSum > 0 ? (e.value / totalExpenseSum * 100).toStringAsFixed(1) : '0';
                      return _buildReportRow(e.key, PettyCashService.formatCurrency(e.value), '$pct%');
                    }).toList(),
                  ),
            const SizedBox(height: 20),

            // Section 2: Other Expenses (Overhead / General)
            _buildReportSectionTitle('Other / Overhead Expenses', Icons.miscellaneous_services_rounded),
            const SizedBox(height: 8),
            otherExpenses.isEmpty
                ? const Text('No other expenses recorded.', style: TextStyle(fontSize: 12, color: Colors.grey))
                : Column(
                    children: otherExpenses.map((t) {
                      return _buildReportRow(
                        '${t.description} (${t.supervisorName})',
                        PettyCashService.formatCurrency(t.amount),
                        DateFormat('dd MMM').format(t.transactionDate),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),

            // Section 3: Supervisor-wise Breakdown
            _buildReportSectionTitle('Supervisor-wise Expense Breakdown', Icons.engineering_rounded),
            const SizedBox(height: 8),
            supervisorExpenses.isEmpty
                ? const Text('No supervisor expenses recorded.', style: TextStyle(fontSize: 12, color: Colors.grey))
                : Column(
                    children: supervisorExpenses.entries.map((e) {
                      return _buildReportRow(
                        e.key,
                        PettyCashService.formatCurrency(e.value),
                        'Total Used',
                      );
                    }).toList(),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildReportSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildReportRow(String title, String amount, String extra) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(extra, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. DIALOGS: FORWARD TO ORG, REJECT, ALLOCATE
  // ---------------------------------------------------------------------------

  void _showForwardDialog(PettyCashRequest req) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Forward to Organization HQ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forward ${PettyCashService.formatCurrency(req.requestedAmount)} request for ${req.supervisorName} to Organization HQ for authorization.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Manager verification remarks (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _pettyCashService.managerForwardToOrg(
                    requestId: req.requestId,
                    managerName: _currentManagerName,
                    managerId: _currentManagerId,
                    remarks: remarksController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request forwarded to Organization HQ!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Forward'),
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(PettyCashRequest req) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Reject Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for declining this request:', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Rejection reason (required)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _pettyCashService.managerRejectRequest(
                    requestId: req.requestId,
                    managerName: _currentManagerName,
                    managerId: _currentManagerId,
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request rejected.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
  }

  void _showAllocateConfirmationDialog(PettyCashRequest req) {
    final approvedAmt = req.approvedAmount > 0 ? req.approvedAmount : req.requestedAmount;
    final amountController = TextEditingController(text: approvedAmt.toStringAsFixed(0));
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Allocate Approved Petty Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization HQ has authorized ${PettyCashService.formatCurrency(approvedAmt)}. Confirm fund release to ${req.supervisorName}.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              const Text('Allocation Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  hintText: 'Optional release remarks',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final allocAmt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (allocAmt <= 0 || allocAmt > approvedAmt) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Allocation amount must be between ₹1 and ${PettyCashService.formatCurrency(approvedAmt)}.'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await _pettyCashService.managerAllocatePettyCash(
                    requestId: req.requestId,
                    managerName: _currentManagerName,
                    managerId: _currentManagerId,
                    allocationAmount: allocAmt,
                    remarks: remarksController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Allocated ${PettyCashService.formatCurrency(allocAmt)} to ${req.supervisorName} successfully!',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Release Funds'),
            ),
          ],
        );
      },
    );
  }

  void _showManualAllocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ManagerManualAllocationDialog(
        currentManagerId: _currentManagerId,
        currentManagerName: _currentManagerName,
      ),
    );
  }
}

// =============================================================================
// MANAGER MANUAL PETTY CASH ALLOCATION MODAL (MANDATORY ORG APPROVAL FLOW)
// =============================================================================

class _ManagerManualAllocationDialog extends StatefulWidget {
  final String currentManagerId;
  final String currentManagerName;

  const _ManagerManualAllocationDialog({
    required this.currentManagerId,
    required this.currentManagerName,
  });

  @override
  State<_ManagerManualAllocationDialog> createState() =>
      _ManagerManualAllocationDialogState();
}

class _ManagerManualAllocationDialogState
    extends State<_ManagerManualAllocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, String>> _supervisors = [];
  List<Map<String, String>> _allSiteMappings = [];

  String? _selectedSupervisorId;
  String? _selectedSupervisorName;
  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedProjectId;
  String? _selectedProjectName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final Set<String> seenSupIds = {};
      final List<Map<String, String>> sups = [];
      final List<Map<String, String>> sites = [];

      final mapSnap = await FirestoreService.siteSupervisorMap.get();
      for (final doc in mapSnap.docs) {
        final d = doc.data();
        final supId = (d['Supervisor ID'] ?? d['supervisorId'] ?? '').toString().trim();
        final supName = (d['supervisor'] ?? d['supervisorName'] ?? supId).toString().trim();
        final siteId = (d['siteId'] ?? d['site'] ?? d['site_id'] ?? doc.id).toString().trim();
        final siteName = (d['siteName'] ?? d['site'] ?? siteId).toString().trim();
        final projId = (d['projectId'] ?? d['project_id'] ?? d['project'] ?? '').toString().trim();
        final projName = (d['projectName'] ?? d['project_name'] ?? d['project'] ?? '').toString().trim();

        if (supId.isNotEmpty && !seenSupIds.contains(supId.toLowerCase())) {
          seenSupIds.add(supId.toLowerCase());
          sups.add({'supervisorId': supId, 'supervisorName': supName});
        }

        if (siteId.isNotEmpty) {
          sites.add({
            'supervisorId': supId,
            'supervisorName': supName,
            'siteId': siteId,
            'siteName': siteName,
            'projectId': projId,
            'projectName': projName,
          });
        }
      }

      // Also fallback fetch from petty cash accounts if supervisor list is empty
      if (sups.isEmpty) {
        final accSnap = await FirestoreService.pettyCashAccounts.get();
        for (final doc in accSnap.docs) {
          final d = doc.data();
          final sId = (d['supervisorId'] ?? doc.id).toString().trim();
          final sName = (d['supervisorName'] ?? sId).toString().trim();
          if (sId.isNotEmpty && !seenSupIds.contains(sId.toLowerCase())) {
            seenSupIds.add(sId.toLowerCase());
            sups.add({'supervisorId': sId, 'supervisorName': sName});
          }
        }
      }

      // Fallback from sites collection
      if (sites.isEmpty) {
        final siteSnap = await FirestoreService.sites.get();
        for (final doc in siteSnap.docs) {
          final d = doc.data();
          final sId = (d['siteId'] ?? doc.id).toString().trim();
          final sName = (d['siteName'] ?? d['name'] ?? sId).toString().trim();
          final pId = (d['projectId'] ?? d['project_id'] ?? '').toString().trim();
          final pName = (d['projectName'] ?? d['project_name'] ?? '').toString().trim();
          sites.add({
            'supervisorId': '',
            'supervisorName': '',
            'siteId': sId,
            'siteName': sName,
            'projectId': pId,
            'projectName': pName,
          });
        }
      }

      if (mounted) {
        setState(() {
          _supervisors = sups;
          _allSiteMappings = sites;
          if (_supervisors.isNotEmpty) {
            _selectedSupervisorId = _supervisors.first['supervisorId'];
            _selectedSupervisorName = _supervisors.first['supervisorName'];
            _updateSitesForSupervisor();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSitesForSupervisor() {
    final matching = _allSiteMappings.where(
      (s) =>
          s['supervisorId']?.toLowerCase() == _selectedSupervisorId?.toLowerCase() ||
          (s['supervisorId'] ?? '').isEmpty,
    ).toList();

    final availableSites = matching.isNotEmpty ? matching : _allSiteMappings;
    if (availableSites.isNotEmpty) {
      final first = availableSites.first;
      _selectedSiteId = first['siteId'];
      _selectedSiteName = first['siteName'];
      _selectedProjectId = first['projectId'];
      _selectedProjectName = first['projectName'];
    } else {
      _selectedSiteId = null;
      _selectedSiteName = null;
      _selectedProjectId = null;
      _selectedProjectName = null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final matchingSites = _allSiteMappings.where(
      (s) =>
          s['supervisorId']?.toLowerCase() == _selectedSupervisorId?.toLowerCase() ||
          (s['supervisorId'] ?? '').isEmpty,
    ).toList();
    final availableSites = matchingSites.isNotEmpty ? matchingSites : _allSiteMappings;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_card_rounded, color: Color(0xFF7E22CE), size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Manual Petty Cash Allocation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mandatory Org Approval Notice
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Manual allocations created by Managers are submitted to Organization HQ for mandatory authorization before funds become active.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1. Supervisor Selection
                      const Text(
                        'Select Supervisor *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedSupervisorId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        items: _supervisors.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['supervisorId'],
                            child: Text(
                              '${s['supervisorName']} (${s['supervisorId']})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSupervisorId = val;
                            final found = _supervisors.firstWhere(
                              (s) => s['supervisorId'] == val,
                              orElse: () => {'supervisorId': val ?? '', 'supervisorName': val ?? ''},
                            );
                            _selectedSupervisorName = found['supervisorName'];
                            _updateSitesForSupervisor();
                          });
                        },
                        validator: (val) => val == null || val.isEmpty ? 'Supervisor is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // 2. Site Selection
                      const Text(
                        'Select Site *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedSiteId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        items: availableSites.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['siteId'],
                            child: Text(
                              '${s['siteName']} (${s['siteId']})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSiteId = val;
                            final found = availableSites.firstWhere(
                              (s) => s['siteId'] == val,
                              orElse: () => {'siteId': val ?? '', 'siteName': val ?? ''},
                            );
                            _selectedSiteName = found['siteName'];
                            _selectedProjectId = found['projectId'];
                            _selectedProjectName = found['projectName'];
                          });
                        },
                        validator: (val) => val == null || val.isEmpty ? 'Site is required' : null,
                      ),
                      if (_selectedProjectName != null && _selectedProjectName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Project: $_selectedProjectName',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // 3. Amount Input
                      const Text(
                        'Allocation Amount (₹) *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. 15000',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Amount is required';
                          final n = double.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Enter a valid amount > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Purpose / Reason
                      const Text(
                        'Purpose / Reason *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Site mobilization operational petty cash',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Purpose is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 5. Remarks
                      const Text(
                        'Remarks (Optional)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          hintText: 'Notes for Organization HQ approval',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Submit for Org Approval'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupervisorId == null || _selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a Supervisor and a Site.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      await PettyCashService().managerCreateManualAllocation(
        supervisorId: _selectedSupervisorId!,
        supervisorName: _selectedSupervisorName ?? _selectedSupervisorId!,
        managerId: widget.currentManagerId,
        managerName: widget.currentManagerName,
        siteId: _selectedSiteId!,
        siteName: _selectedSiteName ?? '',
        projectId: _selectedProjectId,
        projectName: _selectedProjectName,
        amount: amount,
        reason: _reasonController.text.trim(),
        remarks: _remarksController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual allocation of ${PettyCashService.formatCurrency(amount)} created for ${_selectedSupervisorName ?? _selectedSupervisorId} and sent to Organization HQ for mandatory authorization.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
