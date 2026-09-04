import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/approval_workflow_service.dart';
import 'package:demo_cst/widgets/approval_lifecycle_stepper.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  String get _currentUserName {
    final ud = AuthService().userData;
    return ud['name'] ?? ud['userName'] ?? ud['email'] ?? 'Manager';
  }

  String get _currentUserId {
    final ud = AuthService().userData;
    return ud['userId'] ?? ud['id'] ?? '';
  }

  UserRole get _currentUserRole => AuthService().userRole;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Workforce Request Approvals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: Column(
              children: [
                // TabBar Container
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: "1. MGR REVIEW"),
                      Tab(text: "2. ORG APPROVAL"),
                      Tab(text: "3. MGR CLEARANCE"),
                      Tab(text: "APPROVED"),
                    ],
                    labelColor: const Color(0xFF6366F1),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                    unselectedLabelColor: const Color(0xFF64748B),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    indicatorColor: const Color(0xFF6366F1),
                    indicatorWeight: 3,
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search Workforce Requests by ID, Site, Supervisor, Stage...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF6366F1),
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: Color(0xFF64748B), size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 1.6),
                      ),
                    ),
                  ),
                ),

                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsList(
                        targetStage: ApprovalStage.pendingManagerReview,
                        emptyMessage: 'No workforce requests waiting for Manager Review',
                      ),
                      _buildRequestsList(
                        targetStage: ApprovalStage.pendingOrgApproval,
                        emptyMessage:
                            'No workforce requests waiting for Organization Approval',
                      ),
                      _buildRequestsList(
                        targetStage: ApprovalStage.pendingManagerClearance,
                        emptyMessage:
                            'No workforce requests waiting for Final Manager Clearance',
                      ),
                      _buildRequestsList(
                        targetStage: ApprovalStage.approved,
                        emptyMessage: 'No approved workforce allocations found',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList({
    required ApprovalStage targetStage,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.siteSupervisorProjectStageSchedule.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading workforce requests: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final status = data['status']?.toString() ?? data['approvalStatus']?.toString();
          final stage = ApprovalWorkflowService.parseStatus(status);

          if (stage != targetStage) return false;

          if (_searchQuery.isEmpty) return true;

          final reqId = (data['wsReqId'] ?? data['id'] ?? doc.id).toString().toLowerCase();
          final siteId = (data['siteId'] ?? '').toString().toLowerCase();
          final supervisor = (data['supervisorName'] ?? '').toString().toLowerCase();
          final projectStage = (data['projectStage'] ?? '').toString().toLowerCase();

          return reqId.contains(_searchQuery) ||
              siteId.contains(_searchQuery) ||
              supervisor.contains(_searchQuery) ||
              projectStage.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  emptyMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            return _buildRequestCard(doc.data(), doc.id, targetStage);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> data,
    String docId,
    ApprovalStage stage,
  ) {
    final reqId = data['wsReqId'] ?? data['id'] ?? docId;
    final siteId = data['siteId'] ?? 'N/A';
    final supervisor = data['supervisorName'] ?? 'Supervisor';
    final projectStage = data['projectStage'] ?? 'N/A';
    final date = data['date'] ?? '';
    final reqDays = data['reqDays'] ?? data['days'] ?? 1;
    final labours = List<Map<String, dynamic>>.from(data['reqLabours'] ?? data['labours'] ?? []);
    final rawPayment = data['estimatedPayment'] ?? data['payment'] ?? 0;
    final num estimatedPayment = (rawPayment is num) ? rawPayment : (num.tryParse(rawPayment.toString()) ?? 0);
    final history = List<dynamic>.from(data['approvalHistory'] ?? []);
    final status = data['status']?.toString() ?? data['approvalStatus']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () => _showRequestDetailsModal(data, docId, stage),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.groups_rounded,
                            color: Color(0xFF6366F1), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Workforce Req $reqId',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStageColor(stage).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ApprovalWorkflowService.getStatusDisplayText(status),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _getStageColor(stage),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Text(
                'Site: $siteId • Supervisor: $supervisor',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Stage: $projectStage • $reqDays Days • ${labours.length} Roles • ${_currencyFormat.format(estimatedPayment)} • $date',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),

              // Visual Stepper
              ApprovalLifecycleStepper(
                status: status,
                history: history,
                isCompact: true,
              ),
              const SizedBox(height: 10),

              // Quick Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text(
                      'Review & Actions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: BorderSide(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () =>
                        _showRequestDetailsModal(data, docId, stage),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DETAILS & ACTION MODAL ---
  void _showRequestDetailsModal(
    Map<String, dynamic> data,
    String docId,
    ApprovalStage stage,
  ) {
    final reqId = data['wsReqId'] ?? data['id'] ?? docId;
    final siteId = data['siteId'] ?? 'N/A';
    final supervisor = data['supervisorName'] ?? 'Supervisor';
    final projectStage = data['projectStage'] ?? 'N/A';
    final reqDays = data['reqDays'] ?? data['days'] ?? 1;
    final labours = List<Map<String, dynamic>>.from(data['reqLabours'] ?? data['labours'] ?? []);
    final history = List<dynamic>.from(data['approvalHistory'] ?? []);
    final status = data['status']?.toString() ?? data['approvalStatus']?.toString();
    final rawPayment = data['estimatedPayment'] ?? data['payment'] ?? 0;
    final num estimatedPayment = (rawPayment is num) ? rawPayment : (num.tryParse(rawPayment.toString()) ?? 0);

    final isOrgUser = _currentUserRole == UserRole.organization;
    final isManagerUser = _currentUserRole == UserRole.manager || !isOrgUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.engineering_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workforce Request #$reqId',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildModalTagPill(Icons.location_on_rounded, 'Site: $siteId', primaryColor),
                            _buildModalTagPill(Icons.layers_rounded, 'Stage: $projectStage', const Color(0xFF6366F1)),
                            _buildModalTagPill(Icons.person_rounded, 'By: $supervisor', const Color(0xFF059669)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Full Stepper
              ApprovalLifecycleStepper(
                status: status,
                history: history,
                isCompact: false,
              ),
              const SizedBox(height: 14),

              // Summary Stat Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Duration', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          Text('$reqDays Working Days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Est. Wages', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          Text(_currencyFormat.format(estimatedPayment), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Labour Roles Header
              const Text(
                'Requested Labour & Trades',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Labour Items
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: labours.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 6),
                  itemBuilder: (c, i) {
                    final lab = labours[i];
                    final roleName = lab['labourDesignation'] ?? lab['labourRole'] ?? lab['role'] ?? 'Labour';
                    final count = lab['labourCount'] ?? lab['count'] ?? 1;
                    final wage = lab['labourWage'] ?? lab['wage'] ?? 0;
                    final num wageNum = (wage is num) ? wage : (num.tryParse(wage.toString()) ?? 0);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Daily Rate: ${_currencyFormat.format(wageNum)} / day',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Qty: $count Workers',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              _buildActionButtons(ctx, data, docId, stage, isManagerUser, isOrgUser),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalTagPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext ctx,
    Map<String, dynamic> data,
    String docId,
    ApprovalStage stage,
    bool isManager,
    bool isOrg,
  ) {
    final supervisorName = data['supervisorName']?.toString() ?? 'Supervisor';

    if (stage == ApprovalStage.pendingManagerReview && isManager) {
      return Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
              label: const Text(
                'Reject',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
              onPressed: () => _showRejectDialog(
                ctx,
                docId: docId,
                supervisorName: supervisorName,
                isOrgReject: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Verify & Forward to Org',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showForwardToOrgDialog(ctx, docId),
              ),
            ),
          ),
        ],
      );
    }

    if (stage == ApprovalStage.pendingOrgApproval && isOrg) {
      return Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
              label: const Text(
                'Reject',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
              onPressed: () => _showRejectDialog(
                ctx,
                docId: docId,
                supervisorName: supervisorName,
                isOrgReject: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text(
                  'Authorize & Send to Manager',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showOrgApproveDialog(ctx, docId, supervisorName),
              ),
            ),
          ),
        ],
      );
    }

    if (stage == ApprovalStage.pendingManagerClearance && isManager) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text(
            'Complete Final Clearance & Deploy Workforce',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _showFinalClearanceDialog(ctx, docId, supervisorName),
        ),
      );
    }

    if (stage == ApprovalStage.approved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 6),
              Text(
                'Workforce Allocation is fully Approved & Active',
                style: TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- ACTION DIALOGS ---

  void _showForwardToOrgDialog(BuildContext sheetCtx, String docId) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Forward to Organization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add verification remarks before forwarding workforce schedule requisition to Organization for approval:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Labour strength & wages verified for this stage.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              Navigator.pop(sheetCtx);
              await ApprovalWorkflowService.managerVerifyAndForward(
                collectionName: 'siteSupervisorProjectStageSchedule',
                docId: docId,
                managerName: _currentUserName,
                managerId: _currentUserId,
                remarks: remarksController.text.trim(),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Workforce request verified & forwarded to Organization!')),
              );
            },
            child: const Text('Forward', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOrgApproveDialog(BuildContext sheetCtx, String docId, String supName) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Authorize Workforce Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authorize labour deployment. Returned to Manager for site deployment clearance:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Budget & contractor quota authorized by HQ.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              Navigator.pop(sheetCtx);
              await ApprovalWorkflowService.orgApprove(
                collectionName: 'siteSupervisorProjectStageSchedule',
                docId: docId,
                orgUserName: _currentUserName,
                orgUserId: _currentUserId,
                remarks: remarksController.text.trim(),
                supervisorName: supName,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Workforce schedule authorized and returned to Manager!')),
              );
            },
            child: const Text('Authorize', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFinalClearanceDialog(BuildContext sheetCtx, String docId, String supName) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Complete Final Clearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete final clearance and release workforce schedule for site deployment:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Workers briefed and deployed on site.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              Navigator.pop(sheetCtx);
              await ApprovalWorkflowService.managerFinalClearance(
                collectionName: 'siteSupervisorProjectStageSchedule',
                docId: docId,
                managerName: _currentUserName,
                managerId: _currentUserId,
                remarks: remarksController.text.trim(),
                supervisorName: supName,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Workforce clearance completed! Supervisor notified.')),
              );
            },
            child: const Text('Release & Deploy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext sheetCtx, {
    required String docId,
    required String supervisorName,
    required bool isOrgReject,
  }) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject Workforce Request', style: TextStyle(color: Color(0xFFDC2626))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide the reason for declining this workforce schedule requisition:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Labour quota exceeded for current phase.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              Navigator.pop(sheetCtx);

              if (isOrgReject) {
                await ApprovalWorkflowService.orgReject(
                  collectionName: 'siteSupervisorProjectStageSchedule',
                  docId: docId,
                  orgUserName: _currentUserName,
                  orgUserId: _currentUserId,
                  reason: reason,
                  supervisorName: supervisorName,
                );
              } else {
                await ApprovalWorkflowService.managerReject(
                  collectionName: 'siteSupervisorProjectStageSchedule',
                  docId: docId,
                  managerName: _currentUserName,
                  managerId: _currentUserId,
                  reason: reason,
                  supervisorName: supervisorName,
                );
              }

              messenger.showSnackBar(
                const SnackBar(content: Text('Workforce request rejected and parties notified.')),
              );
            },
            child: const Text('Reject Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStageColor(ApprovalStage stage) {
    switch (stage) {
      case ApprovalStage.pendingManagerReview:
        return const Color(0xFF6366F1);
      case ApprovalStage.pendingOrgApproval:
        return const Color(0xFF8B5CF6);
      case ApprovalStage.pendingManagerClearance:
        return const Color(0xFF2563EB);
      case ApprovalStage.approved:
        return const Color(0xFF10B981);
      case ApprovalStage.rejectedByManager:
      case ApprovalStage.rejectedByOrg:
        return const Color(0xFFEF4444);
    }
  }
}
