import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../services/auth_service.dart';
import '../../services/approval_workflow_service.dart';
import '../../utils/app_theme.dart';

class OrgPettyCashPage extends StatefulWidget {
  final int initialTabIndex;
  const OrgPettyCashPage({super.key, this.initialTabIndex = 0});

  @override
  State<OrgPettyCashPage> createState() => _OrgPettyCashPageState();
}

class _OrgPettyCashPageState extends State<OrgPettyCashPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PettyCashService _pettyCashService = PettyCashService();

  String _searchQuery = '';
  String _selectedMonth = DateFormat('MMM yyyy').format(DateTime.now());

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  String get _currentOrgUserName {
    final ud = AuthService().userData;
    return (ud['name'] ?? ud['userName'] ?? ud['username'] ?? 'HQ Admin').toString();
  }

  String get _currentOrgUserId {
    final ud = AuthService().userData;
    return (ud['userId'] ?? ud['id'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
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
          'Organization Petty Cash Command',
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
            Tab(icon: Icon(Icons.verified_user_rounded, size: 18), text: 'HQ Approvals'),
            Tab(icon: Icon(Icons.supervisor_account_rounded, size: 18), text: 'Supervisors'),
            Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'Site Expenses'),
            Tab(icon: Icon(Icons.miscellaneous_services_rounded, size: 18), text: 'Other Expenses'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Master Ledger'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Monthly Report'),
            Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Audit Trail'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Executive KPI Header
            _buildOrgKpiHeader(),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHqApprovalsTab(),
                  _buildSupervisorsTab(),
                  _buildSiteExpensesTab(),
                  _buildOtherExpensesTab(),
                  _buildMasterLedgerTab(),
                  _buildMonthlyReportTab(),
                  _buildAuditTrailTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. EXECUTIVE KPI HEADER
  // ---------------------------------------------------------------------------

  Widget _buildOrgKpiHeader() {
    return StreamBuilder<List<PettyCashAccount>>(
      stream: _pettyCashService.streamAllAccounts(),
      builder: (context, accSnap) {
        return StreamBuilder<List<PettyCashRequest>>(
          stream: _pettyCashService.streamAllRequests(),
          builder: (context, reqSnap) {
            final accounts = accSnap.data ?? [];
            final requests = reqSnap.data ?? [];

            double companyTotalAllocated = 0.0;
            double companyTotalUsed = 0.0;
            double companyTotalRemaining = 0.0;

            for (final a in accounts) {
              companyTotalAllocated += a.totalAllocated;
              companyTotalUsed += a.totalUsed;
              companyTotalRemaining += a.availableBalance;
            }

            final pendingHqApprovals = requests
                .where((r) => r.status == ApprovalWorkflowService.statusPendingOrgApproval)
                .length;

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildOrgMiniKpi(
                          title: 'Allocations',
                          amount: PettyCashService.formatCurrency(companyTotalAllocated),
                          color: const Color(0xFF2563EB),
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildOrgMiniKpi(
                          title: 'Consumed',
                          amount: PettyCashService.formatCurrency(companyTotalUsed),
                          color: const Color(0xFFDC2626),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildOrgMiniKpi(
                          title: 'Pool Balance',
                          amount: PettyCashService.formatCurrency(companyTotalRemaining),
                          color: const Color(0xFF059669),
                          icon: Icons.savings_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (pendingHqApprovals > 0) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _tabController.animateTo(0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$pendingHqApprovals Petty Cash Request(s) Awaiting Organization Authorization',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrgMiniKpi({
    required String title,
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
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

  // ---------------------------------------------------------------------------
  // 2. TAB 1: HQ APPROVALS (STAGE 2 -> STAGE 3)
  // ---------------------------------------------------------------------------

  Widget _buildHqApprovalsTab() {
    return StreamBuilder<List<PettyCashRequest>>(
      stream: _pettyCashService.streamAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        final pendingHq = requests
            .where((r) => r.status == ApprovalWorkflowService.statusPendingOrgApproval)
            .toList();

        if (pendingHq.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No pending HQ approvals',
            subtitle: 'All manager-verified petty cash requests have been processed.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pendingHq.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = pendingHq[index];
            return _buildHqApprovalCard(req);
          },
        );
      },
    );
  }

  Widget _buildHqApprovalCard(PettyCashRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Request Type & Requested Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  req.isReplenishment ? 'REPLENISHMENT' : 'INITIAL REQUEST',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                ),
              ),
              Text(
                PettyCashService.formatCurrency(req.requestedAmount),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            'Supervisor: ${req.supervisorName} (${req.supervisorId})',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          Text(
            'Forwarded by Manager: ${req.managerName}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: ${req.reason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          if (req.managerReviewRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Manager Endorsement: ${req.managerReviewRemarks}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Actions: Approve vs Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showHqRejectDialog(req),
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
                  onPressed: () => _showHqApproveDialog(req),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Authorize', style: TextStyle(fontWeight: FontWeight.w800)),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TAB 2: SUPERVISOR DIRECTORY & ALLOCATION HISTORY
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
            title: 'No supervisor accounts',
            subtitle: 'No petty cash accounts have been created yet.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final a = accounts[index];
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
                      Text(a.supervisorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text(
                        'Available: ${PettyCashService.formatCurrency(a.availableBalance)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: a.isLowBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Text('Supervisor ID: ${a.supervisorId} • Manager: ${a.managerName.isNotEmpty ? a.managerName : "Assigned"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Allocated: ${PettyCashService.formatCurrency(a.totalAllocated)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                      Text('Used: ${PettyCashService.formatCurrency(a.totalUsed)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. TAB 3: SITE-WISE EXPENSES
  // ---------------------------------------------------------------------------

  Widget _buildSiteExpensesTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];
        final siteTxns = txns.where((t) => t.isSiteExpense && t.isExpense).toList();

        final Map<String, List<PettyCashTransaction>> groupedBySite = {};
        for (final t in siteTxns) {
          final sKey = t.siteName ?? t.siteId ?? 'Unknown Site';
          groupedBySite.putIfAbsent(sKey, () => []).add(t);
        }

        if (groupedBySite.isEmpty) {
          return _buildEmptyState(
            icon: Icons.location_city_rounded,
            title: 'No site-wise expenses',
            subtitle: 'Expenses logged against specific construction sites will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: groupedBySite.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final siteKey = groupedBySite.keys.elementAt(index);
            final items = groupedBySite[siteKey]!;
            final double siteTotal = items.fold(0.0, (acc, t) => acc + t.amount);

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
                      Row(
                        children: [
                          const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            siteKey,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Text(
                        PettyCashService.formatCurrency(siteTotal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${items.length} total petty cash transaction(s)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  ...items.take(3).map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• ${t.description} (${t.supervisorName})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            PettyCashService.formatCurrency(t.amount),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. TAB 4: OTHER EXPENSES (OVERHEADS & GENERAL)
  // ---------------------------------------------------------------------------

  Widget _buildOtherExpensesTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];
        final otherTxns = txns.where((t) => !t.isSiteExpense && t.isExpense).toList();

        if (otherTxns.isEmpty) {
          return _buildEmptyState(
            icon: Icons.miscellaneous_services_rounded,
            title: 'No other / overhead expenses',
            subtitle: 'Non-site operational expenses will appear here.',
          );
        }

        final double otherTotal = otherTxns.fold(0.0, (acc, t) => acc + t.amount);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: const Color(0xFFFFFBEB),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Overhead Expenses:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    PettyCashService.formatCurrency(otherTotal),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: otherTxns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final t = otherTxns[index];
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
                            Text(t.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(
                              PettyCashService.formatCurrency(t.amount),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Supervisor: ${t.supervisorName} • Category: ${t.expenseCategory}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. TAB 5: MASTER TRANSACTION LEDGER
  // ---------------------------------------------------------------------------

  Widget _buildMasterLedgerTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];
        final filtered = txns.where((t) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return t.description.toLowerCase().contains(q) ||
              t.supervisorName.toLowerCase().contains(q) ||
              (t.siteName ?? '').toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search master ledger...',
                  prefixIcon: const Icon(Icons.search_rounded),
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
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No ledger transactions',
                      subtitle: 'Transactions will be logged here in chronological order.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = filtered[index];
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
                                  Text(t.supervisorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
                              const SizedBox(height: 2),
                              Text(t.description, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t.isSiteExpense ? (t.siteName ?? 'Site') : 'Overhead Expense',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: t.isSiteExpense ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                                    ),
                                  ),
                                  Text(
                                    'Bal: ${PettyCashService.formatCurrency(t.previousBalance)} → ${PettyCashService.formatCurrency(t.newBalance)}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(dateStr, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. TAB 6: MONTHLY REPORT
  // ---------------------------------------------------------------------------

  Widget _buildMonthlyReportTab() {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];
        double openingAlloc = 0.0;
        double replenishments = 0.0;
        double totalSpent = 0.0;

        for (final t in txns) {
          if (t.transactionType == 'ALLOCATION') {
            openingAlloc += t.amount;
          } else if (t.transactionType == 'REPLENISHMENT') {
            replenishments += t.amount;
          } else if (t.isExpense) {
            totalSpent += t.amount;
          }
        }

        final closingBal = (openingAlloc + replenishments - totalSpent).clamp(0.0, double.infinity);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Statement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      DropdownButton<String>(
                        value: _selectedMonth,
                        underline: const SizedBox(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryColor),
                        items: [
                          DropdownMenuItem(value: _selectedMonth, child: Text(_selectedMonth)),
                          DropdownMenuItem(
                            value: DateFormat('MMM yyyy').format(DateTime.now().subtract(const Duration(days: 30))),
                            child: Text(DateFormat('MMM yyyy').format(DateTime.now().subtract(const Duration(days: 30)))),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedMonth = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatementRow('Initial Allocations', PettyCashService.formatCurrency(openingAlloc), const Color(0xFF2563EB)),
                  const Divider(height: 20),
                  _buildStatementRow('Valid Replenishments (+)', PettyCashService.formatCurrency(replenishments), const Color(0xFF059669)),
                  const Divider(height: 20),
                  _buildStatementRow('Total Expenses (-)', PettyCashService.formatCurrency(totalSpent), const Color(0xFFDC2626)),
                  const Divider(height: 20),
                  _buildStatementRow('Net Closing Balance', PettyCashService.formatCurrency(closingBal), const Color(0xFF0F172A), isTotal: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatementRow(String label, String value, Color color, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14.5 : 13,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 8. TAB 7: IMMUTABLE AUDIT TRAIL
  // ---------------------------------------------------------------------------

  Widget _buildAuditTrailTab() {
    return StreamBuilder<List<PettyCashAuditLog>>(
      stream: _pettyCashService.streamAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_edu_rounded,
            title: 'No audit logs recorded',
            subtitle: 'All important petty cash operations will generate immutable audit logs.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            final dateStr = DateFormat('dd MMM yyyy • hh:mm:ss a').format(log.timestamp);

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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.action,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Actor: ${log.actorName} (${log.actorRole}) • Target: ${log.entityType} #${log.entityId}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            );
          },
        );
      },
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
  // 9. HQ APPROVE & REJECT DIALOGS
  // ---------------------------------------------------------------------------

  void _showHqApproveDialog(PettyCashRequest req) {
    final amountController = TextEditingController(text: req.requestedAmount.toStringAsFixed(0));
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Authorize Petty Cash Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review requested funds for ${req.supervisorName} (Forwarded by ${req.managerName}).',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              const Text('Approved Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                  hintText: 'HQ authorization remarks',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final approvedAmt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (approvedAmt <= 0) return;

                Navigator.pop(ctx);
                try {
                  await _pettyCashService.orgApproveRequest(
                    requestId: req.requestId,
                    orgUserName: _currentOrgUserName,
                    orgUserId: _currentOrgUserId,
                    approvedAmount: approvedAmt,
                    remarks: remarksController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request authorized by Organization HQ!'),
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
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Authorization'),
            ),
          ],
        );
      },
    );
  }

  void _showHqRejectDialog(PettyCashRequest req) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Decline Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide an official rejection reason:', style: TextStyle(fontSize: 12.5)),
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
                  await _pettyCashService.orgRejectRequest(
                    requestId: req.requestId,
                    orgUserName: _currentOrgUserName,
                    orgUserId: _currentOrgUserId,
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request declined.')),
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
              child: const Text('Confirm Decline'),
            ),
          ],
        );
      },
    );
  }
}
