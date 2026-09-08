import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../services/auth_service.dart';
import '../../services/approval_workflow_service.dart';
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
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
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
            Tab(icon: Icon(Icons.supervisor_account_rounded, size: 18), text: 'Supervisors'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Ledger'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Reports'),
          ],
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
                    PettyCashService.formatCurrency(req.requestedAmount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    req.isReplenishment ? 'Replenishment' : 'Initial Request',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: req.isReplenishment ? const Color(0xFF0F766E) : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

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
                const SizedBox(width: 8),
                Text(
                  'Total Alloc: ${PettyCashService.formatCurrency(req.totalAllocatedAtRequest)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Reason: ${req.reason}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Review & Forward vs Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog(req),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showForwardDialog(req),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Forward to HQ', style: TextStyle(fontWeight: FontWeight.w800)),
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
          // Header: Approved badge & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(height: 2),
          Text(
            'Reason: ${req.reason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
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
}
