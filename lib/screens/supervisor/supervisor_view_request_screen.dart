import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ViewApprovalScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const ViewApprovalScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<ViewApprovalScreen> createState() => _ViewApprovalScreenState();
}

class _ViewApprovalScreenState extends State<ViewApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Work Schedule Approvals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Segmented Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        darkAccent,
                        Color.alphaBlend(
                          primaryColor.withValues(alpha: 0.35),
                          darkAccent,
                        ),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: darkAccent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Pending'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Approved'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ApprovalList(
                      status: 'Pending',
                      supervisorId: widget.supervisorId,
                      supervisorName: widget.supervisorName,
                      primaryColor: primaryColor,
                      darkAccent: darkAccent,
                    ),
                    ApprovalList(
                      status: 'Approved',
                      supervisorId: widget.supervisorId,
                      supervisorName: widget.supervisorName,
                      primaryColor: primaryColor,
                      darkAccent: darkAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApprovalList extends StatefulWidget {
  final String status;
  final String supervisorId;
  final String supervisorName;
  final Color primaryColor;
  final Color darkAccent;

  const ApprovalList({
    super.key,
    required this.status,
    required this.supervisorId,
    required this.supervisorName,
    required this.primaryColor,
    required this.darkAccent,
  });

  @override
  State<ApprovalList> createState() => _ApprovalListState();
}

class _ApprovalListState extends State<ApprovalList> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (!FirestoreService.isReady)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Firestore is not initialized. Please re-login.',
              style: TextStyle(color: cs.onErrorContainer),
              textAlign: TextAlign.center,
            ),
          ),
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search by Request ID, Project...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search_rounded,
                  color: widget.primaryColor, size: 18),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.primaryColor, width: 1.8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.siteSupervisorProjectStageSchedule
                .where('approvalStatus', isEqualTo: widget.status)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: cs.error),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                  ),
                );
              }

              final allDocs = snapshot.data!.docs;

              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dbSupName = (data['supervisorName'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                final dbSupId = (data['supervisorId'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

                final searchName = widget.supervisorName.trim().toLowerCase();
                final searchId = widget.supervisorId.trim().toLowerCase();

                return dbSupName == searchName || dbSupId == searchId;
              }).toList();

              final filteredDocs = docs.where((doc) {
                if (_searchText.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final wsReqId = (data['wsReqId'] ?? '').toString().toLowerCase();
                final projectName = (data['projectName'] ?? '').toString().toLowerCase();
                final siteId = (data['siteId'] ?? '').toString().toLowerCase();
                final query = _searchText.toLowerCase();
                return wsReqId.contains(query) || projectName.contains(query) || siteId.contains(query);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.status == 'Pending'
                                ? Icons.pending_actions_rounded
                                : Icons.verified_rounded,
                            size: 48,
                            color: widget.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${widget.status} Requests Found',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'For supervisor: ${widget.supervisorName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ApprovalCard(
                    docId: doc.id,
                    data: data,
                    status: widget.status,
                    primaryColor: widget.primaryColor,
                    darkAccent: widget.darkAccent,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ApprovalCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String status;
  final Color primaryColor;
  final Color darkAccent;

  const ApprovalCard({
    super.key,
    required this.docId,
    required this.data,
    required this.status,
    required this.primaryColor,
    required this.darkAccent,
  });

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isApproved = widget.status == 'Approved';

    final statusBgColor = isApproved
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFFBEB);
    final statusTextColor = isApproved
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);
    final statusBorderColor = isApproved
        ? const Color(0xFF6EE7B7)
        : const Color(0xFFFDE68A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            // Header Row
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: widget.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                data['wsReqId'] ?? 'Request',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: widget.darkAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorderColor),
                                ),
                                child: Text(
                                  data['approvalStatus'] ?? widget.status,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data['projectName'] ?? 'Project',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: widget.darkAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded details
            if (_expanded) ...[
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Site ID', data['siteId'] ?? '-'),
                    _buildInfoRow('Supervisor', data['supervisorName'] ?? '-'),
                    _buildInfoRow('Project Stage', data['projectStage'] ?? '-'),
                    const SizedBox(height: 12),

                    // Metrics Grid (Days & Payment)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Requested Days',
                            '${data['reqDays'] ?? 0} Days',
                            Icons.timelapse_rounded,
                            widget.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            'Approved Days',
                            data['appDays'] != null
                                ? '${data['appDays']} Days'
                                : 'Pending',
                            Icons.check_circle_outline_rounded,
                            isApproved
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Estimated Cost',
                            '₹${data['estimatedPayment'] ?? 0}',
                            Icons.payments_outlined,
                            const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            'Approved Cost',
                            data['approvedPayment'] != null
                                ? '₹${data['approvedPayment']}'
                                : 'Pending',
                            Icons.account_balance_wallet_outlined,
                            isApproved
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Labour Details Tables
                    const Text(
                      'Labour Allocation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (data['reqLabours'] is List &&
                        (data['reqLabours'] as List).isNotEmpty)
                      _buildLabourTable(
                        data['reqLabours'] as List<dynamic>,
                        'Requested Roles',
                      ),
                    if (data['appLabours'] is List &&
                        (data['appLabours'] as List).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildLabourTable(
                        data['appLabours'] as List<dynamic>,
                        'Approved Roles',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourTable(List<dynamic> labours, String title) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.5),
            },
            children: labours.map((labour) {
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      labour['labourDesignation'] ?? '',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      '${labour['labourCount'] ?? 0} Persons',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
