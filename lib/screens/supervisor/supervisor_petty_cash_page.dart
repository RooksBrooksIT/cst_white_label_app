import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/petty_cash_models.dart';
import '../../services/petty_cash_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_storage_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/approval_lifecycle_stepper.dart';

String formatSiteDisplay({String? siteCode, String? siteName, String? siteId}) {
  final code = (siteCode ?? '').trim();
  final name = (siteName ?? '').trim();
  final id = (siteId ?? '').trim();

  if (code.isNotEmpty && name.isNotEmpty) {
    if (name.toUpperCase().startsWith('${code.toUpperCase()}_')) {
      return name;
    }
    return '${code}_$name';
  }
  if (name.isNotEmpty) {
    return name;
  }
  if (id.isNotEmpty) {
    return id;
  }
  return 'Unknown Site';
}

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
  String _expenseFilter = 'All'; // 'All', 'Pending Review', 'Approved', 'Rejected'
  String _expenseTypeFilter = 'All'; // 'All', 'Site Expenses', 'Other Expenses'
  String _requestTypeFilter = 'All'; // 'All', 'Site Requests', 'Other Requests', 'Replenishments'

  Color get primaryColor => Theme.of(context).colorScheme.primary;
  bool _isConfirmingReceipt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final amount = req.disbursedAmount > 0
        ? req.disbursedAmount
        : (req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount);
    final formattedAmt = PettyCashService.formatCurrency(amount);
    final managerName = (req.disbursedBy != null && req.disbursedBy!.isNotEmpty)
        ? req.disbursedBy!
        : ((req.allocatedBy != null && req.allocatedBy!.isNotEmpty)
            ? req.allocatedBy!
            : req.managerName);

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
              'Have you physically received the disbursed petty cash of $formattedAmt from Manager $managerName?',
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
                        'Disbursed Amount:',
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
        final availableBalance = account?.availableBalance ?? 0.0;
        final reservedBalance = account?.reservedBalance ?? 0.0;
        final spendableBalance = account?.spendableBalance ?? availableBalance;
        final totalReturned = account?.totalReturned ?? 0.0;
        final isLowBalance = account?.isLowBalance ?? false;

        return StreamBuilder<List<PettyCashExpense>>(
          stream: _pettyCashService.streamSupervisorExpenses(widget.supervisorId),
          builder: (context, expenseSnap) {
            final allExpenses = expenseSnap.data ?? [];
            final approvedExpenses = allExpenses.where((e) => e.status == PettyCashStatus.expenseApproved).toList();
            final siteSpentTotal = approvedExpenses
                .where((e) => e.isSiteExpense)
                .fold<double>(0.0, (sum, e) => sum + e.amount);
            final otherSpentTotal = approvedExpenses
                .where((e) => !e.isSiteExpense)
                .fold<double>(0.0, (sum, e) => sum + e.amount);
            final totalSpent = siteSpentTotal + otherSpentTotal;

            final pendingReviewExpenses = allExpenses
                .where((e) =>
                    e.status == PettyCashStatus.pendingExpenseReview ||
                    e.status == PettyCashStatus.pendingManagerReview)
                .toList();
            final pendingReviewTotal = pendingReviewExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
            final pendingReviewCount = pendingReviewExpenses.length;

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
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      tabs: const [
                        Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
                        Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Expenses'),
                        Tab(icon: Icon(Icons.history_toggle_off_rounded, size: 18), text: 'Requests'),
                        Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Reconcile & Return'),
                      ],
                    ),
                  ),
                  body: SafeArea(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Overview Tab (Essential Balance -> Request Cash -> Record Expense -> Recent Expenses)
                        _buildOverviewTab(
                          spendableBalance: spendableBalance,
                          totalSpent: totalSpent,
                          reservedBalance: reservedBalance,
                          isLowBalance: isLowBalance,
                          account: account,
                          unconfirmedRequests: unconfirmedRequests,
                          allExpenses: allExpenses,
                        ),

                        // 2. Expenses Tab (Expense history, filters, and categories)
                        _buildExpensesTab(spendableBalance),

                        // 3. Requests Tab (Petty cash requests and statuses)
                        _buildRequestsTab(
                          account,
                          requests: requests,
                          isLoading: reqSnap.connectionState == ConnectionState.waiting,
                        ),

                        // 4. Reconcile & Return Tab (Reconciliation, returns, replenishment, and financial summary)
                        _buildReconciliationAndReturnsTab(
                          account: account,
                          totalAllocated: totalAllocated,
                          totalSpent: totalSpent,
                          siteSpentTotal: siteSpentTotal,
                          otherSpentTotal: otherSpentTotal,
                          pendingReviewTotal: pendingReviewTotal,
                          pendingReviewCount: pendingReviewCount,
                          totalReturned: totalReturned,
                          spendableBalance: spendableBalance,
                        ),
                      ],
                    ),
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _showRecordExpenseSelectionModal(
                      context,
                      spendableBalance: spendableBalance,
                      unconfirmedRequests: unconfirmedRequests,
                      account: account,
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TAB 1: SIMPLIFIED OVERVIEW (ESSENTIAL BALANCE -> ACTIONS -> RECENT EXPENSES)
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab({
    required double spendableBalance,
    required double totalSpent,
    required double reservedBalance,
    required bool isLowBalance,
    required PettyCashAccount? account,
    required List<PettyCashRequest> unconfirmedRequests,
    required List<PettyCashExpense> allExpenses,
  }) {
    final recentExpenses = allExpenses.take(5).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Awaiting Physical Receipt Confirmation Banner
          if (unconfirmedRequests.isNotEmpty)
            _buildAwaitingConfirmationBanner(unconfirmedRequests),

          // Low Balance Alert Banner
          if (isLowBalance)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                          'Low Petty Cash Balance',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          'Spendable: ${PettyCashService.formatCurrency(spendableBalance)}. Request top-up from manager.',
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

          // Top Balance Card (Essential Balance Information - Light Theme)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLowBalance ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                width: isLowBalance ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isLowBalance ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: isLowBalance ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    if (reservedBalance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Reserved: ${PettyCashService.formatCurrency(reservedBalance)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  PettyCashService.formatCurrency(spendableBalance),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isLowBalance ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Text(
                            'Total Spent',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        PettyCashService.formatCurrency(totalSpent),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Actions: Request Cash & Record Expense
          Row(
            children: [
              // Primary Action 1: Request Cash
              Expanded(
                child: InkWell(
                  onTap: () => _showRequestPettyCashSelectionModal(context, account),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Request Cash',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Site or other funds',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Primary Action 2: Record Expense
              Expanded(
                child: InkWell(
                  onTap: () => _showRecordExpenseSelectionModal(
                    context,
                    spendableBalance: spendableBalance,
                    unconfirmedRequests: unconfirmedRequests,
                    account: account,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Record Expense',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Log spent money',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Expenses Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Expenses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (recentExpenses.isNotEmpty)
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All (${allExpenses.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: primaryColor),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (recentExpenses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No expenses recorded yet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Record Expense" above to submit your first expense.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentExpenses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exp = recentExpenses[index];
                return _buildExpenseCard(exp);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepPill({
    required String step,
    required String label,
    required String subLabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            subLabel,
            style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SELECTION MODAL: REQUEST PETTY CASH (SITE VS OTHER REQUEST)
  // ---------------------------------------------------------------------------
  void _showRequestPettyCashSelectionModal(BuildContext context, PettyCashAccount? account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Request Petty Cash',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'What do you need petty cash for?',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Site Request
              _buildSelectionCard(
                icon: Icons.apartment_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: 'Site Request',
                description: 'Request petty cash for a specific construction site.',
                onTap: () {
                  Navigator.pop(ctx);
                  _openRequestModal(context, isReplenishment: false, currentAccount: account);
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Other Request
              _buildSelectionCard(
                icon: Icons.work_outline_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFFFBEB),
                title: 'Other Request',
                description: 'Request petty cash for approved non-site operational expenses.',
                onTap: () {
                  Navigator.pop(ctx);
                  _openOtherExpenseRequestModal(context, currentAccount: account);
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SELECTION MODAL: RECORD EXPENSE (SITE VS OTHER EXPENSE)
  // ---------------------------------------------------------------------------
  void _showRecordExpenseSelectionModal(
    BuildContext context, {
    required double spendableBalance,
    required List<PettyCashRequest> unconfirmedRequests,
    required PettyCashAccount? account,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Record Expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'What type of expense do you have?',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Site Expense
              _buildSelectionCard(
                icon: Icons.apartment_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: 'Site Expense',
                description: 'Record an expense related to a construction site.',
                onTap: () {
                  Navigator.pop(ctx);
                  _openRecordExpenseModal(
                    context,
                    spendableBalance: spendableBalance,
                    unconfirmedRequests: unconfirmedRequests,
                    account: account,
                    initialIsSiteExpense: true,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Other Expense
              _buildSelectionCard(
                icon: Icons.work_outline_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFFFBEB),
                title: 'Other Expense',
                description: 'Record an approved operational expense not linked to a site.',
                onTap: () {
                  Navigator.pop(ctx);
                  _openRecordExpenseModal(
                    context,
                    spendableBalance: spendableBalance,
                    unconfirmedRequests: unconfirmedRequests,
                    account: account,
                    initialIsSiteExpense: false,
                  );
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpentMetricCard({
    required double totalSpent,
    required double siteSpent,
    required double otherSpent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF475569), size: 14),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: Color(0xFF475569), shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            PettyCashService.formatCurrency(totalSpent),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          const Text(
            'Total Spent',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Site: ${PettyCashService.formatCurrency(siteSpent)} | Other: ${PettyCashService.formatCurrency(otherSpent)}',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
    String? subText,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isPrimary ? 0.35 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            PettyCashService.formatCurrency(amount),
            style: TextStyle(
              fontSize: isPrimary ? 15.5 : 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 2),
            Text(
              subText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildAwaitingConfirmationBanner(List<PettyCashRequest> unconfirmedRequests) {
    return Column(
      children: unconfirmedRequests.map((req) {
        final amount = req.disbursedAmount > 0
            ? req.disbursedAmount
            : (req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount);
        final formattedAmt = PettyCashService.formatCurrency(amount);
        final manager = (req.disbursedBy != null && req.disbursedBy!.isNotEmpty)
            ? req.disbursedBy!
            : ((req.allocatedBy != null && req.allocatedBy!.isNotEmpty)
                ? req.allocatedBy!
                : req.managerName);

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
                            'Disbursed by $manager',
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disbursed Amount',
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
                'Amount becomes spendable only after physical cash receipt is confirmed.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TAB 1: EXPENSES LIST (TWO-STAGE EXPENSE WORKFLOW)
  // ---------------------------------------------------------------------------

  Widget _buildExpensesTab(double spendableBalance) {
    return StreamBuilder<List<PettyCashExpense>>(
      stream: _pettyCashService.streamSupervisorExpenses(widget.supervisorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allExpenses = snapshot.data ?? [];

        final filtered = allExpenses.where((e) {
          // 1. Type Filter
          if (_expenseTypeFilter == 'Site Expenses' && !e.isSiteExpense) {
            return false;
          }
          if (_expenseTypeFilter == 'Other Expenses' && e.isSiteExpense) {
            return false;
          }

          // 2. Status Filter
          if (_expenseFilter == 'Pending Review') {
            return e.status == PettyCashStatus.pendingExpenseReview ||
                e.status == PettyCashStatus.pendingManagerReview;
          }
          if (_expenseFilter == 'Approved') {
            return e.status == PettyCashStatus.expenseApproved;
          }
          if (_expenseFilter == 'Rejected') {
            return e.status == PettyCashStatus.expenseRejected;
          }
          return true;
        }).toList();

        final siteExpensesCount = allExpenses.where((e) => e.isSiteExpense).length;
        final otherExpensesCount = allExpenses.where((e) => !e.isSiteExpense).length;

        return Column(
          children: [
            // Filter Strip
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Type Filter Pills (All / Site / Other)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeFilterChip('All Types', allExpenses.length, 'All'),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('Site Expenses', siteExpensesCount, 'Site Expenses', icon: Icons.location_city_rounded),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('Other / Non-Site', otherExpensesCount, 'Other Expenses', icon: Icons.miscellaneous_services_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Status Filter Pills (All / Pending / Approved / Rejected)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilterChip('All Statuses', allExpenses.length, 'All'),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          'Pending Review',
                          allExpenses.where((e) =>
                              e.status == PettyCashStatus.pendingExpenseReview ||
                              e.status == PettyCashStatus.pendingManagerReview).length,
                          'Pending Review',
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          'Approved',
                          allExpenses.where((e) => e.status == PettyCashStatus.expenseApproved).length,
                          'Approved',
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          'Rejected',
                          allExpenses.where((e) => e.status == PettyCashStatus.expenseRejected).length,
                          'Rejected',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expense List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No expenses found',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Record Expense" below to submit a new site or other expense.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final exp = filtered[index];
                        return _buildExpenseCard(exp);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeFilterChip(String label, int count, String typeKey, {IconData? icon}) {
    final isSelected = _expenseTypeFilter == typeKey;
    return InkWell(
      onTap: () => setState(() => _expenseTypeFilter = typeKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 4),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, int count, String filterKey) {
    final isSelected = _expenseFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _expenseFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(PettyCashExpense exp) {
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(exp.transactionDate);
    final isPending = exp.status == PettyCashStatus.pendingExpenseReview ||
        exp.status == PettyCashStatus.pendingManagerReview;
    final isApproved = exp.status == PettyCashStatus.expenseApproved;
    final isRejected = exp.status == PettyCashStatus.expenseRejected;

    Color badgeBg = const Color(0xFFEFF6FF);
    Color badgeColor = const Color(0xFF2563EB);
    String statusLabel = 'POSTED';

    if (isPending) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFFD97706);
      statusLabel = 'PENDING REVIEW';
    } else if (isApproved) {
      badgeBg = const Color(0xFFECFDF5);
      badgeColor = const Color(0xFF059669);
      statusLabel = 'APPROVED';
    } else if (isRejected) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFEF4444);
      statusLabel = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isRejected
                      ? const Color(0xFFFEF2F2)
                      : (isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : (isApproved ? Icons.check_circle_outline_rounded : Icons.pending_outlined),
                  color: isRejected
                      ? const Color(0xFFEF4444)
                      : (isApproved ? const Color(0xFF059669) : const Color(0xFFD97706)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exp.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exp.expenseCategory,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (exp.isSiteExpense) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_city_rounded, size: 10, color: Color(0xFF2563EB)),
                                const SizedBox(width: 3),
                                Text(
                                  exp.siteName?.isNotEmpty == true
                                      ? exp.siteName!
                                      : (exp.siteId?.isNotEmpty == true ? exp.siteId! : 'Site Expense'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE9D5FF)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.miscellaneous_services_rounded, size: 10, color: Color(0xFF7E22CE)),
                                SizedBox(width: 3),
                                Text(
                                  'Personal / Non-Site Expense',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7E22CE),
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
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    PettyCashService.formatCurrency(exp.amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isRejected ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (exp.vendorName != null && exp.vendorName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Payee: ${exp.vendorName}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],

          if (exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  exp.receiptVerified ? 'Receipt Verified' : 'Receipt Attached',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: exp.receiptVerified ? const Color(0xFF059669) : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ] else if (exp.noReceiptReason != null && exp.noReceiptReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No Receipt: ${exp.noReceiptReason}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontStyle: FontStyle.italic),
            ),
          ],

          if (isRejected && exp.rejectionReason != null && exp.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejection Reason: ${exp.rejectionReason}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
              if (isPending)
                const Text(
                  'Reserved from balance',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                )
              else if (isApproved)
                const Text(
                  'Approved & posted to ledger',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
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

    final filteredRequests = requests.where((r) {
      if (_requestTypeFilter == 'site') {
        return !r.isOtherExpense && !r.isReplenishment;
      } else if (_requestTypeFilter == 'other') {
        return r.isOtherExpense;
      } else if (_requestTypeFilter == 'replenishment') {
        return r.isReplenishment;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Pills Row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildRequestTypeFilterChip('All Requests', 'All'),
                const SizedBox(width: 8),
                _buildRequestTypeFilterChip('Site Requests', 'site'),
                const SizedBox(width: 8),
                _buildRequestTypeFilterChip('Other / Non-Site', 'other'),
                const SizedBox(width: 8),
                _buildRequestTypeFilterChip('Replenishments', 'replenishment'),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _requestTypeFilter == 'All'
                            ? 'No petty cash requests found'
                            : 'No ${_requestTypeFilter == 'other' ? 'other expense' : (_requestTypeFilter == 'site' ? 'site' : 'replenishment')} requests found',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openRequestModal(context, isReplenishment: false, currentAccount: account),
                            icon: const Icon(Icons.apartment_rounded, size: 16),
                            label: const Text('Site Request'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openOtherExpenseRequestModal(context, currentAccount: account),
                            icon: const Icon(Icons.work_outline_rounded, size: 16),
                            label: const Text('Other Request'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = filteredRequests[index];
                    return _buildRequestStatusCard(req);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRequestTypeFilterChip(String label, String value) {
    final isSelected = _requestTypeFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _requestTypeFilter = value;
          });
        }
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: req.isOtherExpense
                      ? const Color(0xFFFFFBEB)
                      : (req.isManualManager
                          ? const Color(0xFFFAF5FF)
                          : (req.isReplenishment
                              ? const Color(0xFFF0FDFA)
                              : const Color(0xFFEFF6FF))),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: req.isOtherExpense
                        ? const Color(0xFFFDE68A)
                        : (req.isManualManager
                            ? const Color(0xFFE9D5FF)
                            : (req.isReplenishment
                                ? const Color(0xFF99F6E4)
                                : const Color(0xFFBFDBFE))),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      req.isOtherExpense
                          ? Icons.work_outline_rounded
                          : (req.isReplenishment ? Icons.autorenew_rounded : Icons.apartment_rounded),
                      size: 12,
                      color: req.isOtherExpense
                          ? const Color(0xFFB45309)
                          : (req.isManualManager
                              ? const Color(0xFF7E22CE)
                              : (req.isReplenishment
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF1D4ED8))),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      req.isOtherExpense
                          ? 'OTHER EXPENSE REQUEST'
                          : (req.isManualManager
                              ? 'MANAGER ALLOCATION'
                              : (req.isReplenishment ? 'REPLENISHMENT' : 'SITE REQUEST')),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: req.isOtherExpense
                            ? const Color(0xFFB45309)
                            : (req.isManualManager
                                ? const Color(0xFF7E22CE)
                                : (req.isReplenishment
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF1D4ED8))),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                PettyCashService.formatCurrency(
                    req.requestedAmount > 0 ? req.requestedAmount : req.allocatedAmount),
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
          if (req.isOtherExpense) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (req.expenseCategory != null && req.expenseCategory!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.category_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          req.expenseCategory!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                if (req.requiredDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          'Needed by: ${DateFormat('dd MMM yyyy').format(req.requiredDate!)}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ] else if (req.siteName != null || req.siteId != null) ...[
            const SizedBox(height: 6),
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
          ],
          const SizedBox(height: 4),
          Text(
            'Submitted: $dateStr',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          ApprovalLifecycleStepper(
            status: req.status,
            history: req.approvalHistory,
            rejectionReason: req.rejectionReason,
            isCompact: true,
          ),

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
                      Text(
                        'Amount Disbursed: ${PettyCashService.formatCurrency(req.disbursedAmount > 0 ? req.disbursedAmount : (req.allocatedAmount > 0 ? req.allocatedAmount : req.requestedAmount))}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Awaiting Confirmation',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manager has disbursed cash. Confirm physical receipt to activate spendable balance.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
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
                          : const Icon(Icons.verified_rounded, size: 16),
                      label: const Text(
                        'Confirm Amount Received',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. TAB 3: RECONCILIATIONS & RETURNS TAB
  // ---------------------------------------------------------------------------

  Widget _buildReconciliationAndReturnsTab({
    required PettyCashAccount? account,
    required double totalAllocated,
    required double totalSpent,
    required double siteSpentTotal,
    required double otherSpentTotal,
    required double pendingReviewTotal,
    required int pendingReviewCount,
    required double totalReturned,
    required double spendableBalance,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Detailed Financial Summary
          const Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 1. Total Allocated
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Allocated',
                  amount: totalAllocated,
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  subText: 'Total funds disbursed',
                ),
              ),
              const SizedBox(width: 8),
              // 2. Total Funds Disbursed / Spent
              Expanded(
                child: _buildSpentMetricCard(
                  totalSpent: totalSpent,
                  siteSpent: siteSpentTotal,
                  otherSpent: otherSpentTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 3. Pending Review
              Expanded(
                child: _buildMetricCard(
                  title: 'Pending Review',
                  amount: pendingReviewTotal,
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  subText: '$pendingReviewCount items awaiting manager',
                ),
              ),
              const SizedBox(width: 8),
              // 4. Total Returned
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Returned',
                  amount: totalReturned,
                  icon: Icons.currency_exchange_rounded,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  subText: 'Returned to manager',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Account Actions (Reconcile, Return, Replenish)
          const Text(
            'Account Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // Action 1: Cash Reconciliation
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fact_check_outlined, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Cash Reconciliation',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openReconcileModal(context, currentAccount: account),
                      icon: const Icon(Icons.fact_check_outlined, size: 14),
                      label: const Text('New Count'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Perform physical cash counting and submit reconciliation records for manager review and audit tracking.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: Return Cash
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.currency_exchange_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Cash Returns',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openReturnModal(
                        context,
                        spendableBalance: spendableBalance,
                      ),
                      icon: const Icon(Icons.currency_exchange_rounded, size: 14),
                      label: const Text('Return Cash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Return unused petty cash back to Manager at site closure or fund readjustment.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action 3: Replenishment
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.autorenew_rounded, color: Color(0xFF0F766E), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Replenishment',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openRequestModal(context, isReplenishment: true, currentAccount: account),
                      icon: const Icon(Icons.autorenew_rounded, size: 14),
                      label: const Text('Request Top-Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Request additional petty cash funds to top up your balance when running low.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: How Petty Cash Works
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 6),
                    Text(
                      'How Petty Cash Works',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildWorkflowStepPill(
                        step: '1',
                        label: 'Request',
                        subLabel: 'Site or other',
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                    Expanded(
                      child: _buildWorkflowStepPill(
                        step: '2',
                        label: 'Approval',
                        subLabel: 'Manager review',
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                    Expanded(
                      child: _buildWorkflowStepPill(
                        step: '3',
                        label: 'Spend',
                        subLabel: 'Record expense',
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                    Expanded(
                      child: _buildWorkflowStepPill(
                        step: '4',
                        label: 'Track',
                        subLabel: 'Live ledger',
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // 5. MODAL: RECORD EXPENSE (TWO-STAGE FLOW)
  // ---------------------------------------------------------------------------

  void _openRecordExpenseModal(
    BuildContext context, {
    required double spendableBalance,
    required List<PettyCashRequest> unconfirmedRequests,
    required PettyCashAccount? account,
    bool initialIsSiteExpense = true,
  }) {
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
          spendableBalance: spendableBalance,
          account: account,
          initialIsSiteExpense: initialIsSiteExpense,
          onExpenseRecorded: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense submitted for Manager review!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. MODAL: RECONCILE CASH
  // ---------------------------------------------------------------------------

  void _openReconcileModal(BuildContext context, {PettyCashAccount? currentAccount}) {
    showDialog(
      context: context,
      builder: (ctx) => _ReconcileCashDialog(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        assignedSites: _assignedSites,
        currentAccount: currentAccount,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. MODAL: RETURN CASH
  // ---------------------------------------------------------------------------

  void _openReturnModal(BuildContext context, {required double spendableBalance}) {
    showDialog(
      context: context,
      builder: (ctx) => _ReturnCashDialog(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        assignedSites: _assignedSites,
        spendableBalance: spendableBalance,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. MODAL: CREATE REQUEST
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
          assignedSites: _assignedSites,
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

  // ---------------------------------------------------------------------------
  // 9. MODAL: CREATE OTHER EXPENSE REQUEST (NON-SITE / PERSONAL EXPENSE)
  // ---------------------------------------------------------------------------

  void _openOtherExpenseRequestModal(
    BuildContext context, {
    PettyCashAccount? currentAccount,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _CreateOtherExpenseRequestDialog(
          supervisorId: widget.supervisorId,
          supervisorName: widget.supervisorName,
          currentAccount: currentAccount,
          onRequestSubmitted: (reqId) {
            _tabController.animateTo(1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Other expense request submitted to manager!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// RECORD EXPENSE BOTTOM SHEET COMPONENT (TWO-STAGE FLOW & RECEIPT VALIDATION)
// =============================================================================

class _RecordExpenseBottomSheet extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, String>> assignedSites;
  final bool isLoadingSites;
  final List<PettyCashRequest> unconfirmedRequests;
  final double spendableBalance;
  final PettyCashAccount? account;
  final bool initialIsSiteExpense;
  final VoidCallback onExpenseRecorded;

  const _RecordExpenseBottomSheet({
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedSites,
    required this.isLoadingSites,
    required this.unconfirmedRequests,
    required this.spendableBalance,
    this.account,
    this.initialIsSiteExpense = true,
    required this.onExpenseRecorded,
  });

  @override
  State<_RecordExpenseBottomSheet> createState() => _RecordExpenseBottomSheetState();
}

class _RecordExpenseBottomSheetState extends State<_RecordExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _noReceiptReasonController = TextEditingController();

  bool _isSiteExpense = true;
  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedSiteCode;
  String? _selectedProjectId;
  String? _selectedProjectName;
  String _selectedCategory = 'Office & Site Supplies';
  DateTime _selectedDate = DateTime.now();
  File? _receiptFile;
  String? _uploadedReceiptUrl;
  bool _isUploadingReceipt = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  StreamSubscription<PettyCashAccount?>? _siteAccountSub;
  PettyCashAccount? _siteAccount;
  bool _isLoadingSiteAccount = false;

  final List<String> _categories = [
    'Office & Site Supplies',
    'Transport & Travel',
    'Emergency Repairs',
    'Refreshments & Meals',
    'Loading & Unloading',
    'Fuel & Utilities',
    'Hardware & Fasteners',
    'Other / Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    _isSiteExpense = widget.initialIsSiteExpense;
    if (_isSiteExpense && widget.assignedSites.isNotEmpty) {
      final first = widget.assignedSites.first;
      _selectedSiteId = first['siteId'];
      _selectedSiteName = first['siteName'];
      _selectedSiteCode = first['siteCode'] ?? first['SiteCode'];
      _selectedProjectId = first['projectId'];
      _selectedProjectName = first['projectName'];
      _fetchSiteAccount(_selectedSiteId);
    } else if (!_isSiteExpense) {
      _selectedCategory = 'Other / Miscellaneous';
    }
  }

  void _fetchSiteAccount(String? siteId) {
    _siteAccountSub?.cancel();
    if (siteId == null || siteId.trim().isEmpty) {
      setState(() {
        _siteAccount = null;
        _isLoadingSiteAccount = false;
      });
      return;
    }
    setState(() => _isLoadingSiteAccount = true);
    _siteAccountSub = PettyCashService().streamSiteAccount(siteId).listen((acc) {
      if (mounted) {
        setState(() {
          _siteAccount = acc;
          _isLoadingSiteAccount = false;
          if (acc == null && widget.account == null && _isSiteExpense) {
            _errorMessage = 'No petty cash account found for this site. Please request fund allocation before recording an expense.';
          } else if (_errorMessage == 'No petty cash account found for this site. Please request fund allocation before recording an expense.') {
            _errorMessage = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _siteAccountSub?.cancel();
    _amountController.dispose();
    _descController.dispose();
    _vendorController.dispose();
    _remarksController.dispose();
    _noReceiptReasonController.dispose();
    super.dispose();
  }

  double get _currentSpendableBalance {
    if (_isSiteExpense && _siteAccount != null) {
      return _siteAccount!.spendableBalance;
    }
    if (widget.account != null && widget.account!.spendableBalance > 0) {
      return widget.account!.spendableBalance;
    }
    if (_siteAccount != null && _siteAccount!.spendableBalance > 0) {
      return _siteAccount!.spendableBalance;
    }
    return widget.spendableBalance;
  }

  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _receiptFile = File(picked.path);
        _isUploadingReceipt = true;
        _errorMessage = null;
      });

      try {
        final res = await AppStorageService.uploadFile(
          category: 'petty_cash_receipts',
          fileName: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
          file: _receiptFile,
        );
        if (mounted) {
          setState(() {
            _uploadedReceiptUrl = res?.downloadUrl;
            _isUploadingReceipt = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploadingReceipt = false;
            _errorMessage = 'Failed to upload receipt: $e';
          });
        }
      }
    }
  }

  Widget _buildInlineErrorMessage() {
    if (_errorMessage == null || _errorMessage!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 19,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB91C1C),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.close_rounded,
                size: 17,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final maxSpendable = _currentSpendableBalance;

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final isReceiptRequired = enteredAmount >= 500.0 && (_uploadedReceiptUrl == null || _uploadedReceiptUrl!.isEmpty);

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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isSiteExpense ? 'Site Spendable Balance:' : 'Supervisor Spendable Balance:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    _isLoadingSiteAccount
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            PettyCashService.formatCurrency(maxSpendable),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: maxSpendable > 0 ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Expense Type Toggle
              const Text(
                'Expense Type *',
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
                      onTap: () => setState(() {
                        _isSiteExpense = true;
                        _errorMessage = null;
                        if (widget.assignedSites.isNotEmpty && (_selectedSiteId == null || _selectedSiteId!.isEmpty)) {
                          final first = widget.assignedSites.first;
                          _selectedSiteId = first['siteId'];
                          _selectedSiteName = first['siteName'];
                          _selectedSiteCode = first['siteCode'] ?? first['SiteCode'];
                          _selectedProjectId = first['projectId'];
                          _selectedProjectName = first['projectName'];
                          _fetchSiteAccount(_selectedSiteId);
                        }
                        if (_selectedCategory == 'Other / Miscellaneous') {
                          _selectedCategory = 'Office & Site Supplies';
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeToggle(
                      title: 'Other Expense',
                      icon: Icons.miscellaneous_services_rounded,
                      isSelected: !_isSiteExpense,
                      onTap: () => setState(() {
                        _isSiteExpense = false;
                        _errorMessage = null;
                        _selectedSiteId = null;
                        _selectedSiteName = null;
                        _selectedSiteCode = null;
                        _selectedProjectId = null;
                        _selectedProjectName = null;
                        _fetchSiteAccount(null);
                        _selectedCategory = 'Other / Miscellaneous';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Site Dropdown (Visible only for Site Expenses)
              if (_isSiteExpense) ...[
                const Text(
                  'Assigned Construction Site *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                widget.isLoadingSites
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedSiteId,
                        isExpanded: true,
                        decoration: _buildInputDecoration(hint: 'Select Site', icon: Icons.domain_rounded),
                        items: widget.assignedSites.map((s) {
                          final display = formatSiteDisplay(
                            siteCode: s['siteCode'] ?? s['SiteCode'],
                            siteName: s['siteName'],
                            siteId: s['siteId'],
                          );
                          return DropdownMenuItem<String>(
                            value: s['siteId'],
                            child: Text(
                              display,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSiteId = val;
                            _errorMessage = null;
                            final found = widget.assignedSites.firstWhere(
                              (s) => s['siteId'] == val,
                              orElse: () => {'siteId': val ?? '', 'siteName': val ?? ''},
                            );
                            _selectedSiteName = found['siteName'];
                            _selectedSiteCode = found['siteCode'] ?? found['SiteCode'];
                            _selectedProjectId = found['projectId'];
                            _selectedProjectName = found['projectName'];
                          });
                          _fetchSiteAccount(val);
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

              // Category
              const Text(
                'Category *',
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
                onChanged: (val) => setState(() {
                  _selectedCategory = val ?? _categories.first;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: 14),

              // Description
              Text(
                _isSiteExpense ? 'Description / Purpose *' : 'Non-Site Purpose & Details *',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                decoration: _buildInputDecoration(
                  hint: _isSiteExpense
                      ? 'e.g. Nails, Binding wire, Travel to site, Emergency cement'
                      : 'e.g. Personal travel allowance, Office courier, Vehicle fuel',
                  icon: Icons.description_outlined,
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Description is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Vendor Name
              const Text(
                'Vendor / Payee Name (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _vendorController,
                decoration: _buildInputDecoration(
                  hint: 'e.g. Sri Hardware, Local Auto, Fuel Station',
                  icon: Icons.store_rounded,
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 14),

              // Amount
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
                onChanged: (_) => setState(() => _errorMessage = null),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Amount is required';
                  final n = double.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount greater than 0';
                  if (n > maxSpendable) {
                    return 'Exceeds spendable balance (${PettyCashService.formatCurrency(maxSpendable)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Receipt Attachment Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    enteredAmount >= 500.0 ? 'Bill / Receipt Image (Required ≥ ₹500)' : 'Bill / Receipt Image (Optional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: enteredAmount >= 500.0 ? const Color(0xFFD97706) : const Color(0xFF334155),
                    ),
                  ),
                  if (_uploadedReceiptUrl != null)
                    const Text('Uploaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isUploadingReceipt ? null : _pickReceiptImage,
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
                      _isUploadingReceipt
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _uploadedReceiptUrl != null ? 'Receipt Attached (Tap to replace)' : 'Attach Bill / Receipt Photo',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isReceiptRequired) ...[
                const SizedBox(height: 12),
                const Text(
                  'Reason for No Receipt *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noReceiptReasonController,
                  decoration: _buildInputDecoration(
                    hint: 'Explain why receipt was unavailable (Required for ≥ ₹500)',
                    icon: Icons.announcement_outlined,
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                  validator: (val) {
                    if (isReceiptRequired && (val == null || val.trim().isEmpty)) {
                      return 'Please attach receipt or provide a justification';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),

              // Date Picker
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
                  if (picked != null) setState(() => _selectedDate = picked);
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
              const SizedBox(height: 16),

              // Inline Error Message Box (Visible on errors, keeps modal open)
              _buildInlineErrorMessage(),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Expense for Review', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _submitExpense() async {
    setState(() => _errorMessage = null);

    if (_isSiteExpense && (_selectedSiteId == null || _selectedSiteId!.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Please select an assigned site before recording a site expense.';
      });
      return;
    }

    if (_isSiteExpense && _siteAccount == null && widget.account == null) {
      setState(() {
        _errorMessage = 'No petty cash account found for this site. Please request fund allocation before recording an expense.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final maxSpendable = _currentSpendableBalance;

    if (amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid expense amount greater than ₹0.';
      });
      return;
    }

    if (amount > maxSpendable) {
      setState(() {
        _errorMessage = 'Expense amount (${PettyCashService.formatCurrency(amount)}) exceeds available spendable balance (${PettyCashService.formatCurrency(maxSpendable)}).';
      });
      return;
    }

    final isReceiptRequired = amount >= PettyCashService.defaultReceiptThreshold &&
        (_uploadedReceiptUrl == null || _uploadedReceiptUrl!.isEmpty);
    if (isReceiptRequired && _noReceiptReasonController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please attach a bill/receipt photo or provide a reason for missing receipt (required for ≥ ₹500).';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService().userData;
      final managerId = (user['managerId'] ?? user['supervisorManagerId'] ?? '').toString();
      final managerName = (user['managerName'] ?? '').toString();

      await PettyCashService().submitExpense(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        managerId: managerId,
        managerName: managerName,
        expenseType: _isSiteExpense ? 'site' : 'other',
        siteId: _isSiteExpense ? _selectedSiteId : null,
        siteName: _isSiteExpense ? _selectedSiteName : null,
        siteCode: _isSiteExpense ? _selectedSiteCode : null,
        projectId: _isSiteExpense ? _selectedProjectId : null,
        projectName: _isSiteExpense ? _selectedProjectName : null,
        vendorName: _vendorController.text.trim().isNotEmpty ? _vendorController.text.trim() : null,
        isSiteExpense: _isSiteExpense,
        expenseCategory: _selectedCategory,
        description: _descController.text.trim(),
        amount: amount,
        transactionDate: _selectedDate,
        remarks: _remarksController.text.trim(),
        receiptUrl: _uploadedReceiptUrl,
        noReceiptReason: _noReceiptReasonController.text.trim().isNotEmpty ? _noReceiptReasonController.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onExpenseRecorded();
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString().replaceFirst('Exception: ', '').trim();
      String friendlyMessage = rawError;
      if (rawError.toLowerCase().contains('no petty cash account found')) {
        friendlyMessage = 'No petty cash account found for this site. Please request fund allocation before recording an expense.';
      } else if (rawError.toLowerCase().contains('insufficient spendable balance')) {
        friendlyMessage = 'Insufficient spendable balance for this expense. Please request fund replenishment.';
      }
      setState(() {
        _errorMessage = friendlyMessage;
        _isSubmitting = false;
      });
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// =============================================================================
// RECONCILE CASH DIALOG COMPONENT
// =============================================================================

class _ReconcileCashDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, String>> assignedSites;
  final PettyCashAccount? currentAccount;

  const _ReconcileCashDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedSites,
    this.currentAccount,
  });

  @override
  State<_ReconcileCashDialog> createState() => _ReconcileCashDialogState();
}

class _ReconcileCashDialogState extends State<_ReconcileCashDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _physicalCashController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedSiteId;
  String? _selectedSiteName;
  double _expectedCash = 0.0;
  bool _isLoadingExpected = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignedSites.isNotEmpty) {
      _selectedSiteId = widget.assignedSites.first['siteId'];
      _selectedSiteName = widget.assignedSites.first['siteName'];
    }
    _computeExpected();
  }

  Future<void> _computeExpected() async {
    setState(() => _isLoadingExpected = true);
    final expected = await PettyCashService().calculateExpectedCash(
      supervisorId: widget.supervisorId,
      siteId: _selectedSiteId,
    );
    if (mounted) {
      setState(() {
        _expectedCash = expected;
        _isLoadingExpected = false;
      });
    }
  }

  @override
  void dispose() {
    _physicalCashController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final physical = double.tryParse(_physicalCashController.text.trim()) ?? 0.0;
    final diff = physical - _expectedCash;
    final hasDiscrepancy = diff.abs() > 0.01 && _physicalCashController.text.trim().isNotEmpty;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Physical Cash Reconciliation', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('System Expected Cash:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    _isLoadingExpected
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            PettyCashService.formatCurrency(_expectedCash),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text('Physical Cash Counted (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _physicalCashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Physical cash count is required';
                  final n = double.tryParse(val.trim());
                  if (n == null || n < 0) return 'Enter a valid amount ≥ 0';
                  return null;
                },
              ),

              if (hasDiscrepancy) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Difference: ${diff >= 0 ? '+' : ''}${PettyCashService.formatCurrency(diff)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: diff < 0 ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          hintText: 'Explanation for difference *',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                        validator: (val) {
                          if (hasDiscrepancy && (val == null || val.trim().isEmpty)) {
                            return 'Discrepancy explanation is mandatory';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              const Text('Notes / Remarks (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any audit observations',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          onPressed: _isSubmitting ? null : _submitReconciliation,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Reconciliation'),
        ),
      ],
    );
  }

  Future<void> _submitReconciliation() async {
    if (!_formKey.currentState!.validate()) return;
    final physical = double.tryParse(_physicalCashController.text.trim()) ?? 0.0;

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService().userData;
      final managerId = (user['managerId'] ?? user['supervisorManagerId'] ?? '').toString();
      final managerName = (user['managerName'] ?? '').toString();

      await PettyCashService().submitReconciliation(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        managerId: managerId,
        managerName: managerName,
        siteId: _selectedSiteId,
        siteName: _selectedSiteName,
        expectedCash: _expectedCash,
        physicalCash: physical,
        differenceReason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconciliation submitted for manager review!'), backgroundColor: Color(0xFF10B981)),
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

// =============================================================================
// RETURN CASH DIALOG COMPONENT
// =============================================================================

class _ReturnCashDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<Map<String, String>> assignedSites;
  final double spendableBalance;

  const _ReturnCashDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedSites,
    required this.spendableBalance,
  });

  @override
  State<_ReturnCashDialog> createState() => _ReturnCashDialogState();
}

class _ReturnCashDialogState extends State<_ReturnCashDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedSiteId;
  String? _selectedSiteName;
  bool _isSubmitting = false;

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
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Return Petty Cash to Manager', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spendable Balance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      PettyCashService.formatCurrency(widget.spendableBalance),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text('Return Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Amount is required';
                  final n = double.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount > 0';
                  if (n > widget.spendableBalance) return 'Exceeds spendable balance';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const Text('Reason for Return *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Site work completed, excess funds handed back to manager',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reason is required';
                  return null;
                },
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
          onPressed: _isSubmitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Return'),
        ),
      ],
    );
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService().userData;
      final managerId = (user['managerId'] ?? user['supervisorManagerId'] ?? '').toString();
      final managerName = (user['managerName'] ?? '').toString();

      await PettyCashService().submitCashReturn(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        managerId: managerId,
        managerName: managerName,
        siteId: _selectedSiteId,
        siteName: _selectedSiteName,
        returnAmount: amount,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash return submitted to manager for confirmation!'), backgroundColor: Color(0xFF10B981)),
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

// =============================================================================
// CREATE REQUEST / REPLENISHMENT DIALOG
// =============================================================================

class _CreateRequestDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final bool isReplenishment;
  final PettyCashAccount? currentAccount;
  final List<Map<String, String>> assignedSites;
  final ValueChanged<String> onRequestSubmitted;

  const _CreateRequestDialog({
    required this.supervisorId,
    required this.supervisorName,
    required this.isReplenishment,
    this.currentAccount,
    this.assignedSites = const [],
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

  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedProjectId;
  String? _selectedProjectName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignedSites.isNotEmpty) {
      final first = widget.assignedSites.first;
      _selectedSiteId = first['siteId'];
      _selectedSiteName = first['siteName'];
      _selectedProjectId = first['projectId'];
      _selectedProjectName = first['projectName'];
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
    final spendable = widget.currentAccount?.spendableBalance ?? 0.0;
    final totalAlloc = widget.currentAccount?.totalAllocated ?? 0.0;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isReplenishment
            ? 'Request Petty Cash Replenishment'
            : 'Request Petty Cash Allocation',
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
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
                      Expanded(
                        child: Text(
                          'Spendable: ${PettyCashService.formatCurrency(spendable)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Allocated: ${PettyCashService.formatCurrency(totalAlloc)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const Text('Associated Site *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedSiteId,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
                items: widget.assignedSites.map((s) {
                  final display = formatSiteDisplay(
                    siteCode: s['siteCode'] ?? s['SiteCode'],
                    siteName: s['siteName'],
                    siteId: s['siteId'],
                  );
                  return DropdownMenuItem<String>(
                    value: s['siteId'],
                    child: Text(
                      display,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSiteId = val;
                    final found = widget.assignedSites.firstWhere(
                      (s) => s['siteId'] == val,
                      orElse: () => {'siteId': '', 'siteName': ''},
                    );
                    _selectedSiteName = found['siteName']?.isNotEmpty == true ? found['siteName'] : null;
                    _selectedProjectId = found['projectId'];
                    _selectedProjectName = found['projectName'];
                  });
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please select an assigned site';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const Text('Requested Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

              const Text('Reason / Justification *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

              const Text('Remarks (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
        projectId: _selectedProjectId,
        projectName: _selectedProjectName,
        siteId: _selectedSiteId ?? '',
        siteName: _selectedSiteName ?? '',
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

// =============================================================================
// CREATE OTHER EXPENSE REQUEST DIALOG (NON-SITE / PERSONAL EXPENSE)
// =============================================================================

class _CreateOtherExpenseRequestDialog extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final PettyCashAccount? currentAccount;
  final ValueChanged<String> onRequestSubmitted;

  const _CreateOtherExpenseRequestDialog({
    required this.supervisorId,
    required this.supervisorName,
    this.currentAccount,
    required this.onRequestSubmitted,
  });

  @override
  State<_CreateOtherExpenseRequestDialog> createState() => _CreateOtherExpenseRequestDialogState();
}

class _CreateOtherExpenseRequestDialogState extends State<_CreateOtherExpenseRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedCategory = 'Travel & Conveyance';
  DateTime? _requiredDate;
  File? _docFile;
  String? _uploadedDocUrl;
  bool _isUploadingDoc = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Travel & Conveyance',
    'Food & Meals',
    'Office Stationery & Supplies',
    'Mobile & Internet Recharge',
    'Emergency Operational Expenses',
    'Accommodation & Lodging',
    'Training / Certification',
    'Other / Miscellaneous',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _docFile = File(picked.path);
        _isUploadingDoc = true;
      });

      try {
        final res = await AppStorageService.uploadFile(
          category: 'petty_cash_documents',
          fileName: 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
          file: _docFile,
        );
        if (mounted) {
          setState(() {
            _uploadedDocUrl = res?.downloadUrl;
            _isUploadingDoc = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploadingDoc = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  Future<void> _pickRequiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _requiredDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Icon(Icons.work_outline_rounded, size: 20, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Other Expense Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Personal or Non-Site Petty Cash',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Form(
          key: _formKey,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner explaining non-site nature
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This request is for non-site or supervisor operational expenses. It will not be linked to any construction site ledger.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Expense Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.category_outlined, size: 18, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                const Text('Requested Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'e.g. 2500',
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

                const Text('Required By Date (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickRequiredDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              _requiredDate != null
                                  ? DateFormat('dd MMM yyyy').format(_requiredDate!)
                                  : 'Select needed date (optional)',
                              style: TextStyle(
                                fontSize: 13,
                                color: _requiredDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontWeight: _requiredDate != null ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        if (_requiredDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _requiredDate = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Purpose / Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Travel expenses for supplier meeting, internet pack recharge',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Purpose is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                const Text('Remarks (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksController,
                  decoration: InputDecoration(
                    hintText: 'Any extra details or manager reference notes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),

                // Supporting Document / Quotation Upload
                const Text('Supporting Quotation / Document (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isUploadingDoc ? null : _pickDocumentImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isUploadingDoc
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _uploadedDocUrl != null
                                ? 'Document Attached ✓'
                                : (_isUploadingDoc ? 'Uploading document...' : 'Attach estimate / document'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _uploadedDocUrl != null ? FontWeight.w700 : FontWeight.w500,
                              color: _uploadedDocUrl != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        if (_uploadedDocUrl != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () {
                              setState(() {
                                _uploadedDocUrl = null;
                                _docFile = null;
                              });
                            },
                          ),
                      ],
                    ),
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
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Other Request'),
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
        isReplenishment: false,
        isSiteExpense: false,
        expenseType: 'other',
        expenseCategory: _selectedCategory,
        requiredDate: _requiredDate,
        documentUrl: _uploadedDocUrl,
        siteId: null,
        siteName: null,
        projectId: null,
        projectName: null,
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
