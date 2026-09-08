import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/approval_lifecycle_stepper.dart';

class SupervisorPettyCashPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorPettyCashPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorPettyCashPage> createState() => _SupervisorPettyCashPageState();
}

class _SupervisorPettyCashPageState extends State<SupervisorPettyCashPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PettyCashService _pettyCashService = PettyCashService();

  List<Map<String, String>> _assignedSites = [];
  bool _isLoadingSites = true;
  String _txnFilter = 'All'; // 'All', 'Site', 'Other'

  Color get primaryColor => Theme.of(context).colorScheme.primary;
  bool _isConfirmingReceipt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAssignedSites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedSites() async {
    final sites = await _pettyCashService.fetchSupervisorAssignedSites(
      supervisorId: widget.supervisorId,
      supervisorName: widget.supervisorName,
    );
    if (mounted) {
      setState(() {
        _assignedSites = sites;
        _isLoadingSites = false;
      });
    }
  }

  /// Supervisor confirmation dialog and idempotent execution
  Future<void> _confirmAmountReceived(PettyCashRequest req) async {
    final amount = req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount;
    final formattedAmt = PettyCashService.formatCurrency(amount);
    final managerName = (req.allocatedBy != null && req.allocatedBy!.isNotEmpty)
        ? req.allocatedBy!
        : req.managerName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Confirm Amount Received',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have you physically received the allocated petty cash from Manager $managerName?',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
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
                      const Text(
                        'Allocated Amount:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      Text(
                        formattedAmt,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Awaiting Confirmation',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Notice: Only confirm after the cash is physically in your hand. Once confirmed, this amount will become available for expenses and the Manager will be notified.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Not Yet', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Confirm Amount Received', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (_isConfirmingReceipt) return; // Idempotent UI guard
    setState(() => _isConfirmingReceipt = true);

    try {
      await _pettyCashService.supervisorConfirmAmountReceived(
        requestId: req.requestId,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Receipt of $formattedAmt confirmed! Amount is now available for expense usage.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm receipt: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingReceipt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return StreamBuilder<PettyCashAccount?>(
      stream: _pettyCashService.streamAccount(widget.supervisorId),
      builder: (context, accountSnap) {
        final account = accountSnap.data;
        final totalAllocated = account?.totalAllocated ?? 0.0;
        final totalUsed = account?.totalUsed ?? 0.0;
        final availableBalance = account?.availableBalance ?? 0.0;
        final isLowBalance = account?.isLowBalance ?? false;

        return StreamBuilder<List<PettyCashRequest>>(
          stream: _pettyCashService.streamSupervisorRequests(
            widget.supervisorId,
            supervisorName: widget.supervisorName,
          ),
          builder: (context, reqSnap) {
            final requests = reqSnap.data ?? [];
            final unconfirmedRequests =
                requests.where((r) => r.isAwaitingConfirmation).toList();

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Petty Cash',
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
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt_long_rounded, size: 20), text: 'Expenses & Ledger'),
                    Tab(icon: Icon(Icons.history_toggle_off_rounded, size: 20), text: 'Requests & Status'),
                  ],
                ),
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    // 1. Live Balance Hero Section, Awaiting Confirmation Banner & Low-Balance Alert
                    _buildHeroOverview(
                      totalAllocated: totalAllocated,
                      totalUsed: totalUsed,
                      availableBalance: availableBalance,
                      isLowBalance: isLowBalance,
                      account: account,
                      unconfirmedRequests: unconfirmedRequests,
                    ),

                    // 2. Tab Content (Transactions Ledger or Requests Status)
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTransactionsTab(availableBalance),
                          _buildRequestsTab(
                            account,
                            requests: requests,
                            isLoading: reqSnap.connectionState == ConnectionState.waiting,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _openRecordExpenseModal(
                  context,
                  availableBalance: availableBalance,
                  unconfirmedRequests: unconfirmedRequests,
                ),
                backgroundColor: primaryColor,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Record Expense',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HERO OVERVIEW CARDS, AWAITING CONFIRMATION & LOW BALANCE BANNER
  // ---------------------------------------------------------------------------

  Widget _buildHeroOverview({
    required double totalAllocated,
    required double totalUsed,
    required double availableBalance,
    required bool isLowBalance,
    required PettyCashAccount? account,
    required List<PettyCashRequest> unconfirmedRequests,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          // Awaiting Physical Receipt Confirmation Banner
          if (unconfirmedRequests.isNotEmpty)
            _buildAwaitingConfirmationBanner(unconfirmedRequests),

          // 10% Low Balance Alert Banner
          if (isLowBalance)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Low Petty Cash Balance (≤ 10%)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          'Available: ${PettyCashService.formatCurrency(availableBalance)}. Request additional petty cash from your manager.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _openRequestModal(context, isReplenishment: true, currentAccount: account),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Top-Up'),
                  ),
                ],
              ),
            ),

          // 3 Financial Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Available',
                  amount: availableBalance,
                  icon: Icons.account_balance_wallet_rounded,
                  color: isLowBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  bgColor: isLowBalance ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Used',
                  amount: totalUsed,
                  icon: Icons.shopping_bag_outlined,
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Allocated',
                  amount: totalAllocated,
                  icon: Icons.savings_outlined,
                  color: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Action Pill Bar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRequestModal(context, isReplenishment: false, currentAccount: account),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Request Petty Cash'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRequestModal(context, isReplenishment: true, currentAccount: account),
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: const Text('Replenish Cash'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    backgroundColor: const Color(0xFFF0FDFA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingConfirmationBanner(List<PettyCashRequest> unconfirmedRequests) {
    return Column(
      children: unconfirmedRequests.map((req) {
        final amount = req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount;
        final formattedAmt = PettyCashService.formatCurrency(amount);
        final manager = (req.allocatedBy != null && req.allocatedBy!.isNotEmpty)
            ? req.allocatedBy!
            : req.managerName;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allocated by $manager',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Awaiting Confirmation',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Highlighted Amount Details & Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Allocated Amount',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78350F),
                        ),
                      ),
                      Text(
                        formattedAmt,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isConfirmingReceipt ? null : () => _confirmAmountReceived(req),
                    icon: _isConfirmingReceipt
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Confirm Amount Received',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Amount becomes available for expense usage only after physical cash receipt is confirmed.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isPrimary ? 0.35 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            PettyCashService.formatCurrency(amount),
            style: TextStyle(
              fontSize: isPrimary ? 16 : 14.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TAB 1: TRANSACTIONS LEDGER
  // ---------------------------------------------------------------------------

  Widget _buildTransactionsTab(double availableBalance) {
    return StreamBuilder<List<PettyCashTransaction>>(
      stream: _pettyCashService.streamSupervisorTransactions(widget.supervisorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTxns = snapshot.data ?? [];

        final filteredTxns = allTxns.where((txn) {
          if (_txnFilter == 'Site') return txn.isSiteExpense;
          if (_txnFilter == 'Other') return !txn.isSiteExpense && txn.isExpense;
          return true;
        }).toList();

        return Column(
          children: [
            // Filter Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  _buildFilterChip('All', allTxns.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Site', allTxns.where((t) => t.isSiteExpense).length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Other',
                    allTxns.where((t) => !t.isSiteExpense && t.isExpense).length,
                  ),
                ],
              ),
            ),

            // Transactions List
            Expanded(
              child: filteredTxns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions recorded yet',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Record Expense" below to log expenses against sites or overheads.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: filteredTxns.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final txn = filteredTxns[index];
                        return _buildTransactionCard(txn);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, int count) {
    final isSelected = _txnFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _txnFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$filterKey ($count)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(PettyCashTransaction txn) {
    final isExp = txn.isExpense;
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(txn.transactionDate);

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isExp ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isExp ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Icon(
                  isExp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isExp ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            txn.expenseCategory,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (txn.isSiteExpense) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              txn.siteName ?? txn.siteId ?? 'Site Expense',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ] else if (isExp) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Other Expense',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${isExp ? '-' : '+'}${PettyCashService.formatCurrency(txn.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isExp ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Footer: Timestamp & Balance Ledger Transition
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
              Text(
                'Bal: ${PettyCashService.formatCurrency(txn.previousBalance)} → ${PettyCashService.formatCurrency(txn.newBalance)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TAB 2: REQUESTS & STATUS LIFECYCLE
  // ---------------------------------------------------------------------------

  Widget _buildRequestsTab(
    PettyCashAccount? account, {
    required List<PettyCashRequest> requests,
    required bool isLoading,
  }) {
    if (isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No petty cash requests found',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () => _openRequestModal(context, isReplenishment: false, currentAccount: account),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create New Request'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = requests[index];
        return _buildRequestStatusCard(req);
      },
    );
  }

  Widget _buildRequestStatusCard(PettyCashRequest req) {
    final dateStr = req.createdAt != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(req.createdAt!)
        : 'Recently';

    return Container(
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Request Type Badge & Requested Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: req.isReplenishment
                      ? const Color(0xFFF0FDFA)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: req.isReplenishment
                        ? const Color(0xFF99F6E4)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Text(
                  req.isReplenishment ? 'REPLENISHMENT' : 'INITIAL ALLOCATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: req.isReplenishment
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Text(
                PettyCashService.formatCurrency(req.requestedAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            req.reason,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Submitted: $dateStr',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          // Stepper tracking 4 approval stages
          ApprovalLifecycleStepper(
            status: req.status,
            history: req.approvalHistory,
            rejectionReason: req.rejectionReason,
            isCompact: true,
          ),

          // Reviewer remarks if available
          if (req.managerReviewRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Manager Note: ${req.managerReviewRemarks}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],
          if (req.orgApprovalRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HQ Note: ${req.orgApprovalRemarks}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],

          // Amount Received Confirmation Section
          if (req.isAwaitingConfirmation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allocated Amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF78350F),
                            ),
                          ),
                          Text(
                            PettyCashService.formatCurrency(
                              req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount,
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD97706)),
                        ),
                        child: const Text(
                          'Awaiting Confirmation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConfirmingReceipt ? null : () => _confirmAmountReceived(req),
                      icon: _isConfirmingReceipt
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text(
                        'Confirm Amount Received',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (req.isReceived && req.receivedAt != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Received & Active: Confirmed on ${DateFormat('dd MMM yyyy • hh:mm a').format(req.receivedAt!)} by ${(req.receivedBySupervisorName != null && req.receivedBySupervisorName!.isNotEmpty) ? req.receivedBySupervisorName! : req.supervisorName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. MODAL: RECORD EXPENSE (SITE-WISE OR OTHER EXPENSE)
  // ---------------------------------------------------------------------------

  void _openRecordExpenseModal(
    BuildContext context, {
    required double availableBalance,
    required List<PettyCashRequest> unconfirmedRequests,
  }) {
    if (availableBalance <= 0 && unconfirmedRequests.isNotEmpty) {
      final req = unconfirmedRequests.first;
      final amt = req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Receipt Confirmation Needed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Text(
            'You have ${PettyCashService.formatCurrency(amt)} allocated by your Manager awaiting physical receipt confirmation.\n\nYou cannot record expenses until you confirm that you have physically received the cash.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmAmountReceived(req);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm Amount Received', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RecordExpenseBottomSheet(
          supervisorId: widget.supervisorId,
          supervisorName: widget.supervisorName,
          assignedSites: _assignedSites,
          isLoadingSites: _isLoadingSites,
          unconfirmedRequests: unconfirmedRequests,
          onExpenseRecorded: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense recorded successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. MODAL: REQUEST PETTY CASH / REPLENISHMENT
  // ---------------------------------------------------------------------------

  void _openRequestModal(
    BuildContext context, {
    required bool isReplenishment,
    PettyCashAccount? currentAccount,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _CreateRequestDialog(
          supervisorId: widget.supervisorId,
          supervisorName: widget.supervisorName,
          isReplenishment: isReplenishment,
          currentAccount: currentAccount,
          onRequestSubmitted: (reqId) {
            _tabController.animateTo(1);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isReplenishment
                      ? 'Replenishment request submitted to manager!'
                      : 'Petty cash request submitted to manager!',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// EXPENSE RECORDING BOTTOM SHEET COMPONENT
// =============================================================================

class _RecordExpenseBottomSheet extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, String>> assignedSites;
  final bool isLoadingSites;
  final List<PettyCashRequest> unconfirmedRequests;
  final VoidCallback onExpenseRecorded;

  const _RecordExpenseBottomSheet({
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedSites,
    required this.isLoadingSites,
    required this.unconfirmedRequests,
    required this.onExpenseRecorded,
  });

  @override
  State<_RecordExpenseBottomSheet> createState() =>
      _RecordExpenseBottomSheetState();
}

class _RecordExpenseBottomSheetState extends State<_RecordExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _isSiteExpense = true;
  String? _selectedSiteId;
  String? _selectedSiteName;
  String _selectedCategory = 'Office & Site Supplies';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Office & Site Supplies',
    'Transport & Travel',
    'Emergency Repairs',
    'Refreshments & Meals',
    'Loading & Unloading',
    'Fuel & Utilities',
    'Hardware & Fasteners',
    'Other Expenses',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.assignedSites.isNotEmpty) {
      _selectedSiteId = widget.assignedSites.first['siteId'];
      _selectedSiteName = widget.assignedSites.first['siteName'];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<PettyCashAccount?>(
      stream: PettyCashService().streamAccount(widget.supervisorId),
      builder: (context, snapshot) {
        final currentAccount = snapshot.data;
        final availableBalance = currentAccount?.availableBalance ?? 0.0;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle pill
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

                  // Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Petty Cash Expense',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // Available Balance Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Balance:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        Text(
                          PettyCashService.formatCurrency(availableBalance),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.unconfirmedRequests.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Awaiting Confirmation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'You have ${PettyCashService.formatCurrency(widget.unconfirmedRequests.first.allocatedAmount > 0 ? widget.unconfirmedRequests.first.allocatedAmount : widget.unconfirmedRequests.first.requestedAmount)} allocated by your Manager. This amount is awaiting physical receipt confirmation and cannot be used for expenses until confirmed.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 1. Toggle: Site Expense vs Other Expense
                  const Text(
                    'Expense Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeToggle(
                          title: 'Site Expense',
                          icon: Icons.location_city_rounded,
                          isSelected: _isSiteExpense,
                          onTap: () => setState(() => _isSiteExpense = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeToggle(
                          title: 'Other Expense',
                          icon: Icons.miscellaneous_services_rounded,
                          isSelected: !_isSiteExpense,
                          onTap: () => setState(() => _isSiteExpense = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Site Dropdown (Visible only when Site Expense is chosen)
                  if (_isSiteExpense) ...[
                    const Text(
                      'Assigned Site',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    widget.isLoadingSites
                        ? const LinearProgressIndicator()
                        : widget.assignedSites.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFEF3C7)),
                                ),
                                child: const Text(
                                  'No sites currently assigned. Please select "Other Expense" or contact your manager.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedSiteId,
                                isExpanded: true,
                                decoration: _buildInputDecoration(hint: 'Select Site', icon: Icons.domain_rounded),
                                items: widget.assignedSites.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s['siteId'],
                                    child: Text(
                                      '${s['siteName']} (${s['siteId']})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSiteId = val;
                                    final found = widget.assignedSites.firstWhere(
                                      (s) => s['siteId'] == val,
                                      orElse: () => {'siteId': val ?? '', 'siteName': val ?? ''},
                                    );
                                    _selectedSiteName = found['siteName'];
                                  });
                                },
                                validator: (val) {
                                  if (_isSiteExpense && (val == null || val.isEmpty)) {
                                    return 'Please select a site';
                                  }
                                  return null;
                                },
                              ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Expense Category Dropdown
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    decoration: _buildInputDecoration(hint: 'Select Category', icon: Icons.category_rounded),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? _categories.first),
                  ),
                  const SizedBox(height: 14),

                  // 4. Description (Required)
                  const Text(
                    'Description *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    decoration: _buildInputDecoration(
                      hint: 'e.g. Nails, Binding wire, Travel to site',
                      icon: Icons.description_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. Amount Input & Dynamic Balance Validation
                  const Text(
                    'Amount (₹) *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: _buildInputDecoration(
                      hint: '0.00',
                      icon: Icons.currency_rupee_rounded,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      final n = double.tryParse(val.trim());
                      if (n == null || n <= 0) {
                        return 'Enter a valid amount greater than 0';
                      }
                      if (n > availableBalance) {
                        return 'Insufficient balance. Available: ${PettyCashService.formatCurrency(availableBalance)}';
                      }
                      return null;
                    },
                  ),

                  // Dynamic Balance Preview
                  Builder(builder: (context) {
                    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
                    if (enteredAmount > 0) {
                      final rem = availableBalance - enteredAmount;
                      final isDeficit = rem < 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          isDeficit
                              ? '⚠️ Exceeds balance by ${PettyCashService.formatCurrency(-rem)}'
                              : 'Remaining balance after expense: ${PettyCashService.formatCurrency(rem)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDeficit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 14),

                  // 6. Remarks (Optional)
                  const Text(
                    'Remarks (Optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _remarksController,
                    decoration: _buildInputDecoration(
                      hint: 'Optional notes or vendor reference',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7. Expense Date Picker
                  const Text(
                    'Expense Date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const Spacer(),
                          const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || availableBalance <= 0)
                          ? null
                          : () => _submitExpense(availableBalance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              availableBalance <= 0
                                  ? (widget.unconfirmedRequests.isNotEmpty
                                      ? 'Confirm Cash Received Before Spending'
                                      : 'Insufficient Balance')
                                  : 'Save Expense',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeToggle({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? primaryColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? primaryColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
    );
  }

  Future<void> _submitExpense(double availableBalance) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSiteExpense && _selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assigned site.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (widget.unconfirmedRequests.isNotEmpty && amount > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot record expenses against unconfirmed allocations. Please confirm cash receipt on the Petty Cash page first.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (amount <= 0 || amount > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount or exceeds available balance.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService().userData;
      final managerId = (user['managerId'] ?? user['supervisorManagerId'] ?? '').toString();
      final managerName = (user['managerName'] ?? '').toString();

      await PettyCashService().recordExpense(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        managerId: managerId,
        managerName: managerName,
        siteId: _isSiteExpense ? _selectedSiteId : null,
        siteName: _isSiteExpense ? _selectedSiteName : null,
        isSiteExpense: _isSiteExpense,
        expenseCategory: _selectedCategory,
        description: _descController.text.trim(),
        amount: amount,
        transactionDate: _selectedDate,
        remarks: _remarksController.text.trim(),
      );

      if (!mounted) return;
      nav.pop();
      widget.onExpenseRecorded();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// =============================================================================
// CREATE REQUEST / REPLENISHMENT DIALOG
// =============================================================================

class _CreateRequestDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final bool isReplenishment;
  final PettyCashAccount? currentAccount;
  final ValueChanged<String> onRequestSubmitted;

  const _CreateRequestDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.isReplenishment,
    this.currentAccount,
    required this.onRequestSubmitted,
  });

  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

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
    final currentBal = widget.currentAccount?.availableBalance ?? 0.0;
    final totalAlloc = widget.currentAccount?.totalAllocated ?? 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isReplenishment
            ? 'Request Petty Cash Replenishment'
            : 'Request Petty Cash Allocation',
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isReplenishment) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Balance: ${PettyCashService.formatCurrency(currentBal)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Allocated: ${PettyCashService.formatCurrency(totalAlloc)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const Text(
                'Requested Amount (₹) *',
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
                  hintText: 'e.g. 10000',
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

              const Text(
                'Reason / Justification *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: widget.isReplenishment
                      ? 'e.g. Daily site expenses, fuel and urgent hardware supplies'
                      : 'e.g. Initial operational petty cash for site management',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reason is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const Text(
                'Remarks (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _remarksController,
                decoration: InputDecoration(
                  hintText: 'Any additional notes for manager',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
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
              : const Text('Submit Request'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService().userData;
      final managerId = (user['managerId'] ?? user['supervisorManagerId'] ?? '').toString();
      final managerName = (user['managerName'] ?? '').toString();

      final reqId = await PettyCashService().submitRequest(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        requestedAmount: amount,
        reason: _reasonController.text.trim(),
        remarks: _remarksController.text.trim(),
        managerId: managerId,
        managerName: managerName,
        isReplenishment: widget.isReplenishment,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onRequestSubmitted(reqId);
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
