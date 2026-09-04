import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/approval_workflow_service.dart';
import 'package:demo_cst/widgets/approval_lifecycle_stepper.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ManagerMaterialApprovalScreen extends StatefulWidget {
  const ManagerMaterialApprovalScreen({super.key});

  @override
  State<ManagerMaterialApprovalScreen> createState() =>
      _ManagerMaterialApprovalScreenState();
}

class _ManagerMaterialApprovalScreenState
    extends State<ManagerMaterialApprovalScreen>
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dynamicGradientColors =
        AppTheme.getBackgroundGradientColors(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Container(
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
              ),
              child: Column(
                children: [
                  // Top Executive Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
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
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.05),
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
                                    'Material Requests',
                                    style: TextStyle(
                                      fontSize: 20,
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
                                      color: const Color(0xFFE11D48)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Approvals',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Authorize raw material supply & requisitions',
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
                  ),

                  // Modern Frosted TabBar Container
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            AppTheme.getDarkAccent(primaryColor),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      tabs: const [
                        Tab(
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('1. Mgr Review'),
                          ),
                        ),
                        Tab(
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('2. Org Approval'),
                          ),
                        ),
                        Tab(
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('3. Mgr Clearance'),
                          ),
                        ),
                        Tab(
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('Approved'),
                          ),
                        ),
                      ],
                      labelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      unselectedLabelColor: const Color(0xFF64748B),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Modern Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(
                            () => _searchQuery = v.trim().toLowerCase()),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search by ID, Site, Supervisor or Stage...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: primaryColor,
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
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
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
                          emptyMessage: 'No requests waiting for Manager Review',
                        ),
                        _buildRequestsList(
                          targetStage: ApprovalStage.pendingOrgApproval,
                          emptyMessage:
                              'No requests waiting for Organization Approval',
                        ),
                        _buildRequestsList(
                          targetStage: ApprovalStage.pendingManagerClearance,
                          emptyMessage:
                              'No requests waiting for Final Manager Clearance',
                        ),
                        _buildRequestsList(
                          targetStage: ApprovalStage.approved,
                          emptyMessage: 'No approved material requests found',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      stream: FirestoreService.getCollection('siteMaterialsRequest').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading requests: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final status = data['status']?.toString();
          final stage = ApprovalWorkflowService.parseStatus(status);

          if (stage != targetStage) return false;

          if (_searchQuery.isEmpty) return true;

          final reqId = (data['matReqId'] ?? doc.id).toString().toLowerCase();
          final siteId = (data['siteId'] ?? '').toString().toLowerCase();
          final supervisor =
              (data['supervisorName'] ?? '').toString().toLowerCase();
          final stageName =
              (data['projectStage'] ?? '').toString().toLowerCase();

          return reqId.contains(_searchQuery) ||
              siteId.contains(_searchQuery) ||
              supervisor.contains(_searchQuery) ||
              stageName.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
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
    final reqId = data['matReqId'] ?? docId;
    final siteId = data['siteId'] ?? 'N/A';
    final supervisor = data['supervisorName'] ?? 'Supervisor';
    final projectStage = data['projectStage'] ?? 'General Stage';
    final date = data['date'] ?? '';
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final history = List<dynamic>.from(data['approvalHistory'] ?? []);
    final status = data['status']?.toString();
    final stageColor = _getStageColor(stage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: stageColor.withValues(alpha: 0.08),
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
          onTap: () => _showRequestDetailsModal(data, docId, stage),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                stageColor.withValues(alpha: 0.18),
                                stageColor.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: stageColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: stageColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request #$reqId',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Site: $siteId',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ApprovalWorkflowService.getStatusDisplayText(status),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: stageColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Details Chips
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          supervisor,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 12,
                        color: const Color(0xFFCBD5E1),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      const Icon(
                        Icons.category_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$projectStage (${materials.length} items)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Visual Stepper
                ApprovalLifecycleStepper(
                  status: status,
                  history: history,
                  isCompact: true,
                ),
                const SizedBox(height: 12),

                // Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fact_check_rounded,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Review & Actions',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: primaryColor,
                          ),
                        ],
                      ),
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

  // --- DETAILS & ACTION MODAL ---
  void _showRequestDetailsModal(
    Map<String, dynamic> data,
    String docId,
    ApprovalStage stage,
  ) {
    final reqId = data['matReqId'] ?? docId;
    final siteId = data['siteId'] ?? 'N/A';
    final supervisor = data['supervisorName'] ?? 'Supervisor';
    final projectStage = data['projectStage'] ?? 'General Stage';
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);
    final history = List<dynamic>.from(data['approvalHistory'] ?? []);
    final status = data['status']?.toString();

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
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
                          'Material Request #$reqId',
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
              const SizedBox(height: 16),

              // Materials List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Requested Material Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${materials.length} ${materials.length == 1 ? 'Item' : 'Items'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Materials Items
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: materials.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final mat = materials[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Icon(
                              Icons.category_rounded,
                              size: 17,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mat['materialName'] ?? 'Item',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Unit: ${mat['materialUnit'] ?? 'Nos'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.12),
                                  primaryColor.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              'Qty: ${mat['materialQty'] ?? 0}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
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

              // Action Buttons based on stage and role
              _buildActionButtons(
                  ctx, data, docId, stage, isManagerUser, isOrgUser),
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

    // 1. Manager Initial Review (Stage 1)
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
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
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

    // 2. Organization Authorization (Stage 2)
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

    // 3. Manager Final Clearance (Stage 3)
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
            'Complete Final Clearance & Release to Site',
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

    // If already approved
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
                'Request is fully Approved & Released',
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
              'Add verification remarks before forwarding to the Organization for final budget authorization:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Stock verified; approved for procurement.',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              Navigator.pop(sheetCtx);
              await ApprovalWorkflowService.managerVerifyAndForward(
                collectionName: 'siteMaterialsRequest',
                docId: docId,
                managerName: _currentUserName,
                managerId: _currentUserId,
                remarks: remarksController.text.trim(),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Request verified & forwarded to Organization!')),
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
        title: const Text('Authorize Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authorize this requisition. It will return to the Manager for final physical clearance and release:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Authorized by HQ. Manager may dispatch.',
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
                collectionName: 'siteMaterialsRequest',
                docId: docId,
                orgUserName: _currentUserName,
                orgUserId: _currentUserId,
                remarks: remarksController.text.trim(),
                supervisorName: supName,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Request authorized and returned to Manager for clearance!')),
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
              'Complete final approval and release the requested materials for immediate dispatch to the site:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                hintText: 'e.g. Materials packed and dispatched via vehicle #12.',
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
                collectionName: 'siteMaterialsRequest',
                docId: docId,
                managerName: _currentUserName,
                managerId: _currentUserId,
                remarks: remarksController.text.trim(),
                supervisorName: supName,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Final clearance completed! Supervisor notified.')),
              );
            },
            child: const Text('Release & Approve', style: TextStyle(color: Colors.white)),
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
        title: const Text('Reject Request', style: TextStyle(color: Color(0xFFDC2626))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide the reason for declining this requisition:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Items currently not needed for this stage.',
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
                  collectionName: 'siteMaterialsRequest',
                  docId: docId,
                  orgUserName: _currentUserName,
                  orgUserId: _currentUserId,
                  reason: reason,
                  supervisorName: supervisorName,
                );
              } else {
                await ApprovalWorkflowService.managerReject(
                  collectionName: 'siteMaterialsRequest',
                  docId: docId,
                  managerName: _currentUserName,
                  managerId: _currentUserId,
                  reason: reason,
                  supervisorName: supervisorName,
                );
              }

              messenger.showSnackBar(
                const SnackBar(content: Text('Request has been rejected and parties notified.')),
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
        return const Color(0xFF2563EB);
      case ApprovalStage.pendingOrgApproval:
        return const Color(0xFF8B5CF6);
      case ApprovalStage.pendingManagerClearance:
        return const Color(0xFFF59E0B);
      case ApprovalStage.approved:
        return const Color(0xFF10B981);
      case ApprovalStage.rejectedByManager:
      case ApprovalStage.rejectedByOrg:
        return const Color(0xFFEF4444);
    }
  }
}
